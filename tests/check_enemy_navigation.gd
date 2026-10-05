extends SceneTree
const Navigation = preload("res://enemy_navigation.gd")
const Steering = preload("res://crowd_steering.gd")

class SilentAudio:
	extends Node
	func set_power(_enabled): pass
	func set_threat(_threat): pass
	func play_event(_event, _position): pass

class Probe:
	extends "res://main.gd"
	func _ready(): pass
	func update_economy(_dt): pass
	func active_producers(): return 0
	func update_shells(_dt): pass
	func update_corpses(_dt): pass
	func update_mission(_dt): pass
	func bank_earned_upgrades(): pass
	func drain_blast_queue(): pass
	func pulse(_position, _color, _radius, _duration): pass

var nodes: Array[Node] = []

func _initialize(): call_deferred("run")

func grid() -> AStarGrid2D:
	var nav := AStarGrid2D.new()
	nav.region = Rect2i(-31, -31, 63, 63)
	nav.cell_size = Vector2.ONE
	nav.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	nav.update()
	return nav

func target_at(position: Vector3, radius: float = 0.0) -> Dictionary:
	var node := Node3D.new()
	node.position = position
	nodes.append(node)
	return {"node": node, "kind": "hq", "radius": radius, "hp": 1000000.0, "maxhp": 1000000.0, "built": 1.0}

func enemy_at(position: Vector3) -> Dictionary:
	var node := Node3D.new()
	node.position = position
	nodes.append(node)
	return {"node": node, "dead": false, "route": [], "path_cd": 0.0, "cd": 0.0, "speed": 1.65, "hp": 45.0, "armored": false}

func seal(nav: AStarGrid2D):
	for z in range(-31, 32): nav.set_point_solid(Vector2i(0, z), true)

func request_step(helper, nav, enemies, target):
	helper.begin_step(nav)
	for enemy in enemies: helper.update_route(enemy, target, nav, 0.05)
	assert(helper.queries_this_step <= Navigation.MAX_QUERIES_PER_STEP, "Actual AStar query cap exceeded")

func run():
	for count in [300, 500]: check_sealed_horde(count)
	check_perimeter_budget()
	check_changed_goals_and_sources()
	check_moving_goal_fairness()
	for count in [300, 500]: check_integrated_horde(count)
	check_integrated_attacks()
	check_rng_and_render()
	for node in nodes:
		if is_instance_valid(node): node.free()
	print("ENEMY_NAVIGATION_PASS sealed_300_500=true fifo=true invalidation=true wall_attacks=true rng_unchanged=true")
	quit()

func check_sealed_horde(count: int):
	var nav := grid()
	seal(nav)
	var helper := Navigation.new()
	var target := target_at(Vector3(15, 0, 0))
	var enemies: Array = []
	for i in count:
		enemies.append(enemy_at(Vector3(-28 + i % 20, 0, -14 + i / 20)))
	var max_queries := 0
	var start := Time.get_ticks_usec()
	for tick in 200:
		request_step(helper, nav, enemies, target)
		max_queries = maxi(max_queries, helper.queries_this_step)
	var duration := Time.get_ticks_usec() - start
	assert(helper.total_queries == count, "Each unique sealed source should be queried only once over 10 s")
	for enemy in enemies:
		assert(enemy.route.is_empty() and enemy.enemy_nav.blocked)
	var completed_queries := helper.total_queries
	for tick in 200: request_step(helper, nav, enemies, target)
	assert(helper.total_queries == completed_queries, "Unchanged blocked result must persist beyond the cooldown")
	var late := enemy_at(enemies[0].node.position)
	enemies.append(late)
	request_step(helper, nav, enemies, target)
	request_step(helper, nav, enemies, target)
	assert(helper.total_queries == completed_queries and helper.negative_hits > 0, "Shared negative cache must answer a new enemy at the same source")
	# Open the actual divider. Existing blocked actors must recover without any
	# cooldown expiry, while the per-step budget still spreads the burst.
	nav.set_point_solid(Vector2i(0, 0), false)
	helper.navigation_changed()
	var recovery_ticks := 0
	while enemies.any(func(enemy): return enemy.route.is_empty()) and recovery_ticks < 30:
		request_step(helper, nav, enemies, target)
		recovery_ticks += 1
	assert(enemies.all(func(enemy): return not enemy.route.is_empty()), "All blocked enemies must recover after the opening")
	assert(recovery_ticks <= 1 + ceili(float(enemies.size()) / Navigation.MAX_QUERIES_PER_STEP))
	for enemy in enemies:
		var previous: Vector3 = enemy.node.position
		for waypoint in enemy.route:
			assert(Steering._safe_step(previous, waypoint, nav), "Recovered route must not cross solid corners")
			previous = waypoint
	print("SEALED_HORDE count=%d seconds=10 actual_queries=%d max_step=%d baseline_empty_route_minimum=%d cpu_ms=%.2f all_recovered_seconds=%.2f" % [count, completed_queries, max_queries, count * 200, duration / 1000.0, recovery_ticks * 0.05])

