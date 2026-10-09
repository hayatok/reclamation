extends RefCounted
## Original indexed warehouse / fused fungal mantle. Static, two opaque surfaces.
## Baked asset colors are linear RGB; no reliance on Compatibility's sRGB flag.
## Public contract: create() -> Node3D; set_state(root, dead, alarm) -> void.

const AliveScene = preload("res://assets/models/infected_warehouse_alive.glb")
const DeadScene = preload("res://assets/models/infected_warehouse_dead.glb")
const InfectionShader = preload("res://infected_warehouse_material.gdshader")
const FibreTexture = preload("res://assets/materials/infected_fibre.png")
static var _shell_material: StandardMaterial3D
static var _spent_material: ShaderMaterial

static func create() -> Node3D:
	_ensure_materials()
	var root := Node3D.new()
	root.name = "FrontierInfectedNest"
	var intact: Node3D = AliveScene.instantiate()
	intact.name = "Intact"
	root.add_child(intact)
	var core := _infection_material()
	intact.get_node("WarehouseShell").material_override = _shell_material
	intact.get_node("Infection").material_override = core
	var rubble: Node3D = DeadScene.instantiate()
	rubble.name = "Rubble"
	root.add_child(rubble)
	rubble.get_node("BrokenWarehouse").material_override = _shell_material
	rubble.get_node("SpentInfection").material_override = _spent_material
	rubble.visible = false
	root.set_meta("frontier_core_material", core)
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
	var core: ShaderMaterial = root.get_meta("frontier_core_material")
	# The UV2 mask is authored only on the interior recess. No flashing or lights.
	core.set_shader_parameter("alarm", 1.0 if active_alarm else 0.0)

static func _ensure_materials() -> void:
	if _shell_material != null:
		return
	_shell_material = StandardMaterial3D.new()
	_shell_material.vertex_color_use_as_albedo = true
	_shell_material.vertex_color_is_srgb = false
	_shell_material.roughness = 0.97
	_shell_material.metallic_specular = 0.16
	_shell_material.albedo_texture = load("res://assets/materials/ruined_plaster.png")
	_shell_material.uv1_triplanar = true
	_shell_material.uv1_world_triplanar = true
	_shell_material.uv1_scale = Vector3(0.18, 0.18, 0.18)
	_shell_material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	_spent_material = _infection_material()

static func _infection_material() -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = InfectionShader
	material.set_shader_parameter("fibre_texture", FibreTexture)
	material.set_shader_parameter("alarm", 0.0)
	return material
