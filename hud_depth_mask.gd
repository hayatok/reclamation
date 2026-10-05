extends MeshInstance3D
## Render-only occluder. Never changes a world node or game state.
## A single opaque surface sits behind proven opaque HUD interiors and in front
## of the 3D world. The CanvasLayer still draws the actual HUD over this surface.
const PANEL_TEXTURE = "res://assets/ui/panel.svg"
const MIN_TEXTURE_MARGIN = 19.0
const PIXEL_GUARD = 2.0
var enabled:bool = true
var covered_rects:Array[Rect2] = []
var rebuild_count:int = 0
var game:Node
var camera:Camera3D
var _signature:Array = []

func setup(owner_game:Node)->void:
 game=owner_game
 camera=game.camera
 name="HudDepthMask"
 cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 gi_mode=GeometryInstance3D.GI_MODE_DISABLED
 layers=1
 extra_cull_margin=.001
 var surface=StandardMaterial3D.new()
 surface.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
 surface.transparency=BaseMaterial3D.TRANSPARENCY_DISABLED
 surface.depth_draw_mode=BaseMaterial3D.DEPTH_DRAW_OPAQUE_ONLY
 surface.no_depth_test=false
 surface.cull_mode=BaseMaterial3D.CULL_DISABLED
 surface.disable_fog=true
 surface.albedo_color=Color("161c18")
 surface.render_priority=Material.RENDER_PRIORITY_MIN
 material_override=surface
 camera.add_child(self)
 RenderingServer.frame_pre_draw.connect(sync_now)
 sync_now()

func _exit_tree()->void:
 if RenderingServer.frame_pre_draw.is_connected(sync_now):RenderingServer.frame_pre_draw.disconnect(sync_now)

func _blocked()->bool:
 if not enabled or not is_instance_valid(game) or not is_instance_valid(camera):return true
 if camera.projection!=Camera3D.PROJECTION_ORTHOGONAL or (camera.cull_mask&1)==0:return true
 if not camera.global_transform.basis.is_equal_approx(camera.global_transform.basis.orthonormalized()):return true
 if camera.get_viewport().get_camera_3d()!=camera:return true
 if game.title_open or game.ended or game.active_card:return true
 for key in ["options_panel","choice_panel","route_panel","dismantle_panel"]:
  var overlay=game.get(key)
  if is_instance_valid(overlay) and overlay is CanvasItem and overlay.is_visible_in_tree():return true
 return false

func _opaque_rect(panel:Control,viewport_rect:Rect2)->Rect2:
 if not is_instance_valid(panel) or not panel.is_visible_in_tree():return Rect2()
 var ancestor:Node=panel
 while ancestor!=null:
  if ancestor is CanvasItem:
   if ancestor.modulate.a!=1.0 or ancestor.self_modulate.a!=1.0 or ancestor.material!=null:return Rect2()
  if ancestor is CanvasLayer and not ancestor.visible:return Rect2()
  if ancestor!=panel and ancestor is Control and ancestor.clip_contents:return Rect2()
  ancestor=ancestor.get_parent()
 if not panel.has_theme_stylebox_override("panel"):return Rect2()
 var skin=panel.get_theme_stylebox("panel")
 if not skin is StyleBoxTexture or not skin.draw_center or skin.modulate_color.a!=1.0:return Rect2()
 if skin.texture==null or skin.texture.resource_path!=PANEL_TEXTURE or skin.region_rect!=Rect2():return Rect2()
 for side in [SIDE_LEFT,SIDE_TOP,SIDE_RIGHT,SIDE_BOTTOM]:
  if skin.get_texture_margin(side)<MIN_TEXTURE_MARGIN or skin.get_expand_margin(side)!=0:return Rect2()
 var transform2d=panel.get_global_transform_with_canvas()
 # The current HUD has positive axis-aligned transforms. Reject rotation,
 # skew and mirroring instead of approximating the opaque polygon by an AABB.
 if absf(transform2d.x.y)>.000001 or absf(transform2d.y.x)>.000001 or transform2d.x.x<=0 or transform2d.y.y<=0:return Rect2()
 var inside=Rect2(Vector2.ZERO,panel.size).grow_individual(-skin.get_texture_margin(SIDE_LEFT),-skin.get_texture_margin(SIDE_TOP),-skin.get_texture_margin(SIDE_RIGHT),-skin.get_texture_margin(SIDE_BOTTOM))
 if not inside.has_area():return Rect2()
 var screen_rect:Rect2=(transform2d*inside).grow(-PIXEL_GUARD).intersection(viewport_rect)
 return screen_rect if screen_rect.has_area() else Rect2()

func sync_now()->void:
 if _blocked():
  visible=false
  covered_rects.clear()
  return
 var viewport_rect=camera.get_viewport().get_visible_rect()
 var rects:Array[Rect2]=[]
 for panel in game.hud_parts:
  if not panel is Control:continue
  var rectangle=_opaque_rect(panel,viewport_rect)
  if rectangle.has_area():rects.append(rectangle)
 if rects.is_empty():
  visible=false
  covered_rects.clear()
  return
 var next_signature:Array=[rects,camera.get_camera_projection(),camera.h_offset,camera.v_offset,viewport_rect]
 if next_signature!=_signature:
  var vertices=PackedVector3Array()
  var normals=PackedVector3Array()
  var indices=PackedInt32Array()
  var depth:float=camera.near+.25
  for rectangle in rects:
   var start=vertices.size()
   for corner in [rectangle.position,Vector2(rectangle.end.x,rectangle.position.y),rectangle.end,Vector2(rectangle.position.x,rectangle.end.y)]:
    vertices.append(camera.to_local(camera.project_position(corner,depth)))
    normals.append(Vector3.BACK)
   for offset in [0,1,2,0,2,3]:indices.append(start+offset)
  var arrays:Array=[]
  arrays.resize(Mesh.ARRAY_MAX)
  arrays[Mesh.ARRAY_VERTEX]=vertices
  arrays[Mesh.ARRAY_NORMAL]=normals
  arrays[Mesh.ARRAY_INDEX]=indices
  var geometry=ArrayMesh.new()
  geometry.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
  mesh=geometry
  _signature=next_signature
  rebuild_count+=1
 covered_rects=rects
 visible=true
