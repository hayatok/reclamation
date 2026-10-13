extends SceneTree
## Controlled integration fixtures, not earned campaign play. Run with a fresh
## XDG_DATA_HOME: this test writes real isolated checkpoints and victory records.
## Economy, travel, command dispatch, FIFO, combat and loading use the game paths.
const Orders = preload("res://worker_orders.gd")
const Validation = preload("res://checkpoint_validation.gd")
var g: Node
var passed := 0
var failed := 0

func _initialize(): call_deferred("run")

func check(ok: bool, label: String):
	if ok: passed += 1; print("PASS ", label)
	else: failed += 1; push_error("FAIL " + label)

func fresh(index: int = 2):
	if is_instance_valid(g): g.free()
	var campaign = root.get_node("Campaign")
	campaign.current = index; campaign.launch = true; campaign.resume = false
	campaign.muted = true; campaign.low_fx = true; campaign.best = {}
	campaign.run_seed = 20261013
	g = load("res://main.tscn").instantiate()
	root.add_child(g); current_scene = g; g.set_process(false)
	g.set_process_unhandled_input(false)
	g.wave_clock = 100000; g.threat_voice_clock = 100000
	g.auto_save_clock = 100000; g.low_fx = true
	g.settlement_age = 3; g.tech_level = 3
	g.stockpile = {"food":1000.0, "salvage":1000.0, "parts":1000.0}
	# Controlled geometry keeps the real site footprint and navigation. Remove
	# unrelated actors/terrain so exact repair accounting has no other consumers.
	g.friendly_navigation.clear_reservations()
	for collection in [g.units, g.enemies]:
		for actor in collection: actor.node.free()
		collection.clear()
	g.selected.clear(); g.inspected = {}; g.inspected_site = {}; g.inspected_resource = {}
	g.terrain_blocks.clear(); g.rebuild_navigation()
	g.render_interpolation.reset(g.units, g.enemies, g.corpses)

func reclaimed_station() -> Dictionary:
	fresh()
	for site in g.sites:
		site.reclaimed = true; site.paid = true; site.progress = 1.0
	return g.get_site("pump")

func select(actors: Array):
	g.selected = actors.duplicate()
	g.inspected = {}; g.inspected_site = {}; g.inspected_resource = {}
	g.attack_move = false

func tick(count: int = 1):
	for step in count:
		if g.ended: return
		g.simulate(0.05)

func clear_enemies():
	for enemy in g.enemies: enemy.node.free()
	g.enemies.clear()

func worker_at(site: Dictionary, offset: Vector3 = Vector3(-7, 0, 0)) -> Dictionary:
	return g.make_unit("worker", site.node.position + offset)

func wait_for_work(worker: Dictionary, limit: int = 240):
	for step in limit:
		tick()
		if g.friendly_navigation.is_work_arrived(worker, g.nav): return

func check_initial_reclamation_and_scope():
	fresh()
	var station: Dictionary = g.get_site("pump")
	check(station.get("central_station", false) and station.get("maxhp", 0) == 600, "only the authored M3 central station starts with 600 maximum HP")
	var before: float = station.get("hp", -1)
	g.spawn_enemy(station.node.position + Vector3(-4, 0, 0))
	g.enemies.back().cd = 0
	tick(20)
	check(station.get("hp", -1) == before and not station.reclaimed, "unreclaimed central station is not an ordinary enemy damage target")
	clear_enemies()
	# Seed paid progress near completion, then finish with the ordinary order.
	station.paid = true; station.progress = 0.999
	var worker: Dictionary = worker_at(station)
	var funds: Dictionary = g.stockpile.duplicate()
	select([worker]); check(g.command_at(station.node.position), "normal right-click accepts unfinished central restoration")
	for step in 240:
		tick()
		if station.reclaimed: break
	check(station.reclaimed and station.paid and station.progress == 1 and station.hp == 600 and not station.disabled, "ordinary restoration completion leaves an operational 600 HP station")
	check(g.stockpile == funds, "finishing an already paid central restoration never charges a second restoration cost")
	check(not g.get_site("generator").get("central_station", false) and not g.get_site("substation").get("central_station", false), "M3 generator and substation remain outside the damageable-site contract")
	for index in [0, 1]:
		fresh(index)
		check(g.sites.all(func(site): return not site.get("central_station", false) and not site.has("disabled") and not site.has("hp")), "M%d existing sites gain no central-station damage or shutdown state" % (index + 1))

