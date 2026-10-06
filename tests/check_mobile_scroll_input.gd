extends SceneTree
## Real Input dispatch, with a ScrollContainer -> VBox -> Panel -> Button path.
## Native mouse-to-touch verifies the desktop test path. Direct ScreenTouch
## verifies device -1 mouse-from-touch cancellation, as used by Web touch.
const Guard = preload("res://mobile_gui_guard.gd")

class GateNode extends Node:
	var guard = Guard.new()
	var consumed: int = 0
	func _input(event: InputEvent) -> void:
		if guard.before_input(event, get_viewport()):
			consumed += 1

var gate: GateNode
var scroll: ScrollContainer
var buttons: Array[Button] = []
var clicks: int = 0
var started: int = 0
var ended: int = 0
var failures: int = 0


func _initialize() -> void:
	call_deferred("_check")


func _check() -> void:
	root.size = Vector2i(400, 260)
	root.content_scale_size = Vector2i(400, 260)
	Input.emulate_touch_from_mouse = true
	Input.emulate_mouse_from_touch = true
	gate = GateNode.new()
	root.add_child(gate)
	scroll = ScrollContainer.new()
	scroll.position = Vector2(20, 20)
	scroll.size = Vector2(320, 200)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.mouse_filter = Control.MOUSE_FILTER_STOP
	scroll.scroll_deadzone = 12
	root.add_child(scroll)
	var body: VBoxContainer = VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.mouse_filter = Control.MOUSE_FILTER_PASS
	scroll.add_child(body)
	for i in range(10):
		var panel: PanelContainer = PanelContainer.new()
		panel.mouse_filter = Control.MOUSE_FILTER_PASS
		panel.custom_minimum_size.y = 72
		body.add_child(panel)
		var button: Button = Button.new()
		button.text = "Action %d" % i
		button.focus_mode = Control.FOCUS_NONE
		button.mouse_filter = Control.MOUSE_FILTER_PASS
		button.pressed.connect(func(): clicks += 1)
		panel.add_child(button)
		buttons.append(button)
	scroll.scroll_started.connect(func(): started += 1)
	scroll.scroll_ended.connect(func(): ended += 1)
	await process_frame
	await process_frame
	_expect(DisplayServer.is_touchscreen_available(), "runtime touch-from-mouse satisfies ScrollContainer touch availability")
	_expect(scroll.get_v_scroll_bar().max_value > scroll.get_v_scroll_bar().page, "content has vertical overflow")
	var point: Vector2 = buttons[0].get_global_rect().get_center()
	_mouse_button(point, true)
	_mouse_button(point, false)
	_expect(clicks == 1, "native mouse-to-touch stationary Button tap activates once")

	point = buttons[1].get_global_rect().get_center()
	_mouse_button(point, true)
	_mouse_motion(point - Vector2(0, 8), Vector2(0, -8))
	_expect(scroll.scroll_vertical == 0 and started == 0, "movement below 12-unit deadzone remains a pending tap")
	_mouse_motion(point - Vector2(0, 38), Vector2(0, -30))
	_mouse_motion(point - Vector2(0, 88), Vector2(0, -50))
	_mouse_button(point - Vector2(0, 88), false)
	_expect(scroll.scroll_vertical > 0 and started == 1, "native mouse-to-touch drag over Button and Panel scrolls")
	_expect(clicks == 1, "native drag releases with zero additional Button actions")
	_expect(ended == 1 and not scroll.is_processing_internal(), "normal scroll release ends internal drag")

	# Preserve STOP behavior as a regression control: it blocks press/motion,
	# while wheel still traverses the force-pass wheel exception.
	scroll.scroll_vertical = 0
	await process_frame
	buttons[1].mouse_filter = Control.MOUSE_FILTER_STOP
	point = buttons[1].get_global_rect().get_center()
	_mouse_button(point, true)
	_mouse_motion(point - Vector2(0, 50), Vector2(0, -50))
	_mouse_button(point - Vector2(0, 50), false)
	_expect(scroll.scroll_vertical == 0, "STOP child reproduces blocked drag")
	_wheel(point)
	_expect(scroll.scroll_vertical > 0, "wheel still passes the same STOP child")
	buttons[1].mouse_filter = Control.MOUSE_FILTER_PASS
	scroll.scroll_vertical = 0
	await process_frame

	var baseline_clicks: int = clicks
	point = buttons[1].get_global_rect().get_center()
	_touch(31, point, true)
	_touch_drag(31, point - Vector2(0, 50), Vector2(0, -50))
	_expect(scroll.scroll_vertical > 0 and scroll.is_processing_internal(), "raw touch starts built-in drag through mouse emulation")
	var canceled_offset: int = scroll.scroll_vertical
	gate.guard.cancel_interaction()
	# The public setter invokes _cancel_drag even for an unchanged offset.
	scroll.scroll_vertical = scroll.scroll_vertical
	_expect(not scroll.is_processing_internal(), "current-offset setter cancels internal drag immediately")
	_touch(31, point - Vector2(0, 50), false)
	_expect(gate.consumed == 1 and clicks == baseline_clicks, "canceled emulated release is consumed without Button activation")
	await process_frame
	await process_frame
	_expect(scroll.scroll_vertical == canceled_offset and not scroll.is_processing_internal(), "canceled scroll has no residual movement or internal processing")

	scroll.scroll_vertical = 0
	await process_frame
	point = buttons[1].get_global_rect().get_center()
	_touch(32, point, true)
	_touch_drag(32, point - Vector2(0, 70), Vector2(0, -70))
	_touch(32, point - Vector2(0, 70), false)
	_expect(scroll.scroll_vertical > 0 and clicks == baseline_clicks, "next fresh raw touch drag scrolls with zero Button actions")
	_expect(not scroll.is_processing_internal(), "next drag releases normally after cancellation")

	scroll.scroll_vertical = 0
	await process_frame
	point = buttons[0].get_global_rect().get_center()
	_touch(33, point, true)
	gate.guard.cancel_interaction()
	scroll.scroll_vertical = scroll.scroll_vertical
	_touch(33, point, false)
	_expect(clicks == baseline_clicks and not buttons[0].button_pressed, "canceled tap inside ScrollContainer cannot activate Button")
	_touch(34, point, true)
	_touch(34, point, false)
	_expect(clicks == baseline_clicks + 1, "fresh tap after canceled scroll/tap activates once")
	print("Mobile ScrollContainer actual Input fixture: ", "PASS" if failures == 0 else "FAIL", " (", failures, " failures)")
	quit(1 if failures else 0)


