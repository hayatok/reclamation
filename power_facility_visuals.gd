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
