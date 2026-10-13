"""Normalize Blender duplicate-name suffixes without touching mesh buffers."""
import hashlib
import json
import re
import struct
from pathlib import Path

OUT=Path(__file__).resolve().parent.parent/'generated'


def finalize(path):
    data=path.read_bytes();parts=[];at=12
    while at<len(data):
        size,kind=struct.unpack_from('<II',data,at);at+=8
        chunk=data[at:at+size];at+=size
        if kind==0x4e4f534a:
            g=json.loads(chunk)
            for record in g.get('nodes',[])+g.get('meshes',[]):
                if 'name' in record:
                    record['name']=re.sub(r'^(idle|walk|windup|recovery|death)_(\d\d)\.\d+$',r'\1_\2',record['name'])
            chunk=json.dumps(g,separators=(',',':')).encode()
            chunk+=b' '*((-len(chunk))%4)
        parts.append(struct.pack('<II',len(chunk),kind)+chunk)
    payload=b''.join(parts)
    path.write_bytes(struct.pack('<III',0x46546c67,2,len(payload)+12)+payload)


def finalize_all():
    path=OUT/'boss_manifest.json'
    manifest=json.loads(path.read_text())
    for entry in manifest['lods'].values():
        asset=OUT/entry['file'];finalize(asset)
        entry['bytes']=asset.stat().st_size
        entry['sha256']=hashlib.sha256(asset.read_bytes()).hexdigest()
    path.write_text(json.dumps(manifest,indent=2)+'\n')


if __name__=='__main__':finalize_all()
