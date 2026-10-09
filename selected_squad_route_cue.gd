extends RefCounted
## Read-only minimap data for ONE explicitly identified squad representative.
## No path/occupancy queries, route compaction, or navigation/fog writes.

const Navigation = preload("res://friendly_navigation.gd")
const MAX_SELECTED: int = 64
const MAX_ROUTE_POINTS: int = 512
const MAX_DRAW_POINTS: int = 96
const MAX_FOG_CELL_CHECKS: int = 768
const MAX_GOAL_DIAMETER: float = 8.0
const EPSILON: float = 0.00001
const BORDER_INSET: float = 0.001

var build_count: int = 0
var cache_hit_count: int = 0
var _cache_key: Array = []
var _cached_data: Dictionary = {}

## Instance API for repeated draw calls. Simulation time refreshes moving ticks;
## detached validity/order/position snapshots catch paused edits immediately.
## Camera position and minimap dimensions do not affect this world-space data.
## Grid mutations MUST notify FriendlyNavigation.navigation_changed(), matching
## the production navigation contract. Rendering never inspects solid cells.
func get_data(selected: Array, navigation: RefCounted, field: RefCounted,
		grid: AStarGrid2D, simulation_time: float) -> Dictionary:
	if selected.is_empty() or selected.size() > MAX_SELECTED or navigation == null \
			or field == null or not field.enabled or grid == null or not is_finite(simulation_time):
		return _clear_cached_data()
	var key: Array = [simulation_time, navigation.get_instance_id(), navigation.revision,
		field.get_instance_id(), field.revision, field.bounds, field.cell_size,
		field.columns, field.rows, grid.get_instance_id()]
	var representative: Dictionary = {}
	var representative_id: int = 0
	for value: Variant in selected:
		# current_status is checked on EVERY draw, including a paused cache hit.
		if not value is Dictionary or not _eligible(value, navigation):
			return _clear_cached_data()
		var unit: Dictionary = value
		var node: Node3D = unit.node
		var identifier: int = node.get_instance_id()
		var parent: Node = node.get_parent()
		var parent_transform: Transform3D = parent.global_transform \
			if parent is Node3D and not node.top_level else Transform3D.IDENTITY
		# Every retained value is scalar/vector/transform data, never a unit,
		# node, mutable order dictionary, live route, or visibility object.
		key.append([identifier, str(unit.kind), str(unit.task), float(unit.hp),
			bool(unit.get("dead", false)), node.position, node.global_position,
			parent_transform, node.top_level, unit.goal, unit.planned, unit.nav_goal,
			unit.nav_requested, unit.nav_endpoint, unit.route.size(), unit.route[-1]])
		if representative.is_empty() or identifier < representative_id:
			representative = unit
			representative_id = identifier
	# Only the representative's interior route affects build(); other routes
	# contribute eligibility, length and tail. Snapshot its bounded vector list
	# rather than using a mutable reference or a collision-prone content hash.
	for point: Variant in representative.route:
		if not _finite_point(point):
			return _clear_cached_data()
	key.append(representative.route.duplicate())
	if key != _cache_key:
		_cached_data = build(selected, navigation, field, grid)
		_cache_key = key
		build_count += 1
	else:
		cache_hit_count += 1
	# A renderer/test may modify its result without poisoning future frames.
	return _cached_data.duplicate(true)

func _clear_cached_data() -> Dictionary:
	_cache_key.clear()
	_cached_data.clear()
	return {}

