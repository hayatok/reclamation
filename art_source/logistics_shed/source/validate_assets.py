"""Independently inspect the final glTF files, including decoded bounds/indices/UVs."""
import json, struct, math, hashlib, argparse
from pathlib import Path
ROOT=Path(__file__).resolve().parent.parent
ASSETS=ROOT/'assets'
parser=argparse.ArgumentParser(description=__doc__)
parser.add_argument('--assets-dir',type=Path,default=ASSETS)
parser.add_argument('--atlas-dir',type=Path)
args=parser.parse_args()
ASSETS=args.assets_dir.resolve()
ATLAS=(args.atlas_dir or ASSETS).resolve()
TYPES={'SCALAR':1,'VEC2':2,'VEC3':3,'VEC4':4}
COMP={5120:('b',1),5121:('B',1),5122:('h',2),5123:('H',2),5125:('I',4),5126:('f',4)}

def read_glb(path):
    raw=path.read_bytes();magic,version,total=struct.unpack_from('<III',raw)
    assert magic==0x46546c67 and version==2 and total==len(raw)
    jslen,jstype=struct.unpack_from('<II',raw,12);assert jstype==0x4e4f534a
    g=json.loads(raw[20:20+jslen]);off=20+jslen
    blen,btype=struct.unpack_from('<II',raw,off);assert btype==0x004e4942
    return g,raw[off+8:off+8+blen]

def decode(g,binary,index):
    a=g['accessors'][index];v=g['bufferViews'][a['bufferView']]
    char,size=COMP[a['componentType']];n=TYPES[a['type']]
    step=v.get('byteStride',size*n);start=v.get('byteOffset',0)+a.get('byteOffset',0)
    return [struct.unpack_from('<'+char*n,binary,start+i*step) for i in range(a['count'])]

def validate(name):
    p=ASSETS/(name+'.glb');g,binary=read_glb(p)
    assert len(g['meshes'])==1 and len(g['materials'])==1
    primitives=g['meshes'][0]['primitives'];assert len(primitives)==1
    pr=primitives[0];assert pr.get('mode',4)==4 and pr['material']==0
    mat=g['materials'][0];assert mat.get('alphaMode','OPAQUE')=='OPAQUE'
    pos=decode(g,binary,pr['attributes']['POSITION'])
    indices=[x[0] for x in decode(g,binary,pr['indices'])]
    uv=decode(g,binary,pr['attributes']['TEXCOORD_0'])
    normal=decode(g,binary,pr['attributes']['NORMAL'])
    assert len(indices)%3==0 and len(indices)//3<=5500
    assert max(indices)<len(pos) and min(indices)>=0
    assert all(math.isfinite(x) for v in pos+uv+normal for x in v)
    assert all(0<=x<=1 for v in uv for x in v)
    assert all(abs(sum(x*x for x in v)-1)<.001 for v in normal)
    mn=[min(v[k] for v in pos) for k in range(3)]
    mx=[max(v[k] for v in pos) for k in range(3)]
    assert mn[0]>=-1.80001 and mx[0]<=1.80001
    assert mn[2]>=-1.60001 and mx[2]<=1.60001
    assert abs(mn[1])<.00001 and mx[1]<=3.1
    textures=[]
    for im in g['images']:
        assert 'uri' in im and 'bufferView' not in im
        ip=ATLAS/im['uri'];assert ip.is_file()
        textures.append({'uri':im['uri'],'bytes':ip.stat().st_size,'sha256':hashlib.sha256(ip.read_bytes()).hexdigest()})
    # Non-zero area triangles are necessary for clean shadows and culling.
    tiny=0
    for i in range(0,len(indices),3):
        a,b,c=[pos[k] for k in indices[i:i+3]]
        ab=[b[k]-a[k] for k in range(3)];ac=[c[k]-a[k] for k in range(3)]
        cr=[ab[1]*ac[2]-ab[2]*ac[1],ab[2]*ac[0]-ab[0]*ac[2],ab[0]*ac[1]-ab[1]*ac[0]]
        if sum(x*x for x in cr)<1e-18:tiny+=1
    assert tiny==0,(name,tiny)
    return {'file':p.name,'bytes':p.stat().st_size,'sha256':hashlib.sha256(p.read_bytes()).hexdigest(),'triangles':len(indices)//3,'export_vertices':len(pos),'indexed':True,'meshes':1,'primitives':1,'materials':1,'alpha_mode':'OPAQUE','bounds_min':mn,'bounds_max':mx,'height_m':mx[1],'degenerate_triangles':tiny,'external_textures':textures}

if __name__=='__main__':
    report={'assets':[validate(n) for n in ['abandoned_depot','depot']]}
    (ROOT/'validation.json').write_text(json.dumps(report,indent=2)+'\n')
    print(json.dumps(report,indent=2))
