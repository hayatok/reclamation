extends "res://tests/review_hud_depth_mask.gd"
## Frozen-scene renderer control, not a live-game or browser FPS benchmark.
func summarize(samples:Dictionary)->Dictionary:
 var report={}
 for key in samples:
  var values:Array=samples[key].duplicate();values.sort()
  var total:float=0.0
  for value in values:total+=float(value)
  report[key]={"mean":total/values.size(),"median":values[values.size()/2],"p95":values[mini(values.size()-1,int(values.size()*.95))],"n":values.size()}
 return report
func run()->void:
 var destination="res://.experiment/static_abba.json"
 var order="ABBA"
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--mask-bench-output="):destination=arg.trim_prefix("--mask-bench-output=")
  if arg.begins_with("--mask-bench-order="):order=arg.trim_prefix("--mask-bench-order=")
 if order not in ["ABBA","BAAB"]:push_error("Expected ABBA or BAAB");quit(2);return
 var campaign=root.get_node("Campaign")
 campaign.current=0;campaign.launch=true;campaign.resume=true;campaign.muted=true;campaign.performance_mode=false
 game=load("res://main.tscn").instantiate();root.add_child(game);current_scene=game
 if game.title_open or game.units.size()!=16 or game.enemies.size()!=13 or not is_equal_approx(game.elapsed,677.3):
  push_error("Exact earned fixture was not restored");quit(2);return
 game.paused=true
 await settle();freeze_everything()
 mask=game.hud_depth_mask;mask.enabled=false;mask.sync_now()
 var before=game.checkpoint_data()
 var viewport=root.get_viewport_rid()
 RenderingServer.viewport_set_measure_render_time(viewport,true)
 var pooled={"baseline":{},"mask":{}}
 var blocks=[]
 # Four blocks, 10 transition frames discarded + 50 measured in each block.
 for block in 4:
  var on=(block in [1,2]) if order=="ABBA" else (block in [0,3])
  var label="mask" if on else "baseline"
  mask.enabled=on;mask.sync_now()
  var samples={}
  var last=Time.get_ticks_usec()
  for frame in 60:
   await process_frame
   await RenderingServer.frame_post_draw
   var now=Time.get_ticks_usec()
   var wall=float(now-last)/1000.0;last=now
   if frame<10:continue
   var row={"frame_ms":wall,"render_cpu_ms":RenderingServer.viewport_get_measured_render_time_cpu(viewport),"render_gpu_timer_ms":RenderingServer.viewport_get_measured_render_time_gpu(viewport),"setup_cpu_ms":RenderingServer.get_frame_setup_time_cpu(),"draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),"primitives":Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME),"shadow_draws":RenderingServer.viewport_get_render_info(viewport,RenderingServer.VIEWPORT_RENDER_INFO_TYPE_SHADOW,RenderingServer.VIEWPORT_RENDER_INFO_DRAW_CALLS_IN_FRAME),"shadow_primitives":RenderingServer.viewport_get_render_info(viewport,RenderingServer.VIEWPORT_RENDER_INFO_TYPE_SHADOW,RenderingServer.VIEWPORT_RENDER_INFO_PRIMITIVES_IN_FRAME),"canvas_draws":RenderingServer.viewport_get_render_info(viewport,RenderingServer.VIEWPORT_RENDER_INFO_TYPE_CANVAS,RenderingServer.VIEWPORT_RENDER_INFO_DRAW_CALLS_IN_FRAME),"texture_bytes":Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED)}
   for key in row:
    if not samples.has(key):samples[key]=[]
    if not pooled[label].has(key):pooled[label][key]=[]
    samples[key].append(row[key]);pooled[label][key].append(row[key])
  blocks.append({"block":block,"variant":label,"summary":summarize(samples),"raw":samples,"masked_panels":mask.covered_rects.size(),"rebuild_count":mask.rebuild_count})
  print("MASK_ABBA_BLOCK ",block," ",label," ",JSON.stringify(blocks.back().summary))
 var result={"scenario":"frozen_earned_scene_renderer_only","renderer":RenderingServer.get_video_adapter_name(),"order":order,"samples_per_variant":100,"warmup_per_block":10,"state_equal":before==game.checkpoint_data(),"logical_elapsed":game.elapsed,"units":game.units.size(),"enemies":game.enemies.size(),"quality_mode":game.performance_mode,"scaling_3d_scale":root.scaling_3d_scale,"viewport":str(root.get_visible_rect().size),"blocks":blocks,"summary":{"baseline":summarize(pooled.baseline),"mask":summarize(pooled.mask)}}
 var file=FileAccess.open(destination,FileAccess.WRITE);file.store_string(JSON.stringify(result,"  "))
 print("HUD_MASK_STATIC_ABBA ",JSON.stringify(result.summary)," state_equal=",result.state_equal)
 quit(0 if result.state_equal else 1)
