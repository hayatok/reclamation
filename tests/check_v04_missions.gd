extends SceneTree
# Isolated mechanics fixtures; run with --headless --path . --script res://tests/check_v04_missions.gd.
const BOSS_HP=3600.0
const BOSS_SPEED=1.45
const BOSS_WINDUP=1.4
var game
var results:Array=[]
var failures:int=0
var campaign
func _initialize():call_deferred("run")
func check(name:String, ok:bool, details:Dictionary={}):
 results.append({"test":name,"pass":ok,"details":details})
 print(("PASS " if ok else "FAIL ")+name+" "+JSON.stringify(details))
 if not ok:failures+=1
func reset(index:int):
 if is_instance_valid(game):
  root.remove_child(game)
  game.free()
 campaign.current=index;campaign.launch=true;campaign.best={};campaign.unlocked=1;campaign.muted=true;campaign.low_fx=true
 game=load("res://main.tscn").instantiate()
 root.add_child(game)
 game.set_process(false);game.set_process_unhandled_input(false)
 game.wave_clock=100000;game.threat_voice_clock=100000
 game.low_fx=true;game.muted=true;game.title_open=false
func restore_all():
 for s in game.sites:
  if s.kind!="scrap":s.reclaimed=true;s.paid=true;s.progress=1
 game.generator_on=true
func quiet_army():
 for u in game.units.duplicate():
  if u.kind!="convoy":game.units.erase(u);u.node.free()
 for b in game.buildings.duplicate():
  if b.kind!="hq":game.buildings.erase(b);b.node.free()
 game.rebuild_navigation()
func prepare_convoy():
 reset(1);restore_all();game.resources=180;game.launch_convoy();game.convoy_encounter_stage=3;game.wave_clock=100000;quiet_army()
func won()->bool:return campaign.best.has(str(campaign.current))
func boss_count()->int:return game.enemies.filter(func(e):return e.get("boss",false)).size()
func tick(dt:float):
 game.simulate(dt)
 game.update_effects(dt)
