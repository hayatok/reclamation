extends SceneTree
## Run with: godot --headless --path . --script res://tests/test_horde_hits.gd
## Hit reactions deliberately use recoil only, preserving original material identity.
const Horde = preload("res://horde_renderer.gd")
const Visuals = preload("res://actor_visuals.gd")
var failures: int = 0

func _initialize() -> void:
	call_deferred("_test")

func _test() -> void:
	var world := Node3D.new()
	root.add_child(world)
	var horde := Horde.new()
	world.add_child(horde)
	var enemies: Array = []
	var originals: Array[Transform3D] = []
	for i: int in 6:
		var actor := Node3D.new()
		world.add_child(actor)
		actor.position = Vector3(i * 2.0, 0, -i * .5)
		actor.rotation.y = i * .3
		originals.append(actor.transform)
		enemies.append({"node":actor,"hp":80.0,"speed":1.2 if i == 2 else 1.65,"armored":i == 2,"dead":false})
	horde.update_horde(enemies, 10.0)
	var baseline: Array = _snapshot(horde)
	_check(horde.get_child_count() == 18, "18 batches")
	for i: int in 18:
		var batch: MultiMeshInstance3D = horde.get_child(i)
		_check(not batch.multimesh.use_custom_data and not batch.multimesh.use_colors, "transform-only instances")
		_check(batch.material_override == null, "no shader or material override")
		var expected: Material = Visuals.mesh_for(Horde.KINDS[i / 6], Horde.PARTS[i % 6]).surface_get_material(0)
		_check(batch.multimesh.mesh.surface_get_material(0) == expected, "original shared material identity")
		_check(expected is StandardMaterial3D and expected.vertex_color_use_as_albedo, "original vertex-colored StandardMaterial3D")
	for bucket in horde._buckets:
		for buffer: PackedFloat32Array in bucket.buffers:
			_check(buffer.size() == bucket.capacity * 12, "12-float allocated stride")
	var kinds: Array[String] = ["normal", "critical", "armored", "critical", "normal"]
	for i: int in 5:
		enemies[i]["hit_kind"] = kinds[i]
		enemies[i]["hit_until"] = 9.9 if i == 4 else 10.12
	enemies[3]["hit_reduced"] = true
	horde.update_horde(enemies, 10.0)
	var active: Array = _snapshot(horde)
	var addresses: Array[Vector2i] = [Vector2i(0,0),Vector2i(0,1),Vector2i(2,0),Vector2i(0,2),Vector2i(0,3),Vector2i(0,4)]
	for i: int in 6:
		var address: Vector2i = addresses[i]
		var offset: int = address.y * 12
		for part: int in 6:
			var before: PackedFloat32Array = baseline[address.x][part]
			var after: PackedFloat32Array = active[address.x][part]
			var moved: bool = not _same_transform(before, after, offset)
			_check(moved == (i < 4 and part not in [2,3]), "recoil only moves affected body, head, and arms")
			for value: float in after:
				_check(is_finite(value), "finite buffer")
		_check(enemies[i].node.transform.is_equal_approx(originals[i]), "actor root unchanged")
		_check(enemies[i].hp == 80.0, "health untouched")
	var normal_recoil: float = _position(active[0][0], 0).distance_to(_position(baseline[0][0], 0))
	var critical_recoil: float = _position(active[0][0], 12).distance_to(_position(baseline[0][0], 12))
	var armored_recoil: float = _position(active[2][0], 0).distance_to(_position(baseline[2][0], 0))
	var reduced_recoil: float = _position(active[0][0], 24).distance_to(_position(baseline[0][0], 24))
	_check(critical_recoil > normal_recoil and armored_recoil < normal_recoil, "critical stronger, armored softer")
	_check(reduced_recoil > 0.0 and reduced_recoil < normal_recoil, "reduced effects has smaller recoil and no flash")
	horde.update_horde(enemies, 10.121)
	var expired: Array = _snapshot(horde)
	for enemy: Dictionary in enemies:
		enemy.erase("hit_until")
		enemy.erase("hit_kind")
		enemy.erase("hit_reduced")
	horde.update_horde(enemies, 10.121)
	var missing: Array = _snapshot(horde)
	for kind: int in 3:
		for part: int in 6:
			_check(expired[kind][part] == missing[kind][part], "expired effects exactly match missing fields")
	enemies[0].hit_until = NAN
	horde.update_horde(enemies, 11.0)
	var invalid: Array = _snapshot(horde)
	enemies[0].erase("hit_until")
	horde.update_horde(enemies, 11.0)
	_check(invalid == _snapshot(horde), "invalid hit clock safely ignored")
	_check(horde.get_child_count() == 18 and horde.visible_enemies == 6, "effects add no nodes or instances")
	world.free()
	print("HORDE_HIT_REACTIONS_FAILURES=", failures)
	quit(1 if failures > 0 else 0)

func _snapshot(horde: Node3D) -> Array:
	var result: Array = []
	for bucket in horde._buckets:
		var parts: Array = []
		for buffer: PackedFloat32Array in bucket.buffers:
			parts.append(buffer.duplicate())
		result.append(parts)
	return result

func _position(buffer: PackedFloat32Array, offset: int) -> Vector3:
	return Vector3(buffer[offset + 3], buffer[offset + 7], buffer[offset + 11])

func _same_transform(a: PackedFloat32Array, b: PackedFloat32Array, offset: int) -> bool:
	for i: int in 12:
		if absf(a[offset+i] - b[offset+i]) > .00001:
			return false
	return true

func _check(condition: bool, label: String) -> void:
	if not condition:
		failures += 1
		push_error(label)
