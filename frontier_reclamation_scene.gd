extends Node3D
## Cosmetic victory-only use of a cleared road. No simulation actors or rewards.
const Actors=preload("res://actor_visuals.gd")
const Worker=preload("res://articulated_worker.gd")
const Structures=preload("res://structure_visuals.gd")
const OFFSETS=[Vector3(-10,0,4),Vector3(-10,0,0),Vector3(-10,0,-4),Vector3(-8,0,7),Vector3(-12,0,7)]
var actors:Array[Node3D]=[]
var cargo:Node3D
var chosen_world:=Vector3.INF
func setup(context:Dictionary,origin:Vector3)->bool:
 chosen_world=choose_space(context,origin)
 if not chosen_world.is_finite():return false
 position=chosen_world-origin
 for title in ["RoadCarrier","RoadReceiver"]:
  var actor=Node3D.new();actor.name=title;add_child(actor);Actors.add_human(actor,"worker");actors.append(actor)
  var visual:Node3D=actor.get_meta(&"actor_visuals")
  var parts=Actors.part_nodes(visual)
  for i in parts.size():
   for mesh in parts[i].find_children("*","GeometryInstance3D",true,false):
    mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_ON if i==1 else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 cargo=_crate("CarriedReliefCrate")
 var received=_crate("RoadsideSupplies");received.position=Vector3(1.45,.25,-.8)
 sample_at(0)
 return true
static func choose_space(context:Dictionary,origin:Vector3)->Vector3:
 var clear:Callable=context.get("frontier_clear",Callable())
 if not clear.is_valid():return Vector3.INF
 var people:Array=context.get("frontier_unit_footprints",[])
 var buildings:Array=context.get("frontier_building_footprints",[])
 for offset in OFFSETS:
  var center:Vector3=origin+offset
  var safe:=true
  # Entire swept corridor, including bodies, hands and both crates.
  for ix in 8:
   for iz in 11:
    var p:Vector3=center+Vector3(-1.25+ix*.5,0,-1.4+iz*.5)
    if Vector2(p.x-origin.x,p.z-origin.z).length()<5.1 or not clear.call(p):safe=false;break
    for other in people:
     if p.distance_to(other.position)<float(other.radius)+.45:safe=false;break
    if not safe:break
    for building in buildings:
     if p.distance_to(building.position)<float(building.radius)+.6:safe=false;break
    if not safe:break
   if not safe:break
  if safe:return center
 return Vector3.INF
func _crate(title:String)->Node3D:
 var surface=SurfaceTool.new();surface.begin(Mesh.PRIMITIVE_TRIANGLES)
 Structures.b(surface,Vector3(.72,.48,.54),Vector3.ZERO,Color("847657"))
 for x in [-.28,.28]:Structures.b(surface,Vector3(.065,.52,.59),Vector3(x,0,0),Color("393d37"))
 for y in [-.16,.16]:Structures.b(surface,Vector3(.78,.055,.60),Vector3(0,y,0),Color("aa9870"))
 Structures.b(surface,Vector3(.22,.17,.012),Vector3(0,.03,-.281),Color("d1c8ab"))
 var material=StandardMaterial3D.new();material.vertex_color_use_as_albedo=true;material.roughness=.86
 surface.set_material(material);surface.index()
 var node=MeshInstance3D.new();node.name=title;node.mesh=surface.commit();add_child(node);return node
func _pose(actor:Node3D,at:Vector3,face:Vector3,phase:float,moving:bool,carrying:bool,motion_weight:float=0.0)->void:
 actor.position=at;actor.rotation.y=atan2(-face.x,-face.z)
 Actors.pose(actor,phase,moving,-1,-1,false,-1,1,motion_weight,1.4,{"carrying":carrying})
 # Private cinematic instances use a shared external crate and no tools.
 var parts=Actors.part_nodes(actor.get_meta(&"actor_visuals"));parts[13].hide();parts[14].hide()
func sample_at(seconds:float)->void:
 if actors.size()!=2:return
 var t:float=clampf(seconds,0,5.6)
 var progress:float=smoothstep(0,2.8,t)
 var at:Vector3=Vector3(-.45,.025,2.6*(1-progress))
 var moving:bool=t>0 and t<2.8
 var direction:Vector3=Vector3(0,0,-1).slerp(Vector3.RIGHT,smoothstep(2.4,3.05,t))
 _pose(actors[0],at,direction,2.6*progress/1.4*TAU,moving,true,smoothstep(0,.35,t)*(1-smoothstep(2.45,2.8,t)))
 _pose(actors[1],Vector3(.45,.025,0),Vector3.LEFT,0,false,true)
 var first:Vector3=actors[0].transform*Vector3(0,1.0,-.43)
 var second:Vector3=actors[1].transform*Vector3(0,1.0,-.43)
 var transfer:float=smoothstep(3.2,3.9,t)
 cargo.position=first.lerp(second,transfer)
 cargo.rotation.y=lerp_angle(actors[0].rotation.y,actors[1].rotation.y,transfer)
 # Actual crate-side contact, using the worker's existing arm lengths and IK.
 # Both people support the box during the short handover.
 for index in 2:
  var actor=actors[index]
  var parts=Actors.part_nodes(actor.get_meta(&"actor_visuals"))
  var torso:Transform3D=parts[1].transform
  var local_crate:Vector3=actor.transform.affine_inverse()*cargo.position
  var ready:float=smoothstep(2.75,3.1,t) if index==1 else 1.0
  var center:Vector3=Vector3(0,1.0,-.43).lerp(local_crate,ready)
  for side_index in 2:
   var side:float=-1.0 if side_index==0 else 1.0
   var shoulder:Vector3=torso*Vector3(side*.212,.335,0)
   var hand:Vector3=center+Vector3(side*.35,0,0)
   var elbow:Vector3=Worker._joint(shoulder,hand,Worker.UPPER_ARM_LENGTH,Worker.FOREARM_LENGTH,Vector3(side*.72,-.82,.33))
   parts[9+side_index].transform=Worker._segment(shoulder,elbow)
   parts[11+side_index].transform=Worker._segment(elbow,hand)
