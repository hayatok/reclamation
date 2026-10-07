extends RefCounted
## Render-only snapshots. Actor roots always retain authoritative simulation state.
## New actors, lifecycle changes and teleports snap; old actors never persist as ghosts.

const ActorVisuals = preload("res://actor_visuals.gd")
const CorpseMotion=preload("res://corpse_motion.gd")
const MAX_STEP_DISTANCE: float = 1.0
const VISUAL_ROOT: StringName = &"interpolated_visual_root"
var _previous: Dictionary = {}
var _current: Dictionary = {}
var _units: Array = []
var _enemies: Array = []
var _corpses: Array = []

func visual_root(actor: Node3D) -> Node3D:
	var visual: Node3D = actor.get_meta(VISUAL_ROOT) if actor.has_meta(VISUAL_ROOT) else null
	if not is_instance_valid(visual):
		visual = Node3D.new()
		visual.name = "InterpolatedVisuals"
		actor.add_child(visual)
		actor.set_meta(VISUAL_ROOT, visual)
	return visual

func reset(units: Array, enemies: Array, corpses: Array) -> void:
	_track(units, enemies, corpses)
	_current = _capture()
	_previous = _current.duplicate()
	for state: Dictionary in _current.values():
		_apply_visual(state.node, state.world)

func before_step(units: Array, enemies: Array, corpses: Array) -> void:
	_track(units, enemies, corpses)
	_previous = _capture()

func after_step(units: Array, enemies: Array, corpses: Array) -> void:
	_track(units, enemies, corpses)
	_current = _capture()
	for id: int in _current:
		var state: Dictionary = _current[id]
		if not _previous.has(id) or _previous[id].stage != state.stage or _previous[id].world.origin.distance_to(state.world.origin) > MAX_STEP_DISTANCE:
			_previous[id] = state
	for id: int in _previous.keys():
		if not _current.has(id):
			_previous.erase(id)

## Call for a deliberately discontinuous relocation, even if shorter than one metre.
func snap_actor(actor: Node3D) -> void:
	if not is_instance_valid(actor):
		return
	var id: int = actor.get_instance_id()
	_current.erase(id)
	_previous.erase(id)
	_apply_visual(actor, actor.global_transform)

func frame(alpha: float) -> Dictionary:
	_sync_lifecycle()
	var weight: float = clampf(alpha, 0.0, 1.0) if is_finite(alpha) else 1.0
	var rendered: Dictionary = {}
	for id: int in _current:
		var current: Dictionary = _current[id]
		var previous: Dictionary = _previous.get(id, current)
		var state: Dictionary = {"world": previous.world.interpolate_with(current.world, weight)}
		if current.has("parts"):
			var parts: Array[Transform3D] = []
			for i: int in current.parts.size():
				parts.append(previous.get("parts", current.parts)[i].interpolate_with(current.parts[i], weight))
			state.parts = parts
		if current.has("life"):
			state.life = lerpf(previous.life, current.life, weight)
			state.baked_world = previous.baked_world.interpolate_with(current.baked_world, weight)
		rendered[id] = state
		_apply_visual(current.node, state.world)
	return rendered

func _track(units: Array, enemies: Array, corpses: Array) -> void:
	_units = units
	_enemies = enemies
	_corpses = corpses

func _valid(record: Dictionary) -> bool:
	var actor: Variant = record.get("node")
	return is_instance_valid(actor) and not actor.is_queued_for_deletion() and not record.get("dead", false) and float(record.get("hp", 1.0)) > 0.0 and actor.global_transform.is_finite()

func _capture() -> Dictionary:
	var result: Dictionary = {}
	for group: int in 3:
		for record: Dictionary in [_units, _enemies, _corpses][group]:
			if _valid(record):
				result[record.node.get_instance_id()] = _snapshot(record, group)
	return result

func _snapshot(record: Dictionary, stage: int) -> Dictionary:
	var actor: Node3D = record.node
	var world: Transform3D = actor.global_transform
	var state: Dictionary = {"node": actor, "stage": stage, "world": world}
	var skeleton: Node3D = actor.get_meta(&"actor_visuals") if actor.has_meta(&"actor_visuals") else null
	if stage == 0 and is_instance_valid(skeleton):
		var nodes: Array = ActorVisuals.part_nodes(skeleton)
		var inverse: Transform3D = world.affine_inverse()
		var parts: Array[Transform3D] = []
		for part: Node3D in nodes:
			parts.append(inverse * part.global_transform)
		state.parts = parts
	if stage == 2:
		state.life = float(record.life)
		# Baked death meshes already contain the topple, unlike procedural corpses.
		var parent_world: Transform3D = actor.get_parent().global_transform if actor.get_parent() is Node3D else Transform3D.IDENTITY
		var motion:Dictionary=CorpseMotion.sample(record.get("death_kind",&"ballistic"),record.get("death_direction",Vector3.ZERO),3.5-state.life)
		var baked_world: Transform3D = CorpseMotion.apply_world(parent_world * record.start,motion)
		if state.life < 1.0:
			baked_world.basis = baked_world.basis.scaled(Vector3.ONE * maxf(0.03, state.life))
		state.baked_world = baked_world
	return state

func _sync_lifecycle() -> void:
	var seen: Dictionary = {}
	for group: int in 3:
		for record: Dictionary in [_units, _enemies, _corpses][group]:
			if not _valid(record):
				continue
			var actor: Node3D = record.node
			var id: int = actor.get_instance_id()
			seen[id] = true
			# Out-of-step changes include load, developer teleport and newly spawned actors.
			if not _current.has(id) or _current[id].stage != group or not _current[id].world.is_equal_approx(actor.global_transform) or (group == 2 and not is_equal_approx(_current[id].life, float(record.life))):
				_current[id] = _snapshot(record, group)
				_previous[id] = _current[id]
	for id: int in _current.keys():
		if not seen.has(id):
			var actor: Variant = _current[id].node
			if is_instance_valid(actor):
				_apply_visual(actor, actor.global_transform)
			_current.erase(id)
			_previous.erase(id)

func _apply_visual(actor: Node3D, world: Transform3D) -> void:
	var visual: Node3D = actor.get_meta(VISUAL_ROOT) if actor.has_meta(VISUAL_ROOT) else null
	if is_instance_valid(visual):
		visual.transform = actor.global_transform.affine_inverse() * world
