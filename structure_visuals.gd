extends RefCounted
## Original RECLAMATION rail-yard models. Single indexed vertex-colored mesh per model.
## Forward is -Z. Geometry only: never mutates gameplay state or collision.
const Shapes = preload("res://actor_visuals.gd")
static var cache: Dictionary = {}
static var material: StandardMaterial3D
const STEEL = Color("505e60")
const DARK = Color("292c28")
const RUST = Color("855338")
const BONE = Color("aaa899")
const AMBER = Color("c49b54")
const GLASS = Color("292f2a")
const CONCRETE = Color("92907a")

static func add_building(parent: Node3D, kind: String) -> bool:
	if kind in ["house","depot","barracks","vehicle_workshop","garden"]:
		parent.add_child((load("res://assets/models/"+kind+".glb") as PackedScene).instantiate())
		return true
	if kind in ["hq", "tower", "factory"]:
		var path: String = {"hq":"refuge_hq", "tower":"scrap_gun_tower", "factory":"ammo_workshop"}[kind]
		var scene := load("res://assets/models/"+path+".glb") as PackedScene
		parent.add_child(scene.instantiate())
		return true
	if kind not in ["hq", "tower", "factory", "relay", "wall", "artillery", "mortar", "yard"]: return false
	_add(parent, "artillery" if kind == "mortar" else ("site_rail_depot" if kind == "yard" else kind))
	return true

static func add_truck(parent: Node3D) -> void:
	_add(parent, "truck")

static func _add(parent: Node3D, kind: String) -> void:
	var instance := MeshInstance3D.new()
	instance.name = "RailYard_" + kind
	instance.mesh = mesh_for(kind)
	parent.add_child(instance)
	if kind == "hq": _letter(parent, "R • 07", Vector3(0, 1.7, 1.97), 0.30)
	if kind == "factory": _letter(parent, "FORGE", Vector3(0, 2.02, 1.51), 0.22)

static func _letter(parent: Node3D, text: String, pos: Vector3, size: float) -> void:
	var label := Label3D.new()
	label.text = text
	label.pixel_size = size / 32.0
	label.font_size = 32
	label.modulate = BONE
	label.outline_size = 0
	label.position = pos
	parent.add_child(label)

static func mesh_for(kind: String) -> ArrayMesh:
	if cache.has(kind): return cache[kind]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	match kind:
		"hq": _hq(st)
		"tower": _tower(st)
		"factory": _factory(st)
		"relay": _relay(st)
		"wall": _wall(st)
		"truck": _truck(st)
		"artillery": _artillery(st)
		_: _site(st,kind.trim_prefix("site_"))
	if material == null:
		material = StandardMaterial3D.new()
		material.vertex_color_use_as_albedo = true
		material.roughness = 0.96
		material.metallic_specular = .12
		material.albedo_color = Color(1.35,1.35,1.35,1.0)
		material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
		material.albedo_texture = load("res://assets/materials/ruined_plaster.png")
		material.uv1_triplanar = true
		material.uv1_world_triplanar = true
		material.uv1_scale = Vector3(.52,.52,.52)
	st.set_material(material)
	st.index()
	var mesh: ArrayMesh = st.commit()
	cache[kind] = mesh
	return mesh

static func b(st: SurfaceTool, size: Vector3, pos: Vector3, color: Color, angles: Vector3 = Vector3.ZERO) -> void:
	Shapes._box(st, size, pos, color, angles)

static func p(st: SurfaceTool, radius: float, top: float, height: float, pos: Vector3, color: Color, sides: int = 8) -> void:
	Shapes._prism(st, radius, top, height, pos, color, sides)

static func beam(st: SurfaceTool, a: Vector3, z: Vector3, radius: float, color: Color, sides: int = 6) -> void:
	var direction := (z-a).normalized()
	var u := direction.cross(Vector3.UP).normalized()
	if u.length_squared() < .1: u = direction.cross(Vector3.RIGHT).normalized()
	var v := direction.cross(u).normalized()
	for i in sides:
		var a0: float = TAU*i/sides
		var a1: float = TAU*(i+1)/sides
		var x := (u*cos(a0)+v*sin(a0))*radius
		var y := (u*cos(a1)+v*sin(a1))*radius
		Shapes._quad(st,a+x,a+y,z+y,z+x,color)
		Shapes._triangle(st,a,a+y,a+x,color.darkened(.15))
		Shapes._triangle(st,z,z+x,z+y,color.lightened(.08))

