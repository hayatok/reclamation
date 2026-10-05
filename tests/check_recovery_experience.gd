extends SceneTree
var g:Node
func _initialize():call_deferred("run")
func fresh(mission:int):
 if is_instance_valid(g):g.free()
 var c=root.get_node("Campaign");c.current=mission;c.launch=true;c.resume=false;c.muted=true
 g=load("res://main.tscn").instantiate();root.add_child(g);current_scene=g;g.set_process(false)
func ready_finale():
 g.settlement_age=3;g.generator_on=true
 for site in g.sites:site.reclaimed=true
 g.hold_time=54.99;g.update_mission(.02)
 assert(g.boss_spawned)
func kill_boss():
 for e in g.enemies:
  if e.get("boss",false):g.hit(e,100000,false)
 assert(g.boss_defeated)
func run():
 fresh(2);ready_finale();g.update_mission(5)
 assert(g.hold_time==60 and not g.ended)
 kill_boss();g.update_mission(.05)
 assert(g.ended and g.result_won)
 print("FINAL_RESOLUTION_NO_WAIT_AFTER_BOSS_PASS")
 fresh(2);ready_finale();g.hold_time=59.8;g.generator_on=false;kill_boss();g.update_mission(.4)
 assert(not g.ended and is_equal_approx(g.hold_time,59.8))
 g.generator_on=true;g.get_site("substation").reclaimed=false;g.update_mission(.4)
 assert(not g.ended)
 g.get_site("substation").reclaimed=true;g.update_mission(.3)
 assert(g.ended and g.result_won)
 fresh(2);ready_finale();kill_boss();g.hold_time=59.99;g.buildings[0].hp=0;g.simulate(.05)
 assert(g.ended and not g.result_won)
 print("FINAL_RESOLUTION_POWER_FACILITY_DEFEAT_GATES_PASS")
 fresh(0)
 var worker=g.units.filter(func(u):return u.kind=="worker")[0]
 g.selected=[worker]
 var food=g.resource_nodes.filter(func(r):return r.resource=="food")[0]
 g.economy.assign_resource(worker,food)
 for step in 5:g.simulate(.05)
 g.update_worker_route_preview()
 var preview=g.worker_route_preview.get_preview_state()
 assert(preview.visible and preview.waypoint_count==worker.route.size())
 assert(preview.destination.world_position==worker.nav_endpoint)
 assert(g.worker_destination_text(worker).contains("食料"))
 g.friendly_navigation.navigation_changed();g.update_worker_route_preview()
 assert(not g.worker_route_preview.visible)
 g.selected=[];g.update_worker_route_preview();assert(not g.worker_route_preview.visible)
 var clear_point=Vector3(-15,0,10)
 # The fixture clears surrounding resources/terrain only to isolate occupancy.
 g.terrain_blocks.clear();g.resource_nodes.clear();g.sites.clear();g.rebuild_navigation()
 worker.node.position=clear_point
 assert(g.placement_issue("house",clear_point).contains("部隊"))
 print("VALIDATED_WORKER_ROUTE_AND_FOUNDATION_OCCUPANCY_PASS")
 g.free();await process_frame;quit()
