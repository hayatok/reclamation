extends SceneTree
const Motion = preload("res://corpse_motion.gd")
var failures: Array[String] = []
var checks: int = 0

func _initialize() -> void:
	var causes: Array[StringName] = [Motion.BALLISTIC, Motion.EXPLOSIVE, Motion.ELECTRIC, &"unknown"]
	var directions: Array[Vector3] = [Vector3.RIGHT, Vector3(1, 8, -1), Vector3.ZERO, Vector3.UP, Vector3(NAN, 0, 1), Vector3(INF, 0, 0), Vector3(1e30, 0, -1e30)]
	for cause: StringName in causes:
		for direction: Vector3 in directions:
			var at_zero: Dictionary = Motion.sample(cause, direction, 0.0)
			check(at_zero.offset == Vector3.ZERO and at_zero.rotation == Basis.IDENTITY and at_zero.clip_age == 0.0, "birth is continuous")
			var previous_age: float = -1.0
			for frame: int in 351:
				var sample: Dictionary = Motion.sample(cause, direction, float(frame) / 100.0)
				check(sample.offset.is_finite() and sample.rotation.is_finite() and is_finite(sample.clip_age), "sample stays finite")
				check(Vector2(sample.offset.x, sample.offset.z).length() <= Motion.MAX_TRAVEL + 0.00001 and sample.offset.y >= 0.0 and sample.offset.y <= Motion.MAX_LIFT + 0.00001, "travel stays bounded and above captured ground")
				check(sample.rotation.get_rotation_quaternion().get_angle() <= Motion.MAX_TILT + 0.00001, "extra rotation cannot double-topple")
				check(sample.clip_age >= previous_age and sample.clip_age <= Motion.BAKED_DURATION and sample.fall_age >= 0.0 and sample.fall_age <= Motion.PROCEDURAL_DURATION, "both clip clocks are bounded and monotonic")
				previous_age = sample.clip_age
			var settled: Dictionary = Motion.sample(cause, direction, 1.0)
			check(settled.rotation == Basis.IDENTITY and settled.offset.y == 0.0 and settled.clip_age == Motion.BAKED_DURATION, "landed by one second")
			check(Motion.sample(cause, direction, 2.5) == settled and Motion.sample(cause, direction, 3.5) == settled, "no late slide or pose change during existing fade")
		for boundary: float in [0.0, 0.045, 0.055, 0.08, 0.10, 0.15, 0.17, 0.22, 0.26, 0.43, 0.50, 0.64, 0.65, 0.90, 1.0, 2.5, 3.5]:
			var before: Dictionary = Motion.sample(cause, Vector3.RIGHT, boundary - 0.00001)
			var after: Dictionary = Motion.sample(cause, Vector3.RIGHT, boundary + 0.00001)
			# Compare basis axes directly: acos-based quaternion angles lose precision
			# at these sub-milliradian deltas with Godot's default float Vector3.
			check(before.offset.distance_to(after.offset) < 0.0001 and before.rotation.x.distance_to(after.rotation.x) < 0.0001 and before.rotation.y.distance_to(after.rotation.y) < 0.0001 and before.rotation.z.distance_to(after.rotation.z) < 0.0001 and absf(before.clip_age - after.clip_age) < 0.0001, "piecewise boundaries remain continuous")
		for invalid_age: float in [-1.0, NAN, INF, -INF]:
			check(Motion.sample(cause, Vector3.RIGHT, invalid_age) == Motion.sample(cause, Vector3.RIGHT, 0.0), "invalid age cannot poison render batches")
	var start := Transform3D(Basis.from_euler(Vector3(0, 1.3, 0)).scaled(Vector3.ONE * 2.2), Vector3(14, 0.04, -7))
	var motion: Dictionary = Motion.sample(Motion.EXPLOSIVE, Vector3.RIGHT, 0.2)
	var world: Transform3D = Motion.apply_world(start, motion)
	check(world.origin.is_equal_approx(start.origin + motion.offset), "world offset neither rotates around map origin nor scales with body")
	check(world.basis.get_scale().is_equal_approx(start.basis.get_scale()), "motion preserves root size")
	check(Motion.apply_world(start, Motion.sample(Motion.BALLISTIC, Vector3.RIGHT, 0.0)).is_equal_approx(start), "capture transform preserved exactly at death")
	check(Motion.sample(Motion.BALLISTIC, Vector3.RIGHT, 0.15).clip_age > 0.0 and Motion.sample(Motion.ELECTRIC, Vector3.RIGHT, 0.15).clip_age == 0.0, "electric held beat differs from ballistic fall")
	check(Motion.sample(Motion.EXPLOSIVE, Vector3.RIGHT, 0.4).offset.x > Motion.sample(Motion.BALLISTIC, Vector3.RIGHT, 0.4).offset.x * 2.0, "explosion has distinct outward weight")
	check(Motion.sample(Motion.ELECTRIC, Vector3.RIGHT, 0.7).offset == Vector3.ZERO, "electric collapse settles in place")
	check(Motion.sample(Motion.BALLISTIC, Vector3.RIGHT, 0.2).offset.x > 0.0 and Motion.sample(Motion.BALLISTIC, Vector3.LEFT, 0.2).offset.x < 0.0, "recoil follows impact direction")
	print("CORPSE_MOTION_SUMMARY checks=%d failures=%d" % [checks, failures.size()])
	for failure: String in failures:
		push_error(failure)
	quit(1 if not failures.is_empty() else 0)

func check(ok: bool, description: String) -> void:
	checks += 1
	if not ok and not failures.has(description):
		failures.append(description)
