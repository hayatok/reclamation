import bpy, math, random, json
from mathutils import Vector, Matrix
from pathlib import Path
P=str(Path(__file__).resolve().parent.parent)
bpy.context.scene.render.fps=30
bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
mat=bpy.data.materials.new('Infected_Atlas');mat.use_nodes=True;n=mat.node_tree;bs=n.nodes.get('Principled BSDF');bs.inputs['Roughness'].default_value=.9
tex=n.nodes.new('ShaderNodeTexImage');tex.image=bpy.data.images.load(P+'/assets/infected_atlas.png');n.links.new(tex.outputs['Color'],bs.inputs['Base Color'])
parts=[]
def done(o,name,tile,bone):
 o.name=name;bpy.context.view_layer.objects.active=o;bpy.ops.object.transform_apply(location=False,rotation=False,scale=True);o.data.materials.append(mat)
 uv=o.data.uv_layers.active or o.data.uv_layers.new(name='UVMap')
 for poly in o.data.polygons:
  axis=max(range(3),key=lambda i:abs(poly.normal[i]));axes=[i for i in range(3) if i!=axis];vals=[o.data.vertices[o.data.loops[j].vertex_index].co for j in poly.loop_indices]
  lo=[min(v[k] for v in vals) for k in axes];hi=[max(v[k] for v in vals) for k in axes]
  for j,v in zip(poly.loop_indices,vals):
   q=[(v[k]-a)/max(b-a,.0001) for k,a,b in zip(axes,lo,hi)]
   uv.data[j].uv=((tile%4+.06+q[0]*.88)/4,(3-tile//4+.06+q[1]*.88)/4)
 vg=o.vertex_groups.new(name=bone);vg.add(list(range(len(o.data.vertices))),1,'REPLACE');parts.append(o);return o
def ell(name,loc,scale,tile,bone):
 bpy.ops.mesh.primitive_uv_sphere_add(segments=10,ring_count=6,radius=1,location=loc);o=bpy.context.object;o.scale=scale;return done(o,name,tile,bone)
def taper(name,a,b,r1,r2,tile,bone,verts=8):
 a=Vector(a);b=Vector(b);bpy.ops.mesh.primitive_cone_add(vertices=verts,radius1=r1,radius2=r2,depth=(b-a).length,location=(a+b)/2);o=bpy.context.object;o.rotation_euler=(b-a).to_track_quat('Z','Y').to_euler();return done(o,name,tile,bone)
def plate(name,verts,faces,tile,bone):
 m=bpy.data.meshes.new(name);m.from_pydata(verts,[],faces);m.update();o=bpy.data.objects.new(name,m);bpy.context.collection.objects.link(o);return done(o,name,tile,bone)
# Blender front -Y, 1.65m intact height. Stooped animated pose reduces height.
hip=(0,0,.88);chest=(0,-.07,1.27);neck=(0,-.11,1.43);head=(0,-.16,1.57)
# clothes have a human shoulder/waist silhouette, uneven torn hems.
ell('Hunched worn workshirt',(0,-.025,1.13),(.225,.125,.30),10,'spine')
ell('Slumped upper shoulders',(0,-.07,1.30),(.245,.12,.105),10,'chest')
ell('Exposed abdomen between torn shirt and belt',(0,-.005,1.00),(.175,.115,.19),1,'spine')
ell('Pelvis worn trousers',(0,.0,.87),(.20,.135,.15),4,'hips')
taper('Exposed narrow neck',neck,head,.065,.075,0,'neck')
ell('Gaunt skull',(0,-.17,1.585),(.115,.095,.145),0,'head')
ell('Heavy brow',(.0,-.257,1.63),(.105,.029,.037),1,'head')
ell('Angular protruding jaw',(.004,-.218,1.49),(.078,.070,.050),1,'head')
ell('Open dead mouth',(0,-.281,1.505),(.055,.011,.031),5,'head')
for x in [-.047,.047]:
 ell('Sunken eye socket',(x,-.259,1.592),(.035,.023,.028),5,'head')
 ell('Clouded eye',(x,-.277,1.592),(.007,.006,.008),2,'head')
 ell('Protruding cheek',(x*1.3,-.25,1.55),(.042,.026,.038),2,'head')
taper('Nose bridge',(.0,-.25,1.60),(.0,-.287,1.548),.018,.025,1,'head',6)
ell('Scalp wound',(.071,-.184,1.68),(.045,.057,.018),6,'head')
# shredded cloth lower edge and exposed abdomen patches
for x in [-.18,-.09,.02,.10,.19]:
 plate('Ragged shirt hem',[(x-.045,-.141,.97),(x+.045,-.141,.97),(x+.01,-.144,.875+(x+.2)*.15)],[(0,1,2)],10,'spine')
ell('Torn shirt exposed flank',(.196,-.061,1.06),(.035,.098,.09),0,'spine')
# Limbs with elbows, knuckles and asymmetric clothing tears.
B={}
for side,sign in [('L',1),('R',-1)]:
 shoulder=(sign*.245,-.06,1.30);elbow=(sign*.355,-.07,1.06);wrist=(sign*.405,-.105,.825);fing=(sign*.412,-.15,.72)
 thigh=(sign*.12,0,.85);knee=(sign*.135,-.015,.49);ankle=(sign*.14,.015,.12)
 B.update({f'upper_arm.{side}':(shoulder,elbow,'chest'),f'forearm.{side}':(elbow,wrist,f'upper_arm.{side}'),f'hand.{side}':(wrist,fing,f'forearm.{side}'),f'thigh.{side}':(thigh,knee,'hips'),f'shin.{side}':(knee,ankle,f'thigh.{side}'),f'foot.{side}':(ankle,(sign*.14,-.16,.055),f'shin.{side}')})
 ell('Ragged sleeve '+side,shoulder,(.079,.080,.110),10,f'upper_arm.{side}')
 taper('Upper arm '+side,shoulder,elbow,.074,.055,0 if side=='R' else 10,f'upper_arm.{side}')
 ell('Bony elbow '+side,elbow,(.062,.060,.064),1,f'forearm.{side}')
 taper('Skin forearm '+side,elbow,wrist,.058,.039,0,f'forearm.{side}')
 ell('Long hand '+side,wrist,(.055,.034,.09),0,f'hand.{side}')
 for k in range(4):
  xx=sign*.405+(k-1.5)*.023
  taper('Separated curled finger',(xx,-.12,.80),(xx,-.17,.711+(k%3)*.011),.010,.008,1,f'hand.{side}',5)
 taper('Thumb',(sign*.36,-.12,.81),(sign*.35,-.16,.75),.014,.009,0,f'hand.{side}',5)
 taper('Worn trouser thigh '+side,thigh,knee,.12,.082,4,f'thigh.{side}')
 ell('Knee '+side,knee,(.088,.083,.08),0 if side=='L' else 9,f'shin.{side}')
 taper('Lower trouser '+side,(sign*.135,-.005,.44),ankle,.075,.055,9,f'shin.{side}')
 ell('Broken work shoe '+side,(sign*.14,-.065,.072),(.085,.155,.07),5,f'foot.{side}')
 # torn knee flap and rust-blood smears kept dull, never neon
 if side=='L':ell('Knee bruise',(sign*.135,-.090,.505),(.045,.016,.039),6,f'shin.{side}')
 ell('Forearm bruise',(sign*.37,-.11,.995),(.042,.015,.049),6,f'forearm.{side}')
# Join weighted parts, one shared material surface.
bpy.ops.object.select_all(action='DESELECT')
for o in parts:o.select_set(True)
bpy.context.view_layer.objects.active=parts[0];bpy.ops.object.join();mesh=bpy.context.object;mesh.name='Infected_Civilian_Skinned';bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
tri=mesh.modifiers.new('Triangulation','TRIANGULATE');bpy.ops.object.modifier_apply(modifier=tri.name)
# Armature is real hierarchical skeleton, animation is in local bone rotations.
arm=bpy.data.armatures.new('Infected_Rig');rig=bpy.data.objects.new('Infected_Rig',arm);bpy.context.collection.objects.link(rig);bpy.context.view_layer.objects.active=rig;rig.select_set(True);mesh.select_set(False);bpy.ops.object.mode_set(mode='EDIT')
B={'root':((0,0,0),(0,0,.2),None),'hips':(hip,(0,0,1.03),'root'),'spine':((0,0,1.03),chest,'hips'),'chest':(chest,neck,'spine'),'neck':(neck,head,'chest'),'head':(head,(0,-.16,1.73),'neck'),**B}
for name,(a,b,parent) in B.items():
 bone=arm.edit_bones.new(name);bone.head=a;bone.tail=b
 if parent:bone.parent=arm.edit_bones[parent]
bpy.ops.object.mode_set(mode='OBJECT');mod=mesh.modifiers.new('Infected skeletal deformation','ARMATURE');mod.object=rig;mesh.parent=rig
for bone in rig.pose.bones:bone.rotation_mode='XYZ'
# Full clips with deliberate unequal timing and dragging foot.
def pose(t,kind):
 for b in rig.pose.bones:b.rotation_euler=(0,0,0);b.location=(0,0,0)
 def r(name,x=0,y=0,z=0):rig.pose.bones[name].rotation_euler=(x,y,z)
 r('spine',.22,0,.06);r('chest',.10,0,-.05);r('neck',-.05,.08,0);r('head',.10,-.11,.08)
 r('upper_arm.L',-.30,0,-.13);r('upper_arm.R',-.09,0,.15);r('forearm.L',-.13);r('forearm.R',-.05)
 if kind in ['walk','idle']:
  s=math.sin(t*math.tau);c=math.cos(t*math.tau)
  if kind=='walk':
   r('thigh.L',s*.30);r('thigh.R',-s*.23);r('shin.L',max(0,-s)*.38);r('shin.R',max(0,s)*.17);r('foot.R',.13+max(0,-s)*.15)
   r('upper_arm.L',-.28-s*.13,0,-.16);r('upper_arm.R',-.08+s*.20,0,.11);r('spine',.25+abs(s)*.04,0,c*.065);r('head',.13+c*.05,-.1,.09)
   rig.pose.bones['hips'].location.y=abs(s)*.023
  else:r('spine',.25+s*.018,0,.05);r('head',.13+s*.025,-.1,.09)
 elif kind=='attack':
  reach=math.sin(t*math.pi);swipe=math.sin(t*math.pi*2)
  r('spine',.28+reach*.29,0,-swipe*.12);r('upper_arm.L',-.25-reach*1.85,0,-.16+swipe*.25);r('upper_arm.R',-.20-reach*1.60,0,.20-swipe*.2);r('forearm.L',-.3-reach*.24);r('forearm.R',-.1-reach*.32);r('head',-.05)
 elif kind=='death':
  r('root',t*1.35,0,t*.19);rig.pose.bones['root'].location.y=-t*.31
  r('spine',.3+t*.24);r('thigh.L',t*.62);r('thigh.R',t*.3);r('shin.L',-t*.45);r('upper_arm.L',-.3-t*.7,0,-t*.35);r('upper_arm.R',-.1-t*.45,0,t*.3);r('head',t*.35,-.1,0)
 bpy.context.view_layer.update()
 if kind=='attack':
  # Reach in armature coordinates so anatomical bone rolls cannot cross both wrists over the chest.
  amount=math.sin(t*math.pi)
  for side,sign in [('L',1),('R',-1)]:
   for bone_name,target in [(f'upper_arm.{side}',Vector((sign*.28,-.46,1.20))),(f'forearm.{side}',Vector((sign*.27,-.72,1.18)))]:
    pb=rig.pose.bones[bone_name];headpos=pb.head.copy();q=pb.matrix.to_quaternion();desired=(target-headpos).normalized().to_track_quat('Y','Z');pb.matrix=Matrix.Translation(headpos)@q.slerp(desired,amount).to_matrix().to_4x4();bpy.context.view_layer.update()
 # Bone-local Y is vertical for root: preserve planted ground contact without planar root motion.
 ev=mesh.evaluated_get(bpy.context.evaluated_depsgraph_get());lowest=min(v.co.z for v in ev.data.vertices);rig.pose.bones['root'].location.y-=lowest;bpy.context.view_layer.update()
clips={'idle':(48,2),'walk':(36,12),'attack':(24,8),'death':(36,10)}
rig.animation_data_create()
for name,(length,count) in clips.items():
 act=bpy.data.actions.new(name);rig.animation_data.action=act
 for frame in range(0,length+1):
  pose(frame/length,name)
  for b in rig.pose.bones:
   b.keyframe_insert('rotation_euler',frame=frame);b.keyframe_insert('location',frame=frame)
 track=rig.animation_data.nla_tracks.new();track.name=name;track.strips.new(name,0,act)
rig.animation_data.action=None
for t in rig.animation_data.nla_tracks:t.mute=True
pose(0,'idle');rig.rotation_euler.z=math.pi;bpy.ops.file.pack_all();bpy.ops.wm.save_as_mainfile(filepath=P+'/source/infected_civilian.blend')
# Export clips one action per named NLA track.
for t in rig.animation_data.nla_tracks:t.mute=False
bpy.ops.object.select_all(action='DESELECT');rig.select_set(True);mesh.select_set(True);bpy.context.view_layer.objects.active=rig
bpy.ops.export_scene.gltf(filepath=P+'/assets/infected_animated.glb',export_format='GLB',use_selection=True,export_animations=True,export_animation_mode='NLA_TRACKS',export_skins=True)
for t in rig.animation_data.nla_tracks:t.mute=True
rig.animation_data.action=None
# Bake evaluated geometry, shared PBR surface and root-local coordinates, zero runtime bones.
baked=[];manifest={}
for name,(length,count) in clips.items():
 manifest[name]={'duration':length/30,'loop':name in ['idle','walk'],'poses':[]}
 for i in range(count):
  t=(i*.5+.25) if name=='idle' else (i/count if name=='walk' else i/(count-1))
  pose(t,name);deps=bpy.context.evaluated_depsgraph_get();ev=mesh.evaluated_get(deps);me=bpy.data.meshes.new_from_object(ev,preserve_all_data_layers=True,depsgraph=deps);me.transform(Matrix.Rotation(math.pi,4,'Z'));lowest=min(v.co.z for v in me.vertices);me.transform(Matrix.Translation((0,0,-lowest)));o=bpy.data.objects.new(f'{name}_{i:02}',me);bpy.context.collection.objects.link(o);baked.append(o);manifest[name]['poses'].append(o.name)
bpy.ops.object.select_all(action='DESELECT')
for o in baked:o.select_set(True)
bpy.context.view_layer.objects.active=baked[0]
bpy.ops.export_scene.gltf(filepath=P+'/assets/infected_baked_poses.glb',export_format='GLB',use_selection=True,export_animations=False,export_skins=False)
# Far LOD preserves full mesh poses but reduces small anatomy below gameplay pixel scale.
for o in baked:
 bpy.context.view_layer.objects.active=o;d=o.modifiers.new('Distant crowd budget','DECIMATE');d.ratio=.16;bpy.ops.object.modifier_apply(modifier=d.name);lowest=min(v.co.z for v in o.data.vertices);o.data.transform(Matrix.Translation((0,0,-lowest)))
bpy.ops.export_scene.gltf(filepath=P+'/assets/infected_baked_poses_far.glb',export_format='GLB',use_selection=True,export_animations=False,export_skins=False)
json.dump({'far_triangles_per_pose':[len(o.data.polygons) for o in baked],'forward':'Godot -Z','units':'meters','fps':30,'clips':manifest,'triangles_per_pose':len(mesh.data.polygons),'bones':len(B),'pose_count':len(baked),'batch_contract':'Extract Mesh resources by node name. Never add pose container to scene; instance via MultiMesh per current pose.'},open(P+'/infected_manifest.json','w'),indent=2)
print('INFECTED_BUILD_OK',len(mesh.data.polygons),len(baked),len(B))
