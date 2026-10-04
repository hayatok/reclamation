"""RECLAMATION original mobile siege cart. Blender 4.3.2, Z-up authoring / -Z Godot forward.
All geometry authored here; tiles are original deterministic raster/PBR materials.
"""
import bpy, math, random, json
from mathutils import Vector
from pathlib import Path
P=Path(__file__).resolve().parent.parent
random.seed(910)
objects=[]; mat=None

def material():
 m=bpy.data.materials.new('Survivor_Vehicle_Atlas_PBR');m.use_nodes=True
 n=m.node_tree.nodes;l=m.node_tree.links;bs=n.get('Principled BSDF')
 for filename,color,name in [('survivor_vehicle_atlas.png','sRGB','Base'),('survivor_vehicle_orm.png','Non-Color','ORM'),('survivor_vehicle_normal.png','Non-Color','Normal')]:
  t=n.new('ShaderNodeTexImage');t.name=name;t.image=bpy.data.images.load(str(P/'assets'/filename),check_existing=True);t.image.colorspace_settings.name=color
  if name=='Base':l.new(t.outputs['Color'],bs.inputs['Base Color'])
  elif name=='ORM':
   s=n.new('ShaderNodeSeparateColor');l.new(t.outputs['Color'],s.inputs[0]);l.new(s.outputs['Green'],bs.inputs['Roughness']);l.new(s.outputs['Blue'],bs.inputs['Metallic'])
  else:
   nm=n.new('ShaderNodeNormalMap');nm.inputs['Strength'].default_value=.28;l.new(t.outputs['Color'],nm.inputs['Color']);l.new(nm.outputs['Normal'],bs.inputs['Normal'])
 return m

