extends SceneTree
## Controlled integration fixtures, not a campaign playthrough. Run only with a
## new XDG_DATA_HOME. This script writes/restarts its own isolated checkpoints.
const Nav = preload("res://friendly_navigation.gd")
const Validation = preload("res://checkpoint_validation.gd")
const SAVE_PATH = "user://settlement_v2/checkpoint.json"
var g: Node
var checks := 0
var failures: Array[String] = []
var traversal_safe := true
var speed_limited := true
var bounded := true

func _initialize(): call_deferred("run")
func check(ok: bool, label: String):
	checks += 1
	if ok: print("PASS ", label)
	else: failures.append(label); push_error("FAIL " + label)
func fresh(index: int, resume: bool = false):
	if is_instance_valid(g): g.free()
	var campaign = root.get_node("Campaign")
	campaign.current = index; campaign.launch = true; campaign.resume = resume
	campaign.muted = true; campaign.run_seed = 20261005
	g = load("res://main.tscn").instantiate()
	root.add_child(g); current_scene = g; g.set_process(false)
	g.wave_clock = 100000; g.threat_voice_clock = 100000
func clear_actors():
	g.friendly_navigation.clear_reservations()
	for collection in [g.units, g.enemies]:
		for item in collection: item.node.free()
		collection.clear()
	g.selected.clear(); g.inspected = {}; g.attack_move = false
func controlled_geometry(index: int):
	fresh(index); clear_actors()
	for resource in g.resource_nodes: resource.node.free()
	g.resource_nodes.clear()
	g.terrain_blocks.clear()
	g.buildings[0].node.position = Vector3(-25, 0, 25)
	g.rebuild_navigation()
func choose(actors: Array):
	g.selected = actors.duplicate(); g.inspected = {}; g.inspected_resource = {}; g.inspected_site = {}
func tick(count: int = 1):
	for step in count:
		var before := {}
		for actor in g.units + g.enemies:
			before[actor.node.get_instance_id()] = actor.node.position
		g.simulate(0.05)
		for actor in g.units + g.enemies:
			if not is_instance_valid(actor.get("node")): continue
			var id: int = actor.node.get_instance_id()
			if not before.has(id): continue
			traversal_safe = traversal_safe and Nav.segment_open(g.nav, before[id], actor.node.position)
			var speed: float = float(actor.speed) if actor.has("speed") else float(g.GameRules.unit(actor.kind).speed)
			speed_limited = speed_limited and before[id].distance_to(actor.node.position) <= speed * 0.05 + 0.0001
		bounded = bounded and g.friendly_navigation.queries_this_frame <= Nav.MAX_QUERIES_PER_FRAME
		bounded = bounded and g.enemy_navigation.queries_this_step <= g.EnemyNavigation.MAX_QUERIES_PER_STEP
func settle_move(actor: Dictionary, limit: int = 600):
	for step in limit:
		tick()
		if actor.task == "idle" and g.friendly_navigation.is_arrived(actor): return
func map_click(point: Vector3):
	# Exercise the same handler connected to the minimap's GUI input signal.
	g.minimap.size = Vector2(192, 192)
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_RIGHT; event.pressed = true
	event.position = (Vector2(point.x, point.z) + Vector2(32, 32)) / 64 * g.minimap.size
	g.handle_minimap_input(event)
func expected_rect(site: Dictionary) -> Rect2i:
	# All authored mission anchors are integer coordinates. Their padded pads
	# occupy seven cells on each axis, independently of the helper under test.
	return Rect2i(Vector2i(int(site.node.position.x) - 3, int(site.node.position.z) - 3), Vector2i(7, 7))
func footprint_solid(site: Dictionary) -> bool:
	var rect := expected_rect(site)
	for x in range(rect.position.x, rect.end.x):
		for z in range(rect.position.y, rect.end.y):
			if not g.nav.is_point_solid(Vector2i(x, z)): return false
	return true
func grid_snapshot() -> Array:
	var result: Array = []
	for x in range(-31, 32):
		for z in range(-31, 32): result.append(g.nav.is_point_solid(Vector2i(x, z)))
	return result
func distinct_positions(actors: Array) -> int:
	var positions := {}
	for actor in actors: positions[actor.node.position] = true
	return positions.size()

