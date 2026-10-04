extends RefCounted
## Original low-poly actor silhouettes. Forward is -Z; actor roots are never moved.
## Each actor has six single-surface meshes, shared across instances of its kind.
## Matte rail-command palette: slate/bone friendlies, workwear amber, ash/rust infected.
## phase is a gait angle in radians (about elapsed * 8 for human walking).

static var _meshes: Dictionary = {}
static var _material: StandardMaterial3D

static func add_human(parent: Node3D, kind: String) -> void:
	_add(parent, "grenade" if kind in ["grenade", "grenadier"] else ("guard" if kind == "guard" else "worker"))

static func add_enemy(parent: Node3D, fast: bool, armored: bool = false) -> void:
	_add(parent, "armored" if armored else ("runner" if fast else "infected"))

## Shared source geometry for the horde MultiMesh renderer.
static func mesh_for(kind: String, part: String) -> ArrayMesh:
	return _mesh(kind, part)

## Backward-compatible walk/idle entry point. Call pose instead when combat timing is available.
static func animate(parent: Node3D, phase: float, moving: bool) -> void:
	pose(parent, phase, moving)

## All times are seconds since event; -1 means inactive. Reload is normalized [0,1], -1 inactive.
## Calling each frame is required: pose fully resets transforms, so effects never accumulate.
static func pose(parent: Node3D, phase: float, moving: bool, attack_age: float = -1.0, reload_progress: float = -1.0, working: bool = false, hit_age: float = -1.0, hit_strength: float = 1.0) -> void:
	if not is_instance_valid(parent) or not parent.has_meta(&"actor_visuals"):
		return
	var visual: Node3D = parent.get_meta(&"actor_visuals")
	if not is_instance_valid(visual): return
	var kind: String = visual.get_meta(&"kind")
	var frames := sample_pose(kind, phase, moving, attack_age, reload_progress, working, hit_age, hit_strength)
	var body: Node3D = visual.get_meta(&"body")
	body.transform = frames[0]
	var leg_l: Node3D = visual.get_meta(&"leg_l")
	var leg_r: Node3D = visual.get_meta(&"leg_r")
	leg_l.transform = frames[2]
	leg_r.transform = frames[3]
	var arm_l: Node3D = visual.get_meta(&"arm_l")
	var arm_r: Node3D = visual.get_meta(&"arm_r")
	# Arm nodes remain children of the torso for existing renderer metadata contracts.
	var inverse := body.transform.affine_inverse()
	arm_l.transform = inverse * frames[4]
	arm_r.transform = inverse * frames[5]

