extends SceneTree
## Navigation regression derived from the archived v0.19 earned checkpoint.
## Only test metadata is adapted to schema 3; this is not a player migration
## or evidence of an untouched v0.20 earned run. Orders/resources stay intact.
const Nav = preload("res://friendly_navigation.gd")
var checks: int = 0
var failures: Array[String] = []
var results: Array = []

func _initialize(): call_deferred("run")
func check(value: bool, label: String):
	checks += 1
	if value: print("PASS ", label)
	else:
		failures.append(label)
		push_error("FAIL " + label)

# Independent earned-scene oracle: relay center (8,-2), radius 1.0, and
# main's 0.3 padding rasterize x=6..10, z=-4..0. These are adjacent cells.
func on_relay_perimeter(point: Vector3) -> bool:
	return ((point.z == -5.0 or point.z == 1.0) and point.x >= 6.0 and point.x <= 10.0) or ((point.x == 5.0 or point.x == 11.0) and point.z >= -4.0 and point.z <= 0.0)

func run_case(reissue: bool):
	DirAccess.make_dir_recursive_absolute("user://settlement_v2")
	var fixture:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/earned_m3_approach.json"))
	fixture.version=3;fixture.run_seed="0"
	var fixture_visual=RandomNumberGenerator.new();fixture_visual.seed=0
	fixture.visual_rng=str(fixture_visual.state)
	var fixture_file=FileAccess.open("user://settlement_v2/checkpoint.json",FileAccess.WRITE)
	assert(fixture_file!=null)
	fixture_file.store_string(JSON.stringify(fixture,"",false,true));fixture_file.close()
	var campaign = root.get_node("Campaign")
	campaign.current = 2; campaign.launch = true; campaign.resume = true; campaign.muted = true
	var g = load("res://main.tscn").instantiate()
	root.add_child(g); g.set_process(false)
	check(is_equal_approx(g.elapsed, 1145.0) and is_equal_approx(g.hold_time, 42.95), "earned checkpoint resumes without modifying saved elapsed/hold")
	var relay: Dictionary = g.buildings.filter(func(building): return building.kind == "relay")[0]
	var workers: Array = g.units.filter(func(worker): return worker.kind == "worker" and worker.target == relay)
	check(relay.built == 0.0 and workers.size() == 2, "earned unbuilt relay and both existing builder assignments restore")
	if reissue:
		var available: Array = g.units.filter(func(worker): return worker.kind == "worker" and worker.target != relay and worker.task not in ["build", "site", "repair"])
		available.sort_custom(func(a,b): return a.node.position.distance_squared_to(relay.node.position) < b.node.position.distance_squared_to(relay.node.position))
		g.selected = [available[0]]
		g.command_at(relay.node.position)
		workers.append(available[0])
		check(available[0].task == "build" and available[0].target == relay, "ordinary relay click assigns the audit's nearby third worker")
	var safe_segments := true
	var no_teleports := true
	var bounded_queries := true
	var legitimate_work := true
	var selected_endpoints: Array = []
	var original_built: float = relay.built
	var started: float = g.elapsed
	var progress_times: Array = []
	for tick in 1800:
		if relay.built >= 1.0 or g.ended or relay.hp <= 0.0: break
		if g.active_card: g.choose_upgrade(0)
		var positions: Array = []
		for worker in workers: positions.append(worker.node.position if is_instance_valid(worker.node) else Vector3.INF)
		var before: float = relay.built
		g.advance_simulation_time(0.05)
		bounded_queries = bounded_queries and g.friendly_navigation.queries_this_frame <= Nav.MAX_QUERIES_PER_FRAME
		var at_perimeter := false
		for i in workers.size():
			var worker: Dictionary = workers[i]
			if not is_instance_valid(worker.node): continue
			var after: Vector3 = worker.node.position
			if positions[i].is_finite():
				safe_segments = safe_segments and Nav.segment_open(g.nav, positions[i], after)
				var max_step: float = float(g.GameRules.unit(worker.kind).speed) * (1.0 + g.bonus("move", "move_speed_add")) * 0.05
				no_teleports = no_teleports and positions[i].distance_to(after) <= max_step + 0.0001
			var endpoint: Vector3 = worker.get("nav_endpoint", Vector3.INF)
			if endpoint.is_finite() and not str(endpoint) in selected_endpoints: selected_endpoints.append(str(endpoint))
			if on_relay_perimeter(after) and after.distance_to(endpoint) < 0.0001: at_perimeter = true
		if relay.built > before:
			legitimate_work = legitimate_work and at_perimeter
			if progress_times.is_empty(): progress_times.append(g.elapsed)
	var label := "reissue" if reissue else "resume"
	check(relay.built >= 1.0, label + " completes earned relay with ordinary simulation")
	check(safe_segments and no_teleports, label + " builders follow open segments within movement speed, without teleporting")
	check(legitimate_work and relay.built > original_built, label + " construction progresses only with a builder at the actual target perimeter")
	check(bounded_queries, label + " retains the eight-query shared step budget")
	var report := {"mode": label, "started_at": started, "finished_at": g.elapsed, "relay_built": relay.built, "relay_hp": relay.hp, "ended": g.ended, "selected_endpoints": selected_endpoints, "first_work_at": progress_times, "safe_segments": safe_segments, "no_teleports": no_teleports, "legitimate_work": legitimate_work, "bounded_queries": bounded_queries}
	results.append(report)
	print("EARNED_RELAY_CASE ", JSON.stringify(report))
	g.free()
	await process_frame

func run():
	await run_case(false)
	await run_case(true)
	var output := FileAccess.open("res://earned_relay_result.json", FileAccess.WRITE)
	output.store_string(JSON.stringify(results, "  "))
	output.close()
	print("EARNED_RELAY_SUMMARY checks=%d failures=%d" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
