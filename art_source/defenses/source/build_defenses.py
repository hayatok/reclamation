"""RECLAMATION v08 original hero defenses. Blender 4.3.2 authoring → glTF2.
Units metres. Blender +Y is the working face, exported as Godot -Z. Rebuildable.
"""
import bpy, bmesh, math, random, json, os
from mathutils import Vector
from pathlib import Path
ROOT=Path(__file__).resolve().parent.parent
random.seed(831)
objects=[]; stats={}

def reset():
 global objects,mat
 for existing in list(bpy.data.objects):bpy.data.objects.remove(existing,do_unlink=True)
 for c in list(bpy.data.collections):
  if c.name!='Collection' and c.users==0:bpy.data.collections.remove(c)
 objects=[]
 mat=bpy.data.materials.get('SALVAGE | shared original atlas')
 if not mat:
  mat=bpy.data.materials.new('SALVAGE | shared original atlas');mat.use_nodes=True
  n=mat.node_tree.nodes;link=mat.node_tree.links;bs=n.get('Principled BSDF')
  for file,col in [('salvage_albedo','sRGB'),('salvage_orm','Non-Color'),('salvage_normal','Non-Color')]:
   tx=n.new('ShaderNodeTexImage');tx.name=file;tx.label=file;tx.image=bpy.data.images.load(str(ROOT/'assets'/f'{file}.png'),check_existing=True);tx.image.colorspace_settings.name=col
  link.new(n['salvage_albedo'].outputs['Color'],bs.inputs['Base Color'])
  sp=n.new('ShaderNodeSeparateColor');link.new(n['salvage_orm'].outputs['Color'],sp.inputs[0]);link.new(sp.outputs['Green'],bs.inputs['Roughness']);link.new(sp.outputs['Blue'],bs.inputs['Metallic'])
  no=n.new('ShaderNodeNormalMap');no.inputs['Strength'].default_value=.4;link.new(n['salvage_normal'].outputs['Color'],no.inputs['Color']);link.new(no.outputs[0],bs.inputs['Normal'])
  bs.inputs['Roughness'].default_value=.85