static func _hq(st: SurfaceTool) -> void:
	# Armored rail-command carriage: exposed bogies, sloping cab, roof radio rack.
	b(st,Vector3(6.3,.25,4.4),Vector3(0,.14,0),CONCRETE.darkened(.25))
	for z in [-1.2,1.2]:
		b(st,Vector3(6.8,.13,.12),Vector3(0,.31,z),STEEL)
	for x in [-2.0,-1.45,1.45,2.0]:
		for z in [-1.42,1.42]: beam(st,Vector3(x,.58,z-.12),Vector3(x,.58,z+.12),.37,DARK,10)
	b(st,Vector3(5.8,.3,3.3),Vector3(0,.72,0),DARK)
	b(st,Vector3(5.2,1.48,3.18),Vector3(0,1.53,0),STEEL)
	b(st,Vector3(5.5,.25,3.48),Vector3(0,2.38,0),DARK)
	# Field repairs: sheet-metal patches, boarded windows and roof salvage.
	for x in [-2.1,.8]:
		b(st,Vector3(.65,.40,.05),Vector3(x,1.07,1.625),RUST,Vector3(0,0,.10))
		for dx in [-.26,.26]: b(st,Vector3(.055,.055,.035),Vector3(x+dx,1.15,1.66),BONE)
	b(st,Vector3(.13,.77,.06),Vector3(-1.7,1.94,1.69),RUST,Vector3(0,0,-.52))
	b(st,Vector3(.13,.77,.06),Vector3(-1.7,1.94,1.70),BONE.darkened(.35),Vector3(0,0,.52))
	for z in [-.94,.94]: b(st,Vector3(5.5,.12,1.90),Vector3(0,2.64,z*.80),STEEL,Vector3(0,0,0) if z==0 else Vector3(-signf(z)*.16,0,0))
	for x in [-2.5,2.5]:
		b(st,Vector3(.10,1.4,3.22),Vector3(x,1.6,0),RUST)
		b(st,Vector3(.14,.12,3.55),Vector3(x,2.38,0),BONE.darkened(.35))
	for x in [-1.7,-.57,.57,1.7]:
		for z in [-1.62,1.62]:
			b(st,Vector3(.88,.59,.05),Vector3(x,1.91,z),DARK)
			b(st,Vector3(.69,.40,.06),Vector3(x,1.94,z*1.01),AMBER.darkened(.24))
			b(st,Vector3(.035,.55,.065),Vector3(x,1.94,z*1.015),STEEL)
			b(st,Vector3(.85,.13,.07),Vector3(x,1.34,z),BONE)
	# Entry side armored steps / porch.
	for i in 3: b(st,Vector3(1.2,.18,.38),Vector3(0,.28+i*.19,1.96-i*.23),STEEL)
	for x in [-.61,.61]: beam(st,Vector3(x,.35,2.15),Vector3(x,1.43,1.6),.04,BONE)
	b(st,Vector3(1.1,.35,.65),Vector3(-1.4,2.94,0),DARK)
	for x in [-1.8,-1.6,-1.4,-1.2,-1.0]: b(st,Vector3(.05,.06,.67),Vector3(x,3.14,0),STEEL)
	beam(st,Vector3(1.6,2.7,.1),Vector3(1.6,4.5,.1),.045,BONE)
	beam(st,Vector3(.8,4,.1),Vector3(2.4,4,.1),.045,STEEL)
	for x in [1.0,1.3,1.6,1.9,2.2]: beam(st,Vector3(x,3.85,-.3),Vector3(x,3.85,.5),.025,BONE)
	b(st,Vector3(.58,.42,.03),Vector3(1.91,4.18,.1),RUST)
	# Rear generator and coiled equipment.
	b(st,Vector3(.65,.8,1.4),Vector3(-3,1.22,0),RUST)
	for z in [-.48,-.24,0,.24,.48]: b(st,Vector3(.03,.52,.075),Vector3(-3.34,1.28,z),DARK)

