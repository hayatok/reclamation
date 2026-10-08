extends RefCounted
## Original visual-only freight art. Existing blocker and site state stay in callers.
## Copy assets/*.glb + assets/*.png into res://assets/models before use.
const GANTRY := "freight_transfer_gantry"
const COVER := ["ruined_freight_teal", "ruined_freight_oxide"]
static var _scenes: Dictionary = {}
static var _shared_material: BaseMaterial3D

static func _instantiate(asset: String) -> Node3D:
	if not _scenes.has(asset):
		_scenes[asset] = load("res://assets/models/" + asset + ".glb") as PackedScene
	var scene := _scenes[asset] as PackedScene
	if scene == null:
		return null
	var instance := scene.instantiate() as Node3D
	_share_material(instance)
	return instance

static func _share_material(node: Node) -> void:
	if node is MeshInstance3D:
		var mesh_instance := node as MeshInstance3D
		if mesh_instance.mesh != null and mesh_instance.mesh.get_surface_count() == 1:
			if _shared_material == null:
				_shared_material = mesh_instance.mesh.surface_get_material(0) as BaseMaterial3D
				if _shared_material != null:
					_shared_material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
			if _shared_material != null:
				mesh_instance.material_override = _shared_material
	for child in node.get_children():
		_share_material(child)

static func add_cover(parent: Node3D, ground_center: Vector3, size: Vector3, index: int) -> Node3D:
	var visual := _instantiate(COVER[absi(index) % COVER.size()])
	if visual == null:
		return null
	visual.name = "RuinedFreight_%02d" % index
	var along_x: bool = size.x >= size.z
	var length: float = size.x if along_x else size.z
	var width: float = size.z if along_x else size.x
	visual.scale = Vector3(length / 6.0, size.y / 1.3, width / 2.5)
	visual.rotation.y = 0.0 if along_x else PI * 0.5
	visual.position = ground_center
	parent.add_child(visual)
	return visual

static func add_to(parent: Node3D) -> Node3D:
	var visual := _instantiate(GANTRY)
	if visual == null:
		return null
	visual.name = "FreightTransferVisual"
	parent.add_child(visual)
	return visual

## Optional two-triangle non-emissive cue. Reads existing reclaimed state only.
## No real light, shadow, animation, physics or cargo/navigation change.
static func set_reclaimed(visual: Node3D, reclaimed: bool) -> void:
	var lens := visual.get_node_or_null("CargoReadyLens") as MeshInstance3D
	if lens == null and reclaimed:
		lens = MeshInstance3D.new()
		lens.name = "CargoReadyLens"
		var quad := QuadMesh.new()
		quad.size = Vector2(0.21, 0.075)
		lens.mesh = quad
		var material := StandardMaterial3D.new()
		material.albedo_color = Color("a6b88a")
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.roughness = 1.0
		lens.material_override = material
		lens.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		lens.position = Vector3(-1.66, 1.16, 0.550)
		visual.add_child(lens)
	if lens != null:
		lens.visible = reclaimed
