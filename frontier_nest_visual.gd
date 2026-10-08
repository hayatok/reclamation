extends RefCounted
## Original infected port warehouse, baked once into two surfaces per state.
## Static art only: no nodes with _process, physics, particle emitters or lights.
## All geometry fits radius 4.5 m; west/south spawn centers remain at radius 6.2 m.
## Public contract: create() -> Node3D; set_state(root, dead, alarm) -> void.

const WALL := Color("78807a")
const WALL_DARK := Color("525d59")
const BRICK := Color("805c50")
const SOOT := Color("252e2d")
const STEEL := Color("47524f")
const RUST := Color("775641")
const PAINT := Color("999b84")
const INFECTED_COLOR := Color("78483d")
const CORE_LIGHT := Color("94604b")
const CORE_DARK := Color("4e332d")
const CORE_VOID := Color("252925")

static var _meshes: Dictionary = {}
static var _shell_material: StandardMaterial3D
static var _rubble_material: StandardMaterial3D
static var _dead_infection_material: StandardMaterial3D

class MeshBuilder:
	extends RefCounted
	var surface := SurfaceTool.new()
	var triangles: int = 0
	func _init() -> void:
		surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	func append(primitive: PrimitiveMesh, transform: Transform3D, color: Color, deform: float = 0.0) -> void:
		var arrays: Array = primitive.get_mesh_arrays()
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		var normal_basis := transform.basis.inverse().transposed()
		for j in range(indices.size() if not indices.is_empty() else vertices.size()):
			var index: int = indices[j] if not indices.is_empty() else j
			var point: Vector3 = vertices[index]
			if deform != 0.0:
				# Deterministic, broad asymmetric bulges. No runtime noise or animation.
				var bulge := 1.0 + 0.13 * sin(point.y * 3.6 + deform) + 0.08 * sin(point.x * 4.1 - point.z * 2.8 + deform)
				point.x *= bulge
				point.z *= bulge
				point.x += 0.09 * point.y * sin(deform)
			surface.set_color(color)
			surface.set_normal((normal_basis * normals[index]).normalized())
			surface.add_vertex(transform * point)
		triangles += (indices.size() if not indices.is_empty() else vertices.size()) / 3
	func box(size: Vector3, at: Vector3, color: Color, rotation: Vector3 = Vector3.ZERO) -> void:
		var primitive := BoxMesh.new()
		primitive.size = Vector3.ONE
		append(primitive, Transform3D(Basis.from_euler(rotation) * Basis.from_scale(size), at), color)
	func lobe(at: Vector3, size: Vector3, color: Color, phase: float, rotation: Vector3 = Vector3.ZERO) -> void:
		var primitive := SphereMesh.new()
		primitive.radius = 1.0
		primitive.height = 2.0
		primitive.radial_segments = 9
		primitive.rings = 5
		append(primitive, Transform3D(Basis.from_euler(rotation) * Basis.from_scale(size), at), color, phase)
	func root(points: Array[Vector3], radii: Array[float], color: Color) -> void:
		for i in range(points.size() - 1):
			var delta := points[i + 1] - points[i]
			var up := delta.normalized()
			var helper := Vector3.RIGHT if absf(up.dot(Vector3.RIGHT)) < 0.95 else Vector3.FORWARD
			var right := helper.cross(up).normalized()
			var back := right.cross(up).normalized()
			var primitive := CylinderMesh.new()
			primitive.bottom_radius = radii[i]
			primitive.top_radius = radii[i + 1]
			primitive.height = delta.length()
			primitive.radial_segments = 7
			primitive.rings = 1
			append(primitive, Transform3D(Basis(right, up, back), (points[i + 1] + points[i]) * 0.5), color)
	func finish() -> ArrayMesh:
		surface.index()
		return surface.commit()

static func create() -> Node3D:
	_ensure_baked()
	var root := Node3D.new()
	root.name = "FrontierInfectedNest"
	var intact := Node3D.new()
	intact.name = "Intact"
	root.add_child(intact)
	_add_mesh(intact, "WarehouseShell", _meshes.alive_shell, _shell_material)
	var infection := _material(Color.WHITE, false)
	root.set_meta("frontier_core_material", infection)
	_add_mesh(intact, "Infection", _meshes.alive_infection, infection)
	var rubble := Node3D.new()
	rubble.name = "Rubble"
	root.add_child(rubble)
	_add_mesh(rubble, "BrokenWarehouse", _meshes.dead_shell, _rubble_material)
	_add_mesh(rubble, "SpentInfection", _meshes.dead_infection, _dead_infection_material)
	rubble.visible = false
	root.set_meta("frontier_art_dead", false)
	root.set_meta("frontier_art_alarm", false)
	root.set_meta("frontier_art_radius", 4.5)
	return root

