extends RefCounted
## Cosmetic survivor motion only. Never changes orders, speed, cooldowns or RNG.
## Metadata is deliberately absent from unit save data and upgrade shot counters.
const ActorVisuals = preload("res://actor_visuals.gd")
const ArticulatedSurvivor = preload("res://articulated_survivor.gd")
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
	if unit.get("kind", "") not in ["guard", "grenade", "worker"]: return
	if not is_finite(dt) or dt <= 0.0: return
	var state: Dictionary = node.get_meta(META, {})
	if state.is_empty():
		state = {"phase": float(node.get_instance_id() % 17) * TAU / 17.0, "weight": 0.0, "work_phase": 0.0, "working": false}
	var offset: Vector3 = node.position - previous_position
	offset.y = 0.0
	var distance: float = offset.length()
	if not is_finite(distance) or distance > TELEPORT_DISTANCE: distance = 0.0
	var speed: float = distance / dt
	var articulated: bool = unit.get("kind", "") == "guard"
	var stride_distance: float = ArticulatedSurvivor.cycle_distance(speed) if articulated else CYCLE_DISTANCE
	var target_weight: float = smoothstep(0.18, 0.80, speed) if articulated else smoothstep(0.05, 3.2, speed)
	state.weight = move_toward(float(state.weight), target_weight, dt * (9.0 if target_weight > state.weight else 7.0))
	state.phase = fposmod(float(state.phase) + distance * TAU / stride_distance, TAU)
	if working:
		if not state.working: state.work_phase = 0.0
		state.work_phase = fposmod(float(state.work_phase) + dt * TAU / WORK_CYCLE, TAU)
	state.working = working
	node.set_meta(META, state)
	var phase: float = float(state.work_phase) if working else (float(state.phase) if state.weight > 0.001 else elapsed * 8.0 + float(node.get_instance_id() % 17))
	var attack_age: float = elapsed - float(unit.get("attack_at", -100.0))
	# There is no rifle magazine simulation. Readable recoil/recovery is driven by
	# the real shot; never invent a magazine gesture in every cooldown interval.
	ActorVisuals.pose(node, phase, state.weight > 0.001 and not working, attack_age, -1.0, working, -1.0, 1.0, float(state.weight), stride_distance)
