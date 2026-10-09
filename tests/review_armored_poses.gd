extends SceneTree
const Library=preload("res://armored_pose_library.gd")
const ActorVisuals=preload("res://actor_visuals.gd")
func _initialize():call_deferred("run")
func run():
 assert(Library.configure())
 var stage=Node3D.new();root.add_child(stage)
 var env=WorldEnvironment.new();var settings=Environment.new();settings.background_mode=Environment.BG_COLOR;settings.background_color=Color('#45535a');settings.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;settings.ambient_light_color=Color('#c7d1d0');settings.ambient_light_energy=.65;env.environment=settings;stage.add_child(env)
 var light=DirectionalLight3D.new();light.rotation_degrees=Vector3(-53,-30,0);light.light_energy=1.3;light.shadow_enabled=true;stage.add_child(light)
 var ground=MeshInstance3D.new();var plane=PlaneMesh.new();plane.size=Vector2(20,20);ground.mesh=plane;var mat=StandardMaterial3D.new();mat.albedo_color=Color('#4c5450');ground.material_override=mat;stage.add_child(ground)
 var camera=Camera3D.new();camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=9;camera.position=Vector3(4,6,10);stage.add_child(camera);camera.look_at(Vector3(0,.4,0));camera.current=true
 var old=Node3D.new();stage.add_child(old);old.position=Vector3(-3,0,0);ActorVisuals.add_enemy(old,false,true)
 var i=0
 for pair in [["walk",4],["attack",0],["death",9]]:
  var mesh=MeshInstance3D.new();mesh.mesh=Library.mesh_for(pair[0],pair[1],false);stage.add_child(mesh);mesh.position=Vector3(-1+i*2,0,0);i+=1
 for f in 10:await process_frame
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(OS.get_environment("HEAVY_POSE_OUTPUT"));quit()
