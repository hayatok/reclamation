extends Node3D
## Original ordinary armored infected, using shared GPU pose interpolation.
## Live and corpse classification both use retained armored/boss flags.
## Simulation roots, contact timing and CorpseMotion clocks stay untouched.
const CorpseMotion = preload("res://corpse_motion.gd")
const Library = preload("res://armored_pose_library.gd")
const SharedMotion = preload("res://baked_infected_renderer.gd")
const INSTANCE_STRIDE: int = 20 # row-major 3x4 transform + RGBA tint + RGBA custom
var batches: Dictionary = {}
var buffers: Dictionary = {}
var capacities: Dictionary = {}
var members: Dictionary = {}
# Cosmetic only: position, sample time, cycle and moving flag, keyed by actor ID.
var gait_states: Dictionary = {}
var active: bool = false
var visible_count: int = 0
var near_count: int = 0
var far_count: int = 0
var near_lod: bool = false
var force_far: bool = false

func _ready() -> void:
	if not Library.configure():
		return
	for distant: bool in [false, true]:
		for clip: String in Library.COUNTS:
			for frame: int in Library.COUNTS[clip]:
				var key: String = "%s_%02d_%s" % [clip, frame, str(distant)]
				var mm := MultiMesh.new()
				mm.transform_format = MultiMesh.TRANSFORM_3D
				mm.use_colors = true
				mm.use_custom_data = true # Must be enabled before allocating instances.
				mm.mesh = Library.mesh_for(clip, frame, distant)
				if mm.mesh == null:
					push_error("Missing armored pose " + key)
					return
				var node := MultiMeshInstance3D.new()
				node.multimesh = mm
				node.name = "Armored_" + key
				# Keep the opaque body grounded at both LODs; do not buy performance by removing its shadow.
				node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
				add_child(node)
				batches[key] = mm
				buffers[key] = PackedFloat32Array()
				capacities[key] = 0
				members[key] = []
	active = true

