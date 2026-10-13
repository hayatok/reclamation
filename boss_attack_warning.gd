class_name BossAttackWarning
extends Node3D
## Render-only warnings reconstructed from current boss windup / attack_pos.
## No timer, delta, RNG, effects-list entry, gameplay write, or saved visual state.
## The caller passes ONLY currently visible boss records, and adds an explicit
## target_visible bool to each. Optional patch_visible(Rect2) must conservatively
## accept the entire world-XZ rectangle; omit it only where there is no fog.

const ATTACK_RADIUS: float = 4.5
const WINDUP_SECONDS: float = 1.4
const SEGMENT_COUNT: int = 48
const GROUND_LIFT: float = 0.07
const OUTLINE_WIDTH: float = 0.34
const LINE_WIDTH: float = 0.19
const DASH_FRACTION: float = 0.91
const PENDING_COLOR: Color = Color(0.97, 0.25, 0.075, 0.90)
const READY_COLOR: Color = Color(1.0, 0.66, 0.23, 0.97)
const HEAD_COLOR: Color = Color(1.0, 0.90, 0.55, 0.99)
const HIDDEN_COLOR: Color = Color(0.0, 0.0, 0.0, 0.0)

var _mesh: ArrayMesh
var _material: StandardMaterial3D
var _segment_transforms: Array[Transform3D] = []
var _segment_bounds: Array[Rect2] = []
var _rings: Dictionary = {}
var _mesh_build_count: int = 0
var _color_write_count: int = 0

func _init() -> void:
	set_process(false)
	set_physics_process(false)

## Call once after simulation on every render, including paused frames and the
## first frame after load. Inactive presentation hides immediately. Records are
## read only. Keep eligible idle bosses in the list so their renderer is reused.
func sync_warnings(eligible_bosses: Array, presentation_active: bool = true,
		patch_visible: Callable = Callable()) -> void:
	var retained: Dictionary = {}
	for value: Variant in eligible_bosses:
		if not value is Dictionary:
			continue
		var record: Dictionary = value
		var identifier: int = _living_boss_id(record)
		if identifier == 0:
			continue
		retained[identifier] = true
		var remaining_value: Variant = record.get("windup", 0.0)
		var center_value: Variant = record.get("attack_pos")
		var valid_warning: bool = presentation_active and record.get("target_visible", false) == true \
				and _finite_number(remaining_value) and float(remaining_value) > 0.0 \
				and center_value is Vector3 and center_value.is_finite()
		if not valid_warning:
			if _rings.has(identifier):
				_hide_ring(_rings[identifier])
			continue
		if not _rings.has(identifier):
			_rings[identifier] = _create_ring(identifier)
		_show_ring(_rings[identifier], center_value, float(remaining_value), patch_visible)
	# Omitted, dead, freed and fog-hidden bosses cannot leave a stale warning.
	for identifier: Variant in _rings.keys():
		if not retained.has(identifier):
			var instance: MultiMeshInstance3D = _rings[identifier].instance
			instance.visible = false
			remove_child(instance)
			instance.queue_free()
			_rings.erase(identifier)

## Immediate terminal/menu/reset hook; the next sync remains authoritative.
func clear_warnings() -> void:
	for value: Variant in _rings.values():
		_hide_ring(value)

func get_debug_state() -> Dictionary:
	var states: Dictionary = {}
	var visible_count: int = 0
	for identifier: Variant in _rings:
		var ring: Dictionary = _rings[identifier]
		var instance: MultiMeshInstance3D = ring.instance
		if instance.visible:
			visible_count += 1
		states[identifier] = {
			"visible": instance.visible,
			"radius": ATTACK_RADIUS,
			"center": ring.center,
			"remaining": ring.remaining,
			"progress": ring.progress,
			"bright_segments": ring.bright_segments,
			"visible_segments": ring.visible_segments,
			"mesh_instance_id": instance.get_instance_id(),
			"multimesh_id": instance.multimesh.get_instance_id(),
			"colors": ring.colors.duplicate(),
		}
	return {
		"rings": states,
		"visible_count": visible_count,
		"cached_count": _rings.size(),
		"mesh_build_count": _mesh_build_count,
		"color_write_count": _color_write_count,
		"mesh_resource_id": _mesh.get_instance_id() if _mesh != null else 0,
		"segments_per_ring": SEGMENT_COUNT,
		"vertices_per_segment": 12,
	}

func _living_boss_id(record: Dictionary) -> int:
	if not record.get("boss", false) or record.get("dead", false):
		return 0
	var hp: Variant = record.get("hp", 0.0)
	var actor: Variant = record.get("node")
	if not _finite_number(hp) or float(hp) <= 0.0 or not is_instance_valid(actor) \
			or not actor is Node3D or actor.is_queued_for_deletion():
		return 0
	return actor.get_instance_id()

func _finite_number(value: Variant) -> bool:
	return (value is float or value is int) and is_finite(float(value))

func _hide_ring(ring: Dictionary) -> void:
	ring.instance.visible = false
	ring.remaining = 0.0
	ring.progress = 0.0
	ring.bright_segments = 0
	ring.visible_segments = 0

