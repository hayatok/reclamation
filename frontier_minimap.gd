extends RefCounted
## M2-only minimap. Call draw(host) from the Control's draw signal.
## Terrain is baked once; a single 48x40 texture is tinted on fog revision only.
## No nest coordinates are read from map_config or the live controller.
const MissionMap = preload("res://mission_map.gd")
const NEST_ID: String = "frontier_nest"
const UNKNOWN_COLOR: Color = Color("0c1216")
const LAND_COLOR: Color = Color("52615a")
const MEMORY_TINT: Color = Color(0.35, 0.39, 0.43, 1.0)
const WATER_COLOR: Color = Color("243f48")
const SHELL_COLOR: Color = Color("869083")
const FREIGHT_COLOR: Color = Color("707760")
const FRIENDLY_COLOR: Color = Color("b6c897")
const WORKER_COLOR: Color = Color("8a9c9f")
const SELECTED_COLOR: Color = Color("e3e5c9")
const ENEMY_COLOR: Color = Color("d47758")
const MEMORY_ENEMY_COLOR: Color = Color("84614f")
const CAMERA_COLOR: Color = Color("e5d6a9")

var terrain_bake_count: int = 0
var fog_upload_count: int = 0
var _terrain_image: Image
var _composite_image: Image
var _map_texture: ImageTexture
var _layout_signature: Array = []
var _fog_revision: int = -1
var _field: RefCounted

## Needed only if static terrain is replaced without changing map dimensions.
func invalidate_terrain() -> void:
	_terrain_image = null
	_fog_revision = -1

func draw(host: Node) -> void:
	var field: RefCounted = host.frontier_visibility
	var canvas: Control = host.minimap
	var size: Vector2 = canvas.size
	if field == null or not field.enabled or size.x <= 0.0 or size.y <= 0.0:
		return
	var config: Dictionary = host.map_config
	var texture: ImageTexture = background_texture(config, host.terrain_blocks, field)
	# The full terrain margin stays unknown. The shared map transform also drives
	# minimap clicks; this inset texture covers the playable rectangle precisely.
	canvas.draw_rect(Rect2(Vector2.ZERO, size), UNKNOWN_COLOR)
	if canvas.texture_filter != CanvasItem.TEXTURE_FILTER_NEAREST:
		canvas.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	canvas.draw_texture_rect(texture, _playable_rect(config, size), false)
	_draw_sites(host, canvas, field, config, size)
	_draw_friendlies(host, canvas, config, size)
	_draw_enemies(host, canvas, field, config, size)
	_draw_nest(host, canvas, field, config, size)
	_draw_alert(host, canvas, config, size)
	if host.minimap_order_time > 0.0:
		var order: Vector2 = host.minimap_order_point
		var point: Vector2 = MissionMap.world_to_map(config, Vector3(order.x, 0, order.y), size)
		canvas.draw_arc(point, 3.0 + host.minimap_order_time * 6.0, 0.0, TAU, 20,
			host.minimap_order_color, 1.5, true)
	for segment: PackedVector2Array in camera_outline(host.camera, config, size):
		canvas.draw_line(segment[0], segment[1], CAMERA_COLOR, 1.25, true)
	canvas.draw_rect(Rect2(Vector2(0.5, 0.5), size - Vector2.ONE), Color("596861"), false, 1.0)

## Public for focused cache tests; the draw path performs one texture draw.
func background_texture(config: Dictionary, blocks: Array, field: RefCounted) -> ImageTexture:
	var signature: Array = [field.bounds, field.columns, field.rows, field.cell_size]
	if _terrain_image == null or signature != _layout_signature:
		_bake_terrain(blocks, field)
		_layout_signature = signature
		_map_texture = null
		_fog_revision = -1
	if _field != field:
		_field = field
		_fog_revision = -1
	if _fog_revision != field.revision:
		if _composite_image == null or _composite_image.get_width() != field.columns or _composite_image.get_height() != field.rows:
			_composite_image = Image.create(field.columns, field.rows, false, Image.FORMAT_RGBA8)
		for z: int in field.rows:
			for x: int in field.columns:
				var state: int = field.cell_state(Vector2i(x, z))
				var color: Color = UNKNOWN_COLOR
				if state != 0:
					color = _terrain_image.get_pixel(x, z)
					if state == 1:
						color *= MEMORY_TINT
				_composite_image.set_pixel(x, z, color)
		if _map_texture == null:
			_map_texture = ImageTexture.create_from_image(_composite_image)
		else:
			_map_texture.update(_composite_image)
		_fog_revision = field.revision
		fog_upload_count += 1
	return _map_texture