func check_enemy_damage_and_shutdown():
	var station := reclaimed_station()
	g.generator_on = true; g.hold_time = 12.5
	g.spawn_enemy(station.node.position + Vector3(-4, 0, 0))
	var enemy: Dictionary = g.enemies.back()
	enemy.cd = 0
	for step in 80:
		tick()
		if station.hp < 600: break
	check(station.hp == 591 and enemy.cd > 0, "ordinary enemy approach and attack applies its normal 9 damage to the reclaimed central station")
	# A controlled low-health setup tests the actual lethal-hit transition. The
	# asynchronous route scheduler may consume a new approach before the next
	# attack even with a zero cooldown, so observe the actual fatal-hit frame.
	station.hp = 1; enemy.cd = 0
	var held: float = g.hold_time
	for step in 80:
		held = g.hold_time
		tick()
		if station.disabled: break
	check(station.hp == 0 and station.disabled and station in g.sites and is_instance_valid(station.node), "lethal ordinary hit clamps HP to zero and retains the disabled site and node")
	check(station.reclaimed and station.paid and station.progress == 1 and not g.ended, "shutdown preserves reclamation/payment and does not turn into mission defeat")
	tick(20)
	check(station.hp == 0 and g.hold_time == held, "shutdown freezes accumulated hold on the fatal-hit frame and subsequent ticks")
	clear_enemies()

func check_boss_splash():
	var station := reclaimed_station()
	# The boss deliberately targets a nearby worker, not the station. Its normal
	# snapshotted windup must still damage the station with the area impact.
	var worker: Dictionary = worker_at(station, Vector3(-4, 0, 0))
	g.spawn_enemy(station.node.position + Vector3(-5, 0, 0), false, true, true)
	var boss: Dictionary = g.enemies.back()
	boss.cd = 0
	tick()
	check(boss.windup > 0 and boss.attack_pos == worker.node.position and station.hp == 600, "boss windup snapshots the nearby worker and deals no premature station damage")
	tick(27)
	check(station.hp == 600, "station splash waits for the complete 1.4 second boss telegraph")
	tick(2)
	check(station.hp == 480 and worker.hp == 55, "ordinary boss impact applies one 120 HP station splash and the existing 45 HP worker damage")
	tick(15)
	check(station.hp == 480, "boss cooldown prevents repeated damage from the completed windup")

func check_zero_hp_and_repair_accounting():
	var station := reclaimed_station()
	station.hp = 0; station.disabled = true; g.resources = 0
	var worker: Dictionary = worker_at(station)
	select([worker])
	check(g.command_at(station.node.position) and worker.task == "repair" and worker.target == station, "normal right-click accepts repair of the retained zero-HP central site")
	wait_for_work(worker)
	check(g.friendly_navigation.is_work_arrived(worker, g.nav), "zero-HP repair travels to a real reserved work cell outside the facility")
	tick(20)
	check(worker.task == "repair" and worker.target == station and station.hp == 0 and g.resources == 0 and station.disabled, "no salvage stalls the active repair without abandoning or reviving the station")
	g.resources = 0.05; tick()
	check(is_equal_approx(station.hp, 0.4) and is_equal_approx(g.resources, 0.01), "one unboosted worker repairs 8 HP per second at 0.1 salvage per HP")
	tick(20)
	check(is_equal_approx(station.hp, 0.5) and is_zero_approx(g.resources) and station.disabled, "fractional salvage buys only affordable HP and then stalls without overdraft")
	g.resources = 20
	var hp: float = station.hp
	var funds: float = g.resources
	tick(20)
	check(is_equal_approx(station.hp - hp, 8) and is_equal_approx(funds - g.resources, 0.8), "one arrived worker sustains exactly 8 HP and 0.8 salvage over one second")

func check_multiple_workers():
	var station := reclaimed_station()
	station.hp = 400; g.resources = 0
	var workers: Array = [worker_at(station, Vector3(-7, 0, -1)), worker_at(station, Vector3(-7, 0, 1)), worker_at(station, Vector3(0, 0, 7))]
	select(workers); g.command_at(station.node.position)
	for step in 300:
		tick()
		if workers.all(func(worker): return g.friendly_navigation.is_work_arrived(worker, g.nav)): break
	check(workers.all(func(worker): return g.friendly_navigation.is_work_arrived(worker, g.nav)) and g.friendly_navigation.work_reservations.size() == 3, "three ordinary repair orders acquire three independent reachable work cells")
	g.resources = 100; tick(20)
	check(is_equal_approx(station.hp, 424) and is_equal_approx(g.resources, 97.6), "three arrived workers add 24 HP per second and charge only 2.4 salvage")
	station.hp = 599.7; g.resources = 100
	tick(2)
	check(station.hp == 600 and is_equal_approx(g.resources, 99.97) and workers.all(func(worker): return worker.task == "idle"), "competing workers cap the final 0.3 HP, charge it once, and all finish normally")

