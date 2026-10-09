extends RefCounted
## Original ordinary-armored poses; shared once per LOD, with no per-actor skeleton.
## UV2-safe pose pairing and shader reuse the normal-infected importer.
const SharedPairing = preload("res://infected_pose_library.gd")
const COUNTS = {"idle": 2, "walk": 12, "attack": 8, "death": 10}
const DURATIONS = {"idle": 1.8, "walk": 1.0, "attack": .9, "death": 1.2}
const WALK_STRIDE_METERS: float = 1.20
static var near_poses: Dictionary = {}
static var far_poses: Dictionary = {}

static func configure() -> bool:
	if not near_poses.is_empty() and not far_poses.is_empty():
		return true
	var next_near: Dictionary = _extract("res://assets/models/armored_baked_poses.glb")
	var next_far: Dictionary = _extract("res://assets/models/armored_baked_poses_far.glb")
	if next_near.is_empty() or next_far.is_empty():
		return false
	near_poses = next_near
	far_poses = next_far
	return true

static func _extract(path: String) -> Dictionary:
	var scene := load(path) as PackedScene
	if scene == null:
		push_error("Armored pose scene missing: " + path)
		return {}
	var source: Node = scene.instantiate()
	var raw: Dictionary = {}
	for node: MeshInstance3D in source.find_children("*", "MeshInstance3D", true, false):
		if not node.transform.is_equal_approx(Transform3D.IDENTITY):
			push_error("Armored pose must have an identity transform: " + String(node.name))
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
			var mesh := SharedPairing._pair_mesh(raw.get(name), raw.get(next_name), materials)
			if mesh == null:
				push_error("Invalid armored pose pair: " + name + " in " + path)
				return {}
			poses[name] = mesh
	return poses

static func next_frame(clip: String, frame: int) -> int:
	var count: int = COUNTS.get(clip, 2)
	return (frame + 1) % count if clip in ["idle", "walk"] else mini(frame + 1, count - 1)

## x=current frame, y=next frame, z=interpolation weight. One-shots never wrap.
static func sample(clip: String, elapsed: float, phase: float = 0.0) -> Vector3:
	var count: int = COUNTS.get(clip, 2)
	var duration: float = DURATIONS.get(clip, 1.8)
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
