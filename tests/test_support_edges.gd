extends "res://tests/test_support.gd"
func edge_repair():
 reset();game.upgrades={"repair":1}
 var u=game.make_unit("guard",Vector3(0,0,8));u.hp=0
 var b=game.make_building("tower",Vector3(4,0,8),true);b.hp=0
 game.simulate(.05)
 check("repair must not revive lethal guard",game.units.has(u),false)
 check("repair must not revive lethal tower",game.buildings.has(b),false)
 print("LETHAL_REPAIR observed guard_hp=",u.hp," tower_hp=",b.hp)
 reset();game.upgrades={"repair":1}
 var victim=game.make_unit("guard",Vector3(0,0,8));victim.hp=8.96;victim.cd=999
 game.spawn_enemy(Vector3(0,0,8));game.enemies.back().cd=0
 game.simulate(.05)
 check("real enemy hit dealt lethal damage",victim.hp<=0,true)
 print("LETHAL_COMBAT after_hit_hp=",victim.hp)
 game.simulate(.05)
 check("real enemy lethal hit cannot revive next frame",game.units.has(victim),false)
 print("LETHAL_COMBAT next_frame_hp=",victim.hp)
 reset();game.upgrades={"repair":1,"armor":3}
 var armored=game.make_unit("guard",Vector3(0,0,8));armored.hp=20
 game.update_economy(1)
 check("repair derives from upgraded maxhp",armored.hp,20.8)
 reset();game.upgrades={"repair":2};game.generator_on=true
 var gen=game.get_site("generator").node.position
 var relay=game.make_building("relay",gen+Vector3(20,0,0),true)
 var remote=game.make_unit("guard",gen+Vector3(30,0,0));remote.hp=20
 game.update_economy(1)
 check("repair powered relay extends coverage",remote.hp,21)
 game.generator_on=false;game.update_economy(1)
 check("repair unpowered relay no coverage",remote.hp,21)
func edge_queue():
 reset()
 for i in 27:game.make_unit("guard",Vector3.ZERO)
 game.recruit("worker");game.recruit("worker")
 check("queue cap counts pending units",game.recruit_queue.size(),1)
 check("queue cap charges only accepted",game.resources,970)
 reset();game.upgrades={"build":3,"economy":2};game.victory_boost=8;game.build_boost=12
 var b=game.make_building("wall",Vector3(10,0,0),false)
 var w=game.make_unit("worker",Vector3(10,0,2));w.goal=w.node.position;w.task="build";w.target=b
 game.recruit("worker");game.simulate(.05)
 check("combined construction build3+fallback",b.built,.05*.13*2.1)
 check("combined production build3+fallback+economy2",game.recruit_queue[0].time,4-.05*2.6)
 reset();game.generator_on=true
 var gen=game.get_site("generator").node.position
 for i in 7:game.make_building("tower",gen,true)
 var f=game.make_building("factory",gen,true)
 game.recompute_power()
 check("power factory priority over earlier towers",f.powered,true)
 check("power available tower remainder",game.buildings.filter(func(x):return x.kind=="tower" and x.powered).size(),4)
func edge_fortress_contract():
 reset();game.upgrades={"supply":1,"repair":1,"fortress":1};game.make_unit("truck",Vector3.ZERO)
 var e=target();var before=game.ammo;game.fire(Vector3(5,0,0),e,100,"tower")
 check("master Appendix C fortress ammo squad-only",before-game.ammo,.85)
 reset();game.upgrades={"supply":3,"repair":1,"fortress":1};game.make_unit("truck",Vector3.ZERO)
 e=target();before=game.ammo;game.fire(Vector3(5,0,0),e,100,"guard")
 check("fortress+supply3 ammo reduction additive",before-game.ammo,.45)
func run():
 root.get_node("Campaign").launch=true
 game=load("res://main.tscn").instantiate();root.add_child(game);game.set_process(false);game.muted=true;game.low_fx=true
 edge_repair();edge_queue();edge_fortress_contract()
 FileAccess.open("res://edge_results.json",FileAccess.WRITE).store_string(JSON.stringify({"assertions":results.size(),"failures":failures.size(),"results":results},"  "))
 print("SUPPORT_EDGE_DONE assertions=%d failures=%d"%[results.size(),failures.size()])
 game.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
