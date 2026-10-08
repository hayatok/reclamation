extends RefCounted
## Cosmetic survivor motion only. Never changes orders, speed, cooldowns or RNG.
## Metadata is deliberately absent from unit save data and upgrade shot counters.
const ActorVisuals = preload("res://actor_visuals.gd")
const ArticulatedSurvivor = preload("res://articulated_survivor.gd")
const ArticulatedGrenadier = preload("res://articulated_grenadier.gd")
const META: StringName = &"survivor_motion"
const CYCLE_DISTANCE: float = 2.20
const TELEPORT_DISTANCE: float = 1.0
const WORK_CYCLE: float = 1.10

## Capture immediately before this unit's worker/economy update. Comparing actual
## progress avoids swinging while a resource, repair supply or site payment waits.
static func capture_work(unit: Dictionary) -> Dictionary:
	if unit.get("kind", "") != "worker": return {}
	var task: String = str(unit.get("task", "idle"))
	if task == "gather":
		return {"task": task, "value": float(unit.get("cargo", 0.0))}
	if task not in ["build", "repair", "site"]: return {}
	var target: Variant = unit.get("target")
	if not target is Dictionary or not is_instance_valid(target.get("node")): return {}
	var field: String = "built" if task == "build" else ("hp" if task == "repair" else "progress")
	return {"task": task, "target": target.node, "field": field, "value": float(target.get(field, 0.0))}

static func did_work(unit: Dictionary, observation: Dictionary) -> bool:
	if observation.is_empty() or unit.get("task", "idle") != observation.task: return false
	if observation.task == "gather":
		return unit.get("economy_phase", "") == "gathering" and float(unit.get("cargo", 0.0)) > observation.value
	var target: Variant = unit.get("target")
	return target is Dictionary and is_instance_valid(target.get("node")) and target.node == observation.target and float(target.get(observation.field, 0.0)) > observation.value

## Feed after navigation and fire, before interpolation captures this tick's pose.
## Actual planar displacement drives cadence. Slow separation steps have a small
## stride, and a stopped unit eases its feet down without continuing to march.
static func update_pose(unit: Dictionary, previous_position: Vector3, dt: float, elapsed: float, working: bool = false) -> void:
	var node: Variant = unit.get("node")
	if not is_instance_valid(node) or not node is Node3D: return
	if unit.get("kind", "") not in ["guard", "grenade", "grenadier", "worker"]: return
	if not is_finite(dt) or dt <= 0.0: return
	var state: Dictionary = node.get_meta(META, {})
	if state.is_empty(): state = _initial_state(node)
	state.phase = fposmod(_finite_number(state.get("phase", 0.0), 0.0), TAU)
	state.weight = clampf(_finite_number(state.get("weight", 0.0), 0.0), 0.0, 1.0)
	state.work_phase = fposmod(_finite_number(state.get("work_phase", 0.0), 0.0), TAU)
	state.working = bool(state.get("working", false))
	elapsed = elapsed if is_finite(elapsed) else 0.0
	var offset: Vector3 = node.position - previous_position
	offset.y = 0.0
	var distance: float = offset.length()
	if not is_finite(distance) or distance > TELEPORT_DISTANCE: distance = 0.0
	var speed: float = distance / dt
	if not is_finite(speed): speed = 0.0
	var worker: bool = unit.get("kind", "") == "worker"
	var articulated: bool = unit.get("kind", "") in ["guard", "grenade", "grenadier", "worker"]
	var stride_distance: float = ArticulatedSurvivor.cycle_distance(speed) if articulated else CYCLE_DISTANCE
	if unit.get("kind", "") in ["grenade", "grenadier"]:
		stride_distance = ArticulatedGrenadier.cycle_distance(speed)
	var target_weight: float = smoothstep(0.18, 0.80, speed) if articulated else smoothstep(0.05, 3.2, speed)
	state.weight = move_toward(float(state.weight), target_weight, dt * (9.0 if target_weight > state.weight else 7.0))
	state.phase = fposmod(float(state.phase) + distance * TAU / stride_distance, TAU)
	if worker: working = working and str(unit.get("task", "idle")) in ["gather", "build", "repair", "site"]
	if working:
		if not state.working: state.work_phase = 0.0
		state.work_phase = fposmod(float(state.work_phase) + fposmod(dt, WORK_CYCLE) * TAU / WORK_CYCLE, TAU)
	state.working = working
	var phase: float = float(state.work_phase) if working else (float(state.phase) if state.weight > 0.001 else elapsed * 8.0 + float(node.get_instance_id() % 17))
	var attack_age: float = elapsed - _finite_number(unit.get("attack_at", -100.0), -100.0)
	if not is_finite(phase): phase = 0.0
	if not is_finite(attack_age): attack_age = -1.0
	state.pose_phase = phase
	state.attack_age = attack_age
	state.stride_distance = stride_distance
	var worker_state: Dictionary = _worker_presentation(unit, working) if worker else {}
	if worker:
		state.worker_state = worker_state
		state.work_context = _work_context(unit) if working else {}
		state.presentation_revision = int(state.get("presentation_revision", 0)) + 1
	node.set_meta(META, state)
	# There is no rifle or launcher magazine simulation. Readable recoil/recovery is driven by
	# the real shot; never invent a magazine gesture in every cooldown interval.
	ActorVisuals.pose(node, phase, state.weight > 0.001 and not working, attack_age, -1.0, working, -1.0, 1.0, float(state.weight), stride_distance, worker_state)