func run():
 campaign=root.get_node("Campaign")
 reset(1)
 game.resources=180
 game.launch_convoy()
 check("convoy_blocks_unrestored",not game.convoy_started and game.resources==180)
 game.get_site("pump").reclaimed=true
 game.launch_convoy()
 check("convoy_blocks_power_off",not game.convoy_started and game.resources==180)
 game.get_site("generator").reclaimed=true;game.generator_on=true;game.get_site("pump").reclaimed=false
 game.launch_convoy()
 check("convoy_blocks_depot_unrestored",not game.convoy_started and game.resources==180)
 game.get_site("pump").reclaimed=true;game.resources=79
 game.launch_convoy()
 check("convoy_blocks_insufficient_funds",not game.convoy_started and game.resources==79)
 game.resources=80;game.active_card=true;game.launch_convoy()
 check("convoy_blocks_during_upgrade",not game.convoy_started and game.resources==80)
 game.active_card=false;game.launch_convoy();game.launch_convoy()
 check("convoy_charges_80_once",game.resources==0 and game.units.filter(func(u):return u.kind=="convoy").size()==1 and game.convoy_index==1)
 # Actual movement and navigation, no teleportation, with combat/waves suppressed.
 prepare_convoy()
 var steps=0
 while not game.ended and steps<2400:
  tick(.05);steps+=1
 var convoy=game.convoy_unit()
 check("convoy_full_route_actual_movement",game.ended and won(),{"simulation_seconds":steps*.05,"position":str(convoy.node.position),"index":game.convoy_index,"hp":convoy.hp})
 var victory_children=game.root_ui.get_child_count();game.update_mission(.05);game.finish(true)
 check("convoy_terminal_victory_idempotent",won() and game.root_ui.get_child_count()==victory_children)
 prepare_convoy();game.convoy_unit().hp=0;tick(.05)
 check("convoy_existing_death_fails",game.ended and not won(),{"reason":game.failure_reason})
 var loss_children=game.root_ui.get_child_count();game.update_mission(.05);game.finish(true)
 check("convoy_terminal_loss_cannot_be_overwritten",not won() and game.root_ui.get_child_count()==loss_children)
 prepare_convoy();var gone=game.convoy_unit();game.units.erase(gone);gone.node.free();game.update_mission(.05)
 check("convoy_missing_fails",game.ended and not won())
 # Arrival and enemy strike happen in the same simulate call.
 prepare_convoy();convoy=game.convoy_unit();game.convoy_index=5;convoy.node.position=game.CONVOY_ROUTE[5];convoy.goal=convoy.node.position;convoy.hp=1
 game.spawn_enemy(convoy.node.position);game.enemies.back().cd=0
 tick(.05)
 check("convoy_fatal_arrival_must_fail",game.ended and not won(),{"won":won(),"convoy_hp":convoy.hp,"index":game.convoy_index})
 # HQ must survive the arrival frame too.
 prepare_convoy();convoy=game.convoy_unit();game.convoy_index=5;convoy.node.position=game.CONVOY_ROUTE[5];convoy.goal=convoy.node.position
 game.buildings[0].hp=1;game.spawn_enemy(game.buildings[0].node.position);game.enemies.back().cd=0;tick(.05)
 check("convoy_fatal_hq_arrival_must_fail",game.ended and not won(),{"won":won(),"hq_hp":game.buildings[0].hp})
 reset(2)
 check("finale_contains_three_facilities",not game.get_site("generator").is_empty() and not game.get_site("pump").is_empty() and not game.get_site("substation").is_empty())
 game.update_mission(1);check("finale_no_hold_unrestored",game.hold_time==0)
 game.get_site("generator").reclaimed=true;game.generator_on=true;game.get_site("pump").reclaimed=true
 game.update_mission(1);check("finale_requires_substation",game.hold_time==0)
 game.get_site("substation").reclaimed=true;game.get_site("pump").reclaimed=false
 game.update_mission(1);check("finale_requires_pump",game.hold_time==0)
 game.get_site("pump").reclaimed=true;game.generator_on=false
 game.update_mission(1);check("finale_requires_live_generator",game.hold_time==0)
 game.generator_on=true;game.update_mission(1);check("finale_hold_after_three_restored",game.hold_time==1)
 game.hold_time=54.9;game.update_mission(.05);check("boss_not_before_55_seconds",boss_count()==0 and not game.boss_spawned)
 game.update_mission(.051);check("boss_spawns_at_55_seconds",boss_count()==1 and game.boss_spawned,{"hold":game.hold_time})
 for i in 20:game.update_mission(.05)
 check("boss_spawns_only_once",boss_count()==1 and is_equal_approx(game.enemies[0].hp,BOSS_HP) and is_equal_approx(game.enemies[0].speed,BOSS_SPEED))
 game.hold_time=180;game.update_mission(.05)
 check("finale_hold_alone_not_victory",not game.ended and not won())
 var boss=game.enemies.filter(func(e):return e.boss)[0]
 var previous_kills=game.kills;var previous_xp=game.xp
 game.hit(boss,10000,true);game.hit(boss,10000,true)
 check("boss_death_reward_once",game.boss_defeated and game.kills==previous_kills+1 and game.xp==previous_xp+90 and boss_count()==0,{"xp_delta":game.xp-previous_xp,"kills_delta":game.kills-previous_kills})
 game.update_mission(.05);check("finale_kill_and_hold_victory",game.ended and won())
 reset(2);restore_all();game.hold_time=55;game.update_mission(.01);boss=game.enemies[0];game.hit(boss,10000,true);game.update_mission(.05)
 check("finale_early_kill_still_needs_hold",not game.ended and not won())
 game.hold_time=179.99;game.update_mission(.02);check("finale_hold_after_early_kill_victory",game.ended and won())
 # Actual simulate-loop boss windup; no direct call to boss_impact.
 reset(2);quiet_army();game.spawn_enemy(game.buildings[0].node.position,false,true,true);boss=game.enemies[0];boss.cd=0
 var hp_before=game.buildings[0].hp
 tick(.05)
 var targeted_position:Vector3=boss.attack_pos
 check("boss_telegraph_no_instant_damage",is_equal_approx(boss.windup,BOSS_WINDUP) and game.buildings[0].hp==hp_before and game.effects.size()>0,{"windup":boss.windup,"effects":game.effects.size()})
 for i in 27:tick(.05)
 check("boss_no_damage_before_1400ms",game.buildings[0].hp==hp_before,{"windup_remaining":boss.windup})
 tick(.051)
 check("boss_impact_after_1400ms",game.buildings[0].hp==hp_before-120 and is_equal_approx(boss.cd,3.2),{"damage":hp_before-game.buildings[0].hp,"cooldown":boss.cd})
 for i in 20:tick(.05)
 check("boss_single_impact_per_windup",game.buildings[0].hp==hp_before-120)
 # Windup snapshots the attacked position; dodge away before impact.
 reset(2);quiet_army();var hq=game.buildings[0];hq.node.position=Vector3(20,0,20)
 var worker=game.make_unit("worker",Vector3.ZERO);game.spawn_enemy(Vector3.ZERO,false,true,true);boss=game.enemies[0];boss.cd=0
 tick(.05);var original_attack:Vector3=boss.attack_pos;worker.node.position=Vector3(10,0,0);worker.goal=worker.node.position
 for i in 29:tick(.05)
 check("boss_impact_point_fixed_when_target_repositioned",worker.hp==worker.maxhp and boss.attack_pos==original_attack,{"hp":worker.hp,"attack_pos":str(boss.attack_pos)})
 # Actual baseline guard movement from blast center; this documents escape feasibility, not a human reaction test.
 reset(2);quiet_army();game.buildings[0].node.position=Vector3(20,0,20)
 var guard=game.make_unit("guard",Vector3.ZERO);guard.cd=1000;game.spawn_enemy(Vector3.ZERO,false,true,true);boss=game.enemies[0];boss.cd=0
 tick(.05);guard.goal=Vector3(10,0,0);guard.task="move"
 var travel_steps=0
 while boss.windup>0 and travel_steps<35:
  tick(.05);travel_steps+=1
 check("boss_baseline_guard_center_escape_observation",guard.hp==100 and guard.node.position.length()>4.5,{"guard_hp":guard.hp,"distance_moved":guard.node.position.length(),"elapsed_movement_seconds":travel_steps*.05,"blast_radius":4.5,"conclusion":"Baseline guard exits the blast radius with an immediate move command; this fixture does not model human reaction delay."})
 # Area damage uses the same snapshotted position and covers units and walls.
 reset(2);quiet_army();game.buildings[0].node.position=Vector3(20,0,20)
 var close_worker=game.make_unit("worker",Vector3(1,0,0));var far_worker=game.make_unit("worker",Vector3(6,0,0))
 var wall=game.make_building("wall",Vector3(-2,0,0),true)
 game.spawn_enemy(Vector3.ZERO,false,true,true);boss=game.enemies[0];boss.cd=0
 tick(.05)
 for i in 29:tick(.05)
 check("boss_aoe_hits_units_walls_once",close_worker.hp==55 and far_worker.hp==100 and wall.hp==145,{"near_unit_hp":close_worker.hp,"far_unit_hp":far_worker.hp,"wall_hp":wall.hp})
 # Killing the boss during telegraph cancels its queued impact and prevents respawn.
 reset(2);restore_all();quiet_army();game.hold_time=55;game.update_mission(.01);boss=game.enemies[0];boss.node.position=game.buildings[0].node.position;boss.cd=0;game.wave_clock=100000
 tick(.05);var safe_hp=game.buildings[0].hp;game.hit(boss,10000,true)
 for i in 31:tick(.05)
 check("dead_boss_cancels_impact_never_respawns",game.buildings[0].hp==safe_hp and boss_count()==0 and game.boss_defeated and game.boss_spawned)
 # Terminal ordering on the final hold frame.
 reset(2);restore_all();quiet_army();game.hold_time=179.99;game.boss_spawned=true;game.boss_defeated=true;game.buildings[0].hp=1
 game.spawn_enemy(game.buildings[0].node.position);game.enemies.back().cd=0;tick(.05)
 check("finale_fatal_hq_finish_must_fail",game.ended and not won(),{"won":won(),"hq_hp":game.buildings[0].hp})
 var file=FileAccess.open("user://v04_missions_results.json",FileAccess.WRITE);file.store_string(JSON.stringify({"fixture_only":true,"failures":failures,"results":results},"  "))
 print("SUMMARY tests=%d failures=%d isolated_fixture_only=true"%[results.size(),failures])
 game.free()
 await process_frame
 quit(1 if failures>0 else 0)
