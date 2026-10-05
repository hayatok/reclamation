"""Strict structural contract checks directly on the self-contained GLB bytes."""
import json,struct,pathlib,math,hashlib
ROOT=pathlib.Path(__file__).resolve().parents[1]
for folder in ('assets', 'reports', 'previews', 'source'):
    (ROOT/folder).mkdir(parents=True, exist_ok=True)
def inspect(path):
    raw=path.read_bytes();magic,version,size=struct.unpack_from('<4sII',raw);assert magic==b'glTF' and version==2 and size==len(raw)
    offset=12;j=None;blob=None
    while offset<len(raw):
        length,typ=struct.unpack_from('<II',raw,offset);payload=raw[offset+8:offset+8+length];offset+=8+length
        if typ==0x4E4F534A:j=json.loads(payload)
        elif typ==0x004E4942:blob=payload
    assert j is not None and blob is not None
    assert all('uri' not in x for x in j.get('buffers',[])), 'External binary dependency'
    assert all('bufferView' in x and 'uri' not in x for x in j.get('images',[])), 'External image dependency'
    assert len(j['meshes'])==len(j['materials'])==1
    assert len(j['meshes'][0]['primitives'])==1
    assert not j.get('skins') and not j.get('animations')
    p=j['meshes'][0]['primitives'][0];assert p.get('mode',4)==4
    a=j['accessors'][p['indices']];tris=a['count']//3
    assert tris<=10000
    counts={5120:1,5121:1,5122:2,5123:2,5125:4,5126:4};fmts={5120:'b',5121:'B',5122:'h',5123:'H',5125:'I',5126:'f'};arity={'SCALAR':1,'VEC2':2,'VEC3':3,'VEC4':4}
    def accessor(index):
        ac=j['accessors'][index];view=j['bufferViews'][ac['bufferView']];n=arity[ac['type']];step=view.get('byteStride',counts[ac['componentType']]*n);start=view.get('byteOffset',0)+ac.get('byteOffset',0)
        return [struct.unpack_from('<'+fmts[ac['componentType']]*n,blob,start+k*step) for k in range(ac['count'])]
    pos=accessor(p['attributes']['POSITION']);uv=accessor(p['attributes']['TEXCOORD_0']);norm=accessor(p['attributes']['NORMAL'])
    assert all(math.isfinite(c) for v in pos+uv+norm for c in v)
    assert all(-.0001<=c<=1.0001 for v in uv for c in v)
    assert sum(1 for u,v in uv if u==0 and v==0)==0, 'Unmapped primitive vertices'
    assert all(.90<=sum(c*c for c in v)<=1.10 for v in norm)
    mi=[min(v[k] for v in pos) for k in range(3)];ma=[max(v[k] for v in pos) for k in range(3)]
    assert mi[0]>=-2.25 and ma[0]<=2.25 and mi[2]>=-2.25 and ma[2]<=2.25
    assert abs(mi[1])<=.01
    m=j['materials'][0];assert 'baseColorTexture' in m['pbrMetallicRoughness'] and 'metallicRoughnessTexture' in m['pbrMetallicRoughness'] and 'normalTexture' in m
    return {'file':path.name,'bytes':len(raw),'sha256':hashlib.sha256(raw).hexdigest(),'triangles':tris,'vertices':len(pos),'materials':1,'surfaces':1,'embedded_images':len(j['images']),'bounds_min':mi,'bounds_max':ma,'zero_uv_vertices':0}
reports=[inspect(ROOT/'assets'/f'{name}.glb') for name in ['water_station','water_station_lod1']]
(ROOT/'reports'/'glb_validation.json').write_text(json.dumps(reports,indent=2)+'\n')
print(json.dumps(reports,indent=2))
