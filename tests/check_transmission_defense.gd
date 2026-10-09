extends SceneTree
const Defense = preload("../transmission_defense.gd")
var failures: int = 0
var checks: int = 0

func _initialize() -> void:
	_check_planning_and_dispatch()
	_check_warning_countdown()
	_check_zone_occupancy()
	_check_persistence()
	if failures == 0: print("TRANSMISSION_DEFENSE_CONTROLLER_PASS checks=%d" % checks)
	else: push_error("TRANSMISSION_DEFENSE_CONTROLLER_FAIL failures=%d checks=%d" % [failures, checks])
	quit(0 if failures == 0 else 1)

func check(condition: bool, description: String) -> void:
	checks += 1
	if condition: return
	failures += 1
	push_error(description)

func _check_planning_and_dispatch() -> void:
	var defense = Defense.new()
	var inactive: Dictionary = defense.snapshot()
	check(not defense.activate_wave(1), "Inactive controller must not dispatch")
	check(not defense.plan_if_ready(false, 1, 30.0, 0), "Readiness gates planning")
	for time_left in [-1.0, 0.0, 11.999, INF, -INF, NAN]:
		check(not defense.plan_if_ready(true, 1, time_left, 0), "Too little/nonfinite warning must not plan")
	for number in [-1, 0, Defense.MAX_TARGET_WAVE + 1]:
		check(not defense.plan_if_ready(true, number, 20.0, 0), "Invalid wave cannot be planned")
	for side in [-1, 3]:
		check(not defense.plan_if_ready(true, 1, 20.0, side), "Unknown side cannot be planned")
	check(defense.snapshot() == inactive, "Rejected planning must not mutate state")
	check(defense.plan_if_ready(true, 2, 12.0, 0), "Exactly twelve seconds is enough; later ordinary wave may be selected")
	check(defense.target_kind == "pump" and defense.target_wave == 2, "West targets pump")
	var planned: Dictionary = defense.snapshot()
	check(not defense.plan_if_ready(true, 3, 30.0, 2), "Only one wave may be planned")
	check(not defense.activate_wave(1) and not defense.activate_wave(3), "Only matching scheduled wave dispatches")
	check(defense.snapshot() == planned, "Wrong-wave calls must not mutate a plan")
	check(defense.activate_wave(2), "Matching wave dispatches")
	check(not defense.activate_wave(2), "Matching wave dispatch is one-shot")
	check(not defense.plan_if_ready(true, 4, 30.0, 2), "Dispatch cannot plan another wave")
	for side in [0, 1, 2]:
		defense.reset()
		check(defense.snapshot() == inactive, "Reset starts a fresh mission")
		check(defense.plan_if_ready(true, 7, 30.0, side), "Every existing primary side is valid")
		check(defense.target_kind == ("substation" if side == 2 else "pump"), "Target selection is deterministic by primary side")

func _check_zone_occupancy() -> void:
	var defense = Defense.new()
	var target := Vector3(20.0, 0.0, 30.0)
	var actor := Node3D.new()
	actor.position = target
	var enemy: Dictionary = {"node": actor, "hp": 10.0, "dead": false}
	check(not defense.is_blocked([enemy], target), "Inactive state ignores occupancy")
	defense.plan_if_ready(true, 1, 12.0, 0)
	check(not defense.is_blocked([enemy], target), "Warning alone cannot block transmission")
	defense.activate_wave(1)
	check(defense.is_blocked([enemy], target), "Living enemy at objective blocks")
	actor.position = target + Vector3(3.0, 40.0, 4.0)
	check(defense.is_blocked([enemy], target), "Five-meter ground-plane boundary blocks, regardless of elevation")
	actor.position = target + Vector3(5.001, 0.0, 0.0)
	check(not defense.is_blocked([enemy], target), "Enemy beyond five meters cannot stall transmission")
	actor.position = target
	enemy.dead = true
	check(not defense.is_blocked([enemy], target), "Dead enemy cannot block")
	enemy.dead = false
	for health in [0.0, -1.0, NAN, INF, -INF, true, "10", null]:
		enemy.hp = health
		check(not defense.is_blocked([enemy], target), "Only finite positive numeric health counts as living")
	enemy.hp = 10.0
	check(defense.is_blocked([enemy], target), "Living untagged enemies also count; no friendly garrison needed")
	check(not defense.is_blocked([], target), "Cleared zone immediately unblocks")
	check(not defense.is_blocked([enemy], Vector3(NAN, 0, 0)), "Invalid target cannot block")
	actor.position = Vector3(INF, 0, 0)
	check(not defense.is_blocked([enemy], target), "Invalid actor position cannot block")
	actor.position = target
	enemy.dead = "false"
	check(not defense.is_blocked([enemy], target), "Malformed dead flag is ignored")
	var wrong_node := Node.new()
	check(not defense.is_blocked([null, 2, {}, {"hp": 10, "node": wrong_node}], target), "Malformed records and nonspatial nodes are ignored")
	wrong_node.free()
	enemy.dead = false
	actor.free()
	check(not defense.is_blocked([enemy], target), "Freed enemy node cannot block")