## Allocation is one six-element array. All outputs are ACTOR-ROOT-LOCAL, in horde PARTS order:
## torso, head, legL, legR, armL, armR. Batched renderers can multiply each by actor.global_transform.
## No nodes, materials, meshes, simulation state or actor root transforms are changed here.
static func sample_pose(kind: String, phase: float, moving: bool, attack_age: float = -1.0, reload_progress: float = -1.0, working: bool = false, hit_age: float = -1.0, hit_strength: float = 1.0) -> Array[Transform3D]:
	phase = phase if is_finite(phase) else 0.0
	attack_age = attack_age if is_finite(attack_age) else -1.0
	reload_progress = reload_progress if is_finite(reload_progress) else -1.0
	hit_age = hit_age if is_finite(hit_age) else -1.0
	hit_strength = clampf(hit_strength, 0.0, 2.0) if is_finite(hit_strength) else 1.0
	var runner: bool = kind == "runner"
	var armored: bool = kind == "armored"
	var worker: bool = kind == "worker"
	var grenade: bool = kind in ["grenade", "grenadier"]
	var human: bool = kind in ["guard", "worker", "grenade", "grenadier"]
	var hip: float = .65 if armored else .58
	var lean: float = -.34 if runner else (-.12 if armored else (-.22 if not human else 0.0))
	var width: float = .39 if armored else (.25 if runner else .32)
	var shoulder: float = .43 if armored else .4
	var leg_width: float = .19 if armored else .15
	var gait: float = sin(phase) if moving else 0.0
	var stride: float = .57 if runner else (.29 if grenade else .37)
	var bob: float = absf(cos(phase)) * .025 if moving else sin(phase * .30) * .006
	var roll: float = gait * .028
	var recoil: float = exp(-attack_age * (10.0 if grenade else 22.0)) if attack_age >= 0.0 and attack_age < .65 else 0.0
	var reload: float = sin(clampf(reload_progress, 0.0, 1.0) * PI) if reload_progress >= 0.0 else 0.0
	var reaction: float = sin(clampf(hit_age / .30, 0.0, 1.0) * PI) * exp(-maxf(hit_age,0.0) * 4.0) * hit_strength if hit_age >= 0.0 and hit_age < .30 else 0.0
	var swing: float = .48 if runner else (.22 if worker else .07)
	var left_angles := Vector3(-gait * swing, 0, 0)
	var right_angles := Vector3(gait * swing, 0, 0)
	var body_angles := Vector3(lean, 0, roll)
	var body_pos := Vector3(0, hip + bob, 0)
	var left_offset := Vector3.ZERO
	var right_offset := Vector3.ZERO
	if human and not worker:
		# Aimed weapon stays stable in gait; shot pushes gun, both hands and shoulder back.
		var power: float = 1.8 if grenade else 1.0
		body_angles.x += recoil * .10 * power
		body_pos.z += recoil * .055 * power
		body_pos.y -= recoil * .025 * power
		right_angles += Vector3(recoil * .24 * power, recoil * -.04, 0)
		left_angles += Vector3(recoil * .15 * power, 0, 0)
		right_offset.z += recoil * .085 * power
		left_offset.z += recoil * .055 * power
		# Reload: rifle/launcher lifted across chest; left hand reaches the magazine,
		# dips to the belt around mid-cycle and returns before the gun settles.
		body_angles.y += reload * -.12
		right_angles += Vector3(reload * .70, reload * .32, reload * -.16)
		left_angles += Vector3(reload * -.35, reload * -.92, reload * -.32)
		var magazine: float = sin(clampf((reload_progress-.20)/.60,0.0,1.0)*PI) if reload_progress >= 0.0 else 0.0
		left_offset += Vector3(magazine * .12, -magazine * .14, magazine * .03)
		right_offset += Vector3(-reload * .04, reload * .06, reload * .025)
	elif worker and working:
		# Tool arm winds up then snaps down; off-hand braces the work surface.
		var cycle: float = fposmod(phase / TAU, 1.0)
		var lift: float = smoothstep(0.0,.65,cycle) if cycle < .65 else 1.0-smoothstep(.65,.86,cycle)
		right_angles.x = -.32 + lift * 1.45
		right_angles.z = lift * -.15
		left_angles = Vector3(-.40,-.18,-.22)
		body_angles.x = -.12 + lift * .14
		body_pos.y -= (1.0-lift)*.05
		body_angles.z = lift * -.06
	elif not human and recoil > 0.0:
		# Short whole-upper-body bite/lunge, readable without moving simulation roots.
		body_angles.x -= recoil * .20
		body_pos.z -= recoil * .13
		left_angles.x -= recoil * .40
		right_angles.x -= recoil * .27
	body_pos += Vector3(reaction * .035, -reaction * .035, reaction * .17)
	body_angles += Vector3(reaction * .28, reaction * -.10, reaction * .12)
	left_angles.z -= reaction * .20
	right_angles.z += reaction * .24
	var body := Transform3D(Basis.from_euler(body_angles), body_pos)
	var leg_l := Transform3D(Basis(Vector3.RIGHT, gait * stride), Vector3(-leg_width, hip, 0))
	var leg_r := Transform3D(Basis(Vector3.RIGHT, -gait * stride), Vector3(leg_width, hip, 0))
	var arm_l := body * Transform3D(Basis.from_euler(left_angles), Vector3(-width, shoulder, 0)+left_offset)
	var arm_r := body * Transform3D(Basis.from_euler(right_angles), Vector3(width, shoulder, 0)+right_offset)
	return [body, body, leg_l, leg_r, arm_l, arm_r]

## Cosmetic corpse whole-body offset only. Compose corpse_world * sample_death(age) * part_pose.
## Feed a frozen six-part pose captured at death; do not also apply a second renderer fall.
## Duration .72s: sharp impact, weighted topple, small settle. No gore or root simulation changes.
static func sample_death(age: float, side: float = 1.0, forward: float = 1.0) -> Transform3D:
	age = maxf(age,0.0) if is_finite(age) else 0.0
	side = clampf(side,-1.0,1.0) if is_finite(side) else 1.0
	forward = clampf(forward,-1.0,1.0) if is_finite(forward) else 1.0
	var t: float = clampf(age/.72,0.0,1.0)
	var fall: float = t*t*(3.0-2.0*t)
	var direction := Vector3(forward,0,side*.65)
	if direction.length_squared()<.01: direction=Vector3.RIGHT
	direction=direction.normalized()
	var settle: float = sin(clampf((age-.48)/.24,0.0,1.0)*PI)*.065
	var basis := Basis(direction,fall*1.47-settle)
	var pivot := Vector3(0,.62,0)
	var origin: Vector3 = pivot-basis*pivot+Vector3(side*.14*fall,-.46*fall,forward*.25*fall)
	return Transform3D(basis,origin)

