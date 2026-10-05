extends SceneTree
## Same short combat run on unmodified v033 and the patch; excludes visual fields.
## Absolute --script path works with either project. No project files are written.
func _initialize():call_deferred("run")
func run():
 var campaign=root.get_node("Campaign")
 campaign.current=0;campaign.launch=true;campaign.resume=false;campaign.choose_run_seed(88304)
 var g=load("res://main.tscn").instantiate();root.add_child(g);g.set_process(false)
 g.muted=true;g.low_fx=true;g.wave_clock=9999;g.ammo=240
 for unit:Dictionary in g.units:unit.cd=999
 for building:Dictionary in g.buildings:building.cd=999
 var guard:Dictionary=g.make_unit("guard",Vector3(-2,0,0))
 var grenade:Dictionary=g.make_unit("grenade",Vector3(0,0,0))
 var siege:Dictionary=g.make_unit("siegecart",Vector3(2,0,0))
 for unit:Dictionary in [guard,grenade,siege]:unit.cd=0
 for point:Vector3 in [Vector3(-2,0,-7),Vector3(0,0,-7),Vector3(2,0,-7)]:
  g.spawn_enemy(point);g.enemies.back().hp=10000
 var cadence:Array=[]
 for tick:int in 120:
  var before:Array=[guard.cd,grenade.cd,siege.cd]
  g.advance_simulation_time(.05)
  for i:int in 3:
   var unit:Dictionary=[guard,grenade,siege][i]
   if unit.cd>before[i]:cadence.append([tick,unit.kind])
 var data:Dictionary={"ammo":g.ammo,"rng":str(g.rng.state),"visual_rng":str(g.visual_rng.state),"enemy_count":g.enemies.size(),"kills":g.kills,"xp":g.xp,"elapsed":g.elapsed,"attack_ticks":cadence,"enemy_hp":[],"units":[],"shells":[]}
 for enemy:Dictionary in g.enemies:data.enemy_hp.append(enemy.hp)
 for unit:Dictionary in [guard,grenade,siege]:data.units.append({"kind":unit.kind,"hp":unit.hp,"cd":unit.cd,"shots":unit.shots,"position":g.vec_data(unit.node.position)})
 for shell:Dictionary in g.shells:data.shells.append({"from":g.vec_data(shell.from),"to":g.vec_data(shell.to),"time":shell.time,"duration":shell.duration,"damage":shell.damage,"radius":shell.radius})
 print("MUZZLE_GAMEPLAY_JSON ",JSON.stringify(data,"",true,true))
 g.free();await process_frame;quit()
