extends SceneTree
var g
var failures=0
func check(ok:bool,message:String):
 print("PASS " if ok else "FAIL ",message)
 if not ok:failures+=1
func _initialize():call_deferred("run")
func load_game():
 var c=root.get_node("Campaign");c.current=1;c.launch=true;c.resume=true;c.muted=true
 g=load("res://main.tscn").instantiate();root.add_child(g);g.set_process(false)
 for i in 3:await process_frame
 g.mobile_hud.sync();await process_frame
func run():
 DirAccess.make_dir_recursive_absolute("user://settlement_v2")
 var f=FileAccess.open("user://settlement_v2/checkpoint.json",FileAccess.WRITE);f.store_string(FileAccess.get_file_as_string("res://tests/fixtures/earned_frontier_departure.json"));f.close()
 await load_game()
 var units_before=g.checkpoint_data().units.duplicate(true)
 var waiting=g.units.filter(func(u):return g.worker_needs_attention(u))
 check(waiting.size()==5 and g.units.filter(func(u):return u.kind=="worker").size()==14,"earned state has five waiting and nine working workers")
 g.select_idle_worker();var first=g.selected[0];g.select_idle_worker()
 check(g.selected.size()==1 and g.selected[0]!=first,"ordinary shortcut still cycles one worker")
 var e=InputEventKey.new();e.keycode=KEY_PERIOD;e.pressed=true;e.shift_pressed=true
 g._unhandled_input(e)
 check(g.selected==waiting,"Shift+period selects only waiting workers")
 check(g.checkpoint_data().units==units_before,"selection preserves all cargo, orders and active workers")
 check(g.save_checkpoint(false)==OK,"save selected waiting group")
 g.free();await process_frame;await load_game()
 check(g.selected.size()==5 and g.selected.all(func(u):return g.worker_needs_attention(u)),"resume restores five selected workers")
 g.select_guards();g.mobile_hud._show_selection()
 for i in 3:await process_frame
 var controls=g.mobile_hud.popup.find_children("*","Button",true,false).filter(func(b):return b.text=="待機 5人を選択")
 check(controls.size()==1 and controls[0].size.y>=44,"counted touch control has a finger-size target")
 if controls.size()==1:
  var point=controls[0].get_global_rect().get_center()
  var motion=InputEventMouseMotion.new();motion.position=point;motion.global_position=point;Input.parse_input_event(motion)
  for down in [true,false]:
   var click=InputEventMouseButton.new();click.device=InputEvent.DEVICE_ID_EMULATION;click.position=point;click.global_position=point;click.button_index=MOUSE_BUTTON_LEFT;click.pressed=down;click.button_mask=MOUSE_BUTTON_MASK_LEFT if down else 0
   Input.parse_input_event(click);Input.flush_buffered_events();await process_frame
 check(g.selected.size()==5 and not is_instance_valid(g.mobile_hud.popup),"touch chooses five workers and returns to map")
 check(g.checkpoint_data().units==units_before,"touch selection and reload preserve worker state")
 print("WAITING_SELECTION_RESULT failures=",failures," viewport=",root.size)
 g.free();await process_frame;quit(1 if failures else 0)
