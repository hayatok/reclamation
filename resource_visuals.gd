extends RefCounted
## Original source-built bulk supplies. Cosmetic meshes only; no gameplay state.
## All kinds retain the 1.4 m resource footprint and clear the 2 m stock label.
## One cached, indexed, opaque vertex-colour surface per kind. No random calls.
const Shape = preload("res://actor_visuals.gd")
static var meshes: Dictionary = {}

static func add_resource(parent: Node3D, kind: String) -> void:
	if not meshes.has(kind):
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		if kind == "food":
			_food(st)
		elif kind == "parts":
			_parts(st)
		else:
			_salvage(st)
		var mat := StandardMaterial3D.new()
		mat.vertex_color_use_as_albedo = true
		mat.roughness = .96
		mat.metallic = 0.0
		st.set_material(mat)
		st.index()
		meshes[kind] = st.commit()
	var n := MeshInstance3D.new()
	n.name = "BulkResource"
	n.mesh = meshes[kind]
	parent.add_child(n)

static func _food(st: SurfaceTool) -> void:
	var wood := Color("655c49")
	var sack := Color("b6a783")
	var canvas := Color("677057")
	# A broad battered pallet grounds the whole provision stack.
	for x: float in [-.70, .70]:
		Shape._box(st, Vector3(.23, .12, 1.58), Vector3(x, .06, 0), wood.darkened(.18))
	for z: float in [-.65, -.32, .01, .34, .67]:
		Shape._box(st, Vector3(2.05, .09, .27), Vector3(0, .165, z), wood)
	# Closed cases have generous plank seams and banding; no tiny food tokens.
	_case(st, Vector3(-.48, .48, .35), Vector3(.91, .54, .83), wood)
	_case(st, Vector3(.50, .46, .30), Vector3(.89, .50, .83), wood.lightened(.09))
	_case(st, Vector3(-.45, 1.00, .33), Vector3(.81, .50, .76), wood.lightened(.13))
	# Soft, lumpy sacks form a recognisable curved silhouette above the cases.
	_sack(st, Vector3(.49, .72, .30), Vector3(.78, .51, .70), sack, -.10)
	_sack(st, Vector3(-.48, .21, -.48), Vector3(.94, .55, .68), sack.darkened(.09), .08)
	_sack(st, Vector3(.46, .21, -.48), Vector3(.92, .57, .68), sack, -.10)
	_sack(st, Vector3(-.40, .72, -.42), Vector3(.88, .52, .73), sack.lightened(.06), -.08)
	_sack(st, Vector3(.48, .74, -.41), Vector3(.79, .51, .73), sack.darkened(.03), .12)
	_sack(st, Vector3(.07, 1.19, -.26), Vector3(.93, .44, .75), sack, -.05)
	# A weighty half-cover: a raised ridge, sagging sides and a torn free edge.
	# The near/right provisions stay exposed, so this does not become a tent.
	var a := Vector3(-1.00, 1.00, -.74)
	var b := Vector3(-.57, 1.46, -.62)
	var c := Vector3(.02, 1.69, -.39)
	var d := Vector3(.62, 1.40, -.51)
	var e := Vector3(.94, .95, -.66)
	var f := Vector3(-1.04, .83, .13)
	var g := Vector3(-.60, 1.42, .06)
	var h := Vector3(.03, 1.64, .06)
	var i := Vector3(.59, 1.36, .05)
	var j := Vector3(.90, .93, -.02)
	_sheet_quad(st, a, b, g, f, canvas.darkened(.10))
	_sheet_quad(st, b, c, h, g, canvas.lightened(.10))
	_sheet_quad(st, c, d, i, h, canvas)
	_sheet_quad(st, d, e, j, i, canvas.darkened(.08))
	_sheet_quad(st, a, Vector3(-.95, .28, -.77), Vector3(-.51, .39, -.79), b, canvas.darkened(.20))
	_sheet_quad(st, b, Vector3(-.51, .39, -.79), Vector3(.25, .40, -.77), c, canvas.darkened(.12))
	_sheet_quad(st, c, Vector3(.25, .40, -.77), Vector3(.91, .33, -.71), e, canvas.darkened(.17))
	_sheet_quad(st, f, g, Vector3(-.59, 1.14, .31), Vector3(-1.06, .62, .27), canvas.darkened(.12))
	_sheet_tri(st, g, h, Vector3(-.13, 1.31, .30), canvas.lightened(.02))
	_sheet_tri(st, h, i, Vector3(.35, 1.18, .28), canvas.darkened(.04))
	# Two broad sewn patches and one heavy tie keep the cover weathered and plain.
	_sheet_quad(st, Vector3(-.54, 1.468, -.55), Vector3(-.34, 1.544, -.48), Vector3(-.34, 1.521, -.17), Vector3(-.54, 1.447, -.17), canvas.darkened(.15))
	Shape._box(st, Vector3(.052, .71, .058), Vector3(-.99, .63, -.70), Color("9f9270"), Vector3(0, 0, -.10))

