extends RefCounted
## RECLAMATION static upgrade effect plates. Presentation only.
## API: create(exact_upgrade_id) -> Control; supported_ids() -> Array.
## Frame first child stays a TextureRect for desktop compact layout.
## No family lookup, process callbacks, RNG, timers or gameplay state.

const ROOT := "res://assets/ui/upgrades/composite/"
const PLATES := {
	"damage": "damage.svg",
	"rate": "rate.svg",
	"range": "range.svg",
	"pierce": "pierce.svg",
	"blast_radius": "blast_radius.svg",
	"crit": "crit.svg",
	"armor": "armor.svg",
	"move": "move.svg",
	"supply": "supply.svg",
	"salvage": "salvage.svg",
	"build": "build.svg",
	"power": "power.svg",
	"multi": "multi.svg",
	"chain": "chain.svg",
	"blast": "blast.svg",
	"critpower": "critpower.svg",
	"overload": "overload.svg",
	"salvo": "salvo.svg",
	"repair": "repair.svg",
	"economy": "economy.svg",
	"storm": "storm.svg",
	"cascade": "cascade.svg",
	"sweep": "sweep.svg",
	"fortress": "fortress.svg",
	"reserve": "reserve.svg",
	"field_repair": "field_repair.svg",
	"reserve2": "reserve2.svg",
}

const ART := {
	"guard": {"path": "res://assets/ui/crew_equipment_atlas.png", "region": Rect2(0, 0, 512, 512)},
	"worker": {"path": "res://assets/ui/crew_equipment_atlas.png", "region": Rect2(512, 0, 512, 512)},
	"truck": {"path": "res://assets/ui/crew_equipment_atlas.png", "region": Rect2(1024, 0, 512, 512)},
	"electric": {"path": "res://assets/ui/crew_equipment_atlas.png", "region": Rect2(0, 512, 512, 512)},
	"gun": {"path": "res://assets/ui/crew_equipment_atlas.png", "region": Rect2(512, 512, 512, 512)},
	"support": {"path": "res://assets/ui/crew_equipment_atlas.png", "region": Rect2(1024, 512, 512, 512)},
	"workshop": {"path": "res://assets/ui/portrait_vehicle_workshop.png"},
	"substation": {"path": "res://assets/ui/portrait_substation.png"},
	"depot": {"path": "res://assets/ui/portrait_depot.png"},
}

## Each upgrade chooses context explicitly; catalog progression families are untouched.
const LAYERS := {
	"damage": [["guard", Rect2(-8, 6, 150, 175)]],
	"rate": [["gun", Rect2(-7, 19, 160, 160)]],
	"range": [["guard", Rect2(-8, 6, 175, 175)]],
	"pierce": [["guard", Rect2(-8, 6, 150, 175)]],
	"blast_radius": [["guard", Rect2(-8, 6, 145, 175)]],
	"crit": [["guard", Rect2(-8, 6, 150, 175)]],
	"armor": [["guard", Rect2(-8, 6, 156, 175)]],
	"move": [["truck", Rect2(2, 16, 184, 163)]],
	"supply": [["gun", Rect2(-7, 19, 157, 160)]],
	"salvage": [["worker", Rect2(-8, 6, 150, 175)]],
	"build": [["worker", Rect2(-2, 7, 143, 143)], ["workshop", Rect2(139, 10, 151, 139)]],
	"power": [["substation", Rect2(-5, 12, 155, 172)]],
	"multi": [["gun", Rect2(-8, 20, 154, 163)]],
	"chain": [["electric", Rect2(-9, 15, 156, 170)]],
	"blast": [["guard", Rect2(-8, 6, 145, 175)]],
	"critpower": [["guard", Rect2(-8, 6, 150, 175)]],
	"overload": [["guard", Rect2(-8, 6, 150, 175)]],
	"salvo": [["gun", Rect2(-8, 20, 150, 163)]],
	"repair": [["support", Rect2(-7, 25, 157, 154)]],
	"economy": [["worker", Rect2(-8, 6, 145, 175)], ["workshop", Rect2(145, 74, 147, 99)]],
	"storm": [["electric", Rect2(-12, 17, 148, 169)]],
	"cascade": [["guard", Rect2(-12, 14, 131, 168)]],
	"sweep": [["gun", Rect2(-10, 19, 146, 166)]],
	"fortress": [["truck", Rect2(-2, 8, 199, 185)]],
	"reserve": [["depot", Rect2(-9, 12, 160, 174)]],
	"field_repair": [["support", Rect2(-7, 24, 153, 156)]],
	"reserve2": [["workshop", Rect2(-9, 22, 164, 162)]],
}

static var _textures: Dictionary = {}

static func supported_ids() -> Array:
	return PLATES.keys()

static func _texture(path: String) -> Texture2D:
	if not _textures.has(path):
		_textures[path] = load(path)
	return _textures[path] as Texture2D

static func _artwork(subject: String) -> Texture2D:
	var definition: Dictionary = ART[subject]
	var source: String = definition.path
	if not definition.has("region"):
		return _texture(source)
	var region: Rect2 = definition.region
	var key := source + str(region)
	if not _textures.has(key):
		var atlas := AtlasTexture.new()
		atlas.atlas = _texture(source)
		atlas.region = region
		atlas.filter_clip = true
		_textures[key] = atlas
	return _textures[key] as Texture2D

static func _layer(parent: Control, texture: Texture2D, bounds: Rect2, keep_aspect: bool = true) -> TextureRect:
	var layer := TextureRect.new()
	layer.texture = texture
	layer.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	layer.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED if keep_aspect else TextureRect.STRETCH_SCALE
	layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.set_meta("diagram_bounds", bounds)
	parent.add_child(layer)
	return layer

static func _layout(canvas: TextureRect) -> void:
	var factor := canvas.size / Vector2(300, 200)
	for child in canvas.get_children():
		var bounds: Rect2 = child.get_meta("diagram_bounds")
		child.position = bounds.position * factor
		child.size = bounds.size * factor

static func create(id: String) -> Control:
	var frame := PanelContainer.new()
	frame.name = "UpgradeDiagram_" + id
	frame.custom_minimum_size = Vector2(300, 210)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var skin := StyleBoxTexture.new()
	skin.texture = _texture("res://assets/ui/normal.svg")
	for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		skin.set_texture_margin(side, 19)
		skin.set_content_margin(side, 5)
	frame.add_theme_stylebox_override("panel", skin)
	var art := TextureRect.new()
	art.name = "EffectPlate"
	art.custom_minimum_size = Vector2(280, 200)
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_SCALE
	art.texture = _texture(ROOT + "backdrop.svg")
	art.clip_contents = true
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(art)
	frame.set_meta("upgrade_id", id)
	if not PLATES.has(id):
		push_warning("No upgrade effect diagram registered for exact ID: " + id)
		return frame
	for layer_data in LAYERS[id]:
		_layer(art, _artwork(str(layer_data[0])), layer_data[1] as Rect2)
	_layer(art, _texture(ROOT + str(PLATES[id])), Rect2(0, 0, 300, 200), false)
	art.resized.connect(func(): _layout(art))
	_layout(art)
	return frame
