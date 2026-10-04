extends Node3D
## Render-only horde batching. Enemy Node3D roots continue to own simulation state.
## Usage: add this node under the game, setup(), then update_horde(enemies, elapsed)
## after enemy simulation. Do not also call ActorVisuals.add_enemy on those roots.
## Eighteen geometry batches replace six MeshInstance3D nodes per live enemy.

const BakedInfected = preload("res://baked_infected_renderer.gd")
var baked:Node3D
var low_detail:bool=false
const ActorVisuals = preload("res://actor_visuals.gd")
const KINDS: Array[String] = ["infected", "runner", "armored"]
const PARTS: Array[String] = ["torso", "head", "legL", "legR", "armL", "armR"]
const MAX_CAPACITY: int = 1024
const MIN_CAPACITY: int = 8
const INSTANCE_STRIDE: int = 16
const HIT_DURATION: float = 0.12
# Reactions use only a small body recoil. Keep the original StandardMaterial3D
# untouched: a custom flash shader changed resting palette on Compatibility.

class Bucket:
	extends RefCounted
	var kind: String
	var members: Array[Dictionary] = []
	var batches: Array[MultiMesh] = []
	var buffers: Array[PackedFloat32Array] = []
	var capacity: int = 0

var _buckets: Array[Bucket] = []
var _initialized: bool = false
var _overflow_warned: bool = false
var visible_enemies: int = 0
var overflow_enemies: int = 0

func _ready() -> void:
	setup()

func setup() -> void:
	if _initialized:
		return
	_initialized = true
	baked=BakedInfected.new()
	add_child(baked)
	for kind: String in KINDS:
		var bucket := Bucket.new()
		bucket.kind = kind
		for part: String in PARTS:
			var mesh := MultiMesh.new()
			mesh.transform_format = MultiMesh.TRANSFORM_3D
			mesh.use_colors = true
			mesh.use_custom_data = false
			mesh.mesh = ActorVisuals.mesh_for(kind, part)
			var batch := MultiMeshInstance3D.new()
			batch.name = "Horde_" + kind + "_" + part
			batch.multimesh = mesh
			# One body shadow per enemy retains grounding without six shadow draws.
			batch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if part == "torso" else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(batch)
			bucket.batches.append(mesh)
			bucket.buffers.append(PackedFloat32Array())
		_grow(bucket, MIN_CAPACITY)
		_buckets.append(bucket)

