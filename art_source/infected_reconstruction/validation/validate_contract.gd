extends SceneTree

const Library = preload("res://infected_pose_library.gd")
var failures: Array[String] = []

func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error(message)

func triangle_ids(arrays: Array, count: int) -> PackedInt32Array:
	var uv2: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV2]
	var side: int = ceili(sqrt(float(count)))
	var result := PackedInt32Array()
	for index: int in arrays[Mesh.ARRAY_INDEX]:
		result.append(floori(uv2[index].y * side) * side + floori(uv2[index].x * side))
	return result

func packed_surface_bytes(mesh: Mesh) -> int:
	var surface: Dictionary = RenderingServer.mesh_get_surface(mesh.get_rid(), 0)
	var total: int = 0
	for key: String in ["vertex_data", "attribute_data", "skin_data", "index_data"]:
		total += surface.get(key, PackedByteArray()).size()
	for lod: Dictionary in surface.get("lods", []):
		total += lod.get("index_data", PackedByteArray()).size()
	return total

func test_reordered_target(current: Mesh, following: Mesh, reference: Mesh, label: String) -> float:
	var arrays: Array = following.surface_get_arrays(0)
	var count: int = arrays[Mesh.ARRAY_VERTEX].size()
	for slot: int in [Mesh.ARRAY_VERTEX, Mesh.ARRAY_NORMAL, Mesh.ARRAY_TEX_UV, Mesh.ARRAY_TEX_UV2]:
		arrays[slot].reverse()
	arrays[Mesh.ARRAY_TANGENT] = null
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	for i: int in indices.size():
		indices[i] = count - 1 - indices[i]
	arrays[Mesh.ARRAY_INDEX] = indices
	var permuted := ArrayMesh.new()
	permuted.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	permuted.surface_set_material(0, following.surface_get_material(0))
	var repaired: ArrayMesh = Library._pair_mesh(current, permuted, {})
	check(repaired != null, label + " deliberately permuted target pairs")
	if repaired == null:
		return INF
	var target_arrays: Array = repaired.surface_get_arrays(0)
	var expected_arrays: Array = reference.surface_get_arrays(0)
	check(target_arrays[Mesh.ARRAY_CUSTOM0] == expected_arrays[Mesh.ARRAY_CUSTOM0], label + " arbitrary vertex permutation preserves every paired target position")
	# Constructing the stress-test ArrayMesh repacks its normals once. Validate
	# IDs exactly against those repacked normals and measure that extra rounding.
	var permuted_arrays: Array = permuted.surface_get_arrays(0)
	var current_arrays: Array = current.surface_get_arrays(0)
	var current_ids := Library.corner_indices(current_arrays[Mesh.ARRAY_TEX_UV2], count)
	var permuted_ids := Library.corner_indices(permuted_arrays[Mesh.ARRAY_TEX_UV2], count)
	var actual_normals: PackedFloat32Array = target_arrays[Mesh.ARRAY_CUSTOM1]
	var original_normals: PackedFloat32Array = expected_arrays[Mesh.ARRAY_CUSTOM1]
	var repack_error: float = 0.0
	for id: int in count:
		var offset: int = current_ids[id] * 3
		var actual := Vector3(actual_normals[offset], actual_normals[offset + 1], actual_normals[offset + 2])
		var original := Vector3(original_normals[offset], original_normals[offset + 1], original_normals[offset + 2])
		check(actual == permuted_arrays[Mesh.ARRAY_NORMAL][permuted_ids[id]], label + " arbitrary vertex permutation preserves every repacked normal")
		repack_error = maxf(repack_error, actual.distance_to(original))
	check(repack_error < 0.001, label + " normal stress-test repacking remains below 0.001")
	return repack_error

