extends RefCounted
## A world-input reducer. Feed ALL native touch events from _input, including
## GUI-owned touches, without consuming them before Control receives its mouse
## emulation. Only the adapter knows world hits, the camera, or game commands.

enum Mode { CONTEXT, RANGE, ORDER }
enum Phase { IDLE, PENDING, PAN, RANGE, PINCH, BLOCKED }

class Action extends RefCounted:
 enum Kind { TAP, PAN, ZOOM, RANGE_PREVIEW, RANGE_COMMIT, RANGE_END }
 var kind:int=Kind.TAP
 var position:Vector2=Vector2.ZERO
 var origin:Vector2=Vector2.ZERO
 var delta:Vector2=Vector2.ZERO
 ## New finger distance / previous distance; >1 means zoom IN.
 var scale_factor:float=1.0
 var mode:int=Mode.CONTEXT
 var append:bool=false
 var reason:String=""

class Finger extends RefCounted:
 var start:Vector2
 var position:Vector2
 var world_owned:bool
 func _init(at:Vector2,owns_world:bool):
  start=at
  position=at
  world_owned=owns_world

## Viewport coordinates, not physical screen pixels. The adapter may convert a
## 12 CSS-pixel threshold to viewport units when the canvas is stretched.
var tap_slop:float=14.0
var minimum_pinch_distance:float=8.0
var mode:int=Mode.CONTEXT
var append:bool=false
var _fingers:Dictionary={}
var _phase:int=Phase.IDLE
var _primary:int=-1
var _gesture_mode:int=Mode.CONTEXT
var _gesture_append:bool=false
var _pinch_pair:Array[int]=[]
var _pinch_distance:float=0.0
var _pinch_center:Vector2=Vector2.ZERO
var _viewport_size:Vector2=Vector2.ZERO

func gesture_active()->bool:
 return not _fingers.is_empty()

func active_finger_count()->int:
 return _fingers.size()

func range_active()->bool:
 return _phase==Phase.RANGE

func set_mode(value:int)->Array[Action]:
 assert(value in [Mode.CONTEXT,Mode.RANGE,Mode.ORDER],"Unknown touch interaction mode")
 if mode==value:return []
 var actions=cancel("mode_changed")
 mode=value
 return actions

func set_append(value:bool)->Array[Action]:
 if append==value:return []
 var actions=cancel("append_changed")
 append=value
 return actions

func set_viewport_size(value:Vector2)->Array[Action]:
 if _viewport_size==value:return []
 var initialized:bool=_viewport_size!=Vector2.ZERO
 _viewport_size=value
 if initialized:return cancel("viewport_changed")
 return []

## Cancel keeps existing fingers quarantined until they have ALL lifted. Use
## forget_touches=true only for focus/page loss, where releases may never arrive.
## A Web touchcancel bridge should call the default before Godot's touchend.
func cancel(reason:String="cancel",forget_touches:bool=false)->Array[Action]:
 var actions:Array[Action]=[]
 _end_range(actions,reason)
 _phase=Phase.BLOCKED if not _fingers.is_empty() else Phase.IDLE
 _pinch_pair.clear()
 if forget_touches:
  _fingers.clear()
  _clear_sequence()
 return actions

## over_ui is a point hit-test in viewport coordinates, not GUI mouse hover.
## Ownership is assigned ON PRESS. A UI finger can never become a world finger.
## Release over UI also suppresses the tap/selection, even for a world owner.
func feed(event:InputEvent,world_allowed:bool=true,over_ui:bool=false)->Array[Action]:
 var actions:Array[Action]=[]
 if not (event is InputEventScreenTouch or event is InputEventScreenDrag):return actions
 if not world_allowed:actions.append_array(cancel("world_blocked"))
 if event is InputEventScreenTouch:
  if event.canceled:
   actions.append_array(cancel("pointer_canceled"))
   _fingers.erase(event.index)
   if _fingers.is_empty():_clear_sequence()
  elif event.pressed:_press(event.index,event.position,world_allowed and not over_ui,actions)
  else:_release(event.index,event.position,world_allowed and not over_ui,actions)
 else:
  _drag(event.index,event.position,actions)
 return actions

## Call only in the WORLD mouse path. GUI needs these events for native buttons.
static func is_emulated_mouse(event:InputEvent)->bool:
 return event is InputEventMouse and event.device==InputEvent.DEVICE_ID_EMULATION

