extends SceneTree

const Observer = preload("../supply_feedback.gd")
var failures: Array[String] = []
var assertions := 0


func _initialize() -> void:
	var cases: Array = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/supply_cases.json"))
	for fixture: Dictionary in cases:
		var observer = Observer.new()
		for phase: Dictionary in fixture.phases:
			for second in int(phase.seconds):
				observe(observer, float(phase.get("base", 0)), float(phase.get("factory", 0)), float(phase.get("spent", 0)), int(phase.get("reserve", 0)))
			var result: Dictionary = observer.view()
			check(result.state == phase.expect, str(fixture.name) + ": expected " + str(phase.expect) + ", got " + str(result.state))
			check(result.bucket_count <= 12, str(fixture.name) + ": bounded buckets")
			if phase.has("supply_total"):
				check(is_equal_approx(float(result.observed.supplied), float(phase.supply_total)), str(fixture.name) + ": actual supply")
			if phase.has("spend_total"):
				check(is_equal_approx(float(result.observed.spent), float(phase.spend_total)), str(fixture.name) + ": actual debit")
	check_context_and_reset()
	check_step_partition()
	check_invalid_events()
	var report := {"passed": failures.is_empty(), "assertions": assertions, "fixture_cases": cases.size(), "failures": failures}
	var file := FileAccess.open("user://supply_feedback_result.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "  ") + "\n")
	file.close()
	print(JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)


func check_context_and_reset() -> void:
	var observer = Observer.new()
	for second in 13:
		observe(observer, 2, 0, 14, 0)
	var states: Array[String] = ["生産中", "未給電", "未給電"]
	var before := states.duplicate()
	var stopped: Dictionary = observer.view(states)
	check(stopped.workshop_hint == "未給電の工房2棟", "reports real stopped group without blaming every workshop")
	check(states == before, "caller workshop states unchanged")
	var recovered_states: Array[String] = ["生産中", "生産中", "生産中"]
	var recovered: Dictionary = observer.view(recovered_states)
	check(recovered.workshop_hint == "工房3棟は生産中", "current workshop recovery replaces old stopped reason immediately")
	check(recovered.state == "deficit", "workshop status alone cannot prove supply recovered")
	check(observer.view().workshop_hint == "工房なし", "absent workshop is factual")
	var material: Array[String] = ["資材不足", "生産中"]
	check(observer.view(material).workshop_hint == "廃材不足の工房1棟", "resource alias is salvage, not all three settlement resources")
	var unknown: Array[String] = ["unknown"]
	check(observer.view(unknown).workshop_hint == "工房の状態未確認", "unknown status cannot be relabeled as producing")
	observer.reset()
	var cleared: Dictionary = observer.view(states)
	check(cleared.state == "quiet" and cleared.bucket_count == 0 and cleared.tooltip == "" and cleared.context == "", "new mission / successful load clears observer")
	for second in 11:
		observe(observer, 2, 0, 14, 0)
	check(observer.view().state == "quiet", "resume must warm up, without saved history")


func check_step_partition() -> void:
	var whole = Observer.new()
	var split = Observer.new()
	for second in 13:
		observe(whole, 2, 8, 14, 0)
		for frame in 60:
			split.record_supply(2.0 / 60.0, "base")
			split.record_supply(8.0 / 60.0, "factory")
			split.record_combat_spend(14.0 / 60.0)
			split.finish_step(1.0 / 60.0)
	check(split.view().state == whole.view().state, "fixed-step fractions preserve state")
	check(split.view().bucket_count == 12, "fractional clock closes exactly twelve retained seconds")
	check(is_equal_approx(float(split.view().observed.spent), float(whole.view().observed.spent)), "fractional actual debits preserved")
	var paused: Dictionary = split.view()
	for redraw in 30:
		check(split.view() == paused, "view-only pause does not age or mutate observation")


func check_invalid_events() -> void:
	var observer = Observer.new()
	observer.record_supply(-10, "base")
	observer.record_supply(INF, "factory")
	observer.record_supply(200, "refund")
	observer.record_combat_spend(-5)
	observer.record_combat_spend(NAN)
	observer.finish_step(1)
	check(observer.view().observed.supplied == 0 and observer.view().observed.spent == 0, "invalid events and non-supply sources ignored")
	observer.record_combat_spend(5)
	observer.finish_step(12)
	check(observer.view().bucket_count == 0 and observer.view().state == "quiet", "unobserved time gap clears rather than fabricates history")


func observe(observer: RefCounted, base: float, factory: float, spent: float, reserve: int) -> void:
	observer.record_supply(base, "base")
	observer.record_supply(factory, "factory")
	observer.record_combat_spend(spent)
	for shot in reserve:
		observer.record_reserve_shot()
	observer.finish_step(1)


func check(condition: bool, label: String) -> void:
	assertions += 1
	if not condition:
		failures.append(label)
		push_error(label)