static func _add(parent: Node3D, kind: String) -> void:
	if parent.has_meta(&"actor_visuals"):
		return
	var visual := Node3D.new()
	visual.name = "ActorVisuals"
	parent.add_child(visual)
	parent.set_meta(&"actor_visuals", visual)
	var hip: float = 0.65 if kind == "armored" else 0.58
	var lean: float = -0.34 if kind == "runner" else (-0.22 if kind == "infected" else (-0.12 if kind == "armored" else 0.0))
	var width: float = 0.39 if kind == "armored" else (0.25 if kind == "runner" else 0.32)
	visual.set_meta(&"kind", kind)
	visual.set_meta(&"hip", hip)
	visual.set_meta(&"lean", lean)
	var body := Node3D.new()
	body.name = "Body"
	visual.add_child(body)
	body.position.y = hip
	body.rotation.x = lean
	visual.set_meta(&"body", body)
	_instance(body, _mesh(kind, "torso"), "Torso")
	_instance(body, _mesh(kind, "head"), "Head")
	for side: int in [-1, 1]:
		var suffix: String = "L" if side < 0 else "R"
		var leg := Node3D.new()
		leg.name = "Leg" + suffix
		visual.add_child(leg)
		leg.position = Vector3(side * (0.19 if kind == "armored" else 0.15), hip, 0.0)
		_instance(leg, _mesh(kind, "leg" + suffix), "Geometry")
		visual.set_meta(&"leg_l" if side < 0 else &"leg_r", leg)
		var arm := Node3D.new()
		arm.name = "Arm" + suffix
		body.add_child(arm)
		arm.position = Vector3(side * width, 0.43 if kind == "armored" else 0.4, 0.0)
		_instance(arm, _mesh(kind, "arm" + suffix), "Geometry")
		visual.set_meta(&"arm_l" if side < 0 else &"arm_r", arm)

static func _instance(parent: Node3D, mesh: ArrayMesh, node_name: String) -> void:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = mesh
	parent.add_child(instance)

static func _shared_material() -> StandardMaterial3D:
	if _material == null:
		_material = StandardMaterial3D.new()
		_material.vertex_color_use_as_albedo = true
		_material.roughness = 0.96
		_material.metallic = 0.0
		_material.metallic_specular = .10
	return _material

static func _mesh(kind: String, part: String) -> ArrayMesh:
	var key: String = kind + ":" + part
	if _meshes.has(key):
		return _meshes[key]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	if kind in ["guard", "worker", "grenade"]:
		_human_geometry(st, kind, part)
	else:
		_enemy_geometry(st, kind, part)
	st.set_material(_shared_material())
	var mesh: ArrayMesh = st.commit()
	_meshes[key] = mesh
	return mesh

