extends RefCounted
## Carried-load economy. The host owns all movement, scene nodes and navigation.
## stockpile is credited here; resource_deposited() is a post-credit notification.

const RATES := {"food": 1.2, "salvage": 1.0, "parts": 0.55}
const CAPACITIES := {"food": 10.0, "salvage": 12.0, "parts": 8.0}
const RESOURCE_RULES := {
	"food": {"rate": 1.2, "capacity": 10.0},
	"salvage": {"rate": 1.0, "capacity": 12.0},
	"parts": {"rate": 0.55, "capacity": 8.0},
}
const ARRIVAL_DISTANCE := 0.65
const APPROACH_MARGIN := 0.8

var _host: Node

func setup(host: Node) -> void:
	_host = host

## Accept either an entry in host.resource_nodes or that entry's Node3D.
## An empty but valid node still assigns the resource type, allowing later recovery.
func assign_resource(worker: Dictionary, resource: Variant) -> bool:
	if not _worker_valid(worker):
		return false
	var assignment := _resolve_resource(resource)
	if assignment.is_empty():
		return false
	_ensure_worker(worker)
	worker.erase("return_assignment")
	worker["resource_kind"] = str(assignment.resource)
	worker["resource_target"] = assignment
	worker["target"] = assignment
	worker["task"] = "gather"
	worker["economy_phase"] = ""
	worker["dropoff_target"] = null
	_start_assignment(worker)
	return true

## Call before the host moves this worker toward worker.goal.
## Non-gather orders never collect or deposit, and keep any existing carried load.
func update_worker(worker: Dictionary, dt: float) -> void:
	if not _worker_valid(worker) or worker.get("task", "idle") != "gather":
		return
	_ensure_worker(worker)
	if not is_finite(dt) or dt < 0.0:
		return
	var kind := _assignment_kind(worker)
	if not RESOURCE_RULES.has(kind):
		return
	worker["resource_kind"] = kind
	var phase := str(worker.economy_phase)
	if phase.is_empty() or phase in ["idle", "suspended"]:
		_start_assignment(worker)
		phase = str(worker.economy_phase)
	# Changing resource type cannot turn food in the worker's hands into parts.
	if float(worker.cargo) > 0.0 and str(worker.cargo_kind) != kind and phase not in ["to_dropoff", "waiting_dropoff"]:
		_begin_delivery(worker)
		phase = str(worker.economy_phase)
	if phase == "waiting_dropoff":
		_begin_delivery(worker)
		return
	if phase == "to_dropoff":
		_update_delivery(worker)
		return
	if phase not in ["to_resource", "gathering", "waiting_resource"]:
		_start_assignment(worker)
		return
	var resource: Dictionary = _resource_or_empty(worker.get("resource_target"))
	if not _resource_available(resource):
		resource = _nearest_resource(worker, kind)
		if resource.is_empty():
			if float(worker.cargo) > 0.0:
				_begin_delivery(worker)
			else:
				_wait_for_resource(worker)
			return
		_set_resource_destination(worker, resource)
	if not _arrived(worker):
		worker["economy_phase"] = "to_resource"
		return
	worker["economy_phase"] = "gathering"
	var capacity := _capacity(worker, kind)
	if float(worker.cargo) >= capacity:
		_begin_delivery(worker)
		return
	var amount := minf(_work_rate(worker, kind) * dt, capacity - float(worker.cargo))
	if not bool(resource.get("renewable", false)):
		amount = minf(amount, maxf(0.0, float(resource.get("stock", 0.0))))
	if amount <= 0.0:
		return
	if float(worker.cargo) == 0.0:
		worker["cargo_kind"] = kind
	worker["cargo"] = float(worker.cargo) + amount
	if not bool(resource.get("renewable", false)):
		resource["stock"] = maxf(0.0, float(resource.stock) - amount)
	if float(worker.cargo) >= capacity:
		_begin_delivery(worker)
	elif not _resource_available(resource):
		var next := _nearest_resource(worker, kind)
		if next.is_empty():
			_begin_delivery(worker)
		else:
			_set_resource_destination(worker, next)

## Call before replacing the gather order with a construction order.
## Calling twice during construction preserves the original economic assignment.
func suspend_for_construction(worker: Dictionary) -> void:
	_ensure_worker(worker)
	if worker.get("task", "idle") == "gather":
		worker["return_assignment"] = {
			"resource": _assignment_kind(worker),
			"target": worker.get("resource_target"),
		}
	worker["economy_phase"] = "suspended"
	worker["dropoff_target"] = null

## Call on completion OR destruction/cancellation of the worker's construction.
func resume_after_construction(worker: Dictionary) -> void:
	_ensure_worker(worker)
	var saved: Variant = worker.get("return_assignment")
	worker.erase("return_assignment")
	if saved is not Dictionary or not RESOURCE_RULES.has(str(saved.get("resource", ""))):
		worker["economy_phase"] = "idle"
		return
	worker["resource_kind"] = str(saved.resource)
	worker["resource_target"] = saved.get("target")
	worker["target"] = saved.get("target")
	worker["task"] = "gather"
	worker["economy_phase"] = ""
	worker["dropoff_target"] = null
	if _worker_valid(worker):
		_start_assignment(worker)