static func set_state(root: Node3D, dead: bool, alarm: bool) -> void:
	var active_alarm := alarm and not dead
	if bool(root.get_meta("frontier_art_dead", false)) != dead:
		root.get_node("Intact").visible = not dead
		root.get_node("Rubble").visible = dead
		root.set_meta("frontier_art_dead", dead)
	if bool(root.get_meta("frontier_art_alarm", false)) == active_alarm:
		return
	root.set_meta("frontier_art_alarm", active_alarm)
	var core: StandardMaterial3D = root.get_meta("frontier_core_material")
	# Only the infestation reacts. Static warehouse stone/metal never flash.
	core.albedo_color = Color(1.16, 0.91, 0.76) if active_alarm else Color.WHITE
	core.emission_enabled = active_alarm
	core.emission = Color("8e3e24") if active_alarm else Color.BLACK
	core.emission_energy_multiplier = 0.46 if active_alarm else 0.0

static func _ensure_baked() -> void:
	if not _meshes.is_empty():
		return
	var shell := MeshBuilder.new()
	var infection := MeshBuilder.new()
	var rubble := MeshBuilder.new()
	var spent := MeshBuilder.new()
	_build_warehouse(shell)
	_build_infection(infection)
	_build_rubble(rubble, spent)
	_meshes = {"alive_shell": shell.finish(), "alive_infection": infection.finish(), "dead_shell": rubble.finish(), "dead_infection": spent.finish()}
	_shell_material = _material(Color.WHITE, true)
	_rubble_material = _shell_material
	_dead_infection_material = _material(Color("71665b"), false)

static func _build_warehouse(b: MeshBuilder) -> void:
	# The broken masonry, dark floor plates and fallen half-roof repeat the
	# visual language of the project-owned world_art.gd shells at landmark scale.
	b.box(Vector3(6.5, 0.18, 5.7), Vector3(0, 0.09, 0), WALL_DARK)
	b.box(Vector3(5.9, 0.08, 5.1), Vector3(0, 0.23, 0), SOOT)
	# Tall north wall: a surviving sawtooth crown, no sealed solid building core.
	for entry in [[-2.65, 4.4, 0.9], [-1.6, 4.8, 1.05], [-0.48, 3.85, 1.05], [0.68, 3.35, 1.1], [1.8, 3.95, 0.9], [2.65, 2.85, 0.75]]:
		var x: float = entry[0]
		var height: float = entry[1]
		b.box(Vector3(entry[2], height, 0.32), Vector3(x, height * 0.5, -2.62), WALL if x < 0 else BRICK)
		b.box(Vector3(0.20, height + 0.14, 0.40), Vector3(x - entry[2] * 0.42, height * 0.5, -2.61), WALL_DARK)
	# West loading opening, 2.3 m wide, truly open into the dark warehouse.
	b.box(Vector3(0.32, 4.1, 1.40), Vector3(-3.0, 2.05, -1.95), BRICK)
	b.box(Vector3(0.34, 2.55, 0.72), Vector3(-3.0, 1.275, 2.21), WALL)
	b.box(Vector3(0.38, 0.52, 2.30), Vector3(-3.0, 2.95, 0.02), WALL_DARK, Vector3(0.06, 0, 0))
	b.box(Vector3(0.41, 2.55, 0.24), Vector3(-3.03, 1.275, -1.12), WALL)
	b.box(Vector3(0.41, 2.18, 0.22), Vector3(-3.03, 1.09, 1.20), WALL)
	# Torn shutter folded inward; it does not close the doorway or protrude outside.
	b.box(Vector3(0.10, 1.45, 1.07), Vector3(-2.80, 1.24, -0.73), RUST, Vector3(0.16, 0.22, -0.11))
	for z in [-0.95, -0.72, -0.49]:
		b.box(Vector3(0.055, 1.4, 0.07), Vector3(-2.71, 1.24, z), STEEL, Vector3(0.16, 0.22, -0.11))
	# East wall has lost its entire upper front corner; the infection breaks out here.
	b.box(Vector3(0.34, 3.85, 1.82), Vector3(3.0, 1.925, -1.65), WALL_DARK)
	b.box(Vector3(0.34, 1.70, 1.32), Vector3(3.0, 0.85, 0.08), BRICK)
	b.box(Vector3(0.36, 0.75, 1.18), Vector3(3.0, 0.375, 1.50), WALL)
	# South loading front: one surviving pier, broken lintel and missing facade.
	b.box(Vector3(1.40, 2.72, 0.34), Vector3(-2.38, 1.36, 2.60), BRICK)
	b.box(Vector3(0.30, 3.16, 0.42), Vector3(-1.53, 1.58, 2.59), WALL)
	b.box(Vector3(0.32, 2.58, 0.42), Vector3(1.43, 1.29, 2.59), WALL_DARK)
	b.box(Vector3(2.90, 0.40, 0.38), Vector3(-0.05, 2.82, 2.59), WALL, Vector3(0, 0, -0.13))
	b.box(Vector3(0.78, 0.72, 0.34), Vector3(2.30, 0.36, 2.59), BRICK)
	# Large dark window bays, with surviving narrow masonry mullions.
	for x in [-2.72, -2.18]:
		b.box(Vector3(0.38, 0.92, 0.028), Vector3(x, 1.75, 2.788), SOOT)
	b.box(Vector3(1.48, 0.20, 0.38), Vector3(-2.36, 2.28, 2.62), WALL_DARK)
	# Remaining left mezzanine and half-roof reveal the infected dark center.
	b.box(Vector3(1.74, 0.19, 4.85), Vector3(-2.02, 2.17, -0.10), WALL_DARK)
	b.box(Vector3(1.93, 0.19, 4.98), Vector3(-1.97, 4.13, -0.17), STEEL, Vector3(0.025, 0, -0.11))
	b.box(Vector3(1.55, 0.20, 1.45), Vector3(1.48, 3.65, -1.74), STEEL, Vector3(0.25, 0.06, -0.40))
	b.box(Vector3(1.38, 0.19, 2.17), Vector3(-0.53, 1.09, 0.59), WALL_DARK, Vector3(0.29, 0.11, -0.47))
	# Roof ribs remain dark/rusted and broken, never infection-colored pipes.
	for z in [-2.0, -0.7, 0.65, 1.72]:
		b.box(Vector3(1.98, 0.14, 0.12), Vector3(-1.97, 4.23, z), RUST, Vector3(0.025, 0, -0.11))
	b.box(Vector3(0.095, 1.01, 0.095), Vector3(-1.53, 3.66, 2.59), RUST, Vector3(0.03, 0, -0.19))
	b.box(Vector3(0.095, 0.74, 0.095), Vector3(1.43, 2.93, 2.59), RUST, Vector3(0.17, 0, 0.26))
	# Two small faded loading marks preserve the warehouse identity.
	b.box(Vector3(0.70, 0.022, 0.12), Vector3(-0.62, 0.29, 2.61), PAINT)
	b.box(Vector3(0.70, 0.022, 0.12), Vector3(0.57, 0.29, 2.61), PAINT)
	# A few fallen brick/slab pieces inside the footprint, not exterior confetti.
	for i in range(6):
		b.box(Vector3(0.49 + float(i % 2) * 0.23, 0.25, 0.38), Vector3(-2.42 + float(i) * 0.82, 0.27, 1.81 + float(i % 2) * 0.18), BRICK if i % 2 else WALL_DARK, Vector3(0.10, float(i) * 0.49, 0.12))

