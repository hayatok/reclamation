extends Node3D
## Same six-part meshes, friendly MultiMeshes, interpolation and muzzle FX as play.
## Camera size 54 is the game's default zoom. --before is frozen v036 behavior.
## Space pause; B compare; Z toggles an explicitly labeled close inspection view.
const Actor = preload("res://actor_visuals.gd")
const Before = preload("res://tests/actor_visuals_before.gd")
const Motion = preload("res://survivor_motion.gd")
const Horde = preload("res://horde_renderer.gd")
const Interpolation = preload("res://render_interpolation.gd")
const Muzzles = preload("res://weapon_muzzles.gd")
const Effects = preload("res://battle_fx.gd")
const STEP: float = 1.0 / 30.0
var units: Array = []
var interpolation = Interpolation.new()
var renderer: Node3D
var fx: Node3D
var camera: Camera3D
var caption: Label
var before: bool = false
var paused: bool = false
var elapsed: float = 0.0
var remainder: float = 0.0
var duration: float = -1.0
var capture_at: float = 3.6
var capture_path: String = ""
var quit_capture: bool = false
var rendered: Dictionary = {}

func _ready():
	for arg: String in OS.get_cmdline_user_args():
		if arg == "--before": before = true
		if arg.begins_with("--capture="): capture_path = arg.trim_prefix("--capture=")
		if arg.begins_with("--capture-at="): capture_at = float(arg.trim_prefix("--capture-at="))
		if arg.begins_with("--duration="): duration = float(arg.trim_prefix("--duration="))
		if arg == "--quit-after-capture": quit_capture = true
	var environment := WorldEnvironment.new(); environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("283337")
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color("d5d4c8")
	environment.environment.ambient_light_energy = .8
	add_child(environment)
	var sunlight := DirectionalLight3D.new(); add_child(sunlight)
	sunlight.rotation_degrees = Vector3(-52, -35, 0); sunlight.light_energy = 1.7
	var floor := MeshInstance3D.new(); var plane := PlaneMesh.new(); plane.size = Vector2(95, 95); floor.mesh = plane
	var floor_mat := StandardMaterial3D.new(); floor_mat.albedo_color = Color("4a534d")
	floor.material_override = floor_mat; add_child(floor)
	camera = Camera3D.new(); add_child(camera); camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 54; camera.position = Vector3(37, 48, 43); camera.look_at(Vector3.ZERO); camera.current = true
	renderer = Horde.new(); add_child(renderer); fx = Effects.new(); add_child(fx)
	add_actor("worker", "walk", Vector3(-12, 0, -10), "WALK 4.0 m/s")
	add_actor("guard", "walk_fire", Vector3(0, 0, -10), "WALK + FIRE 4.4 m/s")
	add_actor("grenade", "walk", Vector3(12, 0, -10), "WALK 3.8 m/s")
	add_actor("guard", "fire", Vector3(-12, 0, 0), "RIFLE 0.72 s")
	add_actor("grenade", "fire", Vector3(0, 0, 0), "LAUNCHER 2.3 s")
	add_actor("guard", "shuffle", Vector3(12, 0, 0), "SMALL SEPARATION STEPS")
	add_actor("worker", "gather", Vector3(-12, 0, 10), "GATHER / DEPLETED AT 3 s")
	add_actor("worker", "site", Vector3(0, 0, 10), "UNPAID / WORK FROM 3 s")
	add_actor("worker", "repair", Vector3(12, 0, 10), "REPAIR / NO SUPPLY AT 3 s")
	interpolation.reset(units, [], [])
	var overlay := CanvasLayer.new(); add_child(overlay); caption = Label.new(); overlay.add_child(caption)
	caption.position = Vector2(18, 16); caption.add_theme_font_size_override("font_size", 20)
	update_caption()

func add_actor(kind: String, scenario: String, base: Vector3, title: String):
	var node := Node3D.new(); add_child(node); node.position = base; node.rotation.y = PI * .75
	Actor.add_human(node, kind)
	for mesh: Node in node.find_children("*", "MeshInstance3D", true, false): mesh.visible = false
	var label := Label3D.new(); add_child(label)
	label.text = title; label.position = base + Vector3(0, .04, 2.5)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED; label.font_size = 24; label.pixel_size = .013
	label.modulate = Color("d9cead")
	var unit := {"node": node, "kind": kind, "scenario": scenario, "base": base, "hp": 100.0, "task": "idle", "attack_at": -100.0, "cd": .30, "shot_cycle": .72, "cargo": 0.0, "economy_phase": "gathering", "label": label, "title": title}
	if scenario in ["gather", "site", "repair"]:
		unit.task = scenario
		var target_node := Node3D.new(); add_child(target_node)
		target_node.position = base - node.basis.z * .85
		unit["target"] = {"node": target_node, "hp": 30.0, "progress": .1}
		var workpiece := MeshInstance3D.new(); target_node.add_child(workpiece)
		var box := BoxMesh.new(); box.size = Vector3(.65, .45, .55); workpiece.mesh = box; workpiece.position.y = .225
		var material := StandardMaterial3D.new(); material.albedo_color = Color("746953"); workpiece.material_override = material
	units.append(unit)

