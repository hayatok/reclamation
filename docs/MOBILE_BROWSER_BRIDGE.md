# Mobile browser geometry and interruption bridge

`mobile_browser_bridge.gd` is an isolated `RefCounted` adapter. The game keeps
ownership of its HUD, input controller and root `Window` scaling.

## Integration contract

1. Create the adapter and call `setup(reset_callback)` before the initial mobile
   HUD layout. The callback takes one reason string and must synchronously clear
   any pending touch, range selection or placement gesture.
2. Call `poll_layout()` from the owning node's process function. The returned
   dictionary has `enabled`, `css_size: Vector2` and
   `safe_insets: Vector4(left, top, right, bottom)`. It also exposes `is_browser`
   and `source` for honest diagnostic labels.
3. When enabled, use the rounded CSS size for root `content_scale_size`, with
   canvas-items scaling and factor 1. Apply safe insets once in HUD layout. The
   adapter does not resize the canvas, change its backing buffer, multiply by
   DPR, or transform input coordinates.
4. Call `teardown()` from the owning node's `_exit_tree()` before dropping the
   adapter. This removes listeners and the single probe, disconnects its
   observer, releases its retained JavaScript callback, and restores styles and
   viewport metadata if the host page has not subsequently changed them.

The callback reasons are `touchcancel`, `blur`, `hidden`, `visible`, `pagehide`,
`resize`, `orientationchange`, `viewport_resize`, `canvas_resize`,
`layout_changed` and `native_resize`. A reset should be idempotent: one physical
resize can have multiple browser notifications. `touchcancel`, focus/page loss
and geometry resets must suppress any later release from the interrupted
gesture. Do not defer the touchcancel reset.

## Activation and browser behavior

Web activation requires `web_ios` or `web_android`, or a touch-capable/coarse
pointer viewport with a short edge at most 720 CSS pixels and a long edge at
most 1440 CSS pixels. This is a documented heuristic; a narrow mouse-only
desktop stays unchanged. Detection happens at setup, so resizing an initially
desktop browser does not silently change its interaction scheme mid-session.
An already active phone adapter remains active across rotation and toolbar
resizes. A large hybrid/tablet viewport may remain desktop unless Godot reports
one of the explicit mobile Web features.

The adapter uses the `canvas` element's bounding rectangle. It adds
`touch-action: none` only to that canvas. It preserves unrelated viewport
directives and sets `width=device-width, initial-scale=1, viewport-fit=cover`.
It does not add a maximum-scale or user-scalable restriction. One hidden probe
reads CSS `env(safe-area-inset-*)`; the unsafe viewport strips are intersected
with the canvas so an already inset canvas is not padded twice.

Godot's normal full-window resize policy remains responsible for the backing
canvas size. CSS geometry is cached: GDScript crosses the JavaScript bridge at
most every 250 ms unless a layout event marks it dirty. Browser layout/style
reads are likewise throttled; there is no per-frame evaluation of source or
creation of DOM probes. A hidden zero-size canvas retains the last valid size.

The canvas `touchcancel` listener runs in capture phase before Godot's regular
release handler. It observes cancellation without preventing default,
stopping propagation or changing browser security, audio or authentication
behavior. The retained callback's lifetime and explicit teardown are required.

## Canceling an interrupted GUI press

`mobile_gui_guard.gd` complements the world gesture reducer. Instantiate it in
the owner and call `before_input(event, get_viewport())` first in `_input()`;
return immediately when it returns true. Call `cancel_interaction()` from the
synchronous browser reset callback and other deliberate interaction resets
(such as opening a modal or canceling a held UI action on multitouch).

The guard records the pressed Button for device -1 left-button mouse
emulation. On interruption it clears that Button's pending press by briefly
disabling and restoring it, then consumes canceled emulated releases before
GUI dispatch. This also delivers `button_up` for pressed-tile visual cleanup,
without `pressed` or `toggled`. An existing toggle selection is preserved.
The next fresh emulated press clears the latch; ordinary GUI mouse emulation
and real mouse events continue to work. Freed/disabled Buttons are handled
without touching invalid or already disabled nodes.

The ordering is deliberate: Godot 4.6's Input implementation dispatches the
emulated mouse event before the originating ScreenTouch. Its viewport updates
mouse hover before `_input()`, and dispatches GUI afterward. Thus the guard
can use the current hovered Control and its Button ancestor even when a touch
press has no preceding mouse motion. It also validates the event position.
Consuming a release alone only clears the viewport's mouse-focus mask; it
does not clear a Button's pending press. Releasing keyboard focus does not
solve this for the game's `FOCUS_NONE` Buttons.

`tests/check_mobile_gui_guard.gd` exercises actual
`Input.parse_input_event()` plus `Input.flush_buffered_events()`. Its 15
Godot 4.6.3 checks passed: no-motion hover ordering, normal emulation, canceled
release, cleanup signals/appearance, next fresh press, toggle preservation,
the native canceled flag, real mouse behavior, dragging off the original
Button, and deletion of a pressed Button. This is headless engine evidence;
the real browser capture callback still needs exported-browser verification.

## ScrollContainer content and interrupted scrolling

For scrollable mobile modals, leave the ScrollContainer's mouse filter at
`MOUSE_FILTER_STOP`, set a deliberate `scroll_deadzone` (12 CSS-equivalent
units in this integration), and set content Buttons/intermediate panels and
layout containers to `MOUSE_FILTER_PASS`. Keep decorative `IGNORE` nodes and
scrollbars' own handling. A STOP content child blocks pointer press/motion
before they reach the ScrollContainer, while wheel input has a special
propagation exception. Thus wheel success does not establish touch drag
support for the same control tree.

