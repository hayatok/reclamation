extends Node3D
## Visual A/B fixture: same real meshes, interpolation, poses and FX as gameplay.
## Space pause / M motion / B original centre origins / F fire / Z zoom / 1–5 row.
const ActorVisuals=preload("res://actor_visuals.gd")
const StructureVisuals=preload("res://structure_visuals.gd")
const WeaponMuzzles=preload("res://weapon_muzzles.gd")
const Interpolation=preload("res://render_interpolation.gd")
const Horde=preload("res://horde_renderer.gd")
const FX=preload("res://battle_fx.gd")
const STEP:float=1.0/30.0
var units:Array=[]
var shots:Array=[]
var interpolation=Interpolation.new()
var renderer
var fx
var camera:Camera3D
var caption:Label
var clock:float=0
var remainder:float=0
var fire_clock:float=.55
var moving:bool=false
var paused:bool=false
var legacy:bool=false
var zoom:int=0
var row:int=-1
var last_frames:Dictionary={}
var screenshot_path:String=""
var screenshot_at:float=-1
var quit_after_capture:bool=false

func _ready():
 for arg:String in OS.get_cmdline_user_args():
  if arg=="--legacy-origins":legacy=true
  if arg=="--moving":moving=true
  if arg.begins_with("--capture="):screenshot_path=arg.trim_prefix("--capture=");screenshot_at=.55
  if arg.begins_with("--row="):row=int(arg.trim_prefix("--row="))
  if arg.begins_with("--zoom="):zoom=int(arg.trim_prefix("--zoom="))%3
  if arg=="--quit-after-capture":quit_after_capture=true
 var environment=WorldEnvironment.new();environment.environment=Environment.new()
 environment.environment.background_mode=Environment.BG_COLOR
 environment.environment.background_color=Color("283337")
 environment.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
 environment.environment.ambient_light_color=Color("d5d4c8");environment.environment.ambient_light_energy=.8
 add_child(environment)
 var sunlight=DirectionalLight3D.new();add_child(sunlight)
 sunlight.rotation_degrees=Vector3(-52,-35,0);sunlight.light_energy=1.7
 var floor=MeshInstance3D.new();var plane=PlaneMesh.new();plane.size=Vector2(95,95);floor.mesh=plane
 var floor_mat=StandardMaterial3D.new();floor_mat.albedo_color=Color("4a534d");floor.material_override=floor_mat;add_child(floor)
 camera=Camera3D.new();add_child(camera);camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.current=true
 renderer=Horde.new();add_child(renderer);fx=FX.new();add_child(fx)
 var kinds:Array=["guard","grenade","siegecart","tower","mortar"]
 for y:int in kinds.size():
  for direction:int in 8:
   var kind:String=kinds[y]
   var actor=Node3D.new();add_child(actor)
   actor.position=Vector3((direction-3.5)*4.8,0,(y-2)*7.5)
   actor.rotation.y=direction*TAU/8
   if kind in ["guard","grenade"]:
    ActorVisuals.add_human(actor,kind)
    for mesh:Node in actor.find_children("*","MeshInstance3D",true,false):mesh.visible=false
   elif kind=="siegecart":interpolation.visual_root(actor).add_child(load("res://assets/models/siege_cart.glb").instantiate())
   else:StructureVisuals.add_building(actor,kind)
   var unit={"node":actor,"kind":kind,"hp":100.0,"base":actor.position,"direction":direction,"row":y,"attack_at":-10.0,"shots":0}
   units.append(unit)
   var label=Label3D.new();actor.add_child(label)
   label.text=kind+" "+str(direction*45)+"°";label.position=Vector3(0,.06,1.8)
   label.billboard=BaseMaterial3D.BILLBOARD_ENABLED;label.font_size=28;label.pixel_size=.012
 interpolation.reset(units,[],[])
 var overlay=CanvasLayer.new();add_child(overlay);caption=Label.new();overlay.add_child(caption)
 caption.position=Vector2(18,16);caption.add_theme_font_size_override("font_size",20)
 update_view()

func update_view():
 var focus:=Vector3(0,0,(row-2)*7.5 if row>=0 else 0)
 camera.position=focus+Vector3(10,31,34);camera.look_at(focus)
 camera.size=[52.0,35.0,22.0][zoom]
 for unit:Dictionary in units:
  unit.node.visible=row<0 or unit.row==row
 caption.text=("LEGACY: centre / fixed height" if legacy else "FIXED: actual rendered weapon socket")+" | "+("MOVING" if moving else "STOPPED")+" | zoom "+str(camera.size)+"\nSpace pause  •  M motion  •  B compare  •  F fire  •  Z zoom  •  1–5 row / 0 all"