static func _build_infection(b: MeshBuilder) -> void:
	# A lopsided fused colony shoulders through the missing roof and east wall.
	# Broad lobes and tapering roots carry the silhouette; no repeating pipe rack.
	b.lobe(Vector3(1.15, 2.81, -0.60), Vector3(1.40, 1.48, 1.28), INFECTED_COLOR, 1.3, Vector3(0.10, 0.10, -0.16))
	b.lobe(Vector3(1.72, 4.04, -0.98), Vector3(0.94, 1.09, 0.95), CORE_LIGHT, 2.5, Vector3(-0.12, 0.20, -0.25))
	b.lobe(Vector3(0.32, 3.79, -0.15), Vector3(0.86, 0.73, 0.90), INFECTED_COLOR, 4.0, Vector3(0.05, 0.12, 0.31))
	b.lobe(Vector3(2.66, 2.11, 0.79), Vector3(0.65, 1.19, 0.86), CORE_DARK, 5.1, Vector3(0.12, 0.03, -0.17))
	b.lobe(Vector3(1.82, 0.93, 1.54), Vector3(1.00, 0.77, 0.82), INFECTED_COLOR, 2.0, Vector3(0.16, -0.12, 0.20))
	b.lobe(Vector3(-0.51, 1.17, 0.12), Vector3(0.79, 0.75, 0.99), CORE_DARK, 3.2)
	# Dark recessed-looking sacs interrupt the large mass at normal RTS zoom.
	b.lobe(Vector3(1.91, 4.19, -0.08), Vector3(0.43, 0.50, 0.15), CORE_VOID, 1.6, Vector3(0.10, -0.12, -0.19))
	b.lobe(Vector3(0.42, 3.88, 0.64), Vector3(0.28, 0.31, 0.10), CORE_DARK, 2.8)
	b.lobe(Vector3(2.97, 2.49, 1.20), Vector3(0.23, 0.33, 0.10), CORE_VOID, 3.7, Vector3(0.1, 0.7, 0))
	b.root([Vector3(1.69, 4.42, -1.15), Vector3(2.18, 3.61, -0.35), Vector3(2.10, 2.08, 0.75), Vector3(1.53, 0.55, 2.10), Vector3(1.29, 0.22, 3.53)], [0.38, 0.47, 0.39, 0.26, 0.055], CORE_LIGHT)
	b.root([Vector3(0.91, 3.42, -0.37), Vector3(-0.45, 2.51, 0.36), Vector3(-1.17, 0.92, 0.20), Vector3(-2.33, 0.34, -0.04), Vector3(-3.70, 0.17, 0.14)], [0.34, 0.37, 0.30, 0.22, 0.05], INFECTED_COLOR)
	b.root([Vector3(2.26, 2.32, 0.70), Vector3(3.27, 1.35, 1.12), Vector3(3.55, 0.28, 1.31), Vector3(3.84, 0.16, 1.68)], [0.30, 0.26, 0.19, 0.045], CORE_DARK)
	b.root([Vector3(0.75, 1.48, -0.16), Vector3(0.61, 0.50, -1.42), Vector3(-0.22, 0.25, -2.45), Vector3(-0.52, 0.15, -3.73)], [0.30, 0.29, 0.20, 0.035], CORE_DARK)

