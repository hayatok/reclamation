extends RefCounted
## Drop-in art helper: local visual only. Call only for art_kind == "pump".
## Runtime placement: copy GLB to res://assets/models/water_station.glb.
## Does not change root transforms, gameplay, site labels, selection rings or navigation.
const MODEL_PATH := "res://assets/models/water_station.glb"
static var _scene: PackedScene

static func add_to(parent: Node3D) -> Node3D:
	if _scene == null:
		_scene = load(MODEL_PATH) as PackedScene
	if _scene == null:
		return null
	var visual := _scene.instantiate() as Node3D
	visual.name = "WaterStationVisual"
	parent.add_child(visual)
	return visual

## Optional small visual hook for the EXISTING site.reclaimed state.
## Adds one 2-triangle indicator surface when on; no light and no state mutation.
## Omit this call entirely for the strict one-draw-call static asset.
static func set_reclaimed(visual: Node3D, reclaimed: bool) -> void:
	var lens := visual.get_node_or_null("RestoredFlowLens") as MeshInstance3D
	if lens == null and reclaimed:
		lens = MeshInstance3D.new()
		lens.name = "RestoredFlowLens"
		var quad := QuadMesh.new()
		quad.size = Vector2(0.087, 0.087)
		lens.mesh = quad
		var material := StandardMaterial3D.new()
		material.albedo_color = Color("9fb78b")
		material.roughness = 0.8
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		lens.material_override = material
		lens.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		lens.position = Vector3(1.36, 1.36, -0.974)
		visual.add_child(lens)
	if lens != null:
		lens.visible = reclaimed