func _unhandled_key_input(event:InputEvent):
 if not event is InputEventKey or not event.pressed or event.echo:return
 match event.keycode:
  KEY_SPACE:paused=not paused
  KEY_M:moving=not moving
  KEY_B:legacy=not legacy;clear_fx();fire_clock=0
  KEY_F:fire_clock=0
  KEY_Z:zoom=(zoom+1)%3
  KEY_0:row=-1
  KEY_1,KEY_2,KEY_3,KEY_4,KEY_5:row=event.keycode-KEY_1
 update_view()

func clear_fx():
 for shot:Dictionary in shots:shot.node.free()
 shots.clear()
 for list:Array in fx.particles.values():list.clear()

func _process(delta:float):
 var fired:bool=false
 if not paused:
  remainder+=minf(delta,.15)
  while remainder>=STEP:
   remainder-=STEP;interpolation.before_step(units,[],[]);clock+=STEP;fire_clock-=STEP
   var firing:bool=fire_clock<=0
   if firing:fire_clock=1.1;fired=true
   for unit:Dictionary in units:
    if moving and unit.kind in ["guard","grenade","siegecart"]:
     unit.node.position=unit.base+Vector3(sin(clock*1.6)*.8,0,cos(clock*1.6)*.4)
     unit.node.rotation.y=unit.direction*TAU/8+sin(clock)*.25
    if firing and (row<0 or unit.row==row):unit.attack_at=clock;shoot(unit)
    if unit.kind in ["guard","grenade"]:
     var age:float=clock-unit.attack_at
     ActorVisuals.pose(unit.node,clock*8+unit.direction,moving,age,clampf((age-.2)/.8,0,1) if age>.2 else -1)
   interpolation.after_step(units,[],[])
   # Freeze the same logical shot pose for before/after captures, independent of FPS.
   if screenshot_at>=0 and clock>=screenshot_at and firing:
    remainder=STEP
    break
 last_frames=interpolation.frame(remainder/STEP)
 var visible_units:Array=units.filter(func(u):return row<0 or u.row==row)
 renderer.update_friends(visible_units,last_frames)
 for shot:Dictionary in shots.duplicate():
  var fresh:bool=shot.get("fresh",false);shot.erase("fresh")
  if shot.has("socket"):
   shot.origin=WeaponMuzzles.world_position(shot.socket,last_frames,shot.origin);shot.erase("socket")
  if not paused and not fresh:shot.age+=delta
  var t:float=minf(1,shot.age/shot.duration)
  shot.node.position=shot.origin.lerp(shot.target,t)+Vector3(0,sin(t*PI)*shot.height,0)
  if t>=1:shot.node.free();shots.erase(shot)
 var capturing:bool=screenshot_at>=0 and clock>=screenshot_at and fired
 fx.update(0 if paused or capturing else delta,camera,[],last_frames)
 if capturing:
  screenshot_at=-1;paused=true
  await RenderingServer.frame_post_draw
  var result=get_viewport().get_texture().get_image().save_png(screenshot_path)
  print("MUZZLE_REVIEW_CAPTURE ",screenshot_path," result=",result," clock=",clock," alpha=",remainder/STEP)
  if quit_after_capture:
   await RenderingServer.frame_post_draw
   get_tree().quit(0 if result==OK else 1)

func shoot(unit:Dictionary):
 var origin:Vector3=unit.node.global_position+Vector3(0,3.3 if unit.kind=="tower" else 2.4 if unit.kind=="mortar" else 1,0)
 if unit.kind=="siegecart":origin=unit.node.to_global(WeaponMuzzles.SIEGE_MUZZLE)
 var socket:Dictionary={} if legacy else WeaponMuzzles.anchor(unit)
 var target:Vector3=unit.node.global_position-unit.node.global_basis.z*3.2+Vector3(0,.7,0)
 var heavy:bool=unit.kind in ["siegecart","mortar"]
 fx.muzzle(origin,heavy,socket)
 if unit.kind in ["guard","tower"]:fx.beam(origin,target,Color("d2a148"),.10,.055,socket)
 else:
  var ball=MeshInstance3D.new();var sphere=SphereMesh.new();sphere.radius=.10;sphere.height=.20;ball.mesh=sphere;add_child(ball)
  var material=StandardMaterial3D.new();material.albedo_color=Color("fff0a3");material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;ball.material_override=material
  var shot={"node":ball,"origin":origin,"target":target,"duration":1.35 if heavy else .8,"height":7 if heavy else 3,"age":0.0,"fresh":true}
  if not socket.is_empty():shot.socket=socket
  shots.append(shot)
 unit.shots+=1
