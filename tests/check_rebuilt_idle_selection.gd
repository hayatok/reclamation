extends SceneTree
const OUT="user://rebuilt_idle_selection/"
var g:Node
func _initialize():call_deferred("run")
func settle():
 for frame in 8:g._process(0);await process_frame
func tap(p:Vector2):
 for down in [true,false]:
  var e=InputEventScreenTouch.new();e.index=0;e.position=p;e.pressed=down;Input.parse_input_event(e);await process_frame
func run():
 create_timer(45).timeout.connect(func():quit(2));DirAccess.make_dir_recursive_absolute(OUT)
 var c=root.get_node("Campaign");c.current=1;c.launch=true;c.resume=false;c.muted=true
 g=load("res://main.tscn").instantiate();root.add_child(g);current_scene=g;g.set_process(false);g.paused=true
 Input.emulate_mouse_from_touch=true;Input.emulate_touch_from_mouse=false
 g.select_guards();await settle();var hud=g.mobile_hud
 var orders_before=JSON.stringify(g.checkpoint_data().units)
 await tap(hud.order_button.get_global_rect().get_center());await settle()
 await tap(hud.append_button.get_global_rect().get_center());await settle()
 assert(g.mobile_input.controller.mode==2 and g.mobile_input.controller.append)
 await tap(hud.idle_button.get_global_rect().get_center());await settle()
 assert(g.selected.size()==1 and g.selected[0].kind=="worker")
 assert(JSON.stringify(g.checkpoint_data().units)==orders_before,"Selection must not mutate existing unit orders")
 var mode=g.mobile_input.controller.mode;var append=g.mobile_input.controller.append
 var tag="after" if mode==0 and not append else "before"
 root.get_texture().get_image().save_png(OUT+tag+".png")
 if tag=="after":
  assert(mode==0 and not append and g.paused)
  await tap(hud.idle_button.get_global_rect().get_center());await settle()
  assert(g.selected.size()==1 and g.selected[0].kind=="worker" and g.mobile_input.controller.mode==0)
  assert(JSON.stringify(g.checkpoint_data().units)==orders_before)
  assert(g.save_checkpoint(false)==OK and g.load_checkpoint())
 var result={"mode_after_idle":mode,"append_after_idle":append,"selected_worker":true,"synthetic_touch":true,"real_phone":false}
 var f=FileAccess.open(OUT+tag+".json",FileAccess.WRITE);f.store_string(JSON.stringify(result,"  "));f.close()
 print("IDLE_MODE ",JSON.stringify(result));g.free();quit()
