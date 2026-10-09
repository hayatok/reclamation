extends SceneTree
var g
var failures=0
func check(ok:bool,label:String):
 print("PASS " if ok else "FAIL ",label)
 if not ok:failures+=1
func _initialize():call_deferred("run")
func save_reload()->bool:
 var saved=g.checkpoint_data()
 if not g.valid_checkpoint(saved):return false
 DirAccess.make_dir_recursive_absolute("user://settlement_v2")
 var f=FileAccess.open("user://settlement_v2/checkpoint.json",FileAccess.WRITE);f.store_string(JSON.stringify(saved));f.close()
 return g.load_checkpoint()
func step(seconds:float):
 for i in int(seconds/.05):
  if g.active_card:g.postpone_growth_choice()
  g.simulate(.05)
func run():
 var c=root.get_node("Campaign");c.current=1;c.launch=true;c.resume=false;c.muted=true;c.choose_run_seed(4451)
 g=load("res://main.tscn").instantiate();root.add_child(g);g.set_process(false)
 var site=g.get_site("abandoned_depot")
 check(not site.is_empty() and not site.node.visible,"unknown optional depot starts hidden")
 check(g.valid_checkpoint(g.checkpoint_data()),"new frontier checkpoint valid")
 # Controlled restoration fixture; these checks are not an earned playthrough.
 for enemy in g.enemies:enemy.node.queue_free()
 g.enemies.clear()
 var workers=g.units.filter(func(u):return u.kind=="worker").slice(0,2)
 for i in workers.size():
  workers[i].node.position=Vector3(-50+i,0,-3);workers[i].goal=workers[i].node.position
 g.refresh_frontier_visibility(0,true);g.update_ui()
 check(site.node.visible,"scouting reveals the abandoned structure")
 g.selected=workers;g.command_at(site.node.position)
 var money=g.stockpile.duplicate()
 step(4)
 check(site.paid and site.progress>0 and site.progress<1,"normal work pays once and starts restoration")
 check(g.stockpile.salvage==money.salvage-50 and g.stockpile.parts==money.parts-10,"explicit actual repair cost")
 var progress=site.progress
 check(save_reload(),"partial restoration saves and reloads")
 site=g.get_site("abandoned_depot")
 check(site.paid and is_equal_approx(site.progress,progress),"payment and progress preserved")
 step(12)
 var depots=g.buildings.filter(func(b):return b.kind=="depot")
 check(site.reclaimed and depots.size()==1 and not site.node.visible,"restoration creates one ordinary depot")
 check(not site.has("nav_half_extents") and g.nav.is_point_solid(Vector2i(-50,-8)),"only completed building owns the footprint")
 check(g.stockpile.salvage==money.salvage-50 and g.stockpile.parts==money.parts-10,"multiple workers and reload do not double charge")
 check(depots.size()==1 and depots[0].hp==260 and depots[0].built==1,"ordinary health and construction state")
 check(save_reload(),"completed restoration roundtrip")
 depots=g.buildings.filter(func(b):return b.kind=="depot");site=g.get_site("abandoned_depot")
 check(depots.size()==1 and not site.node.visible,"reload never creates a duplicate or visible ghost")
 check(g.dismantle_refund_cost(depots[0])=={"salvage":25,"parts":5},"refund is based on actual repair cost")
 g.dismantle_building(depots[0]);step(.1)
 check(not g.nav.is_point_solid(Vector2i(-50,-8)),"dismantling releases the site footprint")
 check(g.placement_issue("depot",site.node.position).is_empty(),"retired site leaves no invisible build exclusion")
 check(save_reload(),"destroyed depot and claimed site remain valid")
 check(g.buildings.filter(func(b):return b.kind=="depot").is_empty(),"reload does not regenerate dismantled depot")
 var bad=g.checkpoint_data();bad.sites[1].paid=false
 check(not g.valid_checkpoint(bad),"unpaid completed repair is rejected")
 print("FRONTIER_DEPOT_RESULT failures=",failures)
 g.free();await process_frame;quit(1 if failures else 0)
