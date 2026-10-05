class_name WorkerRoutePreview
extends Node3D
## Candidate render-only helper. This does not plan, validate, or mutate routes.
## Supply exactly one selected worker and its COMPLETE current validated polyline.
## World positions must already be on the ground; this helper never samples terrain.

const MAX_WAYPOINTS: int = 64
const LINE_WIDTH: float = 0.10
const GROUND_LIFT: float = 0.055
const MARKER_RADIUS: float = 0.34
const MARKER_WIDTH: float = 0.055
const MIN_SEGMENT_LENGTH: float = 0.0001
const ENDPOINT_TOLERANCE: float = 0.001
const LINE_COLOR: Color = Color("d2c19c")
const DESTINATION_COLOR: Color = Color("c4b695")

var _worker_id: int = 0
var _worker_position: Vector3 = Vector3.ZERO
var _waypoints: Array[Vector3] = []
var _destination_info: Dictionary = {}
var _route_vertices: PackedVector3Array = PackedVector3Array()
var _route_arrays: Array = []
var _route_mesh: ArrayMesh = ArrayMesh.new()
var _body: MeshInstance3D
var _lead: MeshInstance3D
var _destination: MeshInstance3D
var _route_segment_count: int = 0
var _rebuild_count: int = 0
var _lead_update_count: int = 0
var _initialized: bool = false

func _init() -> void:
	# World-space input stays correct under a translated/rotated/scaled scene parent.
	top_level = true
	visible = false
	set_process(false)
	set_physics_process(false)

func _ready() -> void:
	global_transform = Transform3D.IDENTITY
	_ensure_renderers()

## Required destination field: world_position (Vector3), matching route.back().
## Optional metadata fields: id, kind, label (strings; retained, never rendered).
## The caller must explicitly affirm that ALL supplied segments are current and
## validated, including worker_world_position -> remaining_waypoints[0].
## Invalid, empty, oversized, incomplete, or unreachable input clears everything.
## Returns true only when a visible preview is accepted.
func set_selected_worker_route(
	selected_worker_id: int,
	worker_world_position: Vector3,
	remaining_waypoints: Array,
	destination_info: Dictionary,
	route_is_valid: bool
) -> bool:
	if not _input_is_valid(selected_worker_id, worker_world_position, remaining_waypoints, destination_info, route_is_valid):
		clear_preview()
		return false
	_ensure_renderers()
	var changed: bool = selected_worker_id != _worker_id or not _same_route(remaining_waypoints)
	_worker_id = selected_worker_id
	_destination_info = {
		"world_position": remaining_waypoints.back(),
		"id": str(destination_info.get("id", "")),
		"kind": str(destination_info.get("kind", "")),
		"label": str(destination_info.get("label", "")),
	}
	if changed:
		_waypoints.clear()
		for point: Vector3 in remaining_waypoints:
			_waypoints.append(point)
		_rebuild_body()
		_destination.position = _waypoints.back() + Vector3.UP * (GROUND_LIFT + 0.005)
	_update_lead(worker_world_position, changed)
	visible = _route_segment_count > 0 or _lead.visible
	_destination.visible = visible
	return visible

## Cheap movement-only update. Call only after authoritative movement ALONG the
## same first segment. A consumed waypoint/replan must use set_selected_worker_route.
## Late movement notifications from a previously selected worker are ignored.
func update_worker_position(selected_worker_id: int, worker_world_position: Vector3) -> bool:
	if _worker_id == 0 or selected_worker_id != _worker_id or _waypoints.is_empty():
		return false
	if not worker_world_position.is_finite():
		clear_preview()
		return false
	_update_lead(worker_world_position, false)
	visible = _route_segment_count > 0 or _lead.visible
	_destination.visible = visible
	return visible

## Call on deselection, multi-selection, worker death, idle/arrived, route pending,
## blocked/unreachable, scene reset, or a destination/route no longer being current.
func clear_preview() -> void:
	visible = false
	_worker_id = 0
	_waypoints.clear()
	_destination_info.clear()
	_route_segment_count = 0
	if _initialized:
		_body.visible = false
		_lead.visible = false
		_destination.visible = false

## A read-only diagnostic snapshot; no references to caller or simulation state.
func get_preview_state() -> Dictionary:
	return {
		"visible": visible,
		"worker_id": _worker_id,
		"waypoint_count": _waypoints.size(),
		"body_segment_count": _route_segment_count,
		"body_rebuild_count": _rebuild_count,
		"lead_update_count": _lead_update_count,
		"destination": _destination_info.duplicate(),
	}

func _input_is_valid(worker_id: int, worker_position: Vector3, points: Array, info: Dictionary, route_is_valid: bool) -> bool:
	if not route_is_valid or worker_id <= 0 or not worker_position.is_finite():
		return false
	if points.is_empty() or points.size() > MAX_WAYPOINTS:
		return false
	if not info.has("world_position") or not info.world_position is Vector3:
		return false
	var endpoint: Vector3 = info.world_position
	if not endpoint.is_finite():
		return false
	for point in points:
		if not point is Vector3 or not point.is_finite():
			return false
	return endpoint.distance_to(points.back()) <= ENDPOINT_TOLERANCE

