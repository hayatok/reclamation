extends SceneTree
func _initialize():call_deferred("run")
func run():
 if FileAccess.file_exists("user://settlement_v2/checkpoint.json"):
  push_error("Use a fresh isolated XDG_DATA_HOME for this trace");quit(2);return
 var raw=FileAccess.get_file_as_string("res://tests/fixtures/earned_m2_prelaunch.json")
 DirAccess.make_dir_recursive_absolute("user://settlement_v2")
 var saved=FileAccess.open("user://settlement_v2/checkpoint.json",FileAccess.WRITE);saved.store_string(raw);saved.close()
 var campaign=root.get_node("Campaign");campaign.current=1;campaign.launch=true;campaign.resume=true;campaign.muted=true
 var game=load("res://main.tscn").instantiate();root.add_child(game);game.set_process(false)
 if game.title_open or game.elapsed<1300:push_error("Earned fixture failed strict load");quit(2);return
 game.paused=false
 var snapshots:Array=[game.checkpoint_data()]
 for step in 400:
  game.simulate(.05)
  if step%5==4:snapshots.append(game.checkpoint_data())
 var output=FileAccess.open("user://death_motion_state_trace.json",FileAccess.WRITE);output.store_string(JSON.stringify(snapshots));output.close()
 print("DEATH_MOTION_STATE_TRACE samples=",snapshots.size()," kills=",game.kills," corpse_count=",game.corpses.size())
 quit()
