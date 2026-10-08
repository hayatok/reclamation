extends RefCounted
## Authoritative mission bounds. Coordinates use world x/z, never screen x/y.
## Resolve once when starting/loading a mission; keep that config on the host.
## Rect2.end is an inclusive world-coordinate limit in the helpers below.
## Rect2i nav_region retains Godot's exclusive-end cell semantics.

const FRONTIER_MISSION: int = 1

static func for_mission(mission_index: int) -> Dictionary:
	var index := clampi(mission_index, 0, 2)
	var frontier := index == FRONTIER_MISSION
	var terrain_size := Vector2(200, 168) if frontier else Vector2(64, 64)
	return {
		"mission_index": index,
		"frontier": frontier,
		"playable_bounds": Rect2(-96, -80, 192, 160) if frontier else Rect2(-30, -30, 60, 60),
		"command_bounds": Rect2(-96, -80, 192, 160) if frontier else Rect2(-28, -28, 56, 56),
		"build_bounds": Rect2(-95, -79, 190, 158) if frontier else Rect2(-29, -29, 58, 58),
		"camera_bounds": Rect2(-82, -66, 164, 132) if frontier else Rect2(-18, -18, 36, 36),
		"nav_region": Rect2i(-96, -80, 193, 161) if frontier else Rect2i(-31, -31, 63, 63),
		"terrain_size": terrain_size,
		"terrain_bounds": Rect2(-terrain_size * 0.5, terrain_size),
		"home": Vector3(-64, 0, 48) if frontier else Vector3(0, 0, 8),
		"generator": Vector3(-42, 0, 32) if frontier else (Vector3(14, 0, -5) if index == 0 else Vector3(12, 0, -14)),
		"enemy_nest": Vector3(62, 0, -48) if frontier else Vector3.INF,
		"camera_default_focus": Vector3(-64, 0, 48) if frontier else Vector3.ZERO,
		"camera_default_size": 50.0 if frontier else 54.0,
		"camera_min_size": 26.0,
		"camera_max_size": 85.0,
	}

static func clamp_playable(config: Dictionary, position: Vector3) -> Vector3:
	return _clamp_xz(config.playable_bounds, position)

static func clamp_command(config: Dictionary, position: Vector3) -> Vector3:
	return _clamp_xz(config.command_bounds, position)

static func clamp_camera(config: Dictionary, position: Vector3) -> Vector3:
	var result := _clamp_xz(config.camera_bounds, position)
	result.y = 0.0
	return result

static func clamp_camera_size(config: Dictionary, size: float) -> float:
	return clampf(size, config.camera_min_size, config.camera_max_size)

static func contains_playable(config: Dictionary, position: Vector3) -> bool:
	return position.is_finite() and _contains_xz(config.playable_bounds, position)

static func contains_camera(config: Dictionary, position: Vector3) -> bool:
	return position.is_finite() and position.y == 0.0 and _contains_xz(config.camera_bounds, position)

static func building_fits(config: Dictionary, position: Vector3, radius: float) -> bool:
	if not position.is_finite() or not is_finite(radius) or radius < 0.0:
		return false
	var bounds: Rect2 = config.build_bounds
	return position.x - radius >= bounds.position.x and position.x + radius <= bounds.end.x and position.z - radius >= bounds.position.y and position.z + radius <= bounds.end.y

## Full terrain extent is also the minimap extent, including its edge margin.
## Keep the two axes separate: frontier terrain is deliberately not square.
static func world_to_map(config: Dictionary, position: Vector3, map_size: Vector2) -> Vector2:
	var bounds: Rect2 = config.terrain_bounds
	return (Vector2(position.x, position.z) - bounds.position) / bounds.size * map_size

static func map_to_world(config: Dictionary, point: Vector2, map_size: Vector2) -> Vector3:
	if map_size.x <= 0.0 or map_size.y <= 0.0 or not map_size.is_finite() or not point.is_finite():
		return Vector3.INF
	var bounds: Rect2 = config.terrain_bounds
	var position := bounds.position + point / map_size * bounds.size
	return Vector3(position.x, 0.0, position.y)

static func map_span(config: Dictionary, world_span: Vector2, map_size: Vector2) -> Vector2:
	var bounds: Rect2 = config.terrain_bounds
	return world_span / bounds.size * map_size

## Clamp to the actual configured navigation region. Callers may first apply
## their mission's playable/command clamp, preserving the old inner margins.
## This does not assert that a cell is open or reachable, or find a route.
static func clamp_nav_cell(grid: AStarGrid2D, cell: Vector2i) -> Vector2i:
	var region := grid.region
	if not region.has_area():
		return cell
	var high := region.end - Vector2i.ONE
	return Vector2i(clampi(cell.x, region.position.x, high.x), clampi(cell.y, region.position.y, high.y))

static func _clamp_xz(bounds: Rect2, position: Vector3) -> Vector3:
	return Vector3(clampf(position.x, bounds.position.x, bounds.end.x), position.y, clampf(position.z, bounds.position.y, bounds.end.y))

static func _contains_xz(bounds: Rect2, position: Vector3) -> bool:
	return position.x >= bounds.position.x and position.x <= bounds.end.x and position.z >= bounds.position.y and position.z <= bounds.end.y
