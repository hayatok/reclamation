extends RefCounted
## NEW reconstruction, 2026-10-07. Original geometry authored here, no imported assets.
## Fourteen cached, single-surface parts. Forward -Z; poses are actor-root-local.
## Only cosmetic poses are calculated: no actors, clocks, RNG, gameplay or navigation.

const PARTS: Array[String] = ["pelvis", "torso", "head", "thighL", "thighR", "shinL", "shinR", "footL", "footR", "upperArmL", "upperArmR", "forearmL", "forearmR", "weapon"]
const MUZZLE := Vector3(0.0, 0.012, -0.815)
const RIGHT_GRIP := Vector3(0.0, -0.070, -0.235)
const LEFT_GRIP := Vector3(-0.035, -0.028, -0.440)
const THIGH_LENGTH := 0.425
const SHIN_LENGTH := 0.435
const UPPER_ARM_LENGTH := 0.295
const FOREARM_LENGTH := 0.310
const ANKLE_HEIGHT := 0.085
const JACKET := Color("6094b1")
const DENIM := Color("667f91")
const SCARF := Color("cc7957")
const SKIN := Color("ccaa87")
const LEATHER := Color("765a45")
const PACK := Color("b29262")
const STEEL := Color("68777d")
const SOLE := Color("444a4b")
static var _meshes: Dictionary = {}
static var _material: StandardMaterial3D

## Cosmetic distance per complete left/right cycle. At 1.2 m/s: 1.01 cycles/s;
## at 4.4 m/s: 2.00 cycles/s. This does not change the actual speed of a unit.
static func cycle_distance(speed: float) -> float:
	return clampf(0.8 + maxf(speed, 0.0) * 0.32, 0.9, 2.2)

static func mesh_for(part: String) -> ArrayMesh:
	if _meshes.has(part): return _meshes[part]
	assert(part in PARTS, "Unknown articulated survivor part: " + part)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_geometry(st, part)
	st.set_material(_shared_material())
	var mesh: ArrayMesh = st.commit()
	mesh.resource_name = "ReconstructedCivilian_" + part
	_meshes[part] = mesh
	return mesh

static func _shared_material() -> StandardMaterial3D:
	if _material == null:
		_material = StandardMaterial3D.new()
		_material.vertex_color_use_as_albedo = true
		# Colors are converted explicitly at vertex emission. Compatibility ignores
		# vertex_color_is_srgb, so relying on that flag gives inconsistent colors.
		_material.vertex_color_is_srgb = false
		_material.roughness = 0.92
		_material.metallic = 0.0
		_material.metallic_specular = 0.12
	return _material