## Empty means no cue. Every selected member must qualify; do not prefilter the
## selection. The minimum instance ID is stable across selection-array reorder.
## known_route is a copied WORLD-SPACE prefix of that member's actual route.
## issued_destination is its own nav_requested, never a projected nav_endpoint.
## route_complete=false explicitly forbids joining known_endpoint to the marker.
static func build(selected: Array, navigation: RefCounted, field: RefCounted,
		grid: AStarGrid2D) -> Dictionary:
	if selected.is_empty() or selected.size() > MAX_SELECTED or navigation == null \
			or field == null or not field.enabled or grid == null:
		return {}
	var representative: Dictionary = {}
	var representative_id: int = 0
	var task: String = ""
	var low: Vector2 = Vector2(INF, INF)
	var high: Vector2 = Vector2(-INF, -INF)
	var seen: Dictionary = {}
	for value: Variant in selected:
		if not value is Dictionary or not _eligible(value, navigation):
			return {}
		var unit: Dictionary = value
		var node: Node3D = unit.node
		var identifier: int = node.get_instance_id()
		if seen.has(identifier):
			return {}
		seen[identifier] = true
		if not task.is_empty() and unit.task != task:
			return {}
		task = unit.task
		var requested: Vector3 = _to_world(node, unit.nav_requested)
		if not requested.is_finite() or not _inside(requested, field.bounds):
			return {}
		low = low.min(Vector2(requested.x, requested.z))
		high = high.max(Vector2(requested.x, requested.z))
		# A bounding-box diagonal is a conservative upper bound on diameter.
		if low.distance_to(high) > MAX_GOAL_DIAMETER:
			return {}
		if representative.is_empty() or identifier < representative_id:
			representative = unit
			representative_id = identifier
	var node: Node3D = representative.node
	var route: Array = representative.route
	# Scan only for malformed data, never inspect hidden navigation cells.
	for point: Variant in route:
		if not _finite_point(point) or not _to_world(node, point).is_finite():
			return {}
	var points: PackedVector3Array = PackedVector3Array()
	var budget: Dictionary = {"fog_checks": 0, "limited": false}
	var start_local: Vector3 = node.position
	var start_world: Vector3 = node.global_position
	var reason: String = "complete"
	if _probe(field.world_to_cell(start_world), field, budget):
		points.append(start_world)
	else:
		reason = "unknown"
	for finish_local: Vector3 in route:
		if reason != "complete":
			break
		var finish_world: Vector3 = _to_world(node, finish_local)
		if not (finish_world - start_world).is_finite() or not (finish_local - start_local).is_finite():
			return {}
		if start_world.distance_to(finish_world) <= EPSILON:
			start_local = finish_local
			start_world = finish_world
			continue
		if points.size() >= MAX_DRAW_POINTS:
			reason = "point_limit"
			break
		var prefix: Dictionary = _known_prefix(start_world, finish_world, field, budget)
		var fraction: float = prefix.fraction
		var known_world: Vector3 = start_world.lerp(finish_world, fraction)
		if fraction > 0.0:
			if points.is_empty() or points[-1].distance_to(known_world) > EPSILON:
				points.append(known_world)
		reason = prefix.reason
		start_local = finish_local
		start_world = finish_world
	return {
		"representative_id": representative_id,
		"representative_position": node.global_position,
		"selected_count": selected.size(),
		"task": task,
		"issued_destination": _to_world(node, representative.nav_requested),
		"known_route": points,
		"known_endpoint": points[-1] if not points.is_empty() else null,
		"route_complete": reason == "complete",
		"stop_reason": reason,
		"point_limit": MAX_DRAW_POINTS,
		"fog_cell_checks": budget.fog_checks,
	}

static func _eligible(unit: Dictionary, navigation: RefCounted) -> bool:
	if unit.get("kind", "") not in ["guard", "grenade", "siegecart"] \
			or unit.get("task", "") not in ["move", "attack_move"] \
			or unit.get("target") != null or bool(unit.get("dead", false)):
		return false
	var hp: Variant = unit.get("hp")
	var node: Variant = unit.get("node")
	if not (hp is int or hp is float) or not is_finite(float(hp)) or float(hp) <= 0.0 \
			or not is_instance_valid(node) or not node is Node3D \
			or node.is_queued_for_deletion() or not node.is_inside_tree() \
			or not node.position.is_finite() or not node.global_position.is_finite():
		return false
	if navigation.current_status(unit) != Navigation.MOVING:
		return false
	var route: Variant = unit.get("route")
	if not route is Array or route.is_empty() or route.size() > MAX_ROUTE_POINTS \
			or not _finite_point(unit.get("goal")) or not _finite_point(unit.get("planned")) \
			or not _finite_point(unit.get("nav_goal")) \
			or not _finite_point(unit.get("nav_requested")) \
			or not _finite_point(unit.get("nav_endpoint")) \
			or not _finite_point(route[-1]):
		return false
	return route[-1].distance_to(unit.nav_endpoint) <= EPSILON \
		and node.position.distance_to(unit.nav_endpoint) > EPSILON

