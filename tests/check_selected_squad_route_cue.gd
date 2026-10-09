extends SceneTree
## Lightweight semantic fixtures; no main scene, rendering, or saved-game writes.
const Cue = preload("res://selected_squad_route_cue.gd")
const Navigation = preload("res://friendly_navigation.gd")
const Visibility = preload("res://frontier_visibility.gd")

var failures: Array[String] = []
var checks: int = 0
var allocated: Array[Node] = []

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	checks += 1
	print("PASS " if ok else "FAIL ", label)
	if not ok:
		failures.append(label)

func grid_fixture() -> AStarGrid2D:
	var grid: AStarGrid2D = AStarGrid2D.new()
	grid.region = Rect2i(-64, -64, 129, 129)
	grid.cell_size = Vector2.ONE
	grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	grid.update()
	return grid

func fog_fixture(unknown: Array[Vector2i] = []) -> RefCounted:
	var field: RefCounted = Visibility.new()
	field.configure(Rect2(-16, -16, 64, 64), 1, 4.0)
	var state: Dictionary = field.snapshot()
	var bits: PackedByteArray = PackedByteArray()
	bits.resize(32)
	bits.fill(255)
	for cell: Vector2i in unknown:
		var index: int = cell.y * 16 + cell.x
		bits[index >> 3] &= ~(1 << (index & 7))
	state.explored = bits.hex_encode()
	check(field.restore(state), "fog fixture accepts explored-cell snapshot")
	return field

func unit_fixture(start: Vector3, points: Array, task: String = "move", kind: String = "guard") -> Dictionary:
	var node: Node3D = Node3D.new()
	root.add_child(node)
	allocated.append(node)
	node.position = start
	var endpoint: Vector3 = points[-1]
	return {"kind": kind, "hp": 100.0, "node": node, "task": task, "target": null,
		"route": points.duplicate(), "goal": endpoint, "planned": endpoint,
		"nav_goal": endpoint, "nav_requested": endpoint, "nav_endpoint": endpoint,
		"nav_task": task, "nav_target_node": null, "nav_revision": 0, "nav_status": "moving"}

func set_task(unit: Dictionary, task: String) -> void:
	unit.task = task
	unit.nav_task = task

