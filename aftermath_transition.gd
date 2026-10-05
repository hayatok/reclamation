extends ColorRect
## A short world-only dissolve. The result panel is a later sibling, so its
## controls remain visible and usable throughout. Owns no gameplay state.
signal midpoint

const FADE_OUT: float = 0.20
const FADE_IN: float = 0.35
const DURATION: float = FADE_OUT + FADE_IN
const SHADE := Color("171b16")

var elapsed: float = 0.0
var settled: bool = false
var complete: bool = false

func setup() -> void:
	name = "AftermathTransition"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_mode = Control.FOCUS_NONE
	color = Color(SHADE, 0.0)
	set_process(true)

func _process(delta: float) -> void:
	if complete or not is_finite(delta) or delta < 0.0:
		return
	var next: float = elapsed + minf(delta, 0.25)
	# Present one fully covered frame when crossing the midpoint, even when a
	# long frame would otherwise skip directly into the reveal.
	if not settled and next >= FADE_OUT:
		next = FADE_OUT
	sample_at(next)

## Deterministic review hook. Midpoint is emitted once; this never rewinds state.
func sample_at(seconds: float) -> void:
	if complete or not is_finite(seconds):
		return
	elapsed = clampf(seconds, elapsed, DURATION)
	if not settled and elapsed >= FADE_OUT:
		color.a = 1.0
		settled = true
		midpoint.emit()
	color.a = smoothstep(0.0, FADE_OUT, elapsed) if elapsed <= FADE_OUT else 1.0 - smoothstep(FADE_OUT, DURATION, elapsed)
	complete = elapsed >= DURATION
	if complete:
		hide()
		set_process(false)

## Hide roots only. Keep actors, shell trajectories, pending damage and records
## intact; in particular, never kill, despawn, award XP or empty game arrays.
static func hide_combat_visuals(collections: Array, combat_fx: Node) -> void:
	for collection: Array in collections:
		for record: Dictionary in collection:
			var visual: Variant = record.get("node")
			if is_instance_valid(visual) and visual is Node3D:
				visual.hide()
	if is_instance_valid(combat_fx) and combat_fx is Node3D:
		combat_fx.hide()
