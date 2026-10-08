extends "res://world_art.gd"
## Original frontier layout, using the project-owned ruined shells and freight art.
## The static blocker list is authoritative for navigation and visible foundations.
## This node creates art only. The host owns all movement, physics, fog and gameplay.

const FreightVisuals = preload("res://freight_yard_visuals.gd")
const PLAYABLE_BOUNDS := Rect2(-96, -80, 192, 160)
const TERRAIN_SIZE := Vector2(200, 168)
const HOME := Vector3(-64, 0, 48)
const GENERATOR := Vector3(-42, 0, 32)
const ENEMY_NEST := Vector3(62, 0, -48)
const BRIDGE_CENTERS := [-32.0, 32.0]

static func canal_blockers() -> Array:
	return [
		{"id": "canal_north", "kind": "water", "pos": Vector3(0, 0, -60), "size": Vector3(14, 1, 40)},
		{"id": "canal_center", "kind": "water", "pos": Vector3(0, 0, 0), "size": Vector3(14, 1, 48)},
		{"id": "canal_south", "kind": "water", "pos": Vector3(0, 0, 60), "size": Vector3(14, 1, 40)},
	]

static func shell_layout() -> Array:
	# Ground centers, original shell dimensions, floor count. Four district groups.
	return [
		{"id": "survivor_row", "district": "survivor", "pos": Vector3(-86, 0, 60), "size": Vector3(9, 5.8, 10), "stories": 2},
		{"id": "survivor_corner", "district": "survivor", "pos": Vector3(-83, 0, 18), "size": Vector3(10, 8.0, 12), "stories": 2},
		{"id": "survivor_workshop", "district": "survivor", "pos": Vector3(-39, 0, 66), "size": Vector3(12, 6.6, 9), "stories": 2},
		{"id": "salvage_foundry", "district": "salvage", "pos": Vector3(-78, 0, -55), "size": Vector3(12, 10.4, 12), "stories": 3},
		{"id": "salvage_stores", "district": "salvage", "pos": Vector3(-51, 0, -66), "size": Vector3(11, 8.4, 11), "stories": 2},
		{"id": "salvage_pump_house", "district": "salvage", "pos": Vector3(-29, 0, -53), "size": Vector3(10, 6.9, 10), "stories": 2},
		{"id": "salvage_gate", "district": "salvage", "pos": Vector3(-80, 0, -9), "size": Vector3(9, 7.4, 12), "stories": 2},
		{"id": "freight_warehouse", "district": "freight", "pos": Vector3(81, 0, 59), "size": Vector3(12, 6.8, 11), "stories": 2},
		{"id": "freight_office", "district": "freight", "pos": Vector3(74, 0, 17), "size": Vector3(12, 8.2, 12), "stories": 2},
		{"id": "freight_annex", "district": "freight", "pos": Vector3(36, 0, 67), "size": Vector3(11, 5.4, 9), "stories": 2},
		{"id": "port_silo_house", "district": "port", "pos": Vector3(82, 0, -62), "size": Vector3(11, 12.0, 12), "stories": 3},
		{"id": "port_customs", "district": "port", "pos": Vector3(34, 0, -63), "size": Vector3(10, 9.0, 11), "stories": 3},
		{"id": "port_gate", "district": "port", "pos": Vector3(83, 0, -14), "size": Vector3(10, 7.0, 12), "stories": 2},
		{"id": "port_quay", "district": "port", "pos": Vector3(28, 0, -9), "size": Vector3(9, 6.0, 10), "stories": 2},
	]

static func freight_blockers() -> Array:
	return [
		{"id": "freight_00", "kind": "freight", "pos": Vector3(29, 0, 54), "size": Vector3(8, 1.3, 2.5)},
		{"id": "freight_01", "kind": "freight", "pos": Vector3(40, 0, 48), "size": Vector3(7, 1.3, 2.5)},
		{"id": "freight_02", "kind": "freight", "pos": Vector3(67, 0, 47), "size": Vector3(8, 1.3, 2.5)},
		{"id": "freight_03", "kind": "freight", "pos": Vector3(80, 0, 39), "size": Vector3(6, 1.3, 2.5)},
		{"id": "freight_04", "kind": "freight", "pos": Vector3(39, 0, 7), "size": Vector3(2.5, 1.15, 8)},
		{"id": "freight_05", "kind": "freight", "pos": Vector3(60, 0, 65), "size": Vector3(8, 1.3, 2.5)},
	]