func _press(index:int,at:Vector2,owns_world:bool,actions:Array[Action])->void:
 if _fingers.has(index):
  # A duplicate down cannot resurrect a previously canceled pointer stream.
  actions.append_array(cancel("duplicate_pointer"))
  _fingers[index]=Finger.new(at,false)
  return
 _fingers[index]=Finger.new(at,owns_world)
 if _fingers.size()==1:
  _primary=index
  _gesture_mode=mode
  _gesture_append=append
  _phase=Phase.PENDING if owns_world else Phase.BLOCKED
  return
 _end_range(actions,"multitouch")
 if _phase==Phase.BLOCKED or _fingers.size()!=2:
  _phase=Phase.BLOCKED
  return
 _pinch_pair.clear()
 for key in _fingers:
  var finger:Finger=_fingers[key]
  if not finger.world_owned:
   _phase=Phase.BLOCKED
   return
  _pinch_pair.append(int(key))
 _pinch_pair.sort()
 _phase=Phase.PINCH
 var a:Finger=_fingers[_pinch_pair[0]]
 var b:Finger=_fingers[_pinch_pair[1]]
 _pinch_distance=a.position.distance_to(b.position)
 _pinch_center=(a.position+b.position)*0.5

func _drag(index:int,at:Vector2,actions:Array[Action])->void:
 if not _fingers.has(index):return
 var finger:Finger=_fingers[index]
 var previous:Vector2=finger.position
 finger.position=at
 if _phase==Phase.BLOCKED:return
 if _phase==Phase.PINCH:
  _pinch(actions)
  return
 if index!=_primary or not finger.world_owned:return
 if _phase==Phase.PENDING and finger.start.distance_to(at)>=tap_slop:
  _phase=Phase.RANGE if _gesture_mode==Mode.RANGE else Phase.PAN
 if _phase==Phase.PAN:
  if at.is_equal_approx(previous):return
  var action=_action(Action.Kind.PAN,at,finger.start)
  # Godot 4.6 Web ScreenDrag.relative is unreliable for changed-touch batches.
  action.delta=at-previous
  actions.append(action)
 elif _phase==Phase.RANGE:
  actions.append(_action(Action.Kind.RANGE_PREVIEW,at,finger.start))

func _pinch(actions:Array[Action])->void:
 if _pinch_pair.size()!=2:return
 var a:Finger=_fingers[_pinch_pair[0]]
 var b:Finger=_fingers[_pinch_pair[1]]
 var distance:float=a.position.distance_to(b.position)
 var center:Vector2=(a.position+b.position)*0.5
 if _pinch_distance>=minimum_pinch_distance and distance>=minimum_pinch_distance:
  var ratio:float=distance/_pinch_distance
  if not is_equal_approx(ratio,1.0):
   var action=_action(Action.Kind.ZOOM,center)
   action.delta=center-_pinch_center
   action.scale_factor=ratio
   actions.append(action)
 _pinch_distance=distance
 _pinch_center=center

func _release(index:int,at:Vector2,release_allowed:bool,actions:Array[Action])->void:
 if not _fingers.has(index):return
 var finger:Finger=_fingers[index]
 finger.position=at
 if index==_primary and finger.world_owned and release_allowed and _fingers.size()==1:
  if _phase==Phase.PENDING and finger.start.distance_to(at)<tap_slop:
   var kind:int=Action.Kind.RANGE_COMMIT if _gesture_mode==Mode.RANGE else Action.Kind.TAP
   actions.append(_action(kind,at,finger.start))
  elif _phase==Phase.RANGE:
   actions.append(_action(Action.Kind.RANGE_COMMIT,at,finger.start))
 _end_range(actions,"released")
 _fingers.erase(index)
 # A lifted pinch finger NEVER promotes the survivor back into a tap or pan.
 if _fingers.is_empty():_clear_sequence()
 else:_phase=Phase.BLOCKED

func _end_range(actions:Array[Action],reason:String)->void:
 if _phase!=Phase.RANGE:return
 var action=_action(Action.Kind.RANGE_END)
 action.reason=reason
 actions.append(action)

func _clear_sequence()->void:
 _phase=Phase.IDLE
 _primary=-1
 _pinch_pair.clear()
 _pinch_distance=0.0

func _action(kind:int,at:Vector2=Vector2.ZERO,start:Vector2=Vector2.ZERO)->Action:
 var action=Action.new()
 action.kind=kind
 action.position=at
 action.origin=start
 action.mode=_gesture_mode
 action.append=_gesture_append
 return action
