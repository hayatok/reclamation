extends SceneTree
var failures=0
var g
func check(ok:bool,title:String):
 print("PASS " if ok else "FAIL ",title)
 if not ok:failures+=1
func refresh():
 g.refresh_context_commands();g.update_ui()
 await process_frame
func _initialize():call_deferred("run")
func run():
 DirAccess.make_dir_recursive_absolute("user://settlement_v2")
 var f=FileAccess.open("user://settlement_v2/checkpoint.json",FileAccess.WRITE)
 f.store_string(FileAccess.get_file_as_string("res://tests/fixtures/earned_frontier_departure.json"));f.close()
 var c=root.get_node("Campaign");c.current=1;c.launch=true;c.resume=true;c.muted=true
 g=load("res://main.tscn").instantiate();root.add_child(g);g.set_process(false);g.paused=true
 g.selected.clear();g.inspected=g.buildings.filter(func(b):return b.kind=="factory")[0];g.update_selection()
 for i in 3:await refresh()
 check(g.command_heading.text=="補給満杯" and g.command_heading.is_visible_in_tree(),"earned full-ammo factory shows its state")
 var state=g.checkpoint_data();await refresh()
 check(g.checkpoint_data()==state,"display refresh preserves all saved state")
 g.toggle_inspected();await refresh()
 check(g.command_heading.text=="手動停止","ordinary factory toggle displays manual stop")
 g.toggle_inspected();g.generator_on=false;g.recompute_power();await refresh()
 check(g.command_heading.text=="未給電","unpowered factory state is visible")
 g.generator_on=true;g.recompute_power();g.ammo=100;g.resources=0;g.stockpile.salvage=0;await refresh()
 check(g.command_heading.text=="資材不足","controlled resource shortage displays exact status")
 g.inspected.built=.5;await refresh()
 check(g.queue_caption.text=="建築 50%" and g.queue_caption.is_visible_in_tree() and not g.command_heading.is_visible_in_tree(),"construction progress takes precedence")
 g.select_headquarters();await refresh()
 check(g.command_heading.text=="生産・発展","HQ category remains intact")
 print("FACTORY_HEADING_RESULT failures=",failures)
 g.free();await process_frame;quit(1 if failures else 0)
