extends RefCounted
## NEW worker reconstruction, 2026-10-08; not the missing v041 worker source.
## Original orange/tan civilian geometry. Analytic limb/contact and mesh emission
## conventions adapted from the recovered survivor and grenadier presentations.
## Fifteen cached, single-surface parts; no per-worker skeleton or mesh rebuild.
## Forward -Z. Every pose is actor-root-local and strictly cosmetic.

const PARTS: Array[String] = ["pelvis", "torso", "head", "thighL", "thighR", "shinL", "shinR", "footL", "footR", "upperArmL", "upperArmR", "forearmL", "forearmR", "tool", "cargo"]
const TOOL_INDEX := 13
const CARGO_INDEX := 14
const TOOL_HEAD := Vector3(0.0, 0.335, 0.0)
const THIGH_LENGTH := 0.425
const SHIN_LENGTH := 0.435
const UPPER_ARM_LENGTH := 0.295
const FOREARM_LENGTH := 0.310
const ANKLE_HEIGHT := 0.085
const JACKET := Color("bb7745")
const CANVAS := Color("ae9870")
const SHIRT := Color("777c75")
const SKIN := Color("ccaa87")
const LEATHER := Color("765a45")
const STEEL := Color("68777d")
const SOLE := Color("444a4b")
const HELMET := Color("c7a266")
static var _meshes: Dictionary = {}
static var _material: StandardMaterial3D

static func cycle_distance(speed: float) -> float:
	speed = maxf(speed, 0.0) if is_finite(speed) else 0.0
	return clampf(0.8 + speed * 0.32, 0.9, 2.2)

static func mesh_for(part: String) -> ArrayMesh:
	if _meshes.has(part): return _meshes[part]
	assert(part in PARTS, "Unknown reconstructed worker part: " + part)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_geometry(st, part)
	st.set_material(_shared_material())
	var mesh: ArrayMesh = st.commit()
	mesh.resource_name = "RebuiltCivilianWorker_" + part
	_meshes[part] = mesh
	return mesh

static func _shared_material() -> StandardMaterial3D:
	if _material == null:
		_material = StandardMaterial3D.new()
		_material.vertex_color_use_as_albedo = true
		_material.vertex_color_is_srgb = false
		_material.roughness = 0.92
		_material.metallic = 0.0
		_material.metallic_specular = 0.12
	return _material

## Visibility is separate from rigid poses so transform interpolation stays valid.
## The renderer may collapse hidden GPU instances only after interpolation.
static func part_visibility(worker_state: Dictionary = {}) -> Array[bool]:
	var visibility: Array[bool] = []
	visibility.resize(PARTS.size())
	visibility.fill(true)
	var carrying: Variant = worker_state.get("carrying", false)
	visibility[CARGO_INDEX] = carrying is bool and carrying
	return visibility

