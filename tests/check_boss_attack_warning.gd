extends SceneTree
## Copy to res://tests/check_boss_attack_warning.gd after integrating the helper.
## godot --headless --path <project> --script res://tests/check_boss_attack_warning.gd
const Warning: Script = preload("res://boss_attack_warning.gd")
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error(message)

func _state(warning: Node3D, boss: Node3D) -> Dictionary:
	return warning.get_debug_state().rings.get(boss.get_instance_id(), {})

func _run() -> void:
	var parent: Node3D = Node3D.new()
	parent.transform = Transform3D(Basis(Vector3.UP, 0.7).scaled(Vector3(3, 2, 4)), Vector3(50, 8, -40))
	root.add_child(parent)
	var warning: Node3D = Warning.new()
	parent.add_child(warning)
	var boss: Node3D = Node3D.new()
	root.add_child(boss)
	var target: Vector3 = Vector3(4, 0, -3)
	var record: Dictionary = {
		"node": boss, "boss": true, "dead": false, "hp": 1000.0,
		"windup": 1.4, "attack_pos": target, "target_visible": true,
	}
	warning.sync_warnings([record])
	var initial: Dictionary = _state(warning, boss)
	_check(initial.visible and initial.radius == 4.5 and initial.progress == 0.0, "first frame must show the full authoritative radius")
	_check(initial.visible_segments == 48, "first frame omitted boundary segments")
	_check(not warning.is_processing() and not warning.is_physics_processing(), "renderer must never advance on a local clock")
	var instance: MultiMeshInstance3D = warning.get_child(0)
	_check(instance.top_level and instance.global_transform.basis == Basis.IDENTITY, "parent transform altered warning radius")
	_check(instance.global_position.is_equal_approx(target + Vector3.UP * 0.07), "warning lost world position or ground lift")
	var material: StandardMaterial3D = instance.material_override
	_check(material.shading_mode == BaseMaterial3D.SHADING_MODE_UNSHADED and material.vertex_color_use_as_albedo, "warning must preserve instance colors under any lighting")
	_check(material.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA, "warning became opaque")
	_check(not material.no_depth_test and material.depth_draw_mode == BaseMaterial3D.DEPTH_DRAW_DISABLED, "warning occlusion/depth compromises fog")
	_check(material.render_priority < Material.RENDER_PRIORITY_MAX, "warning renders after fog")
	_check(instance.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF, "warning casts shadows")
	var vertices: PackedVector3Array = instance.multimesh.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	for vertex: Vector3 in vertices:
		var radial: float = Vector2(vertex.x, vertex.z).length()
		_check(radial >= 4.329 and radial <= 4.671, "ring geometry changed radius or filled its center")
	var untouched: Dictionary = record.duplicate()
	var writes: int = warning.get_debug_state().color_write_count
	# Paused renders pass the same simulation state, regardless of wall time.
	for i: int in 120:
		warning.sync_warnings([record])
	_check(_state(warning, boss) == initial, "same authoritative state changed paused warning")
	_check(warning.get_debug_state().color_write_count == writes, "paused sync rewrote unchanged instance colors")
	await create_timer(0.05).timeout
	_check(_state(warning, boss) == initial, "wall time changed the paused warning")
	_check(record == untouched, "renderer mutated the simulation record")
	# Countdown derives from saved authoritative state; no visual history needed.
	record.windup = 0.7
	warning.sync_warnings([record])
	var half: Dictionary = _state(warning, boss)
	_check(is_equal_approx(half.progress, 0.5) and half.bright_segments == 24 and half.radius == 4.5, "half windup cue is not bounded to the fixed radius")
	var reloaded: Node3D = Warning.new()
	parent.add_child(reloaded)
	reloaded.sync_warnings([record.duplicate()])
	var loaded: Dictionary = _state(reloaded, boss)
	_check(loaded.visible and loaded.center == half.center and loaded.remaining == half.remaining and loaded.colors == half.colors, "fresh renderer failed to reconstruct a saved mid-windup warning")
	reloaded.free()
	# View clipping must happen before drawing, even with a visible target center.
	warning.sync_warnings([record], true, func(patch: Rect2) -> bool: return patch.end.x < target.x)
	var clipped: Dictionary = _state(warning, boss)
	_check(clipped.visible_segments > 0 and clipped.visible_segments < 48, "cross-fog ring was not partially clipped")
	var shown: int = 0
	for color: Color in clipped.colors:
		if color.a > 0.0:
			shown += 1
	_check(shown == clipped.visible_segments, "clipped segments retain visible colors")
	warning.sync_warnings([record], true, func(_patch: Rect2) -> bool: return false)
	_check(not _state(warning, boss).visible, "fully clipped ring remains visible")
	record.target_visible = false
	warning.sync_warnings([record])
	_check(not _state(warning, boss).visible, "hidden target reveals warning")
	record.erase("target_visible")
	warning.sync_warnings([record])
	_check(not _state(warning, boss).visible, "missing target visibility must fail closed")
	record.target_visible = true
	# Impact, ended, title and explicit clear must hide immediately.
	record.windup = 0.0
	warning.sync_warnings([record])
	_check(not _state(warning, boss).visible, "impact left the warning on screen")
	record.windup = 1.4
	warning.sync_warnings([record])
	_check(_state(warning, boss).mesh_instance_id == initial.mesh_instance_id, "new attack reallocated the boss renderer")
	warning.sync_warnings([record], false)
	_check(not _state(warning, boss).visible, "ended/inactive presentation left a warning")
	warning.sync_warnings([record])
	warning.clear_warnings()
	_check(not _state(warning, boss).visible, "explicit terminal hook left a warning")
	for remaining: float in [-0.1, NAN, INF]:
		record.windup = remaining
		warning.sync_warnings([record])
		_check(not _state(warning, boss).visible, "invalid/nonpositive windup retained a warning")
	record.windup = 99.0
	warning.sync_warnings([record])
	_check(_state(warning, boss).progress == 0.0 and _state(warning, boss).remaining == 1.4, "oversized windup escaped bounded cue range")
	record.attack_pos = Vector3(INF, 0, 0)
	warning.sync_warnings([record])
	_check(not _state(warning, boss).visible, "invalid target position retained a warning")
	record.attack_pos = target
	warning.sync_warnings([record])
	record.dead = true
	warning.sync_warnings([record])
	_check(warning.get_debug_state().cached_count == 0, "dead boss retained a ring")
	record.dead = false
	warning.sync_warnings([record])
	warning.sync_warnings([])
	_check(warning.get_debug_state().cached_count == 0, "omitted/fog-hidden boss retained a ring")
	warning.sync_warnings([record])
	boss.queue_free()
	warning.sync_warnings([record])
	_check(warning.get_debug_state().cached_count == 0, "queued-for-deletion boss retained a ring")
	_check(warning.get_debug_state().mesh_build_count == 1, "updates rebuilt cached ring geometry")
	parent.free()
	if failures.is_empty():
		print("PASS boss warning: fixed radius, cached geometry/colors, pause, fresh-renderer restore, clipping, lifecycle, bounded cues, no record mutation")
	quit(0 if failures.is_empty() else 1)
