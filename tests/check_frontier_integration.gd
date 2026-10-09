extends SceneTree
var checks=0
func _initialize():call_deferred("run")
func check(value:bool,title:String):
 if not value:push_error(title);quit(1);assert(value,title)
 checks+=1
func run():
 var c=root.get_node("Campaign");c.current=1;c.launch=true;c.resume=false;c.muted=true;c.choose_run_seed(4451)
 var g=load("res://main.tscn").instantiate();root.add_child(g);g.set_process(false);g.paused=false
 check(g.frontier!=null,"frontier controller ready")
 check(g.buildings[0].node.position==Vector3(-64,0,48),"home moved")
 check(g.nav.region==Rect2i(-96,-80,193,161),"broad grid")
 check(g.sites.size()==2 and g.sites[0].kind=="generator" and g.sites[1].kind=="abandoned_depot","optional depot replaces no objective and no old convoy facility")
 check(g.enemies.size()==32,"initial sleeping packs")
 check(g.combat_targets().is_empty(),"unknown mobs and nest excluded")
 check(g.frontier_visibility.structure_memory("frontier_nest").is_empty(),"no nest marker before discovery")
 check(not g.frontier.nest.node.visible,"unknown nest hidden")
 check(g.frontier_visibility.is_visible(g.buildings[0].node.position),"home vision")
 check(g.resource_at(Vector3(30,0,12)).is_empty(),"unexplored resource not selectable")
 check(g.valid_checkpoint(g.checkpoint_data()),"new checkpoint accepted")
 var scout=g.units.filter(func(u):return u.kind=="guard")[0]
 g.selected=[scout]
 g.command_at(Vector3(-25,0,33))
 for i in 150:
  g.simulate(.05)
 check(scout.node.position.x>-40,"scout can leave old 30m map")
 check(g.frontier_visibility.is_explored(scout.node.position),"scout reveals actual route")
 # Controlled integration edge, not an earned assault/playthrough.
 scout.node.position=Vector3(45,0,-48);scout.goal=scout.node.position;scout.task="idle";scout.route.clear()
 g.refresh_frontier_visibility(0,true)
 check(g.frontier.nest.known and g.frontier.nest.node.visible,"sighting discovers nest")
 check(g.frontier_visibility.structure_discovered("frontier_nest"),"discovery memory")
 g.selected=[scout];g.command_at(g.frontier.nest.node.position)
 check(scout.task=="focus_fire" and scout.target==g.frontier.nest,"right click focuses structure")
 var snapshot=g.checkpoint_data()
 check(snapshot.units[g.units.find(scout)].target_type=="structure","structure focus saves")
 check(g.valid_checkpoint(snapshot),"discovered checkpoint valid")
 DirAccess.make_dir_recursive_absolute("user://settlement_v2")
 var f=FileAccess.open("user://settlement_v2/checkpoint.json",FileAccess.WRITE);f.store_string(JSON.stringify(snapshot));f.close()
 check(g.load_checkpoint(),"actual checkpoint reload")
 check(g.frontier.nest.known and g.selected[0].target==g.frontier.nest,"target restored")
 check(g.enemies.size()==32,"no duplicate sleeping packs on reload")
 var live_before=g.checkpoint_data()
 var invalid=JSON.parse_string(JSON.stringify(live_before))
 invalid.frontier.nest.known=false
 f=FileAccess.open("user://settlement_v2/checkpoint.json",FileAccess.WRITE);f.store_string(JSON.stringify(invalid));f.close()
 check(not g.load_checkpoint(),"inconsistent discovery save rejected")
 check(g.checkpoint_data()==live_before,"rejected save preserves live state")
 var hp=g.frontier.nest.hp
 g.detonate_shell({"to":g.frontier.nest.node.position,"radius":4.1,"damage":85.0,"kind":"mortar","critical":false})
 check(is_equal_approx(g.frontier.nest.hp,hp-85.0),"shell structure damage exactly once")
 check(g.frontier.alarm_triggered,"first assault triggers warning")
 check(not g.ended,"no old timer victory")
 g.buildings[0].hp=0
 g.hit(g.frontier.nest,10000,false)
 g.simulate(.05)
 check(g.ended and not g.result_won,"simultaneous headquarters loss takes priority")
 g.free();await process_frame
 c.current=1;c.launch=true;c.resume=false;c.choose_run_seed(4451)
 g=load("res://main.tscn").instantiate();root.add_child(g);g.set_process(false)
 scout=g.units[0];scout.node.position=Vector3(45,0,-48);scout.goal=scout.node.position
 g.refresh_frontier_visibility(0,true)
 g.hit(g.frontier.nest,10000,false)
 g.simulate(.05)
 check(g.ended and g.result_won,"nest destruction wins actual main")
 check(g.hold_time==0 and not g.convoy_started,"no inherited convoy or hold requirement")
 check(is_instance_valid(g.modal) and is_instance_valid(g.aftermath_scene),"assault completion presentation created")
 check(g.aftermath_scene.camera_focus==g.frontier.nest.node.position,"completion view stays at conquered nest outside old map")
 print("FRONTIER_INTEGRATION_PASS checks=",checks)
 g.free();await process_frame;quit()
