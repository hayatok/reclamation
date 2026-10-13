extends SceneTree
## ONE scripted, normal-cost continuation. This is not human-play evidence.
## Run against working_reconstruction, with a fresh isolated XDG_DATA_HOME.
## No restart, grants, map edits, enemy edits, RNG edits or rule overrides.
const INPUT := "res://tests/fixtures/earned_rebuilt_m3_preparation.json"
const INPUT_SHA := "447e3e3f986e69cd4736a5fcd339206baa764712a501a71b242ef62e4439b390"
const OUTPUT := "user://earned_m3_continuation_poststate.json"
const REPORT := "user://earned_m3_continuation_report.json"
const Rules = preload("res://settlement_rules.gd")
const Validation = preload("res://checkpoint_validation.gd")
const Clock = preload("res://simulation_clock.gd")
const Station = preload("res://central_station_defense.gd")
const LIMIT := 480.0
const CARD_PRIORITY := ["sweep", "cascade", "multi", "chain", "blast", "salvo", "pierce", "damage", "rate", "range", "repair", "supply", "armor", "salvage", "build"]
# Each placement gets only these explicit alternatives. No grid search/rebuilds.
const HOME_PLAN := [
	{"name":"west_tower", "kind":"tower", "points":[Vector3(-7,0,1), Vector3(-6,0,2), Vector3(-7,0,4)]},
	{"name":"factory", "kind":"factory", "points":[Vector3(4,0,-1), Vector3(6,0,-3), Vector3(5,0,-2)]},
	{"name":"workshop", "kind":"vehicle_workshop", "points":[Vector3(-2,0,0), Vector3(-1,0,-1)]}
]
const FIELD_PLAN := [
	{"name":"central_relay", "kind":"relay", "points":[Vector3(-6,0,-9), Vector3(-7,0,-10)]},
	{"name":"central_tower", "kind":"tower", "points":[Vector3(-21,0,-12), Vector3(-22,0,-12)]},
	{"name":"central_mortar", "kind":"mortar", "points":[Vector3(-10,0,-12), Vector3(-11,0,-13)]}
]
var game: Node
var start_time := 0.0
var steps := 0
var engineers: Array = []
var restorers: Array = []
var home_guards: Array = []
var field_guards: Array = []
var placed: Dictionary = {}
var attempted: Dictionary = {}
var actions: Array = []
var snapshots: Array = []
var blocked: Dictionary = {}
var home_stage := 0
var field_stage := 0
var field_started := false
var pump_ordered := false
var substation_ordered := false
var reinforcement_count := 0
var last_wave := -1
var last_station_status := ""
var station_min_hp := INF
var repair_orders := 0
var previous_sites: Dictionary = {}

func _initialize(): call_deferred("run")

func emit(event: String, data: Dictionary = {}):
	var entry := {"event":event, "elapsed":float(game.elapsed) if is_instance_valid(game) else 0.0, "data":data}
	actions.append(entry)
	print("M3_ACTION ", JSON.stringify(entry))

func fail(reason: String):
	push_error(reason)
	quit(2)

func living(group: Array) -> Array:
	return group.filter(func(unit): return unit in game.units and float(unit.hp) > 0 and is_instance_valid(unit.node) and not unit.node.is_queued_for_deletion())

func select(group: Array):
	game.cancel_targeting_mode()
	game.selected = living(group)
	game.inspected = {}; game.inspected_site = {}; game.inspected_resource = {}
	game.update_selection()

func order(group: Array, point: Vector3, label: String, attack: bool = false) -> bool:
	select(group)
	game.attack_move = attack
	var accepted: bool = game.command_at(point)
	game.attack_move = false
	if accepted: emit(label, {"units":game.selected.size(), "point":[point.x,point.y,point.z]})
	return accepted

func building(kind: String) -> Dictionary:
	for item in game.buildings:
		if item.kind == kind and float(item.hp) > 0: return item
	return {}

func completed(name: String) -> bool:
	var item: Dictionary = placed.get(name, {})
	return not item.is_empty() and item in game.buildings and float(item.hp) > 0 and float(item.built) >= 1.0

func busy(group: Array) -> bool:
	return living(group).any(func(unit): return unit.task in ["build", "repair", "site"])

