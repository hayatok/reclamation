extends SceneTree
const OUT="user://rebuilt_mobile_close/"
var g:Node
func _initialize():call_deferred("run")
func settle():
 for frame in 8:g._process(0);await process_frame
func tap(p:Vector2):
 for down in [true,false]:
  var event=InputEventScreenTouch.new();event.index=0;event.position=p;event.pressed=down
  Input.parse_input_event(event);await process_frame
func run():
 create_timer(45).timeout.connect(func():quit(2))
 DirAccess.make_dir_recursive_absolute(OUT)
 var c=root.get_node("Campaign");c.current=1;c.launch=true;c.resume=false;c.muted=true
 g=load("res://main.tscn").instantiate();root.add_child(g);current_scene=g
 g.set_process(false);g.paused=false
 Input.emulate_mouse_from_touch=true;Input.emulate_touch_from_mouse=false
 assert(g.mobile_enabled);g.select_headquarters();await settle()
 var initial=JSON.stringify(g.checkpoint_data());var hud=g.mobile_hud
 await tap(hud.selection.get_global_rect().get_center());await settle()
 assert(hud.has_open_popup() and g.paused)
 var fixed=hud.popup.has_meta("fixed_close");var tag="after" if fixed else "before"
 root.get_texture().get_image().save_png(OUT+tag+".png")
 var close:Button
 for b in hud.popup.find_children("*","Button",true,false):
  if b.text=="閉じる":close=b;break
 if fixed:close=hud.popup.get_meta("fixed_close")
 var rect=close.get_global_rect()
 if fixed:
  assert(hud.safe_rect.encloses(rect) and rect.size.y>=48)
  hud.popup.get_meta("scroll").scroll_vertical=10000;await settle()
  assert(close.get_global_rect()==rect)
  await tap(rect.get_center());await settle()
  assert(not hud.has_open_popup() and not g.paused and JSON.stringify(g.checkpoint_data())==initial)
  for repeat in 2:
   g.paused=true;await tap(hud.selection.get_global_rect().get_center());await settle()
   await tap(hud.popup.get_meta("fixed_close").get_global_rect().get_center());await settle()
   assert(not hud.has_open_popup() and g.paused)
  g.mobile_browser._native_test_size=Vector2(390,844);g._mobile_layout();await settle()
  hud.safe_insets=Vector4(0,28,0,22);hud._layout();await settle()
  await tap(hud.selection.get_global_rect().get_center());await settle()
  assert(hud.safe_rect.encloses(hud.popup.get_meta("fixed_close").get_global_rect()))
  root.get_texture().get_image().save_png(OUT+"portrait.png")
  await tap(hud.popup.get_meta("fixed_close").get_global_rect().get_center());await settle()
  assert(not hud.has_open_popup() and g.paused)
  assert(g.save_checkpoint(false)==OK and g.load_checkpoint())
 else:assert(not hud.safe_rect.encloses(rect))
 var result={"fixed":fixed,"close_rect":str(rect),"mission":"M2 fresh start","synthetic_touch":true,"real_phone":false,"state_preserved":fixed}
 var f=FileAccess.open(OUT+tag+".json",FileAccess.WRITE);f.store_string(JSON.stringify(result,"  "));f.close()
 print("MOBILE_CLOSE_REVIEW ",JSON.stringify(result));g.free();quit()
