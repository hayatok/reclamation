extends RefCounted
## Read-only presentation snapshot of main.recompute_power(). This is NOT a
## second allocation solver. Call capture(host) only after that solve commits,
## including its generator-OFF return. Never call capture from UI queries.
const GameRules = preload("res://settlement_rules.gd")
const LINK_RANGE: float = 22.0
const POWER_KINDS: Array[String] = ["relay", "factory", "vehicle_workshop", "mortar", "tower", "yard"]

var _host_id: int = 0
var _signature: Dictionary = {}
var _references: Array[Dictionary] = []
var _powered: Dictionary = {}
var _sources: Array[Vector3] = []
var _source_ids: Array[int] = []
var _generator_on: bool = false
var _capacity: float = 0.0
var _used: float = 0.0


static func applicable(kind: String) -> bool:
	return kind in POWER_KINDS


func reset() -> void:
	_host_id = 0
	_signature.clear()
	_references.clear()
	_powered.clear()
	_sources.clear()
	_source_ids.clear()
	_generator_on = false
	_capacity = 0.0
	_used = 0.0


func capture(host) -> void:
	reset()
	var state: Dictionary = _read_state(host)
	if state.is_empty():
		return
	_host_id = host.get_instance_id()
	_signature = state.signature
	_references = state.references
	_generator_on = bool(_signature.generator_on)
	_capacity = float(_signature.capacity)
	_used = float(_signature.used)
	for row: Array in _signature.buildings:
		_powered[int(row[0])] = bool(row[5])
	if not _generator_on:
		return
	_sources.append(_signature.generator_position)
	_source_ids.append(int(_signature.generator_id))
	for row: Array in _signature.buildings:
		# The real solve ignores relay.enabled and HP. Do not add those filters.
		if str(row[1]) == "relay" and bool(row[5]):
			_sources.append(row[2])
			_source_ids.append(int(row[0]))


func is_fresh(host) -> bool:
	if not is_instance_valid(host) or _host_id != host.get_instance_id() or _signature.is_empty():
		return false
	var state: Dictionary = _read_state(host)
	if state.is_empty() or state.signature != _signature or state.references.size() != _references.size():
		return false
	for index: int in _references.size():
		if not is_same(state.references[index], _references[index]):
			return false
	return true


## Detached positions in the same coordinate space as node.position in the
## actual solve. The caller must apply its own visibility/fog policy.
func committed_sources(host) -> Array[Vector3]:
	if not is_fresh(host):
		return []
	return _sources.duplicate()


## For a preview, powered means available from CURRENT committed spare power,
## not a reservation or a promise about allocation after construction.
## For an existing building, pass its original dictionary; its committed flag
## is authoritative, and its own demand is never charged a second time.
## Existing queries use the building's actual center, not the preview point.
func query(host, kind: String, point: Vector3, existing: Dictionary = {}) -> Dictionary:
	var demand: float = float(GameRules.building(kind).get("power", 0.0))
	var result: Dictionary = {
		"status": "not_applicable", "fresh": false, "preview": existing.is_empty(),
		"scope": "current_availability" if existing.is_empty() else "committed_allocation",
		"generator_on": false, "capacity": 0.0, "used": 0.0,
		"current_free": 0.0, "demand": demand, "deficit": 0.0,
		"powered": false, "available_now": false, "committed": false,
		"nearest_source": Vector3.INF, "distance": INF, "in_range": false,
	}
	if not applicable(kind):
		return result
	if not is_fresh(host):
		return _status(result, "pending")
	result.fresh = true
	result.generator_on = _generator_on
	result.capacity = _capacity
	result.used = _used
	result.current_free = maxf(0.0, _capacity - _used)
	var existing_id: int = 0
	if not existing.is_empty():
		var reference_index: int = -1
		for index: int in _references.size():
			if is_same(existing, _references[index]):
				reference_index = index
				break
		if reference_index < 0 or str(existing.get("kind", "")) != kind:
			result.fresh = false
			return _status(result, "pending")
		existing_id = existing.node.get_instance_id()
		point = existing.node.position
	result.merge(_nearest(point, existing_id if kind == "relay" else 0), true)
	if not existing.is_empty():
		if float(existing.get("built", 0.0)) < 1.0:
			return _status(result, "construction")
		if kind != "relay" and not bool(existing.get("enabled", false)):
			return _status(result, "disabled")
	if not _generator_on:
		return _status(result, "off")
	if not existing.is_empty() and bool(_powered.get(existing_id, false)):
		result.committed = true
		result.powered = true
		result.available_now = true
		return _status(result, "powered")
	result.deficit = maxf(0.0, demand - float(result.current_free))
	if not bool(result.in_range):
		return _status(result, "out_of_range")
	# Use the solver's exact comparison, with no epsilon or projected upgrades.
	if _used + demand > _capacity:
		return _status(result, "capacity")
	if not existing.is_empty():
		return _status(result, "unpowered")
	result.available_now = true
	return _status(result, "powered")


func _nearest(point: Vector3, excluded_id: int) -> Dictionary:
	var nearest: Vector3 = Vector3.INF
	var distance: float = INF
	for index: int in _sources.size():
		if excluded_id != 0 and _source_ids[index] == excluded_id:
			continue
		var next_distance: float = point.distance_to(_sources[index])
		if next_distance < distance:
			distance = next_distance
			nearest = _sources[index]
	return {"nearest_source": nearest, "distance": distance, "in_range": distance <= LINK_RANGE}


func _read_state(host) -> Dictionary:
	if not is_instance_valid(host):
		return {}
	var generator: Dictionary = host.get_site("generator")
	var generator_node = generator.get("node")
	if not is_instance_valid(generator_node):
		return {}
	var references: Array[Dictionary] = []
	var rows: Array = []
	for building: Dictionary in host.buildings:
		var kind: String = str(building.get("kind", ""))
		if kind not in POWER_KINDS:
			continue
		var node = building.get("node")
		if not is_instance_valid(node):
			return {}
		references.append(building)
		rows.append([node.get_instance_id(), kind, node.position,
			float(building.get("built", 0.0)) >= 1.0,
			bool(building.get("enabled", false)), bool(building.get("powered", false))])
	# Completion is a boolean: ordinary construction progress need not invalidate
	# the snapshot. Ordered references matter to priority; HP does not to this solve.
	return {"references": references, "signature": {
		"generator_on": bool(host.generator_on),
		"generator_id": generator_node.get_instance_id(),
		"generator_position": generator_node.position,
		"generator_reclaimed": bool(generator.get("reclaimed", false)),
		"age": int(host.settlement_age),
		"power_upgrade": int(host.upgrades.get("power", 0)),
		"power_effect": float(host.catalog_by_id.get("power", {}).get("effects", {}).get("power_capacity_add", 0.0)),
		"capacity": float(host.power_capacity), "used": float(host.power_used),
		"buildings": rows,
	}}


func _status(result: Dictionary, status: String) -> Dictionary:
	result.status = status
	return result
