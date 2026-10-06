extends SceneTree
## Native visual replay of a genuine earned save with ordinary launch/escort.
func _initialize():call_deferred("run")
func run():
 if FileAccess.file_exists("user://settlement_v2/checkpoint.json"):
  push_error("Use a fresh isolated XDG_DATA_HOME");quit(2);return
 DirAccess.make_dir_recursive_absolute("user://settlement_v2")
 var file=FileAccess.open("user://settlement_v2/checkpoint.json",FileAccess.WRITE)
 file.store_string(FileAccess.get_file_as_string("res://tests/fixtures/earned_m2_prelaunch.json"));file.close()
 var campaign=root.get_node("Campaign");campaign.current=1;campaign.launch=true;campaign.resume=true;campaign.muted=true
 var game=load("res://main.tscn").instantiate();root.add_child(game);current_scene=game;game.set_process(false)
 if game.title_open or game.elapsed<1300:push_error("Strict earned save did not load");quit(2);return
 game.paused=false;game.choose_convoy_route(1)
 var convoy=game.convoy_unit()
 if convoy.is_empty():push_error("Ordinary paid convoy launch failed");quit(3);return
 game.select_guards();game.command_at(convoy.node.position,Vector2.INF)
 for step in 2400:
  game.simulate(.05)
  if game.ended:break
 if not game.ended or not game.result_won:push_error("Earned replay did not win");quit(4);return
 game.set_process(true)
 await create_timer(2.0).timeout
 game.mobile_hud.sync()
 var capture="user://mobile_result.png"
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--capture="):capture=arg.trim_prefix("--capture=")
 await RenderingServer.frame_post_draw
 get_root().get_texture().get_image().save_png(capture)
 print("MOBILE_EARNED_RESULT elapsed=",game.elapsed," kills=",game.kills," capture=",capture)
 if "--quit-after-capture" in OS.get_cmdline_user_args():quit()
