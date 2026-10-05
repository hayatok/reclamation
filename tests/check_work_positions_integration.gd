extends SceneTree
const Nav = preload("res://friendly_navigation.gd")
var g: Node
var checks := 0
var failures: Array[String] = []
var safe := true
var speed_limited := true
var bounded := true
func _initialize(): call_deferred("run")
func check(ok: bool, label: String):
	checks += 1
	if ok: print("PASS ", label)
	else: failures.append(label); push_error("FAIL " + label)
func tick(workers: Array, count: int = 1):
	for step in count:
		var positions: Array = workers.map(func(w): return w.node.position)
		g.advance_simulation_time(0.05)
		for i in workers.size():
			var after: Vector3 = workers[i].node.position
			safe = safe and Nav.segment_open(g.nav, positions[i], after)
			speed_limited = speed_limited and positions[i].distance_to(after) <= float(g.GameRules.unit("worker").speed) * 0.05 + 0.0001
		bounded = bounded and g.friendly_navigation.queries_this_frame <= Nav.MAX_QUERIES_PER_FRAME
func positions_count(workers: Array) -> int:
	var positions := {}
	for worker in workers: positions[worker.node.position] = true
	return positions.size()
func run():
	var campaign = root.get_node("Campaign")
	campaign.current=0;campaign.launch=true;campaign.resume=false;campaign.muted=true
	g=load("res://main.tscn").instantiate();root.add_child(g);current_scene=g;g.set_process(false)
	var workers: Array=g.units.filter(func(w):return w.kind=="worker")
	g.selected=workers;g.update_selection()
	var before: float=g.stockpile.salvage
	g.set_build("house")
	check(g.place_building(Vector3(-4,0,19)), "six selected workers place an ordinary paid house")
	var house: Dictionary=g.buildings.back()
	check(g.stockpile.salvage == before-40 and house.paid_resources == {"salvage":40}, "distinct positions preserve exact house cost")
	for step in 100:
		tick(workers)
		if house.built>0.05:break
	check(house.built>0 and house.built<1 and g.friendly_navigation.work_reservations.size()==6, "six reservations exist during real construction")
	check(g.save_checkpoint(false)==OK, "construction scene saves through the actual schema-3 atomic writer")
	var positions: Array=workers.map(func(w):return w.node.position)
	var paid: Dictionary=house.paid_resources.duplicate()
	var progress: float=house.built
	check(g.load_checkpoint(), "actual checkpoint reload succeeds")
	workers=g.units.filter(func(w):return w.kind=="worker");house=g.buildings.back()
	check(positions==workers.map(func(w):return w.node.position) and house.built==progress and house.paid_resources.size()==paid.size() and house.paid_resources.salvage==paid.salvage, "reload preserves exact authoritative positions, progress, and payment")
	check(g.friendly_navigation.work_reservations.is_empty(), "load drops old node reservations instead of serializing them")
	tick(workers)
	check(g.friendly_navigation.work_reservations.size()==6, "first loaded simulation step reconstructs six distinct reservations")
	for step in 400:
		tick(workers)
		if house.built>=1 and workers.all(func(w):return w.task=="idle"):break
	check(house.built==1 and workers.all(func(w):return w.task=="idle"), "ordinary simulation completes house and all six build orders")
	check(positions_count(workers)==6, "six completed builders remain at six distinct authoritative positions")
	print("INTEGRATED_BUILDER_POSITIONS ", workers.map(func(w):return w.node.position))
	var selectable := true
	for worker in workers:
		var point: Vector2=g.camera.unproject_position(worker.node.position+Vector3(0,0.8,0))
		g.select_rect(point,point)
		selectable=selectable and g.selected.size()==1 and g.selected[0]==worker
	check(selectable, "each completed builder can be selected individually at its actual projected position")

	g.friendly_navigation.begin_frame(0, g.units)
	check(g.friendly_navigation.work_reservations.is_empty(), "completion promptly releases all reservations")
	# Repair has identical end-position behavior and ordinary resource charging.
	house.hp-=10;g.selected=workers;g.command_at(house.node.position)
	for step in 100:
		tick(workers)
		if workers.all(func(w):return w.task=="idle"):break
	check(house.hp==house.maxhp and positions_count(workers)==6 and workers.all(func(w):return w.task=="idle"), "six repair orders finish and preserve distinct positions")

	# Narrow access fixture. Initial actor positions are created as fixture
	# setup; after orders begin all movement is ordinary simulation/navigation.
	var target: Dictionary=g.make_building("relay",Vector3(-20,0,-5))
	var available: Array=g.friendly_navigation._work_perimeter(g.nav,target,Vector3(-26,0,-5))
	var slot: Vector3=available[0]
	for point in available:
		if point!=slot:g.nav.set_point_solid(Nav.cell_of(point),true)
	g.friendly_navigation.navigation_changed()
	var first: Dictionary=g.make_unit("worker",slot+Vector3(-3,0,0))
	var waiting: Dictionary=g.make_unit("worker",slot+Vector3(-3,0,-1))
	var approaching: Dictionary=g.make_unit("worker",slot+Vector3(-5,0,-2))
	var food: Dictionary=g.resource_nodes[0]
	g.economy.assign_resource(waiting,food)
	g.selected=[first,waiting,approaching];g.command_at(target.node.position)
	var narrow: Array=[first,waiting,approaching]
	for step in 250:
		tick(narrow)
		if g.friendly_navigation.is_arrived(first) and g.friendly_navigation.current_status(waiting)==Nav.WORK_WAITING:break
	check(g.friendly_navigation.is_arrived(first) and g.friendly_navigation.current_status(waiting)==Nav.WORK_WAITING, "real game narrow perimeter visibly waits behind its only working builder")
	g.selected=[waiting]
	check(g.selected_order_text()=="作業場所の空き待ち", "selected-unit UI distinguishes work-space waiting from no route")
	var waiting_before: Vector3=waiting.node.position
	# Set up almost-complete fixture so the first worker finishes this step.
	target.built=0.99999
	tick(narrow)
	check(target.built==1 and waiting.task=="gather" and waiting.resource_target==food and approaching.task=="idle", "completion releases waiting orders immediately and restores prior gathering or idle")
	check(waiting.node.position.distance_to(waiting_before)<=float(g.GameRules.unit("worker").speed)*0.05+0.0001, "completion does not relocate the waiting worker into the occupied slot")
	# The same lifecycle path also ends en-route orders when their target dies.
	target.built=0.5
	g.selected=[waiting,approaching];g.command_at(target.node.position)
	tick([waiting,approaching])
	target.hp=0
	tick([waiting,approaching])
	check(waiting.task=="gather" and waiting.resource_target==food and approaching.task=="idle", "destroyed target releases pending orders and restores the prior task")
	check(g.friendly_navigation.work_reservations.is_empty(), "destroyed target leaves no stale slot owner")
	# A separate open-perimeter job verifies cancellation while truly moving.
	var distant_target: Dictionary=g.make_building("relay",Vector3(21,0,6))
	var distant_worker: Dictionary=g.make_unit("worker",Vector3(25,0,14))
	g.economy.assign_resource(distant_worker,food)
	g.selected=[distant_worker];g.command_at(distant_target.node.position)
	tick([distant_worker])
	check(g.friendly_navigation.current_status(distant_worker)==Nav.MOVING, "completion edge fixture has a genuinely approaching builder")
	distant_target.built=1.0
	tick([distant_worker])
	check(distant_worker.task=="gather" and distant_worker.resource_target==food and not distant_worker.has("nav_work_cell"), "already-completed target releases an approaching worker before it reaches the perimeter")

	var barracks: Dictionary=g.make_building("barracks",Vector3(12,0,20),true)
	g.set_rally(barracks,Vector3(20,0,24))
	var combat: Array=[]
	for i in 6:combat.append(g.spawn_produced_unit("guard",barracks))
	for step in 160:
		var prior: Array=combat.map(func(u):return u.node.position)
		g.advance_simulation_time(0.05)
		for i in combat.size():
			safe=safe and Nav.segment_open(g.nav,prior[i],combat[i].node.position)
			speed_limited=speed_limited and prior[i].distance_to(combat[i].node.position)<=float(g.GameRules.unit("guard").speed)*0.05+0.0001
		bounded=bounded and g.friendly_navigation.queries_this_frame<=Nav.MAX_QUERIES_PER_FRAME
	check(positions_count(combat)==6 and combat.all(func(u):return u.task=="idle"), "six actual produced guards reach six distinct nearby rally positions")
	g.set_rally(g.buildings[0],food.node.position)
	var produced_worker: Dictionary=g.spawn_produced_unit("worker",g.buildings[0])
	check(produced_worker.task=="gather" and produced_worker.resource_target==food, "worker resource rally still auto-assigns its original gather behavior")
	check(safe and speed_limited and bounded, "integration movement stays traversable, speed-limited, and within eight AStar queries per step")
	print("WORK_POSITIONS_INTEGRATION_SUMMARY checks=%d failures=%d"%[checks,failures.size()])
	g.free();await process_frame;quit(0 if failures.is_empty() else 1)
