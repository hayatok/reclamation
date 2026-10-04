extends Node3D
## Original layered battlefield effects. Fixed shared batches, no gameplay RNG/state.
const LIMIT=256
var rng=RandomNumberGenerator.new()
var particles:Dictionary={}
var batches:Dictionary={}
var lights:Array=[]
var blast_budget=0
var visual_clock=0.0
var last_blast:Dictionary={}
func _ready():
 rng.seed=719034
 for kind in ["flash","flame","smoke","shock","scorch","streak","debris"]:
  particles[kind]=[]
  var mesh:Mesh
  if kind in ["streak","debris"]:
   var cube=BoxMesh.new();cube.size=Vector3.ONE;mesh=cube
  else:
   var quad=QuadMesh.new();quad.size=Vector2.ONE;mesh=quad
  var mat=StandardMaterial3D.new()
  mat.texture_filter=BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
  mat.vertex_color_use_as_albedo=true
  mat.albedo_color=Color.WHITE
  mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
  mat.cull_mode=BaseMaterial3D.CULL_DISABLED
  mat.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
  mat.blend_mode=BaseMaterial3D.BLEND_MODE_ADD if kind in ["flash","flame","streak"] else BaseMaterial3D.BLEND_MODE_MIX
  if kind not in ["streak","debris"]:mat.albedo_texture=load("res://assets/fx/"+kind+".png")
  var mm=MultiMesh.new();mm.transform_format=MultiMesh.TRANSFORM_3D;mm.use_colors=true;mm.mesh=mesh
  mm.instance_count=LIMIT;mm.visible_instance_count=0;mm.custom_aabb=AABB(Vector3(-80,-10,-80),Vector3(160,80,160))
  var n=MultiMeshInstance3D.new();n.multimesh=mm;n.material_override=mat;n.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
  add_child(n);batches[kind]=mm
 for i in 2:
  var light=OmniLight3D.new();light.shadow_enabled=false;light.light_color=Color("ffb25f");light.light_energy=0;light.omni_range=7
  add_child(light);lights.append({"node":light,"life":0.0})

func spawn(kind:String,p:Vector3,duration:float,size:float,color:Color,velocity:Vector3=Vector3.ZERO,growth:float=0):
 var cap=32 if kind=="scorch" else 96 if kind=="smoke" else LIMIT
 if particles[kind].size()>=cap:return
 particles[kind].append({"pos":p,"life":duration,"total":duration,"size":size,"color":color,"velocity":velocity,"growth":growth,"angle":rng.randf_range(-PI,PI)})

func streak(a:Vector3,b:Vector3,color:Color,duration:float,width:float):
 if a.distance_squared_to(b)<.0001 or particles.streak.size()>=LIMIT:return
 var direction=b-a
 var basis=Basis.looking_at(direction.normalized(),Vector3.UP if absf(direction.normalized().y)<.98 else Vector3.RIGHT)
 particles.streak.append({"pos":(a+b)*.5,"life":duration,"total":duration,"size":1.0,"color":color,"velocity":Vector3.ZERO,"growth":0.0,"angle":0.0,"basis":basis.scaled(Vector3(width,width,direction.length()))})

func beam(a:Vector3,b:Vector3,color:Color,duration:float,width:float):
 if color.b>color.r*1.03:
  var points=[a]
  for i in range(1,6):points.append(a.lerp(b,float(i)/6)+Vector3(rng.randf_range(-.45,.45),rng.randf_range(-.3,.4),rng.randf_range(-.45,.45)))
  points.append(b)
  for i in range(1,points.size()):
   streak(points[i-1],points[i],Color(.24,.57,.79,.35),duration,.13)
   streak(points[i-1],points[i],Color(.76,.93,1,.9),duration,.032)
 else:
  streak(a,b,Color(color.r,color.g,color.b,.65),duration,maxf(.022,width*.65))
  streak(a,b,Color(1,.94,.74,.9),duration*.65,maxf(.012,width*.23))

func muzzle(p:Vector3,heavy:bool=false):
 spawn("flash",p,.12 if heavy else .075,1.15 if heavy else .65,Color(1,.91,.72,.9))
 spawn("smoke",p,.45,.38,Color(.72,.73,.69,.28),Vector3(0,.45,0),.7)

