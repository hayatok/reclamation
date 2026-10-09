extends SceneTree
var failures=0
var g
func check(ok:bool,title:String):
 print("PASS " if ok else "FAIL ",title)
 if not ok:failures+=1
func _initialize():call_deferred("run")
func run():
 DirAccess.make_dir_recursive_absolute("user://settlement_v2")
 var f=FileAccess.open("user://settlement_v2/checkpoint.json",FileAccess.WRITE)
 f.store_string(FileAccess.get_file_as_string("res://tests/fixtures/frontier_depot_earned_before_repair.json"));f.close()
 var c=root.get_node("Campaign");c.current=1;c.launch=true;c.resume=true;c.muted=true
 g=load("res://main.tscn").instantiate();root.add_child(g);g.set_process(false);g.paused=true
 g.selected.assign([g.units[2],g.units[3]]);g.command_at(Vector3(-50,0,-8));g.update_selection()
 for i in 3:await process_frame
 check(g.command_heading.text=="復旧中" and g.command_heading.is_visible_in_tree(),"paused restoration order is visible for two workers")
 var state=g.checkpoint_data()
 for i in 3:g.refresh_context_commands();g.update_ui();await process_frame
 check(g.checkpoint_data()==state,"UI refresh preserves gameplay and RNG")
 var u=g.units[2]
 # Controlled navigation state: verifies presentation, not pathfinding.
 u.nav_goal=u.goal;u.planned=u.goal;u.nav_task=u.task;u.nav_target_node=u.target.node;u.nav_revision=g.friendly_navigation.revision;u.nav_status="blocked"
 g.update_ui();await process_frame
 check(g.command_heading.text=="経路なし / 通路を開ける","blocked order overrides ordinary group activity")
 u.nav_status="work_waiting";g.update_ui();await process_frame
 check(g.command_heading.text=="作業場所の空き待ち","work-space wait is visible")
 g.select_headquarters();g.update_ui();await process_frame
 check(g.command_heading.text=="生産・発展","HQ restores its context heading")
 g.production.queue_unit(g.inspected,"worker");g.refresh_context_commands(true);g.update_ui();await process_frame
 check(g.queue_caption.is_visible_in_tree() and not g.command_heading.is_visible_in_tree(),"producer queue keeps its existing priority")
 g.selected.assign([g.units[0]]);g.inspected={};g.update_selection();await process_frame
 check(g.command_heading.text==g.selected_order_text() and g.command_heading.is_visible_in_tree(),"combat selection restores live order")
 g.selected.clear();g.update_selection();await process_frame
 check(not g.command_heading.is_visible_in_tree(),"empty selection hides stale status")
 print("DESKTOP_ORDER_RESULT failures=",failures)
 g.free();await process_frame;quit(1 if failures else 0)
