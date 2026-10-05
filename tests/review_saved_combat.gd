extends SceneTree
## Unedited ordinary-play checkpoint replay. MovieWriter output is not runtime FPS evidence.
func _initialize():call_deferred("run")
func run():
 var campaign=root.get_node("Campaign")
 campaign.current=2;campaign.launch=true;campaign.resume=true;campaign.muted=false;campaign.performance_mode=false
 var game=load("res://main.tscn").instantiate();root.add_child(game);current_scene=game
 if game.title_open or game.elapsed<=0:
  push_error("Expected an existing playable checkpoint");quit(2);return
 game.paused=false
 print("SAVED_COMBAT_START elapsed=",game.elapsed," enemies=",game.enemies.size()," kills=",game.kills)
 for frame in 240:await process_frame
 print("SAVED_COMBAT_END elapsed=",game.elapsed," enemies=",game.enemies.size()," kills=",game.kills)
 quit()