static func shell_blocker(shell: Dictionary) -> Dictionary:
	# The baked shell's broken canopy and plinth fit on this explicit foundation.
	# Visible foundation and registered blocker use this identical rectangle.
	return {"id": shell.id, "kind": "shell", "pos": shell.pos + Vector3(0.4, 0, 0.4), "size": shell.size + Vector3(2.0, 0, 1.6)}

static func blockers() -> Array:
	var result := canal_blockers()
	for shell: Dictionary in shell_layout():
		result.append(shell_blocker(shell))
	result.append_array(freight_blockers())
	return result

static func layout_contract() -> Dictionary:
	return {
		"playable_bounds": PLAYABLE_BOUNDS,
		"terrain_size": TERRAIN_SIZE,
		"home": HOME, "generator": GENERATOR, "enemy_nest": ENEMY_NEST,
		"bridge_centers": [Vector3(0, 0, -32), Vector3(0, 0, 32)],
		"bridge_size": Vector3(20, 0.16, 16),
		"bridge_open_cell_rows": [Vector2i(-38, -26), Vector2i(26, 38)],
		"forward_pad_centers": [Vector3(-20, 0, -32), Vector3(20, 0, -32), Vector3(-20, 0, 32), Vector3(20, 0, 32)],
		"forward_pad_size": Vector2(12, 12),
		"blockers": blockers(),
	}

func _make_surface_textures() -> void:
	# Retain the original shell plaster, with flat untextured terrain and road mats.
	_surface_textures["plaster"] = load("res://assets/materials/ruined_plaster.png")
	_surface_textures["yard"] = null
	for key in ["masonry", "asphalt", "metal", "marking"]:
		_surface_textures[key] = null

func _make_materials() -> void:
	super._make_materials()
	_material("ground", "#596360", 1.0)
	_material("road", "#354044", 1.0)
	_material("canal_water", "#172c31", 1.0)
	_material("canal_wall", "#434e4d", 1.0)
	_material("district_survivor", "#626b61", 1.0)
	_material("district_salvage", "#666b67", 1.0)
	_material("district_freight", "#626562", 1.0)
	_material("district_port", "#515d58", 1.0)
	_material("stain_oil", "#394644", 1.0)
	_material("stain_moss", "#4c5d49", 1.0)
	_material("stain_dust", "#73776e", 1.0)
	_material("quay_mark", "#92947e", 1.0)

func _make_atmosphere() -> void:
	# Exactly one shared environment and its original two directional lights.
	super._make_atmosphere()
	var environment_node := get_node("DistrictAtmosphere") as WorldEnvironment
	environment_node.environment.fog_density = 0.0012
	var sun := get_node("LateAfternoonThroughSmog") as DirectionalLight3D
	sun.directional_shadow_max_distance = 140.0

func _make_ground() -> void:
	_box(Vector3(0, -0.64, 0), Vector3(200, 0.78, 168), "edge")
	# The two banks stop exactly at the canal edges. No road-colored water surface.
	for x in [-53.5, 53.5]:
		_box(Vector3(x, -0.18, 0), Vector3(93, 0.16, 168), "ground")
	# Broad, quiet district tones: deliberately no fine repeating noise layer.
	for entry in [[Vector3(-53.5, 0, 43), Vector3(93, 0.02, 82), "district_survivor"],
		[Vector3(-53.5, 0, -43), Vector3(93, 0.02, 82), "district_salvage"],
		[Vector3(53.5, 0, 43), Vector3(93, 0.02, 82), "district_freight"],
		[Vector3(53.5, 0, -43), Vector3(93, 0.02, 82), "district_port"]]:
		_box(entry[0] + Vector3(0, -0.092, 0), entry[1], entry[2])
	# Exact visible water rectangles match the three movement blockers.
	for block: Dictionary in canal_blockers():
		var size: Vector3 = block.size
		_box(block.pos + Vector3(0, -0.13, 0), Vector3(size.x, 0.04, size.z), "canal_water")
		for side in [-1.0, 1.0]:
			_box(block.pos + Vector3(side * 6.76, -0.035, 0), Vector3(0.48, 0.22, size.z), "canal_wall")
			_box(block.pos + Vector3(side * 6.72, 0.10, 0), Vector3(0.55, 0.05, size.z), "concrete_dark")
	# Visual water continues beyond the playable edge; the host bounds stop travel.
	for z in [-82.0, 82.0]:
		_box(Vector3(0, -0.13, z), Vector3(14, 0.04, 4), "canal_water")
	for z: float in BRIDGE_CENTERS:
		_make_bridge(z)
	# Open, low apron for the initial base and later bridgehead construction.
	_box(Vector3(-61, -0.041, 48), Vector3(32, 0.05, 24), "apron")
	for p: Vector3 in layout_contract().forward_pad_centers:
		_box(p + Vector3(0, -0.035, 0), Vector3(12, 0.05, 12), "apron")
		for sx in [-1.0, 1.0]:
			_box(p + Vector3(sx * 5.6, 0.04, 4.8), Vector3(0.10, 0.015, 1.6), "paint")

