extends RefCounted
## Original low-poly actor silhouettes. Forward is -Z; actor roots are never moved.
## Each actor has six single-surface meshes, shared across instances of its kind.
## Matte rail-command palette: slate/bone friendlies, workwear amber, ash/rust infected.
## phase is a gait angle in radians (about elapsed * 8 for human walking).

static var _meshes: Dictionary = {}
static var _material: StandardMaterial3D

static func add_human(parent: Node3D, kind: String) -> void:
	_add(parent, "guard" if kind == "guard" else "worker")

static func add_enemy(parent: Node3D, fast: bool, armored: bool = false) -> void:
	_add(parent, "armored" if armored else ("runner" if fast else "infected"))

## Shared source geometry for the horde MultiMesh renderer.
static func mesh_for(kind: String, part: String) -> ArrayMesh:
	return _mesh(kind, part)

static func animate(parent: Node3D, phase: float, moving: bool) -> void:
	if not parent.has_meta(&"actor_visuals"):
		return
	var visual: Node3D = parent.get_meta(&"actor_visuals")
	if not is_instance_valid(visual):
		return
	var kind: String = visual.get_meta(&"kind")
	var gait: float = sin(phase)
	var amplitude: float = (0.57 if kind == "runner" else 0.37) if moving else 0.0
	var left: Node3D = visual.get_meta(&"leg_l")
	var right: Node3D = visual.get_meta(&"leg_r")
	left.rotation.x = gait * amplitude
	right.rotation.x = -gait * amplitude
	var body: Node3D = visual.get_meta(&"body")
	var base_height: float = visual.get_meta(&"hip")
	var lean: float = visual.get_meta(&"lean")
	body.position.y = base_height + (absf(cos(phase)) * 0.025 if moving else 0.0)
	body.rotation.x = lean
	body.rotation.z = gait * (0.028 if moving else 0.0)
	var arm_l: Node3D = visual.get_meta(&"arm_l")
	var arm_r: Node3D = visual.get_meta(&"arm_r")
	var arm_swing: float = 0.48 if kind == "runner" else (0.22 if kind == "worker" else 0.09)
	arm_l.rotation.x = -gait * arm_swing if moving else 0.0
	arm_r.rotation.x = gait * arm_swing if moving else 0.0

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
	return _material

static func _mesh(kind: String, part: String) -> ArrayMesh:
	var key: String = kind + ":" + part
	if _meshes.has(key):
		return _meshes[key]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	if kind == "guard" or kind == "worker":
		_human_geometry(st, kind, part)
	else:
		_enemy_geometry(st, kind, part)
	st.set_material(_shared_material())
	var mesh: ArrayMesh = st.commit()
	_meshes[key] = mesh
	return mesh

