extends RefCounted
## Newly implemented recovery code for verified RECLAMATION v0.10.
## This is not a recovered copy of the missing late-version helper.
## Main calls begin_frame once per simulation step and navigation_changed after
## grid edits. Orders own goal/task/target; this helper owns transient route state.

const ARRIVED := "arrived"
const PENDING := "pending"
const MOVING := "moving"
const BLOCKED := "blocked"
const WORK_WAITING := "work_waiting"
const MAX_ATTEMPTS := 3
const MAX_QUERIES_PER_FRAME := 8
const MAX_APPROACH_CANDIDATES := 64
const RETRY_SECONDS := 0.5
const EPSILON := 0.00001

var revision: int = 0
var queries_this_frame: int = 0
var total_queries: int = 0
var clock_seconds: float = 0.0
# Transient, at most one cell per active worker. Rebuilt from ordinary orders
# after a checkpoint load; actor coordinates remain authoritative.
var work_reservations: Dictionary = {}
var actors: Array = []

func begin_frame(dt: float = 0.0, live_actors: Array = []) -> void:
	queries_this_frame = 0
	if is_finite(dt) and dt > 0.0:
		clock_seconds += dt
	actors = live_actors
	_prune_reservations()

func navigation_changed() -> void:
	revision += 1

## Call for a new explicit order, including an identical repeated destination.
func invalidate_order(unit: Dictionary) -> void:
	release_unit(unit)
	unit["planned"] = Vector3.INF
	unit["route"] = []
	unit["nav_status"] = PENDING
	unit["nav_reason"] = ""
	unit["nav_attempts"] = 0
	unit.erase("nav_goal")

func current_status(unit: Dictionary) -> String:
	if not _same_order(unit) or int(unit.get("nav_revision", -1)) != revision:
		return PENDING
	return str(unit.get("nav_status", PENDING))

func is_arrived(unit: Dictionary) -> bool:
	return current_status(unit) == ARRIVED and unit.node.position.distance_to(unit.get("nav_endpoint", Vector3.INF)) <= EPSILON

## Work requires this worker's reachable, reserved cell on the target's exact
## perimeter. Generic arrival at a projected move goal is not work access.
func is_work_arrived(unit: Dictionary, grid: AStarGrid2D) -> bool:
	var target := _work_target(unit)
	if target.is_empty() or not is_arrived(unit): return false
	var cell := cell_of(unit.node.position)
	if not cell_open(grid, cell) or not work_reservations.has(cell): return false
	if work_reservations[cell].get("node") != unit.node: return false
	var footprint := work_footprint(target)
	var vertical_edge := (cell.x == footprint.position.x - 1 or cell.x == footprint.end.x) and cell.y >= footprint.position.y and cell.y < footprint.end.y
	var horizontal_edge := (cell.y == footprint.position.y - 1 or cell.y == footprint.end.y) and cell.x >= footprint.position.x and cell.x < footprint.end.x
	return vertical_edge or horizontal_edge

func status_text(unit: Dictionary) -> String:
	if current_status(unit) == WORK_WAITING:
		return "作業場所の空き待ち"
	return "経路なし / 通路を開ける" if current_status(unit) == BLOCKED else "経路を確認中" if current_status(unit) == PENDING else ""

