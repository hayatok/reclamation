extends RefCounted
## Mission 2 exploration. Reads friendly simulation records; never writes to them.
## Cells store separate current sight and persistent explored terrain. Seeing terrain
## does not itself discover a structure: call observe_structure for that object.

const FRONTIER_MISSION: int = 1
const DEFAULT_CELL_SIZE: float = 4.0
const UPDATE_INTERVAL: float = 0.2
const MAX_CELLS: int = 65536
const MAX_MEMORIES: int = 256
const UNKNOWN: int = 0
const EXPLORED: int = 1
const VISIBLE: int = 2
const DEFAULT_UNIT_SIGHT: Dictionary = {
	"worker": 14.0, "guard": 22.0, "grenade": 20.0,
	"siegecart": 20.0, "truck": 18.0, "convoy": 18.0,
}
const DEFAULT_BUILDING_SIGHT: Dictionary = {
	"hq": 28.0, "tower": 24.0, "mortar": 22.0, "relay": 14.0, "wall": 0.0,
}

var unit_sight: Dictionary = DEFAULT_UNIT_SIGHT.duplicate()
var building_sight: Dictionary = DEFAULT_BUILDING_SIGHT.duplicate()
var default_building_sight: float = 18.0
var enabled: bool = false
var bounds: Rect2 = Rect2()
var cell_size: float = DEFAULT_CELL_SIZE
var columns: int = 0
var rows: int = 0
var revision: int = 0
var _elapsed: float = UPDATE_INTERVAL
var _explored: PackedByteArray = PackedByteArray()
var _visible: PackedByteArray = PackedByteArray()
var _memories: Dictionary = {}
var _texture: ImageTexture
var _texture_revision: int = -1

## Exact maximum edges are included, matching MissionMap and navigation.
## Failure is transactional: an invalid configuration cannot corrupt live state.
func configure(world_bounds: Rect2, mission_index: int = FRONTIER_MISSION,
		meters_per_cell: float = DEFAULT_CELL_SIZE) -> bool:
	if not _valid_layout(world_bounds, meters_per_cell):
		return false
	bounds = world_bounds
	cell_size = meters_per_cell
	enabled = mission_index == FRONTIER_MISSION
	columns = ceili(bounds.size.x / cell_size) if enabled else 0
	rows = ceili(bounds.size.y / cell_size) if enabled else 0
	_explored.resize(columns * rows)
	_explored.fill(0)
	_visible.resize(columns * rows)
	_visible.fill(0)
	_memories.clear()
	_elapsed = UPDATE_INTERVAL
	_texture = null
	_texture_revision = -1
	revision += 1
	return true

## Call after a simulation step, with ONLY friendly units/buildings. Returns true
## when a scheduled refresh ran; refresh after load/spawn/loss with force=true.
## Oversized delta triggers one refresh, never catch-up work or path extrapolation.
func update_sources(units: Array, buildings: Array, delta: float = UPDATE_INTERVAL,
		force: bool = false) -> bool:
	if not enabled:
		return false
	if is_finite(delta) and delta > 0.0:
		_elapsed += delta
	if not force and _elapsed + 0.000001 < UPDATE_INTERVAL:
		return false
	_elapsed = 0.0
	var previous: PackedByteArray = _visible.duplicate()
	_visible.fill(0)
	for value: Variant in units:
		if value is Dictionary and _source_alive(value):
			_reveal(value.node.global_position, _sight(value, false))
	for value: Variant in buildings:
		# Never use a default of 1: construction ghosts cannot provide vision.
		if value is Dictionary and _source_alive(value) and _number(value.get("built")) \
				and float(value.built) >= 1.0:
			_reveal(value.node.global_position, _sight(value, true))
	if previous != _visible:
		revision += 1
	return true

func is_visible(world_position: Vector3) -> bool:
	if not enabled:
		return true
	var index: int = _index_at(world_position)
	return index >= 0 and _visible[index] == 1

func is_explored(world_position: Vector3) -> bool:
	if not enabled:
		return true
	var index: int = _index_at(world_position)
	return index >= 0 and _explored[index] == 1

func cell_state(cell: Vector2i) -> int:
	if not enabled:
		return VISIBLE
	if cell.x < 0 or cell.y < 0 or cell.x >= columns or cell.y >= rows:
		return UNKNOWN
	var index: int = cell.y * columns + cell.x
	return VISIBLE if _visible[index] == 1 else EXPLORED if _explored[index] == 1 else UNKNOWN

func world_to_cell(world_position: Vector3) -> Vector2i:
	var index: int = _index_at(world_position)
	return Vector2i(index % columns, index / columns) if index >= 0 else Vector2i(-1, -1)

func cell_center(cell: Vector2i) -> Vector3:
	return Vector3(minf(bounds.end.x, bounds.position.x + (float(cell.x) + 0.5) * cell_size),
		0.0, minf(bounds.end.y, bounds.position.y + (float(cell.y) + 0.5) * cell_size))

