"""Structural checks for the authored power facility GLBs; no engine required."""
import json, struct, math, hashlib
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
RUNTIME=ROOT.parents[1]/'assets/models'
WIDTH={5126:4,5125:4,5123:2,5121:1}
FMT={5126:'f',5125:'I',5123:'H',5121:'B'}
NCOMP={'SCALAR':1,'VEC2':2,'VEC3':3,'VEC4':4}

def read(file):
    data=file.read_bytes();magic,version,size=struct.unpack_from('<III',data,0)
    assert magic==0x46546C67 and version==2 and size==len(data)
    jl,jt=struct.unpack_from('<II',data,12);doc=json.loads(data[20:20+jl])
    off=20+jl;bl,bt=struct.unpack_from('<II',data,off)
    return doc,data[off+8:off+8+bl]

def values(doc, binary, index):
    a=doc['accessors'][index];v=doc['bufferViews'][a['bufferView']]
    count=NCOMP[a['type']];fmt='<'+FMT[a['componentType']]*count
    width=count*WIDTH[a['componentType']];stride=v.get('byteStride',width)
    off=v.get('byteOffset',0)+a.get('byteOffset',0)
    return [struct.unpack_from(fmt,binary,off+i*stride) for i in range(a['count'])]

def verify(name):
    file=RUNTIME/(name+'.glb'); doc,binary=read(file)
    assert len(doc['meshes'])==1 and len(doc['meshes'][0]['primitives'])==1
    assert len(doc['materials'])==1 and len(doc['images'])==3
    assert not doc.get('animations') and not doc.get('skins') and not doc.get('cameras')
    assert 'KHR_lights_punctual' not in doc.get('extensionsUsed',[])
    assert all('uri' in im and 'bufferView' not in im for im in doc['images'])
    assert all((RUNTIME/im['uri']).is_file() for im in doc['images'])
    assert not any('data:' in im['uri'] or '..' in im['uri'] for im in doc['images'])
    mat=doc['materials'][0]
    assert mat.get('alphaMode','OPAQUE')=='OPAQUE' and not mat.get('doubleSided',False)
    p=doc['meshes'][0]['primitives'][0]; attrs=p['attributes']
    assert all(a in attrs for a in ('POSITION','NORMAL','TEXCOORD_0'))
    pos=values(doc,binary,attrs['POSITION']);norm=values(doc,binary,attrs['NORMAL']);uv=values(doc,binary,attrs['TEXCOORD_0'])
    assert len(pos)==len(norm)==len(uv)
    assert all(math.isfinite(x) for arr in (pos,norm,uv) for v in arr for x in v)
    assert all(abs(sum(x*x for x in n)-1)<.02 for n in norm)
    assert all(0<=x<=1 for v in uv for x in v)
    idx=values(doc,binary,p['indices']);triangles=len(idx)//3
    assert triangles<=4000 and len(idx)%3==0
    assert all(v[0]<len(pos) for v in idx)
    radius=max(math.hypot(v[0],v[2]) for v in pos)
    assert radius<3 and min(v[1] for v in pos)>=-.0001 and max(v[1] for v in pos)<4
    area=0;zero=0
    for i in range(0,len(idx),3):
        a,b,c=[pos[idx[i+j][0]] for j in range(3)]
        u=[b[j]-a[j] for j in range(3)];v=[c[j]-a[j] for j in range(3)]
        cross=[u[1]*v[2]-u[2]*v[1],u[2]*v[0]-u[0]*v[2],u[0]*v[1]-u[1]*v[0]]
        ar=sum(x*x for x in cross)**.5/2
        area+=ar;zero+=ar<1e-10
    assert zero==0,(name,zero)
    report={'asset':name,'triangles':triangles,'vertices':len(pos),'surface_count':1,'materials':1,'uvs':'all present and in range','normals':'all unit length','degenerate_triangles':zero,'ground_radius':round(radius,4),'external_images':[im['uri'] for im in doc['images']],'file_bytes':file.stat().st_size,'sha256':hashlib.sha256(file.read_bytes()).hexdigest()}
    return report

if __name__=='__main__':
    result=[verify(n) for n in ('central_station','substation')]
    print(json.dumps(result,indent=2))
    (ROOT/'reports/glb_verification.json').write_text(json.dumps(result,indent=2)+'\n')
