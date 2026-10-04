extends SceneTree
func _initialize():call_deferred("run")
func run():
 var campaign=root.get_node("Campaign")
 campaign.launch=true
 campaign.current=2
 var g=load("res://main.tscn").instantiate()
 root.add_child(g)
 await process_frame
 g.set_process(false)
 g.tech_level=2;g.research_active=true;g.research_time=12.5
 g.convoy_started=true;g.convoy_index=3;g.boss_spawned=true
 g.spawn_enemy(Vector3(-15,0,-15),false,true,true)
 g.enemies.back().windup=.4
 g.enemies.back().attack_pos=Vector3(2,0,3)
 g.launch_shell(Vector3(0,2,0),Vector3(3,0,3),85,4.5,"mortar",true)
 g.shells.back().time=.4
 g.save_checkpoint(false)
 g.tech_level=1;g.research_time=0;g.boss_spawned=false
 assert(g.load_checkpoint())
 assert(g.tech_level==2 and g.research_active and g.research_time==12.5)
 assert(g.convoy_started and g.convoy_index==3 and g.boss_spawned)
 assert(g.enemies.back().boss and is_equal_approx(g.enemies.back().windup,.4))
 assert(g.enemies.back().attack_pos==Vector3(2,0,3))
 assert(g.shells.size()==1 and is_equal_approx(g.shells[0].time,.4))
 assert(g.shells[0].radius==4.5 and g.shells[0].critical)
 assert(g.get_site("substation").kind=="substation")
 print("V04_SAVE_RESEARCH_BOSS_CONVOY_SHELL_PASS")
 g.queue_free()
 await process_frame
 quit()
