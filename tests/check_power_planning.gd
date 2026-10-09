extends SceneTree
## No game scene, renderer, save, audio, or simulation loop is loaded.
## In the game project, compile the ACTUAL main.gd solver into a tiny test host.
## The isolated project uses a verbatim source excerpt captured from main.gd.
const Planning = preload("res://power_planning.gd")
const Rules = preload("res://settlement_rules.gd")
var failures: Array[String] = []
var checks: int = 0
var host_script: GDScript
var nodes: Array[Node3D] = []


func _initialize() -> void:
	call_deferred("_run")


func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
		push_error(message)


func _compile_host() -> bool:
	var source_path: String = "res://main.gd" if FileAccess.file_exists("res://main.gd") else "res://tests/fixtures/power_solver_source.txt"
	var source: String = FileAccess.get_file_as_string(source_path)
	var code: String = "extends RefCounted\nconst GameRules=preload('res://settlement_rules.gd')\nconst Planning=preload('res://power_planning.gd')\nvar power_planning=Planning.new()\nvar generator_on=false\nvar power_capacity=0.0\nvar power_used=0.0\nvar power_clock=0.625\nvar buildings=[]\nvar sites=[]\nvar settlement_age=1\nvar upgrades={}\nvar catalog_by_id={'power':{'effects':{'power_capacity_add':0.15}}}\nvar stockpile={'food':33.0,'salvage':27.0,'parts':11.0}\nvar rng=RandomNumberGenerator.new()\n"
	for name: String in ["recompute_power", "base_power", "bonus", "get_site"]:
		var start: int = source.find("func " + name + "(")
		if start < 0:
			_check(false, "missing actual solver function: " + name)
			return false
		var end: int = source.find("\nfunc ", start + 1)
		code += "\n" + source.substr(start, end - start if end >= 0 else -1).strip_edges() + "\n"
	host_script = GDScript.new()
	host_script.source_code = code
	var error: Error = host_script.reload()
	_check(error == OK, "actual main solver compiles in fixture host")
	return error == OK


func _host(on: bool = true):
	var host = host_script.new()
	host.generator_on = on
	var node: Node3D = Node3D.new()
	nodes.append(node)
	host.sites = [{"kind": "generator", "node": node, "reclaimed": true}]
	host.rng.seed = 81231
	return host


func _add(host, kind: String, position: Vector3, built: float = 1.0, enabled: bool = true) -> Dictionary:
	var node: Node3D = Node3D.new()
	node.position = position
	nodes.append(node)
	var building: Dictionary = {"node": node, "kind": kind, "built": built, "enabled": enabled, "powered": false, "hp": 100.0, "production_destroyed": false}
	host.buildings.append(building)
	return building


func _commit(host, planning) -> void:
	host.recompute_power()
	planning.capture(host)


func _view(planning, host, building: Dictionary) -> Dictionary:
	return planning.query(host, building.kind, building.node.position, building)


func _run() -> void:
	if not _compile_host():
		quit(1)
		return
	_test_distance_and_relay()
	_test_capacity_and_priority()
	_test_freshness_and_off()
	_test_reference_and_observer()
	for node: Node3D in nodes:
		node.free()
	print("POWER_PLANNING_CONTRACT checks=%d failed=%d" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)


func _test_distance_and_relay() -> void:
	var host = _host()
	var planning = Planning.new()
	_commit(host, planning)
	_check(planning.query(host, "tower", Vector3(22, 0, 0)).status == "powered", "22m horizontal boundary is included")
	_check(planning.query(host, "tower", Vector3(22.001, 0, 0)).status == "out_of_range", "outside 22m is excluded")
	_check(planning.query(host, "relay", Vector3(0, 22, 0)).status == "powered", "22m vertical boundary is included")
	_check(planning.query(host, "tower", Vector3(21, 8, 0)).status == "out_of_range", "3D center distance is not flattened to ground")
	var far: Dictionary = _add(host, "relay", Vector3(44, 0, 0), 1.0, false)
	var near: Dictionary = _add(host, "relay", Vector3(22, 0, 0), 1.0, false)
	# No HP/production_destroyed filtering exists in main.recompute_power.
	near.hp = 0.0
	near.production_destroyed = true
	_commit(host, planning)
	_check(far.powered and near.powered and host.power_used == 1.0, "actual closure powers reverse-ordered disabled relay chain at 0.5 each")
	_check(_view(planning, host, near).status == "powered" and _view(planning, host, far).status == "powered", "disabled relay is not mislabeled manually stopped")
	_check(planning.committed_sources(host).size() == 3, "committed source list preserves real powered relay chain")
	var preview: Dictionary = planning.query(host, "vehicle_workshop", Vector3(66, 0, 0))
	_check(preview.status == "powered" and preview.nearest_source == Vector3(44, 0, 0) and preview.distance == 22.0, "preview uses nearest committed relay at exact boundary")
	_check(preview.scope == "current_availability" and preview.available_now and not preview.committed and not preview.powered, "preview availability is distinct from an actual allocation")
	_check(preview.demand == Rules.building("vehicle_workshop").power, "preview demand reads settlement GameRules")
	var orphan: Dictionary = _add(host, "relay", Vector3(100, 0, 0))
	_commit(host, planning)
	_check(not orphan.powered and planning.committed_sources(host).size() == 3, "unpowered relay never becomes a source")
	_check(_view(planning, host, orphan).status == "out_of_range", "unconnected existing relay reports range")


