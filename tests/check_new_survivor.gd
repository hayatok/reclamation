extends SceneTree
const S = preload("res://articulated_survivor.gd")
const A = preload("res://actor_visuals.gd")
const M = preload("res://survivor_motion.gd")
var failures: Array[String] = []
var checks := 0

func _initialize() -> void:
	call_deferred("run")

func verify(condition: bool, description: String) -> void:
	checks += 1
	if not condition: failures.append(description)

func close(a: Vector3, b: Vector3, tolerance: float = 0.0001) -> bool:
	return a.distance_to(b) < tolerance

func run() -> void:
	verify(S.PARTS.size() == 14, "Exactly fourteen parts")
	var vertices := 0
	for part: String in S.PARTS:
		var mesh: ArrayMesh = S.mesh_for(part)
		verify(mesh == S.mesh_for(part), part + " mesh is cached")
		verify(mesh.get_surface_count() == 1, part + " has one surface")
		var arrays: Array = mesh.surface_get_arrays(0)
		vertices += arrays[Mesh.ARRAY_VERTEX].size()
		verify(arrays[Mesh.ARRAY_VERTEX].size() > 0, part + " has geometry")
		for color: Color in arrays[Mesh.ARRAY_COLOR]:
			verify(is_finite(color.r) and is_finite(color.g) and is_finite(color.b), "Finite vertex color")
	var jacket_vertex: Color = S.mesh_for("torso").surface_get_arrays(0)[Mesh.ARRAY_COLOR][0]
	var expected_jacket: Color = S.JACKET.srgb_to_linear()
	verify(absf(jacket_vertex.r - expected_jacket.r) < 0.005 and absf(jacket_vertex.g - expected_jacket.g) < 0.005 and absf(jacket_vertex.b - expected_jacket.b) < 0.005, "Vertex colors are explicitly linearized (allow packed-color quantization)")
	var weapon_vertices: PackedVector3Array = S.mesh_for("weapon").surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var front_z := 100.0
	for vertex: Vector3 in weapon_vertices: front_z = minf(front_z, vertex.z)
	var front_min := Vector3(INF, INF, INF)
	var front_max := Vector3(-INF, -INF, -INF)
	for vertex: Vector3 in weapon_vertices:
		if absf(vertex.z - front_z) < 0.00001:
			front_min = front_min.min(vertex)
			front_max = front_max.max(vertex)
	verify(close((front_min + front_max) * 0.5, S.MUZZLE), "Muzzle equals actual barrel front-plane center")
	var max_joint_error := 0.0
	var max_grip_error := 0.0
	var min_sole_height := 100.0
	for speed: float in [0.0, 0.15, 1.2, 2.4, 3.2, 4.4]:
		var stride: float = S.cycle_distance(speed)
		for tick: int in 120:
			var phase: float = float(tick) / 120.0 * TAU
			for attack: float in [-1.0, 0.0, 0.07, 0.35]:
				var frames: Array[Transform3D] = S.sample_pose(phase, speed > 0.0, attack, -1.0, -1.0, 1.0, 1.0, stride)
				verify(frames.size() == 14, "Pose has fourteen transforms")
				for frame: Transform3D in frames:
					verify(frame.origin.is_finite() and frame.basis.is_finite(), "Finite pose")
					verify(absf(frame.basis.determinant() - 1.0) < 0.0001, "Rigid limb transform")
				for side: int in 2:
					var knee: Vector3 = frames[3 + side] * Vector3(0, -S.THIGH_LENGTH, 0)
					var ankle: Vector3 = frames[5 + side] * Vector3(0, -S.SHIN_LENGTH, 0)
					max_joint_error = maxf(max_joint_error, knee.distance_to(frames[5 + side].origin))
					max_joint_error = maxf(max_joint_error, ankle.distance_to(frames[7 + side].origin))
					var elbow: Vector3 = frames[9 + side] * Vector3(0, -S.UPPER_ARM_LENGTH, 0)
					max_joint_error = maxf(max_joint_error, elbow.distance_to(frames[11 + side].origin))
					var hand: Vector3 = frames[11 + side] * Vector3(0, -S.FOREARM_LENGTH, 0)
					var grip: Vector3 = frames[13] * (S.LEFT_GRIP if side == 0 else S.RIGHT_GRIP)
					max_grip_error = maxf(max_grip_error, hand.distance_to(grip))
					var foot_vertices: PackedVector3Array = S.mesh_for("footL").surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
					for vertex: Vector3 in foot_vertices:
						min_sole_height = minf(min_sole_height, (frames[7 + side] * vertex).y)
				verify(close(frames[13].origin, frames[1] * Vector3(0.168,0.335,-0.005)), "Stock stays on shoulder")
	verify(max_joint_error < 0.0001, "Joint continuity error < 0.1 mm: " + str(max_joint_error))
	verify(max_grip_error < 0.0001, "Both hands on grips < 0.1 mm: " + str(max_grip_error))
	verify(min_sole_height > -0.0001, "No sole below ground: " + str(min_sole_height))
	for speed: float in [1.2, 4.4]:
		var stride: float = S.cycle_distance(speed)
		var cycles_per_second: float = speed / stride
		verify(cycles_per_second > 0.7 and cycles_per_second <= 2.01, "Plausible cadence " + str(speed))
		for cycle: float in [0.03,0.1,0.2,0.3]:
			var first: Dictionary = S.foot_sample(cycle, stride)
			var second: Dictionary = S.foot_sample(cycle + 0.001, stride)
			verify(absf(float(second.z) - float(first.z) - stride * 0.001) < 0.00001, "Stance cancels actual root travel")
	var neutral: Array[Transform3D] = S.sample_pose(0.2, false)
	var expired: Array[Transform3D] = S.sample_pose(0.2, false, 0.5)
	var active: Array[Transform3D] = S.sample_pose(0.2, false, 0.0)
	verify(neutral == expired, "No recoil without a current attack timestamp")
	verify(neutral[13] != active[13], "Actual attack timestamp triggers recoil")
	verify(S.sample_pose(NAN, true, NAN, NAN, NAN, NAN, NAN, NAN)[13].origin.is_finite(), "Nonfinite inputs cannot corrupt pose")
	var actor := Node3D.new()
	root.add_child(actor)
	actor.position = Vector3(4.0, 0.0, 2.0)
	A.add_human(actor, "guard")
	verify(A.part_nodes(actor.get_meta("actor_visuals")).size() == 14, "Adapter adds fourteen live nodes")
	var before := actor.transform
	A.pose(actor, 0.3, true, 0.0)
	verify(actor.transform == before, "Adapter never changes actor root")
	var unit := {"node": actor, "kind": "guard", "attack_at": 9.95}
	actor.set_meta(M.META, {"phase": 0.0, "weight": 1.0, "work_phase": 0.0, "working": false})
	M.update_pose(unit, actor.position + Vector3(0,0,0.12), 0.1, 10.0)
	verify(absf(float(actor.get_meta(M.META).phase) - 0.12 * TAU / S.cycle_distance(1.2)) < 0.00001, "Guard phase tracks observed distance")
	verify(actor.transform == before, "Motion helper never changes actor root")
	verify(unit.size() == 3, "Motion helper never adds gameplay state")
	actor.free()
	print("NEW SURVIVOR RECONSTRUCTION: ", checks, " checks; vertices=", vertices, "; max_joint_error=", max_joint_error, "; max_grip_error=", max_grip_error, "; min_sole_y=", min_sole_height)
	for failure: String in failures: printerr(failure)
	print("PASS" if failures.is_empty() else "FAIL")
	quit(0 if failures.is_empty() else 1)
