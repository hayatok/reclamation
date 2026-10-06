extends SceneTree
## No game scene, resources, save writes, OS touches, or physical-phone claims.
const Touch=preload("res://mobile_touch_controller.gd")
const K=Touch.Action.Kind
var checks:int=0
var failures:Array[String]=[]

func _initialize()->void:
 call_deferred("run")

func check(ok:bool,label:String)->void:
 checks+=1
 if ok:print("PASS ",label)
 else:failures.append(label);push_error("FAIL "+label)

func touch(index:int,at:Vector2,pressed:bool,canceled:bool=false)->InputEventScreenTouch:
 var event=InputEventScreenTouch.new()
 event.index=index;event.position=at;event.pressed=pressed;event.canceled=canceled
 return event

func drag(index:int,at:Vector2)->InputEventScreenDrag:
 var event=InputEventScreenDrag.new()
 event.index=index;event.position=at
 # Deliberately wrong: controller must use indexed absolute positions.
 event.relative=Vector2(9000,-9000)
 return event

func kinds(actions:Array)->Array:
 return actions.map(func(action):return action.kind)

func commands(actions:Array)->int:
 return actions.filter(func(action):return action.kind==K.TAP).size()

func run()->void:
 var c=Touch.new()
 var at=Vector2(200,180)
 check(c.feed(touch(7,at,true)).is_empty(),"press waits for release, with arbitrary touch index")
 check(c.gesture_active() and c.active_finger_count()==1,"active stream available to adapter")
 var result=c.feed(touch(7,at+Vector2(3,2),false))
 check(kinds(result)==[K.TAP] and result[0].position==at+Vector2(3,2),"jitter-sized release emits one world tap")
 check(result[0].mode==Touch.Mode.CONTEXT and not result[0].append,"tap captures default interaction flags")
 check(not c.gesture_active(),"tap release drains stream")
 check(c.feed(touch(7,at,false)).is_empty(),"duplicate release cannot repeat a command")

 c.feed(touch(2,at,true))
 check(c.feed(drag(2,at+Vector2(4,0))).is_empty(),"movement under slop does not pan")
 result=c.feed(drag(2,at+Vector2(22,0)))
 check(kinds(result)==[K.PAN] and result[0].delta==Vector2(18,0),"drag crossing slop pans from previous indexed position")
 check(c.feed(drag(2,at+Vector2(1,0)))[0].kind==K.PAN,"drag stays consumed even after returning near press")
 check(c.feed(touch(2,at,false)).is_empty(),"pan release never taps")
 c.feed(touch(3,at,true))
 check(c.feed(touch(3,at+Vector2(100,0),false)).is_empty(),"large release displacement without drag callback cannot tap")

 for first_release in [4,11]:
  c=Touch.new()
  c.feed(touch(11,Vector2(100,100),true))
  c.feed(touch(4,Vector2(200,100),true))
  result=c.feed(drag(4,Vector2(220,100)))
  check(kinds(result)==[K.ZOOM] and is_equal_approx(result[0].scale_factor,1.2),"pinch spread zooms in independent of index ordering "+str(first_release))
  check(result[0].position==Vector2(160,100),"pinch provides current midpoint "+str(first_release))
  result=c.feed(drag(11,Vector2(110,100)))
  check(kinds(result)==[K.ZOOM] and is_equal_approx(result[0].scale_factor,110.0/120.0),"alternating pinch finger uses its own position "+str(first_release))
  var survivor:int=11 if first_release==4 else 4
  check(c.feed(touch(first_release,Vector2(150,100),false)).is_empty(),"first pinch release emits no command "+str(first_release))
  check(c.feed(drag(survivor,Vector2(180,100))).is_empty(),"remaining pinch finger cannot become a pan "+str(first_release))
  check(c.feed(touch(survivor,Vector2(180,100),false)).is_empty(),"last pinch release emits no command "+str(first_release))
  check(not c.gesture_active(),"both pinch release orders drain stream "+str(first_release))

 c=Touch.new()
 c.feed(touch(0,at,true));c.feed(touch(1,at,true))
 check(c.feed(drag(1,at+Vector2(2,0))).is_empty(),"near-zero pinch distance does not divide by zero or jump")
 check(c.feed(drag(1,at+Vector2(20,0))).is_empty(),"first usable pinch distance establishes baseline")
 result=c.feed(drag(1,at+Vector2(30,0)))
 check(kinds(result)==[K.ZOOM] and is_equal_approx(result[0].scale_factor,1.5),"pinch starts after establishing a safe baseline")
 c.feed(touch(2,at+Vector2(50,0),true))
 check(c.feed(drag(1,at+Vector2(60,0))).is_empty(),"third finger blocks the stream")
 c.feed(touch(2,at,false));c.feed(touch(0,at,false))
 check(c.feed(touch(1,at,false)).is_empty(),"three-finger sequence cannot release a command")

 c=Touch.new()
 c.feed(touch(0,at,true),true,true)
 check(c.feed(drag(0,at+Vector2(60,0)),true,false).is_empty(),"UI-origin finger cannot pan after leaving UI")
 check(c.feed(touch(0,at+Vector2(60,0),false),true,false).is_empty(),"UI-origin release over world cannot command")
 c.feed(touch(0,at,true),true,false)
 check(c.feed(touch(0,at,false),true,true).is_empty(),"world-origin release over UI is suppressed")
 for ui_first in [true,false]:
  c=Touch.new()
  c.feed(touch(2,at,true),true,ui_first)
  c.feed(touch(8,at+Vector2(100,0),true),true,not ui_first)
  check(c.feed(drag(8,at+Vector2(150,0))).is_empty(),"mixed UI/world fingers cannot zoom "+str(ui_first))
  c.feed(touch(2,at,false))
  check(c.feed(touch(8,at,false)).is_empty(),"mixed UI/world releases cannot command "+str(ui_first))

 c=Touch.new()
 c.feed(touch(0,at,true))
 check(c.feed(touch(0,at,false,true)).is_empty() and not c.gesture_active(),"native canceled release drains pointer without command")
 c.feed(touch(0,at,true));c.feed(touch(1,at+Vector2(100,0),true))
 c.feed(touch(1,at,false,true))
 check(c.feed(touch(0,at,false)).is_empty(),"one canceled pinch finger blocks the survivor")
 c.feed(touch(0,at,true));c.cancel("web_touchcancel")
 check(c.feed(touch(0,at,false)).is_empty(),"Web bridge cancellation suppresses Godot uncanceled touchend")
 c.feed(touch(0,at,true));c.cancel("page_hidden",true)
 check(not c.gesture_active() and c.feed(touch(0,at,false)).is_empty(),"focus/page reset forgets stranded fingers and ignores late release")
 c.feed(touch(0,at,true))
 check(kinds(c.feed(touch(0,at,false)))==[K.TAP],"fresh press works after page reset")

 c=Touch.new()
 c.set_mode(Touch.Mode.RANGE);c.set_append(true)
 c.feed(touch(5,at,true))
 result=c.feed(drag(5,at+Vector2(80,50)))
 check(kinds(result)==[K.RANGE_PREVIEW] and result[0].origin==at,"range mode provides drag rectangle origin and end")
 check(c.range_active(),"range preview state exposed")
 result=c.feed(touch(5,at+Vector2(90,60),false))
 check(kinds(result)==[K.RANGE_COMMIT,K.RANGE_END],"range commits exactly once then clears overlay")
 check(result[0].append and result[0].mode==Touch.Mode.RANGE,"range snapshots append/mode flags")
 check(commands(result)==0 and not c.range_active(),"range selection never emits a contextual order tap")
 c.feed(touch(5,at,true))
 check(kinds(c.feed(touch(5,at,false)))==[K.RANGE_COMMIT],"short tap in range mode still selects")
 c.feed(touch(5,at,true));c.feed(drag(5,at+Vector2(80,50)))
 result=c.feed(touch(6,at+Vector2(100,0),true))
 check(kinds(result)==[K.RANGE_END],"second finger clears range preview immediately")
 c.feed(touch(6,at,false))
 check(c.feed(touch(5,at,false)).is_empty(),"canceled range cannot commit on final release")
 c.feed(touch(5,at,true));c.feed(drag(5,at+Vector2(80,50)))
 check(kinds(c.feed(touch(5,at+Vector2(90,60),false),true,true))==[K.RANGE_END],"range released over UI only clears preview")

 c=Touch.new()
 c.feed(touch(3,at,true));c.set_mode(Touch.Mode.ORDER)
 check(c.feed(touch(3,at,false)).is_empty(),"changing mode cancels the old pending touch")
 c.feed(touch(3,at,true));result=c.feed(touch(3,at,false))
 check(kinds(result)==[K.TAP] and result[0].mode==Touch.Mode.ORDER,"explicit order flag belongs to the new gesture")
 c.feed(touch(3,at,true));c.set_append(true)
 check(c.feed(touch(3,at,false)).is_empty(),"append toggle cannot reinterpret a held tap")
 c.feed(touch(3,at,true));result=c.feed(touch(3,at,false))
 check(result[0].append,"next explicit order captures append toggle")
 c.set_mode(Touch.Mode.RANGE);c.feed(touch(3,at,true));c.feed(drag(3,at+Vector2(90,60)))
 check(kinds(c.cancel("cancel_button"))==[K.RANGE_END],"Cancel button clears active rectangle")
 check(c.feed(touch(3,at+Vector2(90,60),false)).is_empty(),"Cancel button prevents range commit")

 c=Touch.new()
 check(c.set_viewport_size(Vector2(1440,900)).is_empty(),"initial viewport setup returns an empty typed action list")
 c.feed(touch(0,at,true))
 c.set_viewport_size(Vector2(900,1440))
 check(c.feed(touch(0,at,false)).is_empty(),"orientation/viewport change suppresses old coordinate tap")
 c.feed(touch(0,at,true));c.set_viewport_size(Vector2(900,1440))
 check(kinds(c.feed(touch(0,at,false)))==[K.TAP],"unchanged viewport does not cancel valid tap")
 c.feed(touch(0,at,true))
 check(c.feed(touch(0,at,false),false).is_empty(),"opening modal before release blocks world tap")
 c.feed(touch(0,at,true),false)
 check(c.feed(touch(0,at,false),true).is_empty(),"closing modal before release cannot grant world ownership")
 c.feed(touch(0,at,true));c.feed(touch(0,at,true))
 check(c.feed(touch(0,at,false)).is_empty(),"duplicate pointer-down blocks accidental release command")
 check(c.feed(drag(42,at)).is_empty(),"unknown drag does not create a pointer")

 var mouse=InputEventMouseButton.new()
 mouse.button_index=MOUSE_BUTTON_LEFT;mouse.pressed=true
 mouse.device=InputEvent.DEVICE_ID_EMULATION
 check(Touch.is_emulated_mouse(mouse),"world mouse filter detects engine touch emulation")
 check(c.feed(mouse).is_empty(),"touch reducer does not interpret emulated mouse buttons")
 mouse.device=0
 check(not Touch.is_emulated_mouse(mouse),"native desktop mouse remains eligible for existing controls")
 check(not Touch.is_emulated_mouse(touch(0,at,true)),"native ScreenTouch stays eligible for reducer")
 print("MOBILE_TOUCH_CONTROLLER ",checks-failures.size(),"/",checks," passed")
 quit(0 if failures.is_empty() else 1)
