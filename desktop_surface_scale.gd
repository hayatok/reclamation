extends RefCounted
## Desktop only: preserve the design aspect and large-surface presentation,
## but do not shrink the HUD below its authored size in effective pixels.
## Main must call setup/update only after deciding mobile_enabled is false.
## No DOM writes, window resize, input remapping, or mobile safe-area handling.
const DESIGN_SIZE := Vector2(1440.0, 900.0)
const POLL_INTERVAL_MSEC: int = 250
const WEB_GEOMETRY := """
(function () {
    const canvas = document.getElementById('canvas') || document.querySelector('canvas');
    const positive = value => Number.isFinite(value) && value > 0;
    const dpr = positive(window.devicePixelRatio) ? window.devicePixelRatio : 1;
    if (!canvas) return '';
    const style = window.getComputedStyle(canvas);
    const padding = name => {
        const value = parseFloat(style[name]);
        return Number.isFinite(value) && value >= 0 ? value : 0;
    };
    // clientWidth includes padding but excludes the border. Godot's drawing
    // surface occupies the CSS content box, not that padding or the browser UI.
    const width = canvas.clientWidth - padding('paddingLeft') - padding('paddingRight');
    const height = canvas.clientHeight - padding('paddingTop') - padding('paddingBottom');
    if (positive(width) && positive(height)) return JSON.stringify({width, height});
    // A hidden canvas has no usable layout: retain the last accepted geometry.
    if (canvas.getClientRects().length === 0) return '';
    const fallbackWidth = canvas.width / dpr;
    const fallbackHeight = canvas.height / dpr;
    return positive(fallbackWidth) && positive(fallbackHeight)
        ? JSON.stringify({width: fallbackWidth, height: fallbackHeight}) : '';
}());
"""

var _window: Window
var _last_poll_msec: int = -POLL_INTERVAL_MSEC
var _deferred_for_press: bool = false


func setup(window: Window) -> void:
	_window = window
	_last_poll_msec = -POLL_INTERVAL_MSEC
	_deferred_for_press = false
	update()


## Call each frame; sampling is sparse except immediately after a held mouse
## gesture ends. Re-read at release so we apply the latest, not stale, geometry.
func update() -> bool:
	if not is_instance_valid(_window):
		return false
	if Input.get_mouse_button_mask() != 0:
		_deferred_for_press = true
		return false
	var now: int = Time.get_ticks_msec()
	if not _deferred_for_press and now - _last_poll_msec < POLL_INTERVAL_MSEC:
		return false
	_deferred_for_press = false
	_last_poll_msec = now
	var effective: Vector2 = _effective_size()
	var metrics: Dictionary = layout_metrics(effective)
	if metrics.is_empty():
		return false
	var target: Vector2i = metrics.content_scale_size
	if _window.content_scale_size == target and is_equal_approx(_window.content_scale_factor, 1.0):
		return false
	_window.content_scale_size = target
	_window.content_scale_factor = 1.0
	return true


func _effective_size() -> Vector2:
	if OS.has_feature("web"):
		if not Engine.has_singleton("JavaScriptBridge"):
			return Vector2.ZERO
		var raw: Variant = JavaScriptBridge.eval(WEB_GEOMETRY, true)
		if not raw is String or raw.is_empty():
			return Vector2.ZERO
		var result: Variant = JSON.parse_string(raw)
		if not result is Dictionary:
			return Vector2.ZERO
		var width: Variant = result.get("width")
		var height: Variant = result.get("height")
		if not (width is float or width is int) or not (height is float or height is int):
			return Vector2.ZERO
		return effective_size(Vector2(float(width), float(height)), 1.0)
	# Main-window sentinel preserves fractional Wayland scale. Godot 4.6 returns
	# 1 on Windows/X11; it cannot establish those OS accessibility scale settings.
	return effective_size(Vector2(_window.size), DisplayServer.screen_get_scale(DisplayServer.SCREEN_OF_MAIN_WINDOW))


static func effective_size(physical: Vector2, density: float) -> Vector2:
	if not _positive_size(physical) or not is_finite(density) or density <= 0.0:
		return Vector2.ZERO
	var result: Vector2 = physical / density
	return result if _positive_size(result) else Vector2.ZERO


## Empty means invalid/transient geometry: the caller must retain its last
## accepted size. Small sizes are computed, not certified as supported layouts.
static func layout_metrics(effective: Vector2) -> Dictionary:
	if not _positive_size(effective):
		return {}
	var fit: float = minf(1.0, minf(effective.x / DESIGN_SIZE.x, effective.y / DESIGN_SIZE.y))
	var base: Vector2i = Vector2i(roundi(DESIGN_SIZE.x * fit), roundi(DESIGN_SIZE.y * fit))
	if base.x <= 0 or base.y <= 0:
		return {}
	return {"content_scale_size": base}


static func _positive_size(value: Vector2) -> bool:
	return is_finite(value.x) and is_finite(value.y) and value.x > 0.0 and value.y > 0.0