func place_once(plan: Dictionary) -> bool:
	if attempted.has(plan.name): return completed(plan.name)
	if living(engineers).is_empty() or busy(engineers): return false
	var available: Dictionary = game.build_availability(plan.kind)
	if not available.ok: blocked[plan.name] = available.reason; return false
	select(engineers)
	game.set_build(plan.kind)
	attempted[plan.name] = true
	var rejected: Array = []
	for point: Vector3 in plan.points:
		var issue: String = game.placement_issue(plan.kind, point)
		if issue.is_empty() and game.place_building(point):
			placed[plan.name] = game.buildings.back()
			blocked.erase(plan.name)
			emit("build_" + plan.name, {"point":[point.x,point.y,point.z], "paid":placed[plan.name].paid_resources, "rejected":rejected})
			return false
		rejected.append({"point":[point.x,point.y,point.z], "reason":issue if not issue.is_empty() else "ordinary construction command rejected"})
	game.cancel_targeting_mode()
	blocked[plan.name] = rejected
	emit("placement_blocked_" + plan.name, {"attempts":rejected})
	return false

func choose_offered_card():
	if not game.active_card and not game.pending_upgrade_levels.is_empty(): game.open_growth_choices()
	if not game.active_card: return
	var offered: Array = game.cards.map(func(card): return card.id)
	if offered.is_empty(): return
	var choice := 0
	for preferred: String in CARD_PRIORITY:
		if preferred in offered: choice = offered.find(preferred); break
	var earned_level: int = game.pending_upgrade_levels[0]
	game.choose_upgrade(choice)
	emit("choose_offered_card", {"level":earned_level, "offered":offered, "chosen":offered[choice], "reroll":false})

func commander():
	choose_offered_card()
	if game.active_card or game.ended: return
	if home_stage < HOME_PLAN.size():
		if place_once(HOME_PLAN[home_stage]): home_stage += 1
	var grenadiers: Array = game.units.filter(func(unit): return unit.kind == "grenade" and unit.hp > 0)
	if not game.generator_on and game.get_site("generator").reclaimed and home_stage == HOME_PLAN.size() and grenadiers.size() >= 2 and living(home_guards).size() >= 4:
		game.toggle_generator()
		emit("activate_generator", {"surge_pending":game.incoming_surge, "wave_clock":game.wave_clock})
	var hq: Dictionary = building("hq")
	if game.settlement_age == 2 and game.production.pending_age() == 0 and not hq.is_empty():
		var allowed: Dictionary = game.production.can_queue_age(hq)
		if allowed.ok and game.production.queue_age(hq):
			blocked.erase("age_iii")
			emit("queue_age_iii", {"paid":Rules.age(3).cost})
		else: blocked["age_iii"] = allowed.reason
	# Two additional paid guards stay at the existing home rally. Never replace losses.
	if (game.production.pending_age() == 3 or game.settlement_age == 3) and reinforcement_count < 2:
		var barracks: Dictionary = building("barracks")
		if not barracks.is_empty() and game.production.population_used() + 1 <= game.production.population_cap() and game.production.can_queue_unit(barracks,"guard").ok:
			if game.production.queue_unit(barracks,"guard"):
				reinforcement_count += 1
				emit("queue_home_guard", {"number":reinforcement_count, "paid":Rules.unit("guard").cost})
	if game.settlement_age < 3: return
	# Leave the four original home guards on their saved goals; move only the
	# other two plus the two already-paid grenadiers into western cover.
	if not field_started:
		if living(home_guards).size() < 4 or living(field_guards).size() < 2 or grenadiers.size() < 2:
			blocked["central_cover"] = "Original four-guard HQ cover or two-guard/two-grenadier field force lost"
			return
		field_started = order(living(field_guards) + grenadiers.slice(0,2),Vector3(-13,0,-18),"deploy_central_cover",true)
	if field_stage < FIELD_PLAN.size():
		if place_once(FIELD_PLAN[field_stage]): field_stage += 1
		return
	var station: Dictionary = game.get_site("pump")
	var cover_ready: bool = completed("central_tower") and completed("central_mortar") and completed("central_relay")
	if not pump_ordered and cover_ready and not busy(engineers) and Rules.can_afford(game.stockpile,game.site_rule("pump").cost):
		pump_ordered = order(engineers,station.node.position,"restore_central_station")
	if not substation_ordered and pump_ordered and station.paid and not busy(restorers) and Rules.can_afford(game.stockpile,game.site_rule("substation").cost):
		substation_ordered = order(restorers,game.get_site("substation").node.position,"restore_substation")
	if Station.repairable(station) and not busy(engineers):
		if order(engineers,station.node.position,"repair_central_station"): repair_orders += 1
	# Idle repair workers return by the game's normal construction/gather rules.
	# Only ordinary new repair orders are issued when the station is damaged again.

