"""RECLAMATION original survivor fleet. Blender 4.3.2, Z-up authoring / -Z Godot forward.
All geometry authored here; tiles are original deterministic raster/PBR materials.
"""
import bpy, math, random, json
from mathutils import Vector
from pathlib import Path
P=Path(__file__).resolve().parent.parent
random.seed(810)
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

def wheel(s,y):
 x=s*.775;z=.42
 profile=[(-.13,.22),(-.145,.27),(-.125,.35),(-.084,.382),(.084,.382),(.125,.35),(.145,.27),(.13,.22)]
 ring('All terrain rubber tire',(x,y,z),profile,3,28)
 for row in [-1,1]:
  for i in range(20):
   a=math.tau*i/20+(row+1)*.037;cy=y+math.cos(a)*.384;cz=z+math.sin(a)*.384
   box('Raised staggered tire tread',(x+row*.048,cy,cz),(.084,.102,.021),3,0,(a-math.pi/2,0,row*.13))
 # Hollow stamped steel rim with concentric shoulder and recessed black hub.
 ring('Pressed wheel rim',(x+s*.114,y,z),[(-.022,.10),(-.022,.197),(-.008,.219),(.029,.207),(.03,.171),(.0,.16),(.0,.10)],8,20)
 cyl('Recessed axle hub',(x+s*.124,y,z),.108,.053,14,'X',16,.007)
 cyl('Axle dust cap',(x+s*.16,y,z),.057,.032,8,'X',12,.003)
 for k in range(6):
  a=math.tau*k/6;cyl('Wheel lug',(x+s*.155,y+math.cos(a)*.081,z+math.sin(a)*.081),.012,.018,15,'X',6,0)
 for k in range(6):
  a=math.tau*k/6+.3;cyl('Recessed rim ventilation',(x+s*.153,y+math.cos(a)*.144,z+math.sin(a)*.144),.022,.008,11,'X',8,0)

def wheel_arch(s,y,tile):
 vs=[];n=15
 for x in [s*.68,s*.868]:
  for r in [.410,.456]:
   for i in range(n):a=math.radians(12+156*i/(n-1));vs.append((x,y+math.cos(a)*r,.42+math.sin(a)*r))
 fs=[]
 # Four walls of bent sheet steel arch.
 for i in range(n-1):
  for a,b in [(0,1),(1,3),(3,2),(2,0)]:fs.append((a*n+i,a*n+i+1,b*n+i+1,b*n+i))
 fs += [(0,n,3*n,2*n),(n-1,2*n-1,4*n-1,3*n-1)]
 mesh('Hand repaired steel wheel arch',vs,fs,tile)
 for dy in [-.43,.43]:box('Arch rivet',(s*.875,y+dy,.56),(.022,.03,.03),8,.003)
 # Torn rubber mud flap, visibly behind wheel.
 panel('Hanging flexible mud flap',[(s*.67,y-.41,.54),(s*.88,y-.41,.54),(s*.88,y-.43,.22),(s*.68,y-.44,.25)],3,.012)

def crate(loc,size=(.47,.46,.41),tile=4):
 x,y,z=loc;w,d,h=size
 box('Salvage wooden supply crate',loc,size,tile,.016)
 for sx in [-1,1]:
  for j in [-1,1]:box('Crate reinforcement batten',(x+sx*(w/2+.008),y+j*d*.32,z),(.028,d*.12,h*1.02),4,.003)
 for sy in [-1,1]:
  for k in [-1,1]:box('Crate face wood brace',(x+k*w*.32,y+sy*(d/2+.008),z),(w*.10,.026,h*1.015),4,.004)
 for k in [-1,1]:box('Crate retaining metal band',(x+k*w*.27,y,z+h/2+.009),(.035,d+.035,.019),8,.003)

