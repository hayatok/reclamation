extends Control
## A temporary view of the existing minimap. Only camera navigation is allowed.
const MissionMap=preload("res://mission_map.gd")
var host:Node
var original_parent:Node
var original_rect:Rect2
var fingers:Dictionary={}
var tap_origin=Vector2.ZERO
var valid_tap:bool=false
var primary:int=-1
var mouse_down:bool=false
var quarantined:bool=false

func setup(game:Node,safe_area:Rect2)->void:
 host=game
 original_parent=host.minimap.get_parent()
 original_rect=Rect2(host.minimap.position,host.minimap.size)
 host.minimap.reparent(self,false)
 mouse_filter=Control.MOUSE_FILTER_STOP
 size_flags_horizontal=Control.SIZE_EXPAND_FILL
 resized.connect(_layout_map)
 fit(safe_area)

func fit(safe_area:Rect2)->void:
 var ratio=host.map_config.playable_bounds.size.x/host.map_config.playable_bounds.size.y
 custom_minimum_size.y=minf((safe_area.size.x-24)/ratio,maxf(140,safe_area.size.y-132))
 cancel_gesture(false)
 _layout_map()

func _layout_map()->void:
 if not is_instance_valid(host) or host.minimap.get_parent()!=self:return
 var ratio=host.map_config.playable_bounds.size.x/host.map_config.playable_bounds.size.y
 var h=minf(size.y,size.x/ratio)
 host.minimap.position=Vector2((size.x-h*ratio)/2,0)
 host.minimap.size=Vector2(h*ratio,h)
 host.minimap.queue_redraw()

func cancel_gesture(focus_lost:bool=false)->void:
 valid_tap=false;mouse_down=false;primary=-1
 quarantined=not fingers.is_empty()
 if focus_lost:fingers.clear();quarantined=false

func restore()->void:
 fingers.clear();valid_tap=false;mouse_down=false
 if is_instance_valid(host) and is_instance_valid(original_parent) and host.minimap.get_parent()==self:
  host.minimap.reparent(original_parent,false)
  host.minimap.position=original_rect.position;host.minimap.size=original_rect.size

func _input(event:InputEvent)->void:
 if not is_visible_in_tree() or not is_instance_valid(host):return
 if event is InputEventScreenTouch:
  if event.pressed:
   fingers[event.index]=event.position
   if fingers.size()==1 and not quarantined:
    primary=event.index;tap_origin=event.position
    valid_tap=host.minimap.get_global_rect().has_point(event.position)
   else:valid_tap=false
  else:
   var commit=valid_tap and event.index==primary and fingers.size()==1 and not event.canceled
   fingers.erase(event.index)
   if commit and event.position.distance_to(tap_origin)<=12:_move_camera(event.position)
   valid_tap=false
   if fingers.is_empty():primary=-1;quarantined=false
 elif event is InputEventScreenDrag:
  if event.index==primary and event.position.distance_to(tap_origin)>12:valid_tap=false
 elif event is InputEventMouseButton and event.device!=InputEvent.DEVICE_ID_EMULATION and event.button_index==MOUSE_BUTTON_LEFT:
  if event.pressed:
   mouse_down=host.minimap.get_global_rect().has_point(event.position);tap_origin=event.position
  else:
   if mouse_down and event.position.distance_to(tap_origin)<=12:_move_camera(event.position)
   mouse_down=false
 elif event is InputEventMouseMotion and mouse_down and event.position.distance_to(tap_origin)>12:
  mouse_down=false

func _move_camera(screen:Vector2)->void:
 var rect=host.minimap.get_global_rect()
 if not rect.has_point(screen):return
 var point=MissionMap.map_to_world(host.map_config,screen-rect.position,rect.size)
 if point.is_finite():
  host.camera_focus=MissionMap.clamp_camera(host.map_config,point)
  host.minimap.queue_redraw()