func _bake_terrain(blocks: Array, field: RefCounted) -> void:
	_terrain_image = Image.create(field.columns, field.rows, false, Image.FORMAT_RGBA8)
	_terrain_image.fill(LAND_COLOR)
	var bounds: Rect2 = field.bounds
	for block: Dictionary in blocks:
		var position: Vector3 = block.pos
		var size: Vector3 = block.size
		var rectangle: Rect2 = Rect2(Vector2(position.x - size.x * 0.5, position.z - size.z * 0.5),
			Vector2(size.x, size.z)).intersection(bounds)
		if not rectangle.has_area():
			continue
		var low: Vector2i = Vector2i(
			maxi(0, floori((rectangle.position.x - bounds.position.x) / field.cell_size)),
			maxi(0, floori((rectangle.position.y - bounds.position.y) / field.cell_size)))
		var high: Vector2i = Vector2i(
			mini(field.columns, ceili((rectangle.end.x - bounds.position.x) / field.cell_size)),
			mini(field.rows, ceili((rectangle.end.y - bounds.position.y) / field.cell_size)))
		var color: Color = SHELL_COLOR
		if block.get("kind", "") == "water":
			color = WATER_COLOR
		elif block.get("kind", "") == "freight":
			color = FREIGHT_COLOR
		_terrain_image.fill_rect(Rect2i(low, high - low), color)
	terrain_bake_count += 1

func _draw_sites(host: Node, canvas: Control, field: RefCounted, config: Dictionary, size: Vector2) -> void:
	for site: Dictionary in host.sites:
		if not _has_node(site):
			continue
		var position: Vector3 = site.node.global_position
		if not field.is_explored(position):
			continue
		var color: Color = FRIENDLY_COLOR if site.reclaimed else Color("d9ba75")
		if not field.is_visible(position):
			color *= Color(0.6, 0.6, 0.6, 1.0)
		canvas.draw_circle(MissionMap.world_to_map(config, position, size), 3.0, color)
	for resource: Dictionary in host.resource_nodes:
		if not _has_node(resource) or not (resource.renewable or resource.stock > 0):
			continue
		var position: Vector3 = resource.node.global_position
		if not field.is_explored(position):
			continue
		var color: Color = host.resource_color(resource.resource)
		if not field.is_visible(position):
			color *= Color(0.6, 0.6, 0.6, 1.0)
		canvas.draw_circle(MissionMap.world_to_map(config, position, size), 2.3, color)

func _draw_friendlies(host: Node, canvas: Control, config: Dictionary, size: Vector2) -> void:
	for building: Dictionary in host.buildings:
		if not _alive(building):
			continue
		var point: Vector2 = MissionMap.world_to_map(config, building.node.global_position, size)
		var rectangle: Rect2 = Rect2(point - Vector2(2.2, 2.2), Vector2(4.4, 4.4))
		if building.get("built", 0.0) >= 1.0:
			canvas.draw_rect(rectangle, FRIENDLY_COLOR)
		else:
			canvas.draw_rect(rectangle, FRIENDLY_COLOR, false, 1.0)
	for unit: Dictionary in host.units:
		if not _alive(unit):
			continue
		var color: Color = SELECTED_COLOR if unit in host.selected else WORKER_COLOR
		canvas.draw_circle(MissionMap.world_to_map(config, unit.node.global_position, size), 2.0, color)

func _draw_enemies(host: Node, canvas: Control, field: RefCounted, config: Dictionary, size: Vector2) -> void:
	for enemy: Dictionary in host.enemies:
		if _alive(enemy) and field.is_visible(enemy.node.global_position):
			canvas.draw_circle(MissionMap.world_to_map(config, enemy.node.global_position, size), 1.6, ENEMY_COLOR)

func _draw_nest(host: Node, canvas: Control, field: RefCounted, config: Dictionary, size: Vector2) -> void:
	var memory: Dictionary = field.structure_memory(NEST_ID)
	if memory.is_empty():
		return
	var position: Vector3 = memory.pos
	var point: Vector2 = MissionMap.world_to_map(config, position, size)
	var current: bool = field.is_visible(position)
	var color: Color = ENEMY_COLOR if current else MEMORY_ENEMY_COLOR
	var polygon: PackedVector2Array = PackedVector2Array([
		point + Vector2(0, -5), point + Vector2(5, 0), point + Vector2(0, 5), point + Vector2(-5, 0),
	])
	# Controller information is read only after sight authorizes this location.
	var controller: Variant = host.get("frontier")
	var destroyed: bool = current and controller != null and not controller.nest.is_empty() \
		and controller.nest.get("dead", false)
	if current and not destroyed:
		canvas.draw_colored_polygon(polygon, color)
	else:
		polygon.append(polygon[0])
		canvas.draw_polyline(polygon, color, 1.4, true)
	if destroyed:
		canvas.draw_line(point - Vector2(3, 3), point + Vector2(3, 3), color, 1.3, true)
		canvas.draw_line(point + Vector2(-3, 3), point + Vector2(3, -3), color, 1.3, true)

