extends RefCounted
## Authored M2 controller. The host owns combat, normal enemies, navigation, RNG,
## persistence of those enemies, and final result ordering. Never calls finish().
const NestVisual = preload("frontier_nest_visual.gd")
const SNAPSHOT_VERSION: int = 1
const NEST_ID: String = "frontier_nest"
const NEST_POSITION: Vector3 = Vector3(62, 0, -48)
const NEST_HP: float = 6000.0
const NEST_RADIUS: float = 4.5
const NEST_HALF_EXTENTS: Vector2 = Vector2(4.5, 4.5)
const CAMP_CENTERS: Array[Vector3] = [Vector3(-42, 0, -18), Vector3(34, 0, 20)]
const CAMP_NORMALS: int = 12
const CAMP_FAST: int = 4
const WAKE_DISTANCE: float = 16.0
const FIRST_RAID_SECONDS: float = 180.0
const RAID_INTERVAL_SECONDS: float = 70.0
const RAID_INITIAL_SIZE: int = 12
const RAID_GROWTH: int = 4
const RAID_MAX_SIZE: int = 36
const ALARM_SECONDS: float = 3.0
const EMERGENCE_SECONDS: float = 6.0
const EMERGENCE_COUNT: int = 60
const MOBILE_CAP: int = 180
const MAX_RAID_INDEX: int = 1000000
const MAX_STEP_SECONDS: float = 1.0
const DOOR_DISTANCE: float = 6.2

var nest: Dictionary = {}
var raid_clock: float = FIRST_RAID_SECONDS
var raid_index: int = 0
var camp_awake: Array[bool] = [false, false]
var alarm_triggered: bool = false
var alarm_remaining: float = 0.0
var emergence_clock: float = 0.0
## Consumed emergence slots, including slots skipped because MOBILE_CAP was full.
## No delayed backlog appears after the six-second emergence window.
var emergence_index: int = 0
var reward_claimed: bool = false
var _cues: Array[Dictionary] = []

## Fresh mission only. Host must first clear the previous run's enemy array.
## Restore uses spawn_camps=false and separately restores ordinary enemy records.
func reset(host: Node3D, spawn_camps: bool = true) -> void:
	dispose()
	raid_clock = FIRST_RAID_SECONDS
	raid_index = 0
	camp_awake = [false, false]
	alarm_triggered = false
	alarm_remaining = 0.0
	emergence_clock = 0.0
	emergence_index = 0
	reward_claimed = false
	_cues.clear()
	var node: Node3D = NestVisual.create()
	host.add_child(node)
	node.position = NEST_POSITION
	node.visible = false
	nest = {"node": node, "hp": NEST_HP, "maxhp": NEST_HP,
		"dead": false, "radius": NEST_RADIUS, "known": false,
		"enemy_structure": true, "structure_id": NEST_ID,
		"kind": "infected_nest", "nav_half_extents": NEST_HALF_EXTENTS}
	if spawn_camps:
		for group in CAMP_CENTERS.size():
			for index in CAMP_NORMALS + CAMP_FAST:
				var offset := Vector3((index % 4 - 1.5) * 1.6, 0, (floori(index / 4.0) - 1.5) * 1.6)
				var enemy: Dictionary = _spawn(host, CAMP_CENTERS[group] + offset, index >= CAMP_NORMALS)
				if enemy.is_empty(): continue
				enemy["frontier_group"] = group
				enemy["frontier_awake"] = false
				enemy["moving"] = false

## Removes only this controller's visual. It never frees mobile enemy nodes.
func dispose() -> void:
	if is_instance_valid(nest.get("node")):
		if nest.node.get_parent() != null: nest.node.get_parent().remove_child(nest.node)
		nest.node.queue_free()
	nest.clear()
	_cues.clear()

## Discovery accepts only current sight, never explored terrain or camera view.
## Returns true once, allowing the host to issue its ordinary objective notice.
func discover_if_visible(is_visible: Callable) -> bool:
	if nest.is_empty() or not is_visible.is_valid(): return false
	var in_sight: bool = bool(is_visible.call(NEST_POSITION))
	var newly_known: bool = in_sight and not nest.known
	if in_sight: nest.known = true
	NestVisual.set_observed(nest.node, nest.known, in_sight)
	return newly_known

## This is the only collection that should join host combat target candidates.
## The raw nest dictionary is for navigation/serialization, never unknown markers.
func targetable_structures() -> Array:
	if nest.is_empty() or not nest.known or nest.dead: return []
	return [nest]

func contains_target(target: Variant) -> bool:
	return target is Dictionary and not nest.is_empty() and is_same(target, nest)

func can_target(target: Variant) -> bool:
	return contains_target(target) and nest.known and not nest.dead

