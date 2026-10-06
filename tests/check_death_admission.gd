extends SceneTree
func _initialize():call_deferred("run")
func run():
 if FileAccess.file_exists("user://settlement_v2/checkpoint.json"):
  push_error("Use a fresh isolated XDG_DATA_HOME for this replay");quit(2);return
 var raw=FileAccess.get_file_as_string("res://tests/fixtures/earned_m2_prelaunch.json")
 DirAccess.make_dir_recursive_absolute("user://settlement_v2")
 var saved=FileAccess.open("user://settlement_v2/checkpoint.json",FileAccess.WRITE);saved.store_string(raw);saved.close()
 var campaign=root.get_node("Campaign");campaign.current=1;campaign.launch=true;campaign.resume=true;campaign.muted=true
 var game=load("res://tests/record_death_causes_game.gd").new();root.add_child(game);game.set_process(false);game.paused=false
 if game.title_open or game.elapsed<1300:push_error("Strict fixture load failed");quit(2);return
 var peak=0
 for step in 400:
  game.simulate(.05);peak=maxi(peak,game.corpses.size())
 var result={"deaths":game.death_counts,"admitted":game.admitted_counts,"peak_corpses":peak,"kills":game.kills}
 var output=FileAccess.open("user://death_admission.json",FileAccess.WRITE);output.store_string(JSON.stringify(result,"  "));output.close()
 print("DEATH_ADMISSION ",JSON.stringify(result));quit()