def jerrycan(loc,tile=6,ang=0):
 x,y,z=loc;o=box('Repurposed water can',loc,(.22,.17,.32),tile,.028,(0,0,ang))
 box('Water can shoulder',(x,y,z+.16),(.18,.145,.045),tile,.012)
 for xx in [-.060,.060]:beam('Water can handle support',(x+xx,y,z+.18),(x+xx,y,z+.23),.016,tile)
 beam('Water can carry handle',(x-.06,y,z+.23),(x+.06,y,z+.23),.016,tile)
 cyl('Water can cap',(x+.077,y,z+.195),.029,.024,8,verts=12,bevel=.003)
 for s in [-1,1]:
  beam('Stamped reinforcement',(x-.075,y+s*.087,z-.09),(x+.075,y+s*.087,z+.09),.008,8)
  beam('Stamped reinforcement',(x+.075,y+s*.087,z-.09),(x-.075,y+s*.087,z+.09),.008,8)

def barrel(loc):
 x,y,z=loc;cyl('Reclaimed small water barrel',loc,.20,.48,0,verts=20,bevel=.01)
 for dz in [-.18,.18]:cyl('Barrel rolled rim',(x,y,z+dz),.211,.022,8,verts=20,bevel=.003)
 cyl('Barrel sealed fill cap',(x+.09,y,z+.245),.035,.025,8,verts=12,bevel=.002)