def finish(o,name,tile=0,bevel=0,smooth=False):
 o.name=name;bpy.context.view_layer.objects.active=o;o.select_set(True)
 bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
 bm=bmesh.new();bm.from_mesh(o.data)
 bmesh.ops.remove_doubles(bm,verts=list(bm.verts),dist=.000001)
 bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bm.to_mesh(o.data);bm.free();o.data.update()
 if bevel:
  mod=o.modifiers.new('Authored softened edges','BEVEL');mod.width=bevel;mod.segments=1;mod.affect='EDGES';bpy.ops.object.modifier_apply(modifier=mod.name)
 o.data.materials.clear();o.data.materials.append(mat)
 if smooth:
  for f in o.data.polygons:f.use_smooth=True
 # Full atlas UV coverage: deliberately reuses material regions, rather than overlapping an unknown bake.
 uv=o.data.uv_layers.active or o.data.uv_layers.new(name='UVMap')
 mins=[min(v.co[k] for v in o.data.vertices) for k in range(3)];maxs=[max(v.co[k] for v in o.data.vertices) for k in range(3)]
 offset=random.random()*.10
 for f in o.data.polygons:
  axis=max(range(3),key=lambda k:abs(f.normal[k]));axes=[k for k in range(3) if k!=axis]
  d=max(maxs[k]-mins[k] for k in axes);d=max(d,.001)
  for li in f.loop_indices:
   v=o.data.vertices[o.data.loops[li].vertex_index].co
   q=[.06+offset+((v[k]-mins[k])/d)*.76 for k in axes]
   uv.data[li].uv=((tile%4+q[0])/4,(3-tile//4+q[1])/4)
 if bevel:
  mod=o.modifiers.new('Weighted face normals','WEIGHTED_NORMAL');mod.keep_sharp=True;mod.weight=30
  try:bpy.ops.object.modifier_apply(modifier=mod.name)
  except:pass
 objects.append(o);o.select_set(False);return o

def mesh(name,verts,faces,tile=0,bevel=0):
 m=bpy.data.meshes.new(name);m.from_pydata(verts,[],faces);m.update();o=bpy.data.objects.new(name,m);bpy.context.collection.objects.link(o);return finish(o,name,tile,bevel)
def box(name,loc,scale,tile=0,bevel=.012,rot=(0,0,0)):
 bpy.ops.mesh.primitive_cube_add(size=1,location=loc,rotation=rot);o=bpy.context.object;o.scale=scale;return finish(o,name,tile,bevel)
def cyl(name,loc,r,depth,tile=2,rot=(0,0,0),n=12,bevel=.009):
 bpy.ops.mesh.primitive_cylinder_add(vertices=n,radius=r,depth=depth,location=loc,rotation=rot);return finish(bpy.context.object,name,tile,bevel)
def beam(name,a,b,r=.025,tile=2,n=8):
 a,b=Vector(a),Vector(b);o=cyl(name,(a+b)/2,r,(b-a).length,tile,n=n,bevel=0);o.rotation_euler=(b-a).to_track_quat('Z','Y').to_euler();return o
def squarebeam(name,a,b,w=.09,d=.09,tile=1):
 a,b=Vector(a),Vector(b);o=box(name,(a+b)/2,(w,d,(b-a).length),tile,.006);o.rotation_euler=(b-a).to_track_quat('Z','Y').to_euler();return o

def profile_beam(name,a,b,w=.13,h=.15,t=.035,tile=1):
 # Structural I section, open flange silhouette rather than a solid box.
 p=[(-w/2,-h/2),(w/2,-h/2),(w/2,-h/2+t),(t/2,-h/2+t),(t/2,h/2-t),(w/2,h/2-t),(w/2,h/2),(-w/2,h/2),(-w/2,h/2-t),(-t/2,h/2-t),(-t/2,-h/2+t),(-w/2,-h/2+t)]
 a,b=Vector(a),Vector(b);q=(b-a).to_track_quat('Z','Y');v=[]
 for base in [a,b]:v += [tuple(base+q@Vector((x,y,0))) for x,y in p]
 L=len(p);f=[tuple(range(L-1,-1,-1)),tuple(range(L,L*2))]+[(i,(i+1)%L,(i+1)%L+L,i+L) for i in range(L)]
 return mesh(name,v,f,tile,.005)
def plate(name,outline,y,depth,tile=0,bevel=.012):
 # XZ silhouette extruded through Y. Used for armor, gable and machinery.
 L=len(outline);v=[(x,y-depth/2,z) for x,z in outline]+[(x,y+depth/2,z) for x,z in outline]
 f=[tuple(range(L-1,-1,-1)),tuple(range(L,L*2))]+[(i,(i+1)%L,(i+1)%L+L,i+L) for i in range(L)]
 return mesh(name,v,f,tile,bevel)
def tube(name,a,b,r=.075,wall=.022,tile=9,n=12):
 a,b=Vector(a),Vector(b);q=(b-a).to_track_quat('Z','Y');v=[]
 for base,rad in [(a,r),(b,r),(a,r-wall),(b,r-wall)]:
  v += [tuple(base+q@Vector((math.cos(i*2*math.pi/n)*rad,math.sin(i*2*math.pi/n)*rad,0))) for i in range(n)]
 f=[]
 for i in range(n):
  j=(i+1)%n;f += [(i,j,n+j,n+i),(2*n+i,3*n+i,3*n+j,2*n+j),(i,2*n+i,2*n+j,j),(n+i,n+j,3*n+j,3*n+i)]
 return mesh(name,v,f,tile)
def rope(name,pts,r=.014,tile=6):
 # Smooth sweeping cable with low section count.
 c=bpy.data.curves.new(name,'CURVE');c.dimensions='3D';c.resolution_u=4;c.bevel_depth=r;c.bevel_resolution=0;c.resolution_u=5
 s=c.splines.new('BEZIER');s.bezier_points.add(len(pts)-1)
 for p,co in zip(s.bezier_points,pts):p.co=co;p.handle_left_type='AUTO';p.handle_right_type='AUTO'
 o=bpy.data.objects.new(name,c);bpy.context.collection.objects.link(o);bpy.context.view_layer.objects.active=o;o.select_set(True);bpy.ops.object.convert(target='MESH');return finish(bpy.context.object,name,tile)
def bag(name,loc,scale,rot=0):
 # Faceted rounded pillow with pinched ends, not cuboid sandbags.
 verts=[];faces=[];N=12;M=6
 for j in range(M+1):
  theta=math.pi*j/M
  for i in range(N):
   phi=2*math.pi*i/N
   x=math.cos(theta)*.5;rr=math.sin(theta)**.60
   y=math.cos(phi)*.5*rr;z=math.sin(phi)*.5*rr
   verts.append((x*scale[0],y*scale[1],z*scale[2]))
 for j in range(M):
  for i in range(N):faces.append((j*N+i,j*N+(i+1)%N,(j+1)*N+(i+1)%N,(j+1)*N+i))
 o=mesh(name,verts,faces,4);o.location=loc;o.rotation_euler.z=rot;return o
def bolt(name,loc,axis='Y',r=.027):
 return cyl(name,loc,r,.028,2,rot=(math.pi/2,0,0) if axis=='Y' else (0,math.pi/2,0) if axis=='X' else (0,0,0),n=6,bevel=0)
def barrel(name,loc,r=.23,h=.58,tile=1):
 x,y,z=loc;cyl(name,loc,r,h,tile,n=14,bevel=.015)
 for zz in [z-h*.32,z+h*.32]:cyl(name+' | retaining hoop',(x,y,zz),r+.011,.035,2,n=14,bevel=0)
 cyl(name+' | bung',(x+r*.35,y,z+h*.51),.036,.018,9,n=8,bevel=0)
def crate(name,loc,scale=(.5,.45,.45)):
 box(name,loc,scale,3,.02);x,y,z=loc;w,d,h=scale
 for xx in [-w*.35,w*.35]:
  box(name+' | band',(x+xx,y+d*.508,z),(.04,.021,h*.92),2,.002)
  box(name+' | top band',(x+xx,y,z+h*.505),(.04,d,.018),2,.002)
def stencil(text,loc,size=.15):
 bpy.ops.object.text_add(location=loc,rotation=(math.pi/2,0,math.pi));o=bpy.context.object;o.data.body=text;o.data.align_x='CENTER';o.data.size=size;o.data.extrude=.0007;o.data.resolution_u=1;bpy.ops.object.convert(target='MESH');return finish(bpy.context.object,'Hand-stenciled '+text,8)

def export_asset(name):
 # Preserve authored objects in a separate disabled collection, and join copies for one draw surface.
 src=bpy.data.collections.new('AUTHORING | reveal to edit components');bpy.context.scene.collection.children.link(src)
 copies=[]
 for o in objects:
  for c in list(o.users_collection):c.objects.unlink(o)
  src.objects.link(o)
  cp=o.copy();cp.data=o.data.copy();bpy.context.scene.collection.objects.link(cp);copies.append(cp)
 src.hide_viewport=True;src.hide_render=True
 bpy.ops.object.select_all(action='DESELECT')
 for cp in copies:cp.select_set(True)
 bpy.context.view_layer.objects.active=copies[0];bpy.ops.object.join();hero=bpy.context.object;hero.name=name+'_LOD0'
 bpy.context.scene.cursor.location=(0,0,0);bpy.ops.object.origin_set(type='ORIGIN_CURSOR');bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
 tri=hero.modifiers.new('Export triangulation','TRIANGULATE');bpy.ops.object.modifier_apply(modifier=tri.name)
 bpy.context.view_layer.update()
 verts=[hero.matrix_world@v.co for v in hero.data.vertices];mn=[min(v[k] for v in verts) for k in range(3)];mx=[max(v[k] for v in verts) for k in range(3)]
 # Godot coordinate mapping (x,z,-y).
 gmin=[mn[0],mn[2],-mx[1]];gmax=[mx[0],mx[2],-mn[1]]
 stats[name]={'triangles':len(hero.data.polygons),'vertices':len(hero.data.vertices),'authored_components':len(objects),'surfaces':1,'material':'SALVAGE | shared original atlas','godot_bounds_min':gmin,'godot_bounds_max':gmax,'godot_size':[gmax[k]-gmin[k] for k in range(3)],'uv_loops':len(hero.data.uv_layers.active.data),'atlas_size':2048}
 bpy.context.preferences.filepaths.save_version=0
 bpy.ops.file.pack_all();bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'source'/f'{name}.blend'))
 bpy.ops.export_scene.gltf(filepath=str(ROOT/'assets'/f'{name}.glb'),export_format='GLB',use_selection=True,export_texcoords=True,export_normals=True,export_materials='EXPORT',export_yup=True,export_tangents=True)
 print('BUILT',name,stats[name])

