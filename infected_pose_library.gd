extends RefCounted
## Shared static pose-pair meshes; no per-actor skeleton, mesh or material.
## UV2 encodes a unique corner ID, surviving import vertex reordering/compression.
const BLEND_SHADER = preload("res://infected_pose_blend.gdshader")
const COUNTS = {"idle": 2, "walk": 12, "attack": 8, "death": 10}
const DURATIONS = {"idle": 1.6, "walk": 1.2, "attack": .8, "death": 1.2}
const WALK_STRIDE_METERS: float = 1.12
# Preserve roughly half-detail imported geometry; reject silhouette-poor coarse LODs.
const MIN_IMPORTED_LOD_TRIANGLE_RATIO: float = 0.45
static var near_poses: Dictionary = {}
static var far_poses: Dictionary = {}
static var _source_paths: PackedStringArray = PackedStringArray()

static func configure(near_path: String, far_path: String) -> bool:
	var paths := PackedStringArray([near_path, far_path])
	if _source_paths == paths and not near_poses.is_empty() and not far_poses.is_empty():
		return true
	var next_near: Dictionary = _extract(near_path)
	var next_far: Dictionary = _extract(far_path)
	if next_near.is_empty() or next_far.is_empty():
		return false
	near_poses = next_near
	far_poses = next_far
	_source_paths = paths
	return true

static func _extract(path: String) -> Dictionary:
	var scene := load(path) as PackedScene
	if scene == null:
		push_error("Infected pose scene missing: " + path)
		return {}
	var source: Node = scene.instantiate()
	var raw: Dictionary = {}
	for node: MeshInstance3D in source.find_children("*", "MeshInstance3D", true, false):
		if not node.transform.is_equal_approx(Transform3D.IDENTITY):
			push_error("Infected pose must have an identity transform: " + String(node.name))
			source.free()
			return {}
		raw[String(node.name)] = node.mesh
	source.free()
	var poses: Dictionary = {}
	var materials: Dictionary = {}
	for clip: String in COUNTS:
		for frame: int in COUNTS[clip]:
			var name: String = "%s_%02d" % [clip, frame]
			var next_name: String = "%s_%02d" % [clip, next_frame(clip, frame)]
			var mesh := _pair_mesh(raw.get(name), raw.get(next_name), materials)
			if mesh == null:
				push_error("Invalid infected pose pair: " + name + " in " + path)
				return {}
			poses[name] = mesh
	return poses

## Decode grid cells, not raw UV2 floats: Godot sometimes compresses only one pose.
static func corner_indices(uv2: PackedVector2Array, vertex_count: int) -> PackedInt32Array:
	var by_id := PackedInt32Array()
	if vertex_count == 0 or uv2.size() != vertex_count:
		return by_id
	by_id.resize(vertex_count)
	by_id.fill(-1)
	var side: int = int(ceil(sqrt(float(vertex_count))))
	for vertex: int in vertex_count:
		var cell := Vector2i(floori(uv2[vertex].x * side), floori(uv2[vertex].y * side))
		var id: int = cell.y * side + cell.x
		if cell.x < 0 or cell.x >= side or cell.y < 0 or cell.y >= side or id < 0 or id >= vertex_count or by_id[id] != -1:
			return PackedInt32Array()
		by_id[id] = vertex
	return by_id

static func _pair_mesh(current: Mesh, following: Mesh, materials: Dictionary) -> ArrayMesh:
	if current == null or following == null or current.get_surface_count() != 1 or following.get_surface_count() != 1:
		return null
	var arrays: Array = current.surface_get_arrays(0)
	var next_arrays: Array = following.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var next_vertices: PackedVector3Array = next_arrays[Mesh.ARRAY_VERTEX]
	var next_normals: PackedVector3Array = next_arrays[Mesh.ARRAY_NORMAL]
	var count: int = vertices.size()
	if next_vertices.size() != count or normals.size() != count or next_normals.size() != count:
		return null
	var current_ids := corner_indices(arrays[Mesh.ARRAY_TEX_UV2], count)
	var next_ids := corner_indices(next_arrays[Mesh.ARRAY_TEX_UV2], count)
	if current_ids.size() != count or next_ids.size() != count:
		return null
	var next_positions := PackedFloat32Array()
	var next_directions := PackedFloat32Array()
	next_positions.resize(count * 3)
	next_directions.resize(count * 3)
	for id: int in count:
		var offset: int = current_ids[id] * 3
		var position: Vector3 = next_vertices[next_ids[id]]
		var normal: Vector3 = next_normals[next_ids[id]]
		next_positions[offset] = position.x
		next_positions[offset + 1] = position.y
		next_positions[offset + 2] = position.z
		next_directions[offset] = normal.x
		next_directions[offset + 1] = normal.y
		next_directions[offset + 2] = normal.z
	arrays[Mesh.ARRAY_CUSTOM0] = next_positions
	arrays[Mesh.ARRAY_CUSTOM1] = next_directions
	# The opaque atlas has no normal map; unused current-pose tangents are omitted.
	arrays[Mesh.ARRAY_TANGENT] = null
	var flags: int = (Mesh.ARRAY_CUSTOM_RGB_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT) | (Mesh.ARRAY_CUSTOM_RGB_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM1_SHIFT)
	var result := ArrayMesh.new()
	var lods: Dictionary = imported_lods(current, count)
	result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [], lods, flags)
	result.custom_aabb = current.get_aabb().merge(following.get_aabb())
	# Static shadow meshes cannot be reused: their vertices lack pose targets.
	# Imported LOD indices are safe: they address this unchanged current vertex order.
	var source_material := current.surface_get_material(0) as StandardMaterial3D
	if source_material == null:
		return null
	var material_id: int = source_material.get_instance_id()
	if not materials.has(material_id):
		var material := ShaderMaterial.new()
		material.shader = BLEND_SHADER
		material.set_shader_parameter("albedo_texture", source_material.albedo_texture)
		material.set_shader_parameter("albedo_color", source_material.albedo_color)
		material.set_shader_parameter("roughness_value", source_material.roughness)
		material.set_shader_parameter("metallic_value", source_material.metallic)
		material.set_shader_parameter("specular_value", source_material.metallic_specular)
		materials[material_id] = material
	result.surface_set_material(0, materials[material_id])
	return result

