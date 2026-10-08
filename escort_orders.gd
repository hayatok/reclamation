extends RefCounted
## Persistent player-issued protection order; never selects a strategy or target for the player.
const SLOTS=[Vector3(-2.1,0,-2.5),Vector3(2.1,0,-2.5),Vector3(-2.8,0,.5),Vector3(2.8,0,.5),Vector3(-1.8,0,2.7),Vector3(1.8,0,2.7)]
static func can_follow(unit:Dictionary,target:Dictionary)->bool:
 if unit.node==target.node or unit.kind=="convoy":return false
 var seen:Array=[]
 var cursor:Variant=target
 while cursor!=null:
  var node=cursor.get("node")
  if not is_instance_valid(node) or node==unit.node or node in seen:return false
  seen.append(node)
  cursor=cursor.get("target") if cursor.get("task","")=="escort" else null
 return true
static func assign(unit:Dictionary,target:Dictionary,slot:int)->bool:
 if not can_follow(unit,target):return false
 unit.task="escort";unit.target=target;unit["escort_slot"]=slot;unit["escort_repath"]=0.0
 unit.route.clear();unit.planned=Vector3.INF
 return true
static func update(unit:Dictionary,units:Array,dt:float,command_bounds:Rect2=Rect2(-28,-28,56,56))->void:
 var target:Variant=unit.target
 if target==null or not is_instance_valid(target.get("node")) or target.node.is_queued_for_deletion() or target.get("hp",0)<=0 or not units.any(func(other):return other.node==target.node):
  unit.task="idle";unit.target=null;unit.goal=unit.node.position;unit.route.clear();unit.planned=Vector3.INF
  return
 unit["escort_repath"]=float(unit.get("escort_repath",0))-dt
 if unit.escort_repath>0:return
 unit.escort_repath=.35
 var slot:int=int(unit.get("escort_slot",0))
 var offset:Vector3=SLOTS[slot%SLOTS.size()]+Vector3(0,0,floori(float(slot)/SLOTS.size())*1.4)
 if unit.kind in ["truck","worker"]:offset=Vector3((slot%3-1)*1.6,0,3.3+floori(float(slot)/3)*.5)
 var desired:Vector3=target.node.position+Basis(Vector3.UP,target.node.rotation.y)*offset
 desired.x=clampf(desired.x,command_bounds.position.x,command_bounds.end.x);desired.z=clampf(desired.z,command_bounds.position.y,command_bounds.end.y)
 if unit.planned==Vector3.INF or desired.distance_to(unit.goal)>.85:
  unit.goal=desired;unit.planned=Vector3.INF