func _same_route(points: Array) -> bool:
	if _waypoints.size() != points.size():
		return false
	for i: int in points.size():
		if _waypoints[i] != points[i]:
			return false
	return true

func _ensure_renderers() -> void:
	if _initialized:
		return
	_initialized = true
	_route_arrays.resize(Mesh.ARRAY_MAX)
	var line_material: StandardMaterial3D = _material(LINE_COLOR)
	_body = _make_instance("ValidatedRouteBody", _route_mesh, line_material)
	# Unit quad: transformed onto worker -> first supplied waypoint. It never
	# points directly at the destination unless that IS the supplied first leg.
	var lead_vertices: PackedVector3Array = PackedVector3Array([
		Vector3(-0.5, 0, 0), Vector3(0.5, 0, 0), Vector3(0.5, 0, 1),
		Vector3(-0.5, 0, 0), Vector3(0.5, 0, 1), Vector3(-0.5, 0, 1),
	])
	_lead = _make_instance("ValidatedCurrentLeg", _mesh_from_vertices(lead_vertices), line_material)
	var marker_vertices: PackedVector3Array = PackedVector3Array()
	marker_vertices.resize(24)
	var corners: Array[Vector3] = [Vector3.FORWARD, Vector3.RIGHT, Vector3.BACK, Vector3.LEFT]
	for i: int in 4:
		var next: int = (i + 1) % 4
		var outer_a: Vector3 = corners[i] * MARKER_RADIUS
		var outer_b: Vector3 = corners[next] * MARKER_RADIUS
		var inner_a: Vector3 = corners[i] * (MARKER_RADIUS - MARKER_WIDTH)
		var inner_b: Vector3 = corners[next] * (MARKER_RADIUS - MARKER_WIDTH)
		_set_quad(marker_vertices, i * 6, outer_a, outer_b, inner_b, inner_a)
	_destination = _make_instance("ActualDestinationMarker", _mesh_from_vertices(marker_vertices), _material(DESTINATION_COLOR))
	_body.visible = false
	_lead.visible = false
	_destination.visible = false

func _material(color: Color) -> StandardMaterial3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = color
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	# Keep normal depth testing: the preview does not reveal routes through props.
	material.no_depth_test = false
	return material

func _make_instance(label: String, mesh: ArrayMesh, material: StandardMaterial3D) -> MeshInstance3D:
	var instance: MeshInstance3D = MeshInstance3D.new()
	instance.name = label
	instance.mesh = mesh
	instance.material_override = material
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(instance)
	return instance

func _mesh_from_vertices(vertices: PackedVector3Array) -> ArrayMesh:
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	var mesh: ArrayMesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh

func _rebuild_body() -> void:
	_rebuild_count += 1
	_route_segment_count = 0
	for i: int in range(1, _waypoints.size()):
		if _horizontal_length(_waypoints[i] - _waypoints[i - 1]) > MIN_SEGMENT_LENGTH:
			_route_segment_count += 1
	# Buffers/mesh/instances are retained. Resize only when segment count changes;
	# the render surface is replaced only when selection or waypoint values change.
	var vertex_count: int = _route_segment_count * 6
	if _route_vertices.size() != vertex_count:
		_route_vertices.resize(vertex_count)
	var cursor: int = 0
	for i: int in range(1, _waypoints.size()):
		var start: Vector3 = _waypoints[i - 1] + Vector3.UP * GROUND_LIFT
		var finish: Vector3 = _waypoints[i] + Vector3.UP * GROUND_LIFT
		var direction: Vector3 = finish - start
		if _horizontal_length(direction) <= MIN_SEGMENT_LENGTH:
			continue
		var side: Vector3 = Vector3(-direction.z, 0, direction.x).normalized() * (LINE_WIDTH * 0.5)
		_set_quad(_route_vertices, cursor, start - side, start + side, finish + side, finish - side)
		cursor += 6
	_route_mesh.clear_surfaces()
	if vertex_count > 0:
		_route_arrays[Mesh.ARRAY_VERTEX] = _route_vertices
		_route_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, _route_arrays)
	_body.visible = vertex_count > 0

func _update_lead(worker_position: Vector3, force: bool) -> void:
	if not force and worker_position == _worker_position:
		return
	_worker_position = worker_position
	_lead_update_count += 1
	var direction: Vector3 = _waypoints[0] - worker_position
	if _horizontal_length(direction) <= MIN_SEGMENT_LENGTH:
		_lead.visible = false
		return
	var side: Vector3 = Vector3(-direction.z, 0, direction.x).normalized() * LINE_WIDTH
	# The z basis includes supplied elevation, preserving the actual segment.
	_lead.transform = Transform3D(Basis(side, Vector3.UP, direction), worker_position + Vector3.UP * GROUND_LIFT)
	_lead.visible = true

func _horizontal_length(direction: Vector3) -> float:
	return Vector2(direction.x, direction.z).length()

func _set_quad(vertices: PackedVector3Array, offset: int, a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
	vertices[offset] = a
	vertices[offset + 1] = b
	vertices[offset + 2] = c
	vertices[offset + 3] = a
	vertices[offset + 4] = c
	vertices[offset + 5] = d