## Exact supercover traversal of fog cells, including diagonal corner touches.
## A boundary-aligned leg also checks the cells on its other side. The returned
## fraction stays slightly inside the last known cell, not on an unknown edge.
static func _known_prefix(start: Vector3, finish: Vector3, field: RefCounted,
		budget: Dictionary) -> Dictionary:
	var cell: Vector2i = field.world_to_cell(start)
	if not _probe(cell, field, budget):
		return _stopped(0.0, start, finish, budget)
	var delta: Vector2 = Vector2(finish.x - start.x, finish.z - start.z)
	var step: Vector2i = Vector2i(int(signf(delta.x)), int(signf(delta.y)))
	var scale: float = field.cell_size
	var origin: Vector2 = field.bounds.position
	var aligned_x: bool = delta.x == 0.0 and _internal_boundary(start.x, origin.x, scale, field.columns)
	var aligned_z: bool = delta.y == 0.0 and _internal_boundary(start.z, origin.y, scale, field.rows)
	if not _probe_parallel(cell, aligned_x, aligned_z, field, budget):
		return _stopped(0.0, start, finish, budget)
	var stride: Vector2 = Vector2(INF if delta.x == 0.0 else absf(scale / delta.x),
		INF if delta.y == 0.0 else absf(scale / delta.y))
	var boundary: Vector2 = origin + Vector2(cell) * scale
	if step.x > 0:
		boundary.x += scale
	if step.y > 0:
		boundary.y += scale
	var next: Vector2 = Vector2(INF if delta.x == 0.0 else (boundary.x - start.x) / delta.x,
		INF if delta.y == 0.0 else (boundary.y - start.z) / delta.y)
	while minf(next.x, next.y) <= 1.0:
		var crossing: float = minf(next.x, next.y)
		# Maximum map edges (and a leg ending on its current cell's lower edge)
		# remain in the existing cell; do not probe outside past the endpoint.
		if crossing >= 1.0 and field.world_to_cell(finish) == cell:
			break
		# Equal crossings touch both side cells, even when the diagonal cell is known.
		if absf(next.x - next.y) <= 0.0000001:
			if not _probe(cell + Vector2i(step.x, 0), field, budget) \
					or not _probe(cell + Vector2i(0, step.y), field, budget):
				return _stopped(crossing, start, finish, budget)
			cell += step
			next += stride
		elif next.x < next.y:
			cell.x += step.x
			next.x += stride.x
		else:
			cell.y += step.y
			next.y += stride.y
		# Exact maximum world edge belongs to the final cell, not an outside cell.
		if crossing >= 1.0 and field.world_to_cell(finish) != cell:
			break
		if not _probe(cell, field, budget) or not _probe_parallel(cell, aligned_x, aligned_z, field, budget):
			return _stopped(crossing, start, finish, budget)
	if not _probe(field.world_to_cell(finish), field, budget):
		return _stopped(1.0, start, finish, budget)
	return {"fraction": 1.0, "reason": "complete"}

static func _probe(cell: Vector2i, field: RefCounted, budget: Dictionary) -> bool:
	if budget.fog_checks >= MAX_FOG_CELL_CHECKS:
		budget.limited = true
		return false
	budget.fog_checks += 1
	return field.cell_state(cell) != 0

static func _probe_parallel(cell: Vector2i, aligned_x: bool, aligned_z: bool,
		field: RefCounted, budget: Dictionary) -> bool:
	if aligned_x and not _probe(cell + Vector2i(-1, 0), field, budget):
		return false
	if aligned_z and not _probe(cell + Vector2i(0, -1), field, budget):
		return false
	return true

static func _stopped(fraction: float, start: Vector3, finish: Vector3, budget: Dictionary) -> Dictionary:
	var length: float = Vector2(finish.x - start.x, finish.z - start.z).length()
	var safe_fraction: float = maxf(0.0, fraction - BORDER_INSET / maxf(length, BORDER_INSET))
	return {"fraction": safe_fraction, "reason": "fog_limit" if budget.limited else "unknown"}

static func _internal_boundary(value: float, origin: float, scale: float, count: int) -> bool:
	var coordinate: float = (value - origin) / scale
	return coordinate > 0.0 and coordinate < float(count) and absf(coordinate - roundf(coordinate)) < 0.000001

static func _inside(point: Vector3, rectangle: Rect2) -> bool:
	return point.x >= rectangle.position.x and point.z >= rectangle.position.y \
		and point.x <= rectangle.end.x and point.z <= rectangle.end.y

static func _to_world(node: Node3D, point: Vector3) -> Vector3:
	var parent: Node = node.get_parent()
	return parent.to_global(point) if parent is Node3D and not node.top_level else point

static func _finite_point(value: Variant) -> bool:
	return value is Vector3 and value.is_finite()
