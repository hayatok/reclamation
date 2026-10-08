extends SceneTree
func _initialize():call_deferred("run")
func run():
 DirAccess.make_dir_recursive_absolute("user://settlement_v2")
 var file=FileAccess.open("user://settlement_v2/checkpoint.json",FileAccess.WRITE)
 file.store_string(FileAccess.get_file_as_string("res://tests/fixtures/earned_critical_factory.json"));file.close()
 var c=root.get_node("Campaign");c.current=1;c.launch=true;c.resume=true;c.muted=true
 var g=load("res://main.tscn").instantiate();root.add_child(g);g.set_process(false);g.paused=true
 for b in g.buildings:
  if b.kind=="factory":b.enabled=false
 g.supply_feedback.reset();g.ammo=399.95;g.update_economy(.05);g.supply_feedback.finish_step(1)
 assert(is_equal_approx(float(g.supply_feedback.view().observed.supplied),.05),"Only actual capped credit is counted")
 g.supply_feedback.reset()
 var enemy=g.enemies[0];enemy.hp=100000
 var soldier=g.units.filter(func(u):return u.kind=="guard")[0]
 g.ammo=100
 var before=g.ammo
 g.fire(soldier.node.position,enemy,1,"guard",soldier)
 var paid=before-g.ammo
 g.supply_feedback.finish_step(1)
 assert(paid>0 and is_equal_approx(float(g.supply_feedback.view().observed.spent),paid),"Actual discounted shot debit is counted once")
 g.supply_feedback.reset();g.ammo=0
 g.fire(soldier.node.position,enemy,1,"guard",soldier)
 g.supply_feedback.finish_step(1);g.supply_feedback.finish_step(1);g.supply_feedback.finish_step(1)
 assert(g.supply_feedback.view().state=="reserve" and g.supply_feedback.view().observed.spent==0,"Reserve fire is distinct from actual spending")
 var observation=g.supply_feedback.view()
 g._process(.2)
 assert(g.supply_feedback.view()==observation,"Tactical pause does not advance observation")
 assert(g.load_checkpoint(),"Valid save reload")
 assert(g.supply_feedback.view().state=="quiet" and g.supply_feedback.view().bucket_count==0,"Reload warms up instead of carrying stale context")
 print("SUPPLY_REAL_HOOKS_PASS cap, discounted debit, reserve, pause, reload")
 g.queue_free();await process_frame;quit()