## Optional host helper for explicit stop/move/other orders. Never discards cargo.
## The host still owns setting task, target and the movement goal for that order.
func cancel_assignment(worker: Dictionary) -> void:
	_ensure_worker(worker)
	worker.erase("return_assignment")
	worker["resource_kind"] = ""
	worker["resource_target"] = null
	worker["dropoff_target"] = null
	worker["economy_phase"] = "idle"

func resource_description(resource: Dictionary) -> String:
	var kind := str(resource.get("resource", ""))
	if not RESOURCE_RULES.has(kind):
		return ""
	if bool(resource.get("renewable", false)):
		return "%s: renewable" % kind.capitalize()
	return "%s: %d remaining" % [kind.capitalize(), ceili(maxf(0.0, float(resource.get("stock", 0.0))))]

func _start_assignment(worker: Dictionary) -> void:
	var kind := _assignment_kind(worker)
	if not RESOURCE_RULES.has(kind):
		return
	if float(worker.cargo) > 0.0 and (str(worker.cargo_kind) != kind or float(worker.cargo) >= _capacity(worker, kind)):
		_begin_delivery(worker)
		return
	var resource: Dictionary = _resource_or_empty(worker.get("resource_target"))
	if not _resource_available(resource) or str(resource.get("resource", "")) != kind:
		resource = _nearest_resource(worker, kind)
	if not resource.is_empty():
		_set_resource_destination(worker, resource)
	elif float(worker.cargo) > 0.0:
		_begin_delivery(worker)
	else:
		_wait_for_resource(worker)

func _begin_delivery(worker: Dictionary) -> void:
	if float(worker.cargo) <= 0.0:
		_start_assignment(worker)
		return
	var dropoff := _nearest_dropoff(worker)
	if dropoff.is_empty():
		if str(worker.economy_phase) != "waiting_dropoff":
			_set_goal(worker, _position(worker))
			_notice("A completed HQ or depot is needed to deliver carried resources.")
		worker["economy_phase"] = "waiting_dropoff"
		worker["dropoff_target"] = null
		return
	worker["dropoff_target"] = dropoff
	worker["economy_phase"] = "to_dropoff"
	_set_goal(worker, _approach_point(worker, dropoff, 2.0))

func _update_delivery(worker: Dictionary) -> void:
	var dropoff := _resource_or_empty(worker.get("dropoff_target"))
	if not _dropoff_valid(dropoff):
		_begin_delivery(worker)
		return
	if not _arrived(worker):
		return
	var amount := float(worker.cargo)
	var kind := str(worker.cargo_kind)
	if amount <= 0.0:
		_start_assignment(worker)
		return
	if not RESOURCE_RULES.has(kind):
		# Preserve malformed/unknown cargo rather than silently destroying it.
		return
	var stockpile: Dictionary = _host.get("stockpile")
	stockpile[kind] = float(stockpile.get(kind, 0.0)) + amount
	# Clear before notifying the host, so re-entrant callbacks cannot double credit.
	worker["cargo"] = 0.0
	worker["cargo_kind"] = ""
	worker["dropoff_target"] = null
	worker["economy_phase"] = ""
	if _host.has_method("resource_deposited"):
		_host.call("resource_deposited", kind, amount)
	# A callback may issue a new order; only resume the unchanged gather order.
	if worker.get("task", "idle") == "gather" and str(worker.economy_phase).is_empty():
		_start_assignment(worker)

func _wait_for_resource(worker: Dictionary) -> void:
	if str(worker.economy_phase) != "waiting_resource":
		_set_goal(worker, _position(worker))
		if _host.has_method("economy_notice"):_host.call("economy_notice","近くの"+{"food":"食料","salvage":"廃材","parts":"部品"}.get(_assignment_kind(worker),"資源")+"が尽きた。待機作業員を再配置。")
	worker["economy_phase"] = "waiting_resource"
	worker["resource_target"] = null
	worker["target"] = null
	worker["dropoff_target"] = null

func _set_resource_destination(worker: Dictionary, resource: Dictionary) -> void:
	worker["resource_target"] = resource
	worker["target"] = resource
	worker["economy_phase"] = "to_resource"
	worker["dropoff_target"] = null
	_set_goal(worker, _host.call("worker_resource_approach",worker,resource) if _host.has_method("worker_resource_approach") else _approach_point(worker, resource, 1.2))

func _set_goal(worker: Dictionary, goal: Vector3) -> void:
	worker["goal"] = goal
	worker["route"] = []
	worker["planned"] = Vector3.INF

func _approach_point(worker: Dictionary, destination: Dictionary, default_radius: float) -> Vector3:
	var center := _position(destination)
	var direction := _position(worker) - center
	direction.y = 0.0
	if direction.length_squared() < 0.000001:
		direction = Vector3.FORWARD
	var radius := maxf(0.0, float(destination.get("radius", default_radius)))
	var point := center + direction.normalized() * (radius + APPROACH_MARGIN)
	point.y = 0.0
	return point

