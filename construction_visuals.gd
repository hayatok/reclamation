extends RefCounted
## Original, deterministic construction art. Final meshes stay unchanged.
## One shared indexed surface per kind/stage; only the active stage is submitted.
## Gameplay owns the parent and progress. This helper owns only a visual sibling.
const Shapes = preload("res://actor_visuals.gd")
const META: StringName = &"construction_visuals"
const FOUNDATION_END: float = 0.24
const FRAME_END: float = 0.68
const TIMBER = Color("9b7650")
const CUT_END = Color("c6a777")
const STEEL = Color("536164")
const RUST = Color("89563b")
const CLOTH = Color("c2aa79")
const SAGE = Color("687b6a")
const STONE = Color("99907b")
const EARTH = Color("584e3d")
const DARK = Color("333936")
const AMBER = Color("d9aa50")
static var _cache: Dictionary = {}
static var _material: StandardMaterial3D

class ConstructionState extends Node3D:
	var current_stage: int = -1
	var stage_changes: int = 0
	var kind: String
	var finished_visual: Node3D
	var stage_visual: MeshInstance3D
	var stage_meshes: Array[ArrayMesh] = []
	var _final_was_visible: bool = true

	func set_progress(progress: float) -> void:
		if not is_instance_valid(finished_visual):
			if is_instance_valid(stage_visual): stage_visual.visible = false
			return
		var p: float = clampf(progress, 0.0, 1.0) if is_finite(progress) else 0.0
		var next: int = 3 if kind == "hq" or p >= 1.0 else (0 if p < 0.24 else (1 if p < 0.68 else 2))
		if next == current_stage: return
		current_stage = next
		stage_changes += 1
		finished_visual.visible = next == 3 and _final_was_visible
		if is_instance_valid(stage_visual):
			stage_visual.visible = next < 3
			stage_visual.mesh = stage_meshes[next] if next < 3 else null

	## Optional explicit removal. Normal building deletion frees this child safely.
	func dispose() -> void:
		if is_instance_valid(finished_visual): finished_visual.visible = _final_was_visible
		var owner_node := get_parent()
		if is_instance_valid(owner_node) and owner_node.has_meta(&"construction_visuals") and owner_node.get_meta(&"construction_visuals") == self:
			owner_node.remove_meta(&"construction_visuals")
		if is_instance_valid(stage_visual): stage_visual.visible = false
		queue_free()

## finished_visual is a dedicated, already decorated Node3D child of parent.
## It must not be parent itself or include gameplay children/rings/health labels.
## Call set_progress(saved_built) immediately after setup when restoring a save.
static func setup(parent: Node3D, kind: String, radius: float, finished_visual: Node3D) -> ConstructionState:
	if not is_instance_valid(parent) or not is_instance_valid(finished_visual) or parent == finished_visual:
		push_error("ConstructionVisuals requires a separate valid finished visual child")
		return null
	var previous: Variant = parent.get_meta(META) if parent.has_meta(META) else null
	if is_instance_valid(previous) and previous is ConstructionState:
		if previous.kind == kind and previous.finished_visual == finished_visual and not previous.is_queued_for_deletion(): return previous
		previous.dispose()
	var state := ConstructionState.new()
	state.name = "ConstructionVisuals"
	state.kind = kind
	state.finished_visual = finished_visual
	state._final_was_visible = finished_visual.visible
	parent.add_child(state)
	parent.set_meta(META, state)
	if kind != "hq":
		state.stage_visual = MeshInstance3D.new()
		state.stage_visual.name = "ActiveConstructionStage"
		state.add_child(state.stage_visual)
		# Author at shipped art dimensions. Radius stays cosmetic and never alters gameplay.
		var safe_radius: float = clampf(radius, .5, 5.0) if is_finite(radius) else 1.5
		for stage in 3: state.stage_meshes.append(_mesh_for(kind, stage, safe_radius))
	state.set_progress(1.0 if kind == "hq" else 0.0)
	return state

static func _mesh_for(raw_kind: String, stage: int, _radius: float) -> ArrayMesh:
	var kind: String = "vehicle_workshop" if raw_kind == "workshop" else ("mortar" if raw_kind == "artillery" else raw_kind)
	var key := "%s:%d" % [kind, stage]
	if _cache.has(key): return _cache[key]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	match kind:
		"house", "depot", "barracks", "factory", "vehicle_workshop": _shelter(st, kind, stage)
		"garden": _garden(st, stage)
		"wall": _wall(st, stage)
		"tower", "relay", "mortar", "yard": _equipment(st, kind, stage)
		_: _shelter(st, "depot", stage)
	if _material == null:
		_material = StandardMaterial3D.new()
		_material.vertex_color_use_as_albedo = true
		_material.vertex_color_is_srgb = true
		_material.roughness = .97
		_material.metallic_specular = .12
	st.set_material(_material)
	st.index()
	var mesh := st.commit()
	_cache[key] = mesh
	return mesh