## Copy validated index-only imported LODs. Never regenerate or simplify geometry.
## Current vertex order is unchanged, so every retained index also addresses its
## corresponding UV2-paired CUSTOM0/1 target. Existing edge thresholds are retained.
static func imported_lods(current: Mesh, vertex_count: int) -> Dictionary:
	var surface: Dictionary = RenderingServer.mesh_get_surface(current.get_rid(), 0)
	var source_lods: Array = surface.get("lods", [])
	var result: Dictionary = {}
	if source_lods.is_empty():
		return result
	var base_count: int = int(surface.get("index_count", 0))
	var base_bytes: PackedByteArray = surface.get("index_data", PackedByteArray())
	if base_count <= 0 or base_bytes.size() % base_count != 0:
		push_warning("Infected imported LOD index format invalid; using base detail")
		return result
	var width: int = int(base_bytes.size() / base_count)
	if width != 2 and width != 4:
		push_warning("Infected imported LOD index width unsupported; using base detail")
		return result
	for lod: Dictionary in source_lods:
		var edge: float = float(lod.get("edge_length", 0.0))
		var bytes: PackedByteArray = lod.get("index_data", PackedByteArray())
		if not is_finite(edge) or edge <= 0.0 or bytes.is_empty() or bytes.size() % (width * 3) != 0:
			push_warning("Infected imported LOD malformed; skipping that detail level")
			continue
		var count: int = int(bytes.size() / width)
		if float(count) / base_count < MIN_IMPORTED_LOD_TRIANGLE_RATIO:
			continue
		var indices := PackedInt32Array()
		indices.resize(count)
		var valid: bool = true
		for i: int in count:
			var index: int = bytes.decode_u16(i * width) if width == 2 else bytes.decode_u32(i * width)
			if index < 0 or index >= vertex_count:
				valid = false
				break
			indices[i] = index
		if valid:
			result[edge] = indices
		else:
			push_warning("Infected imported LOD index outside paired vertices; skipping that detail level")
	return result

static func next_frame(clip: String, frame: int) -> int:
	var count: int = COUNTS.get(clip, 2)
	return (frame + 1) % count if clip in ["idle", "walk"] else mini(frame + 1, count - 1)

## x=current frame, y=next frame, z=interpolation weight. One-shots never wrap.
static func sample(clip: String, elapsed: float, phase: float = 0.0) -> Vector3:
	var count: int = COUNTS.get(clip, 2)
	var duration: float = DURATIONS.get(clip, 1.6)
	var normalized: float = maxf(elapsed, 0.0) / duration
	var cursor: float
	if clip in ["idle", "walk"]:
		cursor = fposmod(normalized + phase, 1.0) * count
	else:
		cursor = clampf(normalized, 0.0, 1.0) * (count - 1)
	var frame: int = mini(floori(cursor), count - 1)
	return Vector3(frame, next_frame(clip, frame), cursor - frame)

## Retain the old discrete-query API for other callers. The crowd uses sample().
static func frame_index(clip: String, elapsed: float, phase: float = 0.0) -> int:
	var result := sample(clip, elapsed, phase)
	return int(result.x) if clip in ["idle", "walk"] else mini(roundi(result.x + result.z), int(COUNTS.get(clip, 2)) - 1)

static func mesh_for(clip: String, frame: int, far_lod: bool = false) -> Mesh:
	var poses: Dictionary = far_poses if far_lod else near_poses
	return poses.get("%s_%02d" % [clip, frame])
