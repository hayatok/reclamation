# Smartphone touch controller integration

`mobile_touch_controller.gd` is a `RefCounted` reducer. It has no scene, camera,
game-model, HUD, JavaScript, or platform dependencies. The integration owns all
effects. The script-only regression fixture is
`tests/check_mobile_touch_controller.gd`.

## Adapter contract

Preload `TouchInput=preload("res://mobile_touch_controller.gd")` and instantiate
`touch_input=TouchInput.new()`. Its `Mode` enum is `CONTEXT`, `RANGE`, `ORDER`.
Set modes/append with `set_mode(value)` and `set_append(value)`, dispatching any
returned actions. Do not mutate its public flags directly while a gesture is
active. The public flags are available for HUD state reflection.

Call `feed(event, world_allowed, over_ui)` for **every** `InputEventScreenTouch`
and `InputEventScreenDrag` in `_input`, before GUI handling. `over_ui` must be a
point hit-test against visible interactive HUD rectangles at `event.position`,
including the minimap and all modal surfaces. Do not use mouse hover as touch
ownership. `world_allowed=false` when title, options, route choice, growth card,
dismantle confirmation, end screen, or another modal prevents world interaction.

Do not mark this raw native touch event handled in `_input`. Keep
`input_devices/pointing/emulate_mouse_from_touch=true`, so native `Control`
buttons receive their normal click emulation. At the beginning of the existing
**world** `_unhandled_input`, return for `TouchInput.is_emulated_mouse(event)`.
Never filter emulated mouse globally before GUI dispatch. Desktop mouse input
with device 0 remains supported by its existing path. Also suppress mouse hover
or edge-pan effects during `touch_input.gesture_active()`, because Web may
deliver pointer motion with device 0 even for a touch pointer.

The reducer returns `Array[TouchInput.Action]`. Use
`TouchInput.Action.Kind` to compare `action.kind`. All actions carry gesture-start
`mode` and `append`, so mode changes cannot reinterpret a held finger.

| Kind | Fields | Adapter effect |
| --- | --- | --- |
| `TAP` | `position`, `mode`, `append` | Context selection/order or explicit order resolution below |
| `PAN` | `position`, `delta` | Add `ground_at(position-delta)-ground_at(position)` to `camera_focus`; clamp existing X/Z bounds |
| `ZOOM` | `position`, `scale_factor` | Set `camera.size=clampf(camera.size/scale_factor,26,85)`; optionally preserve the ground beneath `position` |
| `RANGE_PREVIEW` | `origin`, `position` | Draw the touch selection rectangle using these two positions |
| `RANGE_COMMIT` | `origin`, `position`, `append` | Call `select_rect(origin,position,append)` once; then main may restore context mode |
| `RANGE_END` | `reason` | Clear the touch selection rectangle; never issue an order |

Apply camera position/look-at immediately after each pan/zoom action, rather
than waiting for `_process`, so consecutive inputs in one frame use current
projection. Pinch values greater than 1 mean spreading fingers, therefore
zooming in. Only two world-owned fingers can pinch. The remaining finger after
either pinch release stays blocked until all fingers lift; it cannot tap or pan.
ScreenDrag.relative is intentionally unused: deltas are reconstructed from each
event index's previous absolute position.

`TAP` is a request to resolve context, never an unconditional game order:

1. Placement active: commit `place_building(ground_at(position), append)` once.
2. Explicit `ORDER` mode or armed attack-move: call existing `command_at`.
   Restore `CONTEXT` after an accepted one-shot explicit order.
3. A friendly unit or friendly building under the finger: select/inspect it.
   Repair and escort use explicit `ORDER` mode to avoid ambiguous selection.
4. A selected worker and actionable resource/restoration site, or selected
   combat units and an enemy: call the existing `command_at` with the screen hit.
5. Empty terrain and selected units: call existing `command_at` to move.
6. Otherwise use existing point selection/inspection, preserving the same hit
   target precedence used by selection. Do not create duplicate hit policies
   with incompatible radii.

`append` is the visible queue/add toggle: pass it to either `select_rect` or
`command_at` as appropriate. Existing queue limitations still apply. Minimap
touch is UI-owned; its independent adapter may pan on a completed tap. It must
not let UI-origin touch releases enter the world resolver. Main owns whether
range/order modes are one-shot and should keep the HUD state synchronized.

## Cancellation and coordinate changes

- Dispatch `cancel(reason)` when a modal opens, an explicit mode/placement
  changes, Cancel is pressed, or another world interaction takes ownership.
  It clears any range preview and quarantines held fingers until all release.
- Call `set_viewport_size(get_viewport().get_visible_rect().size)` at setup and
  on size changes. A changed size cancels active gestures. An unchanged size
  does not. Set `tap_slop` to about 12 CSS pixels converted to viewport units;
  do not use physical DPR pixels. Its default is 14 viewport units.
- On browser `touchcancel`, call `cancel("web_touchcancel")` from a capture-phase
  listener **before** Godot dispatches the matching release. Godot 4.6 Web maps
  `touchcancel` to its ordinary touchend callback without setting `canceled`.
- On focus/page loss call `cancel("focus_lost", true)`. The second argument
  forgets stranded pointer IDs whose releases may never arrive; late releases
  and drags without a fresh down are ignored. Use this only for a genuine loss
  of the input surface, not normal mode or layout changes.
- Native `InputEventScreenTouch.canceled` is handled directly by `feed`.

No long press, right click, modifier key, or double tap is required for touch.
Synthetic tests verify reducer behavior; they are not physical-device evidence.
