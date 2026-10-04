"""Independent GLB JSON/embedded image contract check, no third-party dependencies."""
from pathlib import Path
import json,struct,hashlib
P=Path(__file__).resolve().parent.parent
out=[]
for path in sorted((P/'assets').glob('*.glb')):
 b=path.read_bytes();magic,version,size=struct.unpack_from('<4sII',b);assert magic==b'glTF' and version==2 and size==len(b)
 n,t=struct.unpack_from('<II',b,12);j=json.loads(b[20:20+n]);binstart=20+n+8;raw=b[binstart:]
 assert len(j['meshes'])==1 and len(j['meshes'][0]['primitives'])==1 and len(j['materials'])==1
 prim=j['meshes'][0]['primitives'][0];attrs=prim['attributes'];assert {'POSITION','NORMAL','TANGENT','TEXCOORD_0'}<=attrs.keys()
 tri=j['accessors'][prim['indices']]['count']//3;mat=j['materials'][0]
 assert mat.get('alphaMode','OPAQUE')=='OPAQUE' and 'baseColorTexture' in mat['pbrMetallicRoughness'] and 'metallicRoughnessTexture' in mat['pbrMetallicRoughness'] and 'normalTexture' in mat
 images=[]
 for im in j['images']:
  view=j['bufferViews'][im['bufferView']];ib=raw[view.get('byteOffset',0):view.get('byteOffset',0)+view['byteLength']];images.append({'name':im.get('name'), 'sha256':hashlib.sha256(ib).hexdigest()})
 out.append({'file':path.name,'bytes':len(b),'sha256':hashlib.sha256(b).hexdigest(),'triangles':tri,'meshes':1,'surfaces':1,'textures_embedded':images,'opaque':True})
json.dump({'pass':True,'assets':out},open(P/'reports'/'glb_contract.json','w'),indent=2)
print('GLB_BINARY_CONTRACT_PASS',[(a['file'],a['triangles']) for a in out])
