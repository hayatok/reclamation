extends RefCounted
## Original demolition boss. Shared paired meshes, never per-actor skeletons.
const SharedPairing = preload("res://infected_pose_library.gd")
const COUNTS = {"idle": 2, "walk": 12, "windup": 12, "recovery": 8, "death": 10}
const DURATIONS = {"idle": 1.8, "walk": 1.0, "windup": 1.4, "recovery": .9, "death": 1.2}
const WALK_STRIDE_METERS: float = .54
const IDLE_HEIGHT_METERS: float = 1.624
const NEAR_PATH: String = "res://assets/models/demolition_boss_near.glb"
const FAR_PATH: String = "res://assets/models/demolition_boss_far.glb"
static var near_poses: Dictionary = {}
static var far_poses: Dictionary = {}

static func configure() -> bool:
	if not near_poses.is_empty() and not far_poses.is_empty():
		return true
	var next_near: Dictionary = _extract(NEAR_PATH)
	var next_far: Dictionary = _extract(FAR_PATH)
	if next_near.is_empty() or next_far.is_empty():
		# Publish neither half of a failed asset load. The caller retains legacy art.
		return false
	near_poses = next_near
	far_poses = next_far
	return true

static func _extract(path: String) -> Dictionary:
	if not ResourceLoader.exists(path):
		push_warning("Boss pose scene missing; retaining legacy model: " + path)
		return {}
	var scene := load(path) as PackedScene
	if scene == null:
		push_warning("Boss pose scene invalid; retaining legacy model: " + path)
		return {}
	var source: Node = scene.instantiate()
	var raw: Dictionary = {}
	for node: MeshInstance3D in source.find_children("*", "MeshInstance3D", true, false):
		var pose_name: String = String(node.name)
		if raw.has(pose_name) or not _identity_chain(node, source) or not _valid_mesh(node.mesh):
			push_warning("Invalid boss pose source: " + pose_name + " in " + path)
			source.free()
			return {}
		raw[pose_name] = node.mesh
	source.free()
	if raw.size() != 44:
		push_warning("Boss library must contain exactly 44 poses: " + path)
		return {}
	var poses: Dictionary = {}
	var materials: Dictionary = {}
	for clip: String in COUNTS:
		for frame: int in COUNTS[clip]:
			var pose_name: String = "%s_%02d" % [clip, frame]
			var following_name: String = "%s_%02d" % [clip, next_frame(clip, frame)]
			var mesh := SharedPairing._pair_mesh(raw.get(pose_name), raw.get(following_name), materials)
			if mesh == null:
				push_warning("Invalid boss pose pair: " + pose_name + " in " + path)
				return {}
			poses[pose_name] = mesh
	return poses

static func _identity_chain(node: Node, root: Node) -> bool:
	var current: Node = node
	while current != null:
		if current is Node3D and not current.transform.is_equal_approx(Transform3D.IDENTITY):
			return false
		if current == root:
			return true
		current = current.get_parent()
	return false

## Reject missing arrays before entering the shared typed UV2 pairing routine.
static func _valid_mesh(mesh: Mesh) -> bool:
	if mesh == null or mesh.get_surface_count() != 1:
		return false
	var arrays: Array = mesh.surface_get_arrays(0)
	if not arrays[Mesh.ARRAY_VERTEX] is PackedVector3Array or not arrays[Mesh.ARRAY_NORMAL] is PackedVector3Array or not arrays[Mesh.ARRAY_TEX_UV2] is PackedVector2Array:
		return false
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var uv2: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV2]
	if vertices.is_empty() or vertices.size() != normals.size() or vertices.size() != uv2.size():
		return false
	for index: int in vertices.size():
		if not vertices[index].is_finite() or not normals[index].is_finite() or not uv2[index].is_finite():
			return false
	var material := mesh.surface_get_material(0) as StandardMaterial3D
	return material != null and material.transparency == BaseMaterial3D.TRANSPARENCY_DISABLED

static func next_frame(clip: String, frame: int) -> int:
	var count: int = COUNTS.get(clip, 2)
	return (frame + 1) % count if clip in ["idle", "walk"] else mini(frame + 1, count - 1)

## x=current, y=following, z=GPU interpolation. One-shots hold their last pose.
static func sample(clip: String, elapsed: float, phase: float = 0.0) -> Vector3:
	var count: int = COUNTS.get(clip, 2)
	var duration: float = DURATIONS.get(clip, 1.8)
	var safe_age: float = maxf(elapsed, 0.0) if is_finite(elapsed) else 0.0
	var safe_phase: float = phase if is_finite(phase) else 0.0
	var cursor: float
	if clip in ["idle", "walk"]:
		cursor = fposmod(safe_age / duration + safe_phase, 1.0) * count
	else:
		cursor = clampf(safe_age / duration, 0.0, 1.0) * (count - 1)
	var frame: int = mini(floori(cursor), count - 1)
	return Vector3(frame, next_frame(clip, frame), cursor - frame)

static func mesh_for(clip: String, frame: int, far_lod: bool = false) -> Mesh:
	var poses: Dictionary = far_poses if far_lod else near_poses
	return poses.get("%s_%02d" % [clip, frame])
