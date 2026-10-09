extends RefCounted
## Read-only selection queries. Callers supply friendly units or the current selection.
## Returned units are the original dictionaries; no order, job or selection is changed.
const CENTER_OFFSET=Vector3(0,0.8,0)

static func point_unit(units:Array,camera:Camera3D,screen:Vector2,radius:float=24.0)->Dictionary:
 if not _camera_valid(camera) or radius<=0.0:return {}
 var nearest:Dictionary={}
 var best:float=radius
 for unit in units:
  if not _selectable(unit):continue
  var center:Vector3=unit.node.position+CENTER_OFFSET
  if not _in_front(camera,center):continue
  var distance:float=camera.unproject_position(center).distance_to(screen)
  if distance<best:
   nearest=unit
   best=distance
 return nearest

static func same_kind_in_view(units:Array,anchor:Dictionary,camera:Camera3D,viewport:Rect2)->Array:
 var matches:Array=[]
 if not _selectable(anchor) or not _camera_valid(camera):return matches
 for unit in units:
  if not _selectable(unit) or unit.kind!=anchor.kind:continue
  var center:Vector3=unit.node.position+CENTER_OFFSET
  if _in_front(camera,center) and viewport.has_point(camera.unproject_position(center)):
   matches.append(unit)
 return matches

static func groups(selected:Array)->Array:
 var result:Array=[]
 var indices:Dictionary={}
 for unit in selected:
  if not _selectable(unit):continue
  var kind:String=unit.kind
  if not indices.has(kind):
   indices[kind]=result.size()
   result.append({"kind":kind,"count":0})
  result[indices[kind]].count+=1
 return result

static func of_kind(selected:Array,kind:String)->Array:
 var matches:Array=[]
 for unit in selected:
  if _selectable(unit) and unit.kind==kind:matches.append(unit)
 return matches

static func _selectable(unit:Variant)->bool:
 if not unit is Dictionary or unit.is_empty():return false
 var kind:Variant=unit.get("kind","")
 if not (kind is String or kind is StringName) or kind=="" or kind=="convoy":return false
 var node:Variant=unit.get("node")
 return unit.get("hp",0)>0 and not unit.get("dead",false) and is_instance_valid(node) and node is Node3D and not node.is_queued_for_deletion()

static func _camera_valid(camera:Camera3D)->bool:
 return is_instance_valid(camera) and camera.is_inside_tree() and not camera.is_queued_for_deletion()

static func _in_front(camera:Camera3D,center:Vector3)->bool:
 return not camera.is_position_behind(center) and camera.is_position_in_frustum(center)