## Load, Stop and reassignment can happen while no simulation tick is running.
## Observe only presentation inputs, and repose only when those inputs change.
## No clock, authoritative transform, or unit dictionary field is advanced here.
static func sync_worker_presentation(unit: Dictionary) -> bool:
	if unit.get("kind", "") != "worker": return false
	var node: Variant = unit.get("node")
	if not is_instance_valid(node) or not node is Node3D or not node.has_meta(&"actor_visuals"): return false
	var state: Dictionary = node.get_meta(META, {})
	if state.is_empty(): state = _initial_state(node)
	var working: bool = bool(state.get("working", false))
	# A previous productive observation belongs to one task and target only.
	# Merely retaining the same 'gather' label after a new order is insufficient.
	if working and state.get("work_context", {}) != _work_context(unit):
		working = false
		state.working = false
		state.work_context = {}
		state.pose_phase = _finite_number(state.get("phase", 0.0), 0.0)
	var worker_state: Dictionary = _worker_presentation(unit, working)
	if state.get("worker_state", {}) == worker_state:
		return false
	state.worker_state = worker_state
	state.presentation_revision = int(state.get("presentation_revision", 0)) + 1
	node.set_meta(META, state)
	var weight: float = clampf(_finite_number(state.get("weight", 0.0), 0.0), 0.0, 1.0)
	ActorVisuals.pose(node, _finite_number(state.get("pose_phase", 0.0), 0.0), weight > 0.001 and not working, _finite_number(state.get("attack_age", -1.0), -1.0), -1.0, working, -1.0, 1.0, weight, _finite_number(state.get("stride_distance", CYCLE_DISTANCE), CYCLE_DISTANCE), worker_state)
	return true

## A direct batch draw may synchronize before interpolation gets its next frame.
## Keep that change observable even after the presentation cache is up to date.
static func worker_presentation_revision(unit: Dictionary) -> int:
	if unit.get("kind", "") != "worker": return 0
	var node: Variant = unit.get("node")
	if not is_instance_valid(node): return 0
	var state: Dictionary = node.get_meta(META, {})
	return int(state.get("presentation_revision", 0))

static func _initial_state(node: Node3D) -> Dictionary:
	return {"phase": float(node.get_instance_id() % 17) * TAU / 17.0, "weight": 0.0, "work_phase": 0.0, "working": false, "pose_phase": 0.0, "attack_age": -1.0, "stride_distance": CYCLE_DISTANCE}

static func _finite_number(value: Variant, fallback: float) -> float:
	if not value is float and not value is int: return fallback
	var number: float = float(value)
	return number if is_finite(number) else fallback

static func _worker_presentation(unit: Dictionary, working: bool) -> Dictionary:
	var task: String = str(unit.get("task", "idle"))
	var activity: String = "none"
	if working:
		if task == "gather": activity = "gather"
		elif task in ["build", "repair", "site"]: activity = "construct"
	var cargo: float = _finite_number(unit.get("cargo", 0.0), 0.0)
	var result: Dictionary = {"activity": activity, "carrying": cargo > 0.0, "cargo_kind": str(unit.get("cargo_kind", "")), "work_direction": Vector3.ZERO}
	if activity == "none": return result
	var target: Node3D = _work_target(unit)
	var actor: Node3D = unit.node
	if not is_instance_valid(target) or not actor.global_transform.is_finite() or not target.global_transform.is_finite(): return result
	if absf(actor.global_basis.determinant()) < 0.000001: return result
	var direction: Vector3 = actor.global_basis.inverse() * (target.global_position - actor.global_position)
	direction.y = 0.0
	if direction.is_finite() and direction.length_squared() > 0.000001:
		result.work_direction = direction.normalized()
	return result

static func _work_target(unit: Dictionary) -> Node3D:
	if str(unit.get("task", "idle")) == "gather":
		var resource: Node3D = _target_node(unit.get("resource_target"))
		if is_instance_valid(resource): return resource
	return _target_node(unit.get("target"))

static func _target_node(target: Variant) -> Node3D:
	if not target is Dictionary: return null
	var node: Variant = target.get("node")
	return node if is_instance_valid(node) and node is Node3D and not node.is_queued_for_deletion() else null

static func _target_id(target: Variant) -> int:
	var node: Node3D = _target_node(target)
	return node.get_instance_id() if is_instance_valid(node) else 0

static func _work_context(unit: Dictionary) -> Dictionary:
	var task: String = str(unit.get("task", "idle"))
	if task not in ["gather", "build", "repair", "site"]: return {}
	var result: Dictionary = {"task": task, "target": _target_id(unit.get("target"))}
	if task == "gather":
		result.resource_target = _target_id(unit.get("resource_target"))
		result.economy_phase = str(unit.get("economy_phase", ""))
		result.resource_kind = str(unit.get("resource_kind", ""))
	return result