## Before the ordinary hit() body: if contains_target(e), apply_damage and return.
## Damage is already computed by the existing weapon/supply/upgrade rules.
## Return flags permit immediate host audio/notice without dispatching an event bus.
func apply_damage(target: Dictionary, damage: float) -> Dictionary:
	var result: Dictionary = {"applied": 0.0, "destroyed": false, "alarm_started": false}
	if not can_target(target) or not is_finite(damage) or damage <= 0.0: return result
	result.applied = minf(float(nest.hp), damage)
	nest.hp = maxf(0.0, float(nest.hp) - damage)
	if not alarm_triggered:
		alarm_triggered = true
		alarm_remaining = ALARM_SECONDS
		result.alarm_started = true
		_cues.append({"type": "nest_alarm", "position": NEST_POSITION, "seconds": ALARM_SECONDS})
	if nest.hp <= 0.0:
		nest.dead = true
		alarm_remaining = 0.0
		result.destroyed = true
		_cues.append({"type": "nest_destroyed", "position": NEST_POSITION})
	NestVisual.set_state(nest.node, nest.dead, alarm_remaining > 0.0)
	return result

## Invoke once per shell explosion / blast-queue event, alongside mobile hits.
## The circular footprint can overlap a blast even when its center is outside it.
## Unknown structures cannot receive damage from blind splash.
func apply_blast(position: Vector3, radius: float, damage: float) -> Dictionary:
	if nest.is_empty() or not position.is_finite() or not is_finite(radius) or radius <= 0.0:
		return {"applied": 0.0, "destroyed": false, "alarm_started": false}
	var planar := Vector2(position.x - NEST_POSITION.x, position.z - NEST_POSITION.z)
	if planar.length_squared() >= pow(radius + NEST_RADIUS, 2):
		return {"applied": 0.0, "destroyed": false, "alarm_started": false}
	return apply_damage(nest, damage)

## Host skips dormant enemies BEFORE route requests, steering and attack cooldowns.
## Awake status is permanent and never depends on camera or current fog visibility.
func enemy_can_act(enemy: Dictionary) -> bool:
	return not enemy.get("dead", false) and float(enemy.get("hp", 0.0)) > 0.0 and bool(enemy.get("frontier_awake", true))

## Call for every actual positive mobile hit before lethal enemies are removed.
## A lethal first hit still wakes that enemy's surviving camp companions.
func notify_enemy_damaged(host: Node3D, enemy: Dictionary) -> void:
	var group: int = int(enemy.get("frontier_group", -1))
	if group >= 0 and group < CAMP_CENTERS.size(): _wake_group(host, group)

## Simulation only. Invoke once per fixed step, even when the camera is elsewhere.
## Host passes 0..1 seconds; pause/end/title already suppress the simulation loop.
## Returns transient cues; saving and presentation never consume the gameplay RNG.
func tick(host: Node3D, dt: float) -> Array[Dictionary]:
	if nest.is_empty() or not is_finite(dt) or dt < 0.0 or dt > MAX_STEP_SECONDS: return []
	_wake_near_friendlies(host)
	if dt > 0.0 and not nest.dead:
		_tick_emergence(host, dt)
		raid_clock -= dt
		if raid_clock <= 0.0:
			var requested: int = mini(RAID_MAX_SIZE, RAID_INITIAL_SIZE + raid_index * RAID_GROWTH)
			var spawned: int = 0
			for index in requested:
				if _spawn_at_door(host, index, index % 4 == 3): spawned += 1
			raid_index = mini(MAX_RAID_INDEX, raid_index + 1)
			raid_clock += RAID_INTERVAL_SECONDS
			# A cue has a location only after discovery. Main must also apply fog
			# to mobile visuals; their simulation positions are not minimap hints.
			if nest.known and spawned > 0:
				_cues.append({"type": "nest_raid", "position": NEST_POSITION, "count": spawned})
	return take_cues()

func take_cues() -> Array[Dictionary]:
	var result: Array[Dictionary] = _cues.duplicate(true)
	_cues.clear()
	return result

## Inspect only AFTER the host's existing fatal-HQ check and blast processing.
func victory_pending() -> bool:
	return not nest.is_empty() and bool(nest.dead)

## Optional host-owned reward. No kill/XP/resource is granted by this module.
## Call after HQ survival; returns true exactly once, including across reloads.
func consume_destruction_reward() -> bool:
	if not victory_pending() or reward_claimed: return false
	reward_claimed = true
	return true

