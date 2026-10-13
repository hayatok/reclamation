extends SceneTree
func _initialize():call_deferred("run")
func run():
 for mission_index in [0,1,2]:
  var campaign=root.get_node("Campaign")
  campaign.current=mission_index;campaign.launch=true;campaign.resume=false;campaign.muted=true
  var game=load("res://main.tscn").instantiate();root.add_child(game);current_scene=game
  await process_frame;game.set_process(false);game.paused=true
  assert(game.units.size()>0 and game.buildings.size()>0)
  game.select_headquarters();game._process(0)
  assert(game.command_grid.get_child_count()>0)
  assert(game.save_checkpoint(false)==OK)
  assert(game.load_checkpoint());game.set_process(false);game.paused=true
  print("BASELINE_MISSION_PASS ",mission_index," units=",game.units.size()," mode=",game.mission.mode)
  game.free();current_scene=null;await process_frame
 print("RECOVERED_BASELINE_BOOT_SAVE_PASS");quit()