## worker_state is read-only. Only activity gather/construct authorizes work.
## carrying must be a true boolean supplied from real cargo by the motion adapter.
## cargo_kind is accepted without inventing a quantity or changing simulation.
## work_direction is a finite actor-local XZ vector; absent/invalid means -Z.
## All frames stay rigid/nondegenerate for interpolation; part_visibility hides cargo.
## Attack/reload inputs are intentionally ignored: workers have no fake magazine.
static func sample_pose(phase: float, moving: bool, _attack_age: float = -1.0, _reload_progress: float = -1.0, hit_age: float = -1.0, hit_strength: float = 1.0, locomotion_weight: float = 1.0, stride_distance: float = 2.2, worker_state: Dictionary = {}) -> Array[Transform3D]:
	phase = phase if is_finite(phase) else 0.0
	hit_age = hit_age if is_finite(hit_age) else -1.0
	hit_strength = clampf(hit_strength, 0.0, 2.0) if is_finite(hit_strength) else 1.0
	locomotion_weight = clampf(locomotion_weight, 0.0, 1.0) if is_finite(locomotion_weight) else 0.0
	stride_distance = clampf(stride_distance, 0.9, 2.2) if is_finite(stride_distance) else 2.2
	var activity: String = str(worker_state.get("activity", "none"))
	var working: bool = activity in ["gather", "construct"]
	var gathering: bool = activity == "gather"
	var carry_value: Variant = worker_state.get("carrying", false)
	var carrying: bool = carry_value is bool and carry_value
	var travel: float = locomotion_weight if moving and not working else 0.0
	var jog: float = smoothstep(1.35, 2.20, stride_distance)
	var cycle: float = fposmod(phase / TAU, 1.0)
	var sway: float = sin(phase) * travel
	var bob: float = (1.0 - cos(phase * 2.0)) * 0.010 * travel
	# Slow lift, quick strike, brief contact, then release. The caller advances
	# phase only for observed productive work; this function never creates work.
	var lift: float = (smoothstep(0.08, 0.50, cycle) if cycle < 0.50 else 1.0 - smoothstep(0.50, 0.68, cycle)) if working else 0.0
	var impact: float = smoothstep(0.50, 0.68, cycle) * (1.0 - smoothstep(0.82, 1.0, cycle)) if working else 0.0
	var reaction: float = sin(clampf(hit_age / 0.30, 0.0, 1.0) * PI) * exp(-maxf(hit_age, 0.0) * 6.0) * hit_strength if hit_age >= 0.0 and hit_age < 0.30 else 0.0
	var pelvis_pos := Vector3(sway * 0.013, 0.940 - travel * lerpf(0.060, 0.135, jog) + bob - (0.035 + impact * 0.020 if gathering else impact * 0.015), 0.0)
	var pelvis_basis := Basis.from_euler(Vector3(0.0, -sway * 0.040, sway * 0.020))
	var stance_width: float = 0.150 if working else 0.125
	# Settle the hips within each planted leg's reach, without moving the root.
	for side_index: int in 2:
		var side: float = -1.0 if side_index == 0 else 1.0
		var foot_data: Dictionary = foot_sample(cycle + float(side_index) * 0.5, stride_distance, travel)
		var hip_offset: Vector3 = pelvis_basis * Vector3(side * 0.114, -0.040, 0.0)
		var dx: float = pelvis_pos.x + hip_offset.x - side * stance_width
		var foot_z: float = float(foot_data.z) + side * (0.075 if working else 0.0)
		var dz: float = pelvis_pos.z + hip_offset.z - foot_z
		var reach: float = THIGH_LENGTH + SHIN_LENGTH - 0.002
		var max_height: float = float(foot_data.height) + sqrt(maxf(0.0, reach * reach - dx * dx - dz * dz)) - hip_offset.y
		pelvis_pos.y = minf(pelvis_pos.y, max_height)
	var pelvis := Transform3D(pelvis_basis, pelvis_pos)
	var work_lean: float = (-0.190 - impact * 0.055 + lift * 0.075) if gathering else (-0.035 - impact * 0.035 if working else 0.0)
	var torso_basis := Basis.from_euler(Vector3(work_lean - travel * 0.060 + reaction * 0.12, sway * 0.022, -sway * 0.018 - lift * 0.025))
	var torso := Transform3D(torso_basis, pelvis_pos + Vector3(0.0, 0.040, reaction * 0.040))
	var head := Transform3D(Basis.from_euler(Vector3(-0.075 if gathering else 0.0, 0.0, 0.0)), torso * Vector3(0.0, 0.430, -0.010))
	var frames: Array[Transform3D] = []
	frames.resize(PARTS.size())
	frames[0] = pelvis
	frames[1] = torso
	frames[2] = head
	for side_index: int in 2:
		var side: float = -1.0 if side_index == 0 else 1.0
		var foot_data: Dictionary = foot_sample(cycle + float(side_index) * 0.5, stride_distance, travel)
		var ankle := Vector3(side * stance_width, float(foot_data.height), float(foot_data.z) + side * (0.075 if working else 0.0))
		var hip: Vector3 = pelvis * Vector3(side * 0.114, -0.040, 0.0)
		var knee: Vector3 = _joint(hip, ankle, THIGH_LENGTH, SHIN_LENGTH, Vector3(side * 0.03, 0.0, -1.0))
		frames[3 + side_index] = _segment(hip, knee)
		frames[5 + side_index] = _segment(knee, ankle)
		frames[7 + side_index] = Transform3D(Basis(Vector3.RIGHT, float(foot_data.pitch)), ankle)
	var right_hand: Vector3 = torso * Vector3(0.270, -0.145 + absf(sway) * 0.020, -0.070 - sway * 0.150)
	var left_hand: Vector3 = torso * Vector3(-0.270, -0.145 + absf(sway) * 0.020, -0.070 + sway * 0.150)
	var tool_pitch: float = -2.70 + sway * 0.12
	if working:
		var contact := Vector3(0.255, -0.130, -0.325) if gathering else Vector3(0.255, 0.225, -0.340)
		var raised := Vector3(0.265, 0.315, -0.145) if gathering else Vector3(0.260, 0.520, -0.105)
		right_hand = torso * contact.lerp(raised, lift)
		tool_pitch = lerpf(-2.15 if gathering else -1.08, 0.18, lift)
		left_hand = torso * Vector3(-0.275, -0.065 if gathering else 0.125, -0.260 if gathering else -0.275)
	if carrying:
		# The tote remains under the left hand during productive work and transit.
		# Its appearance depends only on real cargo, never task labels or time.
		left_hand = torso * Vector3(-0.335, -0.170, -0.065 + sway * 0.025)
	frames[TOOL_INDEX] = Transform3D(torso.basis * Basis(Vector3.RIGHT, tool_pitch), right_hand)
	frames[CARGO_INDEX] = Transform3D(Basis(Vector3.FORWARD, -sway * 0.060), left_hand)
	for side_index: int in 2:
		var side: float = -1.0 if side_index == 0 else 1.0
		var shoulder: Vector3 = torso * Vector3(side * 0.212, 0.335, 0.0)
		var hand: Vector3 = left_hand if side_index == 0 else right_hand
		var elbow: Vector3 = _joint(shoulder, hand, UPPER_ARM_LENGTH, FOREARM_LENGTH, Vector3(side * 0.72, -0.82, 0.33))
		frames[9 + side_index] = _segment(shoulder, elbow)
		frames[11 + side_index] = _segment(elbow, hand)
	# Rotate the whole cosmetic stance toward the work target in actor-local space.
	# This also turns the planted feet, keeping a twist out of the hip/knee chains.
	if working:
		var direction: Variant = worker_state.get("work_direction", Vector3.ZERO)
		if direction is Vector3 and direction.is_finite():
			var planar := Vector3(direction.x, 0.0, direction.z)
			if planar.length_squared() > 0.000001:
				var facing := Transform3D(Basis(Vector3.UP, atan2(-planar.x, -planar.z)), Vector3.ZERO)
				for index: int in frames.size(): frames[index] = facing * frames[index]
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
		_loft(st, [Vector3(0.158, -0.090, 0.107), Vector3(0.163, 0.060, 0.113)], CANVAS, 8)
		_box(st, Vector3(0.316, 0.036, 0.218), Vector3(0, 0.045, 0), LEATHER)
		_box(st, Vector3(0.083, 0.140, 0.065), Vector3(0.143, -0.025, 0.045), LEATHER)
	elif part == "torso":
		# Soft work jacket, sloped shoulders and a canvas bib with utility pocket.
		_loft(st, [Vector3(0.167, 0.012, 0.117), Vector3(0.174, 0.180, 0.125), Vector3(0.222, 0.328, 0.137), Vector3(0.143, 0.402, 0.103)], JACKET, 8)
		_box(st, Vector3(0.220, 0.241, 0.022), Vector3(0, 0.170, -0.126), CANVAS)
		_box(st, Vector3(0.145, 0.079, 0.029), Vector3(0, 0.224, -0.146), CANVAS.darkened(0.16))
		for side: int in [-1, 1]:
			_box(st, Vector3(0.034, 0.316, 0.023), Vector3(side * 0.104, 0.220, -0.133), CANVAS.lightened(0.08), Vector3(0, 0, side * 0.07))
			_box(st, Vector3(0.033, 0.310, 0.022), Vector3(side * 0.106, 0.225, 0.126), CANVAS)
		_loft(st, [Vector3(0.092, 0.365, 0.087), Vector3(0.102, 0.410, 0.092)], SHIRT, 8)
	elif part == "head":
		_loft(st, [Vector3(0.060, -0.020, 0.061), Vector3(0.073, 0.060, 0.074), Vector3(0.107, 0.103, 0.101), Vector3(0.103, 0.219, 0.096)], SKIN, 8)
		# Short civilian hardhat with a broad brim and central reinforcing ridge.
		_loft(st, [Vector3(0.132, 0.196, 0.120), Vector3(0.127, 0.248, 0.117), Vector3(0.073, 0.291, 0.074)], HELMET, 8)
		_box(st, Vector3(0.280, 0.026, 0.277), Vector3(0, 0.198, -0.013), HELMET.darkened(0.08))
		_box(st, Vector3(0.039, 0.021, 0.163), Vector3(0, 0.279, 0), HELMET.lightened(0.10))
		_box(st, Vector3(0.107, 0.036, 0.020), Vector3(0, 0.131, -0.092), LEATHER.darkened(0.16))
	elif part.begins_with("thigh"):
		_loft(st, [Vector3(0.084, -0.016, 0.091), Vector3(0.083, -0.157, 0.086), Vector3(0.066, -THIGH_LENGTH, 0.072)], CANVAS, 7)
		_box(st, Vector3(0.022, 0.147, 0.095), Vector3(-0.073 if part.ends_with("L") else 0.073, -0.161, 0.008), CANVAS.darkened(0.16))
	elif part.begins_with("shin"):
		_loft(st, [Vector3(0.066, 0.016, 0.072), Vector3(0.072, -0.139, 0.078), Vector3(0.052, -SHIN_LENGTH + 0.012, 0.058)], CANVAS, 7)
		_box(st, Vector3(0.098, 0.127, 0.025), Vector3(0, -0.051, -0.070), LEATHER)
		_box(st, Vector3(0.108, 0.065, 0.121), Vector3(0, -0.372, 0), CANVAS.darkened(0.18))
	elif part.begins_with("foot"):
		_box(st, Vector3(0.135, 0.031, 0.258), Vector3(0, -0.0695, -0.047), SOLE)
		_box(st, Vector3(0.129, 0.078, 0.228), Vector3(0, -0.027, -0.042), LEATHER)
		_box(st, Vector3(0.120, 0.104, 0.122), Vector3(0, 0.014, 0.005), LEATHER.lightened(0.12))
	elif part.begins_with("upperArm"):
		_loft(st, [Vector3(0.083, 0.030, 0.086), Vector3(0.075, -0.120, 0.078), Vector3(0.061, -UPPER_ARM_LENGTH, 0.064)], JACKET, 7)
	elif part.begins_with("forearm"):
		_loft(st, [Vector3(0.062, 0.012, 0.064), Vector3(0.063, -0.140, 0.065), Vector3(0.047, -0.236, 0.050)], JACKET, 7)
		_loft(st, [Vector3(0.064, -0.172, 0.064), Vector3(0.055, -0.235, 0.055)], CANVAS, 7)
		_box(st, Vector3(0.080, 0.105, 0.082), Vector3(0, -FOREARM_LENGTH + 0.018, 0), LEATHER)
	elif part == "tool":
		# Short salvage hammer. Origin is the right grip; head socket is TOOL_HEAD.
		_box(st, Vector3(0.046, 0.411, 0.047), Vector3(0, 0.129, 0), LEATHER.lightened(0.16))
		_box(st, Vector3(0.061, 0.106, 0.062), Vector3(0, -0.013, 0), LEATHER.darkened(0.16))
		_box(st, Vector3(0.252, 0.096, 0.108), TOOL_HEAD, STEEL)
		_box(st, Vector3(0.030, 0.107, 0.119), TOOL_HEAD + Vector3(-0.119, 0, 0), STEEL.darkened(0.17))
	elif part == "cargo":
		# Neutral canvas resource tote. No resource is generated by this geometry.
		_loft(st, [Vector3(0.129, -0.370, 0.111), Vector3(0.158, -0.148, 0.132), Vector3(0.144, -0.110, 0.118)], CANVAS.darkened(0.10), 6)
		_box(st, Vector3(0.226, 0.028, 0.184), Vector3(0, -0.106, 0), SHIRT.darkened(0.18))
		for side: int in [-1, 1]:
			_box(st, Vector3(0.030, 0.125, 0.038), Vector3(side * 0.113, -0.065, 0), LEATHER)
		_box(st, Vector3(0.247, 0.030, 0.039), Vector3(0, -0.005, 0), LEATHER)

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
