extends SceneTree
## Main integration checks: real order dispatch, work, escort, and blocked UI.
const Navigation = preload("res://friendly_navigation.gd")
var g: Node
var checks: int = 0
var failures: Array[String] = []
var traversal_safe: bool = true

func _initialize():
	call_deferred("run")

func check(ok: bool, label: String):
	checks += 1
	if ok: print("PASS ", label)
	else:
		failures.append(label)
		push_error("FAIL " + label)

func step(count: int, dt: float = 0.05):
	for index in count:
		var positions: Array[Vector3] = []
		for actor in g.units: positions.append(actor.node.position)
		g.simulate(dt)
		for i in mini(positions.size(), g.units.size()):
			if not Navigation.segment_open(g.nav, positions[i], g.units[i].node.position): traversal_safe = false

func clean():
	for actor in g.units:
		actor.node.queue_free()
	g.units.clear()
	g.selected.clear()
	g.attack_move = false
	g.terrain_blocks.clear()
	for building in g.buildings.duplicate():
		if building.kind != "hq":
			g.buildings.erase(building)
			building.node.queue_free()
	g.buildings[0].node.position = Vector3(-25, 0, 25)
	g.rebuild_navigation()
	g.wave_clock = 100000
	g.threat_voice_clock = 100000
	g.active_card = false
	g.ended = false
	g.paused = false
	traversal_safe = true

func select(actor: Dictionary):
	g.selected = [actor]
	g.inspected = {}

func run():
	root.get_node("Campaign").launch = true
	root.get_node("Campaign").current = 0
	root.get_node("Campaign").muted = true
	g = load("res://main.tscn").instantiate()
	root.add_child(g)
	g.set_process(false)
	g.muted = true
	g.audio_system.set_muted(true)
	check(g.units.all(func(actor): return Navigation.cell_open(g.nav, Navigation.cell_of(actor.node.position))), "all starting units spawn outside solid navigation cells")
	clean()
	var actor: Dictionary = g.make_unit("guard", Vector3(-10, 0, -8))
	select(actor)
	for z in range(-12, -3): g.nav.set_point_solid(Vector2i(0, z))
	g.friendly_navigation.navigation_changed()
	g.command_at(Vector3(10, 0, -8))
	step(400)
	check(g.friendly_navigation.is_arrived(actor) and traversal_safe, "real ground command navigates around wall and arrives")
	actor.node.position = Vector3(-10, 0, -8)
	for z in range(-31, 32): g.nav.set_point_solid(Vector2i(0, z))
	g.friendly_navigation.navigation_changed()
	g.command_at(Vector3(10, 0, -8))
	step(100)
	check(actor.node.position == Vector3(-10, 0, -8) and g.selected_order_text().contains("経路なし"), "sealed real command remains stationary and shows no-route status")
	g.command_at(Vector3(-13, 0, -12))
	check(not g.selected_order_text().contains("経路なし"), "fresh real command clears stale blocked HUD before next tick")
	step(80)
	check(g.friendly_navigation.is_arrived(actor), "fresh command on reachable side advances normally")
	clean()
	actor = g.make_unit("guard", Vector3(-10, 0, -8))
	select(actor)
	g.attack_move = true
	g.command_at(Vector3(10, 0, -8))
	step(250)
	check(actor.task == "idle" and g.friendly_navigation.is_arrived(actor) and traversal_safe, "real attack-move reaches its destination safely and returns to idle")

	clean()
	actor = g.make_unit("guard", Vector3(-10, 0, -8))
	var escorted: Dictionary = g.make_unit("worker", Vector3(4, 0, -8))
	select(actor)
	g.command_at(escorted.node.position)
	step(180)
	check(actor.task == "escort" and g.friendly_navigation.is_arrived(actor) and traversal_safe, "real friendly click follows and reaches escort slot")
	escorted.goal = Vector3(12, 0, -8)
	escorted.task = "move"
	escorted.planned = Vector3.INF
	step(230)
	check(actor.task == "escort" and actor.node.position.x > 8.0 and g.friendly_navigation.is_arrived(actor) and traversal_safe, "escort follows moving ally, repaths, and settles again")

	clean()
	actor = g.make_unit("worker", Vector3(-10, 0, -15))
	var site: Dictionary = g.get_site("generator")
	site.node.position = Vector3(10, 0, -15)
	site.progress = 0.0
	site.reclaimed = false
	site.paid = false
	g.settlement_age = 2
	g.stockpile = {"food": 1000.0, "salvage": 1000.0, "parts": 1000.0}
	select(actor)
	g.command_at(site.node.position)
	step(400)
	check(site.progress > 0.0 and actor.task == "site" and traversal_safe, "real site order travels before restoration work advances")

	clean()
	actor = g.make_unit("worker", Vector3(-10, 0, -15))
	var house: Dictionary = g.make_building("house", Vector3(10, 0, -8))
	select(actor)
	g.command_at(house.node.position)
	step(800)
	check(house.built >= 1.0 and traversal_safe, "real construction order resolves solid building goal to free approach and finishes")
	house.hp = house.maxhp - 40.0
	actor.node.position = Vector3(-10, 0, -15)
	g.command_at(house.node.position)
	step(500)
	check(house.hp >= house.maxhp and traversal_safe, "real repair order travels to safe approach and repairs")

	clean()
	actor = g.make_unit("worker", Vector3(0.49, 0, 0.49))
	g.economy.assign_resource(actor, g.resource_nodes[0])
	actor.goal = Vector3(0.51, 0, 0.51)
	actor.planned = Vector3.INF
	for cell in [Vector2i(1, 0), Vector2i(0, 1), Vector2i(2, 1), Vector2i(1, 2)]:
		g.nav.set_point_solid(cell)
	g.friendly_navigation.navigation_changed()
	var before: float = g.resource_nodes[0].stock
	step(50)
	check(actor.cargo == 0.0 and g.resource_nodes[0].stock == before and g.friendly_navigation.current_status(actor) == Navigation.BLOCKED, "economy arrival hook prevents gathering across a blocked corner inside raw arrival radius")

	print("RECOVERY_ORDERS_SUMMARY checks=%d failures=%d" % [checks, failures.size()])
	g.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