func check_fresh_and_moves():
	for mission_index in 3:
		fresh(mission_index)
		check(g.sites.all(func(s): return footprint_solid(s)), "M%d fresh launch marks every facility before the first simulation tick" % (mission_index + 1))
		check(g.units.all(func(u): return Nav.cell_open(g.nav, Nav.cell_of(u.node.position))), "M%d starting friendlies remain outside all solids" % (mission_index + 1))
		g.make_building("wall", Vector3(25, 0, 25), true)
		check(g.sites.all(func(s): return footprint_solid(s)), "M%d later construction rebuild preserves facility footprints" % (mission_index + 1))
		var before := grid_snapshot()
		for site in g.sites: site.reclaimed = true; site.paid = true; site.progress = 1.0
		g.rebuild_navigation()
		check(before == grid_snapshot(), "M%d reclamation does not change the physical navigation footprint" % (mission_index + 1))
		controlled_geometry(mission_index)
		for site in g.sites:
			for command in ["move", "Q", "minimap"]:
				for destination in ["across", "inside"]:
					clear_actors()
					var p: Vector3 = site.node.position
					var guard: Dictionary = g.make_unit("guard", p + Vector3(-8.25, 0, 0.2))
					choose([guard])
					var point := p + (Vector3(8.7, 0, 0.25) if destination == "across" else Vector3(0.2, 0, 0.35))
					if command == "Q": g.begin_attack_move()
					if command == "minimap": map_click(point)
					else: g.command_at(point)
					check(guard.task == ("attack_move" if command == "Q" else "move"), "M%d %s %s %s dispatches ordinary order" % [mission_index + 1, site.kind, command, destination])
					settle_move(guard)
					check(guard.task == "idle" and g.friendly_navigation.is_arrived(guard) and not expected_rect(site).has_point(Nav.cell_of(guard.node.position)), "M%d %s %s %s arrives outside the body from a fractional start" % [mission_index + 1, site.kind, command, destination])
					if destination == "across": check(guard.node.position.x > p.x + 3, "crossing order reaches the opposite side")
		clear_actors()
		g.make_site("substation", Vector3(24, 0, 20))
		check(g.nav.is_point_solid(Vector2i(24, 20)), "normal site creation immediately updates navigation")

func check_separation_and_enemy():
	controlled_geometry(0)
	var site: Dictionary = g.get_site("generator")
	var rect := expected_rect(site)
	var origin := Vector3(rect.position.x - 0.6, 0, site.node.position.z)
	var guards: Array = []
	for index in 4: guards.append(g.make_unit("guard", origin))
	tick(100)
	check(distinct_positions(guards) == 4 and guards.all(func(u): return u.task == "idle"), "idle separation near the facility keeps four real positions outside its solid edge")
	clear_actors(); guards.clear()
	for index in 4: guards.append(g.make_unit("guard", origin))
	g.spawn_enemy(origin + Vector3(-4, 0, 0))
	var target: Dictionary = g.enemies.back()
	target.hp = 100000; target.speed = 0.01; target.cd = 100000
	choose(guards); g.command_at(target.node.position)
	tick(100)
	check(distinct_positions(guards) == 4 and guards.all(func(u): return u.task == "focus_fire" and u.target == target and u.get("attack_at", -1.0) > 0) and target.hp < 100000, "fire-holding separation preserves the target and firing while respecting the facility edge")
	clear_actors()
	# Ordinary enemy pursuit of a real HQ on the opposite side of the generator.
	g.buildings[0].node.position = site.node.position + Vector3(10, 0, 0)
	g.rebuild_navigation()
	g.spawn_enemy(site.node.position + Vector3(-10.25, 0, 0.2))
	var enemy: Dictionary = g.enemies.back()
	var hp: float = g.buildings[0].hp
	for step in 1500:
		tick()
		if g.buildings[0].hp < hp: break
	check(g.buildings[0].hp < hp and enemy.node.position.x > site.node.position.x + 3, "ordinary enemy pursuit routes around the site and reaches its HQ attack target")

