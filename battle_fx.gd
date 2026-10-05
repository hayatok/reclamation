extends Node3D
## Original layered battlefield effects. Fixed shared batches, no gameplay RNG/state.
const LIMIT=256
const WeaponMuzzles=preload("res://weapon_muzzles.gd")
# Persistent critical-state cues share the existing two textured batches. Combat
# bursts cannot consume these slots, including when reduced effects is enabled.
const CRITICAL_BUILDING_LIMIT=16
const CRITICAL_HEALTH_RATIO=.30
const CRITICAL_FLAME_SLOTS=CRITICAL_BUILDING_LIMIT
const CRITICAL_SMOKE_SLOTS=CRITICAL_BUILDING_LIMIT*2
# Local surface anchors, not model maxima (which can be chimney/radio tips).
# Imported GLB triangles were checked against the authored roof coordinates.
const CRITICAL_ANCHORS={
 "hq":Vector3(1.10,2.53,.75),
 "factory":Vector3(.65,2.82,.35),
 "house":Vector3(-.55,2.49,.30),
 "depot":Vector3(.55,2.44,.35),
 "barracks":Vector3(.55,2.70,.65),
 "vehicle_workshop":Vector3(.85,3.33,.55),
 "tower":Vector3(.50,3.48,.40),
 "garden":Vector3(1.20,.85,.45),
 "relay":Vector3(.35,1.22,.35),
 "wall":Vector3(.65,1.56,0),
 "mortar":Vector3(.40,1.46,.35),
 "artillery":Vector3(.40,1.46,.35),
 "yard":Vector3(.55,3.18,.35)
}
var rng=RandomNumberGenerator.new()
var particles:Dictionary={}
var batches:Dictionary={}
var lights:Array=[]
var blast_budget=0
var visual_clock=0.0
var last_blast:Dictionary={}
var critical_cue_count:int=0
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

func spawn(kind:String,p:Vector3,duration:float,size:float,color:Color,velocity:Vector3=Vector3.ZERO,growth:float=0)->Dictionary:
 var cap=32 if kind=="scorch" else mini(96,LIMIT-CRITICAL_SMOKE_SLOTS) if kind=="smoke" else LIMIT-CRITICAL_FLAME_SLOTS if kind=="flame" else LIMIT
 if particles[kind].size()>=cap:return {}
 var item={"pos":p,"life":duration,"total":duration,"size":size,"color":color,"velocity":velocity,"growth":growth,"angle":rng.randf_range(-PI,PI)}
 particles[kind].append(item)
 return item

func streak(a:Vector3,b:Vector3,color:Color,duration:float,width:float,socket:Dictionary={}):
 if a.distance_squared_to(b)<.0001 or particles.streak.size()>=LIMIT:return
 var direction=b-a
 var item={"pos":(a+b)*.5,"life":duration,"total":duration,"size":1.0,"color":color,"velocity":Vector3.ZERO,"growth":0.0,"angle":0.0,"basis":_streak_basis(direction,width)}
 if not socket.is_empty():
  item.muzzle=socket;item.endpoint=b;item.width=width;item.muzzle_fallback=a
 particles.streak.append(item)

static func _streak_basis(direction:Vector3,width:float)->Basis:
 var axis:Vector3=direction.normalized()
 var rotation:Basis=Basis.looking_at(axis,Vector3.UP if absf(axis.y)<.98 else Vector3.RIGHT)
 # The BoxMesh is one unit long on local Z. Scale its columns, not world axes:
 # rotation.scaled(Vector3(width,width,length)) collapses oblique X/Y travel.
 return Basis(rotation.x*width,rotation.y*width,rotation.z*direction.length())

func beam(a:Vector3,b:Vector3,color:Color,duration:float,width:float,socket:Dictionary={}):
 if color.b>color.r*1.03:
  var points=[a]
  for i in range(1,6):points.append(a.lerp(b,float(i)/6)+Vector3(rng.randf_range(-.45,.45),rng.randf_range(-.3,.4),rng.randf_range(-.45,.45)))
  points.append(b)
  for i in range(1,points.size()):
   streak(points[i-1],points[i],Color(.24,.57,.79,.35),duration,.13)
   streak(points[i-1],points[i],Color(.76,.93,1,.9),duration,.032)
 else:
  streak(a,b,Color(color.r,color.g,color.b,.65),duration,maxf(.022,width*.65),socket)
  streak(a,b,Color(1,.94,.74,.9),duration*.65,maxf(.012,width*.23),socket)

func muzzle(p:Vector3,heavy:bool=false,socket:Dictionary={}):
 var flash=spawn("flash",p,.12 if heavy else .075,1.15 if heavy else .65,Color(1,.91,.72,.9))
 var smoke=spawn("smoke",p,.45,.38,Color(.72,.73,.69,.28),Vector3(0,.45,0),.7)
 if not socket.is_empty():
  if not flash.is_empty():flash.muzzle=socket
  # Smoke detaches after its first displayed position; the brief flame follows the barrel.
  if not smoke.is_empty():smoke.muzzle=socket;smoke.muzzle_once=true

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

