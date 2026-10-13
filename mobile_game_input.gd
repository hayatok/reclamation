extends RefCounted
const MissionMap=preload("res://mission_map.gd")
## Touch-to-existing-command adapter. The simulation remains authoritative.
const Touch=preload("res://mobile_touch_controller.gd")
var host:Node
var controller=Touch.new()
var hud:Control
var map_finger:int=-1
var map_start=Vector2.ZERO
var map_moved:bool=false
var map_mode:int=0
var map_append:bool=false
var previous_modal:bool=false
func setup(game:Node,mobile_hud:Control)->void:
 host=game;hud=mobile_hud
 controller.set_viewport_size(host.get_viewport().get_visible_rect().size)
 sync()
func modal()->bool:
 if host.title_open or host.ended or host.active_card:return true
 for key in ["options_panel","route_panel","dismantle_panel","choice_panel"]:
  if is_instance_valid(host.get(key)):return true
 return hud.has_method("has_open_popup") and hud.has_open_popup()
func sync()->void:
 _dispatch(controller.set_viewport_size(host.get_viewport().get_visible_rect().size))
 var blocked=modal()
 if blocked and not previous_modal:
  host.mobile_gui_guard.cancel_interaction()
  hud.cancel_scroll_drag()
  cancel("modal")
 previous_modal=blocked
 hud.set_touch_state(controller.mode,controller.append)
func set_mode(value:int)->void:_dispatch(controller.set_mode(value));sync()
func set_append(value:bool)->void:_dispatch(controller.set_append(value));sync()
func cancel(reason:String="cancel",forget:bool=false)->void:
 host.escort_targeting=false
 _dispatch(controller.cancel(reason,forget));map_finger=-1;map_moved=false
func cancel_command()->void:
 cancel();host.cancel_targeting_mode()
 _dispatch(controller.set_mode(Touch.Mode.CONTEXT));_dispatch(controller.set_append(false));sync()
func feed(event:InputEvent)->void:
 if not (event is InputEventScreenTouch or event is InputEventScreenDrag):return
 var blocked=modal()
 var over_ui=false
 for rectangle in hud.ui_blocks():
  if rectangle.has_point(event.position):over_ui=true;break
 # Minimap has its own completed-tap policy; the main gesture reducer keeps it
 # UI-owned throughout. A drag never selects or issues an order on release.
 var map_rect=host.minimap.get_global_rect()
 if event is InputEventScreenTouch:
  if event.pressed:
   if map_finger>=0:map_moved=true
   elif not blocked and map_rect.has_point(event.position) and not controller.gesture_active():
    map_finger=event.index;map_start=event.position;map_moved=false;map_mode=controller.mode;map_append=controller.append
  elif event.index==map_finger:
   if not event.canceled and not map_moved and not blocked and map_rect.has_point(event.position):_map_tap(event.position,map_mode,map_append)
   map_finger=-1
 elif event.index==map_finger and event.position.distance_to(map_start)>12:map_moved=true
 _dispatch(controller.feed(event,not blocked,over_ui))
func _dispatch(actions:Array)->void:
 for action in actions:
  match action.kind:
   Touch.Action.Kind.PAN:
    host.camera_focus+=host.ground_at(action.position-action.delta)-host.ground_at(action.position)
    _camera()
   Touch.Action.Kind.ZOOM:
    var anchor=host.ground_at(action.position)
    host.camera.size=clampf(host.camera.size/action.scale_factor,26,85)
    _camera();host.camera_focus+=anchor-host.ground_at(action.position);_camera()
   Touch.Action.Kind.RANGE_PREVIEW:
    host.dragging=true;host.drag_start=action.origin
    # Existing overlay reads the mouse, so touch draws its own endpoint.
    hud.set_meta("range_end",action.position)
    host.drag_overlay.queue_redraw()
   Touch.Action.Kind.RANGE_COMMIT:
    host.select_rect(action.origin,action.position,action.append)
    _dispatch(controller.set_mode(Touch.Mode.CONTEXT))
   Touch.Action.Kind.RANGE_END:
    host.dragging=false;hud.remove_meta("range_end");host.drag_overlay.queue_redraw()
   Touch.Action.Kind.TAP:_tap(action.position,action.mode,action.append)
 if is_instance_valid(hud):hud.set_touch_state(controller.mode,controller.append)
func _camera()->void:
 host.camera_focus=MissionMap.clamp_camera(host.map_config,host.camera_focus)
 host.camera.position=host.camera_focus+Vector3(37,48,43);host.camera.look_at(host.camera_focus)
func _tap(screen:Vector2,mode:int,append:bool)->void:
 if modal():return
 var ground=host.ground_at(screen)
 if host.escort_targeting:
  host.choose_escort_target(ground,screen);return
 if not host.build_mode.is_empty():
  host.place_building(ground,append);return
 if mode==Touch.Mode.ORDER or host.attack_move:
  if host.command_at(ground,screen,append):_dispatch(controller.set_mode(Touch.Mode.CONTEXT))
  return
 # Match point-selection precedence: nearest friendly, then footprint, then
 # resource/site. Explicit Order handles repair/escort and producer rally.
 for unit in host.units:
  if host.camera.unproject_position(unit.node.position+Vector3(0,.8,0)).distance_to(screen)<24:
   host.select_rect(screen,screen,append);return
 for building in host.buildings:
  if building.node.position.distance_to(ground)<building.radius+1:
   host.select_rect(screen,screen,false);return
 var has_workers=host.selected.any(func(u):return u.kind=="worker")
 if has_workers:
  var resource=host.resource_at(ground)
  if not resource.is_empty():host.command_at(ground,screen,append);return
  for site in host.sites:
   if host.frontier_position_known(site.node.position) and site.node.position.distance_to(ground)<3 and not site.get("reclaimed",false):
    host.command_at(ground,screen,append);return
 for site in host.sites:
  if site.kind=="abandoned_depot" and site.reclaimed:continue
  if host.frontier_position_known(site.node.position) and site.node.position.distance_to(ground)<3:
   host.select_rect(screen,screen,false);return
 if not host.selected.is_empty():host.command_at(ground,screen,append)
 else:host.select_rect(screen,screen,false)
func _map_tap(screen:Vector2,mode:int,append:bool)->void:
 var p=MissionMap.map_to_world(host.map_config,screen-host.minimap.global_position,host.minimap.size)
 if not p.is_finite():return
 if host.escort_targeting:
  host.camera_focus=MissionMap.clamp_camera(host.map_config,p);_camera();return
 if mode==Touch.Mode.ORDER or host.attack_move:
  var destination=MissionMap.clamp_command(host.map_config,p)
  var attack=host.attack_move
  if host.command_at(destination,Vector2.INF,append):
   host.minimap_order_point=Vector2(destination.x,destination.z);host.minimap_order_time=.65
   host.minimap_order_color=host.RED if attack else host.CYAN
   _dispatch(controller.set_mode(Touch.Mode.CONTEXT))
 else:host.camera_focus=MissionMap.clamp_camera(host.map_config,p);_camera()
 host.minimap.queue_redraw()