func run() -> void:
	var grid: AStarGrid2D = grid_fixture()
	var navigation: RefCounted = Navigation.new()
	var field: RefCounted = fog_fixture()
	var first: Dictionary = unit_fixture(Vector3(-6, 0, 2), [Vector3(-6, 0, 6), Vector3(6, 0, 6), Vector3(6, 0, 2)])
	var second: Dictionary = unit_fixture(Vector3(-5, 0, 3), [Vector3(-5, 0, 7), Vector3(7, 0, 7), Vector3(7, 0, 3)], "move", "grenade")
	var selected: Array = [first, second]
	var before: Array = [first.duplicate(true), second.duplicate(true), field.snapshot(), navigation.revision, navigation.total_queries, navigation.queries_this_frame]
	var data: Dictionary = Cue.build(selected, navigation, field, grid)
	check(not data.is_empty() and data.selected_count == 2 and data.task == "move", "coherent combat squad receives a cue")
	var expected_id: int = mini(first.node.get_instance_id(), second.node.get_instance_id())
	check(data.representative_id == expected_id, "lowest instance ID is the explicitly identified representative")
	check(Cue.build([second, first], navigation, field, grid) == data, "selection-array reordering keeps route and representative stable")
	check(data.known_route == PackedVector3Array([first.node.position] + first.route) and data.route_complete, "known route preserves actual detour without a wall shortcut")
	check(data.known_endpoint == first.nav_endpoint and data.issued_destination == first.nav_requested, "known endpoint and issued point are explicit and independent")
	data.known_route[0] = Vector3(99, 0, 99)
	check([first, second, field.snapshot(), navigation.revision, navigation.total_queries, navigation.queries_this_frame] == before, "build and returned-data edits leave units, nodes, fog, revision and query counters unchanged")
	check(first.node.position == Vector3(-6, 0, 2), "helper never moves the representative node")

	set_task(second, "attack_move")
	check(Cue.build(selected, navigation, field, grid).is_empty(), "mixed move and attack-move orders suppress the entire cue")
	set_task(first, "attack_move")
	check(Cue.build(selected, navigation, field, grid).get("task") == "attack_move", "matching attack-move squad is eligible")
	second.nav_requested = Vector3(30, 0, 30)
	check(Cue.build(selected, navigation, field, grid).is_empty(), "divergent requested goals cannot invent a shared route")
	second.nav_requested = second.nav_endpoint
	for task: String in ["focus_fire", "escort", "gather", "build", "idle"]:
		set_task(second, task)
		check(Cue.build(selected, navigation, field, grid).is_empty(), task + " member suppresses squad cue")
	set_task(second, "attack_move")
	for status: String in ["pending", "blocked", "arrived", "work_waiting"]:
		second.nav_status = status
		check(Cue.build(selected, navigation, field, grid).is_empty(), status + " member suppresses squad cue")
	second.nav_status = "moving"
	second.kind = "worker"
	check(Cue.build(selected, navigation, field, grid).is_empty(), "mixed worker/combat selection suppresses cue")
	second.kind = "siegecart"
	check(not Cue.build(selected, navigation, field, grid).is_empty(), "siege cart belongs to eligible military kinds")
	second.hp = 0.0
	check(Cue.build(selected, navigation, field, grid).is_empty(), "dead selection member clears cue")
	second.hp = 100.0
	check(Cue.build([first, first], navigation, field, grid).is_empty(), "duplicate actor cannot impersonate a squad")
	check(Cue.build([], navigation, field, grid).is_empty(), "deselection clears cue")

	navigation.navigation_changed()
	check(Cue.build(selected, navigation, field, grid).is_empty(), "navigation revision rejects all stale paths immediately")
	navigation = Navigation.new()
	second.goal = Vector3(8, 0, 3)
	check(Cue.build(selected, navigation, field, grid).is_empty(), "changed order cannot reuse prior nav route")
	second.goal = second.nav_goal
	second.node.position = second.nav_endpoint
	check(Cue.build(selected, navigation, field, grid).is_empty(), "physical arrival clears cue even before status catch-up")
	second.node.position = Vector3(-5, 0, 3)

	# Endpoints are explored; cell x=1 (world x=-12..-8) is unknown between them.
	field = fog_fixture([Vector2i(1, 4)])
	var long_leg: Dictionary = unit_fixture(Vector3(-14, 0, 2), [Vector3(14, 0, 2)])
	data = Cue.build([long_leg], navigation, field, grid)
	check(not data.is_empty() and data.stop_reason == "unknown" and not data.route_complete, "long waypoint leg stops at the first unknown cell")
	check(data.known_route.size() == 2 and data.known_endpoint.x < -12.0 and data.known_endpoint.x > -12.01, "explored prefix ends just inside the first unknown boundary")
	check(data.issued_destination == Vector3(14, 0, 2), "own issued destination survives independently of fog clipping")
	grid.set_point_solid(Vector2i(8, 2))
	check(Cue.build([long_leg], navigation, field, grid) == data, "changed hidden wall beyond first unknown is never inspected")
	grid.set_point_solid(Vector2i(8, 2), false)
	grid.set_point_solid(Vector2i(-12, 2))
	check(Cue.build([long_leg], navigation, field, grid) == data, "hidden boundary navigation cell cannot change the clipped route")
	grid.set_point_solid(Vector2i(-12, 2), false)
	long_leg.nav_requested = Vector3(-10, 0, 2)
	check(Cue.build([long_leg], navigation, field, grid).issued_destination == Vector3(-10, 0, 2), "unknown own requested point is shown instead of projected endpoint")
	long_leg.target = {"node": second.node}
	long_leg.nav_target_node = second.node
	check(Cue.build([long_leg], navigation, field, grid).is_empty(), "target-bearing order cannot expose an enemy or hidden structure target")
	long_leg.target = null
	long_leg.nav_target_node = null
	long_leg.nav_requested = long_leg.nav_endpoint
	long_leg.route = [Vector3(-13, 0, 2), Vector3(14, 0, 2), Vector3(14, 0, 6)]
	long_leg.nav_endpoint = Vector3(14, 0, 6)
	data = Cue.build([long_leg], navigation, field, grid)
	check(data.known_route.size() == 3 and data.known_endpoint.x < -12.0, "route never resumes after crossing unknown into later explored waypoints")

	field = fog_fixture([Vector2i(5, 4)])
	var diagonal: Dictionary = unit_fixture(Vector3(2, 0, 2), [Vector3(6, 0, 6)])
	data = Cue.build([diagonal], navigation, field, grid)
	check(data.stop_reason == "unknown" and data.known_endpoint.x < 4.0, "unknown side cell at a diagonal corner clips the leg conservatively")
	grid.set_point_solid(Vector2i(4, 4))
	check(Cue.build([diagonal], navigation, field, grid) == data, "hidden corner navigation cell cannot change the clipped route")
	grid.set_point_solid(Vector2i(4, 4), false)
	var boundary: Dictionary = unit_fixture(Vector3(4, 0, 2), [Vector3(4, 0, 10)])
	field = fog_fixture([Vector2i(4, 5)])
	data = Cue.build([boundary], navigation, field, grid)
	check(data.stop_reason == "unknown" and data.known_endpoint.z < 4.0, "boundary-aligned leg cannot reveal unknown cells along its other side")
	field = fog_fixture()
	var map_edge: Dictionary = unit_fixture(Vector3(42, 0, 42), [Vector3(48, 0, 48)])
	data = Cue.build([map_edge], navigation, field, grid)
	check(data.route_complete and data.known_endpoint == Vector3(48, 0, 48), "exact maximum fog edge remains an explored endpoint")
	var shifted_parent: Node3D = Node3D.new()
	root.add_child(shifted_parent)
	allocated.append(shifted_parent)
	shifted_parent.position = Vector3(10, 0, 10)
	var shifted: Dictionary = unit_fixture(Vector3(-4, 0, 2), [Vector3(4, 0, 2)])
	shifted.node.reparent(shifted_parent, false)
	data = Cue.build([shifted], navigation, field, grid)
	check(data.representative_position == Vector3(6, 0, 12) and data.issued_destination == Vector3(14, 0, 12), "local navigation points transform into world minimap coordinates")
	allocated.erase(shifted.node)
	var shortcut: Dictionary = unit_fixture(Vector3(-6, 0, 2), [Vector3(6, 0, 2)])
	data = Cue.build([shortcut], navigation, field, grid)
	grid.set_point_solid(Vector2i(0, 2))
	check(Cue.build([shortcut], navigation, field, grid) == data, "drawing never inspects unannounced grid writes")
	navigation.navigation_changed()
	check(Cue.build([shortcut], navigation, field, grid).is_empty(), "production grid revision immediately invalidates the old route")
	navigation = Navigation.new()
	grid.set_point_solid(Vector2i(0, 2), false)
	first.route = [Vector3(NAN, 0, 0), first.nav_endpoint]
	check(Cue.build([first], navigation, field, grid).is_empty(), "nonfinite interior route point is rejected")
	first.route = [first.nav_endpoint]
	first.nav_requested = Vector3.INF
	check(Cue.build([first], navigation, field, grid).is_empty(), "nonfinite requested point is rejected")
	first.nav_requested = first.nav_endpoint
	first.route = [Vector3(8, 0, 8)]
	check(Cue.build([first], navigation, field, grid).is_empty(), "incomplete route whose tail differs from nav endpoint is rejected")
	first.route.clear()
	check(Cue.build([first], navigation, field, grid).is_empty(), "empty route never becomes a straight destination segment")

	var many_points: Array = []
	for index: int in 120:
		many_points.append(Vector3(2 + index % 2, 0, 2 + index * 0.01))
	var bounded: Dictionary = unit_fixture(Vector3(1, 0, 2), many_points)
	data = Cue.build([bounded], navigation, field, grid)
	check(data.known_route.size() <= Cue.MAX_DRAW_POINTS and data.stop_reason == "point_limit" and not data.route_complete, "drawing-point cap reports an explicitly incomplete prefix")
	var huge: Array = []
	huge.resize(Cue.MAX_ROUTE_POINTS + 1)
	huge.fill(Vector3(3, 0, 3))
	bounded.route = huge
	bounded.nav_endpoint = Vector3(3, 0, 3)
	check(Cue.build([bounded], navigation, field, grid).is_empty(), "oversized route is rejected before traversal")
	var tiny_fog: RefCounted = Visibility.new()
	tiny_fog.configure(Rect2(-16, -1, 64, 2), 1, 0.125)
	var tiny_state: Dictionary = tiny_fog.snapshot()
	var tiny_bits: PackedByteArray = PackedByteArray()
	tiny_bits.resize(1024)
	tiny_bits.fill(255)
	tiny_state.explored = tiny_bits.hex_encode()
	check(tiny_fog.restore(tiny_state), "dense fog fixture restores")
	var zigzag: Dictionary = unit_fixture(Vector3(-14, 0, 0.0625), [Vector3(46, 0, 0.0625), Vector3(-14, 0, 0.0625), Vector3(46, 0, 0.0625)])
	data = Cue.build([zigzag], navigation, tiny_fog, grid)
	check(data.stop_reason == "fog_limit" and data.fog_cell_checks <= Cue.MAX_FOG_CELL_CHECKS and not data.route_complete, "fog traversal has a hard shared cell-check budget")
	check(navigation.total_queries == 0, "drawing remains free of pathfinding queries")

	# Normal navigation performs planning; cue never does. Arrival is observed only.
	var real_unit: Dictionary = unit_fixture(Vector3(-4, 0, 2), [Vector3(4, 0, 2)])
	real_unit.planned = Vector3.INF
	navigation.begin_frame()
	navigation.advance(real_unit, grid, 0.0, 4.0)
	var query_count: int = navigation.total_queries
	check(not Cue.build([real_unit], navigation, field, grid).is_empty(), "real FriendlyNavigation moving route is accepted")
	check(navigation.total_queries == query_count, "render cue performs no additional pathfinding")
	navigation.advance(real_unit, grid, 10.0, 4.0)
	check(navigation.is_arrived(real_unit) and Cue.build([real_unit], navigation, field, grid).is_empty(), "ordinary navigation arrival removes the cue")
	check_cache(grid, field)

	for node: Node in allocated:
		node.free()
	print("SELECTED_SQUAD_ROUTE_RESULT checks=", checks, " failures=", failures.size())
	quit(1 if not failures.is_empty() else 0)

