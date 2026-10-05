#!/usr/bin/env python3
"""Share byte-identical model textures without changing geometry or image pixels.

Run after original Blender exports and Godot's initial image extraction. Source
aliases remain in the repository; only unused aliases are excluded from exports.
Godot 4.6 GLTFDocument loads external image URIs as shared Texture2D resources.
"""
import argparse
import hashlib
import io
import json
import os
from pathlib import Path
import re
import struct

from PIL import Image


def digest(data):
    return hashlib.sha256(data).hexdigest()


def pixels(data):
    with Image.open(io.BytesIO(data)) as image:
        return image.size, digest(image.convert("RGBA").tobytes())


def read_glb(path):
    data = path.read_bytes()
    magic, version, total = struct.unpack_from("<III", data)
    assert magic == 0x46546C67 and version == 2 and total == len(data), path
    chunks, cursor = [], 12
    while cursor < len(data):
        length, kind = struct.unpack_from("<II", data, cursor)
        cursor += 8
        chunks.append((kind, data[cursor:cursor + length]))
        cursor += length
    assert cursor == len(data) and chunks[0][0] == 0x4E4F534A
    return json.loads(chunks[0][1]), chunks, data


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=Path(__file__).resolve().parents[1])
    args = parser.parse_args()
    root = args.root.resolve()
    models = root / "assets/models"
    documents, groups, references = {}, {}, []
    for path in sorted(models.rglob("*.glb")):
        doc, chunks, original = read_glb(path)
        documents[path] = (doc, chunks, original)
        for index, image in enumerate(doc.get("images", [])):
            if image.get("uri", "").startswith("data:"):
                continue
            png = path.parent / image["uri"] if "uri" in image else path.with_name(path.stem + "_" + image.get("name", str(index)) + ".png")
            png = png.resolve()
            settings = Path(str(png) + ".import")
            if not png.is_file() or not settings.is_file():
                continue
            assert png.is_relative_to(root), png
            data = png.read_bytes()
            params = settings.read_text().split("[params]", 1)[1]
            key = (digest(data), params)
            groups.setdefault(key, set()).add(png)
            references.append((path, index, png, key))
    shared = {key: sorted(paths)[0] for key, paths in groups.items() if len(paths) > 1}
    modified, aliases = set(), {}
    for path, index, png, key in references:
        if key not in shared:
            continue
        canonical = shared[key]
        doc, chunks, _ = documents[path]
        image = doc["images"][index]
        if "bufferView" in image:
            view = doc["bufferViews"][image["bufferView"]]
            assert view.get("buffer", 0) == 0
            binary = next(data for kind, data in chunks if kind == 0x004E4942)
            start = view.get("byteOffset", 0)
            embedded = binary[start:start + view["byteLength"]]
            assert pixels(embedded) == pixels(canonical.read_bytes()), (path, index)
        image.pop("bufferView", None)
        image["uri"] = os.path.relpath(canonical, path.parent).replace(os.sep, "/")
        modified.add(path)
        if png != canonical:
            aliases[png.relative_to(root).as_posix()] = canonical.relative_to(root).as_posix()
    for path in sorted(modified):
        doc, chunks, original = documents[path]
        before = json.loads(chunks[0][1])
        before.pop("images", None)
        after = dict(doc)
        after.pop("images", None)
        assert before == after, "Only image references may change"
        encoded = json.dumps(doc, ensure_ascii=False, separators=(",", ":")).encode()
        encoded += b" " * (-len(encoded) % 4)
        body = struct.pack("<II", len(encoded), chunks[0][0]) + encoded
        for kind, data in chunks[1:]:
            body += struct.pack("<II", len(data), kind) + data
        rewritten = struct.pack("<III", 0x46546C67, 2, 12 + len(body)) + body
        path.write_bytes(rewritten)
        _, check, _ = read_glb(path)
        assert check[1:] == chunks[1:], "All geometry/binary bytes must be preserved"
    if aliases:
        presets = root / "export_presets.cfg"
        def add_exclusions(match):
            entries = set(filter(None, match.group(1).split(","))) | set(aliases)
            return 'exclude_filter="' + ",".join(sorted(entries)) + '"'
        presets.write_text(re.sub(r'exclude_filter="([^"]*)"', add_exclusions, presets.read_text()))
        report = {"method": "external glTF image URI, identical PNG bytes and importer parameters", "models": [p.relative_to(root).as_posix() for p in sorted(modified)], "export_excluded_aliases": aliases, "geometry_and_non_image_gltf_unchanged": True}
        report_path = root / "docs/SHARED_MODEL_TEXTURES.json"
        report_path.write_text(json.dumps(report, indent=2) + "\n")
    print(json.dumps({"rewritten_models": len(modified), "shared_texture_groups": len(shared), "excluded_aliases": len(aliases)}))


if __name__ == "__main__":
    main()
