extends SceneTree

func _initialize() -> void:
    var entries: Array = []
    for name in ["siege_cart", "siege_cart_lod1", "siege_cart_lod2"]:
        var resource = load("res://assets/" + name + ".glb")
        assert(resource is PackedScene, "Failed import " + name)
        var node: Node3D = resource.instantiate()
        var meshes = node.find_children("*", "MeshInstance3D", true, false)
        assert(meshes.size() == 1, "One runtime mesh expected")
        var mi: MeshInstance3D = meshes[0]
        assert(mi.mesh.get_surface_count() == 1, "Single material draw surface expected")
        var material: StandardMaterial3D = mi.mesh.surface_get_material(0)
        assert(material != null)
        assert(material.albedo_texture != null)
        assert(material.normal_enabled and material.normal_texture != null)
        assert(material.roughness_texture != null and material.metallic_texture != null)
        var aabb: AABB = mi.transform * mi.get_aabb()
        assert(aabb.position.y >= -0.002)
        assert(aabb.end.y < 2.50)
        assert(aabb.size.x >= 2.3 and aabb.size.x < 2.8)
        assert(aabb.size.z >= 3.5 and aabb.size.z < 4.1)
        var arrays = mi.mesh.surface_get_arrays(0)
        var tris: int = arrays[Mesh.ARRAY_INDEX].size() / 3
        if name == "siege_cart":
            assert(tris >= 6000 and tris <= 12000)
        entries.append({"asset": name, "surfaces": 1, "triangles": tris, "aabb_min": [aabb.position.x,aabb.position.y,aabb.position.z], "aabb_max": [aabb.end.x,aabb.end.y,aabb.end.z], "pbr_textures_valid": true})
        node.free()
    var out = FileAccess.open("res://reports/godot_import_check.json", FileAccess.WRITE)
    out.store_string(JSON.stringify({"pass":true,"engine":Engine.get_version_info().string,"assets":entries},"  "))
    print("SIEGE_CART_GODOT_IMPORT_CHECK_PASS ", JSON.stringify(entries))
    quit(0)