func _create_ring(identifier: int) -> Dictionary:
	_ensure_geometry()
	var multimesh: MultiMesh = MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_colors = true
	multimesh.mesh = _mesh
	multimesh.instance_count = SEGMENT_COUNT
	var colors: PackedColorArray = PackedColorArray()
	colors.resize(SEGMENT_COUNT)
	colors.fill(HIDDEN_COLOR)
	for i: int in SEGMENT_COUNT:
		multimesh.set_instance_transform(i, _segment_transforms[i])
		multimesh.set_instance_color(i, HIDDEN_COLOR)
	var instance: MultiMeshInstance3D = MultiMeshInstance3D.new()
	instance.name = "BossWarning_%s" % identifier
	instance.top_level = true
	instance.multimesh = multimesh
	instance.material_override = _material
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	instance.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	instance.layers = 1
	instance.visible = false
	add_child(instance)
	return {
		"instance": instance, "colors": colors, "center": Vector3.ZERO,
		"remaining": 0.0, "progress": 0.0, "bright_segments": 0,
		"visible_segments": 0,
	}

func _show_ring(ring: Dictionary, center: Vector3, remaining: float,
		patch_visible: Callable) -> void:
	var bounded_remaining: float = clampf(remaining, 0.0, WINDUP_SECONDS)
	var progress: float = clampf(1.0 - bounded_remaining / WINDUP_SECONDS, 0.0, 1.0)
	var bright_count: int = clampi(floori(progress * SEGMENT_COUNT), 0, SEGMENT_COUNT)
	var pending: Color = PENDING_COLOR.lerp(READY_COLOR, progress * 0.25)
	var instance: MultiMeshInstance3D = ring.instance
	instance.transform = Transform3D(Basis.IDENTITY, center + Vector3.UP * GROUND_LIFT)
	var colors: PackedColorArray = ring.colors
	var visible_segments: int = 0
	for i: int in SEGMENT_COUNT:
		var patch: Rect2 = _segment_bounds[i]
		patch.position += Vector2(center.x, center.z)
		var permitted: bool = not patch_visible.is_valid() or patch_visible.call(patch) == true
		var color: Color = HIDDEN_COLOR
		if permitted:
			visible_segments += 1
			color = READY_COLOR if i < bright_count else pending
			if i == bright_count and progress > 0.0:
				color = HEAD_COLOR
		if colors[i] != color:
			instance.multimesh.set_instance_color(i, color)
			colors[i] = color
			_color_write_count += 1
	ring.colors = colors
	ring.center = center
	ring.remaining = bounded_remaining
	ring.progress = progress
	ring.bright_segments = bright_count
	ring.visible_segments = visible_segments
	instance.visible = visible_segments > 0

func _ensure_geometry() -> void:
	if _mesh != null:
		return
	var vertices: PackedVector3Array = PackedVector3Array()
	var colors: PackedColorArray = PackedColorArray()
	var step: float = TAU / SEGMENT_COUNT
	# Thin dark border makes the amber/red edge readable against busy ground.
	# No disc/fill obscures units. Both bands stay centered at the damage radius.
	_append_band(vertices, colors, OUTLINE_WIDTH, step * 0.98, 0.0,
		Color(0.10, 0.075, 0.06, 0.86))
	_append_band(vertices, colors, LINE_WIDTH, step * DASH_FRACTION, 0.003, Color.WHITE)
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_COLOR] = colors
	_mesh = ArrayMesh.new()
	_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	_material = StandardMaterial3D.new()
	_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_material.vertex_color_use_as_albedo = true
	_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_material.no_depth_test = false
	_material.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	_material.render_priority = 2 # Below the final camera fog overlay.
	for i: int in SEGMENT_COUNT:
		var pose: Transform3D = Transform3D(Basis(Vector3.UP, -i * step), Vector3.ZERO)
		_segment_transforms.append(pose)
		var first: Vector3 = pose * vertices[0]
		var bounds: Rect2 = Rect2(Vector2(first.x, first.z), Vector2.ZERO)
		for vertex: Vector3 in vertices:
			var point: Vector3 = pose * vertex
			bounds = bounds.expand(Vector2(point.x, point.z))
		# Conservative footprint includes every triangle, with a small rounding guard.
		_segment_bounds.append(bounds.grow(0.002))
	_mesh_build_count += 1

func _append_band(vertices: PackedVector3Array, colors: PackedColorArray,
		width: float, arc: float, elevation: float, color: Color) -> void:
	var inner: float = ATTACK_RADIUS - width * 0.5
	var outer: float = ATTACK_RADIUS + width * 0.5
	var start: Vector3 = Vector3(1.0, 0.0, 0.0)
	var finish: Vector3 = Vector3(cos(arc), 0.0, sin(arc))
	var lift: Vector3 = Vector3.UP * elevation
	vertices.append_array(PackedVector3Array([
		start * inner + lift, start * outer + lift, finish * outer + lift,
		start * inner + lift, finish * outer + lift, finish * inner + lift,
	]))
	for i: int in 6:
		colors.append(color)