static func _box(st: SurfaceTool, size: Vector3, pos: Vector3, color: Color, angles := Vector3.ZERO) -> void:
	Shapes._box(st, size, pos, color, angles)

static func _beam(st: SurfaceTool, a: Vector3, b: Vector3, width: float, color: Color) -> void:
	var axis := b - a
	if axis.length_squared() < .000001: return
	var basis := Basis.looking_at(axis.normalized(), Vector3.RIGHT if absf(axis.normalized().dot(Vector3.UP)) > .98 else Vector3.UP)
	_box(st, Vector3(width, width, axis.length()), (a + b) * .5, color, basis.get_euler())

static func _panel(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, color: Color) -> void:
	# Cloth/roof patches have a back face too; do not depend on a no-cull material.
	Shapes._quad(st, a, b, c, d, color)
	Shapes._quad(st, d, c, b, a, color.darkened(.13))

static func _footing(st: SurfaceTool, x: float, z: float) -> void:
	_box(st, Vector3(.36,.20,.36), Vector3(x,.13,z), STONE)
	_box(st, Vector3(.19,.05,.20), Vector3(x,.26,z), RUST)

static func _materials(st: SurfaceTool, at: Vector3, metal: bool, stage: int, length: float = 1.35) -> void:
	# Palette-sized stacked planks/sections, tied canvas and one supply crate.
	var count: int = 4 if stage == 0 else 2
	for level in count:
		for row in 3:
			_box(st, Vector3(length,.10,.14), at + Vector3(0,.17+level*.11,row*.17), STEEL if metal else TIMBER)
	for x in [-length*.31,length*.31]:
		_box(st, Vector3(.07,.08,.51), at+Vector3(x,.13+count*.11,.17), DARK)
	if stage == 0:
		_box(st, Vector3(.61,.38,.47), at+Vector3(-length*.25,.28,-.48), CLOTH)
		_box(st, Vector3(.08,.39,.49), at+Vector3(-length*.25,.28,-.48), TIMBER)
		_box(st, Vector3(.50,.43,.48), at+Vector3(length*.45,.30,-.47), TIMBER)
		_beam(st,at+Vector3(length*.45-.24,.10,-.72),at+Vector3(length*.45+.24,.50,-.72),.065,CUT_END)

static func _work_barrier(st: SurfaceTool, center: Vector3, width: float = 1.2) -> void:
	# Broad amber boards remain at every unfinished stage, without UI or text.
	for x in [-width*.40,width*.40]:
		_beam(st,center+Vector3(x,.10,-.18),center+Vector3(x,.93,.02),.075,TIMBER)
		_beam(st,center+Vector3(x,.10,.27),center+Vector3(x,.93,.02),.075,TIMBER)
	_box(st,Vector3(width,.20,.08),center+Vector3(0,.74,.02),AMBER)
	for x in [-.34,0,.34]:
		_box(st,Vector3(.16,.21,.012),center+Vector3(x*width,.74,-.03),DARK,Vector3(0,0,-.40))

static func _scaffold(st: SurfaceTool, x: float, z0: float, z1: float, height: float) -> void:
	for xx in [x-.20,x+.20]:
		for z in [z0,z1]:
			_beam(st,Vector3(xx,.10,z),Vector3(xx,height+.34,z),.085,TIMBER)
		_beam(st,Vector3(xx,height+.25,z0),Vector3(xx,height+.25,z1),.065,CUT_END)
		_beam(st,Vector3(xx,.32,z0),Vector3(xx,height,z1),.065,TIMBER)
	_box(st,Vector3(.60,.09,z1-z0+.25),Vector3(x,height-.18,(z0+z1)*.5),TIMBER)
	# Ladder is wide enough to read as work equipment at RTS camera sizes.
	for xx in [x-.21,x+.21]:
		_beam(st,Vector3(xx,.08,z0-.43),Vector3(xx,height+.07,z0+.01),.065,CUT_END)
	for step in 6:
		var t: float = float(step)/5.0
		_beam(st,Vector3(x-.21,.23+t*(height-.27),z0-.39+t*.39),Vector3(x+.21,.23+t*(height-.27),z0-.39+t*.39),.052,CUT_END)