static func _case(st: SurfaceTool, pos: Vector3, size: Vector3, color: Color) -> void:
	Shape._box(st, size, pos, color)
	# Face-height dark seams remain legible when the object is only a few pixels tall.
	for x: float in [-.34, .34]:
		Shape._box(st, Vector3(.09, size.y + .025, size.z + .025), pos + Vector3(x * size.x, 0, 0), color.darkened(.23))
	Shape._box(st, Vector3(size.x - .17, .055, .027), pos + Vector3(0, .015, size.z * .5 + .009), color.darkened(.30))
	Shape._box(st, Vector3(.25, .17, .030), pos + Vector3(.12, .02, size.z * .5 + .027), Color("afa487"))

static func _sack(st: SurfaceTool, base: Vector3, size: Vector3, color: Color, yaw: float) -> void:
	var basis := Basis(Vector3.UP, yaw)
	var rings: Array[Vector3] = []
	# Eight-sided bulging body, slumped shoulders and pinched top. The base is flat.
	var levels: Array[Vector2] = [Vector2(0, .68), Vector2(.18, 1.00), Vector2(.69, .93), Vector2(.91, .58)]
	for level: Vector2 in levels:
		for side: int in 8:
			var angle: float = TAU * float(side) / 8.0 + PI / 8.0
			var local := Vector3(cos(angle) * size.x * .5 * level.y, size.y * level.x, sin(angle) * size.z * .5 * level.y)
			local.y += sin(angle * 2.0) * size.y * .035 if level.x > .0 else 0.0
			rings.append(base + basis * local)
	for row: int in 3:
		for side: int in 8:
			var next: int = (side + 1) % 8
			var shade: Color = color.darkened(.07 if side % 3 == 0 else .0)
			Shape._quad(st, rings[row * 8 + side], rings[row * 8 + next], rings[(row + 1) * 8 + next], rings[(row + 1) * 8 + side], shade)
	for side: int in 8:
		var next: int = (side + 1) % 8
		Shape._triangle(st, base, rings[next], rings[side], color.darkened(.12))
		Shape._triangle(st, base + Vector3(.025, size.y, -.014), rings[24 + side], rings[24 + next], color.lightened(.04))
	# The rolled seam is deliberately chunky, part of the sack rather than garnish.
	Shape._box(st, Vector3(size.x * .39, .048, .085), base + Vector3(.015, size.y - .006, 0), color.darkened(.18), Vector3(0, yaw, .025))

static func _salvage(st: SurfaceTool) -> void:
	var steel := Color("69716c")
	var rust := Color("825e49")
	# Long I-sections and a transverse sleeper make one heavy structural bundle.
	for x: float in [-.69, .69]:
		Shape._box(st, Vector3(.23, .15, 1.44), Vector3(x, .075, 0), Color("555248"))
	for z: float in [-.43, 0, .43]:
		_beam(st, Vector3(0, .34, z), 2.28, .30, .32, -.10, steel if z == 0 else rust)
	for z: float in [-.25, .25]:
		_beam(st, Vector3(-.025, .69, z), 2.17, .31, .32, .10, steel.darkened(.05))
	_beam(st, Vector3(.02, 1.025, -.03), 2.30, .28, .30, -.12, rust.lightened(.10))
	# Broad iron straps are quieter than the beam ends but read as recovered stock.
	for x: float in [-.67, .67]:
		Shape._box(st, Vector3(.11, .045, 1.22), Vector3(x, 1.19, 0), Color("484e49"))
		Shape._box(st, Vector3(.11, .99, .045), Vector3(x, .675, .60), Color("4b504a"))
		Shape._box(st, Vector3(.11, .73, .045), Vector3(x, .53, -.61), Color("4b504a"))
	# A folded, jagged sheet leans against the back: broad facets, missing corner.
	# Corrugation is modelled in five large folds, not a noisy texture.
	var lower: Array[Vector3] = [Vector3(-.74,.28,-.59), Vector3(-.42,.27,-.65), Vector3(-.12,.29,-.61), Vector3(.18,.31,-.69), Vector3(.49,.34,-.61), Vector3(.73,.36,-.67)]
	var upper: Array[Vector3] = [Vector3(-.65,1.42,-.51), Vector3(-.38,1.63,-.59), Vector3(-.10,1.57,-.55), Vector3(.19,1.70,-.63), Vector3(.48,1.45,-.56), Vector3(.65,1.17,-.60)]
	for fold: int in 5:
		_sheet_quad(st, lower[fold], upper[fold], upper[fold + 1], lower[fold + 1], Color("747970") if fold % 2 == 0 else Color("5b645e"))
	_sheet_tri(st, upper[1], Vector3(-.35,1.29,-.70), upper[2], rust.darkened(.05))
	# A fallen off-cut and a flange-shaped scrap break the ordered bundle edge.
	_beam(st, Vector3(.06, .22, .84), 1.34, .19, .20, .13, rust.darkened(.10))
	_sheet_quad(st, Vector3(.72,.17,.59), Vector3(1.13,.13,.47), Vector3(1.12,.39,.11), Vector3(.76,.45,.27), steel.darkened(.15))

