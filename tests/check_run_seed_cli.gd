extends SceneTree
# Run with -- --run-seed=123457. Overrides intentionally reproduce retries.
var g:Node
func _initialize():call_deferred("run")
func run():
 var campaign=root.get_node("Campaign")
 campaign.launch=true;campaign.muted=true
 g=load("res://main.tscn").instantiate();root.add_child(g);current_scene=g;g.set_process(false)
 await process_frame
 assert(g.run_seed==123457,"command-line seed reaches normal scene startup")
 var state=str(g.rng.state);var cards=str(g.card_rng.state)
 g.start_mission(0)
 await scene_changed
 g=current_scene;g.set_process(false)
 await process_frame
 assert(g.run_seed==123457 and str(g.rng.state)==state and str(g.card_rng.state)==cards,"CLI override deliberately repeats the run on retry")
 g.start_mission(0,77)
 await scene_changed
 g=current_scene;g.set_process(false)
 await process_frame
 assert(g.run_seed==77,"explicit call override takes precedence over CLI")
 assert(g.save_checkpoint(false)==OK)
 g.resume_checkpoint()
 await scene_changed
 g=current_scene;g.set_process(false)
 await process_frame
 assert(g.run_seed==77,"resume keeps saved identity despite different CLI seed")
 print("RUN_SEED_CLI_PASS")
 g.queue_free();await process_frame;await process_frame;quit()