## Only surviving enemies in checkpoint order. Host saves their ordinary fields.
## Controller records authored camp group/awake metadata, not node IDs or paths.
func snapshot(living_enemies: Array) -> Dictionary:
	if nest.is_empty(): return {}
	var members: Array = []
	for index in living_enemies.size():
		var enemy: Dictionary = living_enemies[index]
		if enemy.has("frontier_group"):
			members.append({"enemy_index": index, "group": int(enemy.frontier_group), "awake": bool(enemy.frontier_awake)})
	return {"version": SNAPSHOT_VERSION,
		"nest": {"hp": float(nest.hp), "known": bool(nest.known), "dead": bool(nest.dead), "reward_claimed": reward_claimed},
		"raid_clock": raid_clock, "raid_index": raid_index, "camp_awake": camp_awake.duplicate(),
		"alarm_triggered": alarm_triggered, "alarm_remaining": alarm_remaining,
		"emergence_clock": emergence_clock, "emergence_index": emergence_index,
		"camp_members": members}

## Rejects unknown/missing keys, nonfinite/out-of-range values, inconsistent state,
## duplicate indices and excessive camps BEFORE restore creates or modifies nodes.
static func validate_snapshot(data: Variant, enemy_count: int) -> bool:
	if enemy_count < 0 or enemy_count > MOBILE_CAP: return false
	if not _keys_are(data, ["version", "nest", "raid_clock", "raid_index", "camp_awake", "alarm_triggered", "alarm_remaining", "emergence_clock", "emergence_index", "camp_members"]): return false
	if not _integer(data.version, SNAPSHOT_VERSION, SNAPSHOT_VERSION): return false
	if not _keys_are(data.nest, ["hp", "known", "dead", "reward_claimed"]): return false
	if not _number(data.nest.hp, 0.0, NEST_HP): return false
	for key in ["known", "dead", "reward_claimed"]:
		if not data.nest[key] is bool: return false
	if bool(data.nest.dead) != (float(data.nest.hp) == 0.0): return false
	if data.nest.reward_claimed and not data.nest.dead: return false
	if not _integer(data.raid_index, 0, MAX_RAID_INDEX): return false
	if not _number(data.raid_clock, 0.0, FIRST_RAID_SECONDS if int(data.raid_index) == 0 else RAID_INTERVAL_SECONDS): return false
	if not data.camp_awake is Array or data.camp_awake.size() != CAMP_CENTERS.size(): return false
	for awake in data.camp_awake:
		if not awake is bool: return false
	if not data.alarm_triggered is bool: return false
	if not _number(data.alarm_remaining, 0.0, ALARM_SECONDS): return false
	if not _number(data.emergence_clock, 0.0, EMERGENCE_SECONDS): return false
	if not _integer(data.emergence_index, 0, EMERGENCE_COUNT): return false
	if data.alarm_triggered != (float(data.nest.hp) < NEST_HP): return false
	if data.alarm_triggered and not data.nest.known: return false
	if not data.alarm_triggered and (float(data.alarm_remaining) != 0.0 or float(data.emergence_clock) != 0.0 or int(data.emergence_index) != 0): return false
	if float(data.alarm_remaining) > 0.0 and (float(data.emergence_clock) != 0.0 or int(data.emergence_index) != 0 or data.nest.dead): return false
	var expected_slots: int = mini(EMERGENCE_COUNT, floori(float(data.emergence_clock) / _emergence_interval() + 0.000001))
	if int(data.emergence_index) != expected_slots: return false
	if not data.camp_members is Array or data.camp_members.size() > CAMP_CENTERS.size() * (CAMP_NORMALS + CAMP_FAST): return false
	var used: Dictionary = {}
	var group_counts: Array[int] = [0, 0]
	for member in data.camp_members:
		if not _keys_are(member, ["enemy_index", "group", "awake"]): return false
		if not _integer(member.enemy_index, 0, enemy_count - 1) or not _integer(member.group, 0, CAMP_CENTERS.size() - 1): return false
		if not member.awake is bool or member.awake != data.camp_awake[int(member.group)]: return false
		if used.has(int(member.enemy_index)): return false
		used[int(member.enemy_index)] = true
		group_counts[int(member.group)] += 1
		if group_counts[int(member.group)] > CAMP_NORMALS + CAMP_FAST: return false
	return true

## Host validates its complete save before deleting current state. Recreate host
## enemies first, pass them in saved order, then restore their saved gameplay RNG
## after all spawn_enemy calls. This method makes no spawn calls and consumes no RNG.
func restore(host: Node3D, data: Variant, living_enemies: Array) -> bool:
	if not validate_snapshot(data, living_enemies.size()): return false
	reset(host, false)
	nest.hp = float(data.nest.hp)
	nest.known = bool(data.nest.known)
	nest.dead = bool(data.nest.dead)
	reward_claimed = bool(data.nest.reward_claimed)
	raid_clock = float(data.raid_clock)
	raid_index = int(data.raid_index)
	for group in CAMP_CENTERS.size(): camp_awake[group] = bool(data.camp_awake[group])
	alarm_triggered = bool(data.alarm_triggered)
	alarm_remaining = float(data.alarm_remaining)
	emergence_clock = float(data.emergence_clock)
	emergence_index = int(data.emergence_index)
	for enemy in living_enemies:
		enemy.erase("frontier_group")
		enemy.erase("frontier_awake")
	for member in data.camp_members:
		var enemy: Dictionary = living_enemies[int(member.enemy_index)]
		enemy["frontier_group"] = int(member.group)
		enemy["frontier_awake"] = bool(member.awake)
		enemy["moving"] = bool(member.awake)
		if not enemy.frontier_awake:
			enemy["moving"] = false
			enemy["route"] = []
			enemy["path_cd"] = 0.0
			enemy.erase("enemy_nav")
	# Restored fog clears current sight; remembered discovery is not live sight.
	nest.node.visible = false
	NestVisual.set_state(nest.node, nest.dead, alarm_remaining > 0.0)
	return true

