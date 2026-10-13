extends SceneTree
func _initialize():call_deferred("run")
func summarize(values:Array)->Dictionary:
 var ordered=values.duplicate();ordered.sort();var total=0.0
 for value in ordered:total+=value
 return {"total":total,"mean":total/maxi(1,ordered.size()),"p95":ordered[mini(ordered.size()-1,int(ordered.size()*.95))],"max":ordered.back(),"min":ordered.front(),"samples":ordered.size()}
func actors(game)->Dictionary:
 var kinds={};var live=0;var sleeping=0
 for u in game.units:kinds[u.kind]=kinds.get(u.kind,0)+1
 for e in game.enemies:
  if not e.dead:live+=1
  if e.get("sleeping",false):sleeping+=1
 return {"units":game.units.size(),"unit_kinds":kinds,"enemies":game.enemies.size(),"live_enemies":live,"sleeping_field_true":sleeping,"buildings":game.buildings.size()}
func run():
 var arguments=OS.get_cmdline_user_args();var capsule=arguments[0]
 var checkpoint="res://tests/fixtures/earned_frontier_departure.json"
 DirAccess.make_dir_recursive_absolute("user://settlement_v2")
 var file=FileAccess.open("user://settlement_v2/checkpoint.json",FileAccess.WRITE);file.store_string(FileAccess.get_file_as_string(checkpoint));file.close()
 var campaign=root.get_node("Campaign");campaign.current=1;campaign.resume=true;campaign.launch=true;campaign.muted=true
 var game=load("res://tests/combat_candidate_profile/instrumented_main.gd").new();root.add_child(game);game.set_process(false)
 assert(game.elapsed>700 and game.frontier!=null and not game.ended)
 var start=game.elapsed;var initial=actors(game)
 var initial_state=game.checkpoint_data()
 file=FileAccess.open(capsule+"/checkpoint_start.json",FileAccess.WRITE);file.store_string(JSON.stringify(initial_state,"  "));file.close()
 game.measured_target_calls=0;game.measured_target_usec=0;game.measured_enemy_entries=0;game.measured_results=0
 var samples=[];var targets=[];var calls=[];var enemies=[];var units=[]
 for tick in 120:
  if game.ended:break
  var old_usec:int=game.measured_target_usec;var old_calls:int=game.measured_target_calls
  var before=Time.get_ticks_usec();game.simulate(.05);samples.append((Time.get_ticks_usec()-before)/1000.0)
  targets.append((game.measured_target_usec-old_usec)/1000.0);calls.append(game.measured_target_calls-old_calls)
  enemies.append(game.enemies.size());units.append(game.units.size())
 var final_state=game.checkpoint_data()
 file=FileAccess.open(capsule+"/checkpoint_end.json",FileAccess.WRITE);file.store_string(JSON.stringify(final_state,"  "));file.close()
 var simulation=summarize(samples);var targeting=summarize(targets)
 var data={"engine":Engine.get_version_info().string,"fixture":checkpoint,"from":start,"to":game.elapsed,"simulated_seconds":game.elapsed-start,"initial_actors":initial,"final_actors":actors(game),"ended":game.ended,"rng_start":{"rng":initial_state.rng,"card_rng":initial_state.card_rng,"visual_rng":initial_state.visual_rng},"rng_end":{"rng":final_state.rng,"card_rng":final_state.card_rng,"visual_rng":final_state.visual_rng},"simulation_ms":simulation,"combat_targets_ms":targeting,"combat_targets_share_percent":100.0*targeting.total/simulation.total,"combat_targets_calls":summarize(calls),"query_enemy_entries_virtual":game.measured_enemy_entries,"target_results_returned":game.measured_results,"enemies_per_step":summarize(enemies),"units_per_step":summarize(units),"limits":"One bounded earned M2 route, 120 x 50 ms steps. Headless elapsed CPU-work timing includes instrumentation and excludes startup, rendering, browser, and UI processing; not process CPU time or browser FPS. No gameplay state modifications or commands. External subclass calls tested combat_targets on every invocation. query_enemy_entries_virtual sums the enemy array size at each query; it is not a measured scan count, particularly for the cached candidate."}
 file=FileAccess.open(capsule+"/result.json",FileAccess.WRITE);file.store_string(JSON.stringify(data,"  "));file.close();print("TARGET_COST_PROFILE ",JSON.stringify(data))
 game.free();await process_frame;quit()
