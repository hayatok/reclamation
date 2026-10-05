extends SceneTree
## Native pixel gate only. Never use its frozen scene timings as live-game FPS.
const Mask=preload("res://hud_depth_mask.gd")
var game:Node
var mask:MeshInstance3D
var output_dir:String="res://.experiment/visual"
var results:Array=[]
var requested_case:String="all"
var original_content_size:Vector2i
func _initialize():call_deferred("run")
func freeze_tree(node:Node)->void:
 node.process_mode=Node.PROCESS_MODE_DISABLED
 for child in node.get_children():freeze_tree(child)
func settle()->void:
 for i in 3:
  await process_frame
  await RenderingServer.frame_post_draw
func freeze_everything()->void:
 freeze_tree(game)
 for tween in get_processed_tweens():tween.pause()
func run()->void:
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--mask-output="):output_dir=arg.trim_prefix("--mask-output=")
  if arg.begins_with("--mask-review-case="):requested_case=arg.trim_prefix("--mask-review-case=")
 DirAccess.make_dir_recursive_absolute(output_dir)
 var campaign=root.get_node("Campaign")
 campaign.current=0;campaign.launch=true;campaign.resume=true;campaign.muted=true;campaign.performance_mode=false
 game=load("res://main.tscn").instantiate();root.add_child(game);current_scene=game
 if game.title_open or game.units.size()!=16 or game.enemies.size()!=13 or not is_equal_approx(game.elapsed,677.3):
  push_error("Exact earned fixture was not restored");quit(2);return
 game.paused=true
 await settle()
 freeze_everything()
 mask=game.hud_depth_mask;mask.enabled=false;mask.sync_now()
 original_content_size=root.content_scale_size
 var cases=["earned","zoom26","zoom85","pan_ne","pan_sw","viewport_resize","hud_hidden","hud_translucent","menu","title"]
 if requested_case!="all":cases=[requested_case]
 for case_name in cases:
  await prepare_case(case_name)
  await capture_case(case_name)
 var file=FileAccess.open(output_dir.path_join("pixel_gate.json"),FileAccess.WRITE)
 file.store_string(JSON.stringify({"renderer":RenderingServer.get_video_adapter_name(),"cases":results,"all_exact":results.all(func(row):return row.control_exact and row.mask_exact and row.state_equal)},"  "))
 print("HUD_DEPTH_MASK_PIXEL_GATE ",JSON.stringify(results))
 quit(0 if results.all(func(row):return row.control_exact and row.mask_exact and row.state_equal) else 1)
func prepare_case(case_name:String)->void:
 mask.enabled=false;mask.sync_now()
 root.content_scale_size=original_content_size
 if is_instance_valid(game.options_panel):game.close_options()
 for panel in game.hud_parts:
  panel.show();panel.modulate.a=1.0
 game.camera_focus=Vector3(0,0,8);game.camera.size=42.0
 if case_name=="zoom26":game.camera.size=26.0
 if case_name=="zoom85":game.camera.size=85.0
 if case_name=="pan_ne":game.camera_focus=Vector3(18,0,-18)
 if case_name=="pan_sw":game.camera_focus=Vector3(-18,0,18)
 if case_name=="viewport_resize":root.content_scale_size=Vector2i(1100,800)
 game.camera.position=game.camera_focus+Vector3(37,48,43);game.camera.look_at(game.camera_focus)
 await settle()
 # Refresh only camera-dependent visual submissions; no simulation advances.
 game.render_actors()
 game.battle_visibility.update_visibility(game.camera,game.units,game.enemies,game.shells,1.5)
 game.update_ui()
 if case_name=="hud_hidden":
  for panel in game.hud_parts:panel.hide()
 if case_name=="hud_translucent":
  for panel in game.hud_parts:panel.modulate.a=.5
 if case_name=="menu":game.show_options()
 if case_name=="title":game.show_title()
 freeze_everything()
 await settle()
func capture_case(case_name:String)->void:
 var state_before=game.checkpoint_data()
 mask.enabled=false;mask.sync_now();await settle()
 var baseline=root.get_texture().get_image()
 assert(baseline.save_png(output_dir.path_join(case_name+"_before.png"))==OK)
 await settle()
 var control=root.get_texture().get_image()
 assert(control.save_png(output_dir.path_join(case_name+"_control.png"))==OK)
 mask.enabled=true;mask.sync_now();await settle()
 var candidate=root.get_texture().get_image()
 assert(candidate.save_png(output_dir.path_join(case_name+"_after.png"))==OK)
 var row={"case":case_name,"control_exact":baseline.get_data()==control.get_data(),"mask_exact":baseline.get_data()==candidate.get_data(),"state_equal":state_before==game.checkpoint_data(),"masked_panels":mask.covered_rects.size(),"mask_visible":mask.visible,"image_size":str(baseline.get_size()),"viewport":str(root.get_visible_rect().size),"mask_rebuilds":mask.rebuild_count}
 results.append(row)
 var state_file=FileAccess.open(output_dir.path_join(case_name+"_state.json"),FileAccess.WRITE);state_file.store_string(JSON.stringify(state_before,"  "))
 print("HUD_MASK_CASE ",JSON.stringify(row))
 mask.enabled=false;mask.sync_now()