static func sample_pose(phase: float, moving: bool, attack_age: float = -1.0, reload_progress: float = -1.0, hit_age: float = -1.0, hit_strength: float = 1.0, locomotion_weight: float = 1.0, stride_distance: float = 2.2) -> Array[Transform3D]:
	phase = phase if is_finite(phase) else 0.0
	attack_age = attack_age if is_finite(attack_age) else -1.0
	reload_progress = reload_progress if is_finite(reload_progress) else -1.0
	hit_age = hit_age if is_finite(hit_age) else -1.0
	hit_strength = clampf(hit_strength, 0.0, 2.0) if is_finite(hit_strength) else 1.0
	locomotion_weight = clampf(locomotion_weight, 0.0, 1.0) if is_finite(locomotion_weight) else 0.0
	stride_distance = clampf(stride_distance, 0.9, 2.2) if is_finite(stride_distance) else 2.2
	var travel: float = locomotion_weight if moving else 0.0
	var jog: float = smoothstep(1.35, 2.20, stride_distance)
	var cycle: float = fposmod(phase / TAU, 1.0)
	var sway: float = sin(phase * 1.0) * travel
	var bob: float = (1.0 - cos(phase * 2.0)) * 0.010 * travel
	var recoil: float = exp(-attack_age * 23.0) if attack_age >= 0.0 and attack_age < 0.32 else 0.0
	var reload: float = sin(clampf(reload_progress, 0.0, 1.0) * PI) if reload_progress >= 0.0 else 0.0
	var reaction: float = sin(clampf(hit_age / 0.30, 0.0, 1.0) * PI) * exp(-maxf(hit_age, 0.0) * 6.0) * hit_strength if hit_age >= 0.0 and hit_age < 0.30 else 0.0
	var pelvis_pos := Vector3(sway * 0.013, 0.950 - travel * lerpf(0.065, 0.145, jog) + bob, 0.0)
	var pelvis_basis := Basis.from_euler(Vector3(0.0, -sway * 0.040, sway * 0.022))
	# Settle the hips when a long grounded step would overextend either leg.
	# Only this cosmetic pelvis moves; foot contacts and actor roots stay fixed.
	for side_index: int in 2:
		var side: float = -1.0 if side_index == 0 else 1.0
		var foot_data: Dictionary = foot_sample(cycle + float(side_index) * 0.5, stride_distance, travel)
		var hip_offset: Vector3 = pelvis_basis * Vector3(side * 0.114, -0.040, 0.0)
		var dx: float = pelvis_pos.x + hip_offset.x - side * 0.118
		var dz: float = pelvis_pos.z + hip_offset.z - float(foot_data.z)
		var reach: float = THIGH_LENGTH + SHIN_LENGTH - 0.002
		var max_height: float = float(foot_data.height) + sqrt(maxf(0.0, reach * reach - dx * dx - dz * dz)) - hip_offset.y
		pelvis_pos.y = minf(pelvis_pos.y, max_height)
	var pelvis := Transform3D(pelvis_basis, pelvis_pos)
	var torso_basis := Basis.from_euler(Vector3(-travel * 0.070 + recoil * 0.038 + reaction * 0.12, sway * 0.022, -sway * 0.018))
	var torso := Transform3D(torso_basis, pelvis_pos + Vector3(0.0, 0.040, recoil * 0.024 + reaction * 0.045))
	var head := Transform3D(Basis.from_euler(Vector3(0.0, sway * 0.012, 0.0)), torso * Vector3(0.0, 0.430, -0.010))
	var frames: Array[Transform3D] = []
	frames.resize(PARTS.size())
	frames[0] = pelvis
	frames[1] = torso
	frames[2] = head
	for side_index: int in 2:
		var side: float = -1.0 if side_index == 0 else 1.0
		var foot_data: Dictionary = foot_sample(cycle + float(side_index) * 0.5, stride_distance, travel)
		var ankle := Vector3(side * 0.118, float(foot_data.height), float(foot_data.z))
		var hip: Vector3 = pelvis * Vector3(side * 0.114, -0.040, 0.0)
		var knee: Vector3 = _joint(hip, ankle, THIGH_LENGTH, SHIN_LENGTH, Vector3(side * 0.03, 0.0, -1.0))
		frames[3 + side_index] = _segment(hip, knee)
		frames[5 + side_index] = _segment(knee, ankle)
		frames[7 + side_index] = Transform3D(Basis(Vector3.RIGHT, float(foot_data.pitch)), ankle)
	# The stock is the weapon origin, and remains on the actual right shoulder.
	# A small pitch impulse comes solely from the real attack timestamp.
	var weapon := Transform3D(Basis.from_euler(Vector3(recoil * 0.062 - reload * 0.48, reload * 0.25, reload * -0.18)), torso * Vector3(0.168, 0.335, -0.005))
	frames[13] = weapon
	for side_index: int in 2:
		var side: float = -1.0 if side_index == 0 else 1.0
		var shoulder: Vector3 = torso * Vector3(side * 0.205, 0.335, 0.0)
		var hand: Vector3 = weapon * (LEFT_GRIP if side_index == 0 else RIGHT_GRIP)
		var elbow: Vector3 = _joint(shoulder, hand, UPPER_ARM_LENGTH, FOREARM_LENGTH, Vector3(side * 0.72, -0.82, 0.33))
		frames[9 + side_index] = _segment(shoulder, elbow)
		frames[11 + side_index] = _segment(elbow, hand)
	return frames

## Stance is linear in phase, making an established planted foot stationary in
## world space when phase advances by actual distance / stride_distance.
## Swing returns the foot with zero vertical velocity at takeoff and landing.
static func foot_sample(cycle: float, stride_distance: float, travel: float = 1.0) -> Dictionary:
	cycle = fposmod(cycle, 1.0)
	var jog: float = smoothstep(1.35, 2.20, stride_distance)
	var duty: float = lerpf(0.60, 0.46, jog)
	var span: float = stride_distance * duty
	var z: float
	var lift: float = 0.0
	var pitch: float = 0.0
	if cycle < duty:
		z = -span * 0.5 + stride_distance * cycle
	else:
		var swing: float = (cycle - duty) / (1.0 - duty)
		z = lerpf(span * 0.5, -span * 0.5, smoothstep(0.0, 1.0, swing))
		lift = pow(sin(swing * PI), 2.0) * lerpf(0.105, 0.205, jog)
		pitch = -sin(swing * TAU) * 0.22
		lift += absf(sin(pitch)) * 0.18
	return {"z": z * travel, "height": ANKLE_HEIGHT + lift * travel, "pitch": pitch * travel, "stance": cycle < duty, "duty": duty}

