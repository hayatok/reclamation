extends SceneTree
## Same earned save/camera. Toggle only the final fog draw to isolate its cost.
var game:Node
var output=""
func _initialize():call_deferred("run")
func stats(values:Array)->Dictionary:
 var ordered=values.duplicate();ordered.sort();var sum=0.0
 for value in ordered:sum+=value
 return {"mean":sum/maxi(1,ordered.size()),"p95":ordered[mini(ordered.size()-1,int(ordered.size()*.95))],"samples":ordered.size()}
func sample(enabled:bool)->Dictionary:
 game.frontier_fog.visible=enabled
 for i in 25:await process_frame
 var walls=[];var processes=[];var draws=[];var primitives=[]
 var last=Time.get_ticks_usec()
 for i in 150:
  await process_frame
  var now=Time.get_ticks_usec();walls.append((now-last)/1000.0);last=now
  processes.append(Performance.get_monitor(Performance.TIME_PROCESS)*1000)
  draws.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
  primitives.append(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
 return {"fog_draw":enabled,"wall_ms":stats(walls),"process_ms":stats(processes),"draw_calls":stats(draws),"primitives":stats(primitives)}
func run():
 var checkpoint=""
 for a in OS.get_cmdline_user_args():
  if a.begins_with("--checkpoint="):checkpoint=a.trim_prefix("--checkpoint=")
  if a.begins_with("--out="):output=a.trim_prefix("--out=")
 DirAccess.make_dir_recursive_absolute("user://settlement_v2")
 var text=FileAccess.get_file_as_string(checkpoint)
 var f=FileAccess.open("user://settlement_v2/checkpoint.json",FileAccess.WRITE);f.store_string(text);f.close()
 var c=root.get_node("Campaign");c.current=1;c.resume=true;c.launch=true;c.muted=true
 game=load("res://main.tscn").instantiate();root.add_child(game);current_scene=game
 assert(game.elapsed>780 and game.frontier.nest.known)
 game.paused=true;game.camera_focus=Vector3(55,0,-42);game.camera.size=50
 var results=[]
 results.append(await sample(true));results.append(await sample(false))
 game.frontier_fog.visible=true
 f=FileAccess.open(output+"/render_profile.json",FileAccess.WRITE)
 f.store_string(JSON.stringify({"scene":"Unedited earned M2 780.40-second checkpoint, paused, same camera/units/world","renderer":RenderingServer.get_video_adapter_name(),"screen":root.size,"blocks":results,"limits":"One ordered pair on cloud llvmpipe software rendering; not target GPU/Web FPS or gameplay simulation performance"},"  "));f.close()
 print("FRONTIER_RENDER_PROFILE ",JSON.stringify(results))
 await process_frame;await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(output+"/earned_nest_final_materials.png")
 game.paused=false
 while not game.ended:await process_frame
 await create_timer(2).timeout
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(output+"/earned_corrected_result.png")
 print("FRONTIER_RESULT_VIEW ",game.result_won," ",game.camera_focus)
 game.free();await process_frame;quit()
