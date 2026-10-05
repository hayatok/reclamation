extends SceneTree
const Nav = preload("res://friendly_navigation.gd")
var checks: int = 0
var failures: Array[String] = []
var nodes: Array[Node] = []

func _initialize(): call_deferred("run")
func check(ok: bool, label: String):
	checks += 1
	if ok: print("PASS ", label)
	else:
		failures.append(label); push_error("FAIL " + label)
func grid_fixture() -> AStarGrid2D:
	var grid := AStarGrid2D.new()
	grid.region = Rect2i(-12, -12, 25, 25)
	grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	grid.update()
	grid.fill_solid_region(Rect2i(-2, -2, 5, 5), true)
	return grid
func worker_fixture(task: String = "build") -> Dictionary:
	var node := Node3D.new(); nodes.append(node)
	node.position = Vector3(-8, 0, 0)
	var building := Node3D.new(); nodes.append(building)
	return {"node":node,"task":task,"target":{"node":building,"kind":"relay","radius":1.0},"goal":Vector3(0,0,2),"planned":Vector3.INF,"route":[]}
func tick(nav: RefCounted, worker: Dictionary, grid: AStarGrid2D):
	nav.begin_frame(0.05)
	nav.advance(worker, grid, 0.05, 4.0)

func run():
	var grid := grid_fixture()
	# Seal the five closest left-hand perimeter cells in a separate pocket.
	grid.fill_solid_region(Rect2i(-4, -3, 1, 7), true)
	grid.fill_solid_region(Rect2i(-4, -3, 3, 1), true)
	grid.fill_solid_region(Rect2i(-4, 3, 3, 1), true)
	var nav := Nav.new()
	var worker := worker_fixture()
	nav.begin_frame(0.05)
	nav.queries_this_frame = Nav.MAX_QUERIES_PER_FRAME - 1
	nav.advance(worker, grid, 0.05, 4.0)
	check(nav.current_status(worker) == Nav.PENDING and worker.node.position == Vector3(-8,0,0), "budget-exhausted approach search stays pending and stationary")
	check(worker.nav_candidate_index == 1 and worker.nav_attempts == 1, "partial search retains candidate cursor and consumes only one attempt")
	var safe := true
	var bounded := true
	for index in 200:
		var before: Vector3 = worker.node.position
		tick(nav, worker, grid)
		safe = safe and Nav.segment_open(grid, before, worker.node.position)
		bounded = bounded and nav.queries_this_frame <= Nav.MAX_QUERIES_PER_FRAME
	check(nav.is_arrived(worker) and safe and bounded, "search skips sealed preferred side and safely reaches another perimeter")
	check(worker.nav_attempts == 1 and worker.nav_endpoint in nav._work_perimeter(grid, worker.target, worker.node.position), "reachable alternative is actual building perimeter in the original search attempt")

	grid = grid_fixture()
	grid.fill_solid_region(Rect2i(-4, -4, 9, 1), true)
	grid.fill_solid_region(Rect2i(-4, 4, 9, 1), true)
	grid.fill_solid_region(Rect2i(-4, -4, 1, 9), true)
	grid.fill_solid_region(Rect2i(4, -4, 1, 9), true)
	nav = Nav.new(); worker = worker_fixture()
	var perimeter_count: int = nav._work_perimeter(grid, worker.target, worker.node.position).size()
	for index in 250:
		tick(nav, worker, grid)
		bounded = bounded and nav.queries_this_frame <= Nav.MAX_QUERIES_PER_FRAME
	check(nav.current_status(worker) == Nav.BLOCKED and not nav.is_arrived(worker) and worker.node.position == Vector3(-8,0,0), "truly enclosed building stays blocked instead of building from outside its cage")
	check(nav.total_queries == perimeter_count * Nav.MAX_ATTEMPTS and bounded, "fully sealed perimeter has bounded complete searches and shared step budget")
	check(worker.goal == Vector3(0,0,2) and worker.nav_endpoint == Vector3.INF, "failed candidates do not overwrite requested goal or advertise a work endpoint")
	grid.set_point_solid(Vector2i(-4,0), false)
	nav.navigation_changed()
	for index in 100: tick(nav, worker, grid)
	check(nav.is_arrived(worker) and worker.nav_endpoint == Vector3(-3,0,0), "opening enclosure and revision resumes work at newly reachable perimeter")

	grid = grid_fixture(); nav = Nav.new(); worker = worker_fixture("repair")
	# A saved stale free goal is not trusted as the target's work approach.
	worker.goal = Vector3(-10,0,-10)
	for index in 100: tick(nav, worker, grid)
	check(nav.is_arrived(worker) and worker.nav_endpoint == Vector3(-3,0,0), "repair restores target perimeter from identity rather than saved snapped goal")
	print("WORK_APPROACH_SUMMARY checks=%d failures=%d" % [checks, failures.size()])
	for node in nodes: node.free()
	quit(0 if failures.is_empty() else 1)
