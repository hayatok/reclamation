extends MeshInstance3D
## Attach to the active Camera3D, not the terrain or UI CanvasLayer.
## setup(camera, visibility) parents the mesh; sync_now() refreshes the shared
## small mask after a visibility update. It performs no simulation or RNG work.
const FogShader: Shader = preload("res://frontier_fog.gdshader")
var field: RefCounted
var _surface: ShaderMaterial
var _bound_texture: ImageTexture

func setup(camera: Camera3D, visibility_field: RefCounted) -> void:
	field = visibility_field
	name = "FrontierFogOverlay"
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	layers = 1
	# A camera child plus conservative local culling bounds avoids CPU rejection.
	extra_cull_margin = 32.0
	custom_aabb = AABB(Vector3(-16.0, -16.0, -16.0), Vector3(32.0, 32.0, 32.0))
	var vertices: PackedVector3Array = PackedVector3Array([
		Vector3(-1.0, -1.0, 0.0), Vector3(3.0, -1.0, 0.0), Vector3(-1.0, 3.0, 0.0),
	])
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	var triangle: ArrayMesh = ArrayMesh.new()
	triangle.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh = triangle
	_surface = ShaderMaterial.new()
	_surface.shader = FogShader
	# Reserve the final transparent draw priority for fog. World labels and FX
	# must use lower priorities; CanvasLayer controls still render afterwards.
	_surface.render_priority = Material.RENDER_PRIORITY_MAX
	material_override = _surface
	if get_parent() == null:
		camera.add_child(self)
	position = Vector3(0.0, 0.0, -camera.near - 0.1)
	sync_now()

func sync_now() -> void:
	visible = field != null and field.enabled
	if not visible or _surface == null:
		return
	var texture: ImageTexture = field.get_mask_texture()
	if texture != _bound_texture:
		_surface.set_shader_parameter("visibility_mask", texture)
		_bound_texture = texture
	_surface.set_shader_parameter("map_origin", field.bounds.position)
	_surface.set_shader_parameter("map_size", field.bounds.size)
	_surface.set_shader_parameter("mask_world_size", Vector2(field.columns, field.rows) * field.cell_size)