func run_lod(label: String, path: String, expected: Dictionary) -> Dictionary:
	var scene := load(path) as PackedScene
	check(scene != null, label + " packed scene loads")
	if scene == null:
		return {}
	var root_node: Node = scene.instantiate()
	check(root_node.find_children("*", "Skeleton3D", true, false).is_empty(), label + " contains no skeleton")
	var nodes: Array[Node] = root_node.find_children("*", "MeshInstance3D", true, false)
	check(nodes.size() == 32, label + " has 32 pose nodes")
	var meshes: Dictionary = {}
	var reference_ids := PackedInt32Array()
	var reference_uv := PackedVector2Array()
	var minimum_y: float = INF
	var maximum_y: float = -INF
	var lod_count: int = 0
	var imported_vertices: int = 0
	var triangle_count: int = 0
	var reordered_poses: int = 0
	var reference_by_id := PackedInt32Array()
	var source_surface_bytes: int = 0
	var pair_surface_bytes: int = 0
	for node: MeshInstance3D in nodes:
		check(node.transform.is_equal_approx(Transform3D.IDENTITY), label + " identity transform: " + node.name)
		var mesh: Mesh = node.mesh
		check(mesh.get_surface_count() == 1, label + " one material surface: " + node.name)
		check(mesh.surface_get_material(0) is StandardMaterial3D, label + " original PBR material: " + node.name)
		var material := mesh.surface_get_material(0) as StandardMaterial3D
		check(material.albedo_texture != null, label + " embedded atlas: " + node.name)
		var arrays: Array = mesh.surface_get_arrays(0)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var uv: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
		var count: int = vertices.size()
		var by_id: PackedInt32Array = Library.corner_indices(arrays[Mesh.ARRAY_TEX_UV2], count)
		check(count == int(expected.expected_imported_vertices_per_pose), label + " exact corner vertex count: " + node.name)
		check(by_id.size() == count, label + " UV2 bijection: " + node.name)
		check(arrays[Mesh.ARRAY_INDEX].size() / 3 == int(expected.triangles_per_pose), label + " exact triangle count: " + node.name)
		if by_id.size() != count:
			continue
		if reference_by_id.is_empty():
			reference_by_id = by_id
		elif by_id != reference_by_id:
			reordered_poses += 1
		var ids: PackedInt32Array = triangle_ids(arrays, count)
		var stable_uv := PackedVector2Array()
		stable_uv.resize(count)
		for id: int in count:
			stable_uv[id] = uv[by_id[id]]
		if reference_ids.is_empty():
			reference_ids = ids
			reference_uv = stable_uv
		else:
			# Import can reorder the triangle list as well as vertices. Compare
			# canonical oriented triangle triples separately below.
			var expected_faces: Dictionary = {}
			for offset: int in range(0, reference_ids.size(), 3):
				expected_faces[Vector3i(reference_ids[offset], reference_ids[offset + 1], reference_ids[offset + 2])] = true
			for offset: int in range(0, ids.size(), 3):
				var a: int = ids[offset]
				var b: int = ids[offset + 1]
				var c: int = ids[offset + 2]
				check(expected_faces.has(Vector3i(a, b, c)) or expected_faces.has(Vector3i(b, c, a)) or expected_faces.has(Vector3i(c, a, b)), label + " fixed triangle corners: " + node.name)
			for id: int in count:
				check(reference_uv[id].distance_to(stable_uv[id]) < 0.001, label + " atlas UV stable: " + node.name + ":" + str(id))
		for i: int in count:
			check(vertices[i].is_finite() and normals[i].is_finite(), label + " finite vertex and normal: " + node.name)
			check(normals[i].length() > 0.9 and normals[i].length() < 1.1, label + " usable normal: " + node.name)
			minimum_y = minf(minimum_y, vertices[i].y)
			maximum_y = maxf(maximum_y, vertices[i].y)
		lod_count += Library.imported_lods(mesh, count).size()
		imported_vertices += count
		triangle_count += arrays[Mesh.ARRAY_INDEX].size() / 3
		meshes[String(node.name)] = mesh
		source_surface_bytes += packed_surface_bytes(mesh)
	check(minimum_y >= -0.001, label + " all poses floor safe including linear blends")
	var paired: Dictionary = Library.near_poses if label == "near" else Library.far_poses
	var target_max_error: float = 0.0
	for clip: String in Library.COUNTS:
		for frame: int in Library.COUNTS[clip]:
			var name: String = "%s_%02d" % [clip, frame]
			var next_name: String = "%s_%02d" % [clip, Library.next_frame(clip, frame)]
			check(meshes.has(name) and meshes.has(next_name), label + " all named frames: " + name)
			if not meshes.has(name) or not meshes.has(next_name) or not paired.has(name):
				continue
			var source_arrays: Array = meshes[name].surface_get_arrays(0)
			var next_arrays: Array = meshes[next_name].surface_get_arrays(0)
			var pair_arrays: Array = paired[name].surface_get_arrays(0)
			pair_surface_bytes += packed_surface_bytes(paired[name])
			var count: int = source_arrays[Mesh.ARRAY_VERTEX].size()
			var current_ids := Library.corner_indices(source_arrays[Mesh.ARRAY_TEX_UV2], count)
			var next_ids := Library.corner_indices(next_arrays[Mesh.ARRAY_TEX_UV2], count)
			var custom_positions: PackedFloat32Array = pair_arrays[Mesh.ARRAY_CUSTOM0]
			var custom_normals: PackedFloat32Array = pair_arrays[Mesh.ARRAY_CUSTOM1]
			check(custom_positions.size() == count * 3 and custom_normals.size() == count * 3, label + " paired target streams: " + name)
			for id: int in count:
				var offset: int = current_ids[id] * 3
				var target := Vector3(custom_positions[offset], custom_positions[offset + 1], custom_positions[offset + 2])
				var target_normal := Vector3(custom_normals[offset], custom_normals[offset + 1], custom_normals[offset + 2])
				target_max_error = maxf(target_max_error, target.distance_to(next_arrays[Mesh.ARRAY_VERTEX][next_ids[id]]))
				check(target_normal.distance_to(next_arrays[Mesh.ARRAY_NORMAL][next_ids[id]]) < 0.00001, label + " exact paired normal: " + name)
	check(target_max_error < 0.00001, label + " exact reordered next-pose positions")
	var normal_repack_error: float = test_reordered_target(meshes["walk_00"], meshes["walk_01"], paired["walk_00"], label)
	root_node.free()
	return {"poses": nodes.size(), "total_imported_vertices": imported_vertices, "total_triangles": triangle_count, "min_y_m": minimum_y, "max_y_m": maximum_y, "retained_imported_lods": lod_count, "poses_reordered_relative_to_first": reordered_poses, "paired_target_max_error_m": target_max_error, "deliberate_vertex_permutation_checked": true, "stress_test_normal_repack_max_error": normal_repack_error, "source_surface_packed_bytes": source_surface_bytes, "pair_surface_packed_bytes": pair_surface_bytes}

