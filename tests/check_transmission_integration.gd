extends SceneTree
var failures=0
func check(ok:bool,label:String):
 print("PASS " if ok else "FAIL ",label)
 if not ok:failures+=1
func _initialize():call_deferred("run")
func run():
 DirAccess.make_dir_recursive_absolute("user://settlement_v2")
 var c=root.get_node("Campaign");c.current=2;c.launch=true;c.resume=false;c.muted=true;c.run_seed=42813
 var g=load("res://main.tscn").instantiate();root.add_child(g);g.set_process(false);g.paused=true
 g.settlement_age=3;g.generator_on=true;g.wave=5;g.wave_clock=20
 for site in g.sites:site.reclaimed=true;site.progress=1;site.paid=true
 var random_state=g.rng.state
 g.plan_transmission_defense()
 check(g.transmission_defense.planned and g.transmission_defense.target_kind=="pump","eligible west wave announces central transmission site")
 check(g.rng.state==random_state and g.wave_clock==20,"announcement changes neither RNG nor schedule")
 g.hold_time=54.95;g.transmission_defense.advance_warning(1.0)
 g.update_mission(.05)
 check(g.boss_spawned and g.wave_clock>=11.0,"boss acceleration preserves remaining minimum warning")
 for e in g.enemies:e.node.free()
 g.enemies.clear();g.boss_spawned=false;g.hold_time=0;g.wave_clock=20
 g.rng.state=random_state
 var pending=g.checkpoint_data()
 check(g.CheckpointValidation.validate(pending),"pending raid checkpoint validates")
 g.wave=6;g.spawn_wave()
 var tagged=g.enemies.size();var end_rng=g.rng.state
 var positions=[]
 for e in g.enemies:positions.append([e.node.position,e.hp,e.speed])
 check(tagged>0 and g.enemies.all(func(e):return e.get("transmission_raider",false)),"only existing scheduled wave gets routing tag")
 for e in g.enemies:e.node.free()
 g.enemies.clear();g.transmission_defense.reset();g.rng.state=random_state;g.spawn_wave()
 var ordinary=[]
 for e in g.enemies:ordinary.append([e.node.position,e.hp,e.speed])
 check(ordinary==positions and g.rng.state==end_rng,"ordinary and targeted wave match count positions stats and RNG exactly")
 for e in g.enemies:e.node.free()
 g.enemies.clear();g.transmission_defense.restore(pending.transmission_defense);g.transmission_defense.activate_wave(6)
 var anchor=g.get_site("pump").node.position
 g.spawn_enemy(anchor+Vector3(4,0,0));g.enemies.back()["transmission_raider"]=true
 g.hold_time=10;g.update_mission(.5)
 check(g.hold_time==10 and g.transmission_blocked(),"physical occupation preserves but pauses accrued transmission")
 g.enemies.back().node.position=anchor+Vector3(12,0,0)
 g.update_mission(.5)
 check(g.hold_time==10.5 and not g.transmission_blocked(),"outside zone or stuck distant raider cannot stall objective")
 var data=g.checkpoint_data()
 check(g.CheckpointValidation.validate(data),"active raid checkpoint validates")
 var f=FileAccess.open("user://settlement_v2/checkpoint.json",FileAccess.WRITE);f.store_string(JSON.stringify(data));f.close()
 check(g.load_checkpoint(),"active raid loads through real checkpoint loader")
 check(g.transmission_defense.snapshot()==data.transmission_defense and g.enemies[0].transmission_raider,"reload preserves target dispatch and raider identity")
 var bad=data.duplicate(true);bad.transmission_defense.target_kind="hq"
 check(not g.CheckpointValidation.validate(bad),"invalid objective rejected before world mutation")
 # Controlled routing case: retain actual M3 terrain, remove defenders and stop new waves.
 for unit in g.units:unit.node.free()
 g.units.clear();g.selected.clear()
 g.enemies[0].node.position=Vector3(-28,0,-14);g.enemies[0].hp=1000
 g.wave_clock=10000;g.generator_on=false
 for tick in 400:g.simulate(.05)
 check(g.enemies[0].node.position.distance_to(anchor)<5.0,"raider traverses real M3 navigation into physical objective zone")
 check(g.enemy_navigation.queries_this_step<=32,"facility route keeps existing path query budget")
 g.enemies[0].node.position=anchor+Vector3(4,0,0);g.enemies[0].hp=0
 check(not g.transmission_blocked(),"lethal hit clears disruption immediately")
 g.mission=c.MISSIONS[0];g.transmission_defense.reset();g.plan_transmission_defense()
 check(not g.transmission_defense.planned,"mission one never plans facility raid")
 g.mission=c.MISSIONS[1];g.plan_transmission_defense()
 check(not g.transmission_defense.planned,"mission two never plans facility raid")
 print("TRANSMISSION_INTEGRATION failures=",failures)
 g.free();await process_frame;quit(1 if failures else 0)
