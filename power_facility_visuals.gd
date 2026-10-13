extends RefCounted
## Visual-only facility loader. Does not mutate parent transforms or gameplay.
const MODEL_PATHS := {
	"central_station": "res://assets/models/central_station.glb",
	"substation": "res://assets/models/substation.glb",
}
static var _scenes: Dictionary = {}

static func add_to(parent: Node3D, kind: String) -> Node3D:
	if not MODEL_PATHS.has(kind):
		return null
	if not _scenes.has(kind):
		var packed := load(MODEL_PATHS[kind]) as PackedScene
		if packed == null:
			return null
		_scenes[kind] = packed
	var visual := (_scenes[kind] as PackedScene).instantiate() as Node3D
	visual.name = "CentralStationVisual" if kind == "central_station" else "RefugeSubstationVisual"
	parent.add_child(visual)
	return visual

static func set_central_operational(parent: Node3D, operational: bool) -> void:
	var visual := parent.get_node_or_null("CentralStationVisual") as Node3D
	if visual == null or visual.get_meta("station_operational", true) == operational: return
	visual.set_meta("station_operational", operational)
	# Per-instance overrides keep the shared model/portrait materials untouched.
	for child in visual.find_children("*", "MeshInstance3D", true, false):
		var mesh := child as MeshInstance3D
		if mesh.mesh == null: continue
		if operational:
			var originals: Array = mesh.get_meta("station_original_overrides", [])
			for index in originals.size(): mesh.set_surface_override_material(index, originals[index])
			mesh.remove_meta("station_original_overrides")
		else:
			var originals: Array = []
			for index in mesh.mesh.get_surface_count():
				originals.append(mesh.get_surface_override_material(index))
				var source := mesh.get_active_material(index) as BaseMaterial3D
				if source == null: continue
				var muted := source.duplicate() as BaseMaterial3D
				muted.albedo_color *= Color(0.45, 0.45, 0.45)
				muted.emission_enabled = false
				mesh.set_surface_override_material(index, muted)
			mesh.set_meta("station_original_overrides", originals)