def finish(o,name,tile=0,bevel=0,smooth=False):
 o.name=name;bpy.context.view_layer.objects.active=o
 bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
 if bevel:
  mod=o.modifiers.new('Fabricated worn edge bevel','BEVEL');mod.width=bevel;mod.segments=1;bpy.ops.object.modifier_apply(modifier=mod.name)
 o.data.materials.clear();o.data.materials.append(mat)
 uv=o.data.uv_layers.new(name='UVMap') if not o.data.uv_layers else o.data.uv_layers.active
 for poly in o.data.polygons:
  poly.use_smooth=smooth
  n=poly.normal;axis=max(range(3),key=lambda k:abs(n[k]));axes=[k for k in range(3) if k!=axis]
  vals=[o.data.vertices[o.data.loops[j].vertex_index].co for j in poly.loop_indices]
  mins=[min(v[k] for v in vals) for k in axes];maxs=[max(v[k] for v in vals) for k in axes]
  for j,v in zip(poly.loop_indices,vals):
   q=[(v[k]-lo)/max(hi-lo,.000001) for k,lo,hi in zip(axes,mins,maxs)]
   uv.data[j].uv=((tile%4+.03+q[0]*.94)/4,(3-tile//4+.03+q[1]*.94)/4)
 objects.append(o);return o

def box(name,loc,size,tile=0,bevel=.012,rot=(0,0,0)):
 bpy.ops.mesh.primitive_cube_add(size=1,location=loc,rotation=rot);o=bpy.context.object;o.scale=size
 return finish(o,name,tile,bevel)

def mesh(name,verts,faces,tile=0,bevel=0,smooth=False):
 me=bpy.data.meshes.new(name);me.from_pydata(verts,[],faces);me.update();o=bpy.data.objects.new(name,me);bpy.context.collection.objects.link(o)
 return finish(o,name,tile,bevel,smooth)

def cyl(name,loc,r,d,tile=8,axis='Z',verts=16,bevel=.006):
 rot={'Z':(0,0,0),'Y':(math.pi/2,0,0),'X':(0,math.pi/2,0)}[axis]
 bpy.ops.mesh.primitive_cylinder_add(vertices=verts,radius=r,depth=d,location=loc,rotation=rot)
 return finish(bpy.context.object,name,tile,bevel)

def beam(name,a,b,r=.012,tile=8,verts=8):
 a=Vector(a);b=Vector(b);o=cyl(name,(a+b)/2,r,(b-a).length,tile,verts=verts,bevel=0)
 o.rotation_euler=(b-a).to_track_quat('Z','Y').to_euler();return o

def panel(name,verts,tile=0,thick=.014):
 # Four-corner plate with original panel silhouette and real thickness.
 v=[Vector(x) for x in verts];n=(v[1]-v[0]).cross(v[2]-v[0]).normalized(); vv=[tuple(x+n*thick*.5) for x in v]+[tuple(x-n*thick*.5) for x in v]
 return mesh(name,vv,[(0,1,2,3),(7,6,5,4),(0,4,5,1),(1,5,6,2),(2,6,7,3),(3,7,4,0)],tile)

def curve_beam(name,points,r=.014,tile=8):
 for i in range(len(points)-1):beam(name+str(i),points[i],points[i+1],r,tile,8)

def ring(name,loc,profile,tile=3,n=28):
 x,y,z=loc;vs=[]
 for off,r in profile:
  for i in range(n):
   a=math.tau*i/n;vs.append((x+off,y+math.cos(a)*r,z+math.sin(a)*r))
 fs=[]
 for k in range(len(profile)):
  q=(k+1)%len(profile)
  for i in range(n):j=(i+1)%n;fs.append((k*n+i,k*n+j,q*n+j,q*n+i))
 o=mesh(name,vs,fs,tile,smooth=True)
 # Continuous ring UVs make sidewall and tread texel density consistent.
 uv=o.data.uv_layers.active
 for pi,poly in enumerate(o.data.polygons):
  k=pi//n;i=pi%n
  for li,q in zip(poly.loop_indices,[(i/n,k/len(profile)),((i+1)/n,k/len(profile)),((i+1)/n,(k+1)/len(profile)),(i/n,(k+1)/len(profile))]):uv.data[li].uv=((tile%4+.03+.94*q[0])/4,(3-tile//4+.03+.94*q[1])/4)
 return o


# Original siege-cart geometry, adapted from the project's own fleet fabrication
# helpers. Authoring X right, +Y front, Z up; exported X right, -Z front, Y up.

def squarebeam(name,a,b,w=.09,d=.09,tile=14):
 a,b=Vector(a),Vector(b);o=box(name,(a+b)/2,(w,d,(b-a).length),tile,.006)
 o.rotation_euler=(b-a).to_track_quat('Z','Y').to_euler();return o

def tube(name,a,b,r=.23,wall=.057,tile=14,n=32):
 a,b=Vector(a),Vector(b);q=(b-a).to_track_quat('Z','Y');v=[]
 for p,rad in [(a,r),(b,r),(a,r-wall),(b,r-wall)]:
  v += [tuple(p+q@Vector((math.cos(i*math.tau/n)*rad,math.sin(i*math.tau/n)*rad,0))) for i in range(n)]
 f=[]
 for i in range(n):
  j=(i+1)%n;f += [(i,j,n+j,n+i),(2*n+i,3*n+i,3*n+j,2*n+j),(i,2*n+i,2*n+j,j),(n+i,n+j,3*n+j,3*n+i)]
 o=mesh(name,v,f,tile,smooth=True)
 # Flat, dark inner faces preserve a readable hollow muzzle at gameplay scale.
 for p in o.data.polygons:
  p.use_smooth=(p.index%4 in [0,1])
 return o

def wheel(s,y):
 x=s*1.075;z=.49
 profile=[(-.18,.245),(-.20,.32),(-.17,.433),(-.115,.485),(.115,.485),(.17,.433),(.20,.32),(.18,.245)]
 ring('Pneumatic treaded wheel',(x,y,z),profile,3,32)
 for row in [-1,1]:
  for i in range(22):
   a=math.tau*i/22+(row+1)*.031
   box('Raised cross-country tread',(x+row*.071,y+math.cos(a)*.486,z+math.sin(a)*.486),(.124,.123,.022),3,0,(a-math.pi/2,0,row*.19))
 ring('Reclaimed stamped rim',(x+s*.158,y,z),[(-.027,.105),(-.027,.214),(-.005,.268),(.035,.253),(.047,.218),(.011,.183),(.011,.105)],8,24)
 cyl('Axle bearing hub',(x+s*.18,y,z),.113,.10,14,'X',16,.007)
 cyl('Weathered hub cap',(x+s*.235,y,z),.057,.043,8,'X',12,.006)
 for k in range(6):
  a=math.tau*k/6
  cyl('Six wheel bolts',(x+s*.24,y+math.cos(a)*.086,z+math.sin(a)*.086),.015,.018,15,'X',6,0)
  a+=.23
  cyl('Dark inset rim aperture',(x+s*.205,y+math.cos(a)*.192,z+math.sin(a)*.192),.029,.008,11,'X',8,0)


def ammo_crate(name,loc,size=(.57,.62,.45),tile=4):
 x,y,z=loc;w,d,h=size
 box(name,loc,size,tile,.026)
 # Slat gaps and steel straps remain legible without texture text or military marks.
 for zz in [-.11,.09]:
  for s in [-1,1]:box('Crate plank seam',(x+s*(w/2+.002),y,z+zz),(.009,d*.92,.011),14,0)
 for xx in [-w*.32,w*.32]:
  box('Crate lid retaining strap',(x+xx,y,z+h*.51),(.036,d+.014,.017),8,.003)
  for sy in [-1,1]:box('Crate corner strap',(x+xx,y+sy*(d/2+.007),z),(.036,.018,h*.97),8,.002)
 for sy in [-1,1]:
  beam('Crate carry grip',(x-.09,y+sy*(d*.54),z+.025),(x+.09,y+sy*(d*.54),z+.025),.014,14)
 box('Crate lid seam',(x,y,z+h*.512),(w*.95,.011,.010),14,0)


def build_cart():
 # Open, suspended chassis: no ground slab and nothing touches ground except tires.
 for x in [-.74,.74]:
  box('Long salvaged channel rail',(x,-.05,.67),(.16,3.12,.20),14,.018)
  box('Rail welded upper flange',(x,-.05,.778),(.215,3.12,.025),8,.005)
 for y in [-1.47,-.98,-.28,.57,1.43]:box('Crossmember',(0,y,.655),(1.65,.13,.18),14,.015)
 for y in [-1.03,1.03]:
  cyl('Full transverse axle',(0,y,.49),.078,2.23,14,'X',16,.01)
  for s in [-1,1]:
   # Three honest layered leaf springs joining axle to the load-bearing rails.
   for layer,length in enumerate([.83,.64,.45]):
    pts=[(s*.75,y-length/2,.555+layer*.021),(s*.75,y,.515+layer*.021),(s*.75,y+length/2,.555+layer*.021)]
    for i in [0,1]:squarebeam('Laminated leaf spring',pts[i],pts[i+1],.075,.023,8)
   for dy in [-.40,.40]:box('Suspension hanger',(s*.75,y+dy,.595),(.10,.105,.20),1,.007)
   for dy in [-.11,.11]:beam('Axle U clamp',(s*.79,y+dy,.46),(s*.79,y+dy,.66),.012,8)
   wheel(s,y)
 # Three mismatched salvaged floor panels with exposed continuous seams.
 for y,depth,tile in [(-1.01,.96,0),(-.025,.96,14),(.97,.96,0)]:
  box('Patched steel cargo deck',(0,y,.81),(1.96,depth,.105),tile,.016)
 for x in [-.975,.975]:box('Rolled deck perimeter rail',(x,-.015,.887),(.065,3.00,.092),1,.01)
 for y in [-1.49,1.49]:box('Rolled deck end rail',(0,y,.886),(1.98,.064,.095),8,.01)
 # Rust repair patches and honest through-fasteners, no faction/military branding.
 for x,y,w,d,tile in [(-.74,.55,.33,.40,1),(.65,-.23,.45,.30,2),(-.48,-.91,.42,.38,1),(.62,1.12,.39,.34,14)]:
  box('Scrap overlay patch',(x,y,.872),(w,d,.021),tile,.004,rot=(0,0,.035))
  for dx in [-w*.34,w*.34]:
   for dy in [-d*.32,d*.32]:cyl('Deck patch bolt',(x+dx,y+dy,.89),.019,.018,8,'Z',6,0)
 # Small separate fenders reveal tires, axle gaps and suspension rather than tank skirts.
 for s in [-1,1]:
  for y in [-1.03,1.03]:
   box('Bent steel mudguard',(s*1.07,y,1.036),(.45,.79,.057),0 if y>0 else 1,.023)
   for dy in [-.37,.37]:squarebeam('Mudguard stiffener',(s*.90,y+dy,.82),(s*1.18,y+dy,1.025),.037,.043,8)
 # Tow yoke and retracted stowage only, no deployed feet that would imply a static gun.
 for s in [-1,1]:squarebeam('Triangular tow drawbar',(s*.58,1.40,.635),(0,1.81,.52),.10,.10,14)
 ring_o=tube('Front open tow eye',(0,1.81,.52),(0,1.94,.52),.095,.030,8,16)
 box('Rear grab step',(0,-1.67,.53),(.96,.24,.075),14,.012)
 for x in [-.35,-.175,0,.175,.35]:box('Rear step tread strip',(x,-1.67,.575),(.025,.21,.012),8,.001)
 for s in [-1,1]:
  beam('Rear push handle upright',(s*.69,-1.49,.89),(s*.69,-1.77,1.35),.025,8)
  beam('Rear rubber handle',(s*.69,-1.78,1.35),(s*.69,-1.51,1.35),.037,3)
 # Circular traverse cradle: battered industrial bearing plate, not a concrete base.
 cyl('Traverse circular bearing',(0,.18,.945),.64,.105,14,verts=32,bevel=.018)
 cyl('Salvaged slewing plate',(0,.18,1.01),.515,.075,1,verts=32,bevel=.01)
 for i in range(12):
  a=math.tau*i/12;cyl('Traverse base bolts',(math.cos(a)*.552,.18+math.sin(a)*.552,1.011),.024,.026,8,verts=6,bevel=0)
 # Two shaped steel cheeks support the tube trunnion. Triangular side silhouette.
 for s in [-1,1]:
  verts=[(s*.32,-.24,1.04),(s*.32,.62,1.04),(s*.32,.45,1.55),(s*.32,.07,1.62)]
  panel('Welded triangular carriage cheek',verts,0,.070)
  squarebeam('Rear recoil brace',(s*.42,-.37,1.04),(s*.32,.14,1.55),.074,.079,8)
  squarebeam('Forward recoil brace',(s*.46,.72,1.04),(s*.32,.39,1.50),.074,.079,1)
  for yy,zz in [(-.15,1.13),(.54,1.13),(.26,1.53)]:
   cyl('Cheek plate retaining bolt',(s*.367,yy,zz),.027,.032,8,'X',6,0)
 cyl('Working transverse trunnion',(0,.29,1.46),.125,.93,8,'X',24,.007)
 # Short, high-angle field tube. Breech stays behind, muzzle points forward/up.
 breech=Vector((0,-.27,1.15));muzzle=Vector((0,1.19,2.095));direction=(muzzle-breech).normalized()
 tube('Hollow elevated howitzer tube',breech,muzzle,.245,.063,14,32)
 # Closed rear cap is well behind the bore, which remains visibly open.
 beam('Closed breech forging',breech-direction*.055,breech+direction*.09,.267,8,32)
 beam('Breech retaining collar',breech+direction*.08,breech+direction*.20,.282,1,32)
 for along in [.62,1.08]:
  p=breech+direction*along;tube('Barrel strengthening band',p-direction*.032,p+direction*.032,.265,.045,8,32)
 tube('Thick worn muzzle lip',muzzle-direction*.087,muzzle+direction*.018,.268,.085,8,32)
 # Hollow muzzle termination sits at center Y2.105/Z-1.205 after export.
 muzzle=muzzle+direction*.019
 beam('Breech lever',(.12,-.26,1.16),(.42,-.30,1.23),.025,8)
 beam('Breech lever grip',(.42,-.30,1.23),(.42,-.30,1.38),.041,3)
 # Elevation jack and small handwheel clearly articulate the braced mechanism.
 beam('Elevation jack lower sleeve',(.28,.49,1.08),(.28,.70,1.56),.064,8,16)
 beam('Elevation screw upper',(.28,.70,1.56),(.28,.79,1.76),.041,14,12)
 ring('Elevation handwheel',(.57,.27,1.40),[(-.026,.19),(.026,.19),(.026,.156),(-.026,.156)],8,24)
 for i in range(4):
  a=math.tau*i/4;beam('Handwheel spokes',(.57,.27,1.40),(.57,.27+math.cos(a)*.175,1.40+math.sin(a)*.175),.017,8)
 cyl('Handwheel hub',(.57,.27,1.40),.048,.10,8,'X',12,.004)
 beam('Handwheel turning peg',(.60,.42,1.40),(.73,.42,1.40),.030,3,12)
 # Ammunition is in civilian wood crates at the back; shallow side box and canvas roll.
 ammo_crate('Rear wooden ammunition crate',(-.49,-1.045,1.11),(.66,.68,.47),4)
 ammo_crate('Rear repaired ammunition crate',(.40,-1.06,1.083),(.57,.68,.415),4)
 box('Folded canvas pad',(-.50,-1.03,1.398),(.57,.60,.105),7,.043)
 for xx in [-.70,-.31]:box('Crate canvas retaining band',(xx,-1.03,1.456),(.040,.62,.022),14,.005)
 box('Field spares steel chest',(-.69,.005,1.046),(.41,.70,.35),2,.02)
 box('Chest lid',(-.69,.005,1.230),(.43,.72,.041),0,.009)
 for yy in [-.23,.24]:box('Chest latch',(-.906,yy,1.13),(.028,.060,.105),8,.006)
 # Inboard rake/tool holder, patched orange civilian reflectors on trailer back.
 for s in [-1,1]:
  box('Rear amber civilian reflector',(s*.79,-1.532,.946),(.145,.025,.081),6,.008)
  box('Tied equipment loop',(s*.93,-.40,1.06),(.060,.14,.15),7,.015)
 return tuple(muzzle),tuple(direction)


def sanitize_uv(o):
 uv=o.data.uv_layers.active
 for face in o.data.polygons:
  coords=[uv.data[k].uv.copy() for k in face.loop_indices]
  xs=sorted(max(0,min(3,int(q.x*4))) for q in coords);ys=sorted(max(0,min(3,int(q.y*4))) for q in coords)
  x=xs[len(xs)//2];y=ys[len(ys)//2]
  for k in face.loop_indices:
   q=uv.data[k].uv;q.x=max((x+.03)/4,min((x+.97)/4,q.x));q.y=max((y+.03)/4,min((y+.97)/4,q.y))


def run():
 global mat,objects
 bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False);objects=[];mat=material()
 muzzle,direction=build_cart()
 col=bpy.data.collections.new('EDITABLE_COMPONENTS');bpy.context.scene.collection.children.link(col)
 for o in objects:
  for c in list(o.users_collection):c.objects.unlink(o)
  col.objects.link(o)
 bpy.ops.object.select_all(action='DESELECT');clones=[]
 for o in objects:
  q=o.copy();q.data=o.data.copy();bpy.context.scene.collection.objects.link(q);q.select_set(True);clones.append(q)
 bpy.context.view_layer.objects.active=clones[0];bpy.ops.object.join();hero=bpy.context.object;hero.name='Siege_Cart_LOD0'
 bpy.context.scene.cursor.location=(0,0,0);bpy.ops.object.origin_set(type='ORIGIN_CURSOR');bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
 # All four tires sit on the ground exactly. Root remains (0,0,0).
 ground=min(v.co.z for v in hero.data.vertices)
 for v in hero.data.vertices:v.co.z-=ground
 for o in objects:o.location.z-=ground
 muzzle=(muzzle[0],muzzle[1],muzzle[2]-ground)
 bpy.ops.object.mode_set(mode='EDIT');bpy.ops.mesh.select_all(action='SELECT');bpy.ops.mesh.normals_make_consistent(inside=False);bpy.ops.object.mode_set(mode='OBJECT')
 tri=hero.modifiers.new('Final triangulation','TRIANGULATE');bpy.ops.object.modifier_apply(modifier=tri.name)
 if len(hero.data.polygons)>11000:
  dec=hero.modifiers.new('Remove subpixel fabrication detail cost','DECIMATE');dec.ratio=11000/len(hero.data.polygons);bpy.ops.object.modifier_apply(modifier=dec.name);sanitize_uv(hero)
 hero.data.validate(clean_customdata=True);hero.data.update()
 for o in objects:o.hide_render=True;o.hide_set(True)
 col.hide_render=True;col.hide_viewport=True
 bpy.ops.object.select_all(action='DESELECT');hero.select_set(True);bpy.context.view_layer.objects.active=hero
 minb=[min(v.co[k] for v in hero.data.vertices) for k in range(3)];maxb=[max(v.co[k] for v in hero.data.vertices) for k in range(3)]
 stats={'blender':bpy.app.version_string,'asset':'siege_cart','original_geometry':True,'surfaces':1,'material':'Survivor_Vehicle_Atlas_PBR','atlas_size':[2048,2048],'editable_components':len(objects),'godot_bounds_min':[minb[0],minb[2],-maxb[1]],'godot_bounds_max':[maxb[0],maxb[2],-minb[1]],'godot_size':[maxb[0]-minb[0],maxb[2]-minb[2],maxb[1]-minb[1]],'root':[0,0,0],'orientation':'Godot +Y up, -Z forward','muzzle_position_godot':[muzzle[0],muzzle[2],-muzzle[1]],'muzzle_direction_godot':[direction[0],direction[2],-direction[1]],'wheel_count':4,'axle_count':2,'lod_triangles':{}}
 bpy.context.preferences.filepaths.save_version=0;bpy.ops.file.pack_all();bpy.ops.wm.save_as_mainfile(filepath=str(P/'source'/'siege_cart.blend'))
 for level,ratio in [(0,1),(1,.44),(2,.45)]:
  if level:
   dec=hero.modifiers.new('Silhouette distance reduction','DECIMATE');dec.ratio=ratio;bpy.ops.object.modifier_apply(modifier=dec.name);sanitize_uv(hero);hero.data.validate(clean_customdata=True);hero.data.update()
  hero.name=f'Siege_Cart_LOD{level}'
  path=P/'assets'/('siege_cart.glb' if level==0 else f'siege_cart_lod{level}.glb')
  bpy.ops.export_scene.gltf(filepath=str(path),export_format='GLB',use_selection=True,export_texcoords=True,export_normals=True,export_tangents=True,export_materials='EXPORT',export_yup=True)
  stats['lod_triangles'][str(level)]=len(hero.data.polygons)
 json.dump(stats,open(P/'reports'/'asset_stats.json','w'),indent=2)
 print('SIEGE_CART_BUILD_OK',json.dumps(stats))

if __name__=='__main__':run()
