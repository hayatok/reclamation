extends RefCounted
## Pure presentation only. direction points AWAY from the impact source in world XZ.
## Capture the root before death; never apply this offset to a living actor or hit test.
## The baked clip already topples the body. rotation adds only a short impact accent,
## returning to identity before landing; do not also apply ActorVisuals.sample_death.

const BALLISTIC: StringName = &"ballistic"
const EXPLOSIVE: StringName = &"explosive"
const ELECTRIC: StringName = &"electric"
const LIFETIME: float = 3.5
const BAKED_DURATION: float = 1.2
const PROCEDURAL_DURATION: float = 0.72
const MAX_TRAVEL: float = 0.58
const MAX_LIFT: float = 0.11
const MAX_TILT: float = 0.115

## offset and rotation are in WORLD space, independent of root scale and facing.
## clip_age drives InfectedPoseLibrary; fall_age drives the legacy procedural fall.
## Sample from absolute age every time. No accumulated transforms, RNG or state writes.
static func sample(cause: StringName, direction: Vector3, age: float) -> Dictionary:
	age = clampf(age, 0.0, LIFETIME) if is_finite(age) else 0.0
	var away: Vector3 = _flat_unit(direction)
	var offset := Vector3.ZERO
	var angle: float = 0.0
	var progress: float = 0.0
	match cause:
		EXPLOSIVE:
			# A bounded 58 cm push, with an 11 cm grounded arc.
			offset = away * MAX_TRAVEL * _ease_out(age / 0.50)
			offset.y = MAX_LIFT * _pulse(age, 0.10, 0.50)
			angle = MAX_TILT * _pulse(age, 0.08, 0.43)
			progress = clampf(age / 0.64, 0.0, 1.0)
		ELECTRIC:
			# A short held silhouette, then a quicker collapse in place.
			var tension: float = _pulse(age, 0.055, 0.17)
			offset = away * -0.018 * tension
			offset.y = 0.012 * tension
			angle = -0.035 * tension
			progress = clampf((age - 0.15) / 0.50, 0.0, 1.0)
		_:
			# Brief 18 cm recoil followed by the familiar weighted collapse.
			offset = away * 0.18 * _ease_out(age / 0.22)
			angle = 0.065 * _pulse(age, 0.045, 0.26)
			progress = clampf(age / 0.90, 0.0, 1.0)
	var rotation := Basis.IDENTITY
	if not away.is_zero_approx():
		rotation = Basis(Vector3.UP.cross(away), angle)
	return {"offset": offset, "rotation": rotation,
		"clip_age": progress * BAKED_DURATION,
		"fall_age": progress * PROCEDURAL_DURATION}

## Rotate about the captured root, not the world origin. Translation stays world-space
## and is never scaled by creature size. Apply the existing end-of-life fade AFTER this.
static func apply_world(start_world: Transform3D, motion: Dictionary) -> Transform3D:
	return Transform3D(motion.rotation * start_world.basis, start_world.origin + motion.offset)

static func _flat_unit(value: Vector3) -> Vector3:
	if not value.is_finite():
		return Vector3.ZERO
	# Scale before length() so even a huge finite input cannot overflow normalization.
	var largest: float = maxf(absf(value.x), absf(value.z))
	if largest < 0.00001:
		return Vector3.ZERO
	return Vector3(value.x / largest, 0.0, value.z / largest).normalized()

static func _ease_out(value: float) -> float:
	var remaining: float = 1.0 - clampf(value, 0.0, 1.0)
	return 1.0 - remaining * remaining * remaining

## C1 continuous endpoints and peak; zero exactly at birth and after end.
static func _pulse(age: float, peak: float, end: float) -> float:
	if age <= 0.0 or age >= end:
		return 0.0
	return smoothstep(0.0, peak, age) if age <= peak else 1.0 - smoothstep(peak, end, age)