func update_horde(enemies: Array, elapsed: float) -> void:
	if not _initialized:
		setup()
	if is_instance_valid(baked):
		baked.force_far=low_detail
		baked.update_crowd(enemies,elapsed,get_viewport().get_camera_3d())
	visible_enemies = baked.visible_count if is_instance_valid(baked) else 0
	overflow_enemies = 0
	for bucket: Bucket in _buckets:
		bucket.members.clear()
	for enemy: Dictionary in enemies:
		if enemy.get("dead", false):
			continue
		var actor: Node3D = enemy.get("node")
		if not is_instance_valid(actor) or actor.is_queued_for_deletion():
			continue
		if not actor.position.is_finite():
			continue
		var kind_index: int = 2 if enemy.get("armored", false) else (1 if float(enemy.get("speed", 1.65)) > 2.0 else 0)
		if kind_index==0 and is_instance_valid(baked) and baked.active:continue
		var bucket: Bucket = _buckets[kind_index]
		if bucket.members.size() < MAX_CAPACITY:
			bucket.members.append(enemy)
		else:
			overflow_enemies += 1
	if overflow_enemies > 0 and not _overflow_warned:
		push_warning("Horde renderer exceeded 1,024 live enemies of one kind; simulation is unchanged but excess actors are not rendered.")
		_overflow_warned = true
	var inverse: Transform3D = global_transform.affine_inverse()
	var safe_time: float = elapsed if is_finite(elapsed) else 0.0
	for bucket: Bucket in _buckets:
		var count: int = bucket.members.size()
		visible_enemies += count
		_grow(bucket, count)
		if count == 0:
			for batch: MultiMesh in bucket.batches:
				batch.visible_instance_count = 0
			continue
		var runner: bool = bucket.kind == "runner"
		var armored: bool = bucket.kind == "armored"
		var hip: float = 0.65 if armored else 0.58
		var lean: float = -0.34 if runner else (-0.12 if armored else -0.22)
		var shoulder: float = 0.43 if armored else 0.4
		var arm_width: float = 0.39 if armored else (0.25 if runner else 0.32)
		var leg_width: float = 0.19 if armored else 0.15
		var gait_amplitude: float = 0.57 if runner else 0.37
		var arm_amplitude: float = 0.48 if runner else 0.09
		var low := Vector3(INF, INF, INF)
		var high := Vector3(-INF, -INF, -INF)
		for index: int in count:
			var enemy: Dictionary = bucket.members[index]
			var actor: Node3D = enemy["node"]
			var world: Transform3D = inverse * actor.global_transform
			var seed_value:int=actor.get_instance_id()%97
			var stature:float=.90+float(seed_value%7)*.028
			world.basis=world.basis.scaled(Vector3(stature,stature,stature))
			var phase: float = safe_time * ((11.0 if runner else 7.0)+float(seed_value%5)*.14) + float(seed_value%17)
			var moving: bool = bool(enemy.get("moving", true))
			var gait: float = sin(phase) if moving else 0.0
			var bob: float = absf(cos(phase)) * 0.025 if moving else 0.0
			# Reactions are cosmetic only: neither actor transform nor combat state changes.
			var hit_until: float = float(enemy.get("hit_until", 0.0))
			var response: float = clampf((hit_until - safe_time) / HIT_DURATION, 0.0, 1.0) if is_finite(hit_until) else 0.0
			var recoil: float = 0.0
			var recoil_pitch: float = 0.0
			if response > 0.0:
				var hit_kind: String = str(enemy.get("hit_kind", "normal"))
				var critical: bool = hit_kind == "critical"
				var armored_hit: bool = hit_kind == "armored"
				var reduced: bool = bool(enemy.get("hit_reduced", false))
				var motion_scale: float = 0.3 if reduced else 1.0
				recoil = (0.10 if critical else (0.035 if armored_hit else 0.065)) * response * motion_scale
				recoil_pitch = (0.18 if critical else (0.065 if armored_hit else 0.11)) * response * motion_scale
			var strike := clampf(1.0-(safe_time-float(enemy.get("attack_at",-100.0)))/.32,0,1)
			var raised := clampf((1.4-float(enemy.get("windup",0.0)))/1.4,0,1) if float(enemy.get("windup",0.0))>0 else 0.0
			var body := world * Transform3D(Basis.from_euler(Vector3(lean + recoil_pitch - strike*.20, 0, gait * 0.028)), Vector3(0, hip + bob, recoil))
			var leg_l := world * Transform3D(Basis(Vector3.RIGHT, gait * gait_amplitude), Vector3(-leg_width, hip, 0))
			var leg_r := world * Transform3D(Basis(Vector3.RIGHT, -gait * gait_amplitude), Vector3(leg_width, hip, 0))
			var arm_l := body * Transform3D(Basis(Vector3.RIGHT, -gait * arm_amplitude-strike*.9-raised*1.25), Vector3(-arm_width, shoulder, 0))
			var arm_r := body * Transform3D(Basis(Vector3.RIGHT, gait * arm_amplitude-strike*.9-raised*1.25), Vector3(arm_width, shoulder, 0))
			var offset: int = index * INSTANCE_STRIDE
			_write_transform(bucket.buffers[0], offset, body)
			_write_transform(bucket.buffers[1], offset, body)
			_write_transform(bucket.buffers[2], offset, leg_l)
			_write_transform(bucket.buffers[3], offset, leg_r)
			_write_transform(bucket.buffers[4], offset, arm_l)
			_write_transform(bucket.buffers[5], offset, arm_r)
			var tones=[Color(1,.95,.90),Color(.91,.97,1),Color(.93,1,.91),Color(.94,.94,.92)]
			var tone:Color=tones[seed_value%4]
			for buffer in bucket.buffers:
				buffer[offset+12]=tone.r
				buffer[offset+13]=tone.g
				buffer[offset+14]=tone.b
				buffer[offset+15]=1.0
			# Conservative group bounds cover every animated part, also under scaling.
			var axes: Vector3 = world.basis.get_scale().abs()
			var extent := Vector3.ONE * maxf(axes.x, maxf(axes.y, axes.z)) * 2.1
			low = low.min(world.origin - extent)
			high = high.max(world.origin + extent)
		var bounds := AABB(low, high - low)
		for part_index: int in PARTS.size():
			var batch: MultiMesh = bucket.batches[part_index]
			batch.buffer = bucket.buffers[part_index]
			batch.custom_aabb = bounds
			batch.visible_instance_count = count