func _draw_alert(host: Node, canvas: Control, config: Dictionary, size: Vector2) -> void:
	var alert: Dictionary = host.building_attack_alerts.current
	if alert.is_empty() or not is_instance_valid(host.building_attack_button) or not host.building_attack_button.visible:
		return
	var point: Vector2 = MissionMap.world_to_map(config, alert.position, size)
	var radius: float = 6.0 + 2.0 * sin(host.elapsed * 5.0)
	var color: Color = Color("e7af72")
	canvas.draw_arc(point, radius, 0.0, TAU, 24, color, 2.0, true)
	if int(alert.severity) == 3:
		canvas.draw_line(point - Vector2(3, 3), point + Vector2(3, 3), color, 2.0, true)
		canvas.draw_line(point + Vector2(-3, 3), point + Vector2(3, -3), color, 2.0, true)

## The actual four camera rays intersect the y=0 plane. Clipping each edge
## preserves the projected trapezoid and avoids drawing outside the minimap.
static func camera_outline(camera: Camera3D, config: Dictionary, size: Vector2) -> Array[PackedVector2Array]:
	var segments: Array[PackedVector2Array] = []
	if not is_instance_valid(camera) or not camera.is_inside_tree() or size.x <= 2.0 or size.y <= 2.0:
		return segments
	var viewport: Rect2 = camera.get_viewport().get_visible_rect()
	var corners: Array[Vector2] = [viewport.position, Vector2(viewport.end.x, viewport.position.y),
		viewport.end, Vector2(viewport.position.x, viewport.end.y)]
	var points: PackedVector2Array = PackedVector2Array()
	for corner: Vector2 in corners:
		var origin: Vector3 = camera.project_ray_origin(corner)
		var direction: Vector3 = camera.project_ray_normal(corner)
		if not origin.is_finite() or not direction.is_finite() or absf(direction.y) < 0.000001:
			return segments
		var distance: float = -origin.y / direction.y
		if distance < 0.0:
			return segments
		points.append(MissionMap.world_to_map(config, origin + direction * distance, size))
	var clip: Rect2 = Rect2(Vector2.ONE, size - Vector2(2, 2))
	for index: int in 4:
		var segment: PackedVector2Array = _clip_segment(points[index], points[(index + 1) % 4], clip)
		if segment.size() == 2:
			segments.append(segment)
	return segments

static func _clip_segment(start: Vector2, end: Vector2, rectangle: Rect2) -> PackedVector2Array:
	var delta: Vector2 = end - start
	var p: Array[float] = [-delta.x, delta.x, -delta.y, delta.y]
	var q: Array[float] = [start.x - rectangle.position.x, rectangle.end.x - start.x,
		start.y - rectangle.position.y, rectangle.end.y - start.y]
	var lower: float = 0.0
	var upper: float = 1.0
	for index: int in 4:
		if absf(p[index]) < 0.000001:
			if q[index] < 0.0:
				return PackedVector2Array()
			continue
		var ratio: float = q[index] / p[index]
		if p[index] < 0.0:
			lower = maxf(lower, ratio)
		else:
			upper = minf(upper, ratio)
		if lower > upper:
			return PackedVector2Array()
	return PackedVector2Array([start + delta * lower, start + delta * upper])

static func _playable_rect(config: Dictionary, size: Vector2) -> Rect2:
	var bounds: Rect2 = config.playable_bounds
	return Rect2(MissionMap.world_to_map(config, Vector3(bounds.position.x, 0, bounds.position.y), size),
		MissionMap.map_span(config, bounds.size, size))

static func _has_node(record: Dictionary) -> bool:
	var node: Variant = record.get("node")
	return is_instance_valid(node) and node is Node3D and not node.is_queued_for_deletion() \
		and node.is_inside_tree() and node.global_position.is_finite()

static func _alive(record: Dictionary) -> bool:
	return _has_node(record) and not record.get("dead", false) and float(record.get("hp", 0.0)) > 0.0
