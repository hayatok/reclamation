extends RefCounted
## One source for the existing eight rendered district shells, in original order.
## Keep these values/call order unchanged: world art also uses the building index.
const SHELLS: Array[Dictionary] = [
	{"p": Vector3(-23,0,-23), "size": Vector3(12,11.2,11), "stories": 3, "damaged": true},
	{"p": Vector3(-9.5,0,-26.8), "size": Vector3(10,8.4,8), "stories": 2, "damaged": false},
	{"p": Vector3(7.8,0,-26.5), "size": Vector3(12,14.6,8.4), "stories": 4, "damaged": true},
	{"p": Vector3(23.5,0,-22.5), "size": Vector3(11,10.0,11), "stories": 3, "damaged": true},
	{"p": Vector3(-28.1,0,-7), "size": Vector3(6.4,8.5,14), "stories": 2, "damaged": true},
	{"p": Vector3(28.2,0,-5), "size": Vector3(6.4,6.8,13), "stories": 2, "damaged": false},
	{"p": Vector3(-27.5,0,14.5), "size": Vector3(6.0,4.1,7), "stories": 1, "damaged": true},
	{"p": Vector3(28,0,14), "size": Vector3(5.5,3.2,6.5), "stories": 1, "damaged": true},
]

## Bounded first prototype: west middle shell only. All-eight blocking strands
## M3's outer_parts pocket and its fixed boss spawn; do not enable it casually.
const BLOCKING_SHELL_INDICES: Array[int] = [4]
const WEST: int = 0
const NORTH: int = 1
const EAST: int = 2
# Rect2i end is exclusive. These are the original integer spawn strips only.
const ENTRY_REGIONS: Array[Rect2i] = [
	Rect2i(-29, -20, 3, 36),
	Rect2i(-24, -29, 49, 3),
	Rect2i(27, -20, 3, 36),
]

var _active: bool = false
var _entry_cells: Dictionary = {}
var _rim_cells: Dictionary = {}

static func blockers_for(mission_index: int) -> Array:
	var result: Array = []
	if mission_index not in [0, 2]:
		return result
	for index: int in BLOCKING_SHELL_INDICES:
		var shell: Dictionary = SHELLS[index]
		# Main's existing terrain contract adds .4 then floor/ceil inclusive.
		# Reuse that same record for navigation, placement rejection and minimap.
		result.append({"pos": shell.p, "size": shell.size})
	return result

## Call once after every completed navigation rebuild, including player builds,
## destruction and checkpoint restoration. Never query AStar or RNG here.
func rebuild_spawn_cache(grid: AStarGrid2D, mission_index: int) -> void:
	_active = mission_index in [0, 2]
	_entry_cells.clear()
	_rim_cells.clear()
	if not _active:
		return
	for side in range(3):
		var entry: Array[Vector2i] = []
		var rim: Array[Vector2i] = []
		var region: Rect2i = ENTRY_REGIONS[side]
		for x in range(region.position.x, region.end.x):
			for z in range(region.position.y, region.end.y):
				var cell := Vector2i(x, z)
				if _open(grid, cell):
					entry.append(cell)
		# The city nav rim is one cell outside playable bounds, still inside
		# the rendered 64m ground. Keep the original transverse spawn range.
		if side == NORTH:
			for x in range(-24, 25):
				var cell := Vector2i(x, -31)
				if _open(grid, cell):
					rim.append(cell)
		else:
			for z in range(-20, 16):
				var cell := Vector2i(-31 if side == WEST else 31, z)
				if _open(grid, cell):
					rim.append(cell)
		_entry_cells[side] = entry
		_rim_cells[side] = rim

## Preflight BEFORE incrementing the wave or consuming any RNG. Failure means
## unsupported/corrupt terrain: pause and report it, never silently skip a wave.
func entries_available(sides: Array) -> bool:
	if not _active:
		return true
	for side in sides:
		if _entry_cells.get(side, []).is_empty() and _rim_cells.get(side, []).is_empty():
			return false
	return true

func correct_spawn(grid: AStarGrid2D, requested: Vector3, side: int) -> Vector3:
	if not _active:
		return requested
	var source := Vector2i(roundi(requested.x), roundi(requested.z))
	# Preserve the original floating point exactly unless its cell is solid.
	if not grid.is_in_boundsv(source) or not grid.is_point_solid(source):
		return requested
	var candidates: Array = _entry_cells.get(side, [])
	if candidates.is_empty():
		candidates = _rim_cells.get(side, [])
	if candidates.is_empty():
		push_error("City entry %d and its outer nav rim are fully blocked; no legal spawn." % side)
		return Vector3.INF
	var closest: Vector2i = candidates[0]
	var point := Vector2(requested.x, requested.z)
	var best: float = point.distance_squared_to(Vector2(closest))
	for candidate: Vector2i in candidates:
		var distance: float = point.distance_squared_to(Vector2(candidate))
		# Explicit x/z tie break, independent of Dictionary iteration order.
		if distance < best or (distance == best and (candidate.x < closest.x or (candidate.x == closest.x and candidate.y < closest.y))):
			closest = candidate
			best = distance
	return Vector3(closest.x, requested.y, closest.y)

static func _open(grid: AStarGrid2D, cell: Vector2i) -> bool:
	return grid.is_in_boundsv(cell) and not grid.is_point_solid(cell)
