extends SceneTree
## Small semantic fixtures for newly implemented v0.10 recovery navigation.
const Navigation = preload("res://friendly_navigation.gd")
var failures: Array[String] = []
var checks: int = 0
var allocated: Array[Node] = []

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	checks += 1
	if ok:
		print("PASS ", label)
	else:
		failures.append(label)
		push_error("FAIL " + label)

func grid_fixture() -> AStarGrid2D:
	var grid := AStarGrid2D.new()
	grid.region = Rect2i(-8, -8, 17, 17)
	grid.cell_size = Vector2.ONE
	grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	grid.update()
	return grid

func unit_fixture(start: Vector3, goal: Vector3, task: String = "move") -> Dictionary:
	var node := Node3D.new()
	allocated.append(node)
	node.position = start
	return {"node": node, "goal": goal, "planned": Vector3.INF, "route": [], "task": task, "target": null}

func tick(helper: RefCounted, unit: Dictionary, grid: AStarGrid2D, dt: float = 0.1, speed: float = 4.0, hold: bool = false) -> void:
	helper.begin_frame(dt)
	helper.advance(unit, grid, dt, speed, hold)

func walk(helper: RefCounted, unit: Dictionary, grid: AStarGrid2D, count: int = 200) -> bool:
	for step in count:
		var previous: Vector3 = unit.node.position
		tick(helper, unit, grid)
		if not Navigation.segment_open(grid, previous, unit.node.position):
			return false
	return helper.is_arrived(unit)

