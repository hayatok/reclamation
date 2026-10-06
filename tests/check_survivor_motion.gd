extends SceneTree
const Motion = preload("res://survivor_motion.gd")
const Actor = preload("res://actor_visuals.gd")
const Before = preload("res://tests/actor_visuals_before.gd")
const Muzzles = preload("res://weapon_muzzles.gd")
var checks: int = 0
var failures: int = 0

func _initialize(): call_deferred("run")
func check(value: bool, message: String):
	checks += 1
	if not value: failures += 1; push_error(message)

func actor(kind: String) -> Dictionary:
	var node := Node3D.new()
	root.add_child(node)
	Actor.add_human(node, kind)
	return {"node": node, "kind": kind, "task": "idle", "hp": 100.0, "shots": 7, "cd": .51, "attack_at": -100.0}

func reset_motion(unit: Dictionary):
	unit.node.position = Vector3.ZERO
	unit.node.set_meta(Motion.META, {"phase": 0.0, "weight": 0.0, "work_phase": 0.0, "working": false})

func travel(unit: Dictionary, step: float, count: int, speed: float):
	reset_motion(unit)
	for i: int in count:
		var previous: Vector3 = unit.node.position
		unit.node.position.z -= speed * step
		Motion.update_pose(unit, previous, step, float(i + 1) * step)
	return unit.node.get_meta(Motion.META).duplicate()

func run():
	var guard := actor("guard")
	var slow: Dictionary = travel(guard, 1.0 / 30.0, 3, 2.2)
	var fast: Dictionary = travel(guard, 1.0 / 30.0, 3, 4.4)
	check(absf(float(fast.phase) - float(slow.phase) * 2.0) < .00001, "Equal time at double speed advances double gait angle")
	var fine: Dictionary = travel(guard, 1.0 / 60.0, 6, 4.4)
	check(absf(float(fast.phase) - float(fine.phase)) < .00001, "Equal distance has equal gait angle across update rates")
	var shuffle: Dictionary = travel(guard, 1.0 / 30.0, 30, .20)
	check(float(shuffle.weight) < .03, "Tiny separation motion does not cause a full stride")
	var walking: Dictionary = travel(guard, 1.0 / 30.0, 30, 4.4)
	check(float(walking.weight) > .99, "Full travel reaches readable stride")
	var stopped_phase: float = walking.phase
	for i: int in 8: Motion.update_pose(guard, guard.node.position, 1.0 / 30.0, 1.0 + float(i) / 30.0)
	var stopped: Dictionary = guard.node.get_meta(Motion.META)
	check(float(stopped.weight) == 0.0 and stopped.phase == stopped_phase, "Stopping lowers the feet without marching in place")
	var old_position: Vector3 = guard.node.position
	guard.node.position += Vector3(20, 0, 0)
	Motion.update_pose(guard, old_position, 1.0 / 30.0, 2.0)
	check(guard.node.get_meta(Motion.META).phase == stopped_phase, "Teleport does not advance locomotion")
	check(guard.shots == 7 and guard.cd == .51 and guard.task == "idle" and guard.attack_at == -100.0 and guard.hp == 100.0, "Animation does not change gameplay state or upgrade shot counter")
	var root_transform: Transform3D = guard.node.transform
	Motion.update_pose(guard, guard.node.position, 1.0 / 30.0, 2.1)
	check(guard.node.transform == root_transform, "Pose leaves authoritative actor root unchanged")
	guard.attack_at = 2.0
	Motion.update_pose(guard, guard.node.position, 1.0 / 30.0, 2.36)
	var frames: Array[Transform3D] = Actor.sample_pose("guard", 2.36 * 8.0 + float(guard.node.get_instance_id() % 17), false, .36)
	var visual: Node3D = guard.node.get_meta(&"actor_visuals")
	check(visual.get_meta(&"body").transform.is_equal_approx(frames[0]), "Ordinary rifle cooldown has no invented magazine gesture")
	var worker := actor("worker")
	worker.task = "gather"; worker["economy_phase"] = "gathering"; worker["cargo"] = 1.0
	var observation: Dictionary = Motion.capture_work(worker)
	check(not Motion.did_work(worker, observation), "An unchanged gathering label alone is not productive work")
	worker.cargo = 1.1
	check(Motion.did_work(worker, observation), "Actual cargo increase animates gathering")
	for waiting: String in ["waiting_resource", "waiting_dropoff", "to_resource", "to_dropoff"]:
		worker.economy_phase = waiting
		check(not Motion.did_work(worker, observation), waiting + " does not swing the tool")
	var target_node := Node3D.new(); root.add_child(target_node)
	var target := {"node": target_node, "built": .1, "hp": 30.0, "progress": .2}
	worker["target"] = target
	for task: String in ["build", "repair", "site"]:
		worker.task = task
		observation = Motion.capture_work(worker)
		check(not Motion.did_work(worker, observation), task + " waiting without progress stays idle")
		var field: String = observation.field
		target[field] += .01
		check(Motion.did_work(worker, observation), task + " actual progress drives work")
		worker.task = "idle"
		check(not Motion.did_work(worker, observation), task + " completion/order interruption stops the tool")
	for kind: String in ["infected", "runner", "armored"]:
		for phase: float in [0.0, 1.2, 3.4]:
			for moving: bool in [false, true]:
				var a: Array[Transform3D] = Actor.sample_pose(kind, phase, moving, .04, -1, false, .1)
				var b: Array[Transform3D] = Before.sample_pose(kind, phase, moving, .04, -1, false, .1)
				for i: int in 6: check(a[i].is_equal_approx(b[i]), "Survivor pass preserves " + kind + " pose")
	for kind: String in ["guard", "grenade"]:
		var unit := actor(kind)
		for direction: int in 8:
			unit.node.rotation.y = direction * TAU / 8.0
			for weight: float in [0.0, .1, 1.0]:
				Actor.pose(unit.node, 1.2, weight > 0.0, .04, -1, false, -1, 1, weight)
				var parts: Array[Transform3D] = Actor.sample_pose(kind, 1.2, weight > 0.0, .04, -1, false, -1, 1, weight)
				var socket: Dictionary = Muzzles.anchor(unit)
				var actual: Vector3 = Muzzles.world_position(socket, {}, Vector3.INF)
				var expected: Vector3 = unit.node.global_transform * parts[5] * Actor.muzzle_local(kind)
				check(actual.distance_to(expected) < .00001, kind + " eight-direction blended pose retains exact barrel socket")
		unit.node.free()
	guard.node.free(); worker.node.free(); target_node.free()
	print("SURVIVOR_MOTION_SUMMARY checks=", checks, " failures=", failures)
	quit(1 if failures else 0)