static func _shelter(st: SurfaceTool, kind: String, stage: int) -> void:
	var industrial: bool = kind in ["factory","vehicle_workshop"]
	var width: float = {"house":2.60,"depot":3.0,"barracks":3.90,"factory":3.30,"vehicle_workshop":4.20}[kind]
	var depth: float = {"house":1.95,"depot":2.40,"barracks":2.10,"factory":2.75,"vehicle_workshop":3.40}[kind]
	var height: float = {"house":2.12,"depot":2.20,"barracks":2.14,"factory":2.30,"vehicle_workshop":2.88}[kind]
	var ridge: float = {"house":2.64,"depot":2.49,"barracks":2.90,"factory":3.03,"vehicle_workshop":3.30}[kind]
	# GLB source faces -Z. Shelter roof is behind the open training apron.
	var zc: float = .63 if kind == "barracks" else (.28 if kind == "house" else .12)
	var x0: float = -width*.5
	var x1: float = width*.5
	var z0: float = zc-depth*.5
	var z1: float = zc+depth*.5
	var structure: Color = STEEL if industrial else TIMBER
	_box(st,Vector3(width+.34,.07,depth+.38),Vector3(0,.045,zc),EARTH)
	for x in [x0,x1]:
		for z in [z0,z1]: _footing(st,x,z)
	for z in [z0,z1]: _box(st,Vector3(width,.10,.16),Vector3(0,.24,z),structure)
	for x in [x0,x1]: _box(st,Vector3(.16,.10,depth),Vector3(x,.24,zc),structure)
	var front: float = -1.72 if kind == "barracks" else z0-.40
	_materials(st,Vector3(-width*.16,0,zc+.10),industrial,stage, minf(1.8,width*.64))
	_work_barrier(st,Vector3(width*.19,0,front),minf(1.45,width*.55))
	if stage == 0:
		# Survey pegs and coarse cross strings show the actual future footprint.
		for x in [x0,x1]:
			for z in [z0,z1]: _box(st,Vector3(.08,.55,.08),Vector3(x,.35,z),CUT_END)
		_beam(st,Vector3(x0,.48,z0),Vector3(x1,.48,z0),.025,CLOTH)
		return
	for x in [x0,x1]:
		for z in [z0,z1]: _beam(st,Vector3(x,.27,z),Vector3(x,height,z),.15 if industrial else .12,structure)
		_beam(st,Vector3(x,height,z0),Vector3(x,height,z1),.12,structure)
		_beam(st,Vector3(x,.36,z1),Vector3(x,height,z1-.66),.095,RUST if industrial else CUT_END)
	# Three distinct roof profiles: lean-to, shallow barrel, and pitched shelter.
	for z in [z0,zc,z1]:
		if kind == "vehicle_workshop":
			for rib in 6:
				var xa: float = x0+width*float(rib)/6.0
				var xb: float = x0+width*float(rib+1)/6.0
				_beam(st,Vector3(xa,_barrel_height(xa,width,height,ridge),z),Vector3(xb,_barrel_height(xb,width,height,ridge),z),.11,STEEL)
		elif kind == "depot":
			_beam(st,Vector3(x0,height+(z-z0)*.12,z),Vector3(x1,height+(z-z0)*.12,z),.10,structure)
		else:
			_beam(st,Vector3(x0,height,z),Vector3(0,ridge,z),.10,structure)
			_beam(st,Vector3(0,ridge,z),Vector3(x1,height,z),.10,structure)
	if kind != "depot": _beam(st,Vector3(0,ridge,z0),Vector3(0,ridge,z1),.12,structure)
	if kind == "barracks":
		for z in [z0,z1]: _beam(st,Vector3(0,.12,z),Vector3(0,ridge,z),.11,TIMBER)
		# Training apron gets unfinished supports; no targets/bag until completed.
		for x in [-1.18,1.42]: _beam(st,Vector3(x,.1,-1.25),Vector3(x,1.4,-1.25),.11,TIMBER)
	if stage == 1: return
	# Half-fitted wall and roof panels deliberately leave an open skeleton.
	if kind != "barracks":
		_box(st,Vector3(width*.67,height*.55,.075),Vector3(-width*.15,height*.43,z1),RUST if industrial else TIMBER)
		for x in range(5):
			_box(st,Vector3(.055,height*.55,.09),Vector3(-width*.43+x*width*.14,height*.43,z1-.01),CUT_END if not industrial else STEEL)
	else:
		for row in 3: _box(st,Vector3(width,.17,.075),Vector3(0,.42+row*.20,z1),TIMBER)
	var roof_color: Color = CLOTH if kind == "barracks" else (RUST if kind == "depot" else SAGE)
	if kind == "vehicle_workshop":
		for strip in 5:
			var xa: float = x0+width*float(strip)/8.0
			var xb: float = x0+width*float(strip+1)/8.0
			var ya: float = _barrel_height(xa,width,height,ridge)+.035
			var yb: float = _barrel_height(xb,width,height,ridge)+.035
			_panel(st,Vector3(xa,ya,z0-.1),Vector3(xa,ya,z1+.1),Vector3(xb,yb,z1+.1),Vector3(xb,yb,z0-.1),STEEL if strip%3 else SAGE)
	elif kind == "depot":
		_panel(st,Vector3(x0-.12,height+.04,z0-.1),Vector3(x0-.12,ridge+.04,z1+.1),Vector3(.28,ridge+.04,z1+.1),Vector3(.28,height+.04,z0-.1),roof_color)
	else:
		# One roof slope and one rear patch installed; front half stays plainly open.
		_panel(st,Vector3(x0-.12,height+.045,z0-.10),Vector3(x0-.12,height+.045,z1+.10),Vector3(0,ridge+.045,z1+.10),Vector3(0,ridge+.045,z0-.10),roof_color)
		_panel(st,Vector3(0,ridge+.045,zc+.23),Vector3(0,ridge+.045,z1+.10),Vector3(x1+.12,height+.045,z1+.10),Vector3(x1+.12,height+.045,zc+.23),roof_color.darkened(.1))
		_beam(st,Vector3(x0-.1,height+.06,z0-.11),Vector3(0,ridge+.06,z0-.11),.04,CLOTH.lightened(.13))
	_scaffold(st,x1+.16,z0+.25,z1-.15,minf(1.85,height-.3))

