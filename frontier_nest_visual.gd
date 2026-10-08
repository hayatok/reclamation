extends RefCounted
## Original static-geometry placeholder: a breached industrial utility block.
## Shared materials, 25 small primitives, no timers, physics, animations or RNG.
## Two rusted door throats face the authored west/south emergence directions.
const WALL_COLOR := Color("514a40")
const STEEL_COLOR := Color("776956")
const INFECTED_COLOR := Color("934638")

static func create() -> Node3D:
	var root := Node3D.new()
	root.name = "FrontierInfectedNest"
	var wall := _material(WALL_COLOR)
	var steel := _material(STEEL_COLOR)
	var infected := _material(INFECTED_COLOR)
	var dark := _material(Color("201f19"))
	root.set_meta("frontier_core_material", infected)
	var intact := Node3D.new()
	intact.name = "Intact"
	root.add_child(intact)
	_box(intact, Vector3(7.6, 0.35, 7.6), Vector3(0, 0.175, 0), steel)
	_box(intact, Vector3(6.8, 3.3, 5.8), Vector3(0.25, 1.9, -0.35), wall)
	_box(intact, Vector3(6.95, 0.3, 6.0), Vector3(0.25, 3.7, -0.35), steel)
	# West entry: visible dark recess and lintel, not a mobile-infected renderer.
	_box(intact, Vector3(0.12, 2.55, 2.2), Vector3(-3.21, 1.6, 0.35), dark)
	_box(intact, Vector3(1.3, 0.3, 2.85), Vector3(-3.4, 3.0, 0.35), steel)
	_box(intact, Vector3(0.45, 2.7, 0.3), Vector3(-3.45, 1.55, -0.96), steel)
	_box(intact, Vector3(0.45, 2.7, 0.3), Vector3(-3.45, 1.55, 1.66), steel)
	# South entry and slab visibly extend toward the spawn corridor.
	_box(intact, Vector3(2.2, 2.55, 0.12), Vector3(0.65, 1.6, 2.62), dark)
	_box(intact, Vector3(2.85, 0.3, 1.3), Vector3(0.65, 3.0, 2.9), steel)
	_box(intact, Vector3(0.3, 2.7, 0.45), Vector3(-0.66, 1.55, 2.95), steel)
	_box(intact, Vector3(0.3, 2.7, 0.45), Vector3(1.96, 1.55, 2.95), steel)
	for index in 5:
		var rib := _box(intact, Vector3(0.28, 0.35, 6.2), Vector3(-2.2 + index * 1.1, 3.98, -0.35), infected)
		rib.rotation.z = (-0.12 if index % 2 == 0 else 0.12)
	for index in 3:
		var pipe := MeshInstance3D.new()
		var cylinder := CylinderMesh.new()
		cylinder.top_radius = 0.23
		cylinder.bottom_radius = 0.35
		cylinder.height = 1.1 + index * 0.35
		cylinder.radial_segments = 6
		pipe.mesh = cylinder
		pipe.material_override = infected
		pipe.position = Vector3(1.7 + index * 0.5, 4.15 + index * 0.17, -1.7)
		intact.add_child(pipe)
	var rubble := Node3D.new()
	rubble.name = "Rubble"
	root.add_child(rubble)
	for index in 6:
		var piece := _box(rubble, Vector3(1.8, 0.65 + (index % 2) * 0.35, 1.35), Vector3((index % 3 - 1) * 1.7, 0.4, (floori(index / 3.0) - 0.5) * 2.4), wall)
		piece.rotation.y = index * 0.71
	rubble.visible = false
	return root

static func set_state(root: Node3D, dead: bool, alarm: bool) -> void:
	root.get_node("Intact").visible = not dead
	root.get_node("Rubble").visible = dead
	var core: StandardMaterial3D = root.get_meta("frontier_core_material")
	core.albedo_color = Color("ee673f") if alarm else INFECTED_COLOR
	core.emission_enabled = alarm
	core.emission = Color("b13d23") if alarm else Color.BLACK
	core.emission_energy_multiplier = 0.8 if alarm else 0.0

static func _material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.97
	return material

static func _box(parent: Node3D, size: Vector3, position: Vector3, material: StandardMaterial3D) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = material
	instance.position = position
	parent.add_child(instance)
	return instance
