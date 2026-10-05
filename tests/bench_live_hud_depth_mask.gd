extends SceneTree
## One process, four fresh restores of the same checkpoint: live A/B/B/A.
const Mask=preload("res://hud_depth_mask.gd")
const Probe=preload("res://tests/live_hud_depth_probe.gd")
var game:Node
func _initialize():call_deferred("run")
func summarize(raw:Dictionary)->Dictionary:
 var result={}
 for key in raw:
  var values:Array=raw[key].duplicate();values.sort()
  var sum:float=0
  for value in values:sum+=float(value)
  result[key]={"mean":sum/values.size(),"median":(float(values[int((values.size()-1)/2)])+float(values[int(values.size()/2)]))*.5,"p95":values[mini(values.size()-1,int(values.size()*.95))],"n":values.size()}
 return result
func run()->void:
 var destination="res://.experiment/live_abba.json"
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--mask-bench-output="):destination=arg.trim_prefix("--mask-bench-output=")
 var phases=[]
 var pooled={"baseline":{},"mask":{}}
 var reference:Dictionary={}
 for phase in 4:
  if is_instance_valid(game):game.free()
  var campaign=root.get_node("Campaign")
  campaign.current=0;campaign.launch=true;campaign.resume=true;campaign.muted=true;campaign.performance_mode=false
  game=load("res://main.tscn").instantiate();game.set_script(Probe);game.set_process(false)
  root.add_child(game);current_scene=game;game.set_process(false)
  if game.title_open or game.units.size()!=16 or game.enemies.size()!=13 or not is_equal_approx(game.elapsed,677.3):
   push_error("Live fixture did not restore the exact earned state");quit(2);return
  var enabled=phase in [1,2]
  var label="mask" if enabled else "baseline"
  var mask=game.hud_depth_mask;mask.enabled=enabled;mask.sync_now()
  var viewport=root.get_viewport_rid()
  RenderingServer.viewport_set_measure_render_time(viewport,true)
  for warm in 3:
   await process_frame
   await RenderingServer.frame_post_draw
  if not is_equal_approx(game.elapsed,677.3):push_error("Fixture advanced during preparation");quit(2);return
  game.benchmark_frames=0
  game.paused=false;game.set_process(true)
  var raw={}
  var last=Time.get_ticks_usec()
  for frame in 150:
   await process_frame
   await RenderingServer.frame_post_draw
   var now=Time.get_ticks_usec()
   var wall=float(now-last)/1000.0;last=now
   if frame<30:continue
   var row={"frame_ms":wall,"script_cpu_ms":game.benchmark_script_ms,"render_cpu_ms":RenderingServer.viewport_get_measured_render_time_cpu(viewport),"render_gpu_timer_ms":RenderingServer.viewport_get_measured_render_time_gpu(viewport),"setup_cpu_ms":RenderingServer.get_frame_setup_time_cpu(),"draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),"primitives":Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME),"shadow_primitives":RenderingServer.viewport_get_render_info(viewport,RenderingServer.VIEWPORT_RENDER_INFO_TYPE_SHADOW,RenderingServer.VIEWPORT_RENDER_INFO_PRIMITIVES_IN_FRAME),"canvas_draws":RenderingServer.viewport_get_render_info(viewport,RenderingServer.VIEWPORT_RENDER_INFO_TYPE_CANVAS,RenderingServer.VIEWPORT_RENDER_INFO_DRAW_CALLS_IN_FRAME),"texture_bytes":Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED)}
   for key in row:
    if not raw.has(key):raw[key]=[]
    if not pooled[label].has(key):pooled[label][key]=[]
    raw[key].append(row[key]);pooled[label][key].append(row[key])
  game.set_process(false)
  if game.benchmark_frames!=150:push_error("Unexpected logical frame count: %d, elapsed %.6f"%[game.benchmark_frames,game.elapsed]);quit(2);return
  var state=game.checkpoint_data()
  if reference.is_empty():reference=state.duplicate(true)
  var record={"phase":phase,"variant":label,"logical_frames":game.benchmark_frames,"state_equal":state==reference,"state":state,"summary":summarize(raw),"raw":raw,"masked_panels":mask.covered_rects.size(),"mask_rebuilds":mask.rebuild_count,"quality_mode":game.performance_mode,"scaling_3d_scale":root.scaling_3d_scale,"viewport":str(root.get_visible_rect().size)}
  phases.append(record)
  var partial=FileAccess.open(destination.trim_suffix(".json")+"_phase_%d.json"%phase,FileAccess.WRITE);partial.store_string(JSON.stringify(record,"  "))
  print("LIVE_MASK_PHASE ",phase," ",label," ",JSON.stringify(record.summary)," state_equal=",record.state_equal)
 var result={"scenario":"live_fixed_delta_restored_earned_scene","renderer":RenderingServer.get_video_adapter_name(),"order":"ABBA","logical_dt":1.0/60.0,"logical_frames_per_phase":150,"warmup_per_phase":30,"samples_per_phase":120,"state_equal":phases.all(func(p):return p.state_equal),"phases":phases,"summary":{"baseline":summarize(pooled.baseline),"mask":summarize(pooled.mask)}}
 var file=FileAccess.open(destination,FileAccess.WRITE);file.store_string(JSON.stringify(result,"  "))
 print("LIVE_HUD_MASK_ABBA ",JSON.stringify(result.summary)," state_equal=",result.state_equal)
 quit(0 if result.state_equal else 1)