func check_blocked_work():
	controlled_geometry(0)
	g.settlement_age = 3; g.tech_level = 3
	g.stockpile = {"food":10000.0, "salvage":10000.0, "parts":10000.0}
	var site: Dictionary = g.get_site("generator")
	var p: Vector3 = site.node.position
	var rect := expected_rect(site)
	# Seal only the preferred west perimeter into a pocket. Other sides remain
	# accessible, and all probes still share the normal eight-query budget.
	g.nav.fill_solid_region(Rect2i(rect.position + Vector2i(-2, -1), Vector2i(1, 9)), true)
	g.nav.fill_solid_region(Rect2i(rect.position + Vector2i(-2, -1), Vector2i(3, 1)), true)
	g.nav.fill_solid_region(Rect2i(rect.position + Vector2i(-2, 7), Vector2i(3, 1)), true)
	g.friendly_navigation.navigation_changed()
	var worker: Dictionary = g.make_unit("worker", p + Vector3(-9, 0, 0))
	choose([worker]); g.command_at(p)
	# A stale distant saved goal must never override target-derived approaches.
	worker.goal = Vector3(-20, 0, -20)
	for step in 800:
		tick()
		if site.progress > 0: break
	check(site.progress > 0 and g.friendly_navigation.is_work_arrived(worker, g.nav) and worker.node.position.x >= rect.position.x, "site worker rejects sealed preferred side and works at another reachable reserved perimeter")
	check(g.stockpile.salvage == 9880.0 and g.stockpile.parts == 9970.0, "first reachable restoration charges the unchanged cost once")
	# Reset only fixture geometry/actors; retain real paid state and progress.
	clear_actors(); g.rebuild_navigation()
	var outside := rect.grow(2)
	for x in range(outside.position.x, outside.end.x):
		for z in [outside.position.y, outside.end.y - 1]: g.nav.set_point_solid(Vector2i(x, z), true)
	for z in range(outside.position.y, outside.end.y):
		for x in [outside.position.x, outside.end.x - 1]: g.nav.set_point_solid(Vector2i(x, z), true)
	g.friendly_navigation.navigation_changed()
	worker = g.make_unit("worker", p + Vector3(-9, 0, 0))
	choose([worker]); g.command_at(p)
	var progress: float = site.progress
	var funds: Dictionary = g.stockpile.duplicate()
	tick(400)
	check(g.friendly_navigation.current_status(worker) == Nav.BLOCKED and site.progress == progress and g.stockpile == funds, "fully enclosed paid site has no progress and no extra charge")
	check(not g.friendly_navigation.is_work_arrived(worker, g.nav) and not worker.has("nav_work_cell"), "failed site search never advertises or reserves a work endpoint")
	# Cover the entire work perimeter too: generic move projection can find a
	# distant free endpoint, but a restoration order must refuse that endpoint.
	clear_actors(); g.rebuild_navigation()
	g.nav.fill_solid_region(rect.grow(1), true); g.friendly_navigation.navigation_changed()
	site.paid = false; site.progress = 0.0
	worker = g.make_unit("worker", p + Vector3(-9, 0, 0))
	choose([worker]); g.command_at(p)
	var projected: Vector3 = g.friendly_navigation._endpoint(g.nav, p, worker.node.position)
	tick(200); g.work_site(worker, 10.0)
	check(projected.is_finite() and not projected in g.friendly_navigation._work_perimeter(g.nav, site, worker.node.position), "ordinary projection can be outside the bounded site work perimeter")
	check(g.friendly_navigation.current_status(worker) == Nav.BLOCKED and site.progress == 0 and not site.paid and g.stockpile == funds, "unpaid enclosed site cannot work or charge from a too-far projected endpoint")
	# A real grid revision reopens access and resumes the same order normally.
	g.rebuild_navigation()
	for step in 500:
		tick()
		if site.progress > 0: break
	check(site.progress > 0 and site.paid and g.stockpile.salvage == funds.salvage - 120 and g.stockpile.parts == funds.parts - 30, "opening the site resumes reachable work and charges exactly once")
	choose([worker]); g.stop_selected(); g.friendly_navigation.begin_frame(0, g.units)
	check(g.friendly_navigation.work_reservations.is_empty(), "canceling restoration releases its work reservation")