static func _human_geometry(st: SurfaceTool, kind: String, part: String) -> void:
	var guard: bool = kind in ["guard", "grenade"]
	var grenade: bool = kind == "grenade"
	var uniform := (Color("8d5a37") if grenade else Color("546775")) if guard else Color("a57837")
	var accent := (Color("bd975e") if grenade else Color("9e8e72")) if guard else Color("d5b563")
	var bone := Color("d4c9aa")
	var ochre := Color("b69a61")
	var dark := Color("292e31")
	var skin := Color("b9a489")
	var steel := Color("8c918d")
	if part == "torso":
		_prism(st, .24, .30, .49, Vector3(0,.26,0),uniform,6,.70)
		_box(st, Vector3(.51, .32, .09), Vector3(0, .30, -.18), accent)
		_box(st, Vector3(.45, .13, .3), Vector3(0, .025, 0), dark)
		# Mismatched salvaged protection over civilian workwear and a travel backpack.
		for side: int in [-1, 1]:
			_box(st, Vector3(.20, .13 if side < 0 else .09, .30), Vector3(side * .28, .45, 0), bone.darkened(.2) if guard and side < 0 else uniform.darkened(.1))
			_box(st, Vector3(.12, .14, .065), Vector3(side * .135, .20, -.24), dark)
		_box(st, Vector3(.34, .40, .19), Vector3(0, .28, .22), dark)
		_box(st, Vector3(.25, .12, .035), Vector3(0, .41, .327), ochre if guard else accent)
		_box(st,Vector3(.07,.38,.04),Vector3(-.16,.28,-.245),Color("614b35"),Vector3(0,0,.18))
		_box(st,Vector3(.18,.13,.045),Vector3(.10,.31,-.25),Color("a18d69"),Vector3(0,0,-.08))
		if grenade:
			for x in [-.15,0,.15]:
				_prism(st,.055,.055,.21,Vector3(x,.27,-.27),ochre,6)
			_box(st,Vector3(.42,.25,.23),Vector3(0,.40,.28),accent)
		if guard:
			_box(st, Vector3(.032, .36, .035), Vector3(.14, .54, .24), steel)
			_box(st, Vector3(.20, .035, .03), Vector3(0, .43, -.24), bone)
		else:
			_box(st, Vector3(.37, .055, .04), Vector3(0, .36, -.24), bone)
			_box(st, Vector3(.065, .48, .06), Vector3(-.19, .32, .24), steel)
			_box(st, Vector3(.22, .075, .08), Vector3(-.19, .55, .24), dark)
	elif part == "head":
		_prism(st, .115, .125, .26, Vector3(0, .665, -.015), skin, 6, .9)
		if guard:
			# Civilian scavengers: battered baseball cap / welding hood, never a uniform helmet.
			_prism(st,.155,.105,.10,Vector3(0,.785,.0),Color("51473a"),7,.96)
			_box(st,Vector3(.25,.035,.17),Vector3(0,.761,-.15),accent)
			_box(st,Vector3(.17,.10,.10),Vector3(0,.609,-.12),Color("9d5140"))
			_box(st,Vector3(.09,.24,.05),Vector3(.10,.54,-.17),Color("9d5140"),Vector3(0,0,.20))
			if grenade:
				_box(st,Vector3(.31,.28,.055),Vector3(0,.68,-.155),dark,Vector3(-.12,0,0))
				_box(st,Vector3(.18,.055,.025),Vector3(0,.725,-.195),ochre)
				_prism(st,.18,.145,.12,Vector3(0,.83,0),accent,8,.95)

		else:
			_prism(st, .17, .12, .135, Vector3(0, .79, -.005), accent, 8, 1.0)
			_prism(st, .23, .23, .04, Vector3(0, .724, -.025), accent, 8, .89)
			_box(st, Vector3(.045, .025, .25), Vector3(0, .86, -.02), bone)
			_box(st, Vector3(.22, .05, .035), Vector3(0, .675, -.137), dark)
	elif part.begins_with("leg"):
		_prism(st,.085,.115,.28,Vector3(0,-.12,0),Color("4c5558") if guard else uniform.darkened(.24),6,.95)
		_prism(st,.075,.09,.25,Vector3(0,-.35,.015),dark,6,.90)
		_box(st, Vector3(.19, .15, .31), Vector3(0, -.493, -.055), dark.darkened(.14))
		_box(st, Vector3(.19, .14, .07), Vector3(0, -.29, -.115), accent.darkened(.22))
	elif part.begins_with("arm"):
		var side: float = -1.0 if part == "armL" else 1.0
		_prism(st,.075,.11,.27,Vector3(side*.025,-.14,-.015),uniform,6,.85)
		_box(st, Vector3(.13, .17, .25), Vector3(0, -.27, -.13), dark, Vector3(.35, 0, 0))
		_box(st, Vector3(.13, .12, .13), Vector3(0, -.24, -.265), skin)
		if part == "armR":
			if grenade:
				# Oversized drum-fed launcher, squared blast shield and shoulder stock.
				_box(st,Vector3(.22,.22,.75),Vector3(-.035,-.18,-.45),dark)
				_prism(st,.19,.19,.19,Vector3(-.035,-.37,-.43),ochre,8,1)
				_box(st,Vector3(.28,.28,.25),Vector3(-.035,-.18,-.92),accent)
				_box(st,Vector3(.15,.15,.03),Vector3(-.035,-.18,-1.055),dark)
			elif guard:
				_box(st, Vector3(.13, .14, .53), Vector3(-.035, -.18, -.37), Color("614b35"))
				_box(st,Vector3(.14,.145,.045),Vector3(-.035,-.18,-.47),bone)
				_box(st, Vector3(.065, .065, .28), Vector3(-.035, -.175, -.745), steel)
				_box(st, Vector3(.09, .16, .12), Vector3(-.035, -.30, -.36), dark)
				_box(st, Vector3(.06, .06, .10), Vector3(-.035, -.08, -.37), steel)
			else:
				_box(st, Vector3(.065, .38, .065), Vector3(0, -.19, -.30), steel)
				_box(st, Vector3(.20, .10, .09), Vector3(0, .015, -.30), dark)