func _test_capacity_and_priority() -> void:
	var host = _host()
	var planning = Planning.new()
	# Deliberately arrange the list against the solver's kind priority.
	var yard: Dictionary = _add(host, "yard", Vector3(5, 0, 0))
	var tower: Dictionary = _add(host, "tower", Vector3(4, 0, 0))
	var mortar: Dictionary = _add(host, "mortar", Vector3(3, 0, 0))
	var workshop: Dictionary = _add(host, "vehicle_workshop", Vector3(2, 0, 0))
	var factory: Dictionary = _add(host, "factory", Vector3(1, 0, 0))
	_commit(host, planning)
	_check(factory.powered and workshop.powered and mortar.powered and tower.powered and not yard.powered and host.power_used == 7.0, "captured flags follow factory/workshop/mortar/tower/yard priority")
	var view: Dictionary = _view(planning, host, factory)
	_check(view.status == "powered" and view.current_free == 0.0 and view.deficit == 0.0 and view.demand == 2.0 and view.committed, "existing consumer is not charged its allocated demand twice")
	view = planning.query(host, "factory", Vector3(1, 0, 0))
	_check(view.status == "capacity" and view.deficit == 2.0 and view.current_free == 0.0, "same point as preview needs real spare capacity")
	_check(_view(planning, host, yard).status == "capacity" and _view(planning, host, yard).deficit == 1.0, "unallocated connected consumer reports exact shortage")
	var fractional = _host()
	var relay: Dictionary = _add(fractional, "relay", Vector3(1, 0, 0))
	for index: int in 3:
		_add(fractional, "factory", Vector3(index + 2, 0, 0))
	_commit(fractional, planning)
	view = planning.query(fractional, "tower", Vector3.ZERO)
	_check(view.status == "capacity" and view.current_free == 0.5 and view.deficit == 0.5, "fractional relay usage appears in exact deficit")
	_check(_view(planning, fractional, relay).status == "powered", "existing relay retains committed allocation at low spare power")
	var ordered = _host()
	var consumers: Array[Dictionary] = []
	for index: int in 4:
		consumers.append(_add(ordered, "factory", Vector3(index + 1, 0, 0)))
	_commit(ordered, planning)
	_check(consumers[0].powered and not consumers[3].powered, "same-kind priority starts with actual list order")
	ordered.buildings = [consumers[3], consumers[0], consumers[1], consumers[2]]
	_check(planning.query(ordered, "tower", Vector3.ZERO).status == "pending" and planning.committed_sources(ordered).is_empty(), "ordered-priority change invalidates before recomputation")
	_commit(ordered, planning)
	_check(_view(planning, ordered, consumers[3]).status == "powered" and _view(planning, ordered, consumers[2]).status == "capacity", "recapture reflects actual reordered allocation")