func update_caption():
	caption.text = ("BEFORE v036" if before else "AFTER survivor motion") + " | " + ("NORMAL GAME ZOOM 54" if camera.size == 54 else "CLOSE INSPECTION 30") + " | %.2f s" % elapsed + "\nSame paths and shot cadence. At 3 s: gather/repair stop, paid site starts. Space pause · B compare · Z zoom"

func _unhandled_key_input(event: InputEvent):
	if not event is InputEventKey or not event.pressed or event.echo: return
	match event.keycode:
		KEY_SPACE: paused = not paused
		KEY_B: before = not before
		KEY_Z: camera.size = 30 if camera.size == 54 else 54
	update_caption()

func _process(delta: float):
	if not paused:
		remainder += minf(delta, .15)
		while remainder >= STEP:
			remainder -= STEP; interpolation.before_step(units, [], []); elapsed += STEP
			for unit: Dictionary in units:
				var previous: Vector3 = unit.node.position
				var observation: Dictionary = Motion.capture_work(unit)
				var scenario: String = unit.scenario
				if scenario in ["walk", "walk_fire"]:
					var speed: float = 4.0 if unit.kind == "worker" else (4.4 if unit.kind == "guard" else 3.8)
					unit.node.position = unit.base + Vector3(fposmod(elapsed * speed, 8.0) - 4.0, 0, 0)
					unit.node.rotation.y = -PI / 2.0
				elif scenario == "shuffle": unit.node.position = unit.base + Vector3(sin(elapsed * 4.0) * .12, 0, 0)
				elif scenario == "gather":
					unit.economy_phase = "gathering" if elapsed < 3.0 else "waiting_resource"
					if elapsed < 3.0: unit.cargo += STEP
				elif scenario == "site" and elapsed >= 3.0: unit.target.progress += STEP * .01
				elif scenario == "repair" and elapsed < 3.0: unit.target.hp += STEP
				if scenario in ["fire", "walk_fire"]:
					unit.cd -= STEP
					if unit.cd <= 0.0:
						unit.attack_at = elapsed; unit.cd = 2.3 if unit.kind == "grenade" else .72; unit.shot_cycle = unit.cd
						var origin: Vector3 = unit.node.position + Vector3(0, 1, 0)
						var socket: Dictionary = Muzzles.anchor(unit)
						fx.muzzle(origin, false, socket)
						if unit.kind == "guard": fx.beam(origin, origin - unit.node.basis.z * 4.5, Color("d2a148"), .1, .055, socket)
				if before:
					var age: float = elapsed - unit.attack_at
					var cycle: float = unit.shot_cycle
					var reload_phase: float = clampf((age - .2) / maxf(.2, cycle - .2), 0, 1) if age > .2 and age < cycle else -1.0
					Before.pose(unit.node, elapsed * 8 + unit.node.get_instance_id() % 17, unit.node.position.distance_to(previous) > .001, age, reload_phase, scenario in ["gather", "site", "repair"])
				else: Motion.update_pose(unit, previous, STEP, elapsed, Motion.did_work(unit, observation))
			interpolation.after_step(units, [], [])
			if (not capture_path.is_empty() and elapsed >= capture_at) or (duration > 0.0 and elapsed >= duration):
				remainder = STEP; break
	rendered = interpolation.frame(remainder / STEP)
	renderer.update_friends(units, rendered)
	var capturing: bool = not capture_path.is_empty() and elapsed >= capture_at
	fx.update(0.0 if paused or capturing else delta, camera, [], rendered)
	update_caption()
	if capturing:
		paused = duration <= 0.0
		var path: String = capture_path; capture_path = ""
		await RenderingServer.frame_post_draw
		var result: Error = get_viewport().get_texture().get_image().save_png(path)
		print("SURVIVOR_REVIEW_CAPTURE ", path, " result=", result, " before=", before, " zoom=", camera.size, " elapsed=", elapsed)
		if quit_capture: get_tree().quit(0 if result == OK else 1)
	elif duration > 0.0 and elapsed >= duration:
		get_tree().quit()