static func _enemy_geometry(st: SurfaceTool, kind: String, part: String) -> void:
	var runner: bool = kind == "runner"
	var armored: bool = kind == "armored"
	var cloth := Color("874a45") if runner else (Color("535951") if armored else Color("59605e"))
	var skin := Color("939d82") if not runner else Color("9e8e79")
	var dark := Color("303735")
	var plate := Color("92755a")
	var wound := Color("70423e")
	if part == "torso":
		_prism(st,.17 if runner else (.29 if armored else .21),.23 if runner else (.38 if armored else .29),.52,Vector3(0,.25,0),cloth,7,.72)
		# The jutting upper back and ragged shirt make a hunched outline.
		_prism(st,.25 if runner else .31,.19 if runner else .24,.28,Vector3(0,.43,.08),cloth.lightened(.07),7,.70)
		_box(st, Vector3(.38, .13, .29), Vector3(.015, -.015, .005), dark)
		for rag in [-.16,.03,.16]:
			_box(st,Vector3(.08,.20+absf(rag),.045),Vector3(rag,-.08,.12),cloth.darkened(.13),Vector3(.14,0,rag*1.5))
		_box(st, Vector3(.15, .16, .035), Vector3(-.1, .025, -.18), cloth, Vector3(0, 0, -.20))
		if armored:
			_box(st, Vector3(.57, .30, .11), Vector3(0, .31, -.19), plate)
			_box(st,Vector3(.20,.29,.045),Vector3(-.18,.29,-.265),Color("6c3f32"),Vector3(0,0,-.2))
			_box(st, Vector3(.49, .08, .045), Vector3(0, .37, -.265), plate.darkened(.38))
			for side: int in [-1, 1]:
				_box(st, Vector3(.25, .21, .39), Vector3(side * .34, .46, 0), plate, Vector3(0, 0, side * .12))
		elif runner:
			for rib in [.15,.23,.31]:
				_box(st,Vector3(.19,.035,.04),Vector3(.04,rib,-.187),skin.darkened(.12),Vector3(0,0,.2))
			_box(st, Vector3(.09, .39, .035), Vector3(-.07, .24, -.168), Color("b08560"), Vector3(0, 0, -.22))
		else:
			_box(st,Vector3(.19,.35,.045),Vector3(-.16,.20,-.18),cloth.darkened(.22),Vector3(0,0,-.12))
			_box(st, Vector3(.18, .23, .035), Vector3(.13, .21, -.169), skin.darkened(.2), Vector3(0, 0, .15))
	elif part == "head":
		# Sunken sockets, exposed jaw and neck create a recognizable infected profile.
		for eye in [-.047,.097]:
			_box(st,Vector3(.052,.052,.037),Vector3(eye,.688,-.245),Color("1e211a"))
		_box(st,Vector3(.15,.065,.09),Vector3(.025,.536,-.157),Color("817e68"))
		_prism(st, .14 if armored else .13, .115, .285, Vector3(.025, .625 if runner else .65, -.105), skin, 6, .9)
		_box(st, Vector3(.21, .045, .045), Vector3(.025, .67, -.23), dark)
		_box(st, Vector3(.13, .045, .035), Vector3(.025, .60, -.238), skin.darkened(.48))
		if armored:
			_prism(st, .185, .155, .15, Vector3(.025, .80, -.09), cloth.darkened(.13), 6, .95)
			_box(st, Vector3(.26, .05, .08), Vector3(.025, .75, -.25), plate)
		elif runner:
			_box(st, Vector3(.22, .08, .21), Vector3(.025, .77, -.09), cloth.darkened(.45))
	elif part.begins_with("leg"):
		var length: float = .59 if armored else .52
		_box(st, Vector3(.21 if armored else .155, length * .55, .20), Vector3(0, -length * .24, .03), cloth.darkened(.20), Vector3(-.16 if runner else 0.08, 0, 0))
		_box(st, Vector3(.15, length * .48, .145), Vector3(0, -length * .68, .055), skin.darkened(.14), Vector3(.15 if runner else -.1, 0, 0))
		_box(st, Vector3(.19, .13, .30), Vector3(0, -length + .015, -.015), dark)
		if armored:
			_box(st, Vector3(.22, .23, .075), Vector3(0, -.32, -.10), plate.darkened(.1))
	elif part.begins_with("arm"):
		var side: float = -1.0 if part == "armL" else 1.0
		var forward: float = -.15 if runner else -.20
		_box(st, Vector3(.16 if armored else .13, .30, .16), Vector3(side * .025, -.13, -.035), cloth, Vector3(-.30, 0, side * .18))
		_box(st, Vector3(.12, .13, .30), Vector3(side * .04, -.25, forward), skin, Vector3(.13, side * -.15, 0))
		_box(st, Vector3(.13, .105, .18), Vector3(side * .025, -.25, forward - .19), skin.lightened(.06))
		if part == "armL" and not armored:
			_box(st,Vector3(.07,.20,.08),Vector3(-.1,-.22,-.1),wound,Vector3(.4,0,.3))
		for finger in [-.04,.02,.07]:
			_box(st,Vector3(.027,.035,.11),Vector3(side*.025+finger,-.27,forward-.31),skin.darkened(.08))
		if armored:
			_box(st, Vector3(.20, .20, .10), Vector3(side * .01, -.11, -.12), plate.darkened(.12))

