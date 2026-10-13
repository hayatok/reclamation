extends SceneTree
var g:Node
func _initialize():call_deferred("run")
func settle():
 for i in 8:g._process(0);await process_frame
 await RenderingServer.frame_post_draw
func run():
 create_timer(90).timeout.connect(func():quit(2))
 DirAccess.make_dir_recursive_absolute("user://settlement_v2")
 var f=FileAccess.open("user://settlement_v2/checkpoint.json",FileAccess.WRITE);f.store_string(FileAccess.get_file_as_string("res://tests/fixtures/native_nest_first_assault.json"));f.close()
 var c=root.get_node("Campaign");c.current=1;c.launch=true;c.resume=true;c.muted=true
 g=load("res://main.tscn").instantiate();root.add_child(g);current_scene=g;g.set_process(false);g.paused=true
 if is_instance_valid(g.choice_panel):g.choice_panel.queue_free()
 g.active_card=false
 await settle()
 var units=g.units.map(func(u):return [u.node.position,u.hp,u.task,u.target])
 g.frontier.apply_damage(g.frontier.nest,10000)
 g.finish(true)
 g.aftermath_transition.set_process(false);g.aftermath_transition.hide()
 g.settle_aftermath_presentation();g.aftermath_scene.set_process(false)
 var v=g.aftermath_scene._frontier_scene
 print("RECLAMATION_LOCATION ",v.chosen_world if is_instance_valid(v) else "fallback")
 for t in [0.0,2.5,4.2]:
  g.aftermath_scene.sample_at(t)
  await settle()
  root.get_texture().get_image().save_png("user://payoff_%s.png"%str(t))
 assert(g.units.map(func(u):return [u.node.position,u.hp,u.task,u.target])==units)
 print("RECLAMATION_CONTROLLED_REVIEW_PASS actual win presentation; final damage injected; not earned victory")
 g.free();quit()
