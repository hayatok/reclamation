extends SceneTree
## Controlled presentation fixtures, not evidence of earned campaign completion.
const Transition = preload("res://aftermath_transition.gd")
var passed: int = 0
var failed: int = 0
var g: Node

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, description: String) -> void:
	if ok:
		passed += 1
		print("PASS ", description)
	else:
		failed += 1
		push_error("FAIL " + description)

func gameplay_snapshot() -> Dictionary:
	var snapshot: Dictionary = g.checkpoint_data()
	# Camera and current selection are the existing result presentation changes.
	snapshot.erase("camera")
	snapshot.erase("selected")
	return snapshot.duplicate(true)

func friendly_instance_count() -> int:
	var count: int = 0
	for meshes: Array in g.horde_renderer._friendly_batches.values():
		for mesh: MultiMesh in meshes:
			count += mesh.visible_instance_count
	return count

func add_combat_fixture() -> void:
	for kind: int in 4:
		g.spawn_enemy(Vector3(-4 + kind * 2, 0, -2), kind == 1, kind == 2, kind == 3)
	# Make one ordinary real corpse before taking the immutable state snapshot.
	g.spawn_enemy(Vector3(0, 0, 2))
	g.hit(g.enemies.back(), 100.0, true)
	g.launch_shell(Vector3(-2, 2, 0), Vector3(4, 0, 0), 55.0, 3.0, "mortar")
	g.pulse(Vector3.ZERO, Color.RED, 3.0, 2.0)
	g.battle_fx.blast(Vector3.ZERO, 3.0, true)
	g.render_actors()

func run() -> void:
	if DirAccess.dir_exists_absolute("user://settlement_v2"):
		push_error("Fresh isolated XDG_DATA_HOME required")
		quit(2)
		return
	var fade := Transition.new()
	root.add_child(fade)
	fade.setup()
	fade.set_process(false)
	var midpoint_calls: Array = [0]
	fade.midpoint.connect(func(): midpoint_calls[0] += 1)
	fade._process(0.25)
	check(fade.settled and is_equal_approx(fade.color.a, 1.0) and is_equal_approx(fade.elapsed, Transition.FADE_OUT), "a long frame still renders an opaque midpoint")
	fade._process(0.25)
	fade._process(0.25)
	fade.sample_at(0.0)
	check(fade.complete and not fade.visible and not fade.is_processing() and midpoint_calls[0] == 1, "fade finishes in bounded time and midpoint cannot replay")
	fade.free()
	var campaign: Node = root.get_node("Campaign")
	for mission_index: int in 3:
		campaign.current = mission_index
		campaign.launch = true
		campaign.resume = false
		campaign.muted = true
		campaign.run_seed = 20261005
		g = load("res://main.tscn").instantiate()
		root.add_child(g)
		current_scene = g
		g.set_process(false)
		add_combat_fixture()
		var before: Dictionary = gameplay_snapshot()
		var before_corpses: Array = g.corpses.duplicate(true)
		var before_friends: int = friendly_instance_count()
		check(g.horde_renderer.visible_enemies > 0 and before_friends > 0 and not g.corpses.is_empty(), "mission %d fixture includes infected, corpses and batched friends" % mission_index)
		g.finish(true)
		g.aftermath_transition.set_process(false)
		check(not g.aftermath_settled and not g.aftermath_scene.visible and not g.aftermath_scene.is_processing() and g.aftermath_scene.elapsed == 0.0, "mission %d civilians wait behind transition without consuming animation time" % mission_index)
		check(g.modal.visible and g.modal.panel.is_visible_in_tree() and g.aftermath_transition.mouse_filter == Control.MOUSE_FILTER_IGNORE and g.modal.get_child(0) == g.aftermath_transition, "mission %d result panel is above the noninteractive world fade" % mission_index)
		g.aftermath_transition.sample_at(Transition.FADE_OUT)
		check(g.aftermath_settled and g.aftermath_scene.is_visible_in_tree() and g.aftermath_scene.is_processing() and g.aftermath_scene.elapsed == 0.0, "mission %d civilians start at the covered midpoint" % mission_index)
		var combat_hidden: bool = not g.battle_fx.is_visible_in_tree()
		for collection: Array in [g.enemies, g.corpses, g.shells, g.effects]:
			for record: Dictionary in collection:
				combat_hidden = combat_hidden and not record.node.is_visible_in_tree()
		check(combat_hidden, "mission %d enemy roots, corpses, shell, markers and battle effects are hidden" % mission_index)
		for frame: int in 3:
			g.render_actors()
		check(g.horde_renderer.visible_enemies == 0 and g.horde_renderer.baked.visible_count == 0, "mission %d later render frames never repopulate infected batches" % mission_index)
		var friends_visible: bool = g.horde_renderer.is_visible_in_tree() and friendly_instance_count() == before_friends
		for collection: Array in [g.units, g.buildings, g.sites]:
			for record: Dictionary in collection:
				friends_visible = friends_visible and record.node.is_visible_in_tree()
		check(friends_visible, "mission %d original friendly batches, vehicles, buildings and sites remain visible" % mission_index)
		g.aftermath_transition.sample_at(Transition.DURATION)
		g.aftermath_scene.sample_at(g.aftermath_scene.DURATION)
		check(g.aftermath_transition.complete and not g.aftermath_transition.visible and g.aftermath_scene.complete, "mission %d fade and existing civilian animation both complete" % mission_index)
		check(gameplay_snapshot() == before and g.corpses == before_corpses, "mission %d transition preserves all gameplay data, RNG, kills, XP, shell trajectory and corpse records" % mission_index)
		var same_aftermath: Node = g.aftermath_scene
		g.finish(true)
		g.settle_aftermath_presentation()
		check(g.aftermath_scene == same_aftermath and gameplay_snapshot() == before, "mission %d repeated completion and midpoint are idempotent" % mission_index)
		g.free()
		await process_frame
	campaign.current = 0
	g = load("res://main.tscn").instantiate()
	root.add_child(g)
	current_scene = g
	g.set_process(false)
	add_combat_fixture()
	g.finish(false)
	check(not g.aftermath_settled and not is_instance_valid(g.aftermath_transition) and not is_instance_valid(g.aftermath_scene) and g.modal is PanelContainer and g.enemies[0].node.visible and g.shells[0].node.visible and g.battle_fx.visible, "loss retains its original result panel and combat presentation")
	g.free()
	await process_frame
	print("AFTERMATH_TRANSITION_SUMMARY passed=%d failed=%d" % [passed, failed])
	quit(1 if failed else 0)