func _initialize() -> void:
	var start: int = Time.get_ticks_usec()
	var manifest_path: String = ProjectSettings.globalize_path("res://").path_join("../infected_manifest.json")
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(manifest_path))
	var configured: bool = Library.configure("res://assets/infected_baked_poses.glb", "res://assets/infected_baked_poses_far.glb")
	check(configured, "Recovered unmodified library configures both reconstructed LODs")
	var configure_usec: int = Time.get_ticks_usec() - start
	var report: Dictionary = {"engine_version": Engine.get_version_info(), "configured": configured, "configure_usec": configure_usec, "lods": {}}
	report.lods.near = run_lod("near", "res://assets/infected_baked_poses.glb", manifest.lods.near)
	report.lods.far = run_lod("far", "res://assets/infected_baked_poses_far.glb", manifest.lods.far)
	check(report.lods.near.get("poses", 0) == 32 and report.lods.far.get("poses", 0) == 32, "Both complete native LOD validations returned")
	check(Library.near_poses.size() == 32 and Library.far_poses.size() == 32, "64 shared pose-pair meshes created")
	check(Library.sample("attack", 0.0) == Vector3(0, 1, 0), "Attack contact starts at timestamp zero")
	check(Library.sample("attack", 0.8) == Vector3(7, 7, 0), "Attack recovery clamps at clip end")
	check(Library.sample("death", 1.2) == Vector3(9, 9, 0), "Death holds terminal frame")
	report.failures = failures
	report.passed = failures.is_empty()
	report.elapsed_usec = Time.get_ticks_usec() - start
	var output := FileAccess.open("res://godot_contract_report.json", FileAccess.WRITE)
	output.store_string(JSON.stringify(report, "\t") + "\n")
	output.close()
	print("INFECTED_CONTRACT_REPORT ", JSON.stringify(report))
	Library.near_poses.clear()
	Library.far_poses.clear()
	quit(0 if failures.is_empty() else 1)