func check_checkpoint_and_restart_threshold():
	var station := reclaimed_station()
	station.hp = 0; station.disabled = true
	g.generator_on = true; g.hold_time = 17.25; g.resources = 5
	var repairing: Dictionary = worker_at(station)
	select([repairing]); g.command_at(station.node.position)
	for step in 500:
		tick()
		if is_zero_approx(g.resources): break
	check(is_equal_approx(station.hp, 50) and station.disabled and repairing.task == "repair", "checkpoint fixture reaches 50 HP through real paid repair while remaining shut down")
	# Preserve an active site reference and a different worker's queued site
	# reference, both created by the ordinary right-click/Shift-right-click path.
	select([repairing]); g.command_at(Vector3(-25, 0, -22), Vector2.INF, true)
	var queued: Dictionary = worker_at(station, Vector3(0, 0, 7))
	select([queued]); g.command_at(Vector3(-25, 0, -24))
	check(g.command_at(station.node.position, Vector2.INF, true) and Orders.pending(queued).size() == 1 and Orders.pending(queued)[0].target == station, "Shift-right-click queues repair of the partially repaired disabled station")
	var snapshot: Dictionary = g.checkpoint_data()
	var station_index: int = g.sites.find(station)
	check(Validation.validate(snapshot) and snapshot.units[0].target_type == "site" and snapshot.units[0].target_index == station_index and snapshot.units[1].pending_orders[0].target_type == "site" and snapshot.units[1].pending_orders[0].target_index == station_index, "validated checkpoint serializes active and queued repair references as site indices")
	var old_node: int = station.node.get_instance_id()
	var saved: bool = g.save_checkpoint(false) == OK
	check(saved, "partial disabled repair writes an actual atomic checkpoint")
	if not saved: return
	station.hp = 599; station.disabled = false; g.hold_time = 1
	Orders.clear(queued)
	var loaded: bool = g.load_checkpoint()
	check(loaded, "partial disabled repair loads through the actual validated checkpoint path")
	if not loaded: return
	station = g.get_site("pump"); repairing = g.units[0]; queued = g.units[1]
	check(station.node.get_instance_id() != old_node and is_equal_approx(station.hp, 50) and station.maxhp == 600 and station.disabled and station.reclaimed and station.paid and station.progress == 1 and g.hold_time == 17.25, "load reconstructs station identity, partial HP, shutdown, paid progress and prior hold")
	check(repairing.task == "repair" and repairing.target == station and Orders.pending(repairing).size() == 1 and Orders.pending(repairing)[0].task == "move" and Orders.pending(queued).size() == 1 and Orders.pending(queued)[0].target == station, "load reconnects the active repair and both workers' FIFO orders to the new live objects")
	tick(160)
	check(is_equal_approx(station.hp, 50) and station.disabled and g.hold_time == 17.25 and queued.task == "repair" and queued.target == station, "loaded queued repair activates normally while no-salvage shutdown keeps the hold frozen")
	# Stop one worker through the ordinary command before the exact threshold.
	select([queued]); g.stop_selected()
	wait_for_work(repairing)
	station.hp = 149.2; g.resources = 20
	tick()
	check(is_equal_approx(station.hp, 149.6) and station.disabled and g.hold_time == 17.25, "repair below 25 percent cannot resume or reset the previous hold")
	tick()
	check(is_equal_approx(station.hp, 150) and not station.disabled and is_equal_approx(g.hold_time, 17.30), "the normal repair tick at 150 of 600 HP restarts the existing hold")
	tick(20)
	check(is_equal_approx(g.hold_time, 18.30) and station.reclaimed and station.paid and station.progress == 1, "operational hold continues from its preserved value after restart")

func check_boss_death_victory_gate():
	var station := reclaimed_station()
	station.hp = 0; station.disabled = true
	g.generator_on = true; g.hold_time = g.mission.hold; g.boss_spawned = true
	g.spawn_enemy(Vector3(22, 0, 24), false, true, true)
	var boss: Dictionary = g.enemies.back()
	g.hit(boss, 10000, true)
	tick()
	check(g.boss_defeated and not g.ended and g.hold_time == g.mission.hold and not root.get_node("Campaign").best.has("2"), "actual boss death and a completed hold cannot win while the central station is off")
	var worker: Dictionary = worker_at(station)
	g.resources = 30; select([worker]); g.command_at(station.node.position)
	for step in 650:
		tick()
		if g.ended: break
	check(station.hp >= 150 and not station.disabled and g.ended and g.result_won and root.get_node("Campaign").best.has("2"), "ordinary worker recovery permits victory once the saved hold and actual boss kill are already complete")

func run():
	if DirAccess.dir_exists_absolute("user://settlement_v2"):
		push_error("Fresh isolated XDG_DATA_HOME required"); quit(2); return
	check_initial_reclamation_and_scope()
	check_enemy_damage_and_shutdown()
	check_boss_splash()
	check_zero_hp_and_repair_accounting()
	check_multiple_workers()
	check_checkpoint_and_restart_threshold()
	check_boss_death_victory_gate()
	print("CENTRAL_STATION_DEFENSE_SUMMARY passed=%d failed=%d controlled_fixtures_only=true" % [passed, failed])
	g.free(); await process_frame; quit(1 if failed else 0)