def build_tower():
 reset()
 # Uneven chamfered salvage foundation and load-bearing feet.
 outline=[(-1.12,-.91),(-.89,-1.09),(.83,-1.09),(1.12,-.78),(1.12,.88),(.91,1.09),(-.96,1.09),(-1.12,.88)]
 verts=[(x,y,z) for z in [0,.11] for x,y in outline];N=len(outline)
 mesh('Welded octagonal ground mat',verts,[tuple(range(N-1,-1,-1)),tuple(range(N,N*2))]+[(i,(i+1)%N,(i+1)%N+N,i+N) for i in range(N)],9,.018)
 for x in [-.87,.87]:
  for y in [-.73,.73]:
   box('Cast concrete anchor block',(x,y,.20),(.44,.43,.20),10,.045)
   box('Bolted spreader foot',(x,y,.325),(.34,.30,.048),1,.008)
   for dx in [-.105,.105]:bolt('Foundation anchor',(x+dx,y,.365),'Z',.027)
   profile_beam('Splayed reclaimed gantry leg',(x,y,.34),(x*.76,y*.73,2.42),.16,.17,.035,0)
 # Triangulated rust ties; open center and honest I profiles distinguish it from a box tower.
 for x in [-1,1]:
  squarebeam('Lateral X brace A',(x*.83,-.70,.54),(x*.69,.55,2.16),.06,.065,1)
  squarebeam('Lateral X brace B',(x*.83,.70,.54),(x*.69,-.55,2.16),.06,.065,1)
 for y in [-1,1]:
  squarebeam('Front/back diagonal',( -.80,y*.68,.65),(.68,y*.56,2.16),.075,.06,1)
  squarebeam('Front/back diagonal',(.80,y*.68,.65),(-.68,y*.56,2.16),.075,.06,1)
 for z,w,d in [(.60,1.68,1.40),(2.29,1.53,1.27)]:
  for y in [-d/2,d/2]:profile_beam('Horizontal gantry stringer',(-w/2,y,z),(w/2,y,z),.10,.13,.024,9)
 for y in [-.68,.68]:profile_beam('Deck edge channel',(-.95,y,2.41),(.95,y,2.41),.12,.16,.024,2)
 for x in [-.9,.9]:profile_beam('Deck end channel',(x,-.76,2.4),(x,.76,2.4),.13,.13,.025,1)
 for i in range(7):box('Salvaged deck plank',(-.75+i*.25,0,2.44),(.23,1.50,.065),3,.012)
 # Tool box, deep-cycle battery and generator on a lower open platform.
 box('Lower service shelf',(.24,-.05,.70),(.95,.79,.07),9,.016)
 box('Automotive battery casing',(.35,.02,.93),(.48,.42,.43),5,.036)
 box('Battery lid',(.35,.02,1.16),(.50,.43,.048),9,.008)
 for x in [.20,.5]:cyl('Battery terminals',(x,.06,1.20),.031,.047,7,n=8,bevel=0)
 rope('Battery power cable',[(.2,.06,1.20),(.11,-.2,1.14),(.6,-.40,1.48),(.64,-.47,2.44),(.18,-.28,2.76)],.019)
 barrel('Reserve power fuel can',(-.39,.13,.94),.19,.43,5)
 # Rotating bearing base and curved recoil yoke.
 cyl('Traverse ring base',(0,0,2.53),.53,.11,9,n=24)
 cyl('Traverse bearing',(0,0,2.62),.44,.08,2,n=24)
 for i in range(12):
  a=i*math.tau/12;bolt('Bearing cap bolt',(.49*math.cos(a),.49*math.sin(a),2.6),'Z',.021)
 cyl('Mount central pedestal',(0,0,2.80),.24,.31,0,n=16)
 for x in [-.37,.37]:
  # Profile plate modeled in local XZ, then turned so it is a fore/aft yoke.
  p=[(-.34,2.81),(.34,2.81),(.28,3.35),(.14,3.48),(-.20,3.40),(-.35,3.13)]
  o=plate('Cut welded trunnion yoke',p,0,.075,1);o.rotation_euler.z=math.pi/2;o.location.x=x
  cyl('Trunnion cap',(x*1.13,-.02,3.21),.12,.06,2,(0,math.pi/2,0),n=12)
 box('Recoil sled',(0,-.1,3.20),(.61,.76,.18),9,.035)
 for x in [-.22,.22]:
  box('Twin reclaimed receiver',(x,-.27,3.30),(.22,.52,.23),0,.035)
  box('Receiver upper service strip',(x,-.25,3.445),(.15,.41,.035),2,.006)
  tube('Hollow gun barrel',(x,.02,3.30),(x,1.19,3.30),.059,.021,9,n=12)
  tube('Muzzle ring',(x,1.10,3.30),(x,1.23,3.30),.092,.037,2,n=12)
  for yy in [.11,.24,.38,.53]:tube('Ventilated sleeve ring',(x,yy,3.30),(x,yy+.055,3.30),.095,.031,0,n=10)
  for dx,dz in [(0,.080),(.073,-.035),(-.073,-.035)]:beam('Sleeve longitudinal rail',(x+dx,.08,3.3+dz),(x+dx,.69,3.3+dz),.013,2,6)
  beam('Recoil return ram',(x,-.40,3.04),(x,.45,3.04),.031,2)
  tube('Recoil spring housing',(x,-.43,3.04),(x,-.03,3.04),.058,.023,9,n=10)
 # Two bent shields flank muzzle clearance. Strong angled silhouette and exposed bolt pattern.
 plate('Port armor wing',[(-.80,2.78),(-.20,2.85),(-.23,3.15),(-.36,3.15),(-.35,3.58),(-.69,3.66),(-.86,3.48)],.15,.07,5)
 plate('Starboard armor wing',[(.20,2.85),(.79,2.80),(.85,3.44),(.65,3.60),(.34,3.57),(.36,3.15),(.23,3.15)],.15,.065,0)
 for x in [-.68,.68]:
  for z in [2.97,3.43]:bolt('Armor attachment',(x,.199,z),'Y',.032)
 box('Armor repair patch',(-.60,.20,3.21),(.25,.022,.25),1,.012,rot=(0,.15,0))
 stencil('07',(-.62,.226,3.11),.13)
 box('Salvaged ammunition box',(.65,-.28,2.80),(.37,.49,.46),5,.025)
 box('Ammo box lid',(.65,-.28,3.05),(.39,.51,.055),2,.008)
 for yy in [-.44,-.14]:box('Ammo strap',(.855,yy,2.85),(.025,.06,.37),9,.002)
 rope('Flexible ammunition feed',[(.62,-.25,3.08),(.61,-.40,3.35),(.42,-.42,3.43),(.23,-.37,3.40)],.060,9)
 # Sandbags and handrail are confined to rear deck; barrels remain unobstructed.
 for x in [-.60,0,.6]:bag('Rear sandbag parapet',(x,-.59,2.69),(.65,.35,.29),random.uniform(-.06,.06))
 for x in [-.88,.88]:
  beam('Rear guardrail post',(x,-.74,2.45),(x,-.74,3.01),.026,2)
 beam('Rear guardrail',(-.88,-.74,3.01),(.88,-.74,3.01),.029,2)
 # Accessible rung ladder rather than detached decorative lines.
 for x in [-.59,-.18]:beam('Rear ladder stringer',(x,-.96,.18),(x,-.83,2.43),.025,2)
 for j in range(8):
  z=.36+j*.27;yy=-.96+(z-.18)/2.25*.13;beam('Ladder rung',(-.59,yy,z),(-.18,yy,z),.022,1,8)
 for side in [-1,1]:
  plate('Gantry corner gusset',[(side*.58,2.28),(side*.87,2.28),(side*.87,2.03)],.65,.05,1,.005)
  for x in [side*.67,side*.81]:bolt('Gusset fastener',(x,.687,2.23))
 for x,y,z,ang in [(-.86,.66,.46,.10),(-.39,.90,.28,-.07),(.14,.93,.27,.04),(.64,.83,.29,-.16)]:bag('Ground anchor sandbag',(x,y,z),(.57,.34,.27),ang)
 export_asset('scrap_gun_tower')

