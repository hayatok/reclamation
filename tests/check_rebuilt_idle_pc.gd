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
 assert(g.mobile_input==null);await process_frame
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
 print("PC_IDLE_SELECTION_PASS failures=",failures)
 g.free();await process_frame;quit(1 if failures else 0)