func _wake_near_friendlies(host: Node3D) -> void:
	for enemy in host.enemies:
		if enemy.get("dead", false) or float(enemy.get("hp", 0.0)) <= 0.0: continue
		var group: int = int(enemy.get("frontier_group", -1))
		if group < 0 or group >= CAMP_CENTERS.size() or camp_awake[group]: continue
		if not is_instance_valid(enemy.get("node")): continue
		for friendly in host.units:
			if friendly.get("dead", false) or float(friendly.get("hp", 0.0)) <= 0.0 or not is_instance_valid(friendly.get("node")): continue
			if enemy.node.position.distance_squared_to(friendly.node.position) <= WAKE_DISTANCE * WAKE_DISTANCE:
				_wake_group(host, group)
				break

func _wake_group(host: Node3D, group: int) -> void:
	if camp_awake[group]: return
	camp_awake[group] = true
	for enemy in host.enemies:
		if int(enemy.get("frontier_group", -1)) != group: continue
		enemy["frontier_awake"] = true
		enemy["moving"] = true
		enemy["path_cd"] = 0.0
		enemy["route"] = []
		enemy.erase("enemy_nav")

func _tick_emergence(host: Node3D, dt: float) -> void:
	if not alarm_triggered or emergence_index >= EMERGENCE_COUNT: return
	var remaining_step: float = dt
	if alarm_remaining > 0.0:
		var alarm_step: float = minf(alarm_remaining, remaining_step)
		alarm_remaining = maxf(0.0, alarm_remaining - alarm_step)
		remaining_step -= alarm_step
		if alarm_remaining <= 0.0:
			_cues.append({"type": "nest_emergence", "position": NEST_POSITION, "seconds": EMERGENCE_SECONDS})
			NestVisual.set_state(nest.node, false, false)
	if remaining_step <= 0.0: return
	emergence_clock = minf(EMERGENCE_SECONDS, emergence_clock + remaining_step)
	var due: int = mini(EMERGENCE_COUNT, floori(emergence_clock / _emergence_interval() + 0.000001))
	while emergence_index < due:
		_spawn_at_door(host, emergence_index, emergence_index % 4 == 3)
		emergence_index += 1

func _spawn_at_door(host: Node3D, index: int, fast: bool) -> bool:
	if _living_count(host.enemies) >= MOBILE_CAP: return false
	var west: bool = index % 2 == 0
	var outward := Vector3.LEFT if west else Vector3.BACK
	var tangent := Vector3.BACK if west else Vector3.RIGHT
	# The host gameplay stream chooses physical spawn jitter, never visual RNG.
	var position: Vector3 = NEST_POSITION + outward * (DOOR_DISTANCE + host.rng.randf_range(0.0, 0.8)) + tangent * host.rng.randf_range(-0.9, 0.9)
	return not _spawn(host, position, fast).is_empty()

func _spawn(host: Node3D, position: Vector3, fast: bool) -> Dictionary:
	if _living_count(host.enemies) >= MOBILE_CAP: return {}
	var before: int = host.enemies.size()
	host.spawn_enemy(position, fast, false, false)
	if host.enemies.size() != before + 1: return {}
	return host.enemies.back()

static func _living_count(enemies: Array) -> int:
	var count: int = 0
	for enemy in enemies:
		if not enemy.get("dead", false) and float(enemy.get("hp", 0.0)) > 0.0: count += 1
	return count

static func _emergence_interval() -> float:
	return EMERGENCE_SECONDS / float(EMERGENCE_COUNT)

static func _keys_are(value: Variant, keys: Array) -> bool:
	if not value is Dictionary or value.size() != keys.size(): return false
	for key in keys:
		if not value.has(key): return false
	return true

static func _number(value: Variant, minimum: float, maximum: float) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) >= minimum and float(value) <= maximum

static func _integer(value: Variant, minimum: int, maximum: int) -> bool:
	return _number(value, minimum, maximum) and float(value) == floor(float(value))
