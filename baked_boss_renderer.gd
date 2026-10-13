extends Node3D
## Presentation only. Feed the SAME fog-filtered living/corpse list as the horde.
## Each supplied boss owns one one-instance MultiMesh; pose pairs stay shared.
const CorpseMotion = preload("res://corpse_motion.gd")
const Library = preload("res://boss_pose_library.gd")
const SharedMotion = preload("res://baked_infected_renderer.gd")
const SimulationClock = preload("res://simulation_clock.gd")
var render_nodes: Dictionary = {}
var gait_states: Dictionary = {}
var near_lods: Dictionary = {}
var active: bool = false
var force_far: bool = false
var visible_count: int = 0
var near_count: int = 0
var far_count: int = 0

func _ready() -> void:
	active = Library.configure()

func update_crowd(enemies: Array, elapsed: float, camera: Camera3D, rendered: Dictionary = {}) -> void:
	visible_count = 0
	near_count = 0
	far_count = 0
	if not active:
		clear()
		return
	var surviving: Dictionary = {}
	var next_gaits: Dictionary = {}
	var safe_time: float = elapsed if is_finite(elapsed) else 0.0
	var inverse: Transform3D = global_transform.affine_inverse()
	var screen: Rect2 = get_viewport().get_visible_rect().grow(90.0)
	for record: Dictionary in enemies:
		if not is_boss(record) or record.get("dead", false):
			continue
		var actor: Node3D = record.get("node")
		if not is_instance_valid(actor) or actor.is_queued_for_deletion():
			continue
		var id: int = actor.get_instance_id()
		if surviving.has(id):
			continue
		var state: Dictionary = rendered.get(id, {})
		var corpse: bool = record.has("life")
		var life: float = float(state.get("life", record.get("life", CorpseMotion.LIFETIME)))
		if corpse and (not is_finite(life) or life <= 0.0):
			continue
		var world: Transform3D = state.get("world", actor.global_transform)
		if corpse:
			world = corpse_world(record, actor, state, life)
		if not world.is_finite():
			continue
		var phase: float = float(id % 127) / 127.0
		var moving: bool = false
		var cycle: float = phase
		if not corpse:
			# No stature jitter: the existing 2.2 root scale is the complete boss scale.
			# Account for travel before screen culling, but never retain fog-hidden IDs.
			var stride: float = Library.WALK_STRIDE_METERS * maxf(world.basis.z.length(), .001)
			var gait: Dictionary = SharedMotion.advance_gait(gait_states.get(id, {}), world.origin, safe_time, stride, float(record.get("speed", 1.45)), phase)
			next_gaits[id] = gait
			moving = gait.moving
			cycle = gait.cycle
		var selected: Dictionary = select_pose(record, safe_time, moving, cycle, phase, life)
		var pose: Vector3 = selected.pose
		var near_lod: bool = bool(near_lods.get(id, false))
		if camera != null and not camera.is_position_behind(world.origin):
			var height: Vector3 = Vector3.UP * Library.IDLE_HEIGHT_METERS * world.basis.y.length()
			var projected_height: float = camera.unproject_position(world.origin).distance_to(camera.unproject_position(world.origin + height))
			if projected_height > 39.0:
				near_lod = true
			elif projected_height < 32.0:
				near_lod = false
		near_lods[id] = near_lod
		var far_lod: bool = force_far or not near_lod
		var mesh: ArrayMesh = Library.mesh_for(selected.clip, int(pose.x), far_lod) as ArrayMesh
		if mesh == null:
			# A broken shared library must immediately hand ALL bosses back to legacy.
			active = false
			clear()
			return
		var visual: MultiMeshInstance3D = _node_for(id)
		var mm: MultiMesh = visual.multimesh
		surviving[id] = true
		mm.visible_instance_count = 0
		# Pair bounds include both interpolation endpoints, including side-prone death.
		var bounds: AABB = mesh.custom_aabb
		if camera != null and _offscreen(world * bounds, camera, screen):
			continue
		var local_world: Transform3D = inverse * world
		if mm.mesh != mesh:
			mm.mesh = mesh
		mm.set_instance_transform(0, local_world)
		mm.set_instance_custom_data(0, Color(pose.z, 0.0, 0.0, 0.0))
		mm.custom_aabb = (local_world * bounds).grow(.05)
		mm.visible_instance_count = 1
		visible_count += 1
		if far_lod:
			far_count += 1
		else:
			near_count += 1
	# This also removes hidden opaque geometry and shadow casters in the SAME frame.
	for id: int in render_nodes.keys():
		if not surviving.has(id):
			_remove_node(id)
	gait_states = next_gaits
	for id: int in near_lods.keys():
		if not surviving.has(id):
			near_lods.erase(id)