func run() -> void:
	var grid := grid_fixture()
	for z in range(-8, 9):
		grid.set_point_solid(Vector2i(0, z))
	var helper := Navigation.new()
	var unit := unit_fixture(Vector3(-4, 0, 0), Vector3(4, 0, 0))
	tick(helper, unit, grid)
	check(helper.current_status(unit) == Navigation.BLOCKED and not helper.is_arrived(unit), "sealed destination is blocked, never arrived")
	for step in 200:
		tick(helper, unit, grid)
	check(unit.node.position == Vector3(-4, 0, 0), "sealed destination never falls back to walking through wall")
	check(helper.total_queries == Navigation.MAX_ATTEMPTS, "failed route has finite bounded retries for one order/revision")
	grid.set_point_solid(Vector2i(0, 0), false)
	helper.navigation_changed()
	check(helper.current_status(unit) == Navigation.PENDING, "opening a route invalidates stale blocked status immediately")
	check(walk(helper, unit, grid), "opening blocked route plus revision resumes movement and arrives")

	grid = grid_fixture()
	for task in ["move", "attack_move", "focus_fire", "escort", "site", "build", "repair", "gather"]:
		for z in range(-2, 3):
			grid.set_point_solid(Vector2i(0, z))
		helper = Navigation.new()
		unit = unit_fixture(Vector3(-4, 0, 0), Vector3(4.2, 0, 0.2), task)
		check(walk(helper, unit, grid), task + " uses real AStar detour and reaches fractional goal safely")

	grid = grid_fixture()
	helper = Navigation.new()
	unit = unit_fixture(Vector3.ZERO, Vector3(0.2, 0, 0.1))
	tick(helper, unit, grid, 5.0, 100.0)
	check(unit.node.position == Vector3(0.2, 0, 0.1) and helper.is_arrived(unit), "large step clamps exactly to nearby waypoint without overshoot")
	var arrived_queries: int = helper.total_queries
	for step in 50:
		tick(helper, unit, grid)
	check(helper.total_queries == arrived_queries and unit.node.position == unit.goal, "arrival remains stationary without repeated path queries")

	helper = Navigation.new()
	unit = unit_fixture(Vector3(-4, 0, 0), Vector3(4, 0, 0))
	tick(helper, unit, grid, 0.0)
	unit.route.clear()
	tick(helper, unit, grid)
	check(unit.node.position == Vector3(-4, 0, 0) and not helper.is_arrived(unit), "externally consumed route never becomes direct goal fallback")

	helper = Navigation.new()
	unit = unit_fixture(Vector3(-4, 0, 0), Vector3(4, 0, 0))
	tick(helper, unit, grid, 0.0)
	grid.set_point_solid(Vector2i(-3, 0))
	tick(helper, unit, grid, 10.0, 100.0)
	check(unit.node.position.x <= -3.5 and helper.current_status(unit) == Navigation.BLOCKED, "new solid waypoint stops existing route even before revision notification")
	check(not Navigation.segment_open(grid, Vector3(-4, 0, 0), Vector3(4, 0, 0)), "full segment traversal detects thin wall with free endpoints")
	grid = grid_fixture()
	grid.set_point_solid(Vector2i(1, 0))
	check(not Navigation.segment_open(grid, Vector3.ZERO, Vector3(1, 0, 1)), "diagonal does not cut a solid corner")
	check(Navigation.segment_open(grid, Vector3(0, 0, 1), Vector3(1, 0, 1)), "adjacent free segment remains allowed")
	check(not Navigation.segment_open(grid, Vector3.ZERO, Vector3(9, 0, 0)), "segment cannot leave navigation bounds")

	helper = Navigation.new()
	unit = unit_fixture(Vector3(1, 0, 0), Vector3(4, 0, 0))
	tick(helper, unit, grid)
	check(helper.current_status(unit) == Navigation.BLOCKED and unit.node.position == Vector3(1, 0, 0), "solid start never teleports to a nearby open cell")
	unit.node.position = Vector3.ZERO
	unit.task = "build"
	unit.goal = Vector3(0, 0, 3)
	check(helper.current_status(unit) == Navigation.PENDING, "changed task/goal clears stale blocked context before simulation")
	check(walk(helper, unit, grid), "fresh task advances after blocked prior command")
	helper.invalidate_order(unit)
	check(helper.current_status(unit) == Navigation.PENDING, "identical repeated explicit order resets status and retry budget")
	tick(helper, unit, grid, 0.1, 4.0, true)
	check(not helper.is_arrived(unit), "combat hold is distinct from route arrival")
	tick(helper, unit, grid)
	check(helper.is_arrived(unit), "released combat hold can resolve actual arrival")

	grid = grid_fixture()
	helper = Navigation.new()
	var many: Array[Dictionary] = []
	for index in 20:
		many.append(unit_fixture(Vector3(-4, 0, 0), Vector3(4, 0, 0)))
	helper.begin_frame(0.1)
	for actor in many:
		helper.advance(actor, grid, 0.1, 4.0)
	check(helper.queries_this_frame == Navigation.MAX_QUERIES_PER_FRAME, "shared frame query budget bounds large command batches")
	check(helper.current_status(many.back()) == Navigation.PENDING and many.back().node.position == Vector3(-4, 0, 0), "budget-pending units stay still rather than walking directly")
	for frame in 150:
		helper.begin_frame(0.1)
		for actor in many:
			helper.advance(actor, grid, 0.1, 4.0)
	check(many.all(func(actor): return helper.is_arrived(actor)), "deferred command batch eventually advances every ordinary order")

	grid = grid_fixture()
	grid.set_point_solid(Vector2i(4, 0))
	helper = Navigation.new()
	unit = unit_fixture(Vector3.ZERO, Vector3(4, 0, 0), "build")
	check(walk(helper, unit, grid) and unit.goal != Vector3(4, 0, 0), "solid work target resolves to a traversable free approach")
	grid.set_point_solid(Vector2i(4, 0), false)
	helper.navigation_changed()
	check(walk(helper, unit, grid) and unit.goal == Vector3(4, 0, 0), "revision reconsiders original requested point after obstacle removal")
	var random := RandomNumberGenerator.new()
	random.seed = 71452
	var open_segments := true
	for index in 1000:
		var start := Vector3(random.randf_range(-7.9, 7.9), 0, random.randf_range(-7.9, 7.9))
		var end := Vector3(random.randf_range(-7.9, 7.9), 0, random.randf_range(-7.9, 7.9))
		if not Navigation.segment_open(grid, start, end):
			open_segments = false
	check(open_segments, "1000 deterministic arbitrary segments stay traversable on an empty grid")

	print("RECOVERY_NAVIGATION_SUMMARY checks=%d failures=%d" % [checks, failures.size()])
	for node in allocated:
		node.free()
	quit(0 if failures.is_empty() else 1)
