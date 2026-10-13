extends SceneTree
const OUT="user://nest_damage_review/"
var g:Node
func _initialize():call_deferred("run")
func settle():
 for i in 8:g._process(0);await process_frame
 await RenderingServer.frame_post_draw
func run():
 DirAccess.make_dir_recursive_absolute(OUT)
 create_timer(60).timeout.connect(func():quit(2))
 DirAccess.make_dir_recursive_absolute("user://settlement_v2")
 var f=FileAccess.open("user://settlement_v2/checkpoint.json",FileAccess.WRITE);f.store_string(FileAccess.get_file_as_string("res://tests/fixtures/native_nest_first_assault.json"));f.close()
 var c=root.get_node("Campaign");c.current=1;c.launch=true;c.resume=true;c.muted=true
 g=load("res://main.tscn").instantiate();root.add_child(g);current_scene=g;g.set_process(false);g.paused=true
 if is_instance_valid(g.choice_panel):g.choice_panel.queue_free()
 g.active_card=false;g.camera_focus=Vector3(55,0,-42);g.camera.size=50
 await settle()
 var units_before=JSON.stringify(g.checkpoint_data().units)
 var rng_before=[g.rng.state,g.card_rng.state,g.visual_rng.state]
 var result=g.frontier.apply_damage(g.frontier.nest,g.frontier.nest.hp-3000)
 assert(result.applied>0 and g.frontier.nest.hp==3000)
 await settle()
 root.get_texture().get_image().save_png(OUT+"integrated_half.png")
 assert(g.frontier.nest.node.get_node("Damaged").visible)
 assert(JSON.stringify(g.checkpoint_data().units)==units_before)
 assert([g.rng.state,g.card_rng.state,g.visual_rng.state]==rng_before)
 print("NEST_DAMAGE_INTEGRATED half HP through actual damage handler; troops/RNG unchanged; controlled visual fixture, not normal victory")
 g.free();quit()