static func _barrel_height(x: float, width: float, eave: float, ridge: float) -> float:
	return eave+(ridge-eave)*sqrt(maxf(0.0,1.0-pow(x/(width*.5),2)))

static func _garden(st: SurfaceTool, stage: int) -> void:
	for x in [-1.26,0.0,1.26]:
		_box(st,Vector3(.94,.10,2.99),Vector3(x,.06,.12),EARTH)
		for z in [-1.42,1.66]:
			for xx in [x-.48,x+.48]: _box(st,Vector3(.08,.46,.08),Vector3(xx,.25,z),CUT_END)
		if stage > 0:
			for xx in [x-.49,x+.49]: _box(st,Vector3(.08,.30,3.12),Vector3(xx,.23,.12),TIMBER)
			for z in [-1.42,1.66]: _box(st,Vector3(1.04,.30,.08),Vector3(x,.23,z),TIMBER)
		if stage == 2:
			_box(st,Vector3(.92,.24,2.97),Vector3(x,.20,.12),EARTH.lightened(.08))
			for z in [-.85,-.20,.45,1.1]: _box(st,Vector3(.8,.05,.085),Vector3(x,.34,z),EARTH.darkened(.15))
	if stage == 2:
		for x in [-1.75,-.62,.62,1.75]: _beam(st,Vector3(x,.1,1.73),Vector3(x,1.13,1.73),.065,TIMBER)
		for y in [.62,1.01]: _beam(st,Vector3(-1.75,y,1.73),Vector3(1.75,y,1.73),.025,CLOTH)
	_materials(st,Vector3(-.60,0,-1.39),false,stage,1.15)
	_work_barrier(st,Vector3(.96,0,-1.55),1.05)

static func _wall(st: SurfaceTool, stage: int) -> void:
	_box(st,Vector3(3.10,.20,1.1),Vector3(0,.12,0),STONE.darkened(.13))
	for x in [-1.10,0.0,1.10]:
		_box(st,Vector3(.16, .52 if stage == 0 else 1.34,.70),Vector3(x,.30 if stage == 0 else .82,0),STEEL)
	if stage == 0:
		_materials(st,Vector3(-.30,0,0),false,0,1.30)
	elif stage == 1:
		for y in [.55,1.10]: _beam(st,Vector3(-1.45,y,0),Vector3(1.45,y,0),.07,RUST)
		_box(st,Vector3(.86,.65,.55),Vector3(-.58,.56,0),STONE)
	else:
		_box(st,Vector3(2.0,1.04,.64),Vector3(-.51,.83,0),STONE)
		_box(st,Vector3(2.15,.16,.76),Vector3(-.5,1.43,0),STONE.lightened(.1))
		for x in [.73,1.07,1.41]: _box(st,Vector3(.28,.93,.075),Vector3(x,.79,-.38),TIMBER)
		_beam(st,Vector3(1.0,.12,-.68),Vector3(1.0,1.05,-.34),.12,CUT_END)
	_work_barrier(st,Vector3(-.40,0,-.46),1.2)

