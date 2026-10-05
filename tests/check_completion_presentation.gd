extends SceneTree
var g:Node
func _initialize():call_deferred("run")
func run():
 var c=root.get_node("Campaign")
 for mission in 3:
  c.current=mission;c.launch=true;c.resume=false;c.muted=true;c.run_seed=44
  g=load("res://main.tscn").instantiate();root.add_child(g);current_scene=g;g.set_process(false)
  var before=g.checkpoint_data();var seed_state=[g.rng.state,g.card_rng.state,g.visual_rng.state]
  g.finish(true)
  await process_frame
  await process_frame
  assert(g.ended and g.result_won and is_instance_valid(g.aftermath_scene))
  assert(g.modal is Control and g.modal.visible and g.modal.panel.size.y<400)
  assert([g.rng.state,g.card_rng.state,g.visual_rng.state]==seed_state)
  var after=g.checkpoint_data()
  for key in ["stockpile","elapsed","kills","upgrades","units","enemies","buildings","sites"]:assert(before[key]==after[key],"Presentation changed gameplay "+key)
  for child in g.root_ui.get_children():
   if child is CanvasItem and child!=g.modal:assert(not child.visible)
  var elapsed=g.elapsed
  g.aftermath_scene.sample_at(5.6);assert(g.aftermath_scene.complete and g.elapsed==elapsed)
  g.finish(true);assert(g.get_children().filter(func(n):return n==g.aftermath_scene).size()==1)
  g.free();await process_frame
 print("COMPLETION_PRESENTATION_THREE_MISSIONS_NO_GAMEPLAY_OR_RNG_MUTATION_PASS")
 c.current=0;c.launch=true;c.resume=false
 g=load("res://main.tscn").instantiate();root.add_child(g);current_scene=g;g.set_process(false)
 g.finish(false);assert(g.ended and not g.result_won and not is_instance_valid(g.aftermath_scene))
 g.free();await process_frame
 print("DEFEAT_REMAINS_SEPARATE_PASS");quit(0)
