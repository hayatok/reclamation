extends SceneTree
const Actor=preload("res://actor_visuals.gd")
func _initialize():call_deferred("run")
func run():
 var c=root.get_node("Campaign");c.current=0;c.launch=true;c.resume=false;c.muted=true;c.run_seed=410041
 var g=load("res://main.tscn").instantiate();root.add_child(g);current_scene=g;g.set_process(false)
 var workers=g.units.filter(func(u):return u.kind=="worker")
 var worker=workers[0]
 var start_food=g.stockpile.food
 var food=g.resource_nodes.filter(func(r):return r.resource=="food")[0]
 g.selected=[worker];g.command_at(food.node.position,Vector2.INF)
 var saw_cargo=false;var saw_empty=false
 for step in 600:
  g.simulate(.05)
  var rendered=g.render_interpolation.frame(.5)
  g.horde_renderer.update_friends(g.units,rendered)
  var visual=worker.node.get_meta("actor_visuals")
  assert(Actor.part_nodes(visual).size()==15)
  var visible_parts=Actor.part_visibility(visual)
  assert(visible_parts[14]==(worker.cargo>0))
  var state=rendered[worker.node.get_instance_id()]
  assert(state.part_visibility[14]==visible_parts[14])
  for pose in state.parts:assert(pose.is_finite() and absf(pose.basis.determinant())>.99)
  # Dummy headless renderer does not establish GPU instance readback.
  # Actual cargo rendering is reviewed in the native scene separately.
  if worker.cargo>0:saw_cargo=true
  elif saw_cargo:saw_empty=true
 assert(saw_cargo and saw_empty and g.stockpile.food>start_food)
 # A carrying worker retains cargo presentation through stop and immediate save/load.
 for step in 300:
  if worker.cargo>0:break
  g.simulate(.05)
 assert(worker.cargo>0)
 g.selected=[worker];g.stop_selected()
 var value=worker.cargo
 g.render_interpolation.frame(1)
 assert(Actor.part_visibility(worker.node.get_meta("actor_visuals"))[14])
 g.paused=true;assert(g.save_checkpoint(false)==OK);assert(g.load_checkpoint())
 worker=g.units.filter(func(u):return u.kind=="worker" and u.get("cargo",0)>0)[0]
 g.render_interpolation.frame(1)
 assert(worker.cargo==value and Actor.part_visibility(worker.node.get_meta("actor_visuals"))[14])
 # A stopped worker's emptied cargo is reflected even without another simulation tick.
 worker.cargo=0
 g.render_interpolation.frame(.5)
 assert(not Actor.part_visibility(worker.node.get_meta("actor_visuals"))[14])
 var legacy=Node3D.new();g.add_child(legacy);Actor.add_legacy_worker(legacy);Actor.pose(legacy,.6,true)
 assert(Actor.part_nodes(legacy.get_meta("actor_visuals")).size()==6)
 legacy.free()
 print("WORKER_RUNTIME_PASS ordinary_deposit=true cargo_stop_save_load=true interpolated_visibility=true legacy_ending=true")
 g.free();await process_frame;quit()