func advance(unit: Dictionary, grid: AStarGrid2D, dt: float, speed: float, hold: bool = false) -> void:
	if not is_instance_valid(unit.get("node")) or not is_finite(dt) or not is_finite(speed) or dt < 0.0 or speed < 0.0:
		return
	if not _same_order(unit):
		_reset(unit, unit.get("goal", Vector3.INF))
	elif int(unit.get("nav_revision", -1)) != revision:
		_reset(unit, unit.get("nav_requested", unit.goal))
	if unit.get("task", "") in ["build", "repair", "site"] and unit.get("target") is Dictionary and (float(unit.target.get("radius", 0.0)) > 0.0 or unit.target.get("nav_half_extents", Vector2.ZERO) != Vector2.ZERO) and _work_target(unit).is_empty():
		release_unit(unit)
		_block(unit, "target_removed")
		return
	# Holding to fire never counts as arrival at a work destination.
	if hold:
		return
	if unit.nav_status == WORK_WAITING:
		if clock_seconds < float(unit.nav_retry_at):
			return
		unit.nav_status = PENDING
	if unit.nav_status == ARRIVED:
		if is_arrived(unit):
			return
		_reset(unit, unit.nav_requested)
	if unit.nav_status == BLOCKED:
		if int(unit.nav_attempts) >= MAX_ATTEMPTS or clock_seconds < float(unit.nav_retry_at):
			return
		unit.nav_status = PENDING
	if unit.nav_status == PENDING:
		if queries_this_frame >= MAX_QUERIES_PER_FRAME:
			return
		_plan(unit, grid)
	if unit.nav_status != MOVING:
		return
	# Another actor can stop on the endpoint while this worker is en route.
	# Reallocate through the ordinary bounded search; never push either actor.
	if not _work_target(unit).is_empty() and not _slot_available(unit.nav_endpoint, unit):
		_wait_for_work(unit)
		return
	# An emptied/externally consumed path must be replanned, never substituted
	# by a straight segment to goal. Arrival is set only by consuming its end.
	if unit.route.is_empty():
		_block(unit, "route_consumed")
		return
	var budget := dt * speed
	while not unit.route.is_empty():
		var start: Vector3 = unit.node.position
		var waypoint: Vector3 = unit.route[0]
		var distance := start.distance_to(waypoint)
		if not segment_open(grid, start, waypoint):
			_block(unit, "segment_blocked")
			return
		if distance <= EPSILON:
			unit.node.position = waypoint
			unit.route.pop_front()
		elif budget <= 0.0:
			return
		else:
			var travel := minf(budget, distance)
			var direction := (waypoint - start) / distance
			var destination := waypoint if travel >= distance else start + direction * travel
			# Checking the complete waypoint segment above also catches a changed
			# grid even when the caller has not yet advanced its revision.
			unit.node.position = destination
			unit.node.rotation.y = atan2(-direction.x, -direction.z)
			budget -= travel
			if travel >= distance:
				unit.route.pop_front()
			else:
				return
	if unit.node.position.distance_to(unit.nav_endpoint) <= EPSILON:
		unit.nav_status = ARRIVED
	else:
		_block(unit, "route_consumed")

func _reset(unit: Dictionary, requested: Vector3) -> void:
	release_unit(unit)
	unit["route"] = []
	unit["goal"] = requested
	unit["planned"] = requested
	unit["nav_goal"] = requested
	unit["nav_requested"] = requested
	unit["nav_task"] = unit.get("task", "idle")
	unit["nav_target_node"] = _target_node(unit)
	unit["nav_revision"] = revision
	unit["nav_status"] = PENDING
	unit["nav_reason"] = ""
	unit["nav_attempts"] = 0
	unit["nav_retry_at"] = 0.0
	unit["nav_endpoint"] = Vector3.INF
	unit["nav_search_active"] = false
	unit["nav_candidates"] = []
	unit["nav_candidate_index"] = 0
	unit["nav_reachable_cells"] = {}
	unit["nav_unreachable_cells"] = {}

func _same_order(unit: Dictionary) -> bool:
	return unit.has("nav_goal") and unit.get("planned", Vector3.INF) != Vector3.INF and unit.get("goal") == unit.nav_goal and unit.get("task", "idle") == unit.get("nav_task") and _target_node(unit) == unit.get("nav_target_node")

func _target_node(unit: Dictionary) -> Variant:
	var target: Variant = unit.get("target")
	return target.get("node") if target is Dictionary else null

