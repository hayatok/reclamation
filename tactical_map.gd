extends Node3D
## Mission-specific, low industrial cover on the shared procedural district.
## Positions are ground-plane centers; collision and pathfinding share exact X/Z sizes.
## Paint is raised above the district's road deck and never adds a hidden blocker.

var _mission_index: int = -1
var _materials: Dictionary = {}
var _batches: Dictionary = {}

static func blockers_for(mission_index: int) -> Array:
	match clampi(mission_index, 0, 2):
		0:
			# A small central island splits the first approach into two broad avenues.
			return [
				{"pos": Vector3(0, 0, -7), "size": Vector3(2.8, 1.05, 7)},
				{"pos": Vector3(-9, 0, -1), "size": Vector3(5, 0.85, 1.4)},
				{"pos": Vector3(9, 0, -1), "size": Vector3(5, 0.85, 1.4)},
				{"pos": Vector3(-10, 0, -17), "size": Vector3(5, 0.95, 1.5)},
				{"pos": Vector3(10, 0, -17), "size": Vector3(5, 0.95, 1.5)},
			]
		1:
			# Four northern freight stacks make three six-meter crossings.
			# Short southern stacks frame an east/west loading corridor, not a cage.
			return [
				{"pos": Vector3(-21, 0, -4.5), "size": Vector3(6, 1.30, 2.5)},
				{"pos": Vector3(-8.5, 0, -4.5), "size": Vector3(7, 1.30, 2.5)},
				{"pos": Vector3(5, 0, -4.5), "size": Vector3(8, 1.30, 2.5)},
				{"pos": Vector3(19, 0, -4.5), "size": Vector3(8, 1.30, 2.5)},
				{"pos": Vector3(-16, 0, 5.5), "size": Vector3(6, 1.15, 2.5)},
				{"pos": Vector3(17, 0, 5.5), "size": Vector3(8, 1.15, 2.5)},
				{"pos": Vector3(-14, 0, -17), "size": Vector3(8, 1.20, 2.5)},
				{"pos": Vector3(21, 0, -16), "size": Vector3(7, 1.20, 2.4)},
			]
		_:
			# Staggered broken mains screen the facility front. The two offset gaps
			# and the outside flanks remain open; the entire rear of HQ is clear.
			return [
				{"pos": Vector3(-17, 0, -8.5), "size": Vector3(12, 1.25, 2.4)},
				{"pos": Vector3(0, 0, -6.5), "size": Vector3(10, 1.25, 2.4)},
				{"pos": Vector3(16, 0, -8.5), "size": Vector3(12, 1.25, 2.4)},
				{"pos": Vector3(-10, 0, 0), "size": Vector3(2.6, 1.0, 5.8)},
				{"pos": Vector3(11, 0, 0), "size": Vector3(2.6, 1.0, 5.8)},
				{"pos": Vector3(0, 0, -18), "size": Vector3(6, 0.9, 2.5)},
			]

func setup(mission_index: int) -> void:
	var next_index := clampi(mission_index, 0, 2)
	if _mission_index == next_index:
		return
	_mission_index = next_index
	for child in get_children():
		remove_child(child)
		child.queue_free()
	_batches.clear()
	_make_materials()
	var blockers := blockers_for(_mission_index)
	for i in range(blockers.size()):
		var p: Vector3 = blockers[i]["pos"]
		var size: Vector3 = blockers[i]["size"]
		_add_collision(p, size, i)
		if _mission_index == 1:
			_freight(p, size, i)
		elif _mission_index == 2 and i < 3:
			_broken_main(p, size, i)
		else:
			_concrete_island(p, size, i)
	_make_route_paint()
	_flush_batches()

func _make_materials() -> void:
	if not _materials.is_empty():
		return
	for entry in [
		["concrete", "687776"], ["concrete_dark", "3d535a"],
		["edge", "263c45"], ["steel", "344a54"], ["rib", "748b8c"],
		["rust", "946246"], ["freight", "4a7b83"], ["freight_rust", "9b6951"],
		["teal_paint", "83c7b7"], ["amber_paint", "d6b16b"],
		["violet_paint", "b9afd4"], ["ivory", "b5bbaa"], ["void", "182b35"],
	]:
		var material := StandardMaterial3D.new()
		material.albedo_color = Color(entry[1])
		material.roughness = 0.9
		_materials[entry[0]] = material

