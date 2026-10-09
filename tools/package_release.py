#!/usr/bin/env python3
"""Offline, fail-closed release packaging. Never exports, edits source, or publishes.

Use a separately frozen, remotely verified source snapshot, not working_game.
The caller must establish that both raw exports came from that exact snapshot.
See README.md beside this script for the input contract and verification limits.
"""
import argparse
import copy
import hashlib
from html.parser import HTMLParser
import json
import os
from pathlib import Path, PurePosixPath
import plistlib
import re
import runpy
import stat
import struct
import tempfile
import zipfile


MANIFEST = "SOURCE_MANIFEST.sha256"
PROVENANCE = "BUILD-PROVENANCE.json"
ENGINE = "4.6.3"
PAGES_SHA = "26a60bd2747161202e24135b322f6d62ba4cf6323e12afdf4f25f6c6166107e5"
REQUIRED_SOURCE = {"main.gd", "main.tscn", "project.godot", "export_presets.cfg",
                   "AGENTS.md", ".github/workflows/pages.yml", "scripts/prepare_pages.py",
                   "docs/PUBLISHING.md"}
# Godot/Emscripten has a virtual /home/web_user and a /tmp/drop-${...}
# drag/drop directory. Those template literals are not leaked host paths.
LOCAL_PATH = re.compile(r'''file://[/A-Za-z]|/(?:workspace|Users|private/tmp)/|/home/(?!web_user["'])|/tmp/(?!drop-\$\{)|(?<![A-Za-z0-9_])[A-Za-z]:[\\/]''')


def require(condition, message):
    if not condition:
        raise ValueError(message)


def digest(data):
    return hashlib.sha256(data).hexdigest()


def file_sha(path):
    with path.open("rb") as stream:
        return hashlib.file_digest(stream, "sha256").hexdigest()


def safe_name(name, directory=False):
    trimmed = name[:-1] if directory and name.endswith("/") else name
    p = PurePosixPath(trimmed)
    require(bool(trimmed) and not p.is_absolute() and str(p) == trimmed
            and not any(x in {".", ".."} for x in p.parts)
            and not any(ord(x) < 32 for x in name)
            and "\\" not in name and ":" not in name,
            f"Unsafe or noncanonical path: {name!r}")
    return p


def inventory(root):
    """No symlink traversal, hidden exceptions, caches, or metadata exceptions."""
    require(root.is_dir() and not root.is_symlink(), f"Not a real directory: {root}")
    files = {}
    for current, dirs, names in os.walk(root, followlinks=False):
        for name in dirs + names:
            path = Path(current) / name
            relative = path.relative_to(root).as_posix()
            safe_name(relative)
            mode = path.lstat().st_mode
            require(not stat.S_ISLNK(mode), f"Symlink forbidden: {relative}")
            require(stat.S_ISDIR(mode) or stat.S_ISREG(mode), f"Special file forbidden: {relative}")
            if stat.S_ISREG(mode):
                files[relative] = path
    require(len({n.casefold() for n in files}) == len(files), "Case-colliding file paths")
    return files


def check_source(source, version):
    files = inventory(source)
    require(MANIFEST in files, "Source manifest missing")
    manifest_bytes = files[MANIFEST].read_bytes()
    expected = {}
    for number, line in enumerate(manifest_bytes.decode("utf-8").splitlines(), 1):
        match = re.fullmatch(r"([0-9a-fA-F]{64})  (.+)", line)
        require(match is not None, f"Malformed manifest line {number}")
        checksum, name = match.groups()
        safe_name(name)
        require(name not in expected and name != MANIFEST, f"Duplicate/self manifest entry: {name}")
        require(not any(part in {".git", ".godot", "__pycache__"} for part in PurePosixPath(name).parts),
                f"Cache or repository metadata in manifest: {name}")
        expected[name] = checksum.lower()
    require(REQUIRED_SOURCE <= expected.keys(), f"Required source missing: {sorted(REQUIRED_SOURCE - expected.keys())}")
    allowed = set(expected) | {MANIFEST}
    require(set(files) == allowed,
            f"Source allowlist mismatch; extra={sorted(set(files) - allowed)}, missing={sorted(allowed - set(files))}")
    for name, checksum in expected.items():
        require(file_sha(files[name]) == checksum, f"Source checksum mismatch: {name}")
    require(expected["scripts/prepare_pages.py"] == PAGES_SHA,
            "Pages helper changed; inspect the new contract before updating PAGES_SHA")
    project = files["project.godot"].read_text()
    require(re.search(r'^config/version="' + re.escape(version) + r'"\s*$', project, re.M),
            "project.godot version does not match release")
    presets = files["export_presets.cfg"].read_text()
    for key in ("application/short_version", "application/version"):
        values = re.findall(r"^" + re.escape(key) + r'="([^"]+)"\s*$', presets, re.M)
        require(values and all(v == version for v in values), f"Wrong macOS preset {key}")
    expected[MANIFEST] = digest(manifest_bytes)
    return expected


