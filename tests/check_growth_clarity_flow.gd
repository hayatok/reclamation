extends SceneTree
var g
var states={}
func _initialize():call_deferred("run")
func capture(key):states[key]=g.checkpoint_data()
func run():
 DirAccess.make_dir_recursive_absolute("user://settlement_v2")
 var f=FileAccess.open("user://settlement_v2/checkpoint.json",FileAccess.WRITE)
 f.store_string(FileAccess.get_file_as_string("res://tests/fixtures/earned_frontier_growth_resume.json"));f.close()
 var c=root.get_node("Campaign");c.current=1;c.launch=true;c.resume=true;c.muted=true
 g=load("res://main.tscn").instantiate();root.add_child(g);g.set_process(false)
 if not g.active_card:push_error("earned fixture not resumed");quit(1);return
 for i in 3:await process_frame
 capture("opened")
 g.postpone_growth_choice();g.open_growth_choices();capture("reopened")
 g.reroll_cards();capture("rerolled")
 g.choose_upgrade(0);capture("chosen")
 if g.save_checkpoint(false)!=OK or not g.load_checkpoint():quit(2);return
 capture("resumed")
 f=FileAccess.open(OS.get_environment("GROWTH_OUT") if not OS.get_environment("GROWTH_OUT").is_empty() else "user://growth_clarity_state.json",FileAccess.WRITE);f.store_string(JSON.stringify(states));f.close()
 print("EARNED_GROWTH_FLOW_PASS")
 g.free();await process_frame;quit()
