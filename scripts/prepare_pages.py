#!/usr/bin/env python3
"""Package only the checksum-verified static files from an existing game release."""
import argparse
import hashlib
import html
import json
from pathlib import Path, PurePosixPath
import re
import stat
import subprocess
import tempfile
import zipfile


def sha256(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def prepare(tag, assets, output, source, commit, release_url):
    assert re.fullmatch(r"v\d+\.\d+\.\d+", tag), "Invalid release tag"
    archive = assets / f"Reclamation-{tag}-Web.zip"
    lines = (assets / "SHA256SUMS.txt").read_text().splitlines()
    matches = [line.split()[0] for line in lines if len(line.split()) == 2 and line.split()[1].lstrip('*') == archive.name]
    assert len(matches) == 1 and re.fullmatch(r"[a-fA-F0-9]{64}", matches[0]), "Missing or ambiguous Web checksum"
    assert sha256(archive) == matches[0].lower(), "Web ZIP checksum mismatch"
    assert not output.exists(), "Output directory must be new"
    game = output / "releases" / tag
    game.mkdir(parents=True)
    with zipfile.ZipFile(archive) as z:
        names = z.namelist()
        assert len(names) == len(set(names)), "Duplicate ZIP members"
        assert sum(i.file_size for i in z.infolist()) < 512 * 1024 * 1024, "Oversized export"
        for info in z.infolist():
            p = PurePosixPath(info.filename)
            assert not p.is_absolute() and '..' not in p.parts and '\\' not in info.filename, "Unsafe ZIP path"
            assert not stat.S_ISLNK(info.external_attr >> 16), "Symlink in export"
        required = {'index.html', 'BUILD-PROVENANCE.json'}
        assert required.issubset(names), "Web export must have index files at ZIP root"
        provenance = json.loads(z.read('BUILD-PROVENANCE.json'))
        assert provenance['version'] == tag[1:], "Build/release version mismatch"
        assert provenance['source_main_sha256'] == sha256(source / 'main.gd'), "Build does not match tagged game source"
        shell = z.read('index.html').decode()
        assert re.search(r'const GODOT_THREADS_ENABLED\s*=\s*false\s*;', shell), "Pages requires single-thread export"
        config = json.loads(re.search(r'const GODOT_CONFIG\s*=\s*(\{.*?\});', shell).group(1))
        assert not config.get('serviceWorker'), "Disable PWA service worker for versioned deployment"
        assert not config.get('gdextensionLibs'), "Unsupported extension export"
        executable = config['executable']
        assert re.fullmatch(r'[A-Za-z0-9_.-]+', executable), 'Invalid executable basename'
        runtime_required = {executable + suffix for suffix in ('.js', '.pck', '.wasm')}
        assert runtime_required.issubset(names), 'Missing runtime payload'
        for filename, size in config['fileSizes'].items():
            assert filename in runtime_required and z.getinfo(filename).file_size == size, 'Wrong payload size'
        assert z.read(executable + '.wasm')[:8] == b'\0asm\x01\0\0\0', 'Bad WebAssembly header'
        # Only runtime files, provenance and attribution; do not publish launch scripts.
        for name in names:
            p = PurePosixPath(name)
            if name.endswith('/'):
                continue
            if (len(p.parts) == 1 and (name == 'index.html' or name.startswith(executable + '.') or name == 'BUILD-PROVENANCE.json')) or p.parts[0] == 'licenses':
                dest = game.joinpath(*p.parts)
                dest.parent.mkdir(parents=True, exist_ok=True)
                dest.write_bytes(z.read(name))
    # Keep the engine's relative file paths unchanged inside a version-specific directory.
    destination = f"releases/{tag}/"
    target = html.escape(destination, quote=True)
    (output / 'index.html').write_text(f'<!doctype html><html lang="ja"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><meta http-equiv="refresh" content="0;url={target}"><title>RECLAMATION</title><a href="{target}">RECLAMATION をプレイ</a><script>location.replace({json.dumps(destination)}+location.search+location.hash)</script></html>')
    (output / '.nojekyll').write_text('')
    (output / 'version.json').write_text(json.dumps({'version':tag[1:], 'tag':tag, 'commit':commit, 'release':release_url, 'web_sha256':matches[0].lower(), 'game':destination},indent=2)+'\n')
    print(json.dumps({'tag':tag,'commit':commit,'verified_web_sha256':matches[0].lower(),'runtime_files':len(list(game.rglob('*')))}))


def main():
    p=argparse.ArgumentParser()
    p.add_argument('--tag',required=True)
    p.add_argument('--repository',default='hayatok/reclamation')
    p.add_argument('--output',type=Path,required=True)
    p.add_argument('--assets-dir',type=Path,help='Use already-downloaded assets for offline verification')
    p.add_argument('--source-dir',type=Path,default=Path('.'))
    a=p.parse_args()
    assert re.fullmatch(r'v\d+\.\d+\.\d+',a.tag), 'Invalid tag'
    assert a.repository == 'hayatok/reclamation', 'Unexpected repository'
    commit=subprocess.check_output(['git','rev-parse','HEAD'],text=True).strip()
    release_url=f'https://github.com/{a.repository}/releases/tag/{a.tag}'
    if a.assets_dir:
        prepare(a.tag,a.assets_dir,a.output,a.source_dir,commit,release_url)
    else:
        release=json.loads(subprocess.check_output(['gh','release','view',a.tag,'--repo',a.repository,'--json','isDraft,tagName,url,assets'],text=True))
        assert not release['isDraft'] and release['tagName']==a.tag, 'Expected published release'
        expected={f'Reclamation-{a.tag}-Web.zip','SHA256SUMS.txt'}
        names=[x['name'] for x in release['assets']]
        assert all(names.count(x)==1 for x in expected), 'Release assets incomplete'
        with tempfile.TemporaryDirectory() as temp:
            subprocess.run(['gh','release','download',a.tag,'--repo',a.repository,'--pattern',f'Reclamation-{a.tag}-Web.zip','--pattern','SHA256SUMS.txt','--dir',temp],check=True)
            prepare(a.tag,Path(temp),a.output,a.source_dir,commit,release['url'])

if __name__=='__main__':
    main()