func _grow(bucket: Bucket, needed: int) -> void:
	if needed <= bucket.capacity:
		return
	var capacity: int = maxi(MIN_CAPACITY, bucket.capacity)
	while capacity < needed and capacity < MAX_CAPACITY:
		capacity *= 2
	bucket.capacity = mini(capacity, MAX_CAPACITY)
	for i: int in PARTS.size():
		bucket.batches[i].instance_count = bucket.capacity
		bucket.batches[i].visible_instance_count = 0
		bucket.buffers[i].resize(bucket.capacity * INSTANCE_STRIDE)

static func _write_transform(buffer: PackedFloat32Array, offset: int, value: Transform3D) -> void:
	# Godot's 3D MultiMesh buffer packs row-major 3x4 matrices, not Basis columns.
	buffer[offset] = value.basis.x.x
	buffer[offset + 1] = value.basis.y.x
	buffer[offset + 2] = value.basis.z.x
	buffer[offset + 3] = value.origin.x
	buffer[offset + 4] = value.basis.x.y
	buffer[offset + 5] = value.basis.y.y
	buffer[offset + 6] = value.basis.z.y
	buffer[offset + 7] = value.origin.y
	buffer[offset + 8] = value.basis.x.z
	buffer[offset + 9] = value.basis.y.z
	buffer[offset + 10] = value.basis.z.z
	buffer[offset + 11] = value.origin.z


# The friendly skeletons	still drive their original animation transforms; only
# their meshes are collected here, so selection, orders and appearance remain intact.
var _friendly_batches:Dictionary={}
func update_friends(units:Array)->void:
	if _friendly_batches.is_empty():
		for kind in ["guard","worker","grenade"]:
			var meshes=[]
			for part in PARTS:
				var mm=MultiMesh.new()
				mm.transform_format=MultiMesh.TRANSFORM_3D
				mm.mesh=ActorVisuals.mesh_for(kind,part)
				mm.instance_count=64
				mm.visible_instance_count=0
				mm.custom_aabb=AABB(Vector3(-64,-20,-64),Vector3(128,80,128))
				var visual=MultiMeshInstance3D.new()
				visual.name="Survivors_"+kind+"_"+part
				visual.multimesh=mm
				visual.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_ON if part=="torso" else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				add_child(visual)
				meshes.append(mm)
			_friendly_batches[kind]=meshes
	var counts={"guard":0,"worker":0,"grenade":0}
	var inverse=global_transform.affine_inverse()
	for u in units:
		if not counts.has(u.kind) or not is_instance_valid(u.node) or u.hp<=0:continue
		var skeleton=u.node.get_meta(&"actor_visuals",null)
		if not is_instance_valid(skeleton):continue
		var index:int=counts[u.kind]
		if index>=64:continue
		var body:Node3D=skeleton.get_meta(&"body")
		var parts=[body,body,skeleton.get_meta(&"leg_l"),skeleton.get_meta(&"leg_r"),skeleton.get_meta(&"arm_l"),skeleton.get_meta(&"arm_r")]
		for i in 6:_friendly_batches[u.kind][i].set_instance_transform(index,inverse*parts[i].global_transform)
		counts[u.kind]+=1
	for kind in counts:
		for mm in _friendly_batches[kind]:mm.visible_instance_count=counts[kind]
