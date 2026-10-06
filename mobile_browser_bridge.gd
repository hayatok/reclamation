extends RefCounted
## Browser interruption and CSS-geometry adapter for the phone HUD.
## Call setup(reset_callback), poll_layout() from _process(), and teardown()
## from the owning Node's _exit_tree(). The callback is synchronous: cancel a
## pending gesture before Godot 4.6 turns browser touchcancel into a release.
## safe_insets is Vector4(left, top, right, bottom), in canvas CSS pixels.
## Main owns Window.content_scale_size; never multiply these values by DPR.
## Sources and native-only test switches: docs/MOBILE_BROWSER_BRIDGE.md.

const POLL_INTERVAL_MSEC: int = 250
const BROWSER_INTERFACE: String = "__reclamationMobileBridgeV037"

# Kept inline so exported PCKs do not depend on a non-resource .js export filter.
const BROWSER_SOURCE: String = """
(function () {
    'use strict';
    const key = '__reclamationMobileBridgeV037';
    if (window[key] && typeof window[key].teardown === 'function') {
        window[key].teardown();
    }
    let enabled = false;
    let callback = null;
    let canvas = null;
    let probe = null;
    let meta = null;
    let createdMeta = false;
    let previousMeta = null;
    let installedMeta = '';
    let previousTouchAction = '';
    let previousTouchPriority = '';
    let observer = null;
    let dirty = true;
    let lastRead = -Infinity;
    let lastGeometry = null;
    const listeners = [];
    const clock = function () { return window.performance.now(); };

    function listen(target, name, handler, capture) {
        const options = {capture: !!capture, passive: true};
        target.addEventListener(name, handler, options);
        listeners.push([target, name, handler, options]);
    }

    function reset(reason) {
        // No deferred callback: touchcancel must run before Godot's bubble listener.
        if (enabled && callback) callback(reason);
    }

    function changed(reason) {
        dirty = true;
        reset(reason);
    }

    function finiteInset(value) {
        const parsed = parseFloat(value);
        return Number.isFinite(parsed) ? Math.max(0, parsed) : 0;
    }

    function readGeometry() {
        const rect = canvas.getBoundingClientRect();
        if (!(rect.width > 0 && rect.height > 0)) return lastGeometry;
        const css = window.getComputedStyle(probe);
        const viewportWidth = window.innerWidth || rect.right;
        const viewportHeight = window.innerHeight || rect.bottom;
        // env() describes the viewport. Intersect its unsafe strips with the
        // canvas, so an already inset/embedded canvas is not padded twice.
        const left = Math.min(rect.width, Math.max(0, finiteInset(css.paddingLeft) - rect.left));
        const top = Math.min(rect.height, Math.max(0, finiteInset(css.paddingTop) - rect.top));
        const right = Math.min(rect.width, Math.max(0, rect.right - (viewportWidth - finiteInset(css.paddingRight))));
        const bottom = Math.min(rect.height, Math.max(0, rect.bottom - (viewportHeight - finiteInset(css.paddingBottom))));
        lastGeometry = {enabled: true, width: rect.width, height: rect.height,
            left: left, top: top, right: right, bottom: bottom};
        return lastGeometry;
    }

    const api = {
        install: function (onReset, explicitMobileFeature) {
            api.teardown();
            canvas = document.getElementById('canvas') || document.querySelector('canvas');
            if (!canvas) return false;
            const rect = canvas.getBoundingClientRect();
            const width = window.innerWidth || rect.width;
            const height = window.innerHeight || rect.height;
            const coarse = !!(window.matchMedia && window.matchMedia('(any-pointer: coarse)').matches);
            const touch = (window.navigator.maxTouchPoints || 0) > 0;
            const small = Math.min(width, height) <= 720 && Math.max(width, height) <= 1440;
            if (!(explicitMobileFeature || ((touch || coarse) && small))) {
                canvas = null;
                return false;
            }
            enabled = true;
            callback = onReset;
            dirty = true;
            lastRead = -Infinity;
            previousTouchAction = canvas.style.getPropertyValue('touch-action');
            previousTouchPriority = canvas.style.getPropertyPriority('touch-action');
            canvas.style.setProperty('touch-action', 'none', 'important');

            meta = document.querySelector('meta[name="viewport"]');
            createdMeta = !meta;
            if (!meta) {
                meta = document.createElement('meta');
                meta.name = 'viewport';
                document.head.appendChild(meta);
            }
            previousMeta = meta.getAttribute('content');
            const directives = (previousMeta || '').split(',').map(function (part) { return part.trim(); })
                .filter(function (part) { return part && !/^(width|initial-scale|viewport-fit)[ ]*=/i.test(part); });
            directives.push('width=device-width', 'initial-scale=1', 'viewport-fit=cover');
            installedMeta = directives.join(', ');
            meta.setAttribute('content', installedMeta);
            // Do not add user-scalable=no, a maximum scale, or a page-wide touch rule.
            probe = document.createElement('div');
            probe.setAttribute('aria-hidden', 'true');
            probe.style.cssText = 'position:fixed;left:0;top:0;width:0;height:0;visibility:hidden;pointer-events:none;'
                + 'margin:0;border:0;box-sizing:content-box;'
                + 'padding-left:env(safe-area-inset-left,0px);padding-top:env(safe-area-inset-top,0px);'
                + 'padding-right:env(safe-area-inset-right,0px);padding-bottom:env(safe-area-inset-bottom,0px);';
            (document.body || document.documentElement).appendChild(probe);

            listen(canvas, 'touchcancel', function () { reset('touchcancel'); }, true);
            listen(window, 'blur', function () { reset('blur'); }, true);
            listen(document, 'visibilitychange', function () {
                if (document.hidden) reset('hidden');
                else changed('visible');
            }, true);
            listen(window, 'pagehide', function () { reset('pagehide'); }, true);
            listen(window, 'resize', function () { changed('resize'); }, true);
            listen(window, 'orientationchange', function () { changed('orientationchange'); }, true);
            if (window.visualViewport) {
                listen(window.visualViewport, 'resize', function () { changed('viewport_resize'); }, true);
            }
            if (window.ResizeObserver) {
                let observedWidth = rect.width;
                let observedHeight = rect.height;
                observer = new window.ResizeObserver(function (entries) {
                    const entry = entries[0];
                    if (!entry) return;
                    const bounds = entry.contentRect;
                    if (bounds.width !== observedWidth || bounds.height !== observedHeight) {
                        observedWidth = bounds.width;
                        observedHeight = bounds.height;
                        changed('canvas_resize');
                    }
                });
                observer.observe(canvas);
            }
            return true;
        },
        poll: function () {
            if (!enabled || !canvas || !probe) return '';
            const now = clock();
            if (dirty || now - lastRead >= 250) {
                dirty = false;
                lastRead = now;
                readGeometry();
            }
            return lastGeometry ? JSON.stringify(lastGeometry) : '';
        },
        teardown: function () {
            // Invalidate the callback before removing listeners/DOM objects.
            enabled = false;
            callback = null;
            listeners.forEach(function (binding) {
                binding[0].removeEventListener(binding[1], binding[2], binding[3]);
            });
            listeners.length = 0;
            if (observer) observer.disconnect();
            observer = null;
            if (canvas && canvas.style.getPropertyValue('touch-action') === 'none'
                    && canvas.style.getPropertyPriority('touch-action') === 'important') {
                if (previousTouchAction) canvas.style.setProperty('touch-action', previousTouchAction, previousTouchPriority);
                else canvas.style.removeProperty('touch-action');
            }
            if (probe) probe.remove();
            if (meta && meta.getAttribute('content') === installedMeta) {
                if (createdMeta) meta.remove();
                else if (previousMeta === null) meta.removeAttribute('content');
                else meta.setAttribute('content', previousMeta);
            }
            canvas = null;
            probe = null;
            meta = null;
            createdMeta = false;
            previousMeta = null;
            installedMeta = '';
            previousTouchAction = '';
            previousTouchPriority = '';
            lastGeometry = null;
            dirty = true;
            lastRead = -Infinity;
        }
    };
    window[key] = api;
    return true;
}());
"""