static func _box(st: SurfaceTool, size: Vector3, pos: Vector3, color: Color, angles: Vector3 = Vector3.ZERO) -> void:
	var h: Vector3 = size * .5
	var basis := Basis.from_euler(angles)
	var faces: Array = [
		[Vector3(-h.x,-h.y,h.z), Vector3(-h.x,h.y,h.z), Vector3(h.x,h.y,h.z), Vector3(h.x,-h.y,h.z)],
		[Vector3(h.x,-h.y,-h.z), Vector3(h.x,h.y,-h.z), Vector3(-h.x,h.y,-h.z), Vector3(-h.x,-h.y,-h.z)],
		[Vector3(h.x,-h.y,h.z), Vector3(h.x,h.y,h.z), Vector3(h.x,h.y,-h.z), Vector3(h.x,-h.y,-h.z)],
		[Vector3(-h.x,-h.y,-h.z), Vector3(-h.x,h.y,-h.z), Vector3(-h.x,h.y,h.z), Vector3(-h.x,-h.y,h.z)],
		[Vector3(-h.x,h.y,h.z), Vector3(-h.x,h.y,-h.z), Vector3(h.x,h.y,-h.z), Vector3(h.x,h.y,h.z)],
		[Vector3(-h.x,-h.y,-h.z), Vector3(-h.x,-h.y,h.z), Vector3(h.x,-h.y,h.z), Vector3(h.x,-h.y,-h.z)]
	]
	for face: Array in faces:
		_quad(st, basis * face[0] + pos, basis * face[1] + pos, basis * face[2] + pos, basis * face[3] + pos, color)

static func _prism(st: SurfaceTool, bottom_radius: float, top_radius: float, height: float, pos: Vector3, color: Color, sides: int = 8, depth: float = 1.0) -> void:
	for i: int in sides:
		var a: float = TAU * i / sides
		var b: float = TAU * (i + 1) / sides
		var lo_a := pos + Vector3(cos(a) * bottom_radius, -height * .5, sin(a) * bottom_radius * depth)
		var lo_b := pos + Vector3(cos(b) * bottom_radius, -height * .5, sin(b) * bottom_radius * depth)
		var hi_a := pos + Vector3(cos(a) * top_radius, height * .5, sin(a) * top_radius * depth)
		var hi_b := pos + Vector3(cos(b) * top_radius, height * .5, sin(b) * top_radius * depth)
		_quad(st, lo_a, lo_b, hi_b, hi_a, color)
		_triangle(st, pos + Vector3(0, height * .5, 0), hi_a, hi_b, color)
		_triangle(st, pos - Vector3(0, height * .5, 0), lo_b, lo_a, color)

static func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, color: Color) -> void:
	_triangle(st, a, b, c, color)
	_triangle(st, a, c, d, color)

static func _triangle(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, color: Color) -> void:
	st.set_color(color)
	st.set_normal((c - a).cross(b - a).normalized())
	st.add_vertex(a)
	st.add_vertex(b)
	st.add_vertex(c)
