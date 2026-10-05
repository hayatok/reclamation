extends RefCounted
## Enemy-only scheduler. Count actual AStar calls, including alternate approaches.
## Failed requests are valid only for the exact source/goal and map revision.
const MAX_QUERIES_PER_STEP: int = 32
const MAX_NEGATIVE_RESULTS: int = 4096
const REPATH_SECONDS: float = 1.2
# Main permits an attack after a consumed building approach within this gap.
# Candidate cells must satisfy the same unchanged distance, not a distant
# square-footprint corner that would be chosen again on every repath.
const EMPTY_ROUTE_ATTACK_REACH: float = 2.5

var revision: int = 0
var queries_this_step: int = 0
var total_queries: int = 0
var negative_hits: int = 0
var approach_cells: Dictionary = {}
var _negative: Dictionary = {}
var _pending: Array[Dictionary] = []
var _sequence: int = 0
var _ticket: int = 0

func begin_step(grid: AStarGrid2D) -> void:
	queries_this_step = 0
	# FIFO grants each request one probe before its next alternate approach.
	# Requests submitted during this step enter at the tail, for the next step.
	var count := _pending.size()
	var consumed := 0
	while consumed < count and queries_this_step < MAX_QUERIES_PER_STEP:
		var entry: Dictionary = _pending[consumed]
		var job: Dictionary = entry.job
		consumed += 1
		var enemy: Dictionary = entry.enemy
		if not is_instance_valid(enemy.get("node")) or enemy.get("dead", false) or enemy.get("enemy_nav", {}).get("ticket") != job.ticket:
			continue
		if int(job.revision) != revision:
			continue
		var source := cell_of(enemy.node.position)
		if source != job.source:
			job.source = source
			job.index = 0
		if _probe(grid, job):
			_finish(enemy, job)
		else:
			_pending.append(entry)
	if consumed > 0:
		_pending = _pending.slice(consumed)

func navigation_changed() -> void:
	revision += 1
	_negative.clear()
	approach_cells.clear()
	_pending.clear()

func update_route(enemy: Dictionary, target: Dictionary, grid: AStarGrid2D, dt: float) -> void:
	enemy.path_cd = maxf(0.0, float(enemy.get("path_cd", 0.0)) - dt)
	var key := _goal_key(target)
	var source := cell_of(enemy.node.position)
	var job: Dictionary = enemy.get("enemy_nav", {})
	var changed: bool = job.is_empty() or job.key != key or int(job.revision) != revision
	if not changed and job.queued:
		return
	if not changed and enemy.path_cd > 0.0:
		return
	if not changed and job.blocked and job.source == source:
		# An empty failed path is a completed result, never a reason to query.
		enemy.path_cd = _cooldown(enemy)
		return
	if changed and (job.is_empty() or int(job.revision) != revision or job.target_id != target.node.get_instance_id()):
		enemy.route.clear()
	if changed and not job.is_empty() and job.queued and int(job.revision) == revision:
		# A moving goal refreshes its existing FIFO slot instead of putting late
		# pursuers at the back on every crossed grid cell.
		job.merge(_job(grid, enemy.node.position, target), true)
		return
	job = _job(grid, enemy.node.position, target)
	job["queued"] = true
	job["blocked"] = false
	enemy["enemy_nav"] = job
	if not enemy.has("enemy_nav_phase"):
		enemy["enemy_nav_phase"] = _sequence % 24
		_sequence += 1
	_pending.append({"enemy": enemy, "job": job})

## Retained for main's focused route fixtures; obeys the same global call cap.
func route_now(grid: AStarGrid2D, start: Vector3, target: Dictionary) -> Array:
	var job := _job(grid, start, target)
	while queries_this_step < MAX_QUERIES_PER_STEP:
		if _probe(grid, job):
			return job.route
	return []

func _finish(enemy: Dictionary, job: Dictionary) -> void:
	enemy.route = job.route
	enemy.path_cd = _cooldown(enemy)
	job.queued = false
	job.blocked = job.route.is_empty()

func _cooldown(enemy: Dictionary) -> float:
	# Deterministic scheduling, independent of node IDs, render rate and all RNGs.
	return REPATH_SECONDS - 0.3 + float(enemy.get("enemy_nav_phase", 0)) * 0.3 / 23.0