## Shared 48x40 RGBA8 texture for the normal 192x160m map. Red = explored;
## green = currently visible; blue = 0; alpha = 1. No mipmaps/readback.
## The object is stable until configure(), so shader uniforms need binding once.
func get_mask_texture() -> ImageTexture:
	if not enabled:
		return null
	if _texture_revision == revision and _texture != null:
		return _texture
	var bytes: PackedByteArray = PackedByteArray()
	bytes.resize(columns * rows * 4)
	for index: int in _explored.size():
		var offset: int = index * 4
		bytes[offset] = _explored[index] * 255
		bytes[offset + 1] = _visible[index] * 255
		bytes[offset + 2] = 0
		bytes[offset + 3] = 255
	var image: Image = Image.create_from_data(columns, rows, false, Image.FORMAT_RGBA8, bytes)
	if _texture == null:
		_texture = ImageTexture.create_from_image(image)
	else:
		_texture.update(image)
	_texture_revision = revision
	return _texture

## Records last observed static structure data only while actually in sight.
## Mobile enemies must NEVER use memory for drawing or target selection.
func observe_structure(identifier: String, world_position: Vector3, kind: String = "") -> bool:
	if not enabled or not _valid_name(identifier) or kind.length() > 64 \
			or not is_visible(world_position):
		return false
	if not _memories.has(identifier) and _memories.size() >= MAX_MEMORIES:
		return false
	_memories[identifier] = {"pos": world_position, "kind": kind}
	return true

func structure_discovered(identifier: String) -> bool:
	return not enabled or _memories.has(identifier)

## This is LAST OBSERVED information, not permission to render a live enemy node.
## Draw a subdued memory marker from this value while current sight is absent.
func structure_memory(identifier: String) -> Dictionary:
	return _memories.get(identifier, {}).duplicate(true)

## Call only after observing that the structure is gone. Hidden destruction must
## not erase the remembered marker and leak knowledge from outside friendly sight.
func forget_structure(identifier: String, world_position: Vector3) -> bool:
	if not enabled or not is_visible(world_position):
		return false
	return _memories.erase(identifier)

## Save only persistent state. Current sight is rebuilt from loaded living sources.
func snapshot() -> Dictionary:
	if not enabled:
		return {}
	var memories: Dictionary = {}
	for identifier: String in _memories:
		var entry: Dictionary = _memories[identifier]
		var position: Vector3 = entry.pos
		memories[identifier] = {"pos": [position.x, position.y, position.z], "kind": entry.kind}
	return {
		"version": 1, "bounds": [bounds.position.x, bounds.position.y, bounds.size.x, bounds.size.y],
		"cell_size": cell_size, "columns": columns, "rows": rows,
		"explored": _pack_explored().hex_encode(), "structures": memories,
	}

## No state changes until the entire snapshot has passed validation.
func restore(value: Variant) -> bool:
	if not enabled:
		return value is Dictionary and value.is_empty()
	if not validate(value, bounds, cell_size):
		return false
	var packed: PackedByteArray = String(value.explored).hex_decode()
	for index: int in _explored.size():
		_explored[index] = (packed[index >> 3] >> (index & 7)) & 1
	_visible.fill(0)
	_memories.clear()
	for identifier: String in value.structures:
		var entry: Dictionary = value.structures[identifier]
		_memories[identifier] = {
			"pos": Vector3(entry.pos[0], entry.pos[1], entry.pos[2]), "kind": entry.kind,
		}
	_elapsed = UPDATE_INTERVAL
	revision += 1
	return true

