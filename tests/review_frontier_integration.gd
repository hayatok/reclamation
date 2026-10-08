extends SceneTree
var g:Node
var out=""
func _initialize():call_deferred("run")
func capture(name:String):
 for i in 3:await process_frame
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(out+"/"+name+".png")
 print("CAPTURE ",name)
func view(p:Vector3):
 g.camera_focus=p;g.camera.position=p+Vector3(37,48,43);g.camera.look_at(p)
 g.render_actors();g.update_ui();g.drag_overlay.queue_redraw()
func run():
 for a in OS.get_cmdline_user_args():
  if a.begins_with("--out="):out=a.trim_prefix("--out=")
 var c=root.get_node("Campaign");c.current=1;c.launch=true;c.resume=false;c.muted=true;c.choose_run_seed(4451)
 g=load("res://main.tscn").instantiate();root.add_child(g);g.set_process(false);g.paused=true
 view(g.map_config.home)
 await capture("frontier_home")
 view(Vector3(62,0,-48))
 await capture("frontier_unknown_nest")
 # Controlled sight fixture only. This is not evidence of earned scouting.
 var scout=g.units[0]
 scout.node.position=Vector3(46,0,-48);scout.goal=scout.node.position
 g.refresh_frontier_visibility(0,true);g.render_interpolation.reset(g.units,g.enemies,g.corpses)
 view(Vector3(50,0,-46))
 await capture("frontier_discovered_nest")
 scout.node.position=Vector3(-64,0,44);scout.goal=scout.node.position
 g.refresh_frontier_visibility(0,true);g.render_interpolation.reset(g.units,g.enemies,g.corpses)
 view(Vector3(50,0,-46))
 await capture("frontier_remembered_nest")
 g.free();await process_frame;quit()
