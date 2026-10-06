extends SceneTree
## Actual Input.parse_input_event + flush fixture, not direct reducer calls.
const Guard = preload("res://mobile_gui_guard.gd")

class GateNode extends Node:
	var guard = Guard.new()
	var observed_down: Array[String] = []
	var consumed_releases: int = 0
	func _input(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed:
			var hovered: Control = get_viewport().gui_get_hovered_control()
			observed_down.append(hovered.name if hovered != null else "none")
		if guard.before_input(event, get_viewport()):
			consumed_releases += 1

var gate: GateNode
var a: Button
var b: Button
var a_clicks: int = 0
var b_clicks: int = 0
var b_toggles: int = 0
var button_ups: int = 0
var failures: int = 0


func _initialize() -> void:
	call_deferred("_check")


func _check() -> void:
	root.size = Vector2i(400, 220)
	root.content_scale_size = Vector2i(400, 220)
	Input.emulate_touch_from_mouse = false
	Input.emulate_mouse_from_touch = true
	gate = GateNode.new()
	root.add_child(gate)
	a = _button("A", Vector2(20, 20))
	b = _button("B", Vector2(220, 20))
	b.toggle_mode = true
	a.pressed.connect(func(): a_clicks += 1)
	b.pressed.connect(func(): b_clicks += 1)
	b.toggled.connect(func(_value): b_toggles += 1)
	a.button_up.connect(func(): button_ups += 1)
	await process_frame
	await process_frame

	# No preceding MouseMotion: input dispatch must update hover on touch down.
	_touch(5, Vector2(50, 50), true)
	_expect(gate.observed_down.back() == "A", "hover is updated before _input with no prior motion")
	_expect(a.button_pressed, "ordinary emulated down reaches FOCUS_NONE Button")
	gate.guard.cancel_interaction()
	_expect(not a.button_pressed and not a.disabled, "cancel clears pressed visual and restores enabled state")
	_expect(button_ups == 1, "cancel sends button_up for tile visual cleanup")
	_touch(5, Vector2(50, 50), false)
	_expect(a_clicks == 0 and gate.consumed_releases == 1, "browser-style ordinary release after cancel cannot click")

	_touch(8, Vector2(50, 50), true)
	_touch(8, Vector2(50, 50), false)
	_expect(a_clicks == 1, "next fresh touch clicks once")
	# Jump to B without mouse motion to reject stale-hover tracking.
	_touch(11, Vector2(250, 50), true)
	_expect(gate.observed_down.back() == "B", "touch press updates hover when jumping between Buttons")
	gate.guard.cancel_interaction()
	_touch(11, Vector2(250, 50), false)
	_expect(b_clicks == 0 and b_toggles == 0 and not b.button_pressed, "canceled toggle does not activate")
	_touch(12, Vector2(250, 50), true)
	_touch(12, Vector2(250, 50), false)
	_expect(b_clicks == 1 and b_toggles == 1 and b.button_pressed, "fresh toggle activates once")
	_touch(13, Vector2(250, 50), true)
	gate.guard.cancel_interaction()
	_touch(13, Vector2(250, 50), false)
	_expect(b_clicks == 1 and b_toggles == 1 and b.button_pressed, "cancel preserves already selected toggle")

	_touch(15, Vector2(50, 50), true)
	_touch(15, Vector2(50, 50), false, true)
	_expect(a_clicks == 1 and not a.button_pressed, "native canceled flag is gated before raw ScreenTouch")
	# Interruption can lose its physical release. Fresh press still recovers.
	gate.guard.cancel_interaction()
	_touch(16, Vector2(50, 50), true)
	_touch(16, Vector2(50, 50), false)
	_expect(a_clicks == 2, "cancel without an active touch does not swallow next tap")

	gate.guard.cancel_interaction()
	_mouse(Vector2(50, 50), true)
	_mouse(Vector2(50, 50), false)
	_expect(a_clicks == 3, "real mouse is unaffected by touch cancellation latch")
	# UI ownership is captured on down; leaving the button before interruption
	# still clears the originally pressed button, not the hovered world.
	_touch(18, Vector2(50, 50), true)
	_drag(18, Vector2(160, 160))
	gate.guard.cancel_interaction()
	_touch(18, Vector2(160, 160), false)
	_expect(a_clicks == 3 and not a.button_pressed, "cancel after dragging off button clears original press")
	var temporary: Button = _button("Temporary", Vector2(220, 125))
	_touch(20, Vector2(250, 155), true)
	temporary.free()
	gate.guard.cancel_interaction()
	_touch(20, Vector2(250, 155), false)
	_touch(21, Vector2(50, 50), true)
	_touch(21, Vector2(50, 50), false)
	_expect(a_clicks == 4, "freed pressed button cancels safely and next tap works")
	print("Mobile GUI guard fixture: ", "PASS" if failures == 0 else "FAIL", " (", failures, " failures)")
	quit(1 if failures else 0)


func _button(label: String, at: Vector2) -> Button:
	var result: Button = Button.new()
	result.name = label
	result.text = label
	result.position = at
	result.size = Vector2(120, 70)
	result.focus_mode = Control.FOCUS_NONE
	root.add_child(result)
	return result


func _touch(index: int, position: Vector2, pressed: bool, canceled: bool = false) -> void:
	var event: InputEventScreenTouch = InputEventScreenTouch.new()
	event.index = index
	event.position = position
	event.pressed = pressed
	event.canceled = canceled
	Input.parse_input_event(event)
	Input.flush_buffered_events()


func _drag(index: int, position: Vector2) -> void:
	var event: InputEventScreenDrag = InputEventScreenDrag.new()
	event.index = index
	event.position = position
	Input.parse_input_event(event)
	Input.flush_buffered_events()


func _mouse(position: Vector2, pressed: bool) -> void:
	var event: InputEventMouseButton = InputEventMouseButton.new()
	event.position = position
	event.global_position = position
	event.button_index = MOUSE_BUTTON_LEFT
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()


func _expect(condition: bool, label: String) -> void:
	if condition:
		print("PASS ", label)
	else:
		failures += 1
		push_error(label)