func _test_freshness_and_off() -> void:
	var host = _host(false)
	var planning = Planning.new()
	_check(planning.query(host, "factory", Vector3.ZERO).status == "pending", "uncaptured helper never predicts")
	_commit(host, planning)
	_check(planning.is_fresh(host) and planning.query(host, "factory", Vector3.ZERO).status == "off" and planning.committed_sources(host).is_empty(), "generator OFF completion is captured with no sources")
	host.generator_on = true
	_check(planning.query(host, "factory", Vector3.ZERO).status == "pending", "generator toggle before 1s solve waits for commitment")
	_commit(host, planning)
	var foundation: Dictionary = _add(host, "factory", Vector3(4, 0, 0), 0.2)
	_check(_view(planning, host, foundation).status == "pending", "new relevant building invalidates capture")
	_commit(host, planning)
	_check(_view(planning, host, foundation).status == "construction", "unfinished existing building reports construction")
	foundation.built = 0.9
	_check(planning.is_fresh(host) and _view(planning, host, foundation).status == "construction", "construction progress alone remains fresh")
	foundation.built = 1.0
	_check(_view(planning, host, foundation).status == "pending" and not foundation.powered, "completion waits for real allocation and never powers itself")
	_commit(host, planning)
	_check(_view(planning, host, foundation).status == "powered", "completed building follows committed result")
	foundation.enabled = false
	_check(_view(planning, host, foundation).status == "pending", "enable-state input change invalidates")
	_commit(host, planning)
	_check(_view(planning, host, foundation).status == "disabled", "disabled consumer reports manual stop")
	host.settlement_age = 3
	_check(not planning.is_fresh(host), "age change invalidates")
	_commit(host, planning)
	host.upgrades.power = 1
	_check(not planning.is_fresh(host), "power upgrade invalidates")
	_commit(host, planning)
	host.catalog_by_id.power.effects.power_capacity_add = 0.2
	_check(not planning.is_fresh(host), "power effect change invalidates")
	_commit(host, planning)
	host.sites[0].node.position = Vector3(1, 0, 0)
	_check(not planning.is_fresh(host) and planning.committed_sources(host).is_empty(), "generator motion hides stale sources")
	_commit(host, planning)
	foundation.node.position = Vector3(5, 0, 0)
	_check(not planning.is_fresh(host), "building center movement invalidates")
	_commit(host, planning)
	foundation.powered = not foundation.powered
	_check(not planning.is_fresh(host), "committed powered flag mutation invalidates")
	_commit(host, planning)
	host.power_used += 0.5
	_check(not planning.is_fresh(host), "used-capacity mutation invalidates")
	_commit(host, planning)
	host.generator_on = false
	_check(planning.query(host, "tower", Vector3.ZERO).status == "pending", "OFF toggle does not claim its prior allocation is current")
	_commit(host, planning)
	_check(planning.query(host, "tower", Vector3.ZERO).status == "off", "OFF recapture stays fresh after early return")
	planning.reset()
	_check(planning.query(host, "tower", Vector3.ZERO).status == "pending", "reset removes committed state")


func _test_reference_and_observer() -> void:
	var host = _host()
	var planning = Planning.new()
	var factory: Dictionary = _add(host, "factory", Vector3(2, 0, 0))
	_commit(host, planning)
	var detached: Dictionary = factory.duplicate()
	_check(_view(planning, host, detached).status == "pending", "lookalike dictionary is not the actual committed building reference")
	host.buildings[0] = detached
	_check(not planning.is_fresh(host), "replaced dictionary identity invalidates even with identical fields and node")
	_commit(host, planning)
	detached.hp = 0.0
	detached.production_destroyed = true
	_check(planning.is_fresh(host) and _view(planning, host, detached).status == "powered", "HP and production_destroyed do not introduce nonexistent solver filters")
	_add(host, "house", Vector3(30, 0, 0), 0.5)
	_check(planning.is_fresh(host), "unrelated no-power building does not invalidate")
	_check(planning.query(host, "house", Vector3.ZERO).status == "not_applicable" and planning.query(host, "unknown", Vector3.ZERO).status == "not_applicable", "non-power kinds are not applicable")
	var before: Dictionary = {"buildings": host.buildings.duplicate(true), "sites": host.sites.duplicate(true), "stockpile": host.stockpile.duplicate(true), "rng": host.rng.state, "used": host.power_used, "capacity": host.power_capacity, "clock": host.power_clock, "position": detached.node.position}
	for index: int in 100:
		planning.capture(host)
		planning.query(host, "relay", Vector3(index, 0, 0))
		_view(planning, host, detached)
		var sources: Array[Vector3] = planning.committed_sources(host)
		sources.clear()
	_check(host.buildings == before.buildings and host.sites == before.sites and host.stockpile == before.stockpile and host.rng.state == before.rng and host.power_used == before.used and host.power_capacity == before.capacity and host.power_clock == before.clock and detached.node.position == before.position, "100 capture/query/source reads do not mutate game state, position, stockpile, RNG or clock")
	_check(planning.committed_sources(host).size() == 1, "returned source list is detached")
	var other_host = _host()
	other_host.recompute_power()
	_check(not planning.is_fresh(other_host), "snapshot cannot be reused for another host")
	# Capture intentionally odd but committed flags. The observer must report the
	# allocation it saw, not replace it with its own independent solve.
	detached.powered = false
	host.power_used = 0.0
	planning.capture(host)
	_check(_view(planning, host, detached).status == "unpowered" and not detached.powered, "available capacity never invents an existing allocation")
	host.buildings.erase(detached)
	_check(not planning.is_fresh(host), "building removal invalidates immediately")
