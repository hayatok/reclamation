extends RefCounted
## M3 prototype: select one already-scheduled wave, then observe the objective
## zone. The host owns wave timing/counts, navigation, combat, UI and hold time.
const SNAPSHOT_VERSION: int = 1
const MIN_WARNING_SECONDS: float = 12.0
const DISRUPTION_RADIUS: float = 5.0
const MAX_TARGET_WAVE: int = 2147483647

var planned: bool = false
var dispatched: bool = false
var target_kind: String = ""
var target_wave: int = 0
var warning_remaining: float = 0.0

## New run or an old checkpoint without this optional prototype state.
func reset() -> void:
	planned = false
	dispatched = false
	target_kind = ""
	target_wave = 0
	warning_remaining = 0.0

## Call while transmission is ready, before the host advances its wave clock.
## A late candidate is skipped, not delayed; call again for a later normal wave.
## True is a one-shot cue to announce the target and its ordinary arrival time.
func plan_if_ready(ready: bool, next_wave: int, seconds_to_spawn: float, primary_side: int) -> bool:
	if not ready or planned or dispatched: return false
	if next_wave < 1 or next_wave > MAX_TARGET_WAVE: return false
	if not is_finite(seconds_to_spawn) or seconds_to_spawn < MIN_WARNING_SECONDS: return false
	if primary_side < 0 or primary_side > 2: return false
	target_kind = "substation" if primary_side == 2 else "pump"
	target_wave = next_wave
	planned = true
	warning_remaining = MIN_WARNING_SECONDS
	return true

## Advance once per simulation step, alongside the ordinary wave clock. The
## host may use this lower bound when accelerating an already-announced wave;
## this controller never changes the original wave schedule itself.
func advance_warning(dt: float) -> void:
	if not planned or dispatched or not is_finite(dt) or dt < 0.0: return
	warning_remaining = maxf(0.0, warning_remaining - dt)

## Invoke once when that ordinary wave spawns. True tells the host to redirect
## those existing enemies. Repeated calls and other wave numbers do nothing.
func activate_wave(number: int) -> bool:
	if not planned or dispatched or number != target_wave: return false
	dispatched = true
	warning_remaining = 0.0
	return true

## Current physical occupancy only: no latched threat, required garrison or
## distant-raider check. All living enemies can disrupt after dispatch.
## Positions use the host's common local world coordinates, matching main.gd.
## Ground-plane distance ignores actor visual/terrain elevation.
func is_blocked(enemies: Array, target_position: Vector3) -> bool:
	if not dispatched or not target_position.is_finite(): return false
	for enemy in enemies:
		if not enemy is Dictionary: continue
		var health: Variant = enemy.get("hp")
		if not (health is int or health is float): continue
		if not is_finite(float(health)) or float(health) <= 0.0: continue
		var dead: Variant = enemy.get("dead", false)
		if not dead is bool or dead: continue
		var actor: Variant = enemy.get("node")
		if not is_instance_valid(actor) or not actor is Node3D: continue
		var position: Vector3 = actor.position
		if not position.is_finite(): continue
		var offset := Vector2(position.x - target_position.x, position.z - target_position.z)
		if offset.length_squared() <= DISRUPTION_RADIUS * DISRUPTION_RADIUS: return true
	return false

func snapshot() -> Dictionary:
	return {"version": SNAPSHOT_VERSION, "planned": planned, "dispatched": dispatched,
		"target_kind": target_kind, "target_wave": target_wave, "warning_remaining": warning_remaining}

## Exact six-field schema. JSON integers decode as floats in Godot, so integer
## fields accept finite integral numbers only, never bool/string coercions.
static func validate_snapshot(data: Variant) -> bool:
	if not data is Dictionary or data.size() != 6: return false
	for key in ["version", "planned", "dispatched", "target_kind", "target_wave", "warning_remaining"]:
		if not data.has(key): return false
	if not _integer(data.version, SNAPSHOT_VERSION, SNAPSHOT_VERSION): return false
	if not data.planned is bool or not data.dispatched is bool: return false
	if not data.target_kind is String: return false
	if not _integer(data.target_wave, 0, MAX_TARGET_WAVE): return false
	if not _number(data.warning_remaining, 0.0, MIN_WARNING_SECONDS): return false
	if not data.planned:
		return not data.dispatched and data.target_kind == "" and int(data.target_wave) == 0 and float(data.warning_remaining) == 0.0
	if data.dispatched and float(data.warning_remaining) != 0.0: return false
	return data.target_kind in ["pump", "substation"] and int(data.target_wave) >= 1

## Validation finishes before any field changes. An absent checkpoint key is
## handled by the host with a fresh/reset controller; malformed data is rejected.
func restore(data: Variant) -> bool:
	if not validate_snapshot(data): return false
	planned = data.planned
	dispatched = data.dispatched
	target_kind = data.target_kind
	target_wave = int(data.target_wave)
	warning_remaining = float(data.warning_remaining)
	return true

static func _number(value: Variant, minimum: float, maximum: float) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) >= minimum and float(value) <= maximum

static func _integer(value: Variant, minimum: int, maximum: int) -> bool:
	if not (value is int or value is float): return false
	var number: float = float(value)
	return is_finite(number) and number >= minimum and number <= maximum and number == floor(number)