static func validate(value: Variant, expected_bounds: Rect2 = Rect2(),
		expected_cell_size: float = DEFAULT_CELL_SIZE) -> bool:
	if not value is Dictionary or not _integer(value.get("version")) or value.version != 1:
		return false
	var raw: Variant = value.get("bounds")
	if not raw is Array or raw.size() != 4:
		return false
	for component: Variant in raw:
		if not _number(component):
			return false
	var saved_bounds: Rect2 = Rect2(raw[0], raw[1], raw[2], raw[3])
	if not _number(value.get("cell_size")) or not _valid_layout(saved_bounds, float(value.cell_size)):
		return false
	if expected_bounds.has_area() and saved_bounds != expected_bounds:
		return false
	if float(value.cell_size) != expected_cell_size:
		return false
	var saved_columns: int = ceili(saved_bounds.size.x / float(value.cell_size))
	var saved_rows: int = ceili(saved_bounds.size.y / float(value.cell_size))
	if not _integer(value.get("columns")) or not _integer(value.get("rows")) \
			or value.columns != saved_columns or value.rows != saved_rows:
		return false
	var count: int = saved_columns * saved_rows
	var encoded: Variant = value.get("explored")
	if not encoded is String or encoded.length() != ceili(float(count) / 8.0) * 2:
		return false
	# Require exact canonical hexadecimal; hex_decode alone accepts bad input.
	for index: int in encoded.length():
		if "0123456789abcdef".find(encoded[index]) < 0:
			return false
	var packed: PackedByteArray = encoded.hex_decode()
	if count % 8 != 0 and (packed[-1] >> (count % 8)) != 0:
		return false
	var memories: Variant = value.get("structures")
	if not memories is Dictionary or memories.size() > MAX_MEMORIES:
		return false
	for identifier: Variant in memories:
		var entry: Variant = memories[identifier]
		if not identifier is String or not _valid_name(identifier) or not entry is Dictionary:
			return false
		if not entry.get("kind") is String or entry.kind.length() > 64:
			return false
		var position: Variant = entry.get("pos")
		if not position is Array or position.size() != 3:
			return false
		for component: Variant in position:
			if not _number(component):
				return false
		var xz: Vector2 = Vector2(position[0], position[2])
		if not _inside(xz, saved_bounds):
			return false
		var x: int = mini(floori((xz.x - saved_bounds.position.x) / float(value.cell_size)), saved_columns - 1)
		var z: int = mini(floori((xz.y - saved_bounds.position.y) / float(value.cell_size)), saved_rows - 1)
		var cell_index: int = z * saved_columns + x
		if ((packed[cell_index >> 3] >> (cell_index & 7)) & 1) == 0:
			return false
	return true

func _source_alive(record: Dictionary) -> bool:
	var actor: Variant = record.get("node")
	return not record.get("dead", false) and _number(record.get("hp")) \
		and float(record.hp) > 0.0 and is_instance_valid(actor) and actor is Node3D \
		and not actor.is_queued_for_deletion() and actor.is_inside_tree() \
		and actor.global_position.is_finite()

func _sight(record: Dictionary, building: bool) -> float:
	var lookup: Dictionary = building_sight if building else unit_sight
	var radius: Variant = lookup.get(record.get("kind", ""), default_building_sight if building else 14.0)
	return float(radius) if _number(radius) and float(radius) > 0.0 else 0.0

func _reveal(world_position: Vector3, radius: float) -> void:
	var source_index: int = _index_at(world_position)
	if radius <= 0.0 or source_index < 0:
		return
	var low_x: int = maxi(0, floori((world_position.x - radius - bounds.position.x) / cell_size))
	var high_x: int = mini(columns - 1, floori((world_position.x + radius - bounds.position.x) / cell_size))
	var low_z: int = maxi(0, floori((world_position.z - radius - bounds.position.y) / cell_size))
	var high_z: int = mini(rows - 1, floori((world_position.z + radius - bounds.position.y) / cell_size))
	var radius_squared: float = radius * radius
	for z: int in range(low_z, high_z + 1):
		for x: int in range(low_x, high_x + 1):
			var center: Vector3 = cell_center(Vector2i(x, z))
			var offset: Vector2 = Vector2(center.x - world_position.x, center.z - world_position.z)
			var index: int = z * columns + x
			if index == source_index or offset.length_squared() <= radius_squared:
				_visible[index] = 1
				_explored[index] = 1

func _index_at(world_position: Vector3) -> int:
	if not enabled or not world_position.is_finite() \
			or not _inside(Vector2(world_position.x, world_position.z), bounds):
		return -1
	var x: int = mini(floori((world_position.x - bounds.position.x) / cell_size), columns - 1)
	var z: int = mini(floori((world_position.z - bounds.position.y) / cell_size), rows - 1)
	return z * columns + x

func _pack_explored() -> PackedByteArray:
	var packed: PackedByteArray = PackedByteArray()
	packed.resize(ceili(float(_explored.size()) / 8.0))
	packed.fill(0)
	for index: int in _explored.size():
		if _explored[index] == 1:
			packed[index >> 3] |= 1 << (index & 7)
	return packed

static func _inside(point: Vector2, rectangle: Rect2) -> bool:
	return point.x >= rectangle.position.x and point.y >= rectangle.position.y \
		and point.x <= rectangle.end.x and point.y <= rectangle.end.y

static func _number(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value))

static func _integer(value: Variant) -> bool:
	return _number(value) and float(value) == floor(float(value))

static func _valid_name(value: String) -> bool:
	return not value.is_empty() and value.length() <= 64

static func _valid_layout(rectangle: Rect2, meters_per_cell: float) -> bool:
	if not rectangle.position.is_finite() or not rectangle.size.is_finite() \
			or not rectangle.end.is_finite() or not rectangle.has_area() \
			or not is_finite(meters_per_cell) or meters_per_cell <= 0.0:
		return false
	var width: float = ceil(rectangle.size.x / meters_per_cell)
	var height: float = ceil(rectangle.size.y / meters_per_cell)
	return is_finite(width) and is_finite(height) and width >= 1.0 and height >= 1.0 \
		and width <= MAX_CELLS and height <= MAX_CELLS and width * height <= MAX_CELLS