func update_crowd(enemies: Array, elapsed: float, camera: Camera3D, rendered: Dictionary = {}) -> void:
	visible_count = 0
	near_count = 0
	far_count = 0
	for key: String in members:
		members[key].clear()
	if not active:
		# Failed setup or a review toggle must hand every actor back to legacy cleanly.
		for mm: MultiMesh in batches.values():
			mm.visible_instance_count = 0
		gait_states.clear()
		return
	var rect: Rect2 = get_viewport().get_visible_rect().grow(90)
	# Keep the existing screen-height LOD thresholds and culling margin.
	if camera != null:
		var projected_height: float = get_viewport().get_visible_rect().size.y * 1.7 / maxf(camera.size, 1)
		if projected_height > 39:
			near_lod = true
		elif projected_height < 32:
			near_lod = false
	var surviving: Dictionary = {}
	var inverse: Transform3D = global_transform.affine_inverse()
	var safe_time: float = elapsed if is_finite(elapsed) else 0.0
	for e: Dictionary in enemies:
		if e.get("dead", false) or not is_ordinary_armored(e):
			continue
		var actor: Node3D = e.get("node")
		if not is_instance_valid(actor) or actor.is_queued_for_deletion():
			continue
		var id: int = actor.get_instance_id()
		var state: Dictionary = rendered.get(id, {})
		var world: Transform3D = state.get("world", actor.global_transform)
		if not world.is_finite():
			continue
		var corpse: bool = e.has("life")
		var life: float = float(state.get("life", e.get("life", CorpseMotion.LIFETIME)))
		if corpse and (not is_finite(life) or life <= 0.0):
			continue
		var position: Vector3 = world.origin
		var stature: float = .94 + float(id % 7) * .02
		var phase: float = float(id % 127) / 127.0
		var moving: bool = false
		var cycle: float = phase
		if not corpse:
			# Track all eligible roots before culling, so offscreen travel is counted.
			# Root forward scale and stature also scale the authored 1.20 m stride.
			var stride: float = Library.WALK_STRIDE_METERS * stature * maxf(world.basis.z.length(), .001)
			var gait := SharedMotion.advance_gait(gait_states.get(id, {}), position, safe_time, stride, float(e.get("speed", 1.2)), phase)
			surviving[id] = gait
			moving = gait.moving
			cycle = gait.cycle
		if camera != null and (camera.is_position_behind(position) or not rect.has_point(camera.unproject_position(position + Vector3.UP * .8))):
			continue
		var clip: String = "walk" if moving else "idle"
		var age: float = 0.0 if moving else safe_time
		phase = cycle if moving else phase
		var attack_age: float = safe_time - float(e.get("attack_at", -100.0))
		if corpse:
			clip = "death"
			age = CorpseMotion.sample(e.get("death_kind", &"ballistic"), e.get("death_direction", Vector3.ZERO), CorpseMotion.LIFETIME - life).clip_age
			phase = 0.0
		elif attack_age >= 0.0 and attack_age < float(Library.DURATIONS.attack):
			# Authored attack_00 is contact. Preserve existing immediate damage timing.
			clip = "attack"
			age = attack_age
			phase = 0.0
		var pose: Vector3 = Library.sample(clip, age, phase)
		var far_lod: bool = force_far or not near_lod
		var key: String = "%s_%02d_%s" % [clip, int(pose.x), str(far_lod)]
		# The clip contains the topple. Preserve the existing corpse trajectory/fade.
		if corpse:
			if state.has("baked_world"):
				world = state.baked_world
			else:
				var motion: Dictionary = CorpseMotion.sample(e.get("death_kind", &"ballistic"), e.get("death_direction", Vector3.ZERO), CorpseMotion.LIFETIME - life)
				world = CorpseMotion.apply_world(actor.get_parent().global_transform * e.start, motion)
				if life < 1:
					world.basis = world.basis.scaled(Vector3.ONE * maxf(.03, life))
		if not world.is_finite():
			continue
		world.basis = world.basis.scaled(Vector3.ONE * stature)
		var hit_response: float = clampf((float(e.get("hit_until", 0)) - safe_time) / .12, 0, 1)
		world.origin += world.basis.z * hit_response * .07
		members[key].append([inverse * world, id, pose.z])
		visible_count += 1
		if far_lod:
			far_count += 1
		else:
			near_count += 1
	# Removed roots/corpses cannot accumulate stale gait state or render as ghosts.
	gait_states = surviving
	for key: String in batches:
		var mm: MultiMesh = batches[key]
		var count: int = members[key].size()
		if count == 0:
			mm.visible_instance_count = 0
			continue
		if count > capacities[key]:
			capacities[key] = maxi(8, int(pow(2, ceil(log(float(count)) / log(2.0)))))
			mm.instance_count = capacities[key]
			buffers[key].resize(capacities[key] * INSTANCE_STRIDE)
		var buffer: PackedFloat32Array = buffers[key]
		var low := Vector3(INF, INF, INF)
		var high := -low
		for i: int in count:
			var transform: Transform3D = members[key][i][0]
			var offset: int = i * INSTANCE_STRIDE
			_write(buffer, offset, transform)
			var tone: float = .91 + float(int(members[key][i][1]) % 5) * .0225
			buffer[offset + 12] = tone
			buffer[offset + 13] = tone
			buffer[offset + 14] = tone
			buffer[offset + 15] = 1.0
			buffer[offset + 16] = float(members[key][i][2])
			buffer[offset + 17] = 0.0
			buffer[offset + 18] = 0.0
			buffer[offset + 19] = 0.0
			var axes: Vector3 = transform.basis.get_scale().abs()
			var extent: Vector3 = Vector3.ONE * 2.5 * maxf(axes.x, maxf(axes.y, axes.z))
			low = low.min(transform.origin - extent)
			high = high.max(transform.origin + extent)
		buffers[key] = buffer
		mm.buffer = buffer
		mm.custom_aabb = AABB(low, high - low)
		mm.visible_instance_count = count

## This exact predicate also controls legacy fallback routing. Bosses keep their
## six-part model, including after death when main retains the boss flag.
static func is_ordinary_armored(record: Dictionary) -> bool:
	return bool(record.get("armored", false)) and not bool(record.get("boss", false))

## Optional hook for known short teleports which cannot be inferred from displacement.
func reset_motion(actor: Node3D = null) -> void:
	if actor == null:
		gait_states.clear()
	elif is_instance_valid(actor):
		gait_states.erase(actor.get_instance_id())

static func _write(buffer: PackedFloat32Array, o: int, t: Transform3D) -> void:
	buffer[o] = t.basis.x.x
	buffer[o + 1] = t.basis.y.x
	buffer[o + 2] = t.basis.z.x
	buffer[o + 3] = t.origin.x
	buffer[o + 4] = t.basis.x.y
	buffer[o + 5] = t.basis.y.y
	buffer[o + 6] = t.basis.z.y
	buffer[o + 7] = t.origin.y
	buffer[o + 8] = t.basis.x.z
	buffer[o + 9] = t.basis.y.z
	buffer[o + 10] = t.basis.z.z
	buffer[o + 11] = t.origin.z
