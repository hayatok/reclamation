extends SceneTree

const Art = preload("res://frontier_nest_visual.gd")

func _initialize() -> void:
	var first := Art.create()
	var second := Art.create()
	root.add_child(first)
	root.add_child(second)
	var states := {}
	for state_name in ["Intact", "Rubble"]:
		var state := first.get_node(state_name)
		assert(state.get_child_count() == 2)
		var triangles := 0
		var surfaces := 0
		var radius := 0.0
		var max_y := 0.0
		for child: MeshInstance3D in state.get_children():
			assert(child.mesh.get_surface_count() == 1)
			surfaces += child.mesh.get_surface_count()
			var arrays := child.mesh.surface_get_arrays(0)
			triangles += arrays[Mesh.ARRAY_INDEX].size() / 3
			for v: Vector3 in arrays[Mesh.ARRAY_VERTEX]:
				radius = maxf(radius, Vector2(v.x,v.z).length())
				max_y = maxf(max_y,v.y)
			assert(child.material_override != null)
			assert(child.get_child_count() == 0)
		assert(triangles <= 6000)
		assert(radius <= 4.5)
		states[state_name] = {"triangles":triangles,"opaque_surfaces":surfaces,"horizontal_radius":radius,"max_y":max_y}
	assert(first.get_node("Intact").visible)
	assert(not first.get_node("Rubble").visible)
	var core: ShaderMaterial = first.get_meta("frontier_core_material")
	var second_core: ShaderMaterial = second.get_meta("frontier_core_material")
	assert(core != second_core)
	var shell_material: Material = first.get_node("Intact/WarehouseShell").material_override
	Art.set_state(first,false,true)
	assert(core.get_shader_parameter("alarm") == 1.0)
	assert(second_core.get_shader_parameter("alarm") == 0.0)
	assert(first.get_node("Intact/WarehouseShell").material_override == shell_material)
	Art.set_state(first,true,true)
	assert(not first.get_node("Intact").visible)
	assert(first.get_node("Rubble").visible)
	assert(core.get_shader_parameter("alarm") == 0.0)
	assert(not first.get_meta("frontier_art_alarm"))
	Art.set_state(first,false,false)
	assert(first.get_node("Intact").visible)
	assert(not first.get_node("Rubble").visible)
	assert(not first.get_meta("frontier_art_dead"))
	var tex: Texture2D = load("res://assets/materials/infected_fibre.png")
	assert(tex.get_image().has_mipmaps())
	states["checks"] = {"per_instance_alarm":true,"alarm_clears_on_death":true,"architecture_material_unchanged":true,"alive_dead_alive_roundtrip":true,"texture_mipmaps":true,"no_runtime_children_on_meshes":true}
	var f := FileAccess.open("user://infected_warehouse_contract.json",FileAccess.WRITE)
	f.store_string(JSON.stringify(states,"\t"));f.close()
	print("INFECTED_WAREHOUSE_CONTRACT_PASS ",JSON.stringify(states))
	first.free();second.free()
	quit()
