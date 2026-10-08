extends SceneTree
## Independent recovery check. No game source changes or claim of full historical restoration.
const Actor = preload("res://actor_visuals.gd")
const Motion = preload("res://survivor_motion.gd")
const Muzzles = preload("res://weapon_muzzles.gd")
const Guard = preload("res://articulated_survivor.gd")
const Grenadier = preload("res://articulated_grenadier.gd")
var game
var checks := 0
var failures := 0
var shots := 0
var max_generated_error := 0.0
var max_mesh_lip_error := 0.0

func _initialize(): call_deferred("run")

func check(ok: bool, message: String):
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func near(actual: Vector3, expected: Vector3, message: String, tolerance: float = .0001):
	var error := actual.distance_to(expected)
	max_generated_error = maxf(max_generated_error, error)
	check(error < tolerance, message + " error=" + str(error))

func clear_fx():
	for shell: Dictionary in game.shells: shell.node.free()
	game.shells.clear()
	for items: Array in game.battle_fx.particles.values(): items.clear()

func geometry_lip(kind: String) -> Vector3:
	# Independently derive barrel tip from actual front-face vertices, not muzzle constants.
	var mesh: ArrayMesh = Actor.mesh_for(kind, "weapon")
	var minimum_z: float = mesh.get_aabb().position.z
	var vertices: PackedVector3Array = mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var low := Vector3(INF, INF, INF)
	var high := Vector3(-INF, -INF, -INF)
	for vertex: Vector3 in vertices:
		if absf(vertex.z - minimum_z) < .00001:
			low = low.min(vertex)
			high = high.max(vertex)
	return (low + high) * .5

func check_motion(unit: Dictionary):
	var node: Node3D = unit.node
	var kind: String = unit.kind
	var roots := node.transform
	var gameplay := {"hp": unit.hp, "cd": unit.cd, "task": unit.task, "shots": unit.shots, "goal": unit.goal}
	for speed: float in [.0, .2, 1.2, 4.4]:
		node.set_meta(Motion.META, {"phase": .2, "weight": 0.0, "working": false, "work_phase": 0.0})
		var distance := Guard.cycle_distance(speed) if kind == "guard" else Grenadier.cycle_distance(speed)
		var expected_phase := .2
		for step: int in 30:
			var previous: Vector3 = node.position
			node.position.z -= speed / 30.0
			expected_phase = fposmod(expected_phase + speed / 30.0 * TAU / distance, TAU)
			var authoritative: Transform3D = node.transform
			Motion.update_pose(unit, previous, 1.0 / 30.0, step / 30.0)
			check(node.transform.is_equal_approx(authoritative), kind + " motion leaves root untouched")
		check(absf(float(node.get_meta(Motion.META).phase) - expected_phase) < .0001, kind + " cadence follows actual distance and speed-specific stride")
		var phase: float = node.get_meta(Motion.META).phase
		for step: int in 8: Motion.update_pose(unit, node.position, 1.0 / 30.0, 1.0 + step / 30.0)
		check(node.get_meta(Motion.META).phase == phase and node.get_meta(Motion.META).weight == 0.0, kind + " stops without marching")
		var prior: Vector3 = node.position
		node.position.x += 10.0
		Motion.update_pose(unit, prior, 1.0 / 30.0, 2.0)
		check(node.get_meta(Motion.META).phase == phase, kind + " teleport does not advance gait")
	for key: String in gameplay: check(unit[key] == gameplay[key], kind + " animation preserves " + key)
	node.transform = roots