static func is_boss(record: Dictionary) -> bool:
	return bool(record.get("boss", false))

## Read authoritative attack clocks; never synthesize damage or another cooldown.
static func select_pose(record: Dictionary, elapsed: float, moving: bool, cycle: float, phase: float, life: float) -> Dictionary:
	var clip: String = "walk" if moving else "idle"
	var age: float = 0.0 if moving else elapsed
	phase = cycle if moving else phase
	var windup: float = float(record.get("windup", 0.0))
	var attack_age: float = elapsed - float(record.get("attack_at", -INF))
	if record.has("life"):
		clip = "death"
		age = CorpseMotion.sample(record.get("death_kind", &"ballistic"), record.get("death_direction", Vector3.ZERO), CorpseMotion.LIFETIME - life).clip_age
		phase = 0.0
	elif is_finite(windup) and windup > 0.0:
		clip = "windup"
		age = clampf(float(Library.DURATIONS.windup) - windup, 0.0, float(Library.DURATIONS.windup))
		phase = 0.0
	elif is_finite(attack_age) and attack_age >= -SimulationClock.STEP - SimulationClock.EPSILON and attack_age < float(Library.DURATIONS.recovery):
		# Render time can lag the just-committed impact by one simulation tick.
		# Hold contact_00 during that gap rather than flashing an idle/walk pose.
		clip = "recovery"
		age = maxf(0.0, attack_age)
		phase = 0.0
	return {"clip": clip, "pose": Library.sample(clip, age, phase)}

## Ignore actor.global_transform's legacy procedural topple for baked corpses.
static func corpse_world(record: Dictionary, actor: Node3D, state: Dictionary, life: float) -> Transform3D:
	if state.has("baked_world"):
		return state.baked_world
	var parent_world: Transform3D = actor.get_parent().global_transform if actor.get_parent() is Node3D else Transform3D.IDENTITY
	var start: Transform3D = record.get("start", actor.transform)
	var motion: Dictionary = CorpseMotion.sample(record.get("death_kind", &"ballistic"), record.get("death_direction", Vector3.ZERO), CorpseMotion.LIFETIME - life)
	var world: Transform3D = CorpseMotion.apply_world(parent_world * start, motion)
	if life < 1.0:
		world.basis = world.basis.scaled(Vector3.ONE * maxf(.03, life))
	return world

func _node_for(id: int) -> MultiMeshInstance3D:
	if render_nodes.has(id):
		return render_nodes[id]
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.use_custom_data = true
	mm.instance_count = 1
	mm.visible_instance_count = 0
	mm.set_instance_color(0, Color.WHITE)
	var visual := MultiMeshInstance3D.new()
	visual.name = "DemolitionBoss_" + str(id)
	visual.multimesh = mm
	visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	add_child(visual)
	render_nodes[id] = visual
	return visual

## A projected AABB covers protruding arms and horizontal corpses. Camera-plane
## straddlers are left to engine culling instead of rejecting their root point.
static func _offscreen(bounds: AABB, camera: Camera3D, screen: Rect2) -> bool:
	var low := Vector2(INF, INF)
	var high := -low
	var behind: int = 0
	for corner: int in 8:
		var point: Vector3 = bounds.get_endpoint(corner)
		if camera.is_position_behind(point):
			behind += 1
			continue
		var projected: Vector2 = camera.unproject_position(point)
		if not projected.is_finite():
			return false
		low = low.min(projected)
		high = high.max(projected)
	if behind == 8:
		return true
	if behind > 0:
		return false
	return not screen.intersects(Rect2(low, high - low), true)

func _remove_node(id: int) -> void:
	var visual: MultiMeshInstance3D = render_nodes.get(id)
	if is_instance_valid(visual):
		visual.multimesh.visible_instance_count = 0
		visual.free()
	render_nodes.erase(id)
	near_lods.erase(id)
	gait_states.erase(id)

## update_crowd([]) already calls this lifecycle cleanup; teardown is also explicit.
func clear() -> void:
	for id: int in render_nodes.keys():
		_remove_node(id)
	gait_states.clear()
	near_lods.clear()
	visible_count = 0
	near_count = 0
	far_count = 0

func reset_motion(actor: Node3D = null) -> void:
	if actor == null:
		gait_states.clear()
	elif is_instance_valid(actor):
		gait_states.erase(actor.get_instance_id())

func _exit_tree() -> void:
	clear()