func _plan(unit: Dictionary, grid: AStarGrid2D) -> void:
	var start: Vector3 = unit.node.position
	var requested: Vector3 = unit.nav_requested
	if not bool(unit.get("nav_search_active", false)):
		unit.nav_attempts += 1
		if not start.is_finite() or not requested.is_finite():
			_block(unit, "invalid_goal")
			return
		if not cell_open(grid, cell_of(start)):
			_block(unit, "source_solid")
			return
		var target := _work_target(unit)
		var candidates: Array = []
		if not target.is_empty():
			# A resumed checkpoint may contain a previously snapped, unreachable
			# goal. Derive work approaches from the actual target, not that goal.
			candidates = _work_perimeter(grid, target, start)
		else:
			var endpoint := _endpoint(grid, requested, start)
			if endpoint.is_finite():
				candidates.append(endpoint)
		if candidates.is_empty():
			_block(unit, "destination_solid")
			return
		unit["nav_candidates"] = candidates
		unit["nav_candidate_index"] = 0
		unit["nav_search_active"] = true
		unit["nav_occupied_candidate"] = false
	var source := cell_of(start)
	if not cell_open(grid, source):
		_block(unit, "source_solid")
		return
	# Each candidate uses the same shared AStar budget. Continue a partial
	# search next step without consuming a retry or moving the waiting unit.
	while int(unit.nav_candidate_index) < unit.nav_candidates.size():
		if queries_this_frame >= MAX_QUERIES_PER_FRAME:
			return
		var endpoint: Vector3 = unit.nav_candidates[unit.nav_candidate_index]
		unit.nav_candidate_index += 1
		var destination := cell_of(endpoint)
		if not cell_open(grid, destination):
			continue
		var is_work := not _work_target(unit).is_empty()
		var occupied := is_work and not _slot_available(endpoint, unit)
		# Occupancy alone does not prove access. A sealed building can have an
		# idle actor inside its cage; outsiders must still report no route.
		# Cache bounded connectivity facts for this order/revision so a proven
		# work-space wait does not keep issuing the same path query.
		if is_work and unit.nav_unreachable_cells.has(destination): continue
		if occupied and unit.nav_reachable_cells.has(destination):
			unit["nav_occupied_candidate"] = true
			continue
		var route: Array = []
		if source != destination:
			queries_this_frame += 1
			total_queries += 1
			var points := grid.get_id_path(source, destination, false)
			if points.is_empty():
				if is_work: unit.nav_unreachable_cells[destination] = true
				continue
			# Include the source center: fractional starts must not cut corners.
			for point in points:
				route.append(Vector3(point.x, start.y, point.y))
		if is_work: unit.nav_reachable_cells[destination] = true
		if occupied:
			unit["nav_occupied_candidate"] = true
			continue
		if route.is_empty() or route.back().distance_to(endpoint) > EPSILON:
			route.append(endpoint)
		# Only a proven reachable candidate becomes the movement/work goal.
		if not _work_target(unit).is_empty():
			_reserve_work(unit, endpoint)
		unit["nav_endpoint"] = endpoint
		unit["goal"] = endpoint
		unit["planned"] = endpoint
		unit["nav_goal"] = endpoint
		unit["route"] = route
		unit["nav_status"] = MOVING
		unit["nav_reason"] = ""
		unit["nav_search_active"] = false
		return
	if bool(unit.get("nav_occupied_candidate", false)):
		_wait_for_work(unit)
	else:
		_block(unit, "no_path")

func _work_target(unit: Dictionary) -> Dictionary:
	if unit.get("task", "") not in ["build", "repair", "site"]:
		return {}
	var target: Variant = unit.get("target")
	if target is not Dictionary or not _live(target):
		return {}
	if unit.get("task") == "site":
		var half: Vector2 = target.get("nav_half_extents", Vector2.ZERO)
		return target if half.is_finite() and half.x > 0.0 and half.y > 0.0 and not target.get("reclaimed", false) else {}
	var radius := float(target.get("radius", 0.0))
	return target if is_finite(radius) and radius > 0.0 else {}

## Mission facilities retain the same physical pad before/after restoration.
## Art and physics do not participate in the authoritative navigation grid.
static func site_half_extents(kind: String, mission_mode: String) -> Vector2:
	if kind == "abandoned_depot": return Vector2(1.8, 1.8)
	if kind == "pump" and mission_mode == "restore": return Vector2(2.12, 2.12)
	if kind in ["generator", "pump", "substation"]: return Vector2(2.1, 1.75)
	return Vector2.ZERO

static func footprint_rect(position: Vector3, half_extents: Vector2) -> Rect2i:
	var half := half_extents + Vector2(0.3, 0.3)
	var low := Vector2i(floori(position.x - half.x), floori(position.z - half.y))
	var high := Vector2i(ceili(position.x + half.x), ceili(position.z + half.y))
	return Rect2i(low, high - low + Vector2i.ONE)

static func work_footprint(target: Dictionary) -> Rect2i:
	var half: Vector2 = target.get("nav_half_extents", Vector2.ONE * float(target.get("radius", 0.0)))
	return footprint_rect(target.node.position, half)