var _reset_callback: Callable
var _js_callback: JavaScriptObject
var _browser: JavaScriptObject
var _native_override: bool = false
var _native_test_size: Vector2 = Vector2.ZERO
var _layout_dirty: bool = true
var _last_poll_msec: int = -POLL_INTERVAL_MSEC
var _layout: Dictionary = _disabled_layout()


func setup(reset_callback: Callable) -> void:
	teardown()
	_reset_callback = reset_callback
	if not OS.has_feature("web"):
		_read_native_test_options()
		poll_layout()
		return
	# A Web export never treats a native test override as browser evidence.
	if not Engine.has_singleton("JavaScriptBridge"):
		return
	JavaScriptBridge.eval(BROWSER_SOURCE, true)
	_browser = JavaScriptBridge.get_interface(BROWSER_INTERFACE)
	if _browser == null:
		return
	# Godot requires this JavaScriptObject reference to remain alive while used.
	_js_callback = JavaScriptBridge.create_callback(_on_browser_event)
	var mobile_feature: bool = OS.has_feature("web_ios") or OS.has_feature("web_android")
	if not bool(_browser.install(_js_callback, mobile_feature)):
		_browser = null
		_js_callback = null
		return
	_layout_dirty = true
	poll_layout()


func poll_layout() -> Dictionary:
	if _native_override:
		var logical_size: Vector2 = _native_test_size if _native_test_size != Vector2.ZERO else _native_window_size()
		var previous_size: Vector2 = _layout.get("css_size", Vector2.ZERO)
		_layout = {
			"enabled": true, "css_size": logical_size, "safe_insets": Vector4.ZERO,
			"is_browser": false, "source": "native_test_size" if _native_test_size != Vector2.ZERO else "native_window",
		}
		if previous_size != Vector2.ZERO and previous_size != logical_size:
			_emit_reset("native_resize")
		return _layout.duplicate()
	if _browser == null:
		return _layout.duplicate()
	var now: int = Time.get_ticks_msec()
	if not _layout_dirty and now - _last_poll_msec < POLL_INTERVAL_MSEC:
		return _layout.duplicate()
	_layout_dirty = false
	_last_poll_msec = now
	var raw: String = str(_browser.poll())
	if raw.is_empty():
		return _layout.duplicate()
	var decoded: Variant = JSON.parse_string(raw)
	if not decoded is Dictionary:
		return _layout.duplicate()
	var data: Dictionary = decoded
	var size: Vector2 = Vector2(float(data.get("width", 0.0)), float(data.get("height", 0.0)))
	if size.x <= 0.0 or size.y <= 0.0:
		return _layout.duplicate()
	var insets: Vector4 = Vector4(float(data.get("left", 0.0)), float(data.get("top", 0.0)), float(data.get("right", 0.0)), float(data.get("bottom", 0.0)))
	var previous_size: Vector2 = _layout.get("css_size", Vector2.ZERO)
	var previous_insets: Vector4 = _layout.get("safe_insets", Vector4.ZERO)
	_layout = {"enabled": true, "css_size": size, "safe_insets": insets, "is_browser": true, "source": "canvas_css"}
	# Catch geometry/safe-area changes that did not produce a browser resize event.
	if previous_size != Vector2.ZERO and (previous_size != size or previous_insets != insets):
		_emit_reset("layout_changed")
	return _layout.duplicate()


