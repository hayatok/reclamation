"""Verify exported boss geometry, UV2 pairing, timing endpoints and scale."""
import hashlib
import json
import math
import struct
from pathlib import Path
import numpy as np

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / 'generated'


def read_glb(path):
    data = path.read_bytes()
    magic, version, size = struct.unpack_from('<III', data)
    assert magic == 0x46546c67 and version == 2 and size == len(data)
    at, chunks = 12, {}
    while at < len(data):
        length, kind = struct.unpack_from('<II', data, at)
        at += 8
        chunks[kind] = data[at:at+length]
        at += length
    return json.loads(chunks[0x4e4f534a]), chunks[0x004e4942]


def array(g, blob, index):
    a = g['accessors'][index]
    view = g['bufferViews'][a['bufferView']]
    dtype = np.dtype({5126:'<f4',5125:'<u4',5123:'<u2',5121:'u1'}[a['componentType']])
    n = {'SCALAR':1,'VEC2':2,'VEC3':3,'VEC4':4}[a['type']]
    start = view.get('byteOffset',0) + a.get('byteOffset',0)
    return np.ndarray((a['count'],n), dtype=dtype, buffer=blob, offset=start,
                      strides=(view.get('byteStride',dtype.itemsize*n),dtype.itemsize)).copy()


def main():
    manifest=json.loads((OUT/'boss_manifest.json').read_text())
    report={'status':'pass','lods':{}}
    for lod,entry in manifest['lods'].items():
        path=OUT/entry['file'];g,blob=read_glb(path)
        assert not g.get('skins') and not g.get('animations')
        assert len(g['materials'])==1 and len(g['images'])==1
        nodes={n['name']:n for n in g['nodes'] if 'mesh' in n}
        assert len(nodes)==44
        count=entry['corners'];grid=math.ceil(math.sqrt(count))
        shapes={};normals={};ground=[]
        for clip,info in manifest['clips'].items():
            for f in range(info['frames']):
                name=f'{clip}_{f:02d}';node=nodes[name]
                for key,default in [('translation',[0,0,0]),('rotation',[0,0,0,1]),('scale',[1,1,1])]:
                    assert node.get(key,default)==default,(lod,name,key)
                assert 'matrix' not in node
                primitives=g['meshes'][node['mesh']]['primitives'];assert len(primitives)==1
                p=primitives[0];attrs=p['attributes'];assert set(attrs)=={'POSITION','NORMAL','TEXCOORD_0','TEXCOORD_1'}
                pos=array(g,blob,attrs['POSITION']);normal=array(g,blob,attrs['NORMAL'])
                uv=array(g,blob,attrs['TEXCOORD_1']);idx=array(g,blob,p['indices'])
                assert len(pos)==count and len(idx)==entry['triangles']*3
                assert np.isfinite(pos).all() and np.isfinite(normal).all() and np.isfinite(uv).all()
                cells=np.floor(uv*grid).astype(int);ids=cells[:,1]*grid+cells[:,0]
                assert np.array_equal(np.sort(ids),np.arange(count)),(lod,name,'corner IDs')
                shapes[name]=pos[np.argsort(ids)];normals[name]=normal[np.argsort(ids)]
                ground.append(float(pos[:,1].min()))
        # Continuity is checked by semantic corner ID, not incidental GLB ordering.
        assert np.array_equal(shapes['windup_11'],shapes['recovery_00'])
        assert np.array_equal(normals['windup_11'],normals['recovery_00'])
        idle_height=float(shapes['idle_00'][:,1].max())
        final_height=float(shapes['death_09'][:,1].max())
        assert 1.5<idle_height<1.8,(lod,idle_height)
        assert final_height<.85,(lod,final_height)
        assert min(ground)>-.015,(lod,min(ground))
        assert path.stat().st_size<10_000_000
        report['lods'][lod]={'poses':44,'surfaces_per_pose':1,'triangles':entry['triangles'],
            'stable_corners':count,'bytes':path.stat().st_size,'idle_height_m':idle_height,
            'final_death_height_m':final_height,'minimum_ground_m':min(ground),
            'windup_recovery_identical':True,'sha256':hashlib.sha256(path.read_bytes()).hexdigest()}
    (ROOT/'review/glb_contract.json').write_text(json.dumps(report,indent=2)+'\n')
    print(json.dumps(report,indent=2))


if __name__=='__main__':main()