func restart_checkpoint(label: String):
	var index: int = root.get_node("Campaign").current
	var before: Dictionary = g.checkpoint_data()
	var positions: Array = g.units.map(func(u): return u.node.position)
	check(g.save_checkpoint(false) == OK, label + " writes an actual validated atomic checkpoint")
	fresh(index, true)
	check(not g.title_open and positions == g.units.map(func(u): return u.node.position) and g.checkpoint_data().sites == before.sites and g.stockpile == before.stockpile, label + " scene restart preserves positions, site progress, payment and resources")
	check(g.friendly_navigation.work_reservations.is_empty() and g.sites.all(func(s): return footprint_solid(s)), label + " rebuilds site obstacles and leaves reservations transient")

func check_work_lifecycle():
	controlled_geometry(0)
	var site: Dictionary = g.get_site("generator")
	var p: Vector3 = site.node.position
	var slot := p + Vector3(-4, 0, 0)
	for point in g.friendly_navigation._work_perimeter(g.nav, site, slot):
		if point != slot: g.nav.set_point_solid(Nav.cell_of(point), true)
	g.friendly_navigation.navigation_changed()
	var worker: Dictionary = g.make_unit("worker", p + Vector3(-9, 0, 0))
	choose([worker]); g.command_at(p)
	var initial: Dictionary = g.stockpile.duplicate()
	settle_move(worker)
	check(worker.task == "idle" and site.progress == 0 and not site.paid and g.stockpile == initial, "reaching a site still enforces its original settlement-age requirement before payment")
	clear_actors(); g.settlement_age = 3; g.tech_level = 3
	g.stockpile = {"food":10000.0, "salvage":10000.0, "parts":10000.0}
	var workers: Array = []
	for index in 3: workers.append(g.make_unit("worker", p + Vector3(-9, 0, (index - 1) * 2)))
	choose(workers); g.command_at(p)
	for step in 500:
		tick()
		if workers.any(func(w): return g.friendly_navigation.is_work_arrived(w, g.nav)) and workers.filter(func(w): return g.friendly_navigation.current_status(w) == Nav.WORK_WAITING).size() == 2: break
	check(g.friendly_navigation.work_reservations.size() == 1 and workers.filter(func(w): return g.friendly_navigation.current_status(w) == Nav.WORK_WAITING).size() == 2, "one free site work cell has one worker and two distinct space waiters")
	var query_count: int = g.friendly_navigation.total_queries
	tick(60)
	check(g.friendly_navigation.total_queries == query_count, "known occupied site cell waits without repeated AStar queries")
	var waiting: Array = workers.filter(func(w): return g.friendly_navigation.current_status(w) == Nav.WORK_WAITING)
	var positions: Array = waiting.map(func(w): return w.node.position)
	site.progress = 0.99999
	tick(2)
	check(site.reclaimed and workers.all(func(w): return w.task == "idle") and g.friendly_navigation.work_reservations.is_empty(), "site completion immediately releases working and waiting orders")
	check(positions == waiting.map(func(w): return w.node.position), "completion leaves waiting workers at their own positions without jumping into the work cell")

