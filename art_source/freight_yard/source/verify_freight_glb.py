"""Independent standard-library validation of the actual exported freight GLBs."""
from pathlib import Path
import json, struct, hashlib, math

ROOT=Path(__file__).resolve().parents[1]
EXPECTED={
    'ruined_freight_teal':(1200,(-3,0,-1.25),(3,1.3,1.25)),
    'ruined_freight_oxide':(1200,(-3,0,-1.25),(3,1.3,1.25)),
    'freight_transfer_gantry':(4000,(-2.1,0,-1.75),(2.1,3.4,1.75)),
}

def glb(path):
    data=path.read_bytes();magic,version,length=struct.unpack_from('<III',data)
    assert (magic,version,length)==(0x46546C67,2,len(data)),path
    jl,jt=struct.unpack_from('<II',data,12);assert jt==0x4E4F534A
    doc=json.loads(data[20:20+jl]);offset=20+jl
    bl,bt=struct.unpack_from('<II',data,offset);assert bt==0x004E4942
    return doc,data[offset+8:offset+8+bl]

def accessor(doc,binary,index):
    a=doc['accessors'][index];v=doc['bufferViews'][a['bufferView']]
    sizes={'SCALAR':1,'VEC2':2,'VEC3':3,'VEC4':4}
    fmt={5126:'f',5125:'I',5123:'H',5121:'B'}[a['componentType']]
    width=sizes[a['type']];element=struct.calcsize('<'+fmt*width)
    start=v.get('byteOffset',0)+a.get('byteOffset',0);stride=v.get('byteStride',element)
    return [struct.unpack_from('<'+fmt*width,binary,start+i*stride) for i in range(a['count'])]

def main():
    reports={}
    for name,(budget,bmin,bmax) in EXPECTED.items():
        path=ROOT/'assets'/(name+'.glb');doc,binary=glb(path)
        assert len(doc['meshes'])==1 and len(doc['meshes'][0]['primitives'])==1,name
        assert len(doc['materials'])==1,name
        assert not doc.get('skins') and not doc.get('animations'),name
        assert 'KHR_lights_punctual' not in doc.get('extensions',{}),name
        assert len(doc['nodes'])==1,name
        node=doc['nodes'][0]
        assert all(abs(v)<1e-7 for v in node.get('translation',[0,0,0])),node
        assert node.get('rotation',[0,0,0,1])==[0,0,0,1],node
        assert node.get('scale',[1,1,1])==[1,1,1],node
        assert 'matrix' not in node,node
        primitive=doc['meshes'][0]['primitives'][0]
        assert primitive.get('mode',4)==4 and primitive['material']==0,name
        points=accessor(doc,binary,primitive['attributes']['POSITION'])
        indices=accessor(doc,binary,primitive['indices'])
        uv=accessor(doc,binary,primitive['attributes']['TEXCOORD_0'])
        assert len(indices)%3==0
        triangles=len(indices)//3;assert triangles<=budget,(name,triangles)
        assert triangles>=800 if 'ruined' in name else triangles>=2500,(name,triangles)
        assert all(math.isfinite(x) for p in points for x in p),name
        lo=[min(p[k] for p in points) for k in range(3)]
        hi=[max(p[k] for p in points) for k in range(3)]
        assert all(lo[k]>=bmin[k]-.0001 and hi[k]<=bmax[k]+.0001 for k in range(3)),(name,lo,hi)
        assert abs(lo[1])<1e-5,(name,lo)
        assert all(0<=q<=1 for p in uv for q in p),name
        # Both sides of thin folded sheet use the same opaque PBR surface.
        material=doc['materials'][0]
        assert material.get('alphaMode','OPAQUE')=='OPAQUE',material
        assert material.get('doubleSided') is True,material
        assert len(doc['images'])==2 and all('uri' in im and 'bufferView' not in im for im in doc['images']),name
        textures=sorted(im['uri'] for im in doc['images'])
        assert textures==['freight_yard_albedo.png','freight_yard_orm.png'],textures
        for filename in textures:
            assert (ROOT/'assets'/filename).is_file(),filename
        assert all(s.get('minFilter')==9987 for s in doc['samplers']),name
        reports[name]={'passed':True,'triangles':triangles,'mesh_count':1,'surface_count':1,'material_count':1,
            'godot_aabb_min':lo,'godot_aabb_max':hi,'texture_uris':textures,'mipmapped_minification':True,
            'bytes':path.stat().st_size,'sha256':hashlib.sha256(path.read_bytes()).hexdigest()}
    for ext in ('png','glb'):
        for path in (ROOT/'assets').glob('*.'+ext):
            assert path.stat().st_size<1024*1024,path
    (ROOT/'reports/validation_report.json').write_text(json.dumps(reports,indent=2)+'\n')
    print(json.dumps(reports,indent=2))

if __name__=='__main__':main()
