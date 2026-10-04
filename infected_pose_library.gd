extends RefCounted
## Static, shared meshes only. No Skeleton3D, AnimationPlayer or actor node is created.
## Call configure once at startup with the destination's two GLB resource paths.
static var near_poses: Dictionary = {}
static var far_poses: Dictionary = {}
const COUNTS = {"idle": 2, "walk": 12, "attack": 8, "death": 10}
const DURATIONS = {"idle": 1.6, "walk": 1.2, "attack": .8, "death": 1.2}
static func configure(near_path: String, far_path: String) -> void:
	if not near_poses.is_empty(): return
	_extract(near_path, near_poses)
	_extract(far_path, far_poses)
static func _extract(path: String, into: Dictionary) -> void:
	var source: Node = (load(path) as PackedScene).instantiate()
	for node: MeshInstance3D in source.find_children("*", "MeshInstance3D", true, false):
		into[String(node.name)] = node.mesh
	source.free()
static func frame_index(clip: String, elapsed: float, phase: float = 0.0) -> int:
	var count: int = COUNTS.get(clip, 2)
	var duration: float = DURATIONS.get(clip, 1.6)
	var normalized: float = maxf(elapsed, 0.0) / duration
	if clip in ["idle", "walk"]:
		return int(floor(fposmod(normalized + phase, 1.0) * count)) % count
	return clampi(int(round(clampf(normalized, 0.0, 1.0) * (count - 1))), 0, count - 1)
static func mesh_for(clip: String, frame: int, far_lod: bool = false) -> Mesh:
	var poses := far_poses if far_lod else near_poses
	return poses.get("%s_%02d" % [clip, frame])
