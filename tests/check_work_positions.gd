extends SceneTree
const Nav = preload("res://friendly_navigation.gd")
var checks: int = 0
var failures: Array[String] = []
var nodes: Array[Node] = []
var safe := true
var bounded := true
var speed_limited := true

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
func target_fixture() -> Dictionary:
	var node := Node3D.new(); nodes.append(node)
	return {"node":node,"radius":1.0,"hp":100.0}
func worker_fixture(target: Dictionary, start: Vector3, task: String = "build") -> Dictionary:
	var node := Node3D.new(); nodes.append(node); node.position = start
	return {"node":node,"hp":100.0,"task":task,"target":target,"goal":Vector3.ZERO,"planned":Vector3.INF,"route":[]}
func ticks(nav: RefCounted, workers: Array, grid: AStarGrid2D, count: int):
	for step in count:
		nav.begin_frame(0.05, workers)
		for worker in workers:
			if worker.hp <= 0: continue
			var before: Vector3 = worker.node.position
			nav.advance(worker, grid, 0.05, 4.0)
			safe = safe and Nav.segment_open(grid, before, worker.node.position)
			speed_limited = speed_limited and before.distance_to(worker.node.position) <= 0.20001
		bounded = bounded and nav.queries_this_frame <= Nav.MAX_QUERIES_PER_FRAME
func unique_positions(workers: Array) -> int:
	var positions := {}
	for worker in workers: positions[worker.node.position] = true
	return positions.size()
func narrow_grid(nav: RefCounted, target: Dictionary) -> AStarGrid2D:
	var grid := grid_fixture()
	for point in nav._work_perimeter(grid, target, Vector3(-8,0,0)):
		if point != Vector3(-3,0,0): grid.set_point_solid(Nav.cell_of(point), true)
	return grid