func _add_collision(p: Vector3, size: Vector3, index: int) -> void:
	var body := StaticBody3D.new()
	body.name = "RouteObstacle_%02d" % index
	body.position = p + Vector3(0, size.y * 0.5, 0)
	body.set_meta("tactical_blocker", true)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)
	add_child(body)

func _cover_model(p:Vector3,size:Vector3,model:String,base:Vector3)->void:
	var scene:=load("res://assets/models/"+model+".glb") as PackedScene
	var root:=scene.instantiate() as Node3D
	var along_x:bool=size.x>=size.z
	var length:float=size.x if along_x else size.z
	var width:float=size.z if along_x else size.x
	root.scale=Vector3(length/base.x,size.y/base.y,width/base.z)
	root.rotation.y=0 if along_x else PI*.5
	root.position=p
	add_child(root)

func _concrete_island(p: Vector3, size: Vector3, _index: int) -> void:
	_cover_model(p,size,"shattered_road_obstruction",Vector3(6,.9,2.5))

func _freight(p: Vector3, size: Vector3, index: int) -> void:
	var color := "freight" if index % 2 == 0 else "freight_rust"
	_box(p + Vector3(0, size.y * 0.5, 0), size, color)
	_box(p + Vector3(0, size.y - 0.08, 0), Vector3(size.x, 0.16, size.z), "edge")
	for side in [-1.0, 1.0]:
		_box(p + Vector3(0, 0.12, side * (size.z * 0.5 - 0.045)), Vector3(size.x, 0.12, 0.09), "steel")
		_box(p + Vector3(0, size.y - 0.13, side * (size.z * 0.5 - 0.045)), Vector3(size.x, 0.11, 0.09), "rib")
		var count := maxi(4, int(size.x / 0.58))
		for i in range(count):
			var x := -size.x * 0.5 + (float(i) + 0.5) * size.x / count
			_box(p + Vector3(x, size.y * 0.5, side * (size.z * 0.5 - 0.03)), Vector3(0.065, size.y * 0.76, 0.06), "rib")
	for side in [-1.0, 1.0]:
		_box(p + Vector3(side * (size.x * 0.5 - 0.09), size.y * 0.5, 0), Vector3(0.17, size.y, size.z), "steel")
		_box(p + Vector3(side * (size.x * 0.5 - 0.13), size.y + 0.012, 0), Vector3(0.18, 0.016, size.z * 0.78), "amber_paint")
	# Recessed lid panels make the half-height freight distinct at the RTS zoom.
	for x in [-0.24, 0.24]:
		_box(p + Vector3(size.x * x, size.y + 0.012, 0), Vector3(size.x * 0.40, 0.015, size.z * 0.70), color)
	_box(p + Vector3(-size.x * 0.22, size.y + 0.026, 0), Vector3(0.62, 0.012, 0.38), "ivory")

func _broken_main(p: Vector3, size: Vector3, _index: int) -> void:
	_cover_model(p,size,"ruptured_water_main",Vector3(10,1.25,2.4))