func _make_bridge(z: float) -> void:
	_box(Vector3(0, -0.07, z), Vector3(20, 0.16, 16), "concrete_dark")
	_box(Vector3(0, 0.02, z), Vector3(20, 0.03, 13.0), "road")
	# Rails sit at Z ±7.65 from bridge center, beyond the open center-cell rows.
	# Their whole X span remains inside the inflated canal's blocked X band.
	for side in [-1.0, 1.0]:
		_box(Vector3(0, 0.33, z + side * 7.65), Vector3(15, 0.5, 0.30), "concrete_dark")
		_box(Vector3(0, 0.60, z + side * 7.65), Vector3(15, 0.09, 0.32), "rust")
		for x in [-6.5, -3.3, 0.0, 3.3, 6.5]:
			_box(Vector3(x, 0.38, z + side * 7.65), Vector3(0.32, 0.75, 0.32), "steel")
		_box(Vector3(0, 0.05, z + side * 5.9), Vector3(19.6, 0.015, 0.10), "paint")

func _make_district() -> void:
	for shell: Dictionary in shell_layout():
		var block := shell_blocker(shell)
		_box(block.pos + Vector3(0, 0.04, 0), Vector3(block.size.x, 0.16, block.size.z), "concrete_dark")
		_building(shell.pos, shell.size, shell.stories, true)
		occlusion_buildings.back()["frontier_id"] = shell.id
	# The ruins retain individual baked meshes, materials and occlusion bounds.

func _make_roads() -> void:
	# Two continuous bridge avenues and a north/south trunk on each bank.
	for z: float in BRIDGE_CENTERS:
		_box(Vector3(-48, -0.015, z), Vector3(80, 0.055, 9.5), "road")
		_box(Vector3(48, -0.015, z), Vector3(80, 0.055, 9.5), "road")
	_box(Vector3(-60, -0.012, -2), Vector3(9.5, 0.055, 136), "road")
	_box(Vector3(52, -0.012, -3), Vector3(9.5, 0.055, 140), "road")
	# Nest approach and reclaimed base approach stay visually open.
	_box(Vector3(59, -0.008, -48), Vector3(23, 0.05, 9), "road")
	_box(Vector3(-63, -0.008, 48), Vector3(19, 0.05, 10), "road")
	for z: float in BRIDGE_CENTERS:
		for x in range(-86, 89, 6):
			_box(Vector3(x, 0.047, z), Vector3(2.0, 0.012, 0.11), "yellow")
	for x in [-60.0, 52.0]:
		for z in range(-66, 68, 7):
			if absf(float(z) - 32.0) < 7.0 or absf(float(z) + 32.0) < 7.0:
				continue
			_box(Vector3(x, 0.049, z), Vector3(0.10, 0.012, 2.0), "paint")
	# A few wide loading bars make the freight apron recognizably industrial.
	for x in [24.0, 37.0, 67.0, 80.0]:
		for z in [43.0, 44.2, 45.4]:
			_box(Vector3(x, 0.03, z), Vector3(4.2, 0.015, 0.13), "quay_mark")

