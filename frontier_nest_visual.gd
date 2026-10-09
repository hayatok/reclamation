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
	root.set_meta("frontier_art_dead", dead)
	root.set_meta("frontier_art_alarm", alarm and not dead)
	_apply_observation(root)

## A known static structure remains as remembered terrain when scouts leave.
## Live alarm/damage state is never used to update that remembered appearance.
static func set_observed(root: Node3D, known: bool, in_sight: bool) -> void:
	root.visible = known or in_sight
	root.set_meta("frontier_art_in_sight", in_sight)
	_apply_observation(root)

static func _apply_observation(root: Node3D) -> void:
	var in_sight := bool(root.get_meta("frontier_art_in_sight", true))
	var dead := bool(root.get_meta("frontier_art_dead", false))
	if in_sight: root.set_meta("frontier_art_remembered_dead", dead)
	var displayed_dead := dead if in_sight else bool(root.get_meta("frontier_art_remembered_dead", false))
	var active_alarm := in_sight and not displayed_dead and bool(root.get_meta("frontier_art_alarm", false))
	var display_state := int(displayed_dead) * 2 + int(active_alarm)
	if int(root.get_meta("frontier_art_display", -1)) == display_state: return
	root.set_meta("frontier_art_display", display_state)
	root.get_node("Intact").visible = not displayed_dead
	root.get_node("Rubble").visible = displayed_dead
	var core: ShaderMaterial = root.get_meta("frontier_core_material")
	# Only the authored interior can glow, and only in current friendly sight.
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