func _make_route_paint() -> void:
	match _mission_index:
		0:
			for x in [-4.3, 4.3]:
				for z in range(-14, 1, 3):
					_paint(Vector3(x, 0, z), Vector3(0.13, 0.016, 1.5), "teal_paint")
				_arrow(Vector3(x, 0, -12), 0.0, "teal_paint")
			for x in [-12.0, 12.0]:
				for z in [-3.1, -2.65, -2.2]:
					_paint(Vector3(x, 0, z), Vector3(1.2, 0.016, 0.17), "ivory")
		1:
			# Three unmistakable crossing pads at the gaps in the freight line.
			for x in [-15.0, -2.0, 12.0]:
				for z in [-6.3, -5.4, -4.5, -3.6, -2.7]:
					_paint(Vector3(x, 0, z), Vector3(3.6, 0.016, 0.20), "amber_paint")
				_arrow(Vector3(x, 0, -1.9), 0.0, "amber_paint")
			# Double flush rails, sleeper paint and small loading bays.
			for z in [0.7, 2.7]:
				_paint(Vector3(0, 0, z), Vector3(48, 0.016, 0.09), "rib")
			for x in range(-23, 24, 3):
				_paint(Vector3(x, 0, 1.7), Vector3(0.13, 0.012, 2.25), "edge", -0.014)
			for x in [-17.0, 19.0]:
				_arrow(Vector3(x, 0, 1.7), PI * 0.5, "amber_paint")
		2:
			# Long flanking lanes curve visually into the two offset pipe breaches.
			for x in [-7.0, 7.2]:
				for z in [-11.0, -8.3, -3.3, -0.6, 2.1]:
					_paint(Vector3(x, 0, z), Vector3(0.15, 0.016, 1.25), "violet_paint")
				_arrow(Vector3(x, 0, -10.5), 0.0, "violet_paint")
			for x in [-24.5, 23.5]:
				for z in [-10.5, -7.5, -4.5, -1.5]:
					_paint(Vector3(x, 0, z), Vector3(0.16, 0.016, 1.6), "violet_paint")
			# HQ's unblocked southern exit receives a quiet fallback direction.
			for x in [-1.0, 1.0]:
				for z in [14.2, 17.2, 20.2]:
					_paint(Vector3(x, 0, z), Vector3(0.11, 0.016, 1.2), "violet_paint")
			_arrow(Vector3(0, 0, 18), PI, "violet_paint")

func _paint(p: Vector3, size: Vector3, mat: String, height_offset: float = 0.0) -> void:
	_box(p + Vector3(0, 0.084 + height_offset, 0), size, mat)

func _arrow(p: Vector3, angle: float, mat: String) -> void:
	var rotation_basis := Basis(Vector3.UP, angle)
	for side in [-1.0, 1.0]:
		var center := p + rotation_basis * Vector3(side * 0.32, 0.097, 0)
		_box(center, Vector3(0.15, 0.018, 0.95), mat, Vector3(0, angle + side * PI * 0.25, 0))

func _box(p: Vector3, size: Vector3, mat: String, rotation: Vector3 = Vector3.ZERO) -> void:
	_batch("box", mat, Transform3D(Basis.from_euler(rotation) * Basis.from_scale(size), p))

func _cylinder(p: Vector3, size: Vector3, mat: String, rotation: Vector3 = Vector3.ZERO) -> void:
	# Local scaling precedes rotation so a horizontal pipe retains its radius.
	_batch("cylinder", mat, Transform3D(Basis.from_euler(rotation) * Basis.from_scale(size), p))

func _batch(shape: String, mat: String, transform: Transform3D) -> void:
	var key := shape + ":" + mat
	if not _batches.has(key):
		_batches[key] = []
	_batches[key].append(transform)

func _flush_batches() -> void:
	for key in _batches:
		var parts: PackedStringArray = key.split(":")
		var primitive: PrimitiveMesh
		if parts[0] == "cylinder":
			var cylinder := CylinderMesh.new()
			cylinder.top_radius = 1.0
			cylinder.bottom_radius = 1.0
			cylinder.height = 1.0
			cylinder.radial_segments = 12
			primitive = cylinder
		else:
			var cube := BoxMesh.new()
			cube.size = Vector3.ONE
			primitive = cube
		primitive.material = _materials[parts[1]]
		var multimesh := MultiMesh.new()
		multimesh.transform_format = MultiMesh.TRANSFORM_3D
		multimesh.mesh = primitive
		multimesh.instance_count = _batches[key].size()
		for i in range(multimesh.instance_count):
			multimesh.set_instance_transform(i, _batches[key][i])
		var mesh_instance := MultiMeshInstance3D.new()
		mesh_instance.name = "Mission_%d_%s_%s" % [_mission_index + 1, parts[0], parts[1]]
		mesh_instance.multimesh = multimesh
		if parts[1] in ["teal_paint", "amber_paint", "violet_paint", "ivory"]:
			mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mesh_instance)
	_batches.clear()