## Analytic two-link chain; the pole is projected onto the chain's bend plane.
static func _joint(start: Vector3, finish: Vector3, first: float, second: float, pole: Vector3) -> Vector3:
	var delta: Vector3 = finish - start
	var actual_length: float = delta.length()
	var direction: Vector3 = delta / maxf(actual_length, 0.00001)
	var distance: float = clampf(actual_length, absf(first - second) + 0.0001, first + second - 0.0001)
	var along: float = (first * first - second * second + distance * distance) / (2.0 * distance)
	var height: float = sqrt(maxf(0.0, first * first - along * along))
	var bend: Vector3 = pole - direction * pole.dot(direction)
	if bend.length_squared() < 0.00001: bend = Vector3.RIGHT - direction * direction.x
	return start + direction * along + bend.normalized() * height

## All limb meshes run from their proximal joint along local -Y.
static func _segment(start: Vector3, finish: Vector3) -> Transform3D:
	var y: Vector3 = (start - finish).normalized()
	var x: Vector3 = y.cross(Vector3.BACK)
	if x.length_squared() < 0.00001: x = y.cross(Vector3.RIGHT)
	x = x.normalized()
	return Transform3D(Basis(x, y, x.cross(y).normalized()), start)

static func _geometry(st: SurfaceTool, part: String) -> void:
	if part == "pelvis":
		_loft(st, [Vector3(0.160, -0.090, 0.106), Vector3(0.162, 0.035, 0.110), Vector3(0.148, 0.075, 0.101)], DENIM, 8)
		_box(st, Vector3(0.305, 0.033, 0.208), Vector3(0, 0.051, 0), LEATHER)
		_box(st, Vector3(0.032, 0.032, 0.014), Vector3(0, 0.052, -0.111), PACK.lightened(0.12))
	elif part == "torso":
		_loft(st, [Vector3(0.165, 0.020, 0.113), Vector3(0.160, 0.180, 0.113), Vector3(0.215, 0.330, 0.125), Vector3(0.164, 0.400, 0.100)], JACKET, 8)
		# Open civilian jacket, stitched pockets and rolled collar, no body armor.
		_box(st, Vector3(0.078, 0.265, 0.013), Vector3(0, 0.203, -0.115), Color("c3bea5"))
		for side: int in [-1, 1]:
			_box(st, Vector3(0.090, 0.070, 0.012), Vector3(side * 0.108, 0.270, -0.122), JACKET.lightened(0.13))
			_box(st, Vector3(0.090, 0.009, 0.014), Vector3(side * 0.108, 0.302, -0.132), Color("c1bb99"))
			_box(st, Vector3(0.033, 0.305, 0.028), Vector3(side * 0.156, 0.215, -0.125), LEATHER.lightened(0.22), Vector3(0, 0, side * 0.11))
		# Soft hiking daypack is part of the torso mesh; no extra draw surface.
		_loft(st, [Vector3(0.141, 0.065, 0.076), Vector3(0.161, 0.220, 0.101), Vector3(0.127, 0.353, 0.075)], PACK, 8, Vector3(0, 0, 0.167))
		_box(st, Vector3(0.221, 0.098, 0.041), Vector3(0, 0.175, 0.270), PACK.darkened(0.1))
		_box(st, Vector3(0.023, 0.310, 0.020), Vector3(-0.095, 0.207, 0.270), LEATHER)
		_box(st, Vector3(0.027, 0.245, 0.026), Vector3(0.090, 0.205, 0.270), LEATHER)
		_loft(st, [Vector3(0.112, 0.350, 0.101), Vector3(0.129, 0.388, 0.112), Vector3(0.097, 0.430, 0.091)], SCARF, 8)
		_box(st, Vector3(0.075, 0.170, 0.031), Vector3(-0.073, 0.300, -0.147), SCARF.lightened(0.07), Vector3(0, 0, -0.16))
	elif part == "head":
		_loft(st, [Vector3(0.059, 0.006, 0.055), Vector3(0.061, 0.075, 0.061)], SKIN, 7)
		_loft(st, [Vector3(0.067, 0.067, 0.071), Vector3(0.099, 0.113, 0.087), Vector3(0.103, 0.209, 0.090), Vector3(0.083, 0.243, 0.075)], SKIN, 8, Vector3(0, 0, -0.005))
		_box(st, Vector3(0.031, 0.042, 0.030), Vector3(0, 0.147, -0.102), SKIN.lightened(0.07))
		for side: int in [-1, 1]:
			_box(st, Vector3(0.024, 0.007, 0.009), Vector3(side * 0.039, 0.175, -0.092), Color("5c4b3e"))
			_box(st, Vector3(0.025, 0.043, 0.039), Vector3(side * 0.103, 0.152, 0.0), SKIN.darkened(0.05))
		_loft(st, [Vector3(0.110, 0.208, 0.105), Vector3(0.111, 0.251, 0.105), Vector3(0.055, 0.286, 0.060)], PACK.darkened(0.05), 8)
		_box(st, Vector3(0.186, 0.018, 0.112), Vector3(0, 0.211, -0.133), PACK)
		_box(st, Vector3(0.042, 0.026, 0.009), Vector3(0, 0.243, -0.105), Color("d3c6a7"))
	elif part.begins_with("thigh"):
		_loft(st, [Vector3(0.083, -0.018, 0.089), Vector3(0.081, -0.160, 0.083), Vector3(0.068, -THIGH_LENGTH, 0.073)], DENIM, 7)
		_box(st, Vector3(0.013, 0.319, 0.013), Vector3(-0.065 if part.ends_with("L") else 0.065, -0.193, -0.049), DENIM.lightened(0.23))
	elif part.begins_with("shin"):
		_loft(st, [Vector3(0.067, 0.016, 0.073), Vector3(0.075, -0.120, 0.083), Vector3(0.054, -SHIN_LENGTH + 0.016, 0.059)], DENIM.lightened(0.035), 7)
		_box(st, Vector3(0.082, 0.078, 0.011), Vector3(0, -0.080, -0.079), DENIM.lightened(0.13), Vector3(0, 0, 0.07))
		_box(st, Vector3(0.106, 0.033, 0.116), Vector3(0, -0.391, 0), DENIM.lightened(0.22))
	elif part.begins_with("foot"):
		_box(st, Vector3(0.133, 0.031, 0.256), Vector3(0, -0.0695, -0.047), SOLE)
		_box(st, Vector3(0.127, 0.080, 0.226), Vector3(0, -0.026, -0.042), LEATHER)
		_box(st, Vector3(0.123, 0.089, 0.118), Vector3(0, 0.013, 0.004), LEATHER.lightened(0.13))
		for lace: float in [-0.025, -0.058, -0.088]:
			_box(st, Vector3(0.067, 0.011, 0.010), Vector3(0, 0.020, lace), PACK.lightened(0.15))
	elif part.begins_with("upperArm"):
		_loft(st, [Vector3(0.080, 0.030, 0.084), Vector3(0.072, -0.115, 0.078), Vector3(0.062, -UPPER_ARM_LENGTH, 0.066)], JACKET, 7)
		_box(st, Vector3(0.087, 0.077, 0.023), Vector3(0, -0.247, 0.054), JACKET.darkened(0.13))
	elif part.begins_with("forearm"):
		_loft(st, [Vector3(0.062, 0.010, 0.063), Vector3(0.061, -0.111, 0.063), Vector3(0.046, -0.204, 0.047)], JACKET, 7)
		_loft(st, [Vector3(0.067, -0.157, 0.067), Vector3(0.064, -0.202, 0.064)], JACKET.lightened(0.22), 7)
		_loft(st, [Vector3(0.044, -0.200, 0.044), Vector3(0.040, -0.259, 0.041)], SKIN, 7)
		_box(st, Vector3(0.078, 0.080, 0.076), Vector3(0, -FOREARM_LENGTH + 0.014, 0), SKIN)
	elif part == "weapon":
		# Original simple hunting/carbine silhouette with a wooden stock.
		_box(st, Vector3(0.062, 0.105, 0.140), Vector3(0, -0.013, -0.070), LEATHER.darkened(0.03))
		_box(st, Vector3(0.046, 0.067, 0.134), Vector3(0, 0.002, -0.180), LEATHER)
		_box(st, Vector3(0.067, 0.076, 0.226), Vector3(0, 0.004, -0.330), STEEL.darkened(0.17))
		_box(st, Vector3(0.074, 0.066, 0.135), Vector3(0, -0.002, -0.482), LEATHER.lightened(0.11))
		_box(st, Vector3(0.040, 0.101, 0.052), Vector3(0, -0.072, -0.231), LEATHER, Vector3(-0.18, 0, 0))
		_box(st, Vector3(0.046, 0.120, 0.057), Vector3(0, -0.077, -0.344), STEEL.darkened(0.23), Vector3(-0.12, 0, 0))
		_box(st, Vector3(0.034, 0.034, 0.265), Vector3(0, 0.012, -0.6825), STEEL)
		_box(st, Vector3(0.049, 0.049, 0.035), Vector3(0, 0.012, -0.7975), STEEL.darkened(0.21))
		_box(st, Vector3(0.022, 0.026, 0.036), Vector3(0, 0.050, -0.341), STEEL)