def zip_members(archive, max_size=1024 * 1024 * 1024):
    infos = archive.infolist()
    names = [i.filename for i in infos]
    require(len(names) == len(set(names)) == len({n.casefold() for n in names}), "Duplicate ZIP members")
    require(sum(i.file_size for i in infos) < max_size, "Oversized ZIP payload")
    for info in infos:
        safe_name(info.filename, directory=info.is_dir())
        mode = info.external_attr >> 16
        require(not stat.S_ISLNK(mode), f"Symlink in ZIP: {info.filename}")
        require(stat.S_IFMT(mode) in (0, stat.S_IFREG, stat.S_IFDIR), "Special ZIP member")
        require(not info.flag_bits & 1, "Encrypted ZIP member")
    regular = {i.filename for i in infos if not i.is_dir()}
    for name in names:
        require(not any(str(parent) in regular for parent in PurePosixPath(name).parents),
                "ZIP file/directory collision")
    return {i.filename: i for i in infos}


def check_pck(data):
    require(len(data) >= 20 and data[:4] == b"GDPC", "Bad Godot PCK header")
    require(struct.unpack_from("<III", data, 8) == (4, 6, 3), "PCK engine version is not Godot 4.6.3")


def universal_architectures(binary):
    require(len(binary) >= 8, "Truncated Mach-O")
    magic, count = struct.unpack_from(">II", binary)
    require(magic in (0xCAFEBABE, 0xCAFEBABF) and count == 2,
            "macOS executable must be a two-architecture universal Mach-O")
    width = 32 if magic == 0xCAFEBABF else 20
    require(8 + count * width <= len(binary), "Truncated universal header")
    arches, regions = [], []
    for i in range(count):
        entry = 8 + i * width
        cpu = struct.unpack_from(">I", binary, entry)[0]
        offset, size = struct.unpack_from(">QQ" if width == 32 else ">II", binary, entry + 8)
        require(cpu in (0x01000007, 0x0100000C), "Unexpected macOS architecture")
        require(offset >= 8 + count * width and size >= 32 and offset + size <= len(binary),
                "Mach-O slice out of bounds")
        require(binary[offset:offset + 4] == b"\xcf\xfa\xed\xfe", "Missing 64-bit Mach-O slice")
        require(struct.unpack_from("<I", binary, offset + 4)[0] == cpu, "Mach-O architecture mismatch")
        regions.append((offset, offset + size))
        arches.append("arm64" if cpu == 0x0100000C else "x86_64")
    require(set(arches) == {"arm64", "x86_64"}, "Duplicate macOS architecture")
    require(max(regions[0][0], regions[1][0]) >= min(regions[0][1], regions[1][1]),
            "Overlapping Mach-O slices")
    return sorted(arches)