func _mouse_button(at: Vector2, down: bool) -> void:
	var event: InputEventMouseButton = InputEventMouseButton.new()
	event.position = at
	event.global_position = at
	event.button_index = MOUSE_BUTTON_LEFT
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if down else 0
	event.pressed = down
	_send(event)


func _mouse_motion(at: Vector2, delta: Vector2) -> void:
	var event: InputEventMouseMotion = InputEventMouseMotion.new()
	event.position = at
	event.global_position = at
	event.relative = delta
	event.screen_relative = delta
	event.button_mask = MOUSE_BUTTON_MASK_LEFT
	_send(event)


func _wheel(at: Vector2) -> void:
	var event: InputEventMouseButton = InputEventMouseButton.new()
	event.position = at
	event.global_position = at
	event.button_index = MOUSE_BUTTON_WHEEL_DOWN
	event.factor = 1.0
	event.pressed = true
	_send(event)
	var release: InputEventMouseButton = event.duplicate()
	release.pressed = false
	_send(release)


func _touch(index: int, at: Vector2, down: bool) -> void:
	var event: InputEventScreenTouch = InputEventScreenTouch.new()
	event.index = index
	event.position = at
	event.pressed = down
	_send(event)


func _touch_drag(index: int, at: Vector2, delta: Vector2) -> void:
	var event: InputEventScreenDrag = InputEventScreenDrag.new()
	event.index = index
	event.position = at
	event.relative = delta
	event.screen_relative = delta
	_send(event)


func _send(event: InputEvent) -> void:
	Input.parse_input_event(event)
	Input.flush_buffered_events()


func _expect(condition: bool, label: String) -> void:
	if condition:
		print("PASS ", label)
	else:
		failures += 1
		push_error(label)
