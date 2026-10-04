extends SceneTree
func _initialize():call_deferred("run")
func run():
 root.get_node("Campaign").launch=true
 var g=load("res://main.tscn").instantiate();root.add_child(g)
 await process_frame
 g.set_process(false);g.low_fx=true
 var mortar=g.make_building("mortar",Vector3(0,0,5),true)
 for x in [-1,0,1]:g.spawn_enemy(Vector3(x,0,-5))
 g.upgrades={"multi":2,"salvo":2,"sweep":1}
 mortar.shots=3
 g.fire(Vector3(0,2.4,5),g.enemies[0],85,"mortar",mortar)
 assert(g.shells.size()==7)
 assert(mortar.shots==4)
 assert(g.shells[0].damage==85)
 print("GROWTH_SINGLE_SHELL_TO_SEVEN_SHELL_BARRAGE_PASS")
 g.convoy_route_choice=1;g.convoy_halted=true;g.convoy_encounter_stage=2;g.convoy_pending={"stage":1,"clock":2.4}
 g.save_checkpoint(false)
 g.convoy_route_choice=0;g.convoy_pending={}
 assert(g.load_checkpoint())
 assert(g.convoy_route_choice==1 and g.convoy_halted and g.convoy_encounter_stage==2)
 assert(is_equal_approx(g.convoy_pending.clock,2.4))
 print("ROUTE_HALT_PENDING_AMBUSH_SAVE_PASS")
 g.queue_free();await process_frame;quit()