## Profile rings are (x radius, y height, z radius), connected with flat facets.
static func _loft(st: SurfaceTool, rings: Array, color: Color, sides: int = 8, offset: Vector3 = Vector3.ZERO) -> void:
	for ring_index: int in rings.size() - 1:
		var lower: Vector3 = rings[ring_index]
		var upper: Vector3 = rings[ring_index + 1]
		for side: int in sides:
			var a: float = TAU * (float(side) + 0.5) / float(sides)
			var b: float = TAU * (float(side) + 1.5) / float(sides)
			var lo_a := Vector3(cos(a) * lower.x, lower.y, sin(a) * lower.z) + offset
			var lo_b := Vector3(cos(b) * lower.x, lower.y, sin(b) * lower.z) + offset
			var hi_a := Vector3(cos(a) * upper.x, upper.y, sin(a) * upper.z) + offset
			var hi_b := Vector3(cos(b) * upper.x, upper.y, sin(b) * upper.z) + offset
			# Rings may descend for limbs: keep normals and winding facing outward.
			if upper.y > lower.y: _quad(st, lo_a, lo_b, hi_b, hi_a, color)
			else: _quad(st, hi_a, hi_b, lo_b, lo_a, color)
	for end_index: int in [0, rings.size() - 1]:
		var ring: Vector3 = rings[end_index]
		var top: bool = (end_index == rings.size() - 1) == (rings[-1].y > rings[0].y)
		for side: int in sides:
			var a: float = TAU * (float(side) + 0.5) / float(sides)
			var b: float = TAU * (float(side) + 1.5) / float(sides)
			var va := Vector3(cos(a) * ring.x, ring.y, sin(a) * ring.z) + offset
			var vb := Vector3(cos(b) * ring.x, ring.y, sin(b) * ring.z) + offset
			_triangle(st, Vector3(0, ring.y, 0) + offset, va if top else vb, vb if top else va, color)

