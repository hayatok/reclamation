extends SceneTree
var g
func _initialize():call_deferred("run")
func run():
 var label="current"
 var out="user://freight_review/"
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--out="):out=arg.trim_prefix("--out=").trim_suffix("/")+"/"
 DirAccess.make_dir_recursive_absolute(out)
 DirAccess.make_dir_recursive_absolute("user://settlement_v2")
 var c=root.get_node("Campaign");c.current=1;c.launch=true;c.resume=true;c.muted=true
 var rows=[]
 for stage in [1,2,3]:
  var f=FileAccess.open("user://settlement_v2/checkpoint.json",FileAccess.WRITE);f.store_string(FileAccess.get_file_as_string("res://tests/fixtures/freight_scout_%d.json"%stage));f.close()
  if is_instance_valid(g):g.free()
  c.current=1;c.launch=true;c.resume=true
  g=load("res://main.tscn").instantiate();root.add_child(g);g.paused=true
  for frame in 8:await process_frame
  await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png(out+label+"_%d.png"%stage)
  var state=g.checkpoint_data()
  f=FileAccess.open(out+label+"_%d_state.json"%stage,FileAccess.WRITE);f.store_string(JSON.stringify(state));f.close()
  rows.append({"stage":stage,"camera_focus":g.vec_data(g.camera_focus),"camera_size":g.camera.size,"draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),"primitives":Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME),"renderer":RenderingServer.get_video_adapter_name()})
 var f=FileAccess.open(out+label+"_metrics.json",FileAccess.WRITE);f.store_string(JSON.stringify(rows,"  "));f.close()
 print("FREIGHT_CAPTURE ",label," ",JSON.stringify(rows))
 quit()
