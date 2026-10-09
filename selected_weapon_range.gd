class_name SelectedWeaponRange
extends Node3D
## Render-only ground range for ONE selected living combat unit.
## The caller supplies its authoritative weapon radius and eligibility every
## selection/mode change, including death, group selection, menus, and reset.
## world_position must be the unit's ground position; no terrain is sampled.

const ANGULAR_SEGMENTS: int = 64
const DASH_FRACTION: float = 0.62
const LINE_WIDTH: float = 0.10
const GROUND_LIFT: float = 0.06
const LINE_COLOR: Color = Color(0.82, 0.76, 0.57, 0.58)
const RENDER_PRIORITY: int = 0

var _mesh: ArrayMesh = ArrayMesh.new()
var _instance: MeshInstance3D
var _vertices: PackedVector3Array = PackedVector3Array()
var _arrays: Array = []
var _cached_radius: float = -1.0
var _active_radius: float = 0.0
var _world_position: Vector3 = Vector3.ZERO
var _rebuild_count: int = 0
var _position_update_count: int = 0

func _init() -> void:
	top_level = true
	visible = false
	set_process(false)
	set_physics_process(false)

func _ready() -> void:
	_ensure_renderer()

## Returns true for an accepted visible range. Radius is never clamped or
## rounded: this is a visual representation of the caller's weapon value.
## Positive radii must exceed half the fixed line width. Production values
## 10.5-28.6 m are covered without changing the segment or vertex budget.
func set_range(world_position: Vector3, radius: float, eligible: bool) -> bool:
	if not eligible or not world_position.is_finite() or not is_finite(radius) \
			or radius <= LINE_WIDTH * 0.5 \
			or not Vector3(radius + LINE_WIDTH * 0.5, 0.0, 0.0).is_finite():
		clear_range()
		return false
	_ensure_renderer()
	if radius != _cached_radius:
		_rebuild_mesh(radius)
	var origin: Vector3 = world_position + Vector3.UP * GROUND_LIFT
	# As a top-level Node3D, this local transform IS a world transform even
	# under a scaled/rotated parent. Using it also permits calls before _ready.
	if transform.origin != origin or transform.basis != Basis.IDENTITY:
		transform = Transform3D(Basis.IDENTITY, origin)
		_position_update_count += 1
	_world_position = world_position
	_active_radius = radius
	visible = true
	return true

## Hide immediately, retaining the allocation and mesh for a later reselect.
func clear_range() -> void:
	visible = false
	_active_radius = 0.0
	_world_position = Vector3.ZERO

## Values only: callers cannot mutate renderer or simulation state through it.
func get_debug_state() -> Dictionary:
	return {
		"visible": visible,
		"radius": _active_radius,
		"cached_radius": _cached_radius,
		"world_position": _world_position,
		"mesh_rebuild_count": _rebuild_count,
		"position_update_count": _position_update_count,
		"angular_segments": ANGULAR_SEGMENTS,
		"vertex_count": _vertices.size(),
		"triangle_count": _vertices.size() / 3,
		"surface_count": _mesh.get_surface_count(),
		"mesh_resource_id": _mesh.get_instance_id(),
		"mesh_instance_id": _instance.get_instance_id() if is_instance_valid(_instance) else 0,
	}

func _ensure_renderer() -> void:
	if is_instance_valid(_instance):
		return
	_arrays.resize(Mesh.ARRAY_MAX)
	_vertices.resize(ANGULAR_SEGMENTS * 6)
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = LINE_COLOR
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.no_depth_test = false
	# Do not change the scene depth used by the final camera fog overlay.
	material.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	material.render_priority = RENDER_PRIORITY
	_instance = MeshInstance3D.new()
	_instance.name = "SelectedWeaponRangeRing"
	_instance.mesh = _mesh
	_instance.material_override = material
	_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_instance.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	_instance.layers = 1
	add_child(_instance)

func _rebuild_mesh(radius: float) -> void:
	var inner_radius: float = radius - LINE_WIDTH * 0.5
	var outer_radius: float = radius + LINE_WIDTH * 0.5
	var step: float = TAU / ANGULAR_SEGMENTS
	for i: int in ANGULAR_SEGMENTS:
		var start_angle: float = i * step
		var end_angle: float = (i + DASH_FRACTION) * step
		var start: Vector3 = Vector3(cos(start_angle), 0.0, sin(start_angle))
		var finish: Vector3 = Vector3(cos(end_angle), 0.0, sin(end_angle))
		var offset: int = i * 6
		_vertices[offset] = start * inner_radius
		_vertices[offset + 1] = start * outer_radius
		_vertices[offset + 2] = finish * outer_radius
		_vertices[offset + 3] = start * inner_radius
		_vertices[offset + 4] = finish * outer_radius
		_vertices[offset + 5] = finish * inner_radius
	_mesh.clear_surfaces()
	_arrays[Mesh.ARRAY_VERTEX] = _vertices
	_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, _arrays)
	_cached_radius = radius
	_rebuild_count += 1