The desktop DisplayServer's touchscreen-available check reads runtime
mouse-to-touch emulation; the native `--touch-ui` path does not require a
separate touchscreen-hint setting. During normal touch drag, ScrollContainer
notifies descendant Buttons when the deadzone is crossed, clearing their
pending activation. Let the normal release reach GUI so its internal scroll
drag and Button `button_up` handling finish. Do not connect normal
`scroll_started` to the release-consuming interruption guard.

On external interruption, cancel the GUI guard and assign every active
modal scroll's existing offset back to itself:
`scroll.scroll_vertical = scroll.scroll_vertical`. Godot's public setter
invokes its internal drag cancellation even when the offset is unchanged;
this stops drag and momentum before the guard consumes the canceled release.

`tests/check_mobile_scroll_input.gd` passed 17 checks in Godot 4.6.3 using
actual Input dispatch through ScrollContainer → VBox → Panel → Button.
It verifies native mouse-to-touch tap/drag, deadzone, no action after dragging
over a Button, normal release cleanup, STOP-child/wheel regression behavior,
raw-touch emulated cancellation, unchanged-offset cancellation, and recovery
on the next drag and tap. Native test mouse events and device -1 browser-style
mouse emulation are tested separately. Real phone behavior remains untested.

## Native development switches

Use Godot's `--` separator before these application arguments:

- `--touch-ui` enables the test HUD using the native root `Window.size`.
- `--touch-ui-size=844x390` or `--touch-ui-size=932x430` enables a fixed logical
  test geometry. The size switch also enables the override itself.

Both paths report `is_browser: false`, zero browser safe insets and either
`source: native_window` or `source: native_test_size`. They exercise layout and
input integration only. They do not establish CSS, notch, WebGL, audio,
browser interruption or physical-phone behavior. These overrides are ignored
on Web; browser detection and the actual canvas remain authoritative there.

## Verification

Run `node tests/check_mobile_browser_bridge.mjs` for the deterministic DOM
contract suite. It covers 844×390, 932×430 and portrait 390×844 at DPR 1/2/3,
desktop/mobile gating, CSS safe-inset intersection, cancellation before a
mock engine release, focus/page/resize interruption, throttling, zero-size
geometry, reinstall and listener/metadata/style cleanup. These are simulated
DOM tests, not a browser or device run.

Run `godot --headless --path . --script
res://tests/check_mobile_browser_native.gd --` with no extra argument, then with
`--touch-ui`, then with `--touch-ui-size=844x390`. Each validates the native
contract, including accurate test-source labeling and teardown. In a sandbox,
point XDG data/cache/config directories at writable task-local directories.

At delivery, the 21 JavaScript contract checks and all three native Godot
4.6.3 runs passed. Actual exported-browser execution, phone rendering,
JavaScriptBridge event ordering in the real engine, safe-area CSS on Safari,
audio/background resume and device performance require integration QA.

## Primary references

- [Godot 4.6 JavaScriptBridge](https://docs.godotengine.org/en/4.6/classes/class_javascriptbridge.html):
  callback retention, single-array callback signature and interface access.
- [Godot 4.6 Web feature tags](https://docs.godotengine.org/en/4.6/tutorials/export/feature_tags.html):
  explicit `web_ios`/`web_android` detection.
- [Godot 4.6 Window scaling](https://docs.godotengine.org/en/4.6/classes/class_window.html#class-window-property-content-scale-size):
  virtual base dimensions are separate from window/backing dimensions.
- [Godot 4.6-stable Web input source](https://github.com/godotengine/godot/blob/4.6-stable/platform/web/js/libs/library_godot_input.js#L468-L573)
  and [touch dispatch source](https://github.com/godotengine/godot/blob/4.6-stable/platform/web/display_server_web.cpp#L682-L715):
  touch cancellation is mapped to release without the canceled flag.
- [Godot Web canvas sizing](https://github.com/godotengine/godot/blob/4.6-stable/platform/web/js/libs/library_godot_display.js#L225-L326):
  full-window backing size already accounts for DPR.
- [WebKit safe-area guidance](https://webkit.org/blog/7929/designing-websites-for-iphone-x/)
  and [MDN touch-action](https://developer.mozilla.org/en-US/docs/Web/CSS/Reference/Properties/touch-action):
  cover-fit safe areas and gesture policy on the game surface.
- [Godot 4.6 Web export guide](https://docs.godotengine.org/en/4.6/tutorials/export/exporting_for_web.html):
  browser restrictions and mobile/WebGL/audio limitations still apply.
- [Godot Input implementation](https://raw.githubusercontent.com/godotengine/godot/4.6-stable/core/input/input.cpp):
  `_parse_input_event_impl` recursively dispatches mouse-from-touch first.
- [Godot Viewport implementation](https://raw.githubusercontent.com/godotengine/godot/4.6-stable/scene/main/viewport.cpp):
  `push_input` updates hover before `_input`, then calls GUI or its handled
  event cleanup path; `_gui_cleanup_internal_state` only clears the mouse mask.
- [Godot BaseButton implementation](https://raw.githubusercontent.com/godotengine/godot/4.6-stable/scene/gui/base_button.cpp):
  `on_action_event` performs release activation; `set_disabled` resets the
  pending press without activating the Button.
- [Godot ScrollContainer implementation](https://raw.githubusercontent.com/godotengine/godot/4.6-stable/scene/gui/scroll_container.cpp):
  touch-availability gate, deadzone notification and `set_v_scroll` drag reset.
- [Godot base DisplayServer implementation](https://raw.githubusercontent.com/godotengine/godot/4.6-stable/servers/display/display_server.cpp):
  the default touchscreen availability check reads Input's runtime touch
  emulation state.