static func _tower(st: SurfaceTool) -> void:
	b(st,Vector3(2.7,.22,2.7),Vector3(0,.12,0),CONCRETE)
	for x in [-.90,-.30,.30,.90]:
		b(st,Vector3(.58,.28,.38),Vector3(x,.39,1.10),BONE.darkened(.15),Vector3(0,x*.10,0))
		if absf(x)<.5: b(st,Vector3(.56,.26,.37),Vector3(x,.64,1.10),BONE.darkened(.25))
	for x in [-.77,.77]:
		for z in [-.77,.77]:
			b(st,Vector3(.25,.3,.25),Vector3(x,.36,z),RUST)
			beam(st,Vector3(x,.38,z),Vector3(x*.85,2.6,z*.85),.10,STEEL)
	for z in [-.77,.77]:
		beam(st,Vector3(-.77,.5,z),Vector3(.66,2.52,z*.85),.055,RUST)
		beam(st,Vector3(.77,.5,z),Vector3(-.66,2.52,z*.85),.055,RUST)
	b(st,Vector3(2.05,.22,1.9),Vector3(0,2.55,0),STEEL)
	p(st,.42,.42,.18,Vector3(0,2.75,0),DARK)
	b(st,Vector3(1.4,.55,1.05),Vector3(0,3.04,.1),STEEL,Vector3(-.12,0,0))
	for x in [-.82,.82]: b(st,Vector3(.20,.80,1.50),Vector3(x,3,.05),BONE.darkened(.25),Vector3(0,0,x*.12))
	for x in [-.26,.26]:
		beam(st,Vector3(x,3.18,-.2),Vector3(x,3.18,-1.60),.085,DARK)
		beam(st,Vector3(x,3.18,-1.47),Vector3(x,3.18,-1.75),.12,STEEL)
	b(st,Vector3(.4,.35,.5),Vector3(.93,2.98,.2),RUST)
	for i in 7: b(st,Vector3(.50,.06,.06),Vector3(.83,.53+i*.28,.86),BONE)

static func _factory(st: SurfaceTool) -> void:
	b(st,Vector3(3.8,.2,3.6),Vector3(0,.13,0),CONCRETE)
	b(st,Vector3(3.2,1.7,2.8),Vector3(0,1.05,0),RUST)
	for x in [-1.32,1.32]:
		b(st,Vector3(.40,.55,.05),Vector3(x,.60,1.46),STEEL,Vector3(0,0,x*.06))
		b(st,Vector3(.25,.35,.05),Vector3(x,1.41,1.46),BONE.darkened(.40))
	for x in [-1.1,1.1]: b(st,Vector3(1.94,.15,3.15),Vector3(x*.78,2.04,0),STEEL,Vector3(0,0,-signf(x)*.25))
	# Corrugated cladding, open roller door, hazard-striped entrance.
	for x in range(-7,8): b(st,Vector3(.035,1.5,.055),Vector3(x*.20,1.1,1.43),RUST.lightened(.13))
	b(st,Vector3(1.65,1.45,.06),Vector3(0,.98,1.48),DARK)
	b(st,Vector3(1.8,.25,.1),Vector3(0,1.7,1.51),STEEL)
	for x in [-.94,.94]:
		b(st,Vector3(.15,1.7,.16),Vector3(x,1.05,1.53),AMBER)
		for y in [.45,.85,1.25,1.65]: b(st,Vector3(.16,.14,.02),Vector3(x,y,1.62),DARK,Vector3(0,0,.35))
	for x in [-1.08,-.64,.64,1.08]: b(st,Vector3(.24,.15,.4),Vector3(x,.31,1.83),STEEL)
	for x in [-1.1,.95]:
		p(st,.26,.26,2.0,Vector3(x,2.6,-.5),STEEL)
		p(st,.34,.34,.12,Vector3(x,3.57,-.5),DARK)
		p(st,.29,.29,.10,Vector3(x,2.7,-.5),RUST)
	b(st,Vector3(.6,.7,1.0),Vector3(1.87,.66,-.4),STEEL)
	p(st,.30,.30,.83,Vector3(-1.95,.58,.7),RUST)
	p(st,.30,.30,.83,Vector3(-1.95,.58,-.05),AMBER.darkened(.25))
	for y in [.30,.83]:
		p(st,.315,.315,.045,Vector3(-1.95,y,.7),DARK)
		p(st,.315,.315,.045,Vector3(-1.95,y,-.05),DARK)