def cloth(name,x0,x1,y0,y1,z,tile=12):
 nx=12;ny=9;vs=[]
 for j in range(ny):
  v=j/(ny-1)
  for i in range(nx):
   u=i/(nx-1);xx=x0+(x1-x0)*u;yy=y0+(y1-y0)*v
   zz=z+.06*math.sin(u*math.pi)-.12*abs(u-.5)**1.6 +.018*math.sin(6*math.pi*u+v*3)+.012*math.cos(v*5*math.pi+u*8)
   if i in [0,nx-1]:zz-=.12+.04*math.sin(v*math.pi*3)
   vs.append((xx,yy,zz))
 fs=[]
 for j in range(ny-1):
  for i in range(nx-1):a=j*nx+i;fs.append((a,a+1,a+nx+1,a+nx))
 o=mesh(name,vs,fs,tile,smooth=True)
 # Continuous fabric UV across the whole tailored cloth.
 for po in o.data.polygons:
  for li in po.loop_indices:
   ind=o.data.loops[li].vertex_index;uv=(ind%nx/(nx-1),ind//nx/(ny-1));o.data.uv_layers.active.data[li].uv=((tile%4+.03+.94*uv[0])/4,(3-tile//4+.03+.94*uv[1])/4)
 solid=o.modifiers.new('Heavy canvas thickness','SOLIDIFY');solid.thickness=.012;bpy.context.view_layer.objects.active=o;bpy.ops.object.modifier_apply(modifier=solid.name)
 for i in [0,nx-1]:curve_beam('Stitched canvas edge',[vs[j*nx+i] for j in range(ny)],.009,7)
 return vs

def text(name,body,loc,size,rot,tile=2):
 bpy.ops.object.text_add(location=loc,rotation=rot);o=bpy.context.object;o.data.body=body;o.data.size=size;o.data.extrude=.001;o.data.resolution_u=3;o.data.space_character=1.0
 bpy.ops.object.convert(target='MESH');return finish(bpy.context.object,name,tile)

def cab(variant):
 paint=0 if variant=='supply' else 2; accent=6 if variant=='supply' else 13
 # Strong custom faceted cab-over body, with sloped glass and chamfered roof.
 box('Ladder chassis',(0,-.015,.49),(1.42,3.08,.15),14,.021)
 for x in [-.49,.49]:box('Load bearing chassis rail',(x,-.02,.42),(.10,2.91,.16),1,.007)
 for yy in [-1.,1.]:
  beam('Exposed drive axle',(-.73,yy,.42),(.73,yy,.42),.075,14,12)
  for s in [-1,1]:
   beam('Leaf spring suspension',(s*.51,yy-.31,.45),(s*.51,yy+.31,.45),.025,8)
   wheel(s,yy);wheel_arch(s,yy,paint)
 # Cab volume is an authored trapezoid rather than a box.
 verts=[(-.70,.30,.77),(.70,.30,.77),(.71,1.53,.77),(-.71,1.53,.77),(-.68,.30,1.50),(.68,.30,1.50),(.64,1.07,1.50),(-.64,1.07,1.50),(-.69,1.31,1.10),(.69,1.31,1.10)]
 mesh('Fabricated cab shell',verts,[(0,3,2,1),(0,1,5,4),(4,5,6,7),(7,6,9,8),(8,9,2,3),(0,4,7,8,3),(1,2,9,6,5)],paint,.012)
 box('Raised rounded cab roof',(0,.70,1.551),(1.47,.90,.098),paint,.036)
 # Sloped windscreen plus cream surround and center pillar.
 panel('Windscreen rubber seal',[(-.659,1.334,1.095),(.659,1.334,1.095),(.61,1.091,1.510),(-.61,1.091,1.510)],3,.015)
 panel('Dusty split windscreen',[(-.604,1.343,1.143),(.604,1.343,1.143),(.563,1.126,1.465),(-.563,1.126,1.465)],5,.013)
 beam('Center windscreen pillar',(0,1.349,1.12),(0,1.115,1.48),.018,paint)
 for xx in [-.29,.29]:
  beam('Windshield wiper',(xx,1.347,1.145),(xx+.17,1.276,1.259),.007,14)
  beam('Wiper blade',(xx+.13,1.297,1.232),(xx+.22,1.247,1.310),.010,14)
 # low nose, radiator opening and steel emergency bumper
 box('Engine nose panel',(0,1.551,.906),(1.43,.29,.31),paint,.025)
 box('Weathered bonnet lip',(0,1.52,1.077),(1.46,.39,.061),accent,.014)
 box('Radiator deep inset',(0,1.708,.885),(.81,.02,.202),11,.007)
 for x in [-.32,-.24,-.16,-.08,0,.08,.16,.24,.32]:box('Radiator grille vertical fin',(x,1.726,.885),(.023,.022,.184),8,.003)
 for s in [-1,1]:
  box('Headlight metal housing',(s*.553,1.716,.959),(.241,.060,.206),8,.027)
  box('Headlight amber glass',(s*.553,1.752,.959),(.183,.023,.147),10,.022)
  box('Small turn lamp',(s*.603,1.738,.784),(.10,.026,.06),6,.008)
 box('Battered front bumper',(0,1.795,.599),(1.70,.18,.13),8,.018)
 for s in [-1,1]:box('Bumper end pad',(s*.747,1.802,.600),(.13,.195,.142),14,.015)
 box('Bumper plate backing',(0,1.894,.596),(.38,.012,.09),14,.003)
 # Civilian door panels, mismatched repair, handles, steps, mirrors.
 for s in [-1,1]:
  panel('Door shut line',[(s*.717,.337,.84),(s*.717,.879,.84),(s*.717,1.108,1.112),(s*.717,.337,1.474)],14,.012)
  panel('Repaired cab door',[(s*.729,.366,.87),(s*.729,.857,.87),(s*.729,1.081,1.108),(s*.729,.366,1.443)],accent if s==-1 else paint,.016)
  panel('Side window seal',[(s*.735,.385,1.145),(s*.735,.974,1.145),(s*.735,1.052,1.276),(s*.735,.385,1.468)],3,.015)
  panel('Side window glass',[(s*.750,.430,1.190),(s*.750,.944,1.190),(s*.750,1.003,1.276),(s*.750,.430,1.417)],5,.012)
  beam('Side window front divider',(s*.760,.862,1.19),(s*.760,.861,1.356),.012,paint)
  box('Recessed door handle',(s*.756,.464,1.086),(.039,.121,.041),14,.005)
  box('Door foot step',(s*.764,.457,.656),(.20,.39,.052),8,.01)
  for yy in [.32,.43,.54,.65]:box('Step traction slit',(s*.77,yy,.686),(.15,.017,.007),14,0)
  beam('Mirror stalk',(s*.739,1.166,1.178),(s*.843,1.198,1.303),.012,8)
  box('Truck wing mirror housing',(s*.855,1.198,1.325),(.062,.061,.168),14,.016)
  box('Mirror silver inset',(s*.886,1.198,1.325),(.009,.043,.129),5,.004)
  # Small irregular bolted door repair.
  panel('Scavenged door patch',[(s*.750,.49,.87),(s*.750,.77,.884),(s*.750,.754,1.012),(s*.750,.480,1.004)],1,.012)
  for yy,zz in [(.51,.901),(.725,.918),(.718,.984),(.515,.971)]:cyl('Repair plate rivet',(s*.765,yy,zz),.009,.012,8,'X',6,0)
 # Rear cab seam and truck fuel tank, pipe stops at original 2.06 m maximum.
 box('Rear cab window frame',(0,.277,1.278),(.80,.033,.30),3,.014)
 box('Rear cab window',(0,.255,1.278),(.713,.015,.224),5,.008)
 box('Fuel tank',(-.49,-.19,.536),(.29,.39,.23),14,.021)
 for x in [-.59,-.39]:box('Fuel tank strap',(x,-.19,.534),(.032,.409,.245),8,.003)
 curve_beam('Reclaimed exhaust pipe',[(.635,-.17,.49),(.635,-.23,.95),(.635,-.23,1.95),(.635,-.18,2.01)],.035,14)
 cyl('Exhaust outlet',(.635,-.18,2.025),.044,.041,8,verts=12,bevel=.003)
 box('Rear sill',(0,-1.456,.637),(1.51,.15,.11),8,.012)
 for s in [-1,1]:
  box('Rear red lamp',(s*.58,-1.55,.668),(.169,.032,.097),9,.009)
  box('Rear pale marker',(s*.40,-1.55,.668),(.083,.033,.07),10,.006)


def supply():
 cab('supply')
 box('Open load bed',(0,-.671,.776),(1.47,1.65,.105),4,.014)
 # rail body only to 1.21 m retains completely exposed cargo silhouette
 for s in [-1,1]:
  box('Pickup bed side panel',(s*.721,-.691,1.004),(.068,1.66,.376),0,.012)
  box('Bed top folded rim',(s*.729,-.699,1.207),(.09,1.695,.053),8,.013)
  for yy in [-1.408,-.86,-.29]:
   box('Riveted bed vertical',(s*.762,yy,1.01),(.034,.051,.392),1,.005)
   for zz in [.886,1.12]:cyl('Bed rivet',(s*.781,yy,zz),.012,.013,8,'X',6,0)
  # asymmetric planks replace a missing patch on one side
  if s==-1:
   for zz in [.93,1.05]:box('Bolted salvaged oak bed repair',(s*.776,-.719,zz),(.03,.50,.091),4,.006,(.035,0,0))
 box('Drop tailgate',(0,-1.513,1.009),(1.43,.066,.377),0,.014)
 for xx in [-.5,.5]:box('Tailgate hinge',(xx,-1.557,.843),(.16,.05,.036),8,.005)
 box('Tailgate latch',(0,-1.553,1.135),(.21,.028,.039),8,.004)
 # cargo shapes stay specific: open planked crate, water can, barrel, tarp roll.
 crate((-.315,-.72,1.043),(.52,.51,.43))
 crate((.307,-.915,1.05),(.50,.66,.44))
 crate((.323,-.91,1.353),(.41,.49,.166),4)
 barrel((-.325,-1.246,1.11))
 jerrycan((.18,-.22,.992),6);jerrycan((.47,-.24,.992),2)
 # A taut but lumpy partial load cover, with sagging edges and original cloth UVs.
 cloth('Rope-tied partial cargo tarp',-.65,.60,-1.46,-.53,1.548,12)
 for yy in [-1.30,-.70]:
  curve_beam('Cargo tiedown rope',[(-.764,yy,1.154),(-.57,yy,1.54),(0,yy,1.584),(.55,yy,1.54),(.764,yy,1.154)],.012,7)
 # yellow life-supply stripe provides thumbnail readability without military marking
 box('Civilian rescue strip',(.788,-.78,1.02),(.015,.58,.11),6,.002)
 # roof rack and rolled personal bedding, separate from truck cab.
 for xx in [-.46,.46]:beam('Roof luggage rack',(xx,.39,1.626),(xx,1.07,1.626),.022,8)
 for yy in [.39,.73,1.07]:beam('Roof crossbar',(-.55,yy,1.626),(.55,yy,1.626),.021,8)
 cyl('Rolled wool blanket',(-.12,.69,1.734),.109,.70,7,'X',20,.005)
 for xx in [-.33,.10]:cyl('Bedroll retaining strap',(xx,.69,1.734),.116,.025,14,'X',20,.002)
 # lettering on rear facing -Y, no third-party or real organizations
 text('Hand painted supply label','SUPPLY',(-.46,-1.553,1.011),.137,(math.pi/2,0,0),2)


def convoy():
 cab('convoy')
 box('Passenger platform',(0,-.665,.778),(1.47,1.65,.105),4,.014)
 # Hand-built tall enclosed passenger body with pitched bent sheet roof.
 box('Converted rear body',(0,-.644,1.255),(1.425,1.58,.893),2,.018)
 for s in [-1,1]:
  box('Lower red civilian stripe',(s*.727,-.65,1.022),(.024,1.58,.148),13,.004)
  for yy in [-1.36,-.70,-.05]:
   box('Old body panel seam',(s*.727,yy,1.269),(.029,.040,.87),8,.004)
   for zz in [.907,1.556]:cyl('Passenger body rivet',(s*.746,yy,zz),.011,.014,8,'X',6,0)
  for yy in [-1.027,-.383]:
   box('Deep passenger window seal',(s*.739,yy,1.444),(.045,.491,.314),3,.013)
   box('Passenger smoked window',(s*.767,yy,1.446),(.014,.43,.252),5,.008)
   box('Passenger window mullion',(s*.781,yy,1.446),(.021,.019,.268),2,.002)
  # coarse safety mesh diagonal braces over glass, clearly civilian improvised repair
  for yy in [-1.027,-.383]:
   beam('Window protective crosswire',(s*.786,yy-.185,1.332),(s*.786,yy+.185,1.563),.007,8)
   beam('Window protective crosswire',(s*.786,yy+.185,1.332),(s*.786,yy-.185,1.563),.007,8)
  panel('Lower body repair plate',[(s*.748,-1.29,.90),(s*.748,-.895,.884),(s*.748,-.91,1.103),(s*.748,-1.265,1.12)],1,.014)
 # Roof arc built as a single faceted customized shell; roof cargo stops below 2.06.
 vs=[];n=15
 for yy in [-1.465,.18]:
  for i in range(n):
   x=-.772+i*1.544/(n-1);z=1.731+.157*math.cos(x/.772*math.pi/2);vs.append((x,yy,z))
 faces=[(i,i+1,n+i+1,n+i) for i in range(n-1)]
 o=mesh('Arched canvas roof',vs,faces,7,smooth=True);solid=o.modifiers.new('Roof canvas thickness','SOLIDIFY');solid.thickness=.016;bpy.context.view_layer.objects.active=o;bpy.ops.object.modifier_apply(modifier=solid.name)
 for yy in [-1.44,-.67,.16]:
  curve_beam('Roof external securing ribs',[(vs[i][0],yy,vs[i][2]+.012) for i in range(n)],.016,8)
 # closed rear split doors, step and handholds
 box('Rear door jamb',(0,-1.452,1.243),(1.34,.072,.858),14,.014)
 for s in [-1,1]:
  box('Rear evacuation door',(s*.319,-1.499,1.243),(.611,.052,.821),2,.012)
  box('Rear door small glass',(s*.319,-1.535,1.454),(.365,.013,.245),5,.008)
  for zz in [1.047,1.422]:box('Door hinge',(s*.636,-1.540,zz),(.081,.035,.034),8,.003)
  beam('Door handle',(s*.098,-1.548,1.105),(s*.098,-1.548,1.28),.012,14)
 box('Retracted rear boarding step',(0,-1.487,.466),(.72,.175,.069),8,.012)
 for xx in [-.28,-.14,0,.14,.28]:box('Boarding step anti slip',(xx,-1.49,.504),(.025,.135,.008),14,0)
 # Field-made side canvas patch/tied rolled blankets evoke civilian evacuation.
 box('Side tied canvas bag',(-.790,-.739,1.096),(.132,.40,.22),12,.045)
 for yy in [-.875,-.606]:box('Canvas bag strap',(-.861,yy,1.096),(.014,.031,.228),7,.004)
 # Six modest bags on roof rather than giant block cargo.
 for x,y,sz in [(-.31,-.80,(.39,.39,.15)),(.19,-1.01,(.41,.31,.16)),(.26,-.53,(.32,.36,.14))]:
  zz=1.906;box('Personal roof luggage',(x,y,zz),sz,12 if x<0 else 7,.046,(0,0,.06 if x<0 else -.10))
  box('Roof bag strap',(x,y,zz+sz[2]/2+.004),(.025,sz[1]+.025,.02),14,.003)
 for yy in [-1.19,-.55]:
  curve_beam('Roof luggage webbing',[(-.75,yy,1.784),(-.35,yy,1.996),(.33,yy,1.996),(.75,yy,1.784)],.010,14)
 # Front sun visor and faded roofboard EVAC differentiate immediately.
 box('Front civilian roof marker',(0,.683,1.673),(.70,.10,.143),13,.014)
 text('Evacuation identifier','EVAC',(.262,.740,1.638),.114,(math.pi/2,0,math.pi),2)
 # Original back evacuation identifier.
 text('Rear homeward marking','HOME',(-.22,-1.547,.988),.118,(math.pi/2,0,0),13)


def sanitize_uv(o):
 # Decimation may extrapolate corner UVs; keep each triangle in its original atlas tile.
 uv=o.data.uv_layers.active
 for face in o.data.polygons:
  coords=[uv.data[k].uv.copy() for k in face.loop_indices]
  xs=sorted(max(0,min(3,int(q.x*4))) for q in coords);ys=sorted(max(0,min(3,int(q.y*4))) for q in coords)
  x=xs[len(xs)//2];y=ys[len(ys)//2]
  for k in face.loop_indices:
   q=uv.data[k].uv;q.x=max((x+.03)/4,min((x+.97)/4,q.x));q.y=max((y+.03)/4,min((y+.97)/4,q.y))

def build(kind):
 global mat,objects
 bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False);objects=[];mat=material()
 (supply if kind=='supply' else convoy)()
 # retain editable source objects and a combined one-surface export master
 col=bpy.data.collections.new('EDITABLE_COMPONENTS');bpy.context.scene.collection.children.link(col)
 for o in objects:
  for c in list(o.users_collection):c.objects.unlink(o)
  col.objects.link(o)
 bpy.ops.object.select_all(action='DESELECT')
 clones=[]
 for o in objects:
  q=o.copy();q.data=o.data.copy();bpy.context.scene.collection.objects.link(q);q.select_set(True);clones.append(q)
 bpy.context.view_layer.objects.active=clones[0];bpy.ops.object.join();hero=bpy.context.object;hero.name='Supply_Truck_LOD0' if kind=='supply' else 'Evacuation_Carrier_LOD0'
 bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
 # Exterior constraints match legacy gameplay envelope exactly or stay inside.
 for v in hero.data.vertices:
  v.co.x=max(-.925,min(.925,v.co.x));v.co.y=max(-1.575,min(1.90,v.co.y));v.co.z=max(.03,min(2.06,v.co.z))
 # Correct normal winding while leaving intentionally open cloth surfaces double-walled.
 bpy.ops.object.mode_set(mode='EDIT');bpy.ops.mesh.select_all(action='SELECT');bpy.ops.mesh.normals_make_consistent(inside=False);bpy.ops.object.mode_set(mode='OBJECT')
 tri=hero.modifiers.new('Final triangulation','TRIANGULATE');bpy.ops.object.modifier_apply(modifier=tri.name)
 if len(hero.data.polygons)>14500:
  base=hero.modifiers.new('Remove subpixel coplanar edge cost','DECIMATE');base.ratio=14500/len(hero.data.polygons);bpy.ops.object.modifier_apply(modifier=base.name)
 hero.data.validate(clean_customdata=True);hero.data.update()
 # Hard-edge modifiers only affect sharp planar parts; ring meshes retain smooth tire geometry.
 for o in objects:o.hide_render=True;o.hide_set(True)
 col.hide_render=True;col.hide_viewport=True
 hero.select_set(True);bpy.context.view_layer.objects.active=hero
 for o in bpy.context.selected_objects:
  if o!=hero:o.select_set(False)
 hi=len(hero.data.polygons)
 name='supply_truck' if kind=='supply' else 'evacuation_carrier'
 bpy.ops.file.pack_all();bpy.ops.wm.save_as_mainfile(filepath=str(P/'source'/f'{name}.blend'))
 bpy.ops.export_scene.gltf(filepath=str(P/'assets'/f'{name}.glb'),export_format='GLB',use_selection=True,export_texcoords=True,export_normals=True,export_tangents=True,export_materials='EXPORT',export_yup=True)
 # Mesh LODs retain UV / material, transparent draw order never required.
 dec=hero.modifiers.new('Silhouette-preserving distance reduction','DECIMATE');dec.ratio=.44;bpy.ops.object.modifier_apply(modifier=dec.name);hero.data.validate(clean_customdata=True);hero.data.update();sanitize_uv(hero);hero.name=hero.name.replace('LOD0','LOD1')
 bpy.ops.export_scene.gltf(filepath=str(P/'assets'/f'{name}_lod1.glb'),export_format='GLB',use_selection=True,export_texcoords=True,export_normals=True,export_tangents=True,export_materials='EXPORT',export_yup=True)
 lo=len(hero.data.polygons)
 dec=hero.modifiers.new('Far mobile view LOD','DECIMATE');dec.ratio=.45;bpy.ops.object.modifier_apply(modifier=dec.name);hero.data.validate(clean_customdata=True);hero.data.update();sanitize_uv(hero);hero.name=hero.name.replace('LOD1','LOD2')
 bpy.ops.export_scene.gltf(filepath=str(P/'assets'/f'{name}_lod2.glb'),export_format='GLB',use_selection=True,export_texcoords=True,export_normals=True,export_tangents=True,export_materials='EXPORT',export_yup=True)
 return {'asset':name,'lod0_triangles':hi,'lod1_triangles':lo,'lod2_triangles':len(hero.data.polygons),'editable_components':len(objects),'surfaces':1,'atlas':[2048,2048],'orientation':'Godot -Z forward; +Y up','bounds_contract':{'x':[-.925,.925],'y':[.03,2.06],'z':[-1.90,1.575]}}

stats=[build('supply'),build('convoy')]
json.dump({'blender':bpy.app.version_string,'original_asset_authoring':'RECLAMATION deterministic generator; original geometry and raster/PBR materials','vehicles':stats},open(P/'reports'/'asset_stats.json','w'),indent=2)
print('SURVIVOR_VEHICLES_BUILD_OK',stats)
