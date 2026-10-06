extends RefCounted
## Cancels an interrupted touch-driven Button press before its mouse release.
## Call before_input(event, get_viewport()) first in the owner's _input(); return
## when it returns true. Call cancel_interaction() synchronously from the Web
## bridge reset callback, before Godot receives the canceled touch release.
## Ordinary Buttons still receive mouse-from-touch emulation. Real mouse events
## are untouched. Source evidence: docs/MOBILE_BROWSER_BRIDGE.md.

var _cancelled_release: bool = false
var _pressed_button: BaseButton


func before_input(event: InputEvent, viewport: Viewport) -> bool:
	if not event is InputEventMouseButton:
		return false
	if event.device != InputEvent.DEVICE_ID_EMULATION or event.button_index != MOUSE_BUTTON_LEFT:
		return false
	if event.pressed:
		# A new mouse-owning touch starts a new UI interaction. Do not clear this
		# latch on ScreenTouch: its emulated mouse event is dispatched first.
		_clear_button_press()
		_cancelled_release = false
		_pressed_button = _button_at_hover(viewport, event.position)
		return false
	if _cancelled_release or event.canceled:
		_cancelled_release = true
		_clear_button_press()
		# Viewport cleanup still clears its mouse-focus mask for handled release.
		viewport.set_input_as_handled()
		return true
	# Let the normal release activate its original Button through GUI dispatch.
	_pressed_button = null
	return false


func cancel_interaction() -> void:
	_cancelled_release = true
	_clear_button_press()


func _button_at_hover(viewport: Viewport, position: Vector2) -> BaseButton:
	# Godot 4.6 Viewport::push_input updates mouse-over before calling _input.
	# Use its hit result, including Control clipping and mouse filters, rather
	# than a separate tree scan. Check position too so stale/manual test input
	# cannot accidentally capture a different previously hovered Button.
	var control: Control = viewport.gui_get_hovered_control()
	while control != null:
		if control is BaseButton:
			var local_position: Vector2 = control.get_global_transform_with_canvas().affine_inverse() * position
			if control.is_visible_in_tree() and not control.disabled and Rect2(Vector2.ZERO, control.size).has_point(local_position):
				return control
			return null
		if control.mouse_filter == Control.MOUSE_FILTER_STOP:
			return null
		control = control.get_parent_control()
	return null


func _clear_button_press() -> void:
	var button: BaseButton = _pressed_button
	_pressed_button = null
	if not is_instance_valid(button) or button.disabled:
		return
	# BaseButton::set_disabled clears press_attempt / pressing_inside and emits
	# button_up, which restores the command tile's pressed visual. It does not
	# emit pressed/toggled, and preserves a toggle Button's selected state.
	# Merely consuming release, releasing keyboard focus, or changing
	# button_pressed would leave FOCUS_NONE Buttons' press_attempt intact.
	button.disabled = true
	if is_instance_valid(button) and not button.is_queued_for_deletion():
		button.disabled = false