def check_mac(path, version):
    with zipfile.ZipFile(path) as archive:
        members = zip_members(archive)
        require(PROVENANCE not in members, "Raw macOS ZIP already has provenance")
        roots = {PurePosixPath(n).parts[0] for n in members}
        require(len(roots) == 1 and next(iter(roots)).endswith(".app"), "macOS ZIP must contain one root .app")
        app = next(iter(roots))
        info_name = app + "/Contents/Info.plist"
        require(info_name in members, "macOS Info.plist missing")
        plist = plistlib.loads(archive.read(info_name))
        for key in ("CFBundleShortVersionString", "CFBundleVersion"):
            require(plist.get(key) == version, f"macOS {key} does not match release")
        executable = plist.get("CFBundleExecutable", "")
        require(isinstance(executable, str) and len(safe_name(executable).parts) == 1,
                "Invalid macOS executable name")
        executable = app + "/Contents/MacOS/" + executable
        require(executable in members, "macOS executable missing")
        require(members[executable].external_attr >> 16 & 0o111, "macOS executable permission missing")
        pcks = [n for n in members if n.startswith(app + "/Contents/Resources/") and n.endswith(".pck")]
        require(len(pcks) == 1, "Expected one macOS resource PCK")
        check_pck(archive.read(pcks[0])[:20])
        arches = universal_architectures(archive.read(executable))
        hashes = {name: digest(archive.read(name)) for name in members}
        attrs = {name: (i.external_attr, i.create_system) for name, i in members.items()}
    return {"architectures": arches, "executable": executable}, hashes, attrs


class ResourceLinks(HTMLParser):
    def __init__(self):
        super().__init__()
        self.references = []
        self.base = []

    def handle_starttag(self, tag, attrs):
        attrs = dict(attrs)
        if tag == "base":
            self.base.append(attrs.get("href", ""))
        if tag == "link":
            require("manifest" not in attrs.get("rel", "").lower().split(), "PWA manifest link forbidden")
        for key in ("src", "href"):
            if key in attrs and tag != "base":
                self.references.append(attrs[key])


def check_web(web, version):
    files = inventory(web)
    html_files = [n for n in files if n.endswith(".html")]
    require(len(html_files) == 1 and "/" not in html_files[0], "Expected one root HTML shell")
    shell_name = html_files[0]
    shell = files[shell_name].read_text(encoding="utf-8")
    require(re.search(r"const GODOT_THREADS_ENABLED\s*=\s*false\s*;", shell), "Threaded Web export forbidden")
    match = re.search(r"const GODOT_CONFIG\s*=\s*(\{.*?\});", shell)
    require(match is not None, "GODOT_CONFIG missing")
    config = json.loads(match.group(1))
    require(not config.get("serviceWorker") and not config.get("gdextensionLibs"), "PWA/extensions forbidden")
    executable = config.get("executable", "")
    require(executable == "reclamation-" + version, "Expected versioned executable basename reclamation-" + version)
    require(shell_name in {"index.html", executable + ".html"}, "Unexpected Web shell basename")
    required = {executable + suffix for suffix in (".js", ".pck", ".wasm", ".audio.worklet.js", ".audio.position.worklet.js")}
    require(required <= files.keys(), f"Missing Web payload/worklet: {sorted(required - files.keys())}")
    suffixes = {".js", ".pck", ".wasm", ".audio.worklet.js", ".audio.position.worklet.js",
                ".icon.png", ".apple-touch-icon.png", ".png"}
    for name in files:
        allowed = name == shell_name or name in {executable + s for s in suffixes} or name.startswith("licenses/")
        require(allowed, f"Unexpected Web file (thread/PWA/build files forbidden): {name}")
    sizes = config.get("fileSizes")
    require(isinstance(sizes, dict) and {executable + ".pck", executable + ".wasm"} <= sizes.keys(),
            "Web config missing PCK/WASM sizes")
    for name, size in sizes.items():
        require(name in {executable + s for s in (".js", ".pck", ".wasm")}
                and type(size) is int and size == files[name].stat().st_size, f"Wrong Web payload size: {name}")
    require(files[executable + ".wasm"].read_bytes()[:8] == b"\0asm\x01\0\0\0", "Bad WebAssembly header")
    with files[executable + ".pck"].open("rb") as stream:
        check_pck(stream.read(20))
    links = ResourceLinks()
    links.feed(shell)
    require(len(links.base) <= 1 and all(base in {".", "./"} for base in links.base), "Web base path must be relative")
    require(executable + ".js" in links.references, "Web shell does not load versioned engine JS")
    for reference in links.references:
        if reference.startswith("#") or reference == "":
            continue
        name = reference.removeprefix("./")
        safe_name(name)
        require(name in files, f"Web reference is not an adjacent packaged file: {reference}")
    for name, path in files.items():
        if name == shell_name or name.endswith(".js"):
            require(not LOCAL_PATH.search(path.read_text(encoding="utf-8")), f"Local filesystem path leaked in Web file: {name}")
    hashes = {("index.html" if n == shell_name else n): file_sha(p) for n, p in files.items()}
    mapped_files = {("index.html" if n == shell_name else n): p for n, p in files.items()}
    return {"executable": executable, "single_threaded": True, "pwa_enabled": False,
            "relative_runtime_paths": True}, hashes, mapped_files