static func _build_rubble(b: MeshBuilder, spent: MeshBuilder) -> void:
	b.box(Vector3(6.5, 0.18, 5.7), Vector3(0, 0.09, 0), WALL_DARK)
	b.box(Vector3(5.9, 0.10, 5.1), Vector3(0, 0.23, 0), SOOT)
	# A surviving low corner and angled floor plates retain the former footprint.
	b.box(Vector3(2.40, 1.27, 0.40), Vector3(-1.90, 0.635, -2.58), BRICK)
	b.box(Vector3(0.36, 1.03, 1.51), Vector3(-3.0, 0.515, -1.69), WALL)
	b.box(Vector3(0.36, 0.65, 1.76), Vector3(3.0, 0.325, -1.64), WALL_DARK)
	for entry in [
		[Vector3(-1.51, 0.53, -0.72), Vector3(2.45, 0.30, 1.32), Vector3(0.19, 0.33, 0.18)],
		[Vector3(0.81, 0.54, 0.52), Vector3(2.61, 0.29, 1.53), Vector3(-0.23, -0.38, -0.12)],
		[Vector3(-0.89, 0.37, 1.79), Vector3(2.09, 0.22, 1.08), Vector3(0.12, 0.28, -0.21)],
		[Vector3(1.17, 0.57, -1.31), Vector3(2.22, 0.22, 1.66), Vector3(0.25, -0.17, 0.32)],
	]:
		b.box(entry[1], entry[0], WALL_DARK, entry[2])
	for i in range(9):
		var x := -2.15 + float(i % 3) * 2.04
		var z := -1.56 + float(floori(float(i) / 3.0)) * 1.50
		b.box(Vector3(0.71, 0.37, 0.53), Vector3(x, 0.29, z), BRICK if i % 2 else WALL, Vector3(0.16, float(i) * 0.71, 0.13))
	b.box(Vector3(2.84, 0.16, 1.80), Vector3(-0.52, 0.51, -0.31), STEEL, Vector3(0.24, 0.24, -0.10))
	spent.lobe(Vector3(1.51, 0.55, 0.59), Vector3(1.15, 0.41, 1.16), CORE_DARK, 1.8)
	spent.lobe(Vector3(0.22, 0.36, -0.63), Vector3(0.73, 0.22, 0.91), CORE_DARK, 4.1)
	spent.root([Vector3(1.55, 0.44, 0.70), Vector3(1.79, 0.24, 2.03), Vector3(1.29, 0.16, 3.53)], [0.22, 0.15, 0.04], CORE_DARK)
	spent.root([Vector3(0.30, 0.33, 0.19), Vector3(-1.62, 0.26, -0.02), Vector3(-3.70, 0.14, 0.14)], [0.20, 0.17, 0.035], CORE_DARK)

static func _material(color: Color, plaster: bool) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.vertex_color_use_as_albedo = true
	material.roughness = 0.97
	material.metallic_specular = 0.16
	if plaster:
		material.albedo_texture = load("res://assets/materials/ruined_plaster.png")
		material.uv1_triplanar = true
		material.uv1_world_triplanar = true
		material.uv1_scale = Vector3(0.18, 0.18, 0.18)
		material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	return material

static func _add_mesh(parent: Node3D, mesh_name: String, mesh: ArrayMesh, material: StandardMaterial3D) -> void:
	var instance := MeshInstance3D.new()
	instance.name = mesh_name
	instance.mesh = mesh
	instance.material_override = material
	parent.add_child(instance)
