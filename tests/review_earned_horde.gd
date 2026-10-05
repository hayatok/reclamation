extends SceneTree
## Replays an unedited ordinary-play save for an offline movie, not an FPS test.
func _initialize():call_deferred("run")
func run():
 var campaign=root.get_node("Campaign")
 campaign.current=0;campaign.launch=true;campaign.resume=true;campaign.muted=false;campaign.performance_mode=false
 var game=load("res://main.tscn").instantiate();root.add_child(game);current_scene=game
 if game.enemies.size()!=124 or not is_equal_approx(game.elapsed,917.2):
  push_error("Expected the earned pump-defense fixture");quit(2);return
 game.paused=false
 print("EARNED_HORDE_MOVIE_START elapsed=",game.elapsed," enemies=",game.enemies.size()," kills=",game.kills)
 for frame in 240:await process_frame
 print("EARNED_HORDE_MOVIE_END elapsed=",game.elapsed," enemies=",game.enemies.size()," kills=",game.kills)
 quit()
