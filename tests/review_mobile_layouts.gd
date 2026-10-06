extends SceneTree
## Native presentation-only viewport/safe-area fixtures; not device testing.
var game
func _initialize():call_deferred("run")
func capture(name:String,size:Vector2i,insets:Vector4,workers:bool):
 root.mode=Window.MODE_WINDOWED;root.size=size;root.content_scale_size=size
 game.mobile_hud.set_safe_insets(insets)
 if workers:game.select_workers()
 else:game.select_headquarters()
 game.refresh_context_commands(true);game.update_ui()
 for i in 4:
  root.mode=Window.MODE_WINDOWED;root.size=size
  await process_frame
 game.mobile_hud.sync()
 await RenderingServer.frame_post_draw
 var target="user://"+name+".png"
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--capture-dir="):target=arg.trim_prefix("--capture-dir=").path_join(name+".png")
 var img=root.get_texture().get_image();img.save_png(target)
 print("MOBILE_LAYOUT ",name," pixels=",img.get_size()," logical=",root.content_scale_size," insets=",insets)
func run():
 var campaign=root.get_node("Campaign");campaign.launch=true;campaign.resume=false;campaign.current=0;campaign.muted=true;campaign.run_seed=37
 game=load("res://main.tscn").instantiate();root.add_child(game);current_scene=game;game.set_process(false);game.paused=true
 if not game.mobile_enabled:push_error("Use --touch-ui for native fixture");quit(2);return
 await create_timer(.5).timeout
 await capture("hq_844x390",Vector2i(844,390),Vector4.ZERO,false)
 await capture("workers_844x390",Vector2i(844,390),Vector4.ZERO,true)
 await capture("workers_844x320",Vector2i(844,320),Vector4.ZERO,true)
 await capture("safe_932x430",Vector2i(932,430),Vector4(47,0,47,21),true)
 await capture("portrait_390x844",Vector2i(390,844),Vector4(0,44,0,34),true)
 quit()