static func _relay(st: SurfaceTool) -> void:
	b(st,Vector3(2,.25,2),Vector3(0,.15,0),CONCRETE)
	b(st,Vector3(.8,1,.65),Vector3(.35,.7,.35),STEEL)
	for y in [.45,.59,.73,.87]: b(st,Vector3(.48,.045,.03),Vector3(.35,y,.69),DARK)
	for x in [-.45,.45]:
		for z in [-.45,.45]: beam(st,Vector3(x,.3,z),Vector3(x*.27,3.8,z*.27),.055,RUST)
	for y in [1.0,1.8,2.6,3.4]:
		var w: float = .5-y*.09
		beam(st,Vector3(-w,y,-w),Vector3(w,y,w),.035,BONE)
		beam(st,Vector3(-w,y,w),Vector3(w,y,-w),.035,BONE)
	beam(st,Vector3(0,3.4,0),Vector3(0,4.5,0),.035,BONE)
	beam(st,Vector3(-1.1,3.95,0),Vector3(1.1,3.95,0),.05,STEEL)
	for x in [-.95,-.5,0,.5,.95]: beam(st,Vector3(x,3.95,-.48),Vector3(x,3.95,.48),.04,BONE)
	p(st,.105,.105,.13,Vector3(0,4.52,0),AMBER)

static func _wall(st: SurfaceTool) -> void:
	b(st,Vector3(3.15,.30,1.15),Vector3(0,.17,0),CONCRETE.darkened(.18))
	b(st,Vector3(3,1.08,.64),Vector3(0,.83,0),CONCRETE)
	b(st,Vector3(3.12,.18,.77),Vector3(0,1.45,0),CONCRETE.lightened(.09))
	for x in [-1.1,0,1.1]:
		b(st,Vector3(.16,1.25,.80),Vector3(x,.82,0),STEEL)
		b(st,Vector3(.40,.24,.035),Vector3(x,1.11,.425),AMBER)
	for x in [-1.25,-.75,-.25,.25,.75,1.25]:
		beam(st,Vector3(x,1.52,0),Vector3(x+.19,1.91,0),.026,DARK)
	beam(st,Vector3(-1.52,1.75,0),Vector3(1.52,1.75,0),.02,RUST)

static func _truck(st: SurfaceTool) -> void:
	b(st,Vector3(1.5,.25,3.1),Vector3(0,.55,0),DARK)
	for x in [-.78,.78]:
		for z in [-1.0,1.0]:
			beam(st,Vector3(x-.14,.42,z),Vector3(x+.14,.42,z),.39,DARK,10)
			beam(st,Vector3(x-.15,.42,z),Vector3(x+.15,.42,z),.18,STEEL,8)
	b(st,Vector3(1.45,.8,1.05),Vector3(0,1.04,-.99),STEEL)
	b(st,Vector3(1.51,.14,1.18),Vector3(0,1.53,-.93),BONE.darkened(.28))
	b(st,Vector3(1.24,.36,.04),Vector3(0,1.26,-1.54),GLASS)
	b(st,Vector3(.065,.37,.07),Vector3(0,1.27,-1.56),BONE)
	b(st,Vector3(1.4,.45,.36),Vector3(0,.83,-1.58),RUST)
	for x in [-.50,.50]: b(st,Vector3(.23,.18,.04),Vector3(x,.96,-1.78),AMBER)
	for x in [-.30,-.15,0,.15,.30]: b(st,Vector3(.055,.27,.025),Vector3(x,.79,-1.78),DARK)
	b(st,Vector3(1.7,.15,.2),Vector3(0,.59,-1.8),STEEL)
	b(st,Vector3(1.48,.15,1.65),Vector3(0,.75,.69),RUST)
	for x in [-.75,.75]:
		b(st,Vector3(.10,.52,1.7),Vector3(x,1.02,.69),STEEL)
		for z in [.0,.6,1.4]: b(st,Vector3(.12,.65,.09),Vector3(x,1.10,z),BONE.darkened(.35))
	b(st,Vector3(1.5,.5,.09),Vector3(0,1.03,1.53),STEEL)
	for x in [-.35,.35]: b(st,Vector3(.55,.5,.55),Vector3(x,1.07,.8),BONE.darkened(.35))
	beam(st,Vector3(.65,1,-.2),Vector3(.65,2,-.2),.06,DARK)

