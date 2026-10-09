extends SceneTree
var g:Node
func _initialize():call_deferred("run")
func run():
 var out=OS.get_environment("RUNNER_REVIEW_OUTPUT")
 if out.is_empty():out="user://runner_review"
 DirAccess.make_dir_recursive_absolute(out)
 var fixture=FileAccess.get_file_as_string("res://tests/fixtures/freight_scout_3.json")
 DirAccess.make_dir_recursive_absolute("user://settlement_v2")
 var f=FileAccess.open("user://settlement_v2/checkpoint.json",FileAccess.WRITE);f.store_string(fixture);f.close()
 var c=root.get_node("Campaign");c.current=1;c.launch=true;c.resume=true;c.muted=true
 g=load("res://main.tscn").instantiate();root.add_child(g);g.set_process(false)
 if g.title_open or absf(g.elapsed-862.7)>.001:push_error("Current earned fixture failed to load");quit(1);return
 if OS.get_environment("RUNNER_OLD_FALLBACK")=="1":g.horde_renderer.baked_runner.active=false;g.horde_renderer.baked_runner.visible=false
 g.paused=false;g.camera_focus=Vector3(38,0,22);g.camera.size=50
 g.selected=g.units.filter(func(u):return u.kind=="guard" and u.node.position.distance_to(Vector3(63,0,33))<8)
 if g.selected.size()!=4:push_error("Expected four earned scouts");quit(1);return
 g.update_selection();g.attack_move=true;g.command_at(Vector3(32,0,22))
 var first_visible=-1
 for step in 900:
  if g.active_card:g.postpone_growth_choice()
  g._process(1.0/30)
  if g.visible_horde().any(func(e):return not e.has("life") and e.get("speed",0)>2):first_visible=step;break
 if first_visible<0:push_error("No naturally visible runner encounter within30s");quit(1);return
 for skip_frame in maxi(0, int(OS.get_environment("RUNNER_REVIEW_SKIP_FRAMES"))):
  if g.active_card:g.postpone_growth_choice()
  g._process(1.0/30)
 f=FileAccess.open(out.path_join("clip_start.json"),FileAccess.WRITE);f.store_string(JSON.stringify(g.checkpoint_data()));f.close()
 var rows=[]
 for frame in 180:
  if g.active_card:g.postpone_growth_choice()
  var start=Time.get_ticks_usec();g._process(1.0/30);var cpu_ms=(Time.get_ticks_usec()-start)/1000.0
  await process_frame
  await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png(out.path_join("frame_%04d.png"%frame))
  rows.append({"frame":frame,"elapsed":g.elapsed,"enemies":g.enemies.size(),"visible_runners":g.visible_horde().filter(func(e):return not e.has("life") and e.get("speed",0)>2).size(),"kills":g.kills,"script_cpu_ms":cpu_ms,"draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),"primitives":Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)})
 f=FileAccess.open(out.path_join("clip_end.json"),FileAccess.WRITE);f.store_string(JSON.stringify(g.checkpoint_data()));f.close()
 f=FileAccess.open(out.path_join("frames.json"),FileAccess.WRITE);f.store_string(JSON.stringify(rows));f.close()
 print("RUNNER_EARNED_REVIEW ",JSON.stringify({"first_visible_step":first_visible,"frames":rows.size(),"initial":rows[0],"final":rows.back()}));quit()
