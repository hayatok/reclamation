extends SceneTree
## Run only after the reviewed source and art are integrated into a test project.
const ArmoredLibrary = preload("res://armored_pose_library.gd")
const ArmoredRenderer = preload("res://baked_armored_renderer.gd")
const NormalLibrary = preload("res://infected_pose_library.gd")
const RunnerLibrary = preload("res://runner_pose_library.gd")
const Horde = preload("res://horde_renderer.gd")
const CorpseMotion = preload("res://corpse_motion.gd")

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	assert(NormalLibrary.configure("res://assets/models/infected_baked_poses.glb", "res://assets/models/infected_baked_poses_far.glb"))
	assert(RunnerLibrary.configure())
	var normal_mesh: Mesh = NormalLibrary.mesh_for("walk", 0)
	var runner_mesh: Mesh = RunnerLibrary.mesh_for("run", 0)
	assert(ArmoredLibrary.configure())
	assert(normal_mesh == NormalLibrary.mesh_for("walk", 0) and runner_mesh == RunnerLibrary.mesh_for("run", 0), "Independent armored cache preserves both existing libraries")
	assert(ArmoredLibrary.near_poses.size() == 32 and ArmoredLibrary.far_poses.size() == 32)
	for distant: bool in [false, true]:
		var materials: Dictionary = {}
		for clip: String in ArmoredLibrary.COUNTS:
			for frame: int in ArmoredLibrary.COUNTS[clip]:
				var mesh: Mesh = ArmoredLibrary.mesh_for(clip, frame, distant)
				assert(mesh != null and mesh.get_surface_count() == 1)
				var arrays: Array = mesh.surface_get_arrays(0)
				var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
				var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
				var triangles: int = int((indices.size() if not indices.is_empty() else vertices.size()) / 3)
				assert(triangles > 0 and triangles <= (400 if distant else 1500), "Authored geometry stays within the per-body triangle budget")
				assert(NormalLibrary.corner_indices(arrays[Mesh.ARRAY_TEX_UV2], vertices.size()).size() == vertices.size())
				assert(arrays[Mesh.ARRAY_CUSTOM0].size() == vertices.size() * 3 and arrays[Mesh.ARRAY_CUSTOM1].size() == vertices.size() * 3)
				for vertex: Vector3 in vertices:
					assert(vertex.is_finite())
				var material := mesh.surface_get_material(0) as ShaderMaterial
				assert(material != null and material.get_shader_parameter("albedo_texture") != null)
				materials[material.get_instance_id()] = true
		assert(materials.size() == 1, "One shared atlas material per LOD, never per actor or pose")
		var idle_bounds: AABB = ArmoredLibrary.mesh_for("idle", 0, distant).get_aabb()
		assert(idle_bounds.size.y >= 1.50 and idle_bounds.size.y <= 1.67, "Ordinary armored height remains near the authored 1.60 metres")
	assert(ArmoredLibrary.sample("attack", 0.0) == Vector3(0, 1, 0), "Contact starts at the combat timestamp")
	assert(ArmoredLibrary.sample("attack", .9) == Vector3(7, 7, 0))
	assert(ArmoredLibrary.sample("death", 1.2) == Vector3(9, 9, 0))
	assert(ArmoredLibrary.sample("death", 30.0) == Vector3(9, 9, 0), "One-shot death never wraps")
	assert(ArmoredLibrary.next_frame("walk", 11) == 0 and ArmoredLibrary.next_frame("idle", 1) == 0)
	assert(is_equal_approx(ArmoredLibrary.WALK_STRIDE_METERS, 1.20))
	assert(ArmoredRenderer.is_ordinary_armored({"armored": true}))
	assert(not ArmoredRenderer.is_ordinary_armored({"armored": true, "boss": true}))
	assert(not ArmoredRenderer.is_ordinary_armored({"armored": false, "speed": 1.2}))

	var stage := Node3D.new()
	root.add_child(stage)
	stage.transform = Transform3D(Basis(Vector3.UP, .35), Vector3(7, 0, -4))
	var horde := Horde.new()
	stage.add_child(horde)
	var enemies: Array = []
	for i: int in 6:
		var actor := Node3D.new()
		stage.add_child(actor)
		actor.position = Vector3(i * 2, 0, 0)
		var entry: Dictionary = {"node": actor, "speed": 1.65 if i == 0 else 2.7 if i == 1 else 1.2, "armored": i >= 2, "boss": i in [3, 5], "moving": false, "hp": 100.0, "attack_at": -100.0}
		if i in [4, 5]:
			entry.merge({"life": 3.25, "start": actor.transform, "scale": Vector3.ONE, "death_kind": &"ballistic", "death_direction": Vector3.RIGHT})
		enemies.append(entry)
	await process_frame
	assert(horde.baked.active and horde.baked_runner.active and horde.baked_armored.active)
	var before: Array = enemies.duplicate(true)
	var roots: Array[Transform3D] = []
	for entry: Dictionary in enemies:
		roots.append(entry.node.transform)
	horde.update_horde(enemies, 1.0)
	assert(horde.visible_enemies == 6 and horde.overflow_enemies == 0)
	assert(horde.baked.visible_count == 1 and horde.baked_runner.visible_count == 1 and horde.baked_armored.visible_count == 2)
	assert(horde._buckets[2].members.size() == 2, "Only live and dead bosses remain in the legacy armored bucket")
	for entry: Dictionary in horde._buckets[2].members:
		assert(entry.boss)
	assert(enemies == before, "Rendering cannot mutate combat or corpse dictionaries")
	for i: int in enemies.size():
		assert(enemies[i].node.transform == roots[i], "Rendering cannot mutate simulation roots")
	assert(horde.baked_armored.gait_states.size() == 1, "Only ordinary live armored roots enter the gait cache")
	for child: MultiMeshInstance3D in horde.baked_armored.get_children():
		assert(child.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_ON, "Near and far bodies both retain their ground shadow")

	var walker: Node3D = enemies[2].node
	var id: int = walker.get_instance_id()
	var old_phase: float = horde.baked_armored.gait_states[id].cycle
	walker.position.z -= .12
	horde.update_horde(enemies, 1.1)
	var gait: Dictionary = horde.baked_armored.gait_states[id]
	var stature: float = .94 + float(id % 7) * .02
	assert(gait.moving and is_equal_approx(fposmod(gait.cycle - old_phase, 1.0), .1 / stature), "Gait follows 1.2 m/s displacement, including stature")
	var cycle: float = gait.cycle
	horde.update_horde(enemies, 1.1)
	assert(horde.baked_armored.gait_states[id].cycle == cycle, "Paused renders cannot drift gait")
	enemies[2].attack_at = 1.15
	horde.update_horde(enemies, 1.1)
	assert(not member_for(horde.baked_armored, id).key.begins_with("attack_"), "A future contact timestamp cannot play the attack early")
	horde.update_horde(enemies, 1.15)
	assert(member_for(horde.baked_armored, id).key.begins_with("attack_00_"))
	horde.update_horde(enemies, 2.06)
	assert(not member_for(horde.baked_armored, id).key.begins_with("attack_"), "Attack returns to locomotion after the authored recovery")
	horde.baked_armored.near_lod = true
	horde.low_detail = false
	horde.update_horde(enemies, 2.1)
	assert(horde.baked_armored.near_count == 2)
	horde.low_detail = true
	horde.update_horde(enemies, 2.1)
	assert(horde.baked_armored.far_count == 2 and horde.baked_armored.near_count == 0)

	var corpse: Dictionary = enemies[4]
	var corpse_id: int = corpse.node.get_instance_id()
	corpse.node.rotation.x = 1.2
	for cause: StringName in [CorpseMotion.BALLISTIC, CorpseMotion.EXPLOSIVE, CorpseMotion.ELECTRIC]:
		corpse.death_kind = cause
		horde.update_horde(enemies, 2.2)
		var motion: Dictionary = CorpseMotion.sample(cause, corpse.death_direction, CorpseMotion.LIFETIME - corpse.life)
		var expected: Transform3D = CorpseMotion.apply_world(stage.global_transform * corpse.start, motion)
		expected.basis = expected.basis.scaled(Vector3.ONE * (.94 + float(corpse_id % 7) * .02))
		assert(member_for(horde.baked_armored, corpse_id).transform.is_equal_approx(horde.global_transform.affine_inverse() * expected), "Corpse uses saved start and one CorpseMotion accent, never the procedural topple")
	corpse.life = .5
	horde.update_horde(enemies, 2.3)
	var faded: Transform3D = member_for(horde.baked_armored, corpse_id).transform
	assert(faded.basis.get_scale().is_equal_approx(Vector3.ONE * .5 * (.94 + float(corpse_id % 7) * .02)), "Existing last-second corpse shrink is preserved")
	var rendered: Dictionary = {}
	var baked_world := Transform3D(Basis(Vector3.UP, .7).scaled(Vector3.ONE * .7), Vector3(10, 0, 5))
	rendered[corpse_id] = {"world": corpse.node.global_transform, "life": 3.4, "baked_world": baked_world}
	horde.update_horde(enemies, 2.3, rendered)
	baked_world.basis = baked_world.basis.scaled(Vector3.ONE * (.94 + float(corpse_id % 7) * .02))
	assert(member_for(horde.baked_armored, corpse_id).transform.is_equal_approx(horde.global_transform.affine_inverse() * baked_world), "Interpolated baked_world is honored without another fade or topple")
	corpse.life = 0.0
	horde.update_horde(enemies, 2.4)
	assert(horde.baked_armored.visible_count == 1 and member_for(horde.baked_armored, corpse_id).is_empty(), "Expired corpses cannot render or fall through to legacy")
	assert(horde.visible_enemies == 5)
	corpse.life = 3.25

	horde.baked_armored.active = false
	horde.update_horde(enemies, 2.5)
	assert(horde.visible_enemies == 6 and horde._buckets[2].members.size() == 4, "Unavailable armored art falls back for every live and dead armored actor")
	assert(horde.baked_armored.visible_count == 0 and horde.baked_armored.gait_states.is_empty())
	for mm: MultiMesh in horde.baked_armored.batches.values():
		assert(mm.visible_instance_count == 0, "Deactivation must clear prior baked draws")
	horde.baked_armored.active = true
	horde.update_horde(enemies, 2.6)
	enemies[2].dead = true
	enemies[4].node.queue_free()
	horde.update_horde(enemies, 2.7)
	assert(horde.baked_armored.visible_count == 0 and horde.baked_armored.gait_states.is_empty(), "Dead and queued roots leave both renderer and gait cache")
	horde.update_horde([], 2.8)
	assert(horde.visible_enemies == 0 and horde.baked_armored.gait_states.is_empty())
	for mm: MultiMesh in horde.baked_armored.batches.values():
		assert(mm.visible_instance_count == 0)
	assert(ArmoredLibrary.near_poses.size() == 32 and ArmoredLibrary.far_poses.size() == 32, "Shared pose cache stays fixed through all lifecycle changes")
	print("ARMORED_ART_CONTRACT_PASS: 64 shared poses; geometry/UV2/material bounds; ordinary/boss routing; fallback/counts; displacement/contact; both shadows; corpse causes/interpolation/fade/expiry; bounded gait cache; no gameplay mutation")
	quit()

func member_for(renderer: Node3D, id: int) -> Dictionary:
	for key: String in renderer.members:
		for member: Array in renderer.members[key]:
			if int(member[1]) == id:
				return {"key": key, "transform": member[0], "weight": member[2]}
	return {}
