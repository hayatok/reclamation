extends SceneTree
func _initialize():call_deferred("run")
func run():
 var output="user://defeat_review"
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--out="):output=arg.trim_prefix("--out=")
 DirAccess.make_dir_recursive_absolute("user://settlement_v2")
 var f=FileAccess.open("user://settlement_v2/checkpoint.json",FileAccess.WRITE)
 f.store_string(FileAccess.get_file_as_string("res://tests/fixtures/earned_critical_factory.json"));f.close()
 var c=root.get_node("Campaign");c.current=1;c.launch=true;c.resume=true;c.muted=true
 var g=load("res://main.tscn").instantiate();root.add_child(g);current_scene=g;g.set_process(false);g.paused=true
 # Explicit UI fixture damage. Use real cleanup and terminal result, not invented text.
 for b in g.buildings:
  if b.kind=="factory":b.hp=0
 g.simulate(.05)
 var workers=g.units.filter(func(u):return u.kind=="worker")
 workers[0].hp=0;workers[1].hp=0;g.simulate(.05)
 g.buildings[0].hp=0;g.simulate(.05)
 assert(g.ended and not g.result_won)
 g.update_ui()
 if is_instance_valid(g.mobile_hud):g.mobile_hud.sync()
 await process_frame;await process_frame
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(output+".png")
 print("DEFEAT_RENDER_FIXTURE ",JSON.stringify(g.defeat_recap.recent_lines(g.elapsed))," mobile=",g.mobile_enabled)
 if "--auto-exit" in OS.get_cmdline_user_args():quit()
