"""Read-only GLB contract verification without launching Blender or Godot."""
import hashlib,json,struct
from pathlib import Path
import numpy as np
ROOT=Path(__file__).resolve().parent.parent
m=json.loads((ROOT/'armored_manifest.json').read_text())
report={'status':'pass','lods':{}}

def glb(path):
 data=path.read_bytes();magic,version,size=struct.unpack_from('<III',data)
 assert magic==0x46546c67 and version==2 and size==len(data)
 at=12;parts={}
 while at<len(data):
  length,kind=struct.unpack_from('<II',data,at);at+=8
  parts[kind]=data[at:at+length];at+=length
 return json.loads(parts[0x4e4f534a]),parts[0x004e4942]

def array(g,blob,index):
 a=g['accessors'][index];v=g['bufferViews'][a['bufferView']]
 dtypes={5126:'<f4',5125:'<u4',5123:'<u2',5121:'u1'}
 components={'SCALAR':1,'VEC2':2,'VEC3':3,'VEC4':4}
 n=components[a['type']];dtype=np.dtype(dtypes[a['componentType']])
 start=v.get('byteOffset',0)+a.get('byteOffset',0)
 return np.ndarray((a['count'],n),dtype=dtype,buffer=blob,offset=start,strides=(v.get('byteStride',dtype.itemsize*n),dtype.itemsize)).copy()

for lod,entry in m['lods'].items():
 path=ROOT/entry['file'];g,blob=glb(path)
 assert hashlib.sha256(path.read_bytes()).hexdigest()==entry['sha256']
 assert not g.get('skins') and not g.get('animations')
 assert len(g['materials'])==1 and len(g['images'])==1
 nodes={n['name']:n for n in g['nodes'] if 'mesh' in n}
 assert len(nodes)==m['pose_count']
 count=entry['expected_imported_vertices_per_pose'];side=entry['uv2_grid_side'];shapes={};lows=[]
 for clip,info in m['clips'].items():
  for name in info['poses']:
   node=nodes[name]
   assert all(node.get(key,default)==default for key,default in [('translation',[0,0,0]),('rotation',[0,0,0,1]),('scale',[1,1,1])]),name
   primitives=g['meshes'][node['mesh']]['primitives'];assert len(primitives)==1
   p=primitives[0];assert p.get('mode',4)==4
   a=p['attributes'];assert set(a)=={'POSITION','NORMAL','TEXCOORD_0','TEXCOORD_1'},(name,a)
   pos=array(g,blob,a['POSITION']);uv2=array(g,blob,a['TEXCOORD_1']);normal=array(g,blob,a['NORMAL']);idx=array(g,blob,p['indices'])
   assert len(pos)==count and len(idx)==entry['triangles_per_pose']*3
   assert np.isfinite(pos).all() and np.isfinite(normal).all() and np.isfinite(uv2).all()
   cells=np.floor(uv2*side).astype(int);ids=cells[:,1]*side+cells[:,0]
   assert np.array_equal(np.sort(ids),np.arange(count)),name
   shapes[name]=pos[np.argsort(ids)];lows.append(float(pos[:,1].min()))
 assert min(lows)>-1e-5
 for name in ['walk_03','walk_06','walk_09']:
  assert float(np.linalg.norm(shapes[name]-shapes['walk_00'],axis=1).max())>.15
 # The same rest-to-pose solve must not retain a preceding death's root matrix.
 idle_height=float(shapes['idle_00'][:,1].max());assert 1.53<idle_height<1.65,(lod,idle_height)
 final_death_height=float(shapes['death_09'][:,1].max())
 assert final_death_height<.45,(lod,final_death_height)
 report['lods'][lod]={'final_death_height_m':final_death_height,'poses':len(nodes),'triangles_per_pose':entry['triangles_per_pose'],'corners':count,'surfaces':1,'runtime_bones':0,'idle_height_m':idle_height,'min_ground_m':min(lows),'bytes':path.stat().st_size}
report['generator_current']=hashlib.sha256((ROOT/m['generator']).read_bytes()).hexdigest()==m['generator_sha256']
report['motion_current']=hashlib.sha256((ROOT/'source/heavy_gait.py').read_bytes()).hexdigest()==m['motion_sha256']
assert report['generator_current'] and report['motion_current']
(ROOT/'validation/glb_contract.json').write_text(json.dumps(report,indent=2)+'\n')
print(json.dumps(report,indent=2))