func observe():
	for name: String in placed:
		var item: Dictionary = placed[name]
		if (item not in game.buildings or float(item.hp) <= 0) and not blocked.has(name):
			blocked[name] = "Paid construction lost; this one-shot plan does not rebuild it"
			emit("paid_building_lost", {"name":name})
	if game.wave != last_wave:
		last_wave = game.wave
		emit("wave_state", {"wave":game.wave, "enemies":game.enemies.filter(func(enemy): return not enemy.dead).size(), "next_in":game.wave_clock})
	for site in game.sites:
		var status: String = "%s/%s" % [site.paid,site.reclaimed]
		if previous_sites.get(site.kind,"") != status:
			previous_sites[site.kind] = status
			emit("site_state", {"kind":site.kind, "paid":site.paid, "reclaimed":site.reclaimed, "progress":site.progress})
	var station: Dictionary = game.get_site("pump")
	if station.reclaimed:
		station_min_hp = minf(station_min_hp,float(station.hp))
		var status: String = "disabled" if station.disabled else "operational"
		if status != last_station_status:
			last_station_status = status
			emit("central_station_state", {"status":status, "hp":station.hp, "hold":game.hold_time})

func snapshot() -> Dictionary:
	var hq: Dictionary = building("hq")
	var sites: Array = []
	for site in game.sites:
		sites.append({"kind":site.kind, "paid":site.paid, "reclaimed":site.reclaimed, "progress":site.progress, "hp":site.get("hp",null), "disabled":site.get("disabled",false)})
	var counts: Dictionary = {}
	for unit in game.units:
		if unit.hp > 0: counts[unit.kind] = counts.get(unit.kind,0) + 1
	return {"elapsed":game.elapsed, "continued_seconds":game.elapsed-start_time, "age":game.settlement_age, "stockpile":game.stockpile.duplicate(), "ammo":game.ammo, "hq_hp":hq.get("hp",0), "units":counts, "enemies":game.enemies.filter(func(enemy): return not enemy.dead).size(), "wave":game.wave, "wave_clock":game.wave_clock, "kills":game.kills, "generator":game.generator_on, "hold":game.hold_time, "boss_spawned":game.boss_spawned, "boss_defeated":game.boss_defeated, "sites":sites, "home_stage":home_stage, "field_stage":field_stage, "blocked":blocked.duplicate(true)}

func write_json(path: String, data: Dictionary) -> bool:
	var file := FileAccess.open(path,FileAccess.WRITE)
	if file == null: return false
	file.store_string(JSON.stringify(data,"\t"))
	file.close()
	return FileAccess.file_exists(path) and JSON.parse_string(FileAccess.get_file_as_string(path)) is Dictionary

func state_equal(a: Variant, b: Variant) -> bool:
	if a is Dictionary and b is Dictionary:
		if a.size() != b.size(): return false
		for key in a:
			if not b.has(key) or not state_equal(a[key],b[key]): return false
		return true
	if a is Array and b is Array:
		if a.size() != b.size(): return false
		for index in a.size():
			if not state_equal(a[index],b[index]): return false
		return true
	if (a is float or a is int) and (b is float or b is int):
		return absf(float(a)-float(b)) <= 0.000000001
	return a == b

