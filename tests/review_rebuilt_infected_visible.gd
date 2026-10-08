extends SceneTree
var g:Node
var output:String
func _initialize():call_deferred("run")
func run():
 output="user://infected_review"
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--out="):output=arg.trim_prefix("--out=")
 DirAccess.make_dir_recursive_absolute("user://settlement_v2")
 var f=FileAccess.open("user://settlement_v2/checkpoint.json",FileAccess.WRITE);f.store_string(FileAccess.get_file_as_string("res://tests/fixtures/earned_critical_factory.json"));f.close()
 var c=root.get_node("Campaign");c.current=1;c.launch=true;c.resume=true;c.muted=true
 g=load("res://main.tscn").instantiate();root.add_child(g);current_scene=g;g.set_process(false);g.paused=false
 print("LOADED_FIXTURE elapsed=",g.elapsed," enemies=",g.enemies.size()," title=",g.title_open)
 if g.elapsed<500:quit(2);return
 g.camera_focus=Vector3(16,0,5);g.camera.size=42
 g.camera.position=g.camera_focus+Vector3(37,48,43);g.camera.look_at(g.camera_focus)
 var samples:Array=[]
 for frame in 120:
  var start=Time.get_ticks_usec()
  g.render_interpolation.before_step(g.units,g.enemies,g.corpses)
  g.simulate(.025)
  g.render_interpolation.after_step(g.units,g.enemies,g.corpses)
  var rendered=g.render_interpolation.frame(1)
  g.horde_renderer.update_horde(g.enemies+g.corpses,g.elapsed,rendered)
  g.horde_renderer.update_friends(g.units,rendered)
  g.battle_visibility.update_visibility(g.camera,g.units,g.enemies,g.shells,.025)
  g.update_ui()
  await process_frame
  await RenderingServer.frame_post_draw
  if frame>=20:samples.append((Time.get_ticks_usec()-start)/1000.0)
  if frame%3==0 or frame==119:root.get_texture().get_image().save_png(output+"_%03d.png"%frame)
 assert(g.horde_renderer.baked.active)
 var statefile=FileAccess.open(output+"_state.json",FileAccess.WRITE);statefile.store_string(JSON.stringify(g.checkpoint_data(),"  "));statefile.close()
 var total=0.0
 for value in samples:total+=value
 samples.sort()
 var report={"frame_mean_ms":total/samples.size(),"frame_p95_ms":samples[int(samples.size()*.95)],"elapsed":g.elapsed,"enemies":g.enemies.size(),"kills":g.kills,"near":g.horde_renderer.baked.near_count,"far":g.horde_renderer.baked.far_count,"renderer":RenderingServer.get_video_adapter_name(),"scope":"fixed-step native 69-enemy earned save; frame cost includes simulation and rendering; not target GPU"}
 var report_file=FileAccess.open(output+".json",FileAccess.WRITE);report_file.store_string(JSON.stringify(report,"  "));report_file.close()
 print("INFECTED_NATIVE_REVIEW ",report)
 quit()