func _check_warning_countdown() -> void:
	var defense = Defense.new()
	defense.advance_warning(1.0)
	check(defense.warning_remaining == 0.0, "Inactive countdown stays zero")
	defense.plan_if_ready(true, 2, 30.0, 0)
	check(defense.warning_remaining == 12.0, "Planning guarantees twelve seconds of warning, regardless of original wave countdown")
	var planned: Dictionary = defense.snapshot()
	for dt in [-1.0, NAN, INF, -INF, 0.0]:
		defense.advance_warning(dt)
		check(defense.snapshot() == planned, "Negative/nonfinite/zero delta must not change warning")
	defense.advance_warning(0.25)
	check(defense.warning_remaining == 11.75, "Pending warning advances with simulation time")
	var resumed = Defense.new()
	check(resumed.restore(JSON.parse_string(JSON.stringify(defense.snapshot()))), "Fractional pending warning restores through JSON")
	check(resumed.warning_remaining == 11.75, "Reload preserves already elapsed warning")
	resumed.advance_warning(7.75)
	check(resumed.warning_remaining == 4.0, "Only actual simulation time consumes warning")
	resumed.advance_warning(10.0)
	check(resumed.warning_remaining == 0.0, "Warning clamps at zero without dispatching")
	check(resumed.planned and not resumed.dispatched, "Warning expiry does not own ordinary wave dispatch")
	check(defense.activate_wave(2), "Host still owns matching wave dispatch")
	check(defense.warning_remaining == 0.0, "Dispatch clears the pending warning")
	var dispatched: Dictionary = defense.snapshot()
	defense.advance_warning(4.0)
	check(defense.snapshot() == dispatched, "Dispatched state no longer advances warning")
	defense.reset()
	check(defense.warning_remaining == 0.0, "Reset clears warning")
	# The host's boss event may accelerate a future wave, but cannot cut its
	# announced twelve-second minimum or push it past the original deadline.
	for original_deadline in [12.0, 18.0, 30.0]:
		defense.reset()
		defense.plan_if_ready(true, 3, original_deadline, 2)
		var elapsed: float = 0.0
		var wave_clock: float = original_deadline
		while wave_clock > 0.0:
			defense.advance_warning(0.25)
			wave_clock -= 0.25
			elapsed += 0.25
			if elapsed == 1.0:
				wave_clock = minf(wave_clock, maxf(4.0, defense.warning_remaining))
		check(elapsed >= 12.0, "Boss acceleration must retain twelve seconds of announcement")
		check(elapsed <= original_deadline, "Warning protection must never delay the original wave")

func _check_persistence() -> void:
	var defense = Defense.new()
	var inactive: Dictionary = defense.snapshot()
	defense.plan_if_ready(true, 9, 12.0, 2)
	var planned: Dictionary = defense.snapshot()
	defense.activate_wave(9)
	var dispatched: Dictionary = defense.snapshot()
	for expected in [inactive, planned, dispatched]:
		var restored = Defense.new()
		check(Defense.validate_snapshot(expected), "All legitimate lifecycle states validate")
		check(restored.restore(expected), "All legitimate lifecycle states restore")
		check(restored.snapshot() == expected, "Restore must preserve exact state")
		var decoded: Variant = JSON.parse_string(JSON.stringify(expected))
		check(restored.restore(decoded), "Snapshot must survive JSON numeric decoding")
		check(restored.snapshot() == expected, "JSON restore must preserve semantic state")
	var resumed = Defense.new()
	resumed.restore(planned)
	check(resumed.activate_wave(9) and not resumed.activate_wave(9), "Planned reload dispatches exactly once")
	resumed.restore(dispatched)
	check(not resumed.activate_wave(9), "Dispatched reload never repeats the redirected wave")
	check(not resumed.plan_if_ready(true, 10, 30.0, 0), "Dispatched reload never plans another wave")
	var bad_states: Array = [null, [], {}, true, "state"]
	for field in dispatched:
		var missing: Dictionary = dispatched.duplicate()
		missing.erase(field)
		bad_states.append(missing)
	var extra: Dictionary = dispatched.duplicate()
	extra["clock"] = 12.0
	bad_states.append(extra)
	for field in ["version", "target_wave"]:
		for bad_value in [null, true, "1", NAN, INF, -INF, -1, 1.5, Defense.MAX_TARGET_WAVE + 1]:
			var bad: Dictionary = dispatched.duplicate()
			bad[field] = bad_value
			bad_states.append(bad)
	for field in ["planned", "dispatched"]:
		for bad_value in [0, 1, "true", null]:
			var bad: Dictionary = dispatched.duplicate()
			bad[field] = bad_value
			bad_states.append(bad)
	for bad_value in [null, true, "0", NAN, INF, -INF, -0.01, 12.01]:
		var bad: Dictionary = planned.duplicate()
		bad.warning_remaining = bad_value
		bad_states.append(bad)
	for kind in [null, 1, true, "", "generator", "Pump"]:
		var bad: Dictionary = dispatched.duplicate()
		bad.target_kind = kind
		bad_states.append(bad)
	for change in [{"version": 2}, {"version": 0}, {"target_wave": 0}, {"planned": false}, {"warning_remaining": 1.0}]:
		var bad: Dictionary = dispatched.duplicate()
		bad.merge(change, true)
		bad_states.append(bad)
	for change in [{"dispatched": true}, {"target_kind": "pump"}, {"target_wave": 1}, {"warning_remaining": 1.0}]:
		var bad: Dictionary = inactive.duplicate()
		bad.merge(change, true)
		bad_states.append(bad)
	for bad_state in bad_states:
		check(not Defense.validate_snapshot(bad_state), "Malformed or inconsistent snapshot must fail validation")
		check(not defense.restore(bad_state), "Malformed or inconsistent snapshot must fail restoration")
		check(defense.snapshot() == dispatched, "Rejected restoration must be transactional")