func _critical_sources(buildings:Array,camera:Camera3D)->Array:
 var sources:Array=[]
 if not is_visible_in_tree():return sources
 for building:Dictionary in buildings:
  var hp:float=float(building.get("hp",0))
  var maximum:float=float(building.get("maxhp",0))
  if hp<=0 or maximum<=0 or hp>maximum*CRITICAL_HEALTH_RATIO:continue
  if float(building.get("built",0))<1.0 or building.get("being_removed",false):continue
  var node=building.get("node")
  if not is_instance_valid(node) or not node is Node3D:continue
  if node.is_queued_for_deletion() or not node.is_visible_in_tree():continue
  var kind:String=str(building.get("kind",""))
  if not CRITICAL_ANCHORS.has(kind):continue
  var anchor:Vector3=node.to_global(CRITICAL_ANCHORS[kind])
  if not camera.is_position_in_frustum(anchor+Vector3(0,.8,0)):continue
  var distance:float=camera.global_position.distance_squared_to(anchor)
  # Bounded insertion keeps the nearest 16 visible structures. Offscreen damage
  # cannot exhaust the quota, and ties retain the incoming building order.
  var index:int=sources.size()
  while index>0 and distance<float(sources[index-1].distance):index-=1
  if index>=CRITICAL_BUILDING_LIMIT:continue
  sources.insert(index,{"pos":anchor,"distance":distance})
  if sources.size()>CRITICAL_BUILDING_LIMIT:sources.pop_back()
 return sources

func _critical_particles(buildings:Array,camera:Camera3D)->Dictionary:
 var cues:Dictionary={"flame":[],"smoke":[]}
 var sources:Array=_critical_sources(buildings,camera)
 critical_cue_count=sources.size()
 for source:Dictionary in sources:
  var anchor:Vector3=source.pos
  # Position-derived phase uses no RNG and remains stable when a building is
  # added/removed or the visible quota changes. No record is written to saves.
  var phase:float=fposmod(anchor.x*.73+anchor.z*1.17,TAU)
  var pulse:float=sin(visual_clock*7.0+phase)
  cues.flame.append({"pos":anchor+Vector3(0,.70,0),"life":1.0,"total":1.0,"size":1.0,"growth":0.0,"angle":.06*pulse,"color":Color(1,.78,.46,.92),"shape":Vector3(1.32+.09*pulse,1.94+.13*pulse,1)})
  for wisp:int in 2:
   var age:float=fposmod(visual_clock*.64+phase/TAU+float(wisp)*.5,1.0)
   var fade:float=sin(age*PI)
   var size:float=.92+age*.42
   cues.smoke.append({"pos":anchor+Vector3(.08+age*.24,.94+age*1.22,.04+age*.12),"life":1.0,"total":1.0,"size":1.0,"growth":0.0,"angle":phase+age*.35,"color":Color(.32,.28,.24,.76*fade),"shape":Vector3(size,size*1.10,1)})
 return cues

func update(delta:float,camera:Camera3D,buildings:Array=[],actor_frames:Dictionary={}):
 visual_clock+=delta;blast_budget=0
 if last_blast.size()>256:last_blast.clear()
 var critical:Dictionary=_critical_particles(buildings,camera)
 var muzzle_positions:Dictionary={}
 for light in lights:
  light.life=maxf(0,light.life-delta);light.node.light_energy=3*light.life/.12
 for kind in particles:
  var list:Array=particles[kind]
  for i in range(list.size()-1,-1,-1):
   var item:Dictionary=list[i];item.life-=delta
   if item.life<=0:list.remove_at(i);continue
   if item.has("muzzle"):
    var socket:Dictionary=item.muzzle
    var actor:Variant=socket.get("node")
    var id:int=actor.get_instance_id() if is_instance_valid(actor) else 0
    var key:int=id*2+int(socket.get("barrel",0))
    var fallback:Vector3=item.get("muzzle_fallback",item.pos)
    var point:Vector3=muzzle_positions.get(key,fallback)
    if id!=0 and not muzzle_positions.has(key):
     point=WeaponMuzzles.world_position(socket,actor_frames,fallback);muzzle_positions[key]=point
    if kind=="streak":item.muzzle_fallback=point
    if kind=="streak":
     var direction:Vector3=item.endpoint-point
     item.pos=(point+item.endpoint)*.5
     if direction.length_squared()>.0001:
      item.basis=_streak_basis(direction,item.width)
    else:item.pos=point
    if item.get("muzzle_once",false):item.erase("muzzle")
   if kind=="debris":item.velocity.y-=9*delta
   item.pos+=item.velocity*delta
  # Do not put persistent cues in the expiring combat particle lists. Repair,
  # destruction, load and removal therefore clear them on this render update.
  var rendered:Array=list
  if kind in ["flame","smoke"] and not critical[kind].is_empty():
   rendered=list.duplicate()
   rendered.append_array(critical[kind])
  if kind=="smoke":rendered.sort_custom(func(a,b):return camera.global_position.distance_squared_to(a.pos)>camera.global_position.distance_squared_to(b.pos))
  var mm:MultiMesh=batches[kind]
  for i in rendered.size():
   var item:Dictionary=rendered[i]
   var age=item.total-item.life
   var fade=clampf(item.life/minf(.4,item.total),0,1)
   var color:Color=item.color;color.a*=fade
   var size=item.size+age*item.growth
   var basis:Basis
   if kind=="streak":basis=item.basis
   elif kind in ["shock","scorch"]:basis=Basis(Vector3.RIGHT,-PI*.5).scaled(Vector3.ONE*size)
   elif kind=="debris":basis=Basis.from_euler(Vector3(age*6,item.angle+age*5,age*2)).scaled(Vector3(size,size*.65,size*2))
   else:
    var billboard:Basis=camera.global_basis*Basis(Vector3.BACK,item.angle)
    var shape:Vector3=item.get("shape",Vector3.ONE)*size
    # Scale billboard axes locally; world-axis nonuniform scale would tilt the
    # flame into the roof when the camera is pitched.
    basis=Basis(billboard.x*shape.x,billboard.y*shape.y,billboard.z*shape.z)
   mm.set_instance_transform(i,Transform3D(basis,item.pos))
   mm.set_instance_color(i,color)
  mm.visible_instance_count=rendered.size()
