extends SceneTree
## Isolated controlled rendering workload; never instantiates or edits gameplay.
const Horde=preload('res://horde_renderer.gd')
const COUNT=200
const WARMUP=30
const MEASURED=90
const DT=1.0/60.0
var output:String
func _initialize():call_deferred('run')
func stats(values:Array)->Dictionary:
 var sorted=values.duplicate();sorted.sort()
 var total=0.0
 for v in values:total+=v
 return {'mean':total/values.size(),'median':sorted[sorted.size()/2],'p95':sorted[mini(sorted.size()-1,int(sorted.size()*.95))],'min':sorted[0],'max':sorted[-1],'samples':values.size()}
func run():
 output=OS.get_environment('RUNNER_BENCH_OUTPUT')
 if output.is_empty():output='user://runner_benchmark.json'
 root.size=Vector2i(1180,737);root.content_scale_size=Vector2i(1180,737)
 DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
 Engine.max_fps=0
 var stage=Node3D.new();root.add_child(stage);current_scene=stage
 var env=WorldEnvironment.new();var settings=Environment.new()
 settings.background_mode=Environment.BG_COLOR;settings.background_color=Color('#45535a')
 settings.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;settings.ambient_light_color=Color('#c7d1d0');settings.ambient_light_energy=.65
 settings.tonemap_mode=Environment.TONE_MAPPER_FILMIC;env.environment=settings;stage.add_child(env)
 var light=DirectionalLight3D.new();light.rotation_degrees=Vector3(-53,-30,0);light.light_color=Color('#ffe6c2');light.light_energy=1.3;light.shadow_enabled=true;stage.add_child(light)
 var ground=MeshInstance3D.new();var plane=PlaneMesh.new();plane.size=Vector2(70,70);ground.mesh=plane
 var material=StandardMaterial3D.new();material.albedo_color=Color('#4c5450');material.roughness=1;ground.material_override=material;stage.add_child(ground)
 var camera=Camera3D.new();camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=50;camera.position=Vector3(37,48,43);stage.add_child(camera);camera.look_at(Vector3.ZERO);camera.current=true
 var horde=Horde.new();stage.add_child(horde)
 var actors=[];var origins=[]
 for i in COUNT:
  var actor=Node3D.new();stage.add_child(actor)
  var origin=Vector3((float(i%20)-9.5)*1.35,0,(float(i/20)-4.5)*1.35+2.7)
  origins.append(origin);actor.position=origin
  actors.append({'node':actor,'speed':2.7,'armored':false,'moving':true,'hp':100,'attack_at':-100.0})
 await process_frame
 assert(horde.baked.active and horde.baked_runner.active)
 # Preload both branches so first construction cannot contaminate measured work.
 horde.update_horde(actors,0.0)
 await process_frame
 await RenderingServer.frame_post_draw
 var rounds=[]
 for round_index in 4:
  var authored=round_index%2==1
  var label='new_shared_poses' if authored else 'old_six_part'
  horde.baked_runner.active=authored;horde.baked_runner.visible=authored
  horde.baked_runner.visible_count=0
  horde.baked_runner.reset_motion()
  for i in COUNT:actors[i].node.position=origins[i]
  var update_cpu=[];var frame_wall=[];var draws=[];var primitives=[];var visible=[];var far_counts=[]
  for frame in WARMUP+MEASURED:
   var frame_start=Time.get_ticks_usec()
   for i in COUNT:actors[i].node.position=origins[i]+Vector3(0,0,-2.7*float(frame)*DT)
   var update_start=Time.get_ticks_usec()
   horde.update_horde(actors,float(frame)*DT)
   var update_ms=(Time.get_ticks_usec()-update_start)/1000.0
   await process_frame
   await RenderingServer.frame_post_draw
   var frame_ms=(Time.get_ticks_usec()-frame_start)/1000.0
   if frame>=WARMUP:
    update_cpu.append(update_ms);frame_wall.append(frame_ms)
    draws.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
    primitives.append(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
    visible.append(horde.visible_enemies)
    far_counts.append(horde.baked_runner.far_count if authored else 0)
   assert(horde.visible_enemies==COUNT,'Every mode must render all200roots')
  var row={'round':round_index+1,'mode':label,'render_update_cpu_ms':stats(update_cpu),'frame_wall_ms':stats(frame_wall),'draw_calls':stats(draws),'primitives':stats(primitives),'visible_count':stats(visible),'new_far_count':stats(far_counts)}
  rounds.append(row)
  print('RUNNER_BENCH_ROUND ',JSON.stringify(row))
 var report={'scope':'Native controlled200runner renderer A/B; not gameplay enemy-count change or browser/device performance','renderer':RenderingServer.get_video_adapter_name(),'rendering_method':RenderingServer.get_current_rendering_method(),'resolution':[1180,737],'camera_size':50,'count':COUNT,'speed_mps':2.7,'simulation_dt':DT,'warmup_frames_per_round':WARMUP,'measured_frames_per_round':MEASURED,'round_order':['old','new','old','new'],'vsync_requested_disabled':true,'same_loaded_assets_both_modes':true,'same_actor_roots_and_positions':true,'same_light_floor_camera':true,'screenshot_encoding_in_timing':false,'memory_claim':false,'old_shadow_policy':'torso only, retained runtime policy','new_shadow_policy':'farLOD shadows off, retained runtime policy','rounds':rounds}
 var file=FileAccess.open(output,FileAccess.WRITE);assert(file!=null);file.store_string(JSON.stringify(report,'  '));file.close()
 print('RUNNER_BENCH_COMPLETE ',output)
 quit()
