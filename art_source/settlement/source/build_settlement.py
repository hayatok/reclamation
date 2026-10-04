"""RECLAMATION v09 original civilian settlement. Blender 4.3.2 authoring → glTF2.
Units metres. Blender +Y is the working face, exported as Godot -Z. Rebuildable.
"""
import bpy, bmesh, math, random, json, os
from mathutils import Vector
from pathlib import Path
ROOT=Path(__file__).resolve().parent.parent
random.seed(909)
objects=[]; stats={}

def reset():
 global objects,mat
 for existing in list(bpy.data.objects):bpy.data.objects.remove(existing,do_unlink=True)
 for c in list(bpy.data.collections):
  if c.name!='Collection' and c.users==0:bpy.data.collections.remove(c)
 objects=[]
 mat=bpy.data.materials.get('SETTLEMENT | original salvage atlas')
 if not mat:
  mat=bpy.data.materials.new('SETTLEMENT | original salvage atlas');mat.use_nodes=True
  n=mat.node_tree.nodes;link=mat.node_tree.links;bs=n.get('Principled BSDF')
  for file,col in [('settlement_albedo','sRGB'),('settlement_orm','Non-Color'),('settlement_normal','Non-Color')]:
   tx=n.new('ShaderNodeTexImage');tx.name=file;tx.label=file;tx.image=bpy.data.images.load(str(ROOT/'assets'/f'{file}.png'),check_existing=True);tx.image.colorspace_settings.name=col
  link.new(n['settlement_albedo'].outputs['Color'],bs.inputs['Base Color'])
  sp=n.new('ShaderNodeSeparateColor');link.new(n['settlement_orm'].outputs['Color'],sp.inputs[0]);link.new(sp.outputs['Green'],bs.inputs['Roughness']);link.new(sp.outputs['Blue'],bs.inputs['Metallic'])
  no=n.new('ShaderNodeNormalMap');no.inputs['Strength'].default_value=.4;link.new(n['settlement_normal'].outputs['Color'],no.inputs['Color']);link.new(no.outputs[0],bs.inputs['Normal'])
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
 src=bpy.data.collections.new('AUTHORING | reveal to edit components');bpy.context.scene.collection.children.link(src)
 copies=[]
 for o in objects:
  for c in list(o.users_collection):c.objects.unlink(o)
  src.objects.link(o);cp=o.copy();cp.data=o.data.copy();bpy.context.scene.collection.objects.link(cp);copies.append(cp)
 src.hide_viewport=True;src.hide_render=True
 bpy.ops.object.select_all(action='DESELECT')
 for cp in copies:cp.select_set(True)
 bpy.context.view_layer.objects.active=copies[0];bpy.ops.object.join();hero=bpy.context.object;hero.name=name+'_LOD0'
 bpy.context.scene.cursor.location=(0,0,0);bpy.ops.object.origin_set(type='ORIGIN_CURSOR');bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
 tri=hero.modifiers.new('Export triangulation','TRIANGULATE');bpy.ops.object.modifier_apply(modifier=tri.name)
 hero.data.validate(clean_customdata=True);hero.data.update();bpy.context.view_layer.update()
 verts=[hero.matrix_world@v.co for v in hero.data.vertices];mn=[min(v[k] for v in verts) for k in range(3)];mx=[max(v[k] for v in verts) for k in range(3)]
 gmin=[mn[0],mn[2],-mx[1]];gmax=[mx[0],mx[2],-mn[1]]
 stats[name]={'triangles':len(hero.data.polygons),'vertices':len(hero.data.vertices),'authored_components':len(objects),'surfaces':1,'godot_bounds_min':gmin,'godot_bounds_max':gmax,'godot_size':[gmax[k]-gmin[k] for k in range(3)],'atlas_size':1024,'lod_triangles':[]}
 bpy.context.preferences.filepaths.save_version=0;bpy.ops.file.pack_all();bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'source'/f'{name}.blend'))
 def glb(suffix):bpy.ops.export_scene.gltf(filepath=str(ROOT/'assets'/f'{name}{suffix}.glb'),export_format='GLB',use_selection=True,export_texcoords=True,export_normals=True,export_materials='EXPORT',export_yup=True,export_tangents=True)
 glb('')
 for lod,ratio in [(1,.48),(2,.45)]:
  dec=hero.modifiers.new('Explicit silhouette LOD','DECIMATE');dec.ratio=ratio;bpy.ops.object.modifier_apply(modifier=dec.name)
  hero.data.validate(clean_customdata=True);hero.data.update()
  for v in hero.data.vertices:
   if v.co.z < .014:v.co.z=0.0
  uv=hero.data.uv_layers.active
  for f in hero.data.polygons:
   coords=[uv.data[k].uv.copy() for k in f.loop_indices]
   xs=sorted(max(0,min(3,int(q.x*4))) for q in coords);ys=sorted(max(0,min(3,int(q.y*4))) for q in coords);xx=xs[len(xs)//2];yy=ys[len(ys)//2]
   for k in f.loop_indices:
    q=uv.data[k].uv;q.x=max((xx+.025)/4,min((xx+.975)/4,q.x));q.y=max((yy+.025)/4,min((yy+.975)/4,q.y))
  hero.name=name+'_LOD'+str(lod);glb('_lod'+str(lod));stats[name]['lod_triangles'].append(len(hero.data.polygons))
 print('BUILT',name,stats[name],flush=True)

def ground(w,d):
 # Low irregular earth pad, with ground-contact root. Edge is softened but never below zero.
 pts=[(-w/2,-d*.39),(-w*.40,-d/2),(w*.41,-d/2),(w/2,-d*.38),(w/2,d*.41),(w*.39,d/2),(-w*.42,d/2),(-w/2,d*.38)]
 v=[(x,y,z) for z in [0,.08] for x,y in pts];N=len(pts)
 mesh('Compacted settlement ground',v,[tuple(range(N-1,-1,-1)),tuple(range(N,N*2))]+[(i,(i+1)%N,(i+1)%N+N,i+N) for i in range(N)],12,.008)

def sheet(name,xmin,xmax,ymin,ymax,zfn,tile=0,steps=20,depth=.025):
 v=[]
 for dz in [0,-depth]:
  for y in [ymin,ymax]:
   for i in range(steps+1):
    x=xmin+(xmax-xmin)*i/steps;v.append((x,y,zfn(x,y)+(.018 if i%2 else 0)+dz))
 n=steps+1;f=[]
 for k in range(2):
  for i in range(steps):
   a=k*2*n+i;f.append((a,a+1,a+1+n,a+n) if k==0 else (a+n,a+1+n,a+1,a))
 for i in range(steps):f += [(i,2*n+i,2*n+i+1,i+1),(n+i+1,3*n+i+1,3*n+i,n+i)]
 f.extend([(0,n,3*n,2*n),(n-1,3*n-1,4*n-1,2*n-1)])
 return mesh(name,v,f,tile)

def annulus(name,center,ro,ri,depth,tile=6,n=18,axis='Y'):
 x,y,z=center
 return tube(name,(x,y-depth/2,z),(x,y+depth/2,z),ro,ro-ri,tile,n) if axis=='Y' else tube(name,(x,y,z-depth/2),(x,y,z+depth/2),ro,ro-ri,tile,n)

def plankwall(name,x0,x1,y,z0,z1,tile=3,step=.22):
 n=max(1,round((x1-x0)/step))
 for i in range(n):box(name,(x0+(i+.5)*(x1-x0)/n,y,(z0+z1)/2),((x1-x0)/n-.008,.075,z1-z0),tile,.005)

def window(name,x,y,z,w=.68,h=.58):
 box(name+' deep frame',(x,y,z),(w+.11,.10,h+.11),3,.016)
 box(name+' blue dark glass',(x,y+.064,z),(w,.018,h),0,.002)
 for xx in [-w/2,w/2,0]:box(name+' mullion',(x+xx,y+.084,z),(.038,.03,h+.05),8,.003)
 for zz in [-h/2,h/2]:box(name+' rail',(x,y+.085,z+zz),(w+.075,.035,.045),8,.003)
 box(name+' sill',(x,y+.14,z-h/2-.05),(w+.16,.25,.05),3,.005)

def build_house():
 reset();ground(3.2,3.2)
 for x in [-1.20,1.20]:
  for y in [-1.16,.59]:box('Stone pier',(x,y,.20),(.38,.42,.25),10,.035)
 box('Reclaimed timber house floor',(0,-.28,.33),(2.67,2.05,.17),3,.025)
 box('Surviving plaster rear',(0,-1.23,1.22),(2.56,.10,1.66),15,.018)
 for x in [-1.27,1.27]:box('Patched civilian wall',(x,-.30,1.20),(.12,1.88,1.70),15,.018)
 # Door opening is real, with distinct teal inset and lighter domestic window.
 box('Left front wall',(-.80,.66,1.22),(.96,.10,1.74),15,.008)
 box('Right front wall',(.98,.66,1.22),(.61,.10,1.74),15,.008)
 box('Door lintel',(.24,.66,1.99),(1.05,.12,.20),3,.014)
 box('Teal salvaged front door',(.22,.685,1.13),(.81,.065,1.54),5,.016)
 for z in [.72,1.18,1.61]:box('Door panel rail',(.22,.73,z),(.73,.045,.045),3,.006)
 cyl('Door handle',(.49,.766,1.18),.036,.044,7,(math.pi/2,0,0),n=8)
 window('Front family window',-.80,.734,1.37,.65,.58)
 # Modest boarding only on the lower, damaged wall. No military armor plates.
 for z in [.47,.65,.83]:
  box('Civilian repair boards left',(-1.344,-.35,z),(.04,1.76,.15),3,.005)
  box('Back repair boards',(0,-1.30,z),(2.56,.035,.15),3,.005)
 for x,y in [(-1.29,-1.19),(1.29,-1.19),(-1.29,.68),(1.29,.68)]:box('Corner timber batten',(x,y,1.24),(.10,.10,1.84),3,.008)
 # Low uneven gable with a single large replacement sheet and fabric repair.
 for y in [-1.26,.71]:plate('Gable timber infill',[(-1.31,2.08),(1.31,2.08),(.02,2.59)],y,.08,3,.006)
 roof=lambda x,y:2.63-abs(x-.02)*.37
 sheet('Old sage roof',-1.45,.02,-1.42,.92,roof,5,24)
 sheet('Slate replacement roof',.02,1.45,-1.42,.92,roof,0,24)
 sheet('Broad canvas leak repair',-.95,-.17,-.66,.35,lambda x,y:roof(x,y)+.035,4,2)
 for y in [-1.43,.93]:
  squarebeam('Gable roof fascia',(-1.46,y,roof(-1.46,y)),(.02,y,2.65),.065,.08,3)
  squarebeam('Gable roof fascia',(.02,y,2.65),(1.46,y,roof(1.46,y)),.065,.08,3)
 tube('Roof ridge gutter',(.02,-1.43,2.65),(.02,.96,2.65),.058,.02,2,n=8)
 cyl('Small stove flue',(.78,-.73,2.45),.07,.55,9,n=10)
 cyl('Stove rain cap',(.78,-.73,2.755),.14,.035,2,n=10)
 # Domestic front porch and awning in a warm patched textile.
 for i in range(9):box('Porch deck board',(-1.20+i*.30,1.08,.20),(.285,.88,.11),3,.007)
 box('Single porch step',(0,1.46,.125),(1.31,.28,.09),3,.012)
 for x in [-1.23,1.23]:squarebeam('Awning domestic post',(x,1.40,.20),(x,1.40,1.95),.085,.085,3)
 sheet('Porch canvas awning',-1.34,1.34,.72,1.43,lambda x,y:2.07-(y-.72)*.19,4,4)
 for x in [-1.28,1.28]:squarebeam('Awning rail',(x,.72,2.07),(x,1.45,1.93),.055,.055,3)
 # Rain barrel, stool and planter make occupation readable even from far away.
 barrel('Domestic rain barrel',(-1.22,-.90,.43),.20,.61,5)
 box('Front porch stool',(-.94,1.08,.50),(.36,.32,.065),3,.012)
 for x in [-1.06,-.82]:box('Stool legs',(x,1.08,.355),(.055,.26,.28),3,.008)
 box('Kitchen planter',(.97,1.15,.37),(.36,.29,.26),3,.018)
 for i in range(5):leaf('Kitchen herbs',(.98,1.15,.55),.22,.075,i*math.tau/5,13)
 export_asset('house')

def build_depot():
 reset();ground(3.6,3.2)
 for x in [-1.49,1.49]:
  for y in [-1.20,1.19]:
   box('Post shoe',(x,y,.18),(.28,.28,.20),10,.02);squarebeam('Warehouse reclaimed post',(x,y,.26),(x,y,2.38 if y<0 else 2.10),.13,.13,3)
 plankwall('Depot rear pallet boards',-1.48,1.48,-1.21,.30,1.84,3,.24)
 for z in [.50,1.55]:box('Rear pallet cross bearer',(0,-1.28,z),(3.06,.085,.09),1,.005)
 for y in [-1.16,1.18]:squarebeam('Depot high cross rail',(-1.58,y,2.45 if y<0 else 2.16),(1.58,y,2.45 if y<0 else 2.16),.12,.13,3)
 sheet('Oxide shed lean-to roof',-1.72,1.72,-1.43,1.40,lambda x,y:2.52-(y+1.43)*.112,1,44)
 for x in [-1.73,1.73]:squarebeam('Shed roof end rail',(x,-1.43,2.54),(x,1.42,2.22),.065,.065,2)
 for x in [-1.48,1.48]:
  squarebeam('Diagonal corner brace',(x,-1.17,1.79),(x,-.52,2.34),.07,.07,3)
  squarebeam('Front timber knee brace',(x,1.17,1.52),(x*.66,1.17,2.16),.08,.08,3)
 # Open pallets make a visible supply depot, not another enclosed workshop.
 for xx,yy in [(-.90,-.55),(.24,-.72)]:
  for i in range(5):box('Shipping pallet top',(xx-.40+i*.20,yy,.25),(.17,.78,.06),3,.004)
  for xx2 in [-.33,.33]:box('Pallet bearer',(xx+xx2,yy,.165),(.11,.76,.11),3,.006)
 for name,loc,scl in [('Large store crate',(-.91,-.59,.64),(.91,.73,.73)),('Upper salvaged crate',(-.91,-.58,1.25),(.72,.64,.48)),('Store crate middle',(.18,-.69,.58),(.73,.69,.64)),('Store crate top',(.28,-.70,1.10),(.62,.55,.40)),('Forward box',(-.89,.51,.43),(.71,.65,.64))]:crate(name,loc,scl)
 for z in [.57,1.24]:box('Heavy crate label',(-.92,-.208,z),(.26,.017,.13),8,.002)
 for xx in [.83,1.27]:
  for yy in [-.64,-.10]:bag('Folded canvas provision sack',(xx,yy,.33),(.47,.44,.38),.15)
 bag('Provision sack upper',(1.02,-.34,.64),(.55,.41,.36),-.2)
 barrel('Reserve water drum',(1.12,.61,.49),.24,.80,5)
 # Front handcart, kept inside the construction footprint.
 box('Handcart loading tray',(.12,.86,.27),(.62,.66,.08),1,.016)
 for x in [-.18,.42]:
  cyl('Handcart wheel',(x,.88,.19),.15,.10,6,(0,math.pi/2,0),n=12)
  squarebeam('Handcart upright',(x,.59,.25),(x,.35,1.20),.055,.055,2)
 beam('Handcart push grip',(-.18,.35,1.20),(.42,.35,1.20),.03,6)
 # Big crate glyph on a plain front board, physically legible at normal RTS size.
 box('Depot hanging sign',(0,1.21,1.95),(.70,.08,.37),0,.012)
 for x in [-.22,.22]:box('Sign crate upright',(x,1.26,1.95),(.036,.018,.22),8,.002)
 for z in [1.84,2.06]:box('Sign crate rail',(0,1.26,z),(.48,.018,.028),8,.002)
 squarebeam('Sign crate diagonal',(-.20,1.28,1.85),(.20,1.28,2.05),.025,.018,8)
 export_asset('depot')

def canvas_roof(name,w,d,yc,zridge,zeave):
 # Asymmetric stretched fabric with slight broad sag, with true thickness.
 nx=16;ny=6;v=[]
 for off in [0,-.028]:
  for j in range(ny+1):
   yy=yc-d/2+d*j/ny
   for i in range(nx+1):
    xx=-w/2+w*i/nx
    z=zridge-(abs(xx)/(w/2))*(zridge-zeave)-.045*math.sin(math.pi*j/ny)*math.sin(math.pi*abs(xx)/(w/2))
    v.append((xx,yy,z+off))
 N=(nx+1)*(ny+1);f=[]
 for l in [0,1]:
  for j in range(ny):
   for i in range(nx):
    a=l*N+j*(nx+1)+i;f.append((a,a+1,a+nx+2,a+nx+1) if l==0 else (a+nx+1,a+nx+2,a+1,a))
 for j in range(ny):
  for i in [0,nx]:a=j*(nx+1)+i;b=(j+1)*(nx+1)+i;f.append((a,b,b+N,a+N))
 for j in [0,ny]:
  for i in range(nx):a=j*(nx+1)+i;f.append((a,a+N,a+N+1,a+1))
 mesh(name,v,f,4)

def build_barracks():
 reset();ground(4.8,4.4)
 # Rear civilian tarp sleeping/training shelter, with a large open front apron.
 for x in [-1.95,1.95]:
  for y in [-1.70,.34]:
   box('Training shelter post footing',(x,y,.15),(.26,.28,.14),10,.02)
   squarebeam('Tarp corner pole',(x,y,.21),(x,y,2.12),.095,.095,3)
 for y in [-1.75,.35]:squarebeam('Raised center pole',(0,y,.18),(0,y,2.88),.11,.11,3)
 squarebeam('Canopy ridge', (0,-1.84,2.88),(0,.46,2.88),.095,.095,3)
 canvas_roof('Survivor canvas training shelter',4.20,2.56,-.63,2.91,2.14)
 for y in [-1.9,.65]:
  squarebeam('Canvas edge binding',(-2.11,y,2.14),(0,y,2.91),.035,.035,8)
  squarebeam('Canvas edge binding',(0,y,2.91),(2.11,y,2.14),.035,.035,8)
 for x in [-1.95,1.95]:
  rope('Shelter guy rope',[(x,.34,2.14),(x*1.10,.86,1.05),(x*1.13,1.20,.16)],.016,4)
  box('Canvas ground peg',(x*1.13,1.20,.17),(.05,.06,.23),2,.004)
 plankwall('Low pallet windbreak',-1.94,1.94,-1.72,.20,1.20,3,.26)
 for x in [-1.67,-1.10,-.53]:
  box('Reclaimed civilian locker',(x,-1.35,1.00),(.47,.54,1.62),5,.022)
  box('Locker door recess',(x,-1.065,1.02),(.40,.025,1.46),0,.004)
  box('Locker handle',(x+.12,-1.038,1.05),(.04,.03,.20),7,.004)
  for z in [1.48,1.56,1.64]:box('Locker vent',(x,-1.046,z),(.24,.014,.026),9,.001)
 # Shared table and rolled bedding identify improvised survivor training quarters.
 box('Trestle training table',(.85,-1.11,.81),(1.32,.66,.09),3,.02)
 for x in [.33,1.37]:
  squarebeam('Table trestle',(x,-1.36,.20),(x,-.91,.79),.07,.07,3)
  squarebeam('Table trestle',(x,-.91,.20),(x,-1.36,.79),.07,.07,3)
 box('Shared map board',(.85,-1.12,.868),(.72,.45,.022),8,.005)
 for x in [.48,1.04,1.53]:cyl('Rolled bed mat',(x,-.55,.35),.19,.47,4,(math.pi/2,0,0),n=12)
 # Freestanding practice targets, deliberately civilian scrap with painted circles.
 for x,yy,r in [(-1.12,1.16,.38),(.15,1.48,.33)]:
  squarebeam('Target stand upright',(x,yy,.18),(x,yy,1.80),.08,.09,3)
  squarebeam('Target tripod left',(x-.43,yy+.12,.13),(x,yy,1.22),.065,.07,3)
  squarebeam('Target tripod right',(x+.43,yy+.12,.13),(x,yy,1.22),.065,.07,3)
  cyl('Salvaged timber target',(x,yy,1.65),r,.09,3,(math.pi/2,0,0),n=20)
  annulus('Painted target ring',(x,yy+.057,1.65),r*.80,r*.65,.008,8,20)
  annulus('Target inner ring',(x,yy+.064,1.65),r*.40,r*.25,.008,1,20)
  cyl('Target center',(x,yy+.071,1.65),r*.10,.012,8,(math.pi/2,0,0),n=12,bevel=0)
 # Hanging tire and hand-sewn punching bag occupy the opposite apron.
 for x in [1.09,2.03]:squarebeam('Practice frame upright',(x,1.30,.15),(x,1.30,2.31),.11,.11,3)
 squarebeam('Practice frame crossbar',(1.01,1.30,2.33),(2.11,1.30,2.33),.13,.13,3)
 rope('Tire suspension',[(1.36,1.30,2.30),(1.36,1.30,1.90),(1.36,1.30,1.64)],.018,9)
 annulus('Hanging reclaimed tire',(1.36,1.30,1.32),.34,.21,.20,6,18)
 rope('Punching bag suspension',[(1.86,1.30,2.30),(1.86,1.30,1.99)],.02,4)
 cyl('Training canvas bag',(1.86,1.30,1.56),.16,.77,1,n=12,bevel=.045)
 for z in [1.31,1.82]:cyl('Punch bag canvas binding',(1.86,1.30,z),.168,.05,4,n=12,bevel=0)
 export_asset('barracks')

def build_vehicle_workshop():
 reset();ground(5.2,4.8)
 box('Repair bay concrete pad',(0,-.18,.16),(4.85,4.22,.16),10,.025)
 for x in [-2.10,2.10]:
  for y in [-1.86,1.43]:
   box('Garage foot',(x,y,.30),(.31,.36,.20),1,.025)
   profile_beam('Reclaimed industrial bay post',(x,y,.38),(x,y,2.88),.17,.19,.037,0)
 # Low patchwork cladding preserves visibility of the repair equipment.
 box('Garage back wall',(0,-1.95,1.42),(4.30,.075,2.43),0,.018)
 for i in range(24):box('Rear sheet corrugation',(-2.06+i*.18,-2.0,1.42),(.040,.035,2.37),5 if i%8<3 else 0,.002)
 box('Garage low side wall',(-2.15,-.37,.85),(.065,3.12,1.35),5,.012)
 box('Garage side patch panel',(2.15,-1.28,1.19),(.07,1.22,1.98),1,.012)
 # Broad shallow barrel roof; unlike ammo workshop's tall gable roof.
 roof=lambda x,y:2.88+.45*math.sqrt(max(0,1-(x/2.35)**2))
 sheet('Repair garage broad curved roof',-2.35,2.35,-2.17,1.72,roof,0,64)
 for y in [-2.18,1.73]:
  for i in range(16):
   x=-2.35+4.7*i/16;xx=-2.35+4.7*(i+1)/16
   squarebeam('Curved roof edge', (x,y,roof(x,y)),(xx,y,roof(xx,y)),.050,.055,2)
 for x in [-2.28,2.28]:profile_beam('Open repair bay eave',(x,-2.0,2.90),(x,1.58,2.90),.13,.16,.028,2)
 # Heavy red gantry at the entrance; front service area extends beyond the roof.
 for x in [-1.73,1.73]:
  profile_beam('Engine lift independent post',(x,1.68,.22),(x,1.68,2.90),.14,.18,.03,1)
  box('Hoist ground runner',(x,1.68,.26),(.45,.69,.12),1,.022)
 profile_beam('Orange engine lifting gantry',(-1.91,1.68,2.92),(1.91,1.68,2.92),.20,.29,.04,1)
 box('Chain block trolley',(.57,1.68,2.72),(.32,.28,.25),7,.025)
 for x in [.47,.66]:rope('Engine chain',[(x,1.68,2.62),(x,1.68,1.77),(x,1.69,1.36)],.022,9)
 # Bent open hook made from thick steel, not a closed decorative ring.
 pts=[(.57,1.69,1.58),(.43,1.69,1.37),(.48,1.69,1.20),(.65,1.69,1.18),(.74,1.69,1.31)]
 rope('Engine hoist open hook',pts,.045,2)
 # Low incomplete car chassis inside gives an immediate vehicle-repair read.
 for x in [-.50,.50]:profile_beam('Rolling chassis rail',(x,-.97,.61),(x,.87,.61),.12,.14,.025,9)
 for y in [-.74,.65]:
  beam('Exposed chassis axle',(-.87,y,.51),(.87,y,.51),.065,2)
  for x in [-.80,.80]:
   o=annulus('Repair chassis wheel',(0,0,0),.38,.22,.22,6,18)
   o.rotation_euler.z=math.pi/2;o.location=(x,y,.58)
   cyl('Chassis wheel steel hub',(x,y,.58),.205,.225,2,(0,math.pi/2,0),n=12)
 box('Open engine block',(.0,-.38,.85),(.65,.75,.39),0,.06)
 for y in [-.62,-.38,-.14]:
  cyl('Engine rocker detail',(.0,y,1.08),.12,.53,2,(0,math.pi/2,0),n=8,bevel=.005)
 box('Raised vehicle bonnet',(-.02,-1.09,1.20),(1.25,.85,.065),5,.025,rot=(.70,0,0))
 squarebeam('Bonnet stay',(.55,-.91,.74),(.55,-1.29,1.44),.03,.03,2)
 # Full-height salvage workbench, tires, and wheels fill asymmetric side bays.
 box('Repair workbench',(-1.60,-.83,1.00),(.67,1.77,.10),3,.022)
 for y in [-1.55,-.09]:
  for x in [-1.87,-1.34]:box('Workbench leg',(x,y,.62),(.08,.08,.70),0,.008)
 box('Workshop tool chest',(-1.63,-1.1,.67),(.57,.68,.58),1,.025)
 for z in [.49,.68,.87]:box('Tool chest drawer handle',(-1.28,-1.10,z),(.06,.43,.035),2,.005)
 box('Large bench vise',(-1.59,-.30,1.19),(.38,.30,.25),2,.018)
 beam('Vise spindle',(-1.92,-.30,1.18),(-1.30,-.30,1.18),.03,9)
 for z in [.42,.69, .96]:annulus('Stacked spare tires',(1.62,-1.34,z),.38,.23,.24,6,18,axis='Z')
 barrel('Waste oil drum',(1.69,-.46,.57),.27,.72,0)
 box('Portable floor jack',(-1.36,1.25,.32),(.45,.69,.14),1,.026)
 squarebeam('Floor jack raised arm',(-1.36,1.08,.39),(-1.36,.68,.62),.14,.13,2)
 beam('Long floor jack handle',(-1.36,1.46,.35),(-1.36,1.97,.95),.03,2)
 # Broad warning bands are geometry, not unreadable text.
 for x in [-2.09,2.09]:
  box('Garage post guard',(x,1.46,.70),(.23,.16,.71),11,.015)
 # Visible hanging repair sign with wrench profile.
 box('Civilian repair sign',(-.88,1.78,2.64),(.77,.07,.32),5,.015)
 squarebeam('Repair sign wrench shaft',(-1.08,1.83,2.55),(-.72,1.83,2.71),.05,.015,8)
 annulus('Repair sign open jaw impression',(-.72,1.83,2.71),.105,.058,.018,8,10)
 export_asset('vehicle_workshop')

def leaf(name,loc,length,width,ang,tile=13,rise=.17):
 # Thick folded broad leaves, not alpha cards, for stable mobile silhouettes.
 x,y,z=loc;d=Vector((math.cos(ang),math.sin(ang),0));p=Vector((-d.y,d.x,0));a=Vector((x,y,z));tip=a+d*length+Vector((0,0,rise));mid=a+d*length*.52+Vector((0,0,rise*.65))
 vs=[a,mid+p*width,tip,mid-p*width,mid+Vector((0,0,width*.34))]
 v=[tuple(q) for q in vs]+[tuple(q-Vector((0,0,.012))) for q in vs]
 f=[(0,1,4),(1,2,4),(2,3,4),(3,0,4),(5,9,6),(6,9,7),(7,9,8),(8,9,5),(0,5,6,1),(1,6,7,2),(2,7,8,3),(3,8,5,0)]
 return mesh(name,v,f,tile)

def plant(x,y,z,scale=1,kind=0):
 if kind==0:
  for j in range(2):
   for i in range(7):leaf('Broad food greens',(x,y,z+j*.10*scale),(.26-j*.065)*scale,.087*scale,i*math.tau/7+j*.39,13 if i%4 else 5,(.13+j*.055)*scale)
  cyl('Vegetable leaf heart',(x,y,z+.14*scale),.065*scale,.19*scale,13,n=7,bevel=.02)
 else:
  beam('Food plant stalk',(x,y,z),(x,y,z+.56*scale),.018,13,6)
  for j in range(3):
   for k in range(3):leaf('Staked vegetable leaf',(x,y,z+(.12+j*.14)*scale),.23*scale,.057*scale,k*math.tau/3+j*.55,13,.08*scale)
  for dx,dy,dz in [(.07,.05,.34),(-.09,-.04,.46),(.04,-.10,.23)]:
   bpy.ops.mesh.primitive_uv_sphere_add(segments=8,ring_count=4,radius=.065*scale,location=(x+dx*scale,y+dy*scale,z+dz*scale));finish(bpy.context.object,'Ripening food fruit',14)

def build_garden():
 reset();ground(4,4)
 for x in [-1.26,0,1.26]:
  box('Raised food bed rich earth',(x,-.12,.24),(.90,2.97,.30),12,.035)
  for xx in [x-.49,x+.49]:
   for z in [.16,.31]:box('Garden salvaged timber side',(xx,-.12,z),(.09,3.12,.135),3,.011)
  for yy in [-1.68,1.44]:
   for z in [.16,.31]:box('Garden end board',(x,yy,z),(.98,.09,.135),3,.009)
  for xx in [x-.46,x+.46]:
   for yy in [-1.58,1.35]:box('Garden corner stake',(xx,yy,.30),(.075,.075,.44),3,.009)
  for j in range(6):
   yy=-1.39+j*.48
   plant(x+(-.12 if j%2 else .12),yy,.39,.80 if x<.1 else .92,0 if x<.1 else 1)
 # Low back trellis stays within the 1.2m high footprint.
 for x in [-1.75,-.63,.63,1.75]:squarebeam('Low garden trellis stake',(x,-1.72,.08),(x,-1.72,1.13),.055,.055,3)
 for z in [.60,.96]:beam('Garden support twine',(-1.75,-1.73,z),(1.75,-1.73,z),.014,4,6)
 # Front-edge watering can and tool storage.
 cyl('Watering can body',(-.46,1.74,.28),.17,.32,5,n=12)
 tube('Watering can spout',(-.33,1.72,.28),(-.03,1.72,.43),.033,.012,2,n=8)
 rope('Watering can handle',[(-.55,1.76,.39),(-.63,1.76,.58),(-.45,1.76,.62),(-.36,1.76,.44)],.022,2)
 box('Garden harvested produce box',(.60,1.73,.24),(.50,.36,.26),3,.012)
 for i in range(5):
  bpy.ops.mesh.primitive_uv_sphere_add(segments=8,ring_count=4,radius=.095,location=(.45+i%3*.14,1.69+(i//3)*.12,.39));finish(bpy.context.object,'Harvested squash',14)
 beam('Small spade handle',(1.41,1.58,.10),(1.58,1.71,.72),.024,3,8)
 box('Small garden spade',(1.41,1.58,.12),(.16,.035,.22),2,.018,rot=(.2,0,-.4))
 export_asset('garden')

for fn in [build_house,build_depot,build_barracks,build_vehicle_workshop,build_garden]:fn()
(ROOT/'reports'/'asset_stats.json').write_text(json.dumps(stats,indent=2))
print('SETTLEMENT_ASSETS_BUILT',flush=True)