def add_bytes(archive, name, data, mode=0o100644):
    info = zipfile.ZipInfo(name, date_time=(1980, 1, 1, 0, 0, 0))
    info.create_system = 3
    info.external_attr = mode << 16
    info.compress_type = zipfile.ZIP_DEFLATED
    archive.writestr(info, data)


def check_archive(path, expected, attrs=None, max_size=1024 * 1024 * 1024):
    with zipfile.ZipFile(path) as archive:
        members = zip_members(archive, max_size)
        require(set(members) == set(expected), f"Produced ZIP file set mismatch: {path.name}")
        for name, checksum in expected.items():
            require(digest(archive.read(name)) == checksum, f"Produced ZIP checksum mismatch: {name}")
            if attrs and name in attrs:
                require((members[name].external_attr, members[name].create_system) == attrs[name],
                        f"ZIP permissions changed: {name}")


def package(args):
    require(re.fullmatch(r"[0-9a-fA-F]{40}", args.commit) and int(args.commit, 16) != 0,
            "--commit must be a nonzero full 40-hex final remote commit")
    require(re.fullmatch(r"\d+\.\d+\.\d+", args.version), "Invalid semantic version")
    source = args.source.resolve(strict=True)
    web = args.web_dir.resolve(strict=True)
    mac = args.mac_zip.resolve(strict=True)
    output = args.output.absolute()
    require(not output.exists(), "Output directory must be new; existing assets are never overwritten")
    require(not args.source.is_symlink() and not args.web_dir.is_symlink() and not args.mac_zip.is_symlink(), "Inputs must not be symlinks")
    for input_dir in (source, web):
        require(not output.resolve().is_relative_to(input_dir), "Output must be outside source/Web inputs")
    require(output.parent.is_dir(), "Output parent directory must already exist")
    source_hashes = check_source(source, args.version)
    mac_sha = file_sha(mac)
    mac_report, mac_hashes, mac_attrs = check_mac(mac, args.version)
    web_report, web_hashes, web_files = check_web(web, args.version)
    tag = "v" + args.version
    provenance = {
        "schema_version": 1, "version": args.version, "engine_version": ENGINE,
        "source_commit": args.commit.lower(), "source_main_sha256": source_hashes["main.gd"],
        "source_manifest_sha256": source_hashes[MANIFEST], "source_file_count": len(source_hashes),
        "source_commit_verification": "Caller-supplied final remote commit; no network verification is performed by this packager.",
        "raw_export_source_match": "Caller must export both inputs from this exact verified source snapshot; this packager does not re-export or prove PCK/source equivalence.",
        "raw_macos_zip_sha256": mac_sha, "raw_web_files_sha256": web_hashes,
        "pages_contract_sha256": PAGES_SHA, "macos_static_validation": mac_report,
        "web_static_validation": web_report,
        "validation_limits": {
            "native_cloud": "Packaging checks bytes and structures only; native Godot/Linux cloud gameplay or visual tests are separate evidence and are not performed or inferred here.",
            "macos": "No real Mac execution, Gatekeeper, notarization, or codesign validity test; universal architectures and ZIP executable permissions are checked statically.",
            "web": "No real browser boot, WebGL, IndexedDB, audio, touch, or deployed Pages verification is performed here.",
            "phone": "No real iPhone/Android device test; desktop/cloud viewport checks do not establish phone behavior.",
        },
    }
    provenance_bytes = (json.dumps(provenance, ensure_ascii=False, indent=2, sort_keys=True) + "\n").encode()
    provenance_sha = digest(provenance_bytes)
    with tempfile.TemporaryDirectory(prefix=".package-", dir=output.parent) as temp:
        stage = Path(temp) / "assets"
        stage.mkdir()
        source_zip = stage / f"Reclamation-{tag}-Source.zip"
        mac_zip = stage / f"Reclamation-{tag}-macOS.zip"
        web_zip = stage / f"Reclamation-{tag}-Web.zip"
        with zipfile.ZipFile(source_zip, "w") as archive:
            for name in sorted(source_hashes):
                add_bytes(archive, name, (source / name).read_bytes())
        with zipfile.ZipFile(mac) as raw, zipfile.ZipFile(mac_zip, "w") as archive:
            archive.comment = raw.comment
            for info in raw.infolist():
                archive.writestr(copy.copy(info), raw.read(info.filename))
            add_bytes(archive, PROVENANCE, provenance_bytes)
        with zipfile.ZipFile(web_zip, "w") as archive:
            for name, path in sorted(web_files.items()):
                add_bytes(archive, name, path.read_bytes())
            add_bytes(archive, PROVENANCE, provenance_bytes)
        (stage / PROVENANCE).write_bytes(provenance_bytes)
        check_archive(source_zip, source_hashes)
        check_archive(mac_zip, mac_hashes | {PROVENANCE: provenance_sha}, mac_attrs)
        check_archive(web_zip, web_hashes | {PROVENANCE: provenance_sha}, max_size=512 * 1024 * 1024)
        checksums = {p.name: file_sha(p) for p in sorted(stage.iterdir())}
        checksum_text = "".join(f"{checksum}  {name}\n" for name, checksum in checksums.items())
        (stage / "SHA256SUMS.txt").write_text(checksum_text)
        # Execute only the inspected, SHA-pinned helper's offline prepare function.
        # Its main/download/legacy paths are never invoked.
        helper = runpy.run_path(str(source / "scripts/prepare_pages.py"))
        helper["prepare"](tag, stage, Path(temp) / "pages-contract", source, args.commit.lower(),
                          f"https://github.com/hayotok/reclamation/releases/tag/{tag}")
        require(check_source(source, args.version) == source_hashes, "Source changed during packaging")
        require(file_sha(mac) == mac_sha, "Raw macOS ZIP changed during packaging")
        require(check_web(web, args.version)[1] == web_hashes, "Raw Web export changed during packaging")
        require((stage / PROVENANCE).read_bytes() == provenance_bytes, "Provenance readback mismatch")
        require((stage / "SHA256SUMS.txt").read_text() == checksum_text, "Checksum file readback mismatch")
        for name, checksum in checksums.items():
            require(file_sha(stage / name) == checksum, f"Final asset readback mismatch: {name}")
        require(len(list(stage.iterdir())) == 5, "Expected exactly five release assets")
        require(not output.exists(), "Output appeared during packaging")
        stage.rename(output)
    print(json.dumps({"output": str(output), "version": args.version, "source_commit": args.commit.lower(),
                      "source_main_sha256": source_hashes["main.gd"], "assets": checksums,
                      "status": "static packaging verification passed; no export/publication/platform execution"}, indent=2))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", type=Path, required=True, help="Exact frozen source allowlist plus SOURCE_MANIFEST.sha256")
    parser.add_argument("--commit", required=True, help="Final independently verified remote commit, full 40 hex")
    parser.add_argument("--mac-zip", type=Path, required=True, help="Raw Godot macOS universal ZIP")
    parser.add_argument("--web-dir", type=Path, required=True, help="Raw versioned, single-threaded Godot Web export")
    parser.add_argument("--version", default="0.48.0")
    parser.add_argument("--output", type=Path, required=True, help="New directory outside input trees")
    args = parser.parse_args()
    try:
        package(args)
    except (ValueError, OSError, KeyError, zipfile.BadZipFile, AssertionError) as error:
        parser.exit(1, f"Packaging rejected: {error}\n")


if __name__ == "__main__":
    main()