static func _box(st: SurfaceTool, size: Vector3, position: Vector3, color: Color, angles: Vector3 = Vector3.ZERO) -> void:
	var h: Vector3 = size * 0.5
	var basis := Basis.from_euler(angles)
	var faces: Array = [
		[Vector3(-h.x,-h.y,h.z), Vector3(-h.x,h.y,h.z), Vector3(h.x,h.y,h.z), Vector3(h.x,-h.y,h.z)],
		[Vector3(h.x,-h.y,-h.z), Vector3(h.x,h.y,-h.z), Vector3(-h.x,h.y,-h.z), Vector3(-h.x,-h.y,-h.z)],
		[Vector3(h.x,-h.y,h.z), Vector3(h.x,h.y,h.z), Vector3(h.x,h.y,-h.z), Vector3(h.x,-h.y,-h.z)],
		[Vector3(-h.x,-h.y,-h.z), Vector3(-h.x,h.y,-h.z), Vector3(-h.x,h.y,h.z), Vector3(-h.x,-h.y,h.z)],
		[Vector3(-h.x,h.y,h.z), Vector3(-h.x,h.y,-h.z), Vector3(h.x,h.y,-h.z), Vector3(h.x,h.y,h.z)],
		[Vector3(-h.x,-h.y,-h.z), Vector3(-h.x,-h.y,h.z), Vector3(h.x,-h.y,h.z), Vector3(h.x,-h.y,-h.z)]]
	for face: Array in faces:
		_quad(st, basis * face[0] + position, basis * face[1] + position, basis * face[2] + position, basis * face[3] + position, color)

static func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, color: Color) -> void:
	_triangle(st, a, b, c, color)
	_triangle(st, a, c, d, color)

static func _triangle(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, color: Color) -> void:
	st.set_color(color.srgb_to_linear())
	st.set_normal((c - a).cross(b - a).normalized())
	st.add_vertex(a)
	st.add_vertex(b)
	st.add_vertex(c)
