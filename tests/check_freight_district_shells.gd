extends SceneTree
## Focused geometry contract check; this cannot establish visual art acceptance.
const Frontier = preload("res://frontier_world.gd")
const FreightShells = preload("res://freight_district_shells.gd")
var failures: int = 0

func _initialize() -> void:
	call_deferred("run")

func check(value: bool, label: String) -> void:
	if not value:
		failures += 1
	print("PASS " if value else "FAIL ", label)

func run() -> void:
	var art = Frontier.new()
	art._built = true
	root.add_child(art)
	art._make_surface_textures()
	art._make_materials()
	var found: int = 0
	var all_vertices: int = 0
	for shell: Dictionary in Frontier.shell_layout():
		if not FreightShells.handles(shell.id):
			continue
		var first: int = art.occlusion_buildings.size()
		FreightShells.build(art, shell)
		check(art.occlusion_buildings.size() == first + 1, shell.id + " creates one fade record")
		var record: Dictionary = art.occlusion_buildings.back()
		var bounds: AABB = record.local_bounds
		var foundation: Dictionary = Frontier.shell_blocker(shell)
		var floor_low: Vector3 = foundation.pos - foundation.size * 0.5
		var floor_high: Vector3 = foundation.pos + foundation.size * 0.5
		check(bounds.position.x >= floor_low.x and bounds.end.x <= floor_high.x and
			bounds.position.z >= floor_low.z and bounds.end.z <= floor_high.z,
			shell.id + " all geometry remains inside authoritative foundation")
		check(bounds.position.y >= -0.001 and bounds.end.y <= shell.size.y + 0.001,
			shell.id + " stays within original vertical size")
		check(record.meshes.size() >= 1 and record.meshes.size() <= 2 and
			record.materials.size() == record.meshes.size(), shell.id + " uses original bounded bake")
		var vertices: int = 0
		for mesh: MeshInstance3D in record.meshes:
			check(mesh.mesh.get_surface_count() == 1, shell.id + " one surface per baked mesh")
			vertices += mesh.mesh.surface_get_array_len(0)
		all_vertices += vertices
		art.set_building_fade(first, 0.30)
		var faded: bool = true
		for material: StandardMaterial3D in record.materials:
			faded = (faded and is_equal_approx(material.albedo_color.a, 0.30) and
				material.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA)
		art.set_building_fade(first, 1.0)
		for material: StandardMaterial3D in record.materials:
			faded = (faded and is_equal_approx(material.albedo_color.a, 1.0) and
				material.transparency == BaseMaterial3D.TRANSPARENCY_DISABLED)
		check(faded, shell.id + " original per-building fade works and restores")
		print("GEOMETRY ", shell.id, " vertices=", vertices, " meshes=", record.meshes.size(), " bounds=", bounds)
		found += 1
	check(found == 3, "exactly three freight identities")
	check(art.get_child_count() == 4, "three solid meshes and dispatch glazing only")
	check(art._batches.is_empty() and art._captured_parts.is_empty() and not art._capturing_building,
		"no uncaptured geometry or incomplete bake remains")
	print("FREIGHT_SHELL_CONTRACT failures=", failures, " vertices=", all_vertices)
	art.free()
	quit(1 if failures else 0)