func run():
	var nav := Nav.new(); var grid := grid_fixture(); var target := target_fixture()
	var workers: Array = []
	for i in 6: workers.append(worker_fixture(target, Vector3(-8,0,float(i)-3)))
	ticks(nav, workers, grid, 240)
	check(workers.all(func(w): return nav.is_arrived(w)) and unique_positions(workers) == 6, "six builders arrive at six actual, distinct positions")
	check(workers.all(func(w): return w.node.position in nav._work_perimeter(grid,target,w.node.position)), "every reserved endpoint remains on the exact target perimeter")
	check(nav.work_reservations.size() == 6, "reservations are bounded to one cell per working actor")
	print("SIX_BUILDER_POSITIONS ", workers.map(func(w): return w.node.position))
	# Reconstruction uses ordinary saved actor positions, task, target, and goal.
	var restored: Array = []
	for worker in workers:
		var replacement := worker_fixture(target, worker.node.position, worker.task)
		replacement.goal = worker.goal
		restored.append(replacement)
	nav = Nav.new(); ticks(nav, restored, grid, 2)
	check(restored.all(func(w): return nav.is_arrived(w)) and unique_positions(restored) == 6 and nav.work_reservations.size() == 6, "fresh navigation reconstructs six reservations from restored orders and positions")
	var owner: Dictionary = restored[0]
	owner.task = "idle"; owner.target = null
	nav.begin_frame(0.05, restored)
	check(nav.work_reservations.size() == 5 and not owner.has("nav_work_cell"), "implicit completed or changed order releases its reservation next step")
	owner = restored[1]; nav.invalidate_order(owner)
	check(nav.work_reservations.size() == 4, "explicit reissued order releases immediately")
	restored[2].hp = 0
	nav.begin_frame(0.05, restored)
	check(nav.work_reservations.size() == 3, "dead actor releases its reservation without needing another navigation advance")
	restored[3].target = target_fixture()
	nav.begin_frame(0.05, restored)
	check(nav.work_reservations.size() == 2, "target identity change releases the old cell")
	target.hp = 0
	nav.begin_frame(0.05, restored)
	check(nav.work_reservations.is_empty(), "destroyed target releases all remaining reservations")
	ticks(nav, [restored[4]], grid, 1)
	check(not nav.is_arrived(restored[4]) and restored[4].nav_reason == "target_removed", "destroyed target never permits work or movement to its stale goal")

	nav = Nav.new(); target = target_fixture(); grid = narrow_grid(nav, target)
	workers = [worker_fixture(target,Vector3(-8,0,0)),worker_fixture(target,Vector3(-8,0,2))]
	ticks(nav, workers, grid, 240)
	check(nav.is_arrived(workers[0]) and nav.current_status(workers[1]) == Nav.WORK_WAITING, "occupied one-cell perimeter has one builder and one work-space waiter")
	check(workers[1].node.position == Vector3(-8,0,2) and not nav.is_arrived(workers[1]), "waiting worker does not teleport, overlap, or count as working")
	check(nav.status_text(workers[1]) == "作業場所の空き待ち" and workers[1].nav_attempts == 0, "space contention is visible and does not exhaust no-route retries")
	var occupied_queries: int = nav.total_queries
	ticks(nav,workers,grid,100)
	check(occupied_queries==2 and nav.total_queries==occupied_queries, "occupied perimeter proves reachability once, then waits without redundant AStar queries")
	var waiter_start: Vector3 = workers[1].node.position
	workers[0].task = "idle"; workers[0].target = null
	nav.invalidate_order(workers[0]); ticks(nav, workers, grid, 20)
	check(nav.work_reservations.is_empty() and nav.current_status(workers[1]) == Nav.WORK_WAITING and workers[1].node.position == waiter_start, "released reservation still respects its stationary former owner")
	workers[0].goal = Vector3(-8,0,-4); workers[0].task = "move"
	nav.invalidate_order(workers[0]); ticks(nav, workers, grid, 200)
	check(nav.is_arrived(workers[1]) and workers[1].node.position == Vector3(-3,0,0), "waiting worker retries and walks in after former owner actually leaves")

	# Occupancy inside a sealed cage is not evidence that outsiders can work.
	nav=Nav.new();target=target_fixture();grid=grid_fixture()
	for value in range(-4,5):
		for cell in [Vector2i(value,-4),Vector2i(value,4),Vector2i(-4,value),Vector2i(4,value)]:grid.set_point_solid(cell,true)
	var occupant:=worker_fixture({},Vector3(-3,0,0),"idle")
	var outsider:=worker_fixture(target,Vector3(-8,0,0))
	ticks(nav,[outsider,occupant],grid,400)
	check(nav.current_status(outsider)==Nav.BLOCKED and outsider.nav_attempts==Nav.MAX_ATTEMPTS and outsider.node.position==Vector3(-8,0,0), "occupied but unreachable perimeter stays no-route with bounded retries")

	# Different buildings sharing an adjacent free cell cannot double-book it.
	nav = Nav.new(); target = target_fixture(); grid = grid_fixture()
	workers = [worker_fixture(target,Vector3(-8,0,0)),worker_fixture(target,Vector3(-8,0,1),"repair")]
	ticks(nav, workers, grid, 200)
	check(unique_positions(workers) == 2 and workers.all(func(w): return nav.is_arrived(w)), "repair and construction use the same exclusive destination allocation")
	nav.clear_reservations()
	check(nav.work_reservations.is_empty() and workers.all(func(w): return not w.has("nav_work_cell")), "scene replacement clears transient owner references")

	# Rally allocation itself issues no path queries; actual movement still proves reachability.
	nav = Nav.new(); grid = grid_fixture(); workers = []
	for i in 6:
		var unit := worker_fixture({},Vector3(-9,0,float(i)-3),"move")
		unit.goal = nav.rally_destination(grid,Vector3(-6,0,0),unit,workers)
		workers.append(unit)
	ticks(nav, workers, grid, 200)
	check(unique_positions(workers) == 6 and workers.all(func(w): return nav.is_arrived(w)), "six produced combat orders reach distinct nearby rally destinations")
	check(safe and speed_limited and bounded, "all motion stays on open segments within speed and eight-query step budget")
	print("WORK_POSITIONS_SUMMARY checks=%d failures=%d" % [checks, failures.size()])
	for node in nodes: node.free()
	quit(0 if failures.is_empty() else 1)
