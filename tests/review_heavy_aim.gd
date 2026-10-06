extends SceneTree
## Actual ordinary-save replay; --legacy-aim compares the previous nearest policy.
## --movie uses real rendered frames. Offline output is never an FPS benchmark.
const RECORD=preload("res://tests/record_heavy_aim_game.gd")
const DEFAULT_FIXTURE="res://tests/fixtures/earned_m2_prelaunch.json"
func _initialize():call_deferred("run")
func run():
 var fixture=DEFAULT_FIXTURE
 for argument in OS.get_cmdline_user_args():
  if argument.begins_with("--fixture="):fixture=argument.trim_prefix("--fixture=")
 var raw=FileAccess.get_file_as_string(fixture)
 var data=JSON.parse_string(raw)
 if not load("res://checkpoint_validation.gd").validate(data):
  push_error("Earned fixture rejected; no migration or mutation applied");quit(2);return
 DirAccess.make_dir_recursive_absolute("user://settlement_v2")
 var saved=FileAccess.open("user://settlement_v2/checkpoint.json",FileAccess.WRITE);saved.store_string(raw);saved.close()
 var campaign=root.get_node("Campaign")
 campaign.current=1;campaign.launch=true;campaign.resume=true;campaign.muted=false;campaign.performance_mode=false
 var game=RECORD.new();game.legacy_aim="--legacy-aim" in OS.get_cmdline_user_args()
 root.add_child(game);current_scene=game
 if game.title_open or not is_equal_approx(game.elapsed,float(data.elapsed)):
  push_error("Earned fixture did not load");quit(3);return
 game.paused=false
 game.camera_focus=Vector3(-18,0,12);game.camera.size=48
 var start_kills=game.kills
 var start_ammo=game.ammo
 var timeline:Array=[]
 if "--movie" in OS.get_cmdline_user_args():
  game.set_process(false)
  for step in 150:game.simulate(.05)
  game.set_process(true)
  for frame in 360:await process_frame
 else:
  game.set_process(false)
  for step in 600:
   if game.ended:break
   game.simulate(.05)
   if step%5==0:timeline.append({"time":game.elapsed,"enemies":game.enemies.size(),"kills":game.kills})
   if step%100==0:await process_frame
 var result={"legacy":game.legacy_aim,"fixture":fixture,"start_elapsed":data.elapsed,"end_elapsed":game.elapsed,"start_kills":start_kills,"end_kills":game.kills,"start_ammo":start_ammo,"end_ammo":game.ammo,"enemies_remaining":game.enemies.size(),"aims":game.aim_samples,"impacts":game.impact_samples,"aim_costs":game.aim_costs,"heavy_ammo_spent":game.heavy_ammo_spent,"timeline":timeline}
 var f=FileAccess.open("user://heavy_aim_review.json",FileAccess.WRITE);f.store_string(JSON.stringify(result,"  "));f.close()
 print("HEAVY_AIM_REVIEW legacy=",game.legacy_aim," shots=",game.aim_samples.size()," impacts=",game.impact_samples.size()," kills=",game.kills-start_kills)
 quit()