func check_perimeter_budget():
	var nav := grid()
	seal(nav)
	for x in range(12, 19):
		for z in range(-3, 4): nav.set_point_solid(Vector2i(x, z))
	var helper := Navigation.new()
	var target := target_at(Vector3(15, 0, 0), 3.0)
	var enemies: Array = []
	for i in 500: enemies.append(enemy_at(Vector3(-28 + i % 20, 0, -14 + i / 20)))
	for tick in 25: request_step(helper, nav, enemies, target)
	assert(helper.total_queries == 24 * Navigation.MAX_QUERIES_PER_STEP, "Perimeter probes must be included in the cap")
	assert(enemies.all(func(enemy): return enemy.enemy_nav.index >= 1), "One sealed-building job must not starve the horde")
	nav.set_point_solid(Vector2i(0, 0), false)
	helper.navigation_changed()
	for tick in 17: request_step(helper, nav, enemies, target)
	assert(enemies.all(func(enemy): return not enemy.route.is_empty()), "Rebuild must abandon stale perimeter queues and recover promptly")
	# One completed sealed-building request also has a stable negative result.
	seal(nav); helper = Navigation.new()
	var lone := enemy_at(Vector3(-10, 0, 0))
	for tick in 150: request_step(helper, nav, [lone], target)
	assert(lone.enemy_nav.blocked)
	var queries := helper.total_queries
	for tick in 200: request_step(helper, nav, [lone], target)
	assert(helper.total_queries == queries)
	print("SEALED_BUILDING_PERIMETER_PASS alternate_queries_in_cap=true failed_queries=", queries)

func check_changed_goals_and_sources():
	var nav := grid(); seal(nav)
	var helper := Navigation.new()
	var target := target_at(Vector3(15, 0, 0))
	var enemy := enemy_at(Vector3(-10, 0, 0))
	for tick in 3: request_step(helper, nav, [enemy], target)
	assert(enemy.enemy_nav.blocked)
	target.node.position = Vector3(-15, 0, 0)
	for tick in 2: request_step(helper, nav, [enemy], target)
	assert(not enemy.route.is_empty(), "A moving goal must invalidate its old negative answer immediately")
	var other := target_at(Vector3(15, 0, 0))
	for tick in 2: request_step(helper, nav, [enemy], other)
	assert(enemy.enemy_nav.blocked, "Different target identity must replace a prior route")
	enemy.node.position = Vector3(10, 0, 0)
	for tick in 26: request_step(helper, nav, [enemy], other)
	assert(not enemy.route.is_empty(), "Source relocation must invalidate negative reachability")
	var solid := enemy_at(Vector3.ZERO)
	for tick in 3: request_step(helper, nav, [solid], other)
	assert(solid.route.is_empty() and solid.enemy_nav.blocked, "A solid source must never be snapped across the wall")
	print("ENEMY_GOAL_SOURCE_INVALIDATION_PASS")

func check_moving_goal_fairness():
	var nav := grid()
	var helper := Navigation.new()
	var target := target_at(Vector3(15, 0, 0))
	var enemies: Array = []
	for i in 500: enemies.append(enemy_at(Vector3(-28 + i % 20, 0, -14 + i / 20)))
	var serviced: Dictionary = {}
	for tick in 24:
		target.node.position.z = float(tick % 12)
		request_step(helper, nav, enemies, target)
		for i in enemies.size():
			if not enemies[i].route.is_empty(): serviced[i] = true
	assert(serviced.size() == 500, "Repeated moving-goal refreshes must retain FIFO positions for all enemies")
	print("MOVING_TARGET_FAIRNESS_PASS serviced=", serviced.size())

func game_probe() -> Probe:
	var game := Probe.new()
	root.add_child(game)
	game.set_process(false)
	game.nav = grid()
	game.audio_system = SilentAudio.new()
	game.add_child(game.audio_system)
	game.wave_clock = 1000
	game.low_fx = true
	return game