func check_restart_and_workers():
	fresh(0); g.settlement_age = 3; g.tech_level = 3
	g.stockpile = {"food":10000.0, "salvage":10000.0, "parts":10000.0}
	var workers: Array = g.units.filter(func(u): return u.kind == "worker")
	var site: Dictionary = g.get_site("generator")
	choose(workers); g.command_at(site.node.position); tick(5)
	check(site.progress == 0 and not site.paid and workers.any(func(w): return g.friendly_navigation.current_status(w) == Nav.MOVING), "save fixture is genuinely mid-approach and still unpaid")
	restart_checkpoint("mid-approach")
	workers = g.units.filter(func(u): return u.kind == "worker"); site = g.get_site("generator")
	for step in 1000:
		tick()
		if workers.all(func(w): return g.friendly_navigation.is_work_arrived(w, g.nav)): break
	check(site.progress > 0 and site.progress < 1 and distinct_positions(workers) == 6 and g.friendly_navigation.work_reservations.size() == 6, "six restored orders acquire six distinct reachable work positions")
	restart_checkpoint("mid-work")
	workers = g.units.filter(func(u): return u.kind == "worker"); site = g.get_site("generator")
	tick()
	check(g.friendly_navigation.work_reservations.size() == 6, "first resumed work tick reconstructs six unique reservations")
	var funds: Dictionary = g.stockpile.duplicate()
	for step in 1600:
		tick()
		if site.reclaimed and workers.all(func(w): return w.task == "idle"): break
	check(site.reclaimed and workers.all(func(w): return w.task == "idle") and distinct_positions(workers) == 6 and g.stockpile == funds, "restoration finishes once, retains six positions and releases every completed order without another payment")
	restart_checkpoint("reclaimed")
	check(g.get_site("generator").reclaimed and g.friendly_navigation.work_reservations.is_empty(), "reclaimed restart keeps solid facility and no obsolete job reservations")
	# Old checkpoints whose actors occupy newly solid cells are rejected before
	# any live object is replaced. Never teleport or rewrite the actor position.
	var valid: Dictionary = g.checkpoint_data()
	var invalid := valid.duplicate(true)
	invalid.units[0].pos = invalid.sites[0].pos.duplicate()
	check(Validation.validate(valid) and not Validation.validate(invalid), "validator rejects old inside-site positions while accepting current checkpoints")
	var ids: Array = g.units.map(func(u): return u.node.get_instance_id())
	for suffix in ["", ".bak", ".tmp", ".bak.tmp"]:
		if FileAccess.file_exists(SAVE_PATH + suffix): DirAccess.remove_absolute(SAVE_PATH + suffix)
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify(invalid)); file.close()
	check(not g.load_checkpoint() and ids == g.units.map(func(u): return u.node.get_instance_id()), "incompatible load leaves the existing world and actor identities unchanged")
	# Real M3 terrain includes pipe blockers touching the southern site edges.
	fresh(2); g.settlement_age = 3; g.tech_level = 3
	g.stockpile = {"food":10000.0, "salvage":10000.0, "parts":10000.0}
	workers = g.units.filter(func(u): return u.kind == "worker")
	for kind in ["generator", "pump", "substation"]:
		site = g.get_site(kind); choose(workers); g.command_at(site.node.position)
		var before: Dictionary = g.stockpile.duplicate()
		for step in 1600:
			tick()
			if workers.all(func(w): return g.friendly_navigation.is_work_arrived(w, g.nav)): break
		check(workers.all(func(w): return g.friendly_navigation.is_work_arrived(w, g.nav)) and distinct_positions(workers) == 6, "M3 " + kind + " has six reachable distinct work positions with authored pipes intact")
		for step in 2000:
			tick()
			if site.reclaimed and workers.all(func(w): return w.task == "idle"): break
		var cost: Dictionary = g.site_rule(kind).cost
		check(site.reclaimed and g.stockpile.salvage == before.salvage - cost.salvage and g.stockpile.parts == before.parts - cost.parts, "M3 " + kind + " restores through ordinary simulation for one unchanged payment")
	check(not g.ended and g.hold_time == 0 and not g.generator_on, "restored M3 sites do not bypass the existing generator/hold/boss objective conditions")

func check_convoy_routes():
	for choice in 2:
		fresh(1); g.settlement_age = 3; g.tech_level = 3
		for site in g.sites: site.reclaimed = true; site.paid = true; site.progress = 1.0
		g.generator_on = true; g.resources = 1000; g.convoy_route_choice = choice
		g.launch_convoy(); g.convoy_encounter_stage = 3; g.wave_clock = 100000
		var convoy: Dictionary = g.convoy_unit()
		for step in 3000:
			tick()
			if g.ended: break
		check(g.ended and g.result_won and convoy.node.position.is_equal_approx(g.convoy_route().back()), "M2 route %d reaches ordinary convoy victory with site obstacles intact" % choice)
		check(g.resources == 920, "M2 convoy launch still charges its existing cost once")

func run():
	if DirAccess.dir_exists_absolute("user://settlement_v2"):
		push_error("Fresh isolated XDG_DATA_HOME required"); quit(2); return
	check_fresh_and_moves()
	check_separation_and_enemy()
	check_blocked_work()
	check_work_lifecycle()
	check_restart_and_workers()
	check_convoy_routes()
	check(traversal_safe and speed_limited and bounded, "all observed movement remains traversable, speed-limited and within shared query budgets")
	print("MISSION_SITE_NAVIGATION_SUMMARY checks=%d failures=%d" % [checks, failures.size()])
	g.free(); await process_frame; quit(0 if failures.is_empty() else 1)