def corrugated_sheet(name,xmin,xmax,ymin,ymax,zfn,tile=1,steps=36,depth=.022):
 # Single ridged sheet mesh with underside/thickness; detailed roof silhouette at RTS zoom.
 verts=[]
 for zoff in [0,-depth]:
  for y in [ymin,ymax]:
   for i in range(steps+1):
    x=xmin+(xmax-xmin)*i/steps;z=zfn(x,y)+(0.025 if i%2 else 0)+zoff;verts.append((x,y,z))
 n=steps+1;faces=[]
 for k in range(2):
  for i in range(steps):
   a=k*2*n+i;faces.append((a,a+1,a+1+n,a+n) if k==0 else (a+n,a+1+n,a+1,a))
 for i in range(steps):faces += [(i,2*n+i,2*n+i+1,i+1),(n+i+1,3*n+i+1,3*n+i,n+i)]
 faces.extend([(0,n,3*n,2*n),(n-1,3*n-1,4*n-1,2*n-1)])
 return mesh(name,verts,faces,tile)

def build_workshop():
 reset()
 box('Foundry slab',(0,0,.085),(3.30,3.22,.17),10,.045)
 for x in [-1.29,1.29]:
  for y in [-1.15,1.10]:
   box('Post base shoe',(x,y,.22),(.27,.25,.10),1,.018)
   profile_beam('Reused garage column',(x,y,.26),(x,y,2.48),.16,.18,.036,0)
   for xx in [-.08,.08]:bolt('Garage footing bolt',(x+xx,y,.28),'Z',.023)
 # Open face and side walls constructed from corrugated, patched sheet not a single cuboid.
 box('Rear workshop wall',(0,-1.18,1.26),(2.64,.072,2.18),5,.018)
 for i in range(14):box('Rear cladding rib',(-1.26+i*.194,-1.235,1.26),(.041,.043,2.12),0,.004)
 for x in [-1.33,1.33]:
  box('Side salvaged sheet',(x,-.13,1.18),(.065,2.16,2.02),0 if x<0 else 5,.01)
  for i in range(15):box('Side corrugation',(x*1.015,-1.15+i*.148,1.18),(.042,.033,2.01),0 if x<0 else 5,.003)
  profile_beam('Side eave purlin',(x,-1.28,2.49),(x,1.29,2.49),.13,.13,.025,1)
 profile_beam('Open workshop lintel',(-1.37,1.17,2.40),(1.37,1.17,2.40),.15,.22,.035,2)
 # Unequal gable with two different roof sheet sets and a small front canopy.
 roof=lambda x,y:3.04-abs(x+.25)*(.38 if x<-.25 else .27)
 corrugated_sheet('Left oxide corrugated roof',-1.53,-.25,-1.36,1.33,roof,1,18)
 corrugated_sheet('Right grey corrugated roof',-.25,1.53,-1.36,1.33,roof,0,24)
 for y in [-1.36,1.33]:
  squarebeam('Left roof edge',(-1.54,y,roof(-1.54,y)),(-.25,y,3.06),.055,.055,2)
  squarebeam('Right roof edge',(-.25,y,3.06),(1.54,y,roof(1.54,y)),.055,.055,2)
 tube('Folded ridge cap',(-.25,-1.41,3.08),(-.25,1.36,3.08),.066,.022,2,n=8)
 plate('Rear patched gable',[(-1.31,2.29),(1.31,2.29),(1.31,roof(1.31,0)),(-.25,3.01),(-1.31,roof(-1.31,0))],-1.19,.06,3,.007)
 plate('Front upper gable',[(-1.33,2.47),(1.33,2.47),(1.33,roof(1.33,0)),(-.25,3.01),(-1.33,roof(-1.33,0))],1.15,.05,5,.008)
 # Slatted loft ventilation is clearly readable from the hero camera.
 for x in [-.65,-.46,-.27,-.08,.11,.3,.49]:box('Gable vent slot',(x,1.189,2.67),(.10,.022,.18),9,.015)
 box('Workshop sign backing',(.42,1.211,2.45),(1.23,.07,.22),9,.013)
 stencil('AMMO / 07',(.42,1.252,2.38),.15)
 # Partly raised salvage roller shutter leaves the workface fully open.
 for i in range(4):box('Raised roller shutter slat',(-.36,1.10,2.15+i*.061),(1.73,.055,.055),2,.006)
 box('Roller shaft housing',(-.36,1.05,2.42),(1.94,.26,.17),9,.025)
 # Small canvas sun/rain awning; asymmetric drape and supports.
 verts=[]
 for j in range(3):
  for i in range(5):
   x=-1.39+i*.60;y=1.16+j*.23;z=2.18-j*.12-.06*math.sin(i*math.pi/4)
   verts.append((x,y,z))
 faces=[]
 for j in range(2):
  for i in range(4):a=j*5+i;faces.append((a,a+1,a+6,a+5))
 aw=mesh('Sagged canvas workface canopy',verts,faces,4)
 mod=aw.modifiers.new('Canvas thickness','SOLIDIFY');mod.thickness=.014;bpy.context.view_layer.objects.active=aw;bpy.ops.object.modifier_apply(modifier=mod.name)
 for x in [-1.39,1.01]:squarebeam('Canopy brace',(x,1.14,1.68),(x,1.60,1.96),.034,.038,1)
 beam('Canvas front hem',(-1.39,1.62,1.94),(1.01,1.62,1.94),.025,3)
 # Heavy bench and press: the center of the open-front silhouette.
 box('Workbench reclaimed slab',(-.35,.81,.93),(1.75,.63,.12),3,.025)
 for x in [-1.05,.35]:
  for y in [.60,1.02]:squarebeam('Workbench leg',(x,y,.18),(x,y,.89),.075,.075,1)
 box('Bench lower shelf',(-.35,.79,.41),(1.60,.49,.045),9,.01)
 for x in [-.93,-.49,-.06]:crate('Sorted component bin',(x,.83,.55),(.35,.34,.25))
 # Bench mounted handloading/drill press, cut horseshoe casting with visible working throat.
 plate('Reloading press casting',[(-.89,.99),(-.32,.99),(-.32,1.13),(-.66,1.13),(-.66,1.58),(-.34,1.58),(-.34,1.78),(-.89,1.78)],.71,.22,0,.025)
 cyl('Press sliding ram',(-.43,.72,1.40),.046,.50,2,n=12)
 cyl('Press ram shoe',(-.43,.72,1.16),.10,.048,2,n=12)
 beam('Press hand lever',(-.78,.89,1.49),(-.96,1.01,1.75),.025,2)
 cyl('Hand lever grip',(-.96,1.01,1.77),.045,.16,6,n=10)
 box('Bench vise base',(.18,.93,1.04),(.28,.25,.08),9,.015)
 for x in [.07,.25]:box('Bench vise jaw',(x,.93,1.13),(.055,.23,.13),2,.009)
 beam('Vise screw',(-.05,.93,1.11),(.39,.93,1.11),.018,2)
 beam('Vise handle',(.37,.93,1.03),(.37,.93,1.23),.016,2)
 # A few oversized cartridge-like parts read as manufacturing, not tiny confetti.
 for i in range(6):
  x=-.16+(i%3)*.086;y=.66+(i//3)*.10;cyl('Brass cartridge case',(x,y,1.075),.029,.16,7,n=8,bevel=.003)
 # Rear stove / small forging furnace under dedicated extractor hood.
 cyl('Repurposed drum furnace',(-.81,-.65,.67),.38,.86,9,n=16,bevel=.025)
 for z in [.32,.97]:cyl('Furnace retaining band',(-.81,-.65,z),.40,.065,1,n=16,bevel=.008)
 box('Furnace door dark opening',(-.81,-.25,.67),(.37,.065,.34),9,.05)
 box('Furnace ember grate',(-.81,-.21,.63),(.25,.025,.13),14,.004)
 for x in [-.90,-.80,-.70]:box('Furnace front grate',(x,-.186,.64),(.020,.018,.15),9,.001)
 # Sheet metal extractor transition, purpose-built trapezoid rather than a stacked block.
 verts=[(-1.33,-1.10,1.47),(-.30,-1.10,1.47),(-.30,-.22,1.47),(-1.33,-.22,1.47),(-1.00,-.84,1.95),(-.64,-.84,1.95),(-.64,-.48,1.95),(-1.00,-.48,1.95)]
 mesh('Welded extractor hood',verts,[(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7),(4,5,6,7)],2,.012)
 box('Extractor neck',(-.82,-.66,2.14),(.33,.34,.49),9,.015)
 tube('Chimney lower stack',(-.82,-.66,2.20),(-.82,-.66,3.83),.16,.029,9,n=12)
 for z in [2.64,3.27,3.64]:tube('Chimney splice collar',(-.82,-.66,z),(-.82,-.66,z+.065),.19,.03,1,n=12)
 for dx in [-.13,.13]:beam('Rain cap standoff',(-.82+dx,-.66,3.77),(-.82+dx,-.66,4.02),.016,2)
 cyl('Chimney rain hat',(-.82,-.66,4.02),.28,.045,2,n=12,bevel=.01)
 # Side extractor fan, louvers and exposed belt drive.
 box('Fan square surround',(1.395,-.46,1.73),(.13,.78,.78),9,.035)
 cyl('Circular fan rim',(1.48,-.46,1.73),.34,.12,2,(0,math.pi/2,0),n=20,bevel=.006)
 cyl('Dark fan recess',(1.55,-.46,1.73),.28,.013,9,(0,math.pi/2,0),n=20,bevel=0)
 for i in range(6):
  ang=i*math.tau/6;y=-.46+math.cos(ang)*.13;z=1.73+math.sin(ang)*.13
  box('Extractor swept blade',(1.565,y,z),(.025,.22,.095),0,.018,rot=(ang+.6,0,0))
 cyl('Fan hub',(1.59,-.46,1.73),.074,.065,2,(0,math.pi/2,0),n=12,bevel=.005)
 for d in [-.18,0,.18]:beam('Fan safety grille',(1.628,-.72,1.73+d),(1.628,-.20,1.73+d),.012,2,6)
 box('Fan electrical motor',(1.44,-.92,.63),(.24,.34,.37),0,.03)
 rope('Side electrical conduit',[(1.41,-.47,1.49),(1.43,-.62,1.14),(1.43,-.92,.89)],.021,6)
 # Outside storage within footprint: dented water barrel, stacked crates and supply rack.
 barrel('Reclaimed coolant drum',(1.01,.62,.52),.26,.66,1)
 crate('Ammo transport crate',(.86,1.12,.32),(.65,.48,.34))
 crate('Second transport crate',(.88,1.10,.66),(.56,.40,.30))
 box('Crate painted identifier',(.88,1.316,.65),(.33,.018,.09),8,.004)
 # Side repair plates and strapped timber prevent clean standardized factory appearance.
 for y,z,ang in [(-.72,.74,-.06),(.48,1.31,.05)]:
  o=box('Bolted cladding patch',(-1.38,y,z),(.04,.64,.44),1,.008,rot=(ang,0,0))
  for dy in [-.23,.23]:bolt('Patch fastener',(-1.408,y+dy,z+.14),'X')
 for i in range(3):squarebeam('Leaning salvaged stock',(-1.48,-.9+i*.13,.21),(-1.42,-.58+i*.13,1.53),.075,.055,3)
 # Workface step and safety wear strip.
 box('Entry lip',(0,1.47,.20),(2.44,.22,.12),9,.018)
 box('Worn hazard threshold',(0,1.58,.266),(2.35,.11,.02),11,.004)
 # Hanging work lamp and cables, attached to rafters.
 rope('Overhead workshop cable',[(-1.24,-.84,2.41),(-.3,.02,2.23),(.73,.43,2.28),(1.25,1.0,2.4)],.016,6)
 cyl('Work lamp shade',(.18,.60,2.15),.15,.09,2,n=12,bevel=.009)
 cyl('Warm lamp lens',(.18,.60,2.096),.109,.015,15,n=12,bevel=0)
 beam('Lamp flex',(.18,.6,2.19),(.18,.6,2.41),.014,6)
 export_asset('ammo_workshop')

build_tower();build_workshop()
json.dump(stats,open(ROOT/'asset_stats.json','w'),indent=2)
