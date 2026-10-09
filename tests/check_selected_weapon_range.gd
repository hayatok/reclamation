extends SceneTree
## Run from this isolated project; it does not load or mutate the RTS.
const RangeIndicator: Script = preload("res://selected_weapon_range.gd")
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error(message)

func _run() -> void:
	var parent: Node3D = Node3D.new()
	parent.transform = Transform3D(Basis(Vector3.UP, 0.9).scaled(Vector3(3, 2, 4)), Vector3(75, 8, -45))
	root.add_child(parent)
	var ring = RangeIndicator.new()
	# Pre-tree input must survive _ready and a transformed parent.
	_check(ring.set_range(Vector3(4, 2, 7), 10.5, true), "valid pre-tree range rejected")
	parent.add_child(ring)
	_check(ring.top_level, "indicator must be top-level")
	_check(ring.global_transform.basis == Basis.IDENTITY, "parent scale/rotation contaminated radius")
	_check(ring.global_position.is_equal_approx(Vector3(4, 2.06, 7)), "ground lift or world placement incorrect")
	_check(not ring.is_processing() and not ring.is_physics_processing(), "helper must have no automatic update loops")
	_check(ring.get_child_count() == 1, "must create exactly one renderer")
	var instance: MeshInstance3D = ring.get_child(0)
	var material: StandardMaterial3D = instance.material_override
	_check(instance.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF, "range casts shadows")
	_check(instance.gi_mode == GeometryInstance3D.GI_MODE_DISABLED, "range participates in GI")
	_check(material.shading_mode == BaseMaterial3D.SHADING_MODE_UNSHADED, "range responds to lighting")
	_check(material.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA and material.albedo_color.a < 1.0, "range must be subtle transparent geometry")
	_check(not material.no_depth_test, "range reveals through opaque geometry")
	_check(material.depth_draw_mode == BaseMaterial3D.DEPTH_DRAW_DISABLED, "range alters depth read by fog")
	_check(material.render_priority < Material.RENDER_PRIORITY_MAX, "range renders after final fog")
	var initial: Dictionary = ring.get_debug_state()
	_check(initial.mesh_rebuild_count == 1 and initial.surface_count == 1, "first input must build one surface")
	for i: int in 120:
		ring.set_range(Vector3(i * 0.1, 2, 7), 10.5, true)
	var moved: Dictionary = ring.get_debug_state()
	_check(moved.mesh_rebuild_count == 1, "movement rebuilt geometry")
	_check(moved.mesh_resource_id == initial.mesh_resource_id and moved.mesh_instance_id == initial.mesh_instance_id, "movement reallocated mesh or renderer")
	for radius: float in [10.5, 13.0, 22.0, 28.6]:
		ring.set_range(Vector3(5, 0, -3), radius, true)
		var state: Dictionary = ring.get_debug_state()
		_check(state.radius == radius and state.cached_radius == radius, "authoritative radius was changed")
		_check(state.vertex_count == 384 and state.triangle_count == 128 and state.angular_segments == 64, "geometry budget changed")
		var vertices: PackedVector3Array = instance.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
		for i: int in 64:
			var inner: Vector3 = vertices[i * 6]
			var outer: Vector3 = vertices[i * 6 + 1]
			_check(absf(inner.length() - (radius - 0.05)) < 0.0001, "inner radius incorrect")
			_check(absf(outer.length() - (radius + 0.05)) < 0.0001, "outer radius incorrect")
			_check(absf(inner.distance_to(outer) - 0.10) < 0.0001, "world line width changed")
			_check(inner.y == 0.0 and outer.y == 0.0, "local geometry left ground plane")
			var dash_end: Vector3 = vertices[i * 6 + 2]
			var next_start: Vector3 = vertices[((i + 1) % 64) * 6 + 1]
			_check(dash_end.distance_to(next_start) > 0.1, "dash gap missing")
	var before_clear: Dictionary = ring.get_debug_state()
	_check(not ring.set_range(Vector3.ZERO, 28.6, false), "ineligible unit accepted")
	_check(not ring.visible and not instance.is_visible_in_tree(), "ineligible input did not hide immediately")
	_check(ring.get_debug_state().radius == 0.0, "ineligible range left stale active state")
	ring.set_range(Vector3.ZERO, 28.6, true)
	_check(ring.get_debug_state().mesh_rebuild_count == before_clear.mesh_rebuild_count, "reselection rebuilt unchanged cached radius")
	var invalid_cases: Array = [
		[Vector3(INF, 0, 0), 28.6], [Vector3(0, NAN, 0), 28.6],
		[Vector3.ZERO, INF], [Vector3.ZERO, NAN], [Vector3.ZERO, 0.0],
		[Vector3.ZERO, -10.5], [Vector3.ZERO, 0.05], [Vector3.ZERO, 1.0e100],
	]
	for invalid: Array in invalid_cases:
		ring.set_range(Vector3.ZERO, 28.6, true)
		_check(not ring.set_range(invalid[0], invalid[1], true), "invalid input accepted")
		_check(not ring.visible, "invalid input did not clear immediately")
	_check(ring.get_debug_state().mesh_rebuild_count == before_clear.mesh_rebuild_count, "invalid input rebuilt geometry")
	_check(ring.get_child_count() == 1, "repeat input accumulated renderers")
	parent.free()
	if failures.is_empty():
		print("PASS selected weapon range: placement, material/fog order, 64 dashes/128 triangles, 120 moves without rebuild, exact radius/width, cache reuse, immediate invalid clears")
	quit(0 if failures.is_empty() else 1)