static func _human_geometry(st: SurfaceTool, kind: String, part: String) -> void:
	var guard: bool = kind == "guard"
	var uniform := Color("42545f") if guard else Color("85623e")
	var accent := Color("6b7e8b") if guard else Color("b78d50")
	var bone := Color("d4c9aa")
	var ochre := Color("b69a61")
	var dark := Color("292e31")
	var skin := Color("b9a489")
	var steel := Color("8c918d")
	if part == "torso":
		_box(st, Vector3(.48, .5, .29), Vector3(0, .26, 0), uniform)
		_box(st, Vector3(.51, .32, .09), Vector3(0, .30, -.18), accent)
		_box(st, Vector3(.45, .13, .3), Vector3(0, .025, 0), dark)
		# Broad shoulder caps and a radio/tool backpack read from the RTS camera.
		for side: int in [-1, 1]:
			_box(st, Vector3(.20, .17, .34), Vector3(side * .28, .45, 0), bone if guard and side < 0 else accent.darkened(.13))
			_box(st, Vector3(.12, .14, .065), Vector3(side * .135, .20, -.24), dark)
		_box(st, Vector3(.34, .40, .19), Vector3(0, .28, .22), dark)
		_box(st, Vector3(.25, .12, .035), Vector3(0, .41, .327), ochre if guard else accent)
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
			_prism(st, .20, .15, .16, Vector3(0, .79, -.005), uniform, 8, .9)
			# Bone crown stripe and shoulder panel identify the squad from above.
			_box(st, Vector3(.11, .012, .225), Vector3(0, .872, -.005), bone)
			_box(st, Vector3(.32, .075, .055), Vector3(0, .71, -.143), dark)
			_box(st, Vector3(.19, .035, .06), Vector3(0, .724, -.17), Color("8d9b9f"))
			for side: int in [-1, 1]:
				_box(st, Vector3(.075, .15, .13), Vector3(side * .16, .67, .012), uniform)
		else:
			_prism(st, .17, .12, .135, Vector3(0, .79, -.005), accent, 8, 1.0)
			_prism(st, .23, .23, .04, Vector3(0, .724, -.025), accent, 8, .89)
			_box(st, Vector3(.045, .025, .25), Vector3(0, .86, -.02), bone)
			_box(st, Vector3(.22, .05, .035), Vector3(0, .675, -.137), dark)
	elif part.begins_with("leg"):
		_box(st, Vector3(.18, .26, .20), Vector3(0, -.12, .0), uniform.darkened(.24))
		_box(st, Vector3(.16, .25, .17), Vector3(0, -.35, .015), dark)
		_box(st, Vector3(.19, .15, .31), Vector3(0, -.493, -.055), dark.darkened(.14))
		_box(st, Vector3(.19, .14, .07), Vector3(0, -.29, -.115), accent.darkened(.22))
	elif part.begins_with("arm"):
		var side: float = -1.0 if part == "armL" else 1.0
		_box(st, Vector3(.15, .26, .16), Vector3(side * .025, -.14, -.015), uniform, Vector3(-.18, 0, side * .12))
		_box(st, Vector3(.13, .17, .25), Vector3(0, -.27, -.13), dark, Vector3(.35, 0, 0))
		_box(st, Vector3(.13, .12, .13), Vector3(0, -.24, -.265), skin)
		if part == "armR":
			if guard:
				_box(st, Vector3(.13, .14, .53), Vector3(-.035, -.18, -.37), dark)
				_box(st, Vector3(.065, .065, .28), Vector3(-.035, -.175, -.745), steel)
				_box(st, Vector3(.09, .16, .12), Vector3(-.035, -.30, -.36), dark)
				_box(st, Vector3(.06, .06, .10), Vector3(-.035, -.08, -.37), steel)
			else:
				_box(st, Vector3(.065, .38, .065), Vector3(0, -.19, -.30), steel)
				_box(st, Vector3(.20, .10, .09), Vector3(0, .015, -.30), dark)

static func _enemy_geometry(st: SurfaceTool, kind: String, part: String) -> void:
	var runner: bool = kind == "runner"
	var armored: bool = kind == "armored"
	var cloth := Color("934c3b") if runner else (Color("747871") if armored else Color("756f61"))
	var skin := Color("ada895") if not runner else Color("a48f7d")
	var dark := Color("3f3b35")
	var plate := Color("a58b56")
	if part == "torso":
		_box(st, Vector3(.38 if runner else (.66 if armored else .48), .52, .30), Vector3(0, .25, 0), cloth)
		# The jutting upper back and ragged shirt make a hunched outline.
		_box(st, Vector3(.40 if runner else .54, .24, .31), Vector3(0, .42, .08), cloth.lightened(.07), Vector3(.13, 0, 0))
		_box(st, Vector3(.38, .13, .29), Vector3(.015, -.015, .005), dark)
		_box(st, Vector3(.15, .16, .035), Vector3(-.1, .025, -.18), cloth, Vector3(0, 0, -.20))
		if armored:
			_box(st, Vector3(.57, .30, .11), Vector3(0, .31, -.19), plate)
			_box(st, Vector3(.49, .08, .045), Vector3(0, .37, -.265), plate.darkened(.38))
			for side: int in [-1, 1]:
				_box(st, Vector3(.25, .21, .39), Vector3(side * .34, .46, 0), plate, Vector3(0, 0, side * .12))
		elif runner:
			_box(st, Vector3(.09, .39, .035), Vector3(-.07, .24, -.168), Color("b08560"), Vector3(0, 0, -.22))
		else:
			_box(st, Vector3(.18, .23, .035), Vector3(.13, .21, -.169), skin.darkened(.2), Vector3(0, 0, .15))
	elif part == "head":
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