static func _beam(st: SurfaceTool, pos: Vector3, length: float, width: float, height: float, yaw: float, color: Color) -> void:
	var basis := Basis(Vector3.UP, yaw)
	var angles := Vector3(0, yaw, 0)
	for y: float in [-height * .5 + .04, height * .5 - .04]:
		Shape._box(st, Vector3(length, .08, width), pos + Vector3(0, y, 0), color, angles)
	Shape._box(st, Vector3(length, height - .10, .068), pos, color.darkened(.17), angles)
	# Dark oxidised cut faces emphasise the genuine I profile at both exposed ends.
	for end: float in [-1.0, 1.0]:
		var cut: Vector3 = pos + basis * Vector3(end * (length * .5 + .004), 0, 0)
		Shape._box(st, Vector3(.008, height - .10, .075), cut, Color("9b8970"), angles)

static func _parts(st: SurfaceTool) -> void:
	var metal := Color("596c6a")
	var dark := Color("343f3e")
	var iron := Color("8a9080")
	var copper := Color("9c6b4c")
	# The stripped motor sits on two skids and a thick broken machine bed.
	for z: float in [-.55, .55]:
		Shape._box(st, Vector3(2.01, .18, .21), Vector3(0, .09, z), dark)
	Shape._box(st, Vector3(1.82, .15, 1.32), Vector3(0, .255, 0), metal.darkened(.15))
	Shape._box(st, Vector3(1.16, .91, .79), Vector3(-.31, .785, -.24), metal)
	Shape._box(st, Vector3(1.25, .16, .84), Vector3(-.31, .42, -.24), metal.darkened(.14))
	Shape._box(st, Vector3(.98, .14, .75), Vector3(-.31, 1.27, -.24), iron.darkened(.16))
	# Empty dark top access well and displaced lid signal dismantled machinery.
	Shape._box(st, Vector3(.58, .025, .49), Vector3(-.30, 1.351, -.23), dark)
	Shape._box(st, Vector3(.50, .075, .62), Vector3(-.61, 1.43, -.32), metal.lightened(.08), Vector3(0, .13, -.34))
	for x: float in [-.70, -.43, -.16]:
		Shape._box(st, Vector3(.085, .51, .06), Vector3(x, .84, -.667), metal.darkened(.24))
	# Large vertical gear: real toothed outer silhouette, annulus and open hub gaps.
	var wheel := Vector3(-.06, .91, .43)
	_gear(st, wheel, .66, .25, .18, iron)
	for spoke: int in 5:
		var angle: float = TAU * float(spoke) / 5.0
		Shape._box(st, Vector3(.11, .56, .115), wheel + Vector3(-sin(angle) * .23, cos(angle) * .23, 0), iron.darkened(.18), Vector3(0, 0, angle))
	_cylinder_z(st, wheel + Vector3(0, 0, .025), .17, .28, dark, 10)
	_cylinder_z(st, wheel + Vector3(0, 0, .18), .093, .11, iron.darkened(.09), 8)
	# An exposed copper motor winding crosses the gearbox axis on its right.
	# The dark core, heavy end flanges and broad rings read as one coil assembly.
	var coil := Vector3(.67, .72, -.28)
	_cylinder_x(st, coil, .285, .67, dark, 12)
	for x: float in [-.31, .31]:
		_cylinder_x(st, coil + Vector3(x, 0, 0), .35, .085, iron.darkened(.19), 12)
	for turn: int in 6:
		_ring_x(st, coil + Vector3(-.245 + float(turn) * .098, 0, 0), .309, .224, .079, copper.lightened(.05 if turn % 2 == 0 else .0), 12)
	# One tall open pipe and a detached housing add asymmetry without loose tokens.
	Shape._prism(st, .105, .105, .44, Vector3(-.74, 1.42, -.42), dark, 8)
	Shape._prism(st, .146, .146, .08, Vector3(-.74, 1.65, -.42), metal.lightened(.06), 8)
	Shape._prism(st, .093, .093, .012, Vector3(-.74, 1.696, -.42), Color("252e2c"), 8)
	Shape._box(st, Vector3(.54, .23, .49), Vector3(.66, .45, .59), metal.darkened(.07), Vector3(0, -.22, 0))
	Shape._box(st, Vector3(.28, .03, .27), Vector3(.66, .574, .59), dark, Vector3(0, -.22, 0))