func impact(p:Vector3,kind:String):
 var metal=kind in ["armored","critical"]
 spawn("flash",p,.11,.60 if metal else .28,Color(1,.82,.48,.8) if metal else Color(.54,.35,.28,.5))
 for i in (5 if metal else 2):
  var v=Vector3(rng.randf_range(-2,2),rng.randf_range(.8,2.5),rng.randf_range(-2,2))
  spawn("debris",p,.28,.06,Color("d5a764") if metal else Color("653e36"),v)

func blast(p:Vector3,radius:float,heavy:bool,reduced:bool=false):
 var key=Vector2i(roundi(p.x/2),roundi(p.z/2))
 if visual_clock-float(last_blast.get(key,-10))<.09:return
 last_blast[key]=visual_clock
 spawn("shock",p+Vector3(0,.16,0),.45,.5,Color(.72,.63,.47,.48),Vector3.ZERO,radius*4)
 if blast_budget>=5:return
 blast_budget+=1
 spawn("flash",p+Vector3(0,.5,0),.12,radius*1.1,Color(1,.87,.56,.85))
 if reduced:return
 var size=radius*.8
 for i in (3 if heavy else 2):
  var offset=Vector3(rng.randf_range(-.6,.6),.4+float(i)*.35,rng.randf_range(-.6,.6))
  spawn("flame",p+offset,.35+float(i)*.09,size,Color(1,.86,.63,.8),Vector3(0,.5,0),1.2)
  spawn("smoke",p+offset,.85+float(i)*.12,size*.75,Color(.74,.77,.77,.4),Vector3(rng.randf_range(-.3,.3),.8,rng.randf_range(-.3,.3)),1.3)
 spawn("scorch",p+Vector3(0,.12,0),6.0,radius*1.5,Color(1,1,1,.8))
 for i in (10 if heavy else 5):
  var direction=Vector3(cos(i*TAU/10),rng.randf_range(.7,1.5),sin(i*TAU/10))
  spawn("debris",p+Vector3(0,.5,0),rng.randf_range(.45,.8),rng.randf_range(.07,.15),Color("655344") if i%3 else Color("d19b51"),direction*rng.randf_range(2,4))
 if heavy:
  var light=lights[0] if lights[0].life<lights[1].life else lights[1]
  light.node.position=p+Vector3(0,1.4,0);light.life=.12

func trail(a:Vector3,b:Vector3,heavy:bool):
 streak(a,b,Color(1,.74,.35,.75),.16,.09 if heavy else .045)

func update(delta:float,camera:Camera3D):
 visual_clock+=delta;blast_budget=0
 if last_blast.size()>256:last_blast.clear()
 for light in lights:
  light.life=maxf(0,light.life-delta);light.node.light_energy=3*light.life/.12
 for kind in particles:
  var list:Array=particles[kind]
  for i in range(list.size()-1,-1,-1):
   var item:Dictionary=list[i];item.life-=delta
   if item.life<=0:list.remove_at(i);continue
   if kind=="debris":item.velocity.y-=9*delta
   item.pos+=item.velocity*delta
  if kind=="smoke":list.sort_custom(func(a,b):return camera.global_position.distance_squared_to(a.pos)>camera.global_position.distance_squared_to(b.pos))
  var mm:MultiMesh=batches[kind]
  for i in list.size():
   var item:Dictionary=list[i]
   var age=item.total-item.life
   var fade=clampf(item.life/minf(.4,item.total),0,1)
   var color:Color=item.color;color.a*=fade
   var size=item.size+age*item.growth
   var basis:Basis
   if kind=="streak":basis=item.basis
   elif kind in ["shock","scorch"]:basis=Basis(Vector3.RIGHT,-PI*.5).scaled(Vector3.ONE*size)
   elif kind=="debris":basis=Basis.from_euler(Vector3(age*6,item.angle+age*5,age*2)).scaled(Vector3(size,size*.65,size*2))
   else:basis=(camera.global_basis*Basis(Vector3.BACK,item.angle)).scaled(Vector3.ONE*size)
   mm.set_instance_transform(i,Transform3D(basis,item.pos))
   mm.set_instance_color(i,color)
  mm.visible_instance_count=list.size()