func check_cache(grid: AStarGrid2D, field: RefCounted) -> void:
	var navigation: RefCounted = Navigation.new()
	var cached: RefCounted = Cue.new()
	var unit: Dictionary = unit_fixture(Vector3(-6, 0, 2), [Vector3(-6, 0, 6), Vector3(6, 0, 6), Vector3(6, 0, 2)])
	var selection: Array = [unit]
	var first_data: Dictionary = cached.get_data(selection, navigation, field, grid, 10.0)
	for frame: int in 8:
		check(cached.get_data(selection, navigation, field, grid, 10.0) == first_data, "frozen render-only frame reuses identical drawing data")
	check(cached.build_count == 1 and cached.cache_hit_count == 8, "identical paused key builds exactly once")
	first_data.known_route[0] = Vector3(99, 0, 99)
	check(cached.get_data(selection, navigation, field, grid, 10.0).known_route[0] == unit.node.position, "returned cache data cannot mutate retained route")
	var count: int = cached.build_count
	unit.route[0] = Vector3(-5, 0, 6)
	check(cached.get_data(selection, navigation, field, grid, 10.0).known_route[1] == Vector3(-5, 0, 6) and cached.build_count == count + 1, "paused representative route edit invalidates detached snapshot")
	count = cached.build_count
	unit.node.position.x += 0.1
	check(cached.get_data(selection, navigation, field, grid, 10.0).representative_position == unit.node.position and cached.build_count == count + 1, "paused position change rebuilds immediately")
	count = cached.build_count
	cached.get_data(selection, navigation, field, grid, 10.1)
	check(cached.build_count == count + 1, "new simulation tick refreshes even if actor is holding position")
	unit.task = "idle"
	check(cached.get_data(selection, navigation, field, grid, 10.1).is_empty(), "paused stop clears cached route immediately")
	unit.task = "move"
	check(not cached.get_data(selection, navigation, field, grid, 10.1).is_empty(), "resumed valid order rebuilds after a paused stop")
	unit.goal = Vector3(7, 0, 2)
	check(cached.get_data(selection, navigation, field, grid, 10.1).is_empty(), "paused goal replacement hides route before planning")
	unit.goal = unit.nav_goal
	cached.get_data(selection, navigation, field, grid, 10.1)
	unit.nav_requested = Vector3(7, 0, 2)
	check(cached.get_data(selection, navigation, field, grid, 10.1).issued_destination == Vector3(7, 0, 2), "paused requested destination change cannot retain old marker")
	for status: String in ["pending", "blocked", "arrived", "work_waiting"]:
		unit.nav_status = status
		check(cached.get_data(selection, navigation, field, grid, 10.1).is_empty(), "cached " + status + " clears immediately")
		unit.nav_status = "moving"
		check(not cached.get_data(selection, navigation, field, grid, 10.1).is_empty(), "valid movement rebuilds after " + status)
	unit.hp = 0.0
	check(cached.get_data(selection, navigation, field, grid, 10.1).is_empty(), "paused death clears the cache")
	unit.hp = 100.0
	cached.get_data(selection, navigation, field, grid, 10.1)
	check(cached.get_data([], navigation, field, grid, 10.1).is_empty(), "paused deselection clears the cache")
	var other: Dictionary = unit_fixture(Vector3(-5, 0, 3), [Vector3(7, 0, 3)])
	check(cached.get_data([other], navigation, field, grid, 10.1).representative_id == other.node.get_instance_id(), "paused selection replacement uses the new representative")
	cached.get_data(selection, navigation, field, grid, 10.1)
	navigation.navigation_changed()
	check(cached.get_data(selection, navigation, field, grid, 10.1).is_empty(), "navigation revision clears cached route before next simulation tick")
	unit.nav_revision = navigation.revision
	cached.get_data(selection, navigation, field, grid, 10.1)
	count = cached.build_count
	field.revision += 1
	cached.get_data(selection, navigation, field, grid, 10.1)
	check(cached.build_count == count + 1, "fog revision refreshes same-time cached prefix")
	var replacement: RefCounted = fog_fixture()
	replacement.revision = field.revision
	count = cached.build_count
	cached.get_data(selection, navigation, replacement, grid, 10.1)
	check(cached.build_count == count + 1, "same-layout same-revision field replacement refreshes cache")
	count = cached.build_count
	cached.get_data(selection, navigation, replacement, grid_fixture(), 10.1)
	check(cached.build_count == count + 1, "grid instance replacement invalidates cache identity")
	replacement.enabled = false
	check(cached.get_data(selection, navigation, replacement, grid, 10.1).is_empty(), "disabled visibility clears cached presentation")
