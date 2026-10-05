extends SceneTree
const Clock=preload("res://simulation_clock.gd")
const Interpolation=preload("res://render_interpolation.gd")
const Visuals=preload("res://actor_visuals.gd")

class Probe:
 extends "res://main.gd"
 var ticks:int=0
 var stop_after:int=-1
 var stop_mode:String="paused"
 func simulate(dt:float):
  elapsed+=dt
  ticks+=1
  if not units.is_empty():units[0].node.position.x+=4.0*dt
  if ticks==stop_after:set(stop_mode,true)
 func save_checkpoint(_announce:bool=true):pass

func _initialize():call_deferred("run")

func run():
 check_rates_and_stops()
 check_interpolation_lifecycle()
 await check_game_renderers()
 print("RECOVERY_FIXED_CLOCK_INTERPOLATION_PASS")
 quit()

func check_rates_and_stops():
 for fps:int in [10,20,30,60]:
  var g=Probe.new()
  var actor=Node3D.new();root.add_child(actor)
  g.units.append({"node":actor,"hp":1})
  for frame:int in fps*3:g.advance_simulation_time(1.0/fps)
  assert(g.ticks==60 and is_equal_approx(g.elapsed,3.0),"Every render rate must advance the same logical time")
  assert(is_equal_approx(actor.position.x,12.0),"Logical movement must match at every render rate")
  g.free();actor.free()
 var clock=Clock.new()
 assert(clock.take_steps(.025)==0)
 assert(clock.take_steps(5.0)==8 and is_zero_approx(clock.remainder),"Stall catch-up is capped at 0.4 s, with no debt")
 assert(clock.take_steps(.025)==0)
 assert(clock.take_steps(10.0,false)==0 and is_zero_approx(clock.remainder))
 assert(clock.take_steps(.025)==0 and clock.take_steps(.025)==1)
 assert(clock.take_steps(NAN)==0 and clock.take_steps(-1)==0)
 for mode:String in ["paused","ended","active_card","title_open"]:
  var g=Probe.new();g.stop_after=1;g.stop_mode=mode
  assert(g.advance_simulation_time(.37)==1 and g.ticks==1,"Stop must abort all remaining catch-up ticks")
  assert(is_zero_approx(g.simulation_clock.remainder))
  assert(g.advance_simulation_time(10.0)==0)
  g.set(mode,false);g.stop_after=-1
  assert(g.advance_simulation_time(.025)==0 and g.advance_simulation_time(.025)==1,"Paused/menu time must never become resumed backlog")
  g.free()
 print("TIMING_EQUAL_10_20_30_60FPS_CATCHUP_PAUSE_END_PASS")

func check_interpolation_lifecycle():
 var interp=Interpolation.new()
 var actor=Node3D.new();root.add_child(actor)
 Visuals.add_human(actor,"guard")
 var marker=Node3D.new();interp.visual_root(actor).add_child(marker)
 var units:Array=[{"node":actor,"hp":10}]
 var enemies:Array=[];var corpses:Array=[]
 interp.reset(units,enemies,corpses)
 interp.before_step(units,enemies,corpses)
 actor.position.x=.4
 Visuals.pose(actor,1.5,true)
 interp.after_step(units,enemies,corpses)
 var authoritative=actor.global_transform
 var id=actor.get_instance_id()
 var middle=interp.frame(.5)
 assert(is_equal_approx(middle[id].world.origin.x,.2))
 assert(is_equal_approx(marker.global_position.x,.2),"Only the visual child is offset")
 assert(actor.global_transform==authoritative,"Rendering must not move the authoritative root")
 assert(middle[id].parts.size()==6)
 assert(interp.frame(2.0)[id].world==authoritative,"Render alpha cannot extrapolate")
 var spawned=Node3D.new();root.add_child(spawned);spawned.position.x=7
 units.append({"node":spawned,"hp":5})
 assert(interp.frame(.1)[spawned.get_instance_id()].world.origin.x==7,"Spawn must snap on its first render")
 units[1].hp=0
 assert(not interp.frame(.5).has(spawned.get_instance_id()),"Dead actors must not leave snapshot ghosts")
 units.pop_back();spawned.free()
 actor.position.x=8
 assert(interp.frame(.1)[id].world.origin.x==8,"Out-of-step teleports must snap immediately")
 interp.before_step(units,enemies,corpses);actor.position.x=18;interp.after_step(units,enemies,corpses)
 assert(interp.frame(.1)[id].world.origin.x==18,"Long relocations inside a step must snap")
 units.clear();enemies.append({"node":actor,"hp":10,"dead":false})
 interp.reset(units,enemies,corpses);interp.before_step(units,enemies,corpses)
 enemies.clear();corpses.append({"node":actor,"life":3.5,"start":actor.transform})
 interp.after_step(units,enemies,corpses)
 assert(interp.frame(.2)[id].life==3.5,"Live-to-corpse transition must use the new lifecycle")
 interp.before_step(units,enemies,corpses);corpses[0].life=3.45;actor.rotation.z=.2;interp.after_step(units,enemies,corpses)
 assert(is_equal_approx(interp.frame(.5)[id].life,3.475))
 corpses.clear()
 assert(interp.frame(.5).is_empty(),"Expired corpse must disappear from rendered data immediately")
 actor.free()
 print("TIMING_MIDFRAME_SPAWN_DEATH_CORPSE_TELEPORT_PASS")

func check_game_renderers():
 var campaign=root.get_node("Campaign");campaign.current=0;campaign.launch=true;campaign.resume=false
 var g=load("res://main.tscn").instantiate();root.add_child(g);g.set_process(false)
 var truck=g.make_unit("truck",Vector3(20,0,20))
 var vehicle_visual:Node3D=g.render_interpolation.visual_root(truck.node)
 g.spawn_enemy(Vector3(20,0,-20))
 g.render_interpolation.reset(g.units,g.enemies,g.corpses)
 g.advance_simulation_time(.075)
 g.render_actors()
 var transforms=g.units.map(func(u):return u.node.global_transform)
 g.render_actors()
 for i:int in g.units.size():assert(g.units[i].node.global_transform==transforms[i])
 assert(vehicle_visual.get_child_count()>1,"Vehicle art and ring must live under the render-only child")
 assert(g.horde_renderer.visible_enemies==1)
 assert(g.horde_renderer._friendly_batches.guard[0].visible_instance_count==2)
 assert(g.horde_renderer._friendly_batches.worker[0].visible_instance_count==6)
 g.paused=true;g.advance_simulation_time(5.0);g.render_actors()
 assert(vehicle_visual.transform.is_equal_approx(Transform3D.IDENTITY))
 g.queue_free();await process_frame
 print("TIMING_GAME_RENDERER_INTEGRATION_PASS")
