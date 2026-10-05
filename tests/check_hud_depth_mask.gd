extends SceneTree
const Mask=preload("res://hud_depth_mask.gd")
const Deck=preload("res://command_deck.gd")
class Game:
 extends Node3D
 var camera:Camera3D
 var hud_parts:Array=[]
 var title_open=false
 var ended=false
 var active_card=false
 var options_panel:Control
 var choice_panel:Control
 var route_panel:Control
 var dismantle_panel:Control
var viewport:SubViewport
var game:Game
var root_ui:Control
var panel:PanelContainer
var mask:MeshInstance3D
func _initialize():call_deferred("run")
func verify_projection():
 var arrays=mask.mesh.surface_get_arrays(0)
 var vertices:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
 assert(vertices.size()==mask.covered_rects.size()*4)
 assert(arrays[Mesh.ARRAY_INDEX].size()==mask.covered_rects.size()*6)
 for i in mask.covered_rects.size():
  var rectangle:Rect2=mask.covered_rects[i]
  var expected=[rectangle.position,Vector2(rectangle.end.x,rectangle.position.y),rectangle.end,Vector2(rectangle.position.x,rectangle.end.y)]
  for j in 4:
   var world:Vector3=mask.global_transform*vertices[i*4+j]
   assert(game.camera.unproject_position(world).distance_to(expected[j])<.05,"Mask projection escaped HUD rectangle")
   assert(not game.camera.is_position_behind(world))
func run():
 viewport=SubViewport.new();viewport.size=Vector2i(1440,900);viewport.own_world_3d=true;root.add_child(viewport)
 game=Game.new();viewport.add_child(game)
 game.camera=Camera3D.new();game.add_child(game.camera)
 game.camera.projection=Camera3D.PROJECTION_ORTHOGONAL;game.camera.size=42
 game.camera.position=Vector3(37,48,51);game.camera.look_at(Vector3(0,0,8));game.camera.current=true
 var canvas=CanvasLayer.new();game.add_child(canvas)
 root_ui=Control.new();canvas.add_child(root_ui)
 panel=PanelContainer.new();root_ui.add_child(panel);panel.size=Vector2(1440,84)
 panel.add_theme_stylebox_override("panel",Deck.skin("panel",10));game.hud_parts=[panel]
 await process_frame
 mask=Mask.new();mask.setup(game);mask.sync_now()
 assert(mask.visible and mask.covered_rects.size()==1)
 assert(mask.covered_rects[0].is_equal_approx(Rect2(21,21,1398,42)))
 assert(mask.cast_shadow==GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
 assert(mask.material_override.render_priority==Material.RENDER_PRIORITY_MIN)
 assert(mask.material_override.transparency==BaseMaterial3D.TRANSPARENCY_DISABLED)
 verify_projection()
 var rebuilds=mask.rebuild_count;mask.sync_now();assert(mask.rebuild_count==rebuilds,"Unchanged HUD rebuilt")
 for zoom in [26.0,42.0,85.0]:
  game.camera.size=zoom;mask.sync_now();verify_projection()
  game.camera.position+=Vector3(5,0,-3);mask.sync_now();verify_projection()
 panel.size=Vector2(800,200);panel.position=Vector2(100,50);mask.sync_now()
 assert(mask.covered_rects[0].is_equal_approx(Rect2(121,71,758,158)));verify_projection()
 panel.visible=false;mask.sync_now();assert(not mask.visible)
 panel.visible=true;mask.sync_now();assert(mask.visible)
 panel.modulate.a=.5;mask.sync_now();assert(not mask.visible);panel.modulate.a=1
 root_ui.modulate.a=.5;mask.sync_now();assert(not mask.visible);root_ui.modulate.a=1
 var skin=panel.get_theme_stylebox("panel");skin.draw_center=false;mask.sync_now();assert(not mask.visible);skin.draw_center=true
 skin.modulate_color.a=.5;mask.sync_now();assert(not mask.visible);skin.modulate_color.a=1
 panel.rotation=.2;mask.sync_now();assert(not mask.visible);panel.rotation=0
 root_ui.clip_contents=true;mask.sync_now();assert(not mask.visible);root_ui.clip_contents=false
 for flag in ["title_open","ended","active_card"]:
  game.set(flag,true);mask.sync_now();assert(not mask.visible);game.set(flag,false)
 game.options_panel=PanelContainer.new();root_ui.add_child(game.options_panel);mask.sync_now();assert(not mask.visible)
 game.options_panel.hide();mask.sync_now();assert(mask.visible)
 game.camera.projection=Camera3D.PROJECTION_PERSPECTIVE;mask.sync_now();assert(not mask.visible)
 game.camera.projection=Camera3D.PROJECTION_ORTHOGONAL
 mask.enabled=false;mask.sync_now();assert(not mask.visible)
 mask.enabled=true;mask.sync_now();assert(mask.visible);verify_projection()
 print("HUD_DEPTH_MASK_GEOMETRY_PASS opaque_interior=true projection=true cached=true resize=true visibility=true translucent_rejected=true menus=true title=true shadow_off=true priority_min=true")
 quit()