static func _equipment(st: SurfaceTool, kind: String, stage: int) -> void:
	var w: float = {"tower":2.65,"relay":1.95,"mortar":3.2,"yard":4.2}[kind]
	var d: float = 3.5 if kind == "yard" else w
	_box(st,Vector3(w,.17,d),Vector3(0,.11,0),STONE.darkened(.10))
	_materials(st,Vector3(-w*.15,0,w*.16),true,stage,minf(1.6,w*.60))
	_work_barrier(st,Vector3(w*.16,0,-d*.38),minf(1.25,w*.68))
	if kind == "mortar":
		for x in [-.94,.94]: _box(st,Vector3(.17,.16,2.15),Vector3(x,.29,.02),STEEL)
		if stage > 0:
			Shapes._prism(st,.73,.63,.52,Vector3(0,.54,0),STEEL,10)
			_box(st,Vector3(1.60,.22,1.25),Vector3(0,.84,.03),RUST)
			# Barrel stays horizontal on timber cradles until the complete gun is ready.
			for z in [-.48,.70]: _box(st,Vector3(.45,.33,.20),Vector3(-1.05,.38,z),TIMBER)
			_beam(st,Vector3(-1.05,.58,-1.05),Vector3(-1.05,.58,1.16),.23,STEEL)
		if stage == 2:
			for x in [-.81,.81]: _box(st,Vector3(.17,.88,1.03),Vector3(x,1.24,.03),STEEL)
			for x in [-.60,.60]: _beam(st,Vector3(x,.2,-.62),Vector3(x,1.77,0),.09,TIMBER)
			_beam(st,Vector3(-.7,1.77,0),Vector3(.7,1.77,0),.12,TIMBER)
		return
	var tower: bool = kind == "tower"
	var relay: bool = kind == "relay"
	var half_x: float = .77 if tower else (.46 if relay else 1.65)
	var half_z: float = .77 if tower else (.46 if relay else 1.10)
	var height: float = (2.55 if tower else (3.75 if relay else 3.0)) if stage == 2 else (1.46 if tower else (1.65 if relay else 2.15))
	if stage == 0:
		for x in [-half_x,half_x]:
			for z in [-half_z,half_z]: _footing(st,x,z)
		return
	var taper: float = .28 if relay else (.86 if tower else 1.0)
	for x in [-half_x,half_x]:
		for z in [-half_z,half_z]: _beam(st,Vector3(x,.2,z),Vector3(x*taper,height,z*taper),.09 if relay else .15,STEEL)
	for z in [-half_z,half_z]:
		_beam(st,Vector3(-half_x,.36,z),Vector3(half_x*taper,height-.10,z*taper),.065,RUST)
		_beam(st,Vector3(half_x,.36,z),Vector3(-half_x*taper,height-.10,z*taper),.065,RUST)
	if tower:
		_box(st,Vector3(2.05,.18,1.92),Vector3(0,height,0),TIMBER if stage == 1 else STEEL)
		if stage == 2:
			# Empty guard platform, no working gun silhouette yet.
			for x in [-.87,.87]: _box(st,Vector3(.10,.50,1.5),Vector3(x,height+.28,0),SAGE)
			_scaffold(st,1.03,-.55,.71,1.94)
	elif relay:
		for y in [height*.40,height*.73]: _beam(st,Vector3(-.37,y,-.2),Vector3(.37,y,-.2),.06,CUT_END)
		if stage == 2:
			_box(st,Vector3(.70,.78,.57),Vector3(.37,.60,.34),STEEL)
			# Antenna laid out on the pad, visibly waiting for its last installation.
			_beam(st,Vector3(-.82,.40,-.14),Vector3(.82,.40,-.14),.075,CUT_END)
			for x in [-.63,-.21,.21,.63]: _beam(st,Vector3(x,.40,-.39),Vector3(x,.40,.10),.05,STEEL)
	else:
		for x in [-1.65,1.65]: _beam(st,Vector3(x,height,-1.1),Vector3(x,height,1.1),.18,RUST)
		_beam(st,Vector3(-1.8,height,0),Vector3(1.8,height,0),.24,RUST)
		if stage == 2:
			_box(st,Vector3(3.6,.18,1.25),Vector3(0,3.05,.6),RUST)
			_scaffold(st,1.68,-.77,.73,1.95)
