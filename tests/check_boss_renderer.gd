extends SceneTree
## Run after copying the candidate and applying horde_integration.patch.
const Library = preload("res://boss_pose_library.gd")
const Renderer = preload("res://baked_boss_renderer.gd")
const SharedMotion = preload("res://baked_infected_renderer.gd")
const CorpseMotion = preload("res://corpse_motion.gd")
const Horde = preload("res://horde_renderer.gd")
var failures: Array[String] = []
var checks: int = 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	check(Library.configure(), "both boss LODs satisfy the shared-pairing contract")
	if Library.near_poses.is_empty() or Library.far_poses.is_empty():
		finish()
		return
	check(Library.near_poses.size() == 44 and Library.far_poses.size() == 44, "44 shared pairs per LOD")
	check(Library.sample("windup", 1.4) == Vector3(11, 11, 0), "windup holds contact without wrapping")
	check(Library.sample("recovery", .9) == Vector3(7, 7, 0), "recovery holds its last frame")
	check(Library.sample("death", 100) == Vector3(9, 9, 0), "death remains side-prone")
	check(Library.sample("walk", 1) == Library.sample("walk", 0), "walk loops")
	var selected: Dictionary = Renderer.select_pose({"windup": 1.4}, 10, true, .4, .3, 3.5)
	check(selected.clip == "windup" and selected.pose == Vector3(0, 1, 0), "windup begins from actual remaining duration")
	selected = Renderer.select_pose({"windup": .7}, 10, false, 0, .3, 3.5)
	check(selected.clip == "windup" and is_equal_approx(selected.pose.x + selected.pose.z, 5.5), "windup midpoint uses remaining duration")
	selected = Renderer.select_pose({"windup": 0.0, "attack_at": 10.0}, 9.975, true, .4, .3, 3.5)
	check(selected.clip == "recovery" and selected.pose == Vector3(0, 1, 0), "interpolation lag holds the actual contact pose")
	selected = Renderer.select_pose({"windup": 0.0, "attack_at": 10.0}, 10.45, true, .4, .3, 3.5)
	check(selected.clip == "recovery" and is_equal_approx(selected.pose.x + selected.pose.z, 3.5), "recovery uses actual impact age")
	selected = Renderer.select_pose({"windup": 0.0, "attack_at": 10.0}, 11.0, false, .4, .3, 3.5)
	check(selected.clip == "idle", "expired recovery returns to idle")
	selected = Renderer.select_pose({"life": 2.0, "windup": 1.4, "attack_at": 10.0}, 10.1, true, .4, .3, 2.0)
	check(selected.clip == "death" and selected.pose == Vector3(9, 9, 0), "death wins over residual attack fields and settles")
	var stride: float = Library.WALK_STRIDE_METERS * 2.2
	check(is_equal_approx(stride, 1.188), "authored stride respects existing 2.2 scale exactly once")
	var gait: Dictionary = SharedMotion.advance_gait({}, Vector3.ZERO, 0, stride, 1.45, 0)
	for step: int in range(1, 13):
		gait = SharedMotion.advance_gait(gait, Vector3(0, 0, -stride * step / 12.0), step * .1, stride, 1.45, 0)
	check(gait.moving and minf(gait.cycle, 1.0 - gait.cycle) < .00001, "one authored stride produces one cycle independent of elapsed duration")
	var held: Dictionary = SharedMotion.advance_gait(gait, gait.position, gait.time, stride, 1.45, 0)
	check(held.cycle == gait.cycle and held.moving == gait.moving, "paused render retains gait pose")
	var harness := Node3D.new()
	root.add_child(harness)
	var actor := Node3D.new()
	harness.add_child(actor)
	actor.scale = Vector3.ONE * 2.2
	var renderer := Renderer.new()
	harness.add_child(renderer)
	check(renderer.active and renderer.get_child_count() == 0, "no per-pose empty MultiMesh nodes at startup")
	var record: Dictionary = {"node": actor, "boss": true, "armored": true, "speed": 1.45, "windup": 0.0, "dead": false}
	var before: Dictionary = record.duplicate(true)
	var start: Transform3D = actor.transform
	renderer.update_crowd([record, record], 0, null)
	check(renderer.render_nodes.size() == 1 and renderer.get_child_count() == 1 and renderer.visible_count == 1, "one boss allocates exactly one node even with a duplicated record")
	var mm: MultiMesh = renderer.render_nodes[actor.get_instance_id()].multimesh
	check(mm.instance_count == 1 and mm.use_custom_data, "single instance supports shader interpolation")
	check(mm.get_instance_transform(0).basis.get_scale().is_equal_approx(Vector3.ONE * 2.2), "root scale has no second multiplier or stature variation")
	check(mm.custom_aabb.is_equal_approx((start * (mm.mesh as ArrayMesh).custom_aabb).grow(.05)), "boss culling bounds use the merged pair bounds")
	check(record == before and actor.transform == start, "rendering leaves authoritative record/root untouched")
	renderer.force_far = true
	renderer.update_crowd([record], .1, null)
	check(renderer.far_count == 1 and renderer.near_count == 0, "low-detail override forces far mesh")
	actor.position.z = -.1
	renderer.update_crowd([record], .2, null)
	check(not renderer.gait_states.is_empty(), "living boss tracks distance before culling")
	renderer.update_crowd([], .3, null)
	check(renderer.render_nodes.is_empty() and renderer.gait_states.is_empty() and renderer.near_lods.is_empty() and renderer.get_child_count() == 0, "fog omission removes geometry, shadows and cached motion immediately")
	var corpse: Dictionary = {"node": actor, "boss": true, "life": 2.0, "start": start, "death_kind": &"ballistic", "death_direction": Vector3.RIGHT, "dead": false}
	actor.transform = start * Transform3D(Basis(Vector3.RIGHT, 1.2), Vector3.ZERO)
	var expected: Transform3D = CorpseMotion.apply_world(start, CorpseMotion.sample(&"ballistic", Vector3.RIGHT, 1.5))
	renderer.update_crowd([corpse], 2, null)
	mm = renderer.render_nodes[actor.get_instance_id()].multimesh
	check(mm.get_instance_transform(0).is_equal_approx(expected), "corpse ignores legacy procedural root topple")
	check(renderer.gait_states.is_empty(), "corpse releases living gait state")
	var interpolated := Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * 1.1), Vector3(2, .1, 3))
	renderer.update_crowd([corpse], 2.1, null, {actor.get_instance_id(): {"life": .5, "baked_world": interpolated}})
	check(mm.get_instance_transform(0).is_equal_approx(interpolated), "interpolated baked world and existing shrink are applied once")
	renderer.active = false
	renderer.update_crowd([record], 2.2, null)
	check(renderer.render_nodes.is_empty() and renderer.visible_count == 0, "disabled/invalid renderer releases all opaque geometry")
	var horde := Horde.new()
	harness.add_child(horde)
	check(is_instance_valid(horde.baked_boss), "horde integration has boss renderer")
	horde.baked_boss.active = false
	horde.update_horde([record], 3)
	check(horde.visible_enemies == 1 and horde._buckets[2].members.size() == 1, "disabled boss assets route exactly once to legacy armored rendering")
	var sparse_flags: Dictionary = record.duplicate()
	sparse_flags.armored = false
	horde.update_horde([sparse_flags], 3)
	check(horde.visible_enemies == 1 and horde._buckets[2].members.size() == 1, "boss flag alone selects legacy fallback without ordinary baked duplicates")
	horde.baked_boss.active = true
	horde.update_horde([record], 3.1)
	check(horde.visible_enemies == 1 and horde._buckets[2].members.is_empty(), "active boss art exclusively replaces legacy")
	horde.update_horde([], 3.2)
	check(horde.baked_boss.render_nodes.is_empty() and horde.visible_enemies == 0, "existing mission empty-list teardown removes boss art")
	harness.free()
	finish()

func check(ok: bool, description: String) -> void:
	checks += 1
	if not ok:
		failures.append(description)

func finish() -> void:
	print("BOSS_RENDERER_SUMMARY checks=%d failures=%d" % [checks, failures.size()])
	for failure: String in failures:
		push_error(failure)
	quit(0 if failures.is_empty() else 1)