func run():
	if FileAccess.get_sha256(INPUT) != INPUT_SHA: fail("Exact earned checkpoint checksum mismatch; no simulation started"); return
	if OS.get_environment("XDG_DATA_HOME").is_empty() or DirAccess.dir_exists_absolute("user://settlement_v2"):
		fail("A fresh isolated XDG_DATA_HOME is required; existing save directory is never overwritten"); return
	if FileAccess.file_exists(OUTPUT) or FileAccess.file_exists(REPORT): fail("One-shot output already exists; refusing another continuation"); return
	var raw: String = FileAccess.get_file_as_string(INPUT)
	var initial: Variant = JSON.parse_string(raw)
	if not Validation.validate(initial): fail("Actual input checkpoint failed current validation"); return
	if DirAccess.make_dir_recursive_absolute("user://settlement_v2") != OK: fail("Cannot prepare isolated loader directory"); return
	var input_copy := FileAccess.open("user://settlement_v2/checkpoint.json",FileAccess.WRITE)
	if input_copy == null: fail("Cannot copy earned checkpoint for the actual loader"); return
	input_copy.store_string(raw); input_copy.close()
	var campaign: Node = root.get_node("Campaign")
	campaign.current = int(initial.mission); campaign.run_seed = int(initial.run_seed)
	campaign.launch = true; campaign.resume = false; campaign.muted = true
	game = load("res://main.tscn").instantiate()
	root.add_child(game); current_scene = game
	game.set_process(false); game.set_process_input(false); game.set_process_unhandled_input(false)
	if not game.load_checkpoint(): fail("Ordinary load_checkpoint rejected the earned input"); return
	# Compare the mechanical state BEFORE selection, card choices or unpausing.
	var loaded: Dictionary = game.checkpoint_data()
	for key: String in ["run_seed","rng","card_rng","visual_rng","elapsed","wave_clock","wave","hold","noise","stockpile","resources","ammo","units","enemies","buildings","sites","resource_nodes","shells","blast_queue","upgrades","pending_upgrade_levels","cards","settlement_age","generator","first_activation","surge","paused"]:
		if not state_equal(loaded[key], initial[key]):
			write_json("user://earned_m3_loader_difference.json", {"field":key,"loaded":loaded[key],"input":initial[key]})
			fail("Loader changed checkpoint field: " + key); return
	start_time = game.elapsed
	engineers = [game.units[12],game.units[13]]
	restorers = [game.units[4],game.units[6]]
	home_guards = [game.units[0],game.units[1],game.units[10],game.units[11]]
	field_guards = [game.units[14],game.units[15]]
	emit("earned_checkpoint_loaded", {"input_sha256":INPUT_SHA, "state_verified":true, "bounded_seconds":LIMIT, "human_play_proof":false})
	order([game.units[2],game.units[3]],game.resource_nodes[3].node.position,"reassign_two_salvage_workers_to_southeast_food")
	order(restorers,game.get_site("generator").node.position,"restore_generator")
	if game.paused: game.toggle_pause()
	var stop_reason := "480 simulated seconds reached"
	var limit_steps: int = roundi(LIMIT / Clock.STEP)
	for index in limit_steps:
		if game.active_card or not game.pending_upgrade_levels.is_empty(): choose_offered_card()
		if index % 40 == 0: commander(); observe()
		if game.ended: stop_reason = "ordinary victory" if game.result_won else "headquarters defeated"; break
		if not game.simulation_running(): stop_reason = "ordinary simulation paused or card choice blocked"; break
		game.update_effects(Clock.STEP)
		steps += game.advance_simulation_time(Clock.STEP)
		if steps % 1200 == 0:
			var state: Dictionary = snapshot(); snapshots.append(state)
			print("M3_STATE ",JSON.stringify(state))
		# Let queued scene deletions run; the game's automatic process is disabled.
		if index % 20 == 19: await process_frame
	if game.ended: stop_reason = "ordinary victory" if game.result_won else "headquarters defeated"
	observe()
	var poststate: Dictionary = game.checkpoint_data()
	var state_saved: bool = write_json(OUTPUT,poststate)
	var summary: Dictionary = snapshot()
	summary.merge({"stop_reason":stop_reason, "ended":game.ended, "won":game.result_won, "steps":steps, "state_saved":state_saved, "poststate_valid":Validation.validate(poststate), "poststate_path":OUTPUT, "input_path":INPUT, "input_sha256":INPUT_SHA, "main_sha256":FileAccess.get_sha256("res://main.gd"), "rules_sha256":FileAccess.get_sha256("res://settlement_rules.gd"), "station_sha256":FileAccess.get_sha256("res://central_station_defense.gd"), "station_min_hp_after_reclamation":station_min_hp if is_finite(station_min_hp) else null, "station_repair_orders":repair_orders, "human_play_proof":false, "attempts":1})
	var report_saved: bool = write_json(REPORT,{"summary":summary,"sixty_second_states":snapshots,"actions":actions})
	print("M3_FINAL ",JSON.stringify(summary))
	print("M3_REPORT saved=",report_saved," path=",REPORT)
	game.free()
	await process_frame
	quit(0 if state_saved and report_saved else 2)