func _make_ground_weathering() -> void:
	# Local broad opaque stains, no alpha sorting or texture loop.
	for entry in [
		[Vector3(-82, 0, 65), Vector2(7, 3), "stain_moss"],
		[Vector3(-35, 0, 71), Vector2(9, 5), "stain_moss"],
		[Vector3(-85, 0, -63), Vector2(7, 4), "stain_oil"],
		[Vector3(-28, 0, -61), Vector2(9, 4), "stain_oil"],
		[Vector3(-70, 0, -14), Vector2(8, 4), "stain_dust"],
		[Vector3(34, 0, 56), Vector2(12, 5), "stain_oil"],
		[Vector3(76, 0, 63), Vector2(12, 7), "stain_oil"],
		[Vector3(39, 0, 70), Vector2(9, 4), "stain_dust"],
		[Vector3(74, 0, -67), Vector2(13, 6), "stain_moss"],
		[Vector3(28, 0, -69), Vector2(11, 5), "stain_moss"],
		[Vector3(79, 0, -7), Vector2(10, 5), "stain_oil"],
	]:
		_make_stain(entry[0], entry[1], entry[2])

func _make_stain(p: Vector3, radii: Vector2, material_key: String) -> void:
	# A single original low-poly irregular silhouette, flatter than the road deck.
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var vertices: Array[Vector3] = []
	for i in range(10):
		var angle := TAU * float(i) / 10.0
		var radius := 0.86 + 0.12 * sin(float(i) * 4.9 + p.x)
		vertices.append(p + Vector3(cos(angle) * radii.x * radius, -0.055, sin(angle) * radii.y * radius))
	for i in range(10):
		for point: Vector3 in [p + Vector3(0, -0.055, 0), vertices[(i + 1) % 10], vertices[i]]:
			surface.set_normal(Vector3.UP)
			surface.add_vertex(point)
	surface.set_material(_materials[material_key])
	var mesh := MeshInstance3D.new()
	mesh.name = "BroadStain_%s_%d_%d" % [material_key, int(p.x), int(p.z)]
	mesh.mesh = surface.commit()
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mesh)

func _make_props() -> void:
	# Six exact authored freight footprints, and no decorative unregistered stacks.
	var entries := freight_blockers()
	for i in range(entries.size()):
		var block: Dictionary = entries[i]
		FreightVisuals.add_cover(self, block.pos, block.size, i)
	# A small number of dormant infrastructure pieces remain inside shell footprints.
	for p in [Vector3(-81, 0, -57), Vector3(84, 0, -65)]:
		_cylinder(p + Vector3(0, 7.0, 0), Vector3(0.56, 14.0, 0.56), "rust")
		_cylinder(p + Vector3(0, 14.03, 0), Vector3(0.59, 0.12, 0.59), "void")

func _make_ruins() -> void:
	# Eight broad fallen slabs, all inside registered shell footprints.
	for index in [0, 2, 3, 5, 7, 9, 10, 13]:
		var shell: Dictionary = shell_layout()[index]
		_box(shell.pos + Vector3(1.5, 0.4, 2), Vector3(2.8, 0.45, 1.6), "concrete", Vector3(0.13, 0.18, 0.12))

func _make_rail_siding() -> void:
	# The freight history reads from two long flush tracks, with only 18 sleepers.
	# The tracks are ground paint/shallow rails and do not create navigation blocks.
	_box(Vector3(55, -0.048, 57), Vector3(73, 0.04, 3.4), "stain_oil")
	for x in range(20, 91, 4):
		_box(Vector3(x, -0.018, 57), Vector3(0.23, 0.025, 2.4), "roof")
	for z in [56.35, 57.65]:
		_box(Vector3(55, 0.009, z), Vector3(73, 0.025, 0.11), "rust")

func _add_instance(shape: String, mat: String, transform: Transform3D) -> void:
	if _capturing_building:
		_captured_parts.append({"shape": shape, "mat": mat, "transform": transform})
		return
	# Small spatial batches can be culled individually as the camera crosses town.
	var sector := Vector2i(floori(transform.origin.x / 40.0), floori(transform.origin.z / 40.0))
	var key := "%s:%s:%d:%d" % [shape, mat, sector.x, sector.y]
	if not _batches.has(key):
		_batches[key] = []
	_batches[key].append(transform)
	# world_art._flush_batches uses the first two key fields for shape/material.
