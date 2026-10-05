extends SceneTree
const WeaponMuzzles=preload("res://weapon_muzzles.gd")
const ActorVisuals=preload("res://actor_visuals.gd")
var g
var checks:int=0
var failures:int=0
func _initialize():call_deferred("run")
func check(value:bool,message:String):
 checks+=1
 if not value:failures+=1;push_error(message)
func near(a:Vector3,b:Vector3,message:String):check(a.distance_to(b)<.0001,message)
func enemy(at:Vector3)->Dictionary:
 g.spawn_enemy(at)
 var target:Dictionary=g.enemies.back()
 target.hp=10000;target.armored=false;target.speed=1
 return target
func clear_fx():
 for shell:Dictionary in g.shells:shell.node.free()
 g.shells.clear()
 for list:Array in g.battle_fx.particles.values():list.clear()
func run():
 root.get_node("Campaign").current=0;root.get_node("Campaign").launch=true
 g=load("res://main.tscn").instantiate();root.add_child(g);g.set_process(false)
 g.muted=true;g.low_fx=true;g.wave_clock=9999
 var guard:Dictionary=g.make_unit("guard",Vector3.ZERO)
 var launcher:Dictionary=g.make_unit("grenade",Vector3.ZERO)
 var truck:Dictionary=g.make_unit("truck",Vector3(0,0,-10.96))
 var target:Dictionary=enemy(Vector3(0,0,-6))
 var pierced:Dictionary=enemy(Vector3(.87,0,-10))
 var extra:Dictionary=enemy(Vector3(3,0,-6))
 g.upgrades={"fortress":1,"pierce":1,"multi":1};g.ammo=100
 var rng=RandomNumberGenerator.new();rng.state=g.rng.state;rng.randf()
 var expected_rng:int=rng.state
 var before_fx:int=g.battle_fx.rng.state
 var fx_rng=RandomNumberGenerator.new();fx_rng.state=before_fx;fx_rng.randf();fx_rng.randf()
 var origin:=Vector3(0,1,0)
 check(not g.mobile_aura(origin),"legacy origin outside truck aura")
 g.fire(origin,target,20,"guard",guard)
 check(is_equal_approx(g.ammo,99),"fixed muzzle does not change supply range")
 check(is_equal_approx(target.hp,9980),"rifle damage unchanged at aura boundary")
 check(is_equal_approx(pierced.hp,9980),"piercing direction still uses simulation origin")
 check(is_equal_approx(extra.hp,9987),"multishot damage unchanged")
 check(g.rng.state==expected_rng,"one gameplay RNG draw per shot")
 check(g.battle_fx.rng.state==fx_rng.state,"socket adds no visual RNG draws")
 ActorVisuals.pose(guard.node,0,false,0)
 g.render_interpolation.reset(g.units,g.enemies,[])
 var frames:Dictionary=g.render_interpolation.frame(1)
 g.battle_fx.update(0,g.camera,[],frames)
 var muzzle:Vector3=WeaponMuzzles.world_position(WeaponMuzzles.anchor(guard),frames,Vector3.INF)
 check(g.mobile_aura(muzzle),"fixture separates visible muzzle from gameplay aura boundary")
 near(g.battle_fx.particles.flash[0].pos,muzzle,"live fire flash uses visible rifle socket")
 check(g.enemies.size()==3,"visual alignment cannot change enemy count")
 clear_fx()
 g.upgrades={};g.ammo=100
 target.hp=10000;pierced.hp=10000;extra.hp=10000
 g.fire(origin,target,56,"grenade",launcher)
 var shell:Dictionary=g.shells[0]
 check(is_equal_approx(g.ammo,97) and is_equal_approx(shell.damage,56),"launcher ammo and damage unchanged")
 check(is_equal_approx(shell.duration,.8) and is_equal_approx(shell.radius,3),"launcher flight duration and radius unchanged")
 near(shell.from,origin,"launcher simulation launch coordinate preserved")
 ActorVisuals.pose(launcher.node,1.1,true,0)
 g.render_interpolation.reset(g.units,g.enemies,[]);frames=g.render_interpolation.frame(1)
 g.resolve_shell_muzzles(frames);g.battle_fx.update(0,g.camera,[],frames)
 muzzle=WeaponMuzzles.world_position(WeaponMuzzles.anchor(launcher),frames,Vector3.INF)
 near(shell.visual_from,muzzle,"launcher visual spawn on actual posed socket")
 near(shell.node.position,muzzle,"projectile first displayed position equals flash")
 near(g.battle_fx.particles.flash[0].pos,muzzle,"launcher flash and projectile agree")
 launcher.node.position+=Vector3(5,0,2);launcher.node.rotation.y+=PI*.7
 ActorVisuals.pose(launcher.node,2.0,true,.15)
 g.render_interpolation.reset(g.units,g.enemies,[]);frames=g.render_interpolation.frame(1)
 g.resolve_shell_muzzles(frames);g.update_shells(.1)
 near(shell.visual_from,muzzle,"departed projectile never follows shooter")
 near(shell.node.position,muzzle.lerp(target.node.position,.125)+Vector3(0,sin(.125*PI)*3,0),"projectile retains ballistic path after shooter moves")
 check(target.hp==10000,"no early projectile damage")
 g.update_shells(.701)
 check(is_equal_approx(target.hp,9944) and g.shells.is_empty(),"projectile damage arrives at original time and target")
 clear_fx()
 var siege:Dictionary=g.make_unit("siegecart",Vector3(-3,0,2))
 g.fire(Vector3.ZERO,target,96,"mortar",siege)
 shell=g.shells[0]
 var simulation_origin:Vector3=siege.node.to_global(WeaponMuzzles.SIEGE_MUZZLE)
 near(shell.from,simulation_origin,"cart simulation muzzle contract preserved")
 g.render_interpolation.reset(g.units,g.enemies,[])
 g.render_interpolation.before_step(g.units,g.enemies,[])
 siege.node.position+=Vector3(.1,0,-.1);siege.node.rotation.y+=.4
 g.render_interpolation.after_step(g.units,g.enemies,[]);frames=g.render_interpolation.frame(.2)
 g.resolve_shell_muzzles(frames)
 muzzle=WeaponMuzzles.world_position(WeaponMuzzles.anchor(siege),frames,Vector3.INF)
 near(shell.node.position,muzzle,"cart spawn uses interpolated GLB transform")
 near(shell.from,simulation_origin,"cart visual correction does not rewrite simulation origin")
 check(is_equal_approx(shell.duration,1.35) and is_equal_approx(shell.damage,96),"cart flight and damage unchanged")
 g.update_shells(.2)
 var saved_position:Vector3=shell.node.position
 var saved_time:float=shell.time
 var saved:Dictionary=g.checkpoint_data()
 near(g.from_data(saved.shells[0].visual_from),muzzle,"checkpoint retains detached visual launch point")
 check(g.valid_checkpoint(saved),"checkpoint accepts finite visual launch point")
 var corrupt:Dictionary=saved.duplicate(true);corrupt.shells[0].visual_from=[0,INF,0]
 check(not g.valid_checkpoint(corrupt),"checkpoint rejects nonfinite visual launch point")
 check(g.save_checkpoint(false)==OK,"midflight save succeeds")
 check(g.load_checkpoint(),"midflight checkpoint reloads")
 if not g.shells.is_empty():
  near(g.shells[0].node.position,saved_position,"resume preserves visible projectile position")
  near(g.shells[0].from,simulation_origin,"resume preserves gameplay launch point")
  check(is_equal_approx(g.shells[0].time,saved_time),"resume preserves impact timing")
 print("MUZZLE_COMBAT_SUMMARY checks=",checks," failures=",failures)
 g.free();await process_frame
 quit(1 if failures else 0)