static func _artillery(st: SurfaceTool) -> void:
	b(st,Vector3(3.2,.25,3.2),Vector3(0,.18,0),CONCRETE)
	for x in [-1,1]:
		beam(st,Vector3(x,.5,.8),Vector3(x,.5,1.8),.18,STEEL)
		beam(st,Vector3(x-.2,.5,0),Vector3(x+.2,.5,0),.5,DARK,10)
	p(st,.7,.6,.7,Vector3(0,.73,0),STEEL)
	b(st,Vector3(1.65,.55,1.3),Vector3(0,1.15,.15),RUST)
	beam(st,Vector3(0,1.25,.4),Vector3(0,2.12,-2.15),.20,STEEL,10)
	beam(st,Vector3(0,2.03,-1.88),Vector3(0,2.21,-2.40),.28,DARK,10)
	for x in [-.86,.86]: b(st,Vector3(.18,1.05,1.1),Vector3(x,1.43,-.1),BONE.darkened(.20),Vector3(-.20,0,0))
	for x in [-1.1,-.82,-.54]: beam(st,Vector3(x,.35,1.1),Vector3(x,.35,1.85),.10,AMBER)

static func add_vehicle(parent: Node3D, kind: String = "truck") -> void:
	var path:String="evacuation_carrier" if kind=="convoy" else "supply_truck"
	var scene:=load("res://assets/models/"+path+".glb") as PackedScene
	parent.add_child(scene.instantiate())

static func add_site(parent: Node3D, kind: String) -> bool:
	if kind not in ["generator","pump","rail_depot","substation"]: return false
	_add(parent, "site_"+kind)
	return true

static func _site(st: SurfaceTool, kind: String) -> void:
	b(st,Vector3(4.2,.25,3.5),Vector3(0,.14,0),CONCRETE)
	if kind == "generator" or kind == "substation":
		b(st,Vector3(2.8,1.5,1.7),Vector3(0,1,0),STEEL)
		for x in [-1.16,-.88,-.6,-.32,-.04,.24,.52,.8,1.08]:
			b(st,Vector3(.10,1.1,.10),Vector3(x,1,.9),DARK)
		for x in [-.9,0,.9]:
			p(st,.17,.17,.5,Vector3(x,2.02,0),BONE)
			for y in [1.82,1.97,2.12,2.27]: p(st,.26,.26,.055,Vector3(x,y,0),RUST)
		beam(st,Vector3(-1.7,.4,-.6),Vector3(-1.7,2.6,-.6),.13,DARK)
		beam(st,Vector3(-1.7,2.6,-.6),Vector3(-.9,2.6,-.6),.13,DARK)
		b(st,Vector3(.45,.4,.07),Vector3(.9,1.43,.96),AMBER)
	elif kind == "pump":
		for x in [-.8,.8]:
			p(st,.7,.65,1.6,Vector3(x,1.05,0),STEEL,12)
			p(st,.73,.73,.12,Vector3(x,1.85,0),RUST,12)
			beam(st,Vector3(x,1.3,.6),Vector3(x,1.3,1.35),.23,RUST)
			beam(st,Vector3(x,1.3,1.35),Vector3(x,.25,1.35),.23,RUST)
		beam(st,Vector3(-.8,1.15,-.55),Vector3(.8,1.15,-.55),.23,STEEL)
	else:
		for x in [-1.65,1.65]:
			for z in [-1.1,1.1]: beam(st,Vector3(x,.25,z),Vector3(x,3,z),.13,STEEL)
		b(st,Vector3(3.8,.28,2.8),Vector3(0,3.02,0),RUST)
		beam(st,Vector3(0,2.9,0),Vector3(0,1.75,0),.055,DARK)
		b(st,Vector3(.6,.32,.6),Vector3(0,1.7,0),AMBER)
		for x in [-.8,.5]: b(st,Vector3(1,1,1.1),Vector3(x,.76,0),BONE.darkened(.25))