## Orthogonally adjacent cells around the exact padded building/site footprint
## used by main.rebuild_navigation(). Never expand beyond this perimeter:
## a truly enclosed target cannot be worked from the outside of its cage.
func _work_perimeter(grid: AStarGrid2D, target: Dictionary, start: Vector3) -> Array:
	var footprint := work_footprint(target)
	var left := footprint.position.x
	var right := footprint.end.x - 1
	var top := footprint.position.y
	var bottom := footprint.end.y - 1
	var candidates: Array = []
	for x in range(left, right + 1):
		for z in [top - 1, bottom + 1]:
			if cell_open(grid, Vector2i(x, z)):
				candidates.append(Vector3(x, start.y, z))
	for z in range(top, bottom + 1):
		for x in [left - 1, right + 1]:
			if cell_open(grid, Vector2i(x, z)):
				candidates.append(Vector3(x, start.y, z))
	candidates.sort_custom(func(a: Vector3, b: Vector3):
		var a_distance := start.distance_squared_to(a)
		var b_distance := start.distance_squared_to(b)
		if a_distance != b_distance:
			return a_distance < b_distance
		return a.x < b.x if a.x != b.x else a.z < b.z)
	return candidates.slice(0, MAX_APPROACH_CANDIDATES)

func _block(unit: Dictionary, reason: String) -> void:
	release_unit(unit)
	unit["nav_search_active"] = false
	unit["route"] = []
	unit["nav_status"] = BLOCKED
	unit["nav_reason"] = reason
	unit["nav_retry_at"] = clock_seconds + RETRY_SECONDS * pow(2.0, maxi(0, int(unit.nav_attempts) - 1))
	unit["nav_reachable_cells"] = {}
	unit["nav_unreachable_cells"] = {}

## Release on explicit order, death, target removal, or scene replacement.
## A queued deletion is already dead for reservation purposes.
func release_unit(unit: Dictionary) -> void:
	var cell: Variant = unit.get("nav_work_cell")
	if cell != null and work_reservations.has(cell):
		var owner: Dictionary = work_reservations[cell]
		if owner.get("node") == unit.get("node"):
			work_reservations.erase(cell)
	unit.erase("nav_work_cell")

func clear_reservations() -> void:
	for owner in work_reservations.values():
		owner.erase("nav_work_cell")
	work_reservations.clear()
	actors = []

func _live(actor: Dictionary) -> bool:
	var node: Variant = actor.get("node")
	return is_instance_valid(node) and not node.is_queued_for_deletion() and float(actor.get("hp", 1.0)) > 0.0

func _prune_reservations() -> void:
	for cell in work_reservations.keys():
		var owner: Dictionary = work_reservations[cell]
		if not _live(owner) or _work_target(owner).is_empty() or not _same_order(owner):
			release_unit(owner)

func _slot_available(endpoint: Vector3, unit: Dictionary) -> bool:
	var cell := cell_of(endpoint)
	if work_reservations.has(cell) and work_reservations[cell].get("node") != unit.node:
		return false
	# Also respect units that have finished an earlier job and remain standing
	# here. This scan is bounded by the live friendly population, not history.
	for actor in actors:
		if actor.get("node") == unit.node or not _live(actor): continue
		# Passing traffic is not an end-position claim. Its own reserved work
		# endpoint is already excluded above; treating a passer as stationary
		# would repeatedly cancel adjacent builders' valid approaches.
		if actor.get("nav_status", "") == MOVING and _same_order(actor): continue
		if cell_of(actor.node.position) == cell: return false
	return true

func _reserve_work(unit: Dictionary, endpoint: Vector3) -> void:
	release_unit(unit)
	var cell := cell_of(endpoint)
	work_reservations[cell] = unit
	unit["nav_work_cell"] = cell

func _wait_for_work(unit: Dictionary) -> void:
	release_unit(unit)
	unit["route"] = []
	unit["nav_status"] = WORK_WAITING
	unit["nav_reason"] = "work_positions_occupied"
	unit["nav_search_active"] = false
	unit["nav_attempts"] = 0
	unit["nav_endpoint"] = Vector3.INF
	unit["nav_retry_at"] = clock_seconds + RETRY_SECONDS

