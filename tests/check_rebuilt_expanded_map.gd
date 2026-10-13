extends SceneTree
const OUT="user://expanded_map_review/"
var g:Node
func _initialize():call_deferred("run")
func settle():
 for frame in 8:g._process(0);await process_frame
func touch(p:Vector2,down:bool,index:int=0):
 var e=InputEventScreenTouch.new();e.index=index;e.position=p;e.pressed=down;Input.parse_input_event(e);await process_frame
func tap(p:Vector2):
 await touch(p,true);await touch(p,false);await settle()
func button(text:String)->Button:
 for b in g.mobile_hud.popup.find_children("*","Button",true,false):
  if b.text==text:return b
 return null
func run():
 create_timer(60).timeout.connect(func():quit(2));DirAccess.make_dir_recursive_absolute(OUT)
 var c=root.get_node("Campaign");c.current=1;c.launch=true;c.resume=false;c.muted=true
 g=load("res://main.tscn").instantiate();root.add_child(g);current_scene=g;g.set_process(false);g.paused=true
 Input.emulate_mouse_from_touch=true;Input.emulate_touch_from_mouse=false
 g.select_guards();await settle();var hud=g.mobile_hud
 var units=JSON.stringify(g.checkpoint_data().units);var selection=g.selected.duplicate();var parent=g.minimap.get_parent()
 root.get_texture().get_image().save_png(OUT+"before.png")
 hud._show_selection();await settle();await tap(button("地図を開く").get_global_rect().get_center())
 assert(is_instance_valid(hud.expanded_map));assert(g.minimap.size.y>200)
 root.get_texture().get_image().save_png(OUT+"landscape.png")
 var area=g.minimap.get_global_rect();var old=g.camera_focus
 await tap(area.position+area.size*Vector2(.8,.3));assert(g.camera_focus.distance_to(old)>10)
 var moved=g.camera_focus
 await touch(area.get_center(),true);g._mobile_reset("touchcancel");await touch(area.get_center(),false);await settle();assert(g.camera_focus==moved)
 await touch(area.get_center(),true);g._mobile_reset("blur");await touch(area.get_center(),false);await settle();assert(g.camera_focus==moved)
 await touch(area.get_center(),true,0);await touch(area.get_center()+Vector2(25,0),true,1)
 await touch(area.get_center(),false,0);await touch(area.get_center()+Vector2(25,0),false,1);await settle()
 assert(g.camera_focus==moved)
 await touch(area.get_center(),true)
 var drag=InputEventScreenDrag.new();drag.index=0;drag.position=area.get_center()+Vector2(40,0);drag.relative=Vector2(40,0);Input.parse_input_event(drag);await process_frame
 await touch(drag.position,false);await settle();assert(g.camera_focus==moved)
 await tap(button("選択へ戻る").get_global_rect().get_center());assert(g.minimap.get_parent()==parent)
 await tap(button("地図を開く").get_global_rect().get_center());assert(is_instance_valid(hud.expanded_map))
 await touch(g.minimap.get_global_rect().get_center(),true)
 g.mobile_browser._native_test_size=Vector2(390,844);g._mobile_layout();await settle()
 hud.safe_insets=Vector4(0,28,0,22);hud._layout();await settle()
 await touch(g.minimap.get_global_rect().get_center(),false);await settle();assert(g.camera_focus==moved)
 root.get_texture().get_image().save_png(OUT+"portrait.png")
 await tap(hud.popup.get_meta("fixed_close").get_global_rect().get_center())
 assert(not hud.has_open_popup() and g.minimap.get_parent()==parent and g.paused)
 assert(g.selected==selection and JSON.stringify(g.checkpoint_data().units)==units)
 assert(g.save_checkpoint(false)==OK and g.load_checkpoint())
 print("EXPANDED_MAP_PASS camera navigation, multitouch rejection, back, repeated open, portrait safearea, close, selection/orders, save/load")
 g.free();quit()
