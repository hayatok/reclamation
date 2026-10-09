extends SceneTree
const Resources = preload("res://resource_visuals.gd")
func _initialize() -> void:
	var report: Dictionary = {"generator":"Godot 4.6.3 headless", "models": {}}
	var failed: bool = false
	for kind: String in ["food", "salvage", "parts"]:
		var parent := Node3D.new()
		Resources.add_resource(parent, kind)
		var instance: MeshInstance3D = parent.get_child(0)
		var mesh: ArrayMesh = instance.mesh
		var arrays: Array = mesh.surface_get_arrays(0)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var radius: float = 0.0
		var min_y: float = INF
		var max_y: float = -INF
		var degenerate: int = 0
		for vertex: Vector3 in vertices:
			radius = maxf(radius, Vector2(vertex.x, vertex.z).length())
			min_y = minf(min_y, vertex.y)
			max_y = maxf(max_y, vertex.y)
		for i: int in range(0, indices.size(), 3):
			var a: Vector3 = vertices[indices[i]]
			var b: Vector3 = vertices[indices[i+1]]
			var c: Vector3 = vertices[indices[i+2]]
			if (b-a).cross(c-a).length_squared() < 0.00000000001:
				degenerate += 1
		Resources.add_resource(parent, kind)
		var second: MeshInstance3D = parent.get_child(1)
		var aabb: AABB = mesh.get_aabb()
		var material: StandardMaterial3D = mesh.surface_get_material(0)
		var valid: bool = mesh.get_surface_count() == 1 and indices.size() > 0 and indices.size() / 3 <= 2000 and radius <= 1.4 and absf(min_y) < .0001 and max_y <= 1.8 and degenerate == 0 and second.mesh == mesh and material.transparency == BaseMaterial3D.TRANSPARENCY_DISABLED and material.roughness >= .95
		failed = failed or not valid
		report.models[kind] = {"valid": valid, "triangles": indices.size()/3, "indexed_vertices": vertices.size(), "surfaces": mesh.get_surface_count(), "max_ground_radius": radius, "min_y": min_y, "max_y": max_y, "degenerate_triangles": degenerate, "cache_reused": second.mesh == mesh, "bounds_min": [aabb.position.x,aabb.position.y,aabb.position.z], "bounds_max": [aabb.end.x,aabb.end.y,aabb.end.z]}
		parent.free()
	report["passed"] = not failed
	var json: String = JSON.stringify(report, "  ")
	print(json)
	var file := FileAccess.open("user://bulk_resource_geometry.json", FileAccess.WRITE)
	file.store_string(json + "\n")
	quit(1 if failed else 0)
