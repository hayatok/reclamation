extends SceneTree
const OUT="user://mobile_alert_review/"
var g:Node
var candidate:=false
var results:Array=[]
func _initialize():call_deferred("run")
func settle():
 for i in 8:g._process(0);await process_frame
func tap(p:Vector2):
 for pressed in [true,false]:
  var e=InputEventScreenTouch.new();e.index=0;e.position=p;e.pressed=pressed;Input.parse_input_event(e);await process_frame
 await settle()
func run():
 DirAccess.make_dir_recursive_absolute(OUT)
 create_timer(60).timeout.connect(func():quit(2))
 candidate="--candidate" in OS.get_cmdline_user_args()
 var c=root.get_node("Campaign");c.current=0;c.launch=true;c.resume=false;c.muted=true;c.run_seed=731054
 g=load("res://main.tscn").instantiate();root.add_child(g);current_scene=g;g.set_process(false);g.paused=true
 Input.emulate_mouse_from_touch=true;Input.emulate_touch_from_mouse=false
 var worker:Dictionary=g.units.filter(func(u):return u.kind=="worker")[0]
 worker.hp=worker.maxhp*.8
 g.building_attack_alerts.record_hit(worker,g.elapsed);g.update_building_attack_alert()
 g.notify("『向こうの明かりが消える前に、最後の送電をつなぐ。』",100)
 g.select_guards();await settle()
 var state=JSON.stringify(g.checkpoint_data().units);var selection=g.selected.duplicate()
 for viewport in [Vector2(844,390),Vector2(640,360),Vector2(390,844)]:
  g.mobile_browser._native_test_size=viewport;g._mobile_layout();await settle()
  if viewport.x==390:g.mobile_hud.set_safe_insets(Vector4(0,28,0,22));await settle()
  var hud=g.mobile_hud
  var overlap=hud.notice.get_global_rect().intersects(hud.alert.get_global_rect())
  results.append({"width":viewport.x,"overlap":overlap,"notice":str(hud.notice.get_global_rect()),"alert":str(hud.alert.get_global_rect())})
  if candidate:
   assert(not overlap)
   assert(not hud.goal.get_global_rect().intersects(hud.alert.get_global_rect()))
   assert(hud.is_over_ui(hud.alert.get_global_rect().get_center()))
  root.get_texture().get_image().save_png(OUT+("after" if candidate else "before")+"_%d.png"%int(viewport.x))
  g.camera_focus=Vector3(18,0,18);await settle()
  await tap(hud.alert.get_global_rect().get_center())
  assert(g.camera_focus.distance_to(worker.node.position)<.01)
  assert(g.selected==selection and JSON.stringify(g.checkpoint_data().units)==state)
  if candidate:
   var y=hud.notice.position.y
   g.building_attack_alerts.reset();g.update_building_attack_alert();await settle()
   assert(not hud.alert.visible)
   if viewport.x<738:assert(hud.notice.position.y==y-48)
   g.building_attack_alerts.record_hit(worker,g.elapsed);g.update_building_attack_alert();await settle()
 var file=FileAccess.open(OUT+("after" if candidate else "before")+".json",FileAccess.WRITE);file.store_string(JSON.stringify(results,"  "));file.close()
 print("MOBILE_ALERT_LAYOUT_PASS candidate=",candidate," ",JSON.stringify(results))
 g.free();quit()
