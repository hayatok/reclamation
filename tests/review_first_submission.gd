extends Node3D
const Actors=preload("res://actor_visuals.gd")
const Muzzles=preload("res://weapon_muzzles.gd")
var delta_sample:float=.12
var before:bool=false
var output:String=""
func _ready():
 for arg:String in OS.get_cmdline_user_args():
  if arg=="--before":before=true
  if arg.begins_with("--delta="):delta_sample=float(arg.trim_prefix("--delta="))
  if arg.begins_with("--capture="):output=arg.trim_prefix("--capture=")
 var environment=WorldEnvironment.new();environment.environment=Environment.new();environment.environment.background_mode=Environment.BG_COLOR;environment.environment.background_color=Color("263237");environment.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;environment.environment.ambient_light_energy=.65;add_child(environment)
 var sun=DirectionalLight3D.new();sun.rotation_degrees=Vector3(-48,-35,0);sun.light_energy=1.35;add_child(sun)
 var floor=MeshInstance3D.new();var plane=PlaneMesh.new();plane.size=Vector2(34,28);floor.mesh=plane;var mat=StandardMaterial3D.new();mat.albedo_color=Color("39433d");floor.material_override=mat;add_child(floor)
 var camera=Camera3D.new();camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=21;camera.position=Vector3(11,17,18);add_child(camera);camera.look_at(Vector3(0,0,-1));camera.current=true
 var script=load("res://tests/fixtures/battle_fx_v034.gd" if before else "res://battle_fx.gd")
 var fx=script.new();add_child(fx)
 for i in 2:
  var actor=Node3D.new();actor.position=Vector3(-3+i*5,0,2);actor.rotation.y=-.35-float(i)*1.1;add_child(actor);Actors.add_human(actor,"guard");Actors.pose(actor,1.4+i,true,.02)
  var unit={"node":actor,"kind":"guard"};var target:Vector3=actor.position-actor.global_basis.z*6+Vector3(0,.7,0)
  var socket=Muzzles.anchor(unit);fx.muzzle(actor.position+Vector3.UP,false,socket);fx.beam(actor.position+Vector3.UP,target,Color("d2a148"),.1,.055,socket);fx.impact(target,"armored")
 fx.blast(Vector3(-5,0,-6),2,true)
 var ui=CanvasLayer.new();add_child(ui);var caption=Label.new();ui.add_child(caption);caption.position=Vector2(20,18);caption.add_theme_font_size_override("font_size",22);caption.text="Controlled frame delta: %.3f s\nFirst presentation of rifle / impact / blast cues"%delta_sample
 fx.update(delta_sample,camera)
 await RenderingServer.frame_post_draw
 await RenderingServer.frame_post_draw
 print("CUE_REVIEW before=",before," delta=",delta_sample," flash=",fx.batches.flash.visible_instance_count," streak=",fx.batches.streak.visible_instance_count)
 if not output.is_empty():
  var error=get_viewport().get_texture().get_image().save_png(output);print("CUE_CAPTURE ",error)
 get_tree().quit()