func _arrived(worker: Dictionary) -> bool:
	if _host.has_method("worker_navigation_arrived"):
		return bool(_host.call("worker_navigation_arrived", worker))
	return _position(worker).distance_to(worker.get("goal", Vector3.INF)) <= ARRIVAL_DISTANCE

func _nearest_resource(worker: Dictionary, kind: String) -> Dictionary:
	var best: Dictionary = {}
	var distance := INF
	if _host.has_method("worker_retarget_radius"):
		distance = pow(maxf(0,float(_host.call("worker_retarget_radius",worker,kind))),2)
	for resource: Dictionary in _host.get("resource_nodes"):
		if str(resource.get("resource", "")) != kind or not _resource_available(resource):
			continue
		var candidate := _position(worker).distance_squared_to(_position(resource))
		if candidate < distance:
			distance = candidate
			best = resource
	return best

func _nearest_dropoff(worker: Dictionary) -> Dictionary:
	var best: Dictionary = {}
	var distance := INF
	for building: Dictionary in _host.get("buildings"):
		if not _dropoff_valid(building):
			continue
		var candidate := _position(worker).distance_squared_to(_position(building))
		if candidate < distance:
			distance = candidate
			best = building
	return best

func _resource_available(resource: Dictionary) -> bool:
	if not _resource_valid(resource):
		return false
	return bool(resource.get("renewable", false)) or float(resource.get("stock", 0.0)) > 0.0

func _resource_valid(resource: Dictionary) -> bool:
	if resource.is_empty() or not _node_valid(resource) or not RESOURCE_RULES.has(str(resource.get("resource", ""))):
		return false
	if float(resource.get("hp", 1.0)) <= 0.0 or float(resource.get("built", 1.0)) < 1.0:
		return false
	return _contains_node(_host.get("resource_nodes"), resource.node)

func _dropoff_valid(building: Dictionary) -> bool:
	if building.is_empty() or not _node_valid(building):
		return false
	if str(building.get("kind", "")) not in ["hq", "depot"] or float(building.get("built", 0.0)) < 1.0 or float(building.get("hp", 0.0)) <= 0.0:
		return false
	return _contains_node(_host.get("buildings"), building.node)

func _resolve_resource(value: Variant) -> Dictionary:
	if not is_instance_valid(_host):
		return {}
	var wanted_node: Variant = value.get("node") if value is Dictionary else value
	if not is_instance_valid(wanted_node) or wanted_node is not Node3D:
		return {}
	for resource: Dictionary in _host.get("resource_nodes"):
		if resource.get("node") == wanted_node and _resource_valid(resource):
			return resource
	return {}

func _contains_node(entries: Array, node: Node3D) -> bool:
	for entry: Dictionary in entries:
		if entry.get("node") == node:
			return true
	return false

func _resource_or_empty(value: Variant) -> Dictionary:
	return value if value is Dictionary else {}

func _assignment_kind(worker: Dictionary) -> String:
	var kind := str(worker.get("resource_kind", ""))
	if RESOURCE_RULES.has(kind):
		return kind
	for field: String in ["resource_target", "target"]:
		var resource := _resource_or_empty(worker.get(field))
		kind = str(resource.get("resource", ""))
		if RESOURCE_RULES.has(kind):
			return kind
	return ""

func _capacity(worker: Dictionary, kind: String) -> float:
	if _host.has_method("worker_carry_capacity"):
		var value := float(_host.call("worker_carry_capacity", worker, kind))
		if is_finite(value) and value > 0.0:
			return value
	return float(RESOURCE_RULES[kind].capacity)

func _work_rate(worker: Dictionary, kind: String) -> float:
	if _host.has_method("worker_work_rate"):
		var value := float(_host.call("worker_work_rate", worker, kind))
		if is_finite(value):
			return maxf(0.0, value)
	return float(RESOURCE_RULES[kind].rate)

func _ensure_worker(worker: Dictionary) -> void:
	for key: String in ["cargo_kind", "resource_kind", "economy_phase"]:
		if not worker.has(key):
			worker[key] = ""
	if not worker.has("cargo"):
		worker["cargo"] = 0.0
	for key: String in ["resource_target", "dropoff_target"]:
		if not worker.has(key):
			worker[key] = null

func _worker_valid(worker: Dictionary) -> bool:
	return is_instance_valid(_host) and _node_valid(worker) and worker.get("kind", "worker") == "worker" and float(worker.get("hp", 1.0)) > 0.0

func _node_valid(entry: Dictionary) -> bool:
	var node: Variant = entry.get("node")
	return is_instance_valid(node) and node is Node3D and not node.is_queued_for_deletion()

func _position(entry: Dictionary) -> Vector3:
	return entry.node.position

func _notice(message: String) -> void:
	if _host.has_method("economy_notice"):
		_host.call("economy_notice", message)
	elif _host.has_signal("economy_notice"):
		_host.emit_signal("economy_notice", message)