## Production rally points need only a small local spread. Account for both
## standing units and already-issued movement destinations, so a production
## batch cannot claim the same cell before its first simulation step. Routing
## still proves the selected destination through the normal eight-query budget.
func rally_destination(grid: AStarGrid2D, requested: Vector3, unit: Dictionary, live_actors: Array) -> Vector3:
	var candidates: Array[Vector3] = []
	var anchor := _endpoint(grid, requested, unit.node.position)
	if not anchor.is_finite(): return requested
	var center := cell_of(anchor)
	for x in range(-4, 5):
		for z in range(-4, 5):
			var cell := center + Vector2i(x, z)
			var candidate := Vector3(cell.x, unit.node.position.y, cell.y)
			if cell_open(grid, cell) and segment_open(grid, anchor, candidate):
				candidates.append(candidate)
	candidates.sort_custom(func(a: Vector3, b: Vector3):
		var a_distance := a.distance_squared_to(requested)
		var b_distance := b.distance_squared_to(requested)
		if a_distance != b_distance: return a_distance < b_distance
		return a.x < b.x if a.x != b.x else a.z < b.z)
	for candidate in candidates:
		var occupied := work_reservations.has(cell_of(candidate))
		for actor in live_actors:
			if actor.get("node") == unit.node or not _live(actor): continue
			if cell_of(actor.node.position) == cell_of(candidate) or (actor.get("task", "idle") in ["move", "attack_move"] and cell_of(actor.get("goal", actor.node.position)) == cell_of(candidate)):
				occupied = true
				break
		if not occupied:
			return candidate
	# A completely occupied rally area stays at its spawn. It must not choose
	# an already occupied destination merely to satisfy the rally instruction.
	return unit.node.position

## Preserve a free fractional goal. A solid building destination resolves to
## the nearest free perimeter ring, matching v0.10's approach convention.
## A free but sealed destination stays blocked; it is never silently replaced.
func _endpoint(grid: AStarGrid2D, requested: Vector3, start: Vector3) -> Vector3:
	var center := cell_of(requested)
	if not grid.is_in_boundsv(center):
		return Vector3.INF
	if cell_open(grid, center):
		return Vector3(requested.x, start.y, requested.z)
	for radius in range(1, 12):
		var best := Vector3.INF
		var best_distance := INF
		for x in range(-radius, radius + 1):
			for z in range(-radius, radius + 1):
				if absi(x) != radius and absi(z) != radius:
					continue
				var cell := center + Vector2i(x, z)
				if not cell_open(grid, cell):
					continue
				var candidate := Vector3(cell.x, start.y, cell.y)
				var distance := start.distance_squared_to(candidate)
				if distance < best_distance:
					best = candidate
					best_distance = distance
		if best.is_finite():
			return best
	return Vector3.INF

static func cell_of(point: Vector3) -> Vector2i:
	return Vector2i(floori(point.x + 0.5), floori(point.z + 0.5))

static func cell_open(grid: AStarGrid2D, cell: Vector2i) -> bool:
	return grid.is_in_boundsv(cell) and not grid.is_point_solid(cell)

## Exact grid traversal, not point sampling: a long step cannot tunnel through
## a thin wall. At a corner both side cells must be open (no diagonal squeeze).
static func segment_open(grid: AStarGrid2D, start: Vector3, end: Vector3) -> bool:
	if not start.is_finite() or not end.is_finite():
		return false
	var cell := cell_of(start)
	var target := cell_of(end)
	if not cell_open(grid, cell) or not cell_open(grid, target):
		return false
	var delta := Vector2(end.x - start.x, end.z - start.z)
	var step := Vector2i(int(signf(delta.x)), int(signf(delta.y)))
	var stride := Vector2(INF if delta.x == 0.0 else absf(1.0 / delta.x), INF if delta.y == 0.0 else absf(1.0 / delta.y))
	var boundary := Vector2(cell.x + (0.5 if step.x > 0 else -0.5), cell.y + (0.5 if step.y > 0 else -0.5))
	var next := Vector2(INF if delta.x == 0.0 else (boundary.x - start.x) / delta.x, INF if delta.y == 0.0 else (boundary.y - start.z) / delta.y)
	while cell != target:
		if is_equal_approx(next.x, next.y):
			if not cell_open(grid, cell + Vector2i(step.x, 0)) or not cell_open(grid, cell + Vector2i(0, step.y)):
				return false
			cell += step
			next += stride
		elif next.x < next.y:
			cell.x += step.x
			next.x += stride.x
		else:
			cell.y += step.y
			next.y += stride.y
		if not cell_open(grid, cell):
			return false
	return true