func _job(grid: AStarGrid2D, start: Vector3, target: Dictionary) -> Dictionary:
	_ticket += 1
	var source := cell_of(start)
	var key := _goal_key(target)
	var candidates: Array[Vector2i] = []
	var goal: Vector3 = target.node.position
	var center := cell_of(goal)
	var solid_building := not _open(grid, center) and float(target.get("radius", 0.0)) > 0.0
	var maximum_reach := float(target.get("radius", 0.0)) + EMPTY_ROUTE_ATTACK_REACH if solid_building else INF
	var direct := _open_cell(grid, goal, start)
	if _open(grid, direct) and _within_reach(direct, goal, maximum_reach):
		candidates.append(direct)
	var cached: Variant = approach_cells.get(key)
	if cached is Vector2i and _open(grid, cached) and cached not in candidates and _within_reach(cached, goal, maximum_reach):
		candidates.append(cached)
	# An open unit destination must really be reached. The alternate-perimeter
	# recovery is for a solid building's nearest free tile trapped in a pocket.
	if not _open(grid, center):
		var radius := ceili(float(target.get("radius", 0.7)) + 2.0)
		var alternatives: Array[Vector2i] = []
		for x in range(-radius, radius + 1):
			for z in range(-radius, radius + 1):
				var cell := center + Vector2i(x, z)
				if _open(grid, cell) and cell not in candidates and _within_reach(cell, goal, maximum_reach):
					alternatives.append(cell)
		alternatives.sort_custom(func(a, b): return a.distance_to(center) * 5 + a.distance_to(source) < b.distance_to(center) * 5 + b.distance_to(source))
		candidates.append_array(alternatives)
	return {"ticket": _ticket, "key": key, "revision": revision, "target_id": target.node.get_instance_id(), "source": source, "candidates": candidates, "index": 0, "route": []}

func _within_reach(cell: Vector2i, goal: Vector3, maximum_reach: float) -> bool:
	return Vector3(cell.x, goal.y, cell.y).distance_to(goal) < maximum_reach

func _probe(grid: AStarGrid2D, job: Dictionary) -> bool:
	var negative_key := str(job.source) + ":" + str(job.key)
	if _negative.has(negative_key):
		negative_hits += 1
		return true
	if not _open(grid, job.source):
		_remember_failure(negative_key)
		return true
	while job.index < job.candidates.size():
		if queries_this_step >= MAX_QUERIES_PER_STEP:
			return false
		var destination: Vector2i = job.candidates[job.index]
		job.index += 1
		queries_this_step += 1
		total_queries += 1
		var points := grid.get_id_path(job.source, destination, false)
		if not points.is_empty():
			var route: Array = []
			for point in points:
				route.append(Vector3(point.x, 0, point.y))
			# Keep the source center so a fractional starting point cannot jump
			# directly over a blocked corner to the second path cell.
			job.route = route
			if approach_cells.size() >= MAX_NEGATIVE_RESULTS and not approach_cells.has(job.key):
				approach_cells.erase(approach_cells.keys()[0])
			approach_cells[job.key] = destination
			return true
		# One expensive probe per visit keeps large sealed-building requests fair.
		if job.index < job.candidates.size():
			return false
	_remember_failure(negative_key)
	return true

func _remember_failure(key: String) -> void:
	if _negative.size() >= MAX_NEGATIVE_RESULTS:
		_negative.erase(_negative.keys()[0])
	_negative[key] = true

func _goal_key(target: Dictionary) -> String:
	return "%d:%s:%s" % [target.node.get_instance_id(), cell_of(target.node.position), target.get("radius", 0.7)]

static func cell_of(position: Vector3) -> Vector2i:
	return Vector2i(roundi(position.x), roundi(position.z))

static func _open(grid: AStarGrid2D, cell: Vector2i) -> bool:
	return grid.is_in_boundsv(cell) and not grid.is_point_solid(cell)

static func _open_cell(grid: AStarGrid2D, position: Vector3, approach: Vector3) -> Vector2i:
	var center := cell_of(position)
	if _open(grid, center):
		return center
	for radius in range(1, 12):
		var nearest := center
		var distance := INF
		for x in range(-radius, radius + 1):
			for z in range(-radius, radius + 1):
				var cell := center + Vector2i(x, z)
				if not _open(grid, cell):
					continue
				var candidate_distance := Vector3(cell.x, 0, cell.y).distance_squared_to(approach)
				if candidate_distance < distance:
					distance = candidate_distance
					nearest = cell
		if distance < INF:
			return nearest
	return center