func check_integrated_attacks():
	var game := game_probe()
	var core := target_at(Vector3(10, 0, 0), 1.5)
	var wall := target_at(Vector3(-2, 0, 0), 0.8)
	wall.kind = "wall"
	game.buildings = [core, wall]
	var enemy := enemy_at(Vector3(-8, 0, 0))
	game.enemies = [enemy]
	game.rebuild_navigation()
	for tick in 150:
		var previous: Vector3 = enemy.node.position
		game.simulate(0.05)
		assert(Steering._safe_step(previous, enemy.node.position, game.nav), "Integrated pursuit crossed a solid cell or corner")
	assert(wall.hp < wall.maxhp and core.hp == core.maxhp, "Nearest breakable wall must still receive ordinary enemy attacks")
	var wall_damage: float = wall.maxhp - wall.hp
	game.buildings.erase(wall)
	game.rebuild_navigation()
	var position_at_removal: Vector3 = enemy.node.position
	for tick in 200:
		var previous: Vector3 = enemy.node.position
		game.simulate(0.05)
		assert(Steering._safe_step(previous, enemy.node.position, game.nav))
	assert(enemy.node.position.x > position_at_removal.x + 4.0 and core.hp < core.maxhp, "Wall removal must resume pursuit and ordinary attacks")
	print("INTEGRATED_WALL_PURSUIT_ATTACK_PASS wall_damage=%.0f core_damage=%.0f" % [wall_damage, core.maxhp - core.hp])
	game.free()

func check_integrated_horde(count: int):
	var game := game_probe()
	game.threat_voice_clock = 1000
	game.buildings = [target_at(Vector3(15, 0, 0))]
	seal(game.nav)
	var positions: Array[Vector3] = []
	for i in count:
		var position := Vector3(-28 + i % 20, 0, -14 + i / 20)
		positions.append(position)
		game.enemies.append(enemy_at(position))
	for tick in 200:
		game.simulate(0.05)
		assert(game.enemy_navigation.queries_this_step <= Navigation.MAX_QUERIES_PER_STEP)
	assert(game.enemy_navigation.total_queries == count, "The full simulation must retain completed empty routes")
	for i in count: assert(game.enemies[i].node.position == positions[i])
	game.rebuild_navigation()
	for tick in 20:
		game.simulate(0.05)
		assert(game.enemy_navigation.queries_this_step <= Navigation.MAX_QUERIES_PER_STEP)
	for i in count:
		assert(game.enemies[i].node.position.distance_to(positions[i]) > 0.01, "Every foe must actually resume moving after rebuild")
	print("INTEGRATED_SEALED_HORDE_PASS count=%d seconds=10 sealed_queries=%d all_moving_after_open_seconds=1.00" % [count, count])
	game.free()

func check_rng_and_render():
	var game := game_probe()
	var target := target_at(Vector3(10, 0, 0))
	var enemy := enemy_at(Vector3(-10, 0, 0))
	game.buildings = [target]
	game.enemies = [enemy]
	game.rng.seed = 101; game.card_rng.seed = 202; game.visual_rng.seed = 303
	var states := [game.rng.state, game.card_rng.state, game.visual_rng.state]
	seed(404); var expected := randf(); seed(404)
	for tick in 100: game.simulate(0.05)
	assert(states == [game.rng.state, game.card_rng.state, game.visual_rng.state])
	assert(randf() == expected, "Navigation must not consume the global RNG")
	# Replaying the exact simulation work at different display rates cannot
	# change either the scheduler's result or how many path queries it issues.
	var signatures: Array = []
	for fps in [10, 20, 30, 60]:
		var replay := game_probe()
		var replay_target := target_at(Vector3(10, 0, 0))
		var replay_enemy := enemy_at(Vector3(-10, 0, 0))
		replay.add_child(replay_enemy.node)
		replay.add_child(replay_target.node)
		replay.buildings = [replay_target]; replay.enemies = [replay_enemy]
		for frame in fps * 3: replay.advance_simulation_time(1.0 / fps)
		signatures.append([replay_enemy.node.position, replay.enemy_navigation.total_queries, replay_target.hp])
		replay.free()
	assert(signatures.all(func(signature): return signature == signatures[0]))
	game.free()
	print("ENEMY_FIXED_CLOCK_RNG_PASS fps=10,20,30,60")