func teardown() -> void:
	if _browser != null:
		_browser.teardown()
	_browser = null
	_js_callback = null
	_reset_callback = Callable()
	_native_override = false
	_native_test_size = Vector2.ZERO
	_layout_dirty = true
	_last_poll_msec = -POLL_INTERVAL_MSEC
	_layout = _disabled_layout()


func _on_browser_event(arguments: Array) -> void:
	if arguments.is_empty():
		return
	var reason: String = str(arguments[0])
	if reason in ["resize", "orientationchange", "viewport_resize", "canvas_resize", "visible"]:
		_layout_dirty = true
	_emit_reset(reason)


func _emit_reset(reason: String) -> void:
	if _reset_callback.is_valid():
		_reset_callback.call(reason)


func _read_native_test_options() -> void:
	var arguments: PackedStringArray = OS.get_cmdline_args()
	arguments.append_array(OS.get_cmdline_user_args())
	for argument: String in arguments:
		if argument == "--touch-ui":
			_native_override = true
		elif argument.begins_with("--touch-ui-size="):
			var parts: PackedStringArray = argument.trim_prefix("--touch-ui-size=").to_lower().split("x")
			if parts.size() == 2 and parts[0].is_valid_int() and parts[1].is_valid_int():
				var candidate: Vector2 = Vector2(parts[0].to_int(), parts[1].to_int())
				if candidate.x > 0.0 and candidate.y > 0.0 and candidate.x <= 8192.0 and candidate.y <= 8192.0:
					_native_override = true
					_native_test_size = candidate


func _native_window_size() -> Vector2:
	var loop: MainLoop = Engine.get_main_loop()
	if loop is SceneTree:
		var window: Window = (loop as SceneTree).root
		if window != null:
			return Vector2(window.size)
	return Vector2(DisplayServer.window_get_size())


static func _disabled_layout() -> Dictionary:
	return {"enabled": false, "css_size": Vector2.ZERO, "safe_insets": Vector4.ZERO, "is_browser": false, "source": "disabled"}
