extends SceneTree
## Isolated art review, not earned-play acceptance or a browser performance test.
const Library=preload('res://runner_pose_library.gd')
var camera:Camera3D
var stage:Node3D
var output='user://runner_asset_review'
func _initialize():call_deferred('run')
func run():
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with('--out='):output=arg.trim_prefix('--out=')
 root.size=Vector2i(1180,737)
 root.content_scale_size=Vector2i(1180,737)
 assert(Library.configure())
 stage=Node3D.new();root.add_child(stage);current_scene=stage
 var env=WorldEnvironment.new();var settings=Environment.new()
 settings.background_mode=Environment.BG_COLOR;settings.background_color=Color('#45535a')
 settings.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;settings.ambient_light_color=Color('#c7d1d0');settings.ambient_light_energy=.65
 settings.tonemap_mode=Environment.TONE_MAPPER_FILMIC;env.environment=settings;stage.add_child(env)
 var light=DirectionalLight3D.new();light.rotation_degrees=Vector3(-53,-30,0);light.light_color=Color('#ffe6c2');light.light_energy=1.3;light.shadow_enabled=true;stage.add_child(light)
 var ground=MeshInstance3D.new();var plane=PlaneMesh.new();plane.size=Vector2(70,70);ground.mesh=plane
 var material=StandardMaterial3D.new();material.albedo_color=Color('#4c5450');material.roughness=1;ground.material_override=material;stage.add_child(ground)
 camera=Camera3D.new();camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=8;camera.position=Vector3(5,4.5,7);stage.add_child(camera);camera.look_at(Vector3(0,.65,0));camera.current=true
 var figures=[]
 for far in [false,true]:
  for i in 4:
   var node=MeshInstance3D.new();node.position=Vector3((i-1.5)*1.8,0,-1.3 if far else 1.3);node.rotation.y=[-.5,.8,1.65,2.7][i]
   # MeshInstance custom data is not available; pair weight is applied through
   # a 1-instance MultiMesh, the identical runtime shader path.
   var mm=MultiMesh.new();mm.transform_format=MultiMesh.TRANSFORM_3D;mm.use_custom_data=true;mm.use_colors=true;mm.instance_count=1;mm.visible_instance_count=1
   var batch=MultiMeshInstance3D.new();batch.multimesh=mm;batch.transform=node.transform;stage.add_child(batch);node.free()
   figures.append({'mm':mm,'far':far,'phase':float(i)*.25,'batch':batch})
 var title=Label.new();title.position=Vector2(24,20);title.add_theme_font_size_override('font_size',22);root.add_child(title)
 for frame in 144:
  var distant=frame>=96
  camera.size=50 if distant else 8
  title.text='Original runner: near row and far row, articulated run | CAMERA '+str(camera.size)+' | isolated art preview'
  for figure in figures:
   var pose=Library.sample('run',float(frame)/60.0,figure.phase)
   figure.mm.mesh=Library.mesh_for('run',int(pose.x),figure.far)
   figure.mm.set_instance_transform(0,Transform3D.IDENTITY)
   figure.mm.set_instance_color(0,Color.WHITE)
   figure.mm.set_instance_custom_data(0,Color(pose.z,0,0,0))
  await process_frame
  await RenderingServer.frame_post_draw
  if frame in [0,12,24,36,48,60,72,84,96,108,120,132,143]:root.get_texture().get_image().save_png(output+'_%03d.png'%frame)
 print('RUNNER_ASSET_REVIEW_DONE '+output+'; isolated art only, no gameplay/performance acceptance')
 quit()
