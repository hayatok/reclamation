extends RefCounted
## Runtime groups hold node IDs, never serialized object references or orders.
## Checkpoint references use the same unit/building arrays as the main save.
var slots:Dictionary={}

static func alive(actor:Dictionary)->bool:
 var node=actor.get("node")
 return actor.get("hp",0)>0 and not actor.get("dead",false) and is_instance_valid(node) and node is Node3D and not node.is_queued_for_deletion()

static func live_lookup(actors:Array)->Dictionary:
 var found={}
 for actor in actors:
  if alive(actor):found[actor.node.get_instance_id()]=actor
 return found

func assign(slot:int,selected:Array,inspected:Dictionary,units:Array,buildings:Array)->bool:
 if slot<1 or slot>9:return false
 var members=[]
 var living=live_lookup(units)
 for unit in selected:
  if not alive(unit):continue
  var id:int=unit.node.get_instance_id()
  if living.has(id) and not id in members:members.append(id)
 if not members.is_empty():
  slots[slot]={"kind":"units","ids":members}
  return true
 if selected.is_empty() and alive(inspected):
  var id:int=inspected.node.get_instance_id()
  if live_lookup(buildings).has(id):
   slots[slot]={"kind":"building","ids":[id]}
   return true
 return false

func resolve(slot:int,units:Array,buildings:Array)->Dictionary:
 var result={"units":[],"building":{}}
 if not slots.has(slot):return result
 var group:Dictionary=slots[slot]
 var living=live_lookup(units if group.kind=="units" else buildings)
 var retained=[]
 for id in group.ids:
  if not living.has(id):continue
  retained.append(id)
  if group.kind=="units":result.units.append(living[id])
  else:result.building=living[id]
 if retained.is_empty():slots.erase(slot)
 else:group.ids=retained
 return result

func snapshot(units:Array,buildings:Array)->Array:
 var saved=[]
 for slot in range(1,10):
  var group=resolve(slot,units,buildings)
  if not group.units.is_empty():
   saved.append({"slot":slot,"kind":"units","members":group.units.map(func(unit):return units.find(unit))})
  elif not group.building.is_empty():
   saved.append({"slot":slot,"kind":"building","members":[buildings.find(group.building)]})
 return saved

func restore(saved:Array,units:Array,buildings:Array):
 # The whole checkpoint has already passed CheckpointValidation.validate.
 slots.clear()
 for group in saved:
  var actors=units if group.kind=="units" else buildings
  var ids=[]
  for index in group.members:ids.append(actors[int(index)].node.get_instance_id())
  slots[int(group.slot)]={"kind":group.kind,"ids":ids}