static func _gear(st: SurfaceTool, center: Vector3, radius: float, bore: float, depth: float, color: Color) -> void:
	var steps: int = 48
	for step: int in steps:
		var next: int = (step + 1) % steps
		var angle_a: float = TAU * float(step) / float(steps)
		var angle_b: float = TAU * float(next) / float(steps)
		var radius_a: float = radius if step % 4 in [1, 2] else radius * .86
		var radius_b: float = radius if next % 4 in [1, 2] else radius * .86
		var a := Vector3(cos(angle_a) * radius_a, sin(angle_a) * radius_a, -depth * .5)
		var b := Vector3(cos(angle_b) * radius_b, sin(angle_b) * radius_b, -depth * .5)
		var c := Vector3(cos(angle_a) * bore, sin(angle_a) * bore, -depth * .5)
		var d := Vector3(cos(angle_b) * bore, sin(angle_b) * bore, -depth * .5)
		var dz := Vector3(0, 0, depth)
		Shape._quad(st, center+c+dz, center+d+dz, center+b+dz, center+a+dz, color)
		Shape._quad(st, center+d, center+c, center+a, center+b, color.darkened(.18))
		Shape._quad(st, center+a+dz, center+b+dz, center+b, center+a, color.darkened(.22))
		Shape._quad(st, center+d+dz, center+c+dz, center+c, center+d, color.darkened(.28))

static func _cylinder_z(st: SurfaceTool, center: Vector3, radius: float, depth: float, color: Color, sides: int) -> void:
	for side: int in sides:
		var a: float = TAU * float(side) / float(sides)
		var b: float = TAU * float(side + 1) / float(sides)
		var pa := Vector3(cos(a) * radius, sin(a) * radius, -depth * .5)
		var pb := Vector3(cos(b) * radius, sin(b) * radius, -depth * .5)
		var dz := Vector3(0, 0, depth)
		Shape._quad(st, center+pa+dz, center+pb+dz, center+pb, center+pa, color)
		Shape._triangle(st, center+Vector3(0,0,depth*.5), center+pb+dz, center+pa+dz, color)
		Shape._triangle(st, center-Vector3(0,0,depth*.5), center+pa, center+pb, color.darkened(.14))

static func _cylinder_x(st: SurfaceTool, center: Vector3, radius: float, depth: float, color: Color, sides: int) -> void:
	_ring_x(st, center, radius, 0.0, depth, color, sides)

static func _ring_x(st: SurfaceTool, center: Vector3, radius: float, bore: float, depth: float, color: Color, sides: int) -> void:
	for side: int in sides:
		var a: float = TAU * float(side) / float(sides)
		var b: float = TAU * float(side + 1) / float(sides)
		var pa := Vector3(-depth*.5, cos(a)*radius, sin(a)*radius)
		var pb := Vector3(-depth*.5, cos(b)*radius, sin(b)*radius)
		var ia := Vector3(-depth*.5, cos(a)*bore, sin(a)*bore)
		var ib := Vector3(-depth*.5, cos(b)*bore, sin(b)*bore)
		var dx := Vector3(depth, 0, 0)
		Shape._quad(st, center+pa+dx, center+pb+dx, center+pb, center+pa, color.darkened(.07))
		if bore > 0.0:
			Shape._quad(st, center+ib, center+ib+dx, center+ia+dx, center+ia, color.darkened(.21))
			Shape._quad(st, center+pb, center+ib, center+ia, center+pa, color.darkened(.10))
			Shape._quad(st, center+pa+dx, center+ia+dx, center+ib+dx, center+pb+dx, color)
		else:
			Shape._triangle(st, center+Vector3(-depth*.5,0,0), center+pa, center+pb, color.darkened(.10))
			Shape._triangle(st, center+Vector3(depth*.5,0,0), center+pb+dx, center+pa+dx, color)

static func _sheet_quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, color: Color) -> void:
	_sheet_tri(st, a, b, c, color)
	_sheet_tri(st, a, c, d, color)

static func _sheet_tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, color: Color) -> void:
	Shape._triangle(st, a, b, c, color)
	Shape._triangle(st, c, b, a, color.darkened(.12))
