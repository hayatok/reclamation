extends SceneTree
## Native art A/B from an earned campaign save. Never advances simulation.
const Structures=preload("res://structure_visuals.gd")
var game:Node
var output:String="user://power_district_review"
var variants:Array=[]
func _initialize():call_deferred("run")
func freeze(node:Node)->void:
 node.process_mode=Node.PROCESS_MODE_DISABLED
 for child in node.get_children():freeze(child)
func settle()->void:
 for i in 3:
  await process_frame
  await RenderingServer.frame_post_draw
func run()->void:
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--power-output="):output=arg.trim_prefix("--power-output=")
 DirAccess.make_dir_recursive_absolute(output)
 var campaign=root.get_node("Campaign")
 campaign.current=2;campaign.launch=true;campaign.resume=true;campaign.muted=true;campaign.performance_mode=false
 game=load("res://main.tscn").instantiate();root.add_child(game);current_scene=game
 if game.mission.mode!="finale" or not is_equal_approx(game.elapsed,286.95):
  push_error("Expected earned final-operation economy checkpoint");quit(2);return
 game.paused=true
 await settle()
 freeze(game)
 for tween in get_processed_tweens():tween.pause()
 var saved_focus:Vector3=game.camera_focus
 for site in game.sites:
  if site.kind not in ["pump","substation"]:continue
  var visual=site.node.get_node("CentralStationVisual" if site.kind=="pump" else "RefugeSubstationVisual")
  Structures._add(site.node,"site_substation")
  var legacy=site.node.get_node("RailYard_site_substation")
  legacy.hide()
  variants.append({"site":site,"visual":visual,"legacy":legacy})
 var results=[]
 for view in ["overview","central","refuge"]:
  if view=="overview":game.camera_focus=saved_focus
  else:game.assign_site("pump" if view=="central" else "substation")
  game.camera.position=game.camera_focus+Vector3(37,48,43);game.camera.look_at(game.camera_focus)
  game.render_actors()
  game.battle_visibility.update_visibility(game.camera,game.units,game.enemies,game.shells,1.5)
  game.update_ui();game.hud_depth_mask.sync_now()
  var before=game.checkpoint_data()
  var row={"view":view,"camera_size":game.camera.size,"focus":str(game.camera_focus),"state_equal":true,"variants":[]}
  for enabled in [false,true]:
   for pair in variants:
    pair.visual.visible=enabled;pair.legacy.visible=not enabled
   if view!="overview":
    game.selection_portrait.texture=game.portrait_for(("central_station" if view=="central" else "substation") if enabled else "electric")
   await settle()
   var label="after" if enabled else "before"
   var filename=view+"_"+label+".png"
   assert(root.get_texture().get_image().save_png(output.path_join(filename))==OK)
   row.state_equal=row.state_equal and before==game.checkpoint_data()
   row.variants.append({"variant":label,"image":filename,"draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),"primitives":Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME),"texture_bytes":Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED)})
  results.append(row)
 var report={"scope":"native art comparison, unadvanced earned checkpoint, not FPS test","elapsed":game.elapsed,"renderer":RenderingServer.get_video_adapter_name(),"views":results,"all_state_equal":results.all(func(row):return row.state_equal)}
 var file=FileAccess.open(output.path_join("comparison.json"),FileAccess.WRITE);file.store_string(JSON.stringify(report,"  "))
 print("POWER_DISTRICT_REVIEW ",JSON.stringify(report))
 quit(0 if report.all_state_equal else 1)