func run():
	root.get_node("Campaign").current = 0
	root.get_node("Campaign").launch = true
	game = load("res://main.tscn").instantiate()
	root.add_child(game)
	game.set_process(false)
	game.muted = true
	game.low_fx = true
	game.wave_clock = 9999
	game.upgrades = {}
	game.spawn_enemy(Vector3(0, 0, -7))
	var target: Dictionary = game.enemies.back()
	target.armored = false
	target.hp = 100000.0
	for kind: String in ["guard", "grenade"]:
		var unit: Dictionary = game.make_unit(kind, Vector3.ZERO)
		var node: Node3D = unit.node
		var visual: Node3D = node.get_meta(&"actor_visuals")
		var parts: Array[Node3D] = Actor.part_nodes(visual)
		check(parts.size() == 14 and Actor.parts_for(kind).size() == 14, kind + " fourteen parts")
		check(Actor.muzzle_part_index(kind) == 13 and parts[13].name == "weapon", kind + " muzzle on weapon part 13")
		for part: String in Actor.parts_for(kind):
			var mesh: ArrayMesh = Actor.mesh_for(kind, part)
			check(mesh.get_surface_count() == 1 and mesh == Actor.mesh_for(kind, part), kind + " cached single-surface " + part)
		for proxy: MeshInstance3D in visual.find_children("*", "MeshInstance3D", true, false):
			check(not proxy.visible, kind + " hidden skeleton proxy")
		var lip := geometry_lip(kind)
		var lip_error := lip.distance_to(Actor.muzzle_local(kind))
		max_mesh_lip_error = maxf(max_mesh_lip_error, lip_error)
		check(lip_error < .0006, kind + " authored socket within 0.6mm of mesh lip (bore inset thickness)")
		check_motion(unit)
		for moving: bool in [false, true]:
			for direction: int in 8:
				for alpha: float in [0.0, .25, .7, 1.0]:
					clear_fx()
					game.ammo = 100.0
					var yaw: float = direction * TAU / 8.0
					var aim := Vector3(-sin(yaw), 0, -cos(yaw))
					node.position = Vector3(2, 0, 3)
					node.rotation.y = yaw - .35
					Actor.pose(node, .7, moving, .25)
					game.render_interpolation.reset(game.units, game.enemies, [])
					game.render_interpolation.before_step(game.units, game.enemies, [])
					if moving: node.position += aim * .09
					target.node.position = node.position + aim * 7.0
					var target_before: Vector3 = target.node.position
					var hp_before: float = target.hp
					var origin: Vector3 = node.position + Vector3(0, 1, 0)
					game.fire(origin, target, 20.0 if kind == "guard" else 56.0, kind, unit)
					shots += 1
					Actor.pose(node, 1.2, moving, 0.0)
					game.render_interpolation.after_step(game.units, game.enemies, [])
					var roots: Transform3D = node.transform
					var rendered: Dictionary = game.render_interpolation.frame(alpha)
					game.horde_renderer.update_friends(game.units, rendered)
					game.resolve_shell_muzzles(rendered)
					game.battle_fx.update(0.0, game.camera, [], rendered)
					var state: Dictionary = rendered[node.get_instance_id()]
					var expected: Vector3 = state.world * state.parts[13] * Actor.muzzle_local(kind)
					check(state.parts.size() == 14, kind + " interpolated fourteen-part snapshot")
					check(game.horde_renderer._friendly_batches[kind].size() == 14, kind + " fourteen friendly batches")
					check(node.transform.is_equal_approx(roots), kind + " interpolation preserves simulation root")
					near(target.node.position, target_before, kind + " target is unchanged")
					var anchored_flashes := 0
					for flash: Dictionary in game.battle_fx.particles.flash:
						if flash.has("muzzle"):
							anchored_flashes += 1
							near(flash.pos, expected, kind + " real fire flash equals interpolated weapon tip")
					check(anchored_flashes == 1, kind + " exactly one real muzzle flash")
					if kind == "guard":
						check(is_equal_approx(hp_before - target.hp, 20.0) and is_equal_approx(game.ammo, 99.0), "guard damage and ammo unchanged")
						check(game.battle_fx.particles.streak.size() == 2, "real rifle generates two tracer layers")
						for streak: Dictionary in game.battle_fx.particles.streak:
							near(Transform3D(streak.basis, streak.pos) * Vector3(0, 0, .5), expected, "real rifle tracer starts at interpolated weapon tip")
					else:
						var shell: Dictionary = game.shells[0]
						near(shell.node.position, expected, "real grenade first displayed position equals interpolated weapon tip")
						near(shell.visual_from, expected, "grenade retains visual launch point")
						near(shell.from, origin, "grenade simulation origin unchanged")
						near(shell.to, target_before, "grenade target unchanged")
						check(is_equal_approx(shell.damage, 56.0) and is_equal_approx(shell.duration, .8) and is_equal_approx(shell.radius, 3.0), "grenade gameplay values unchanged")
						check(is_equal_approx(target.hp, hp_before) and is_equal_approx(game.ammo, 97.0), "grenade damage deferred and ammo unchanged")
		clear_fx()
	for kind: String in ["infected", "runner", "armored"]:
		check(Actor.parts_for(kind).size() == 6 and Actor.sample_pose(kind, 1.2, true).size() == 6, kind + " legacy six-part contract remains")
	check(Actor.parts_for("worker").size() == 15 and Actor.sample_pose("worker",1.2,true).size() == 15, "new worker fifteen-part contract")
	print("RECOVERED_ACTOR_INTEGRATION_SUMMARY checks=", checks, " failures=", failures, " generated_shots=", shots, " max_generated_origin_error_m=", max_generated_error, " max_mesh_lip_error_m=", max_mesh_lip_error, " gpu_readback=false")
	game.free()
	await process_frame
	quit(1 if failures else 0)
