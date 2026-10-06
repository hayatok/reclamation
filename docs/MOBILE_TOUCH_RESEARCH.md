# RECLAMATION: smartphone Web controls research

Research date: 2026-10-06. Scope: Godot 4.6 Web, landscape browser play at 844×390 and 932×430 CSS pixels. Sources are official Godot documentation/source, browser-vendor documentation, standards guidance, and the publisher's own mobile RTS material. These are implementation recommendations, not a claim that any physical phone has passed testing.

## Recommended first implementation

Use an explicit mobile interaction layer and a compact, CSS-sized HUD. Keep the existing mouse/keyboard behavior and desktop layout as their own path. The mobile layer should provide tap selection/context commands, one-finger camera drag, two-finger pinch zoom, and visible selection-range, command, queue, and cancel controls. Make all critical actions reachable without right click, modifier keys, hover, or a keyboard.

Prioritize four correctness requirements: one touch produces one action; UI touches never become world orders; a pinch or interrupted gesture never ends as a tap; and control hit areas retain their intended CSS size at DPR 1, 2, and 3.

## Verified Godot 4.6 facts and exact pitfalls

### Touch events, emulated mouse events, and ordinary Buttons

- `InputEventScreenTouch` supplies `pressed`, `index`, `position`, and `canceled`; one index identifies one finger. `position` is in the receiving viewport's coordinates. Track an index-to-position dictionary, not a finger count or an assumed index 0. [ScreenTouch reference](https://docs.godotengine.org/en/4.6/classes/class_inputeventscreentouch.html)
- `InputEventScreenDrag.relative` is content-scaled, while `screen_relative` is unscaled. Do not mix their coordinate systems when evaluating thresholds or camera movement. [ScreenDrag reference](https://docs.godotengine.org/en/4.6/classes/class_inputeventscreendrag.html)
- `input_devices/pointing/emulate_mouse_from_touch` defaults to true and emits mouse events for touch. `emulate_touch_from_mouse` defaults to false. [ProjectSettings reference](https://docs.godotengine.org/en/4.6/classes/class_projectsettings.html#class-projectsettings-property-input-devices-pointing-emulate-mouse-from-touch)
- `InputEvent.DEVICE_ID_EMULATION` is -1 and distinguishes Godot-emulated touch/mouse events. [InputEvent reference](https://docs.godotengine.org/en/4.6/classes/class_inputevent.html#class-inputevent-constant-device-id-emulation)
- Ordinary `Button` nodes use mouse-from-touch emulation for touch activation. `TouchScreenButton` supports simultaneous presses, but is a Node2D without Control anchors. It is not a drop-in replacement for an anchored UI. [TouchScreenButton reference](https://docs.godotengine.org/en/4.6/classes/class_touchscreenbutton.html)
- `_input()` runs before GUI handling; `_unhandled_input()` lets GUI intercept first. Consuming events in `_input()` can prevent the GUI from receiving them. [Input propagation](https://docs.godotengine.org/en/4.6/tutorials/inputs/inputevent.html)

Design adaptation: preserve emulation for ordinary Controls, observe native touch streams in the mobile controller, and exclude emulated mouse events only from world handling. UI ownership must be captured on touch-down and remain sticky through movement/release. Hit-testing only on release allows a UI drag to command the world. Hit-testing only on press allows a world drag to finish over a UI control and accidentally activate it. Test both directions.

### Important release-specific Web source behavior

The following are facts from the `4.6-stable` tag, not merely generic input advice:

1. The JavaScript bridge binds `touchcancel` and `touchend` to the same numeric event type. It also maps client coordinates using the canvas bounding rectangle and canvas backing-size ratio. The mouse-motion listener uses `pointermove` without filtering `pointerType`. [Godot Web input bridge, relevant functions](https://github.com/godotengine/godot/blob/4.6-stable/platform/web/js/libs/library_godot_input.js#L468-L573)
2. The C++ touch callback sets `pressed` from that numeric type but never sets `canceled`. It stores previous drag positions by changed-touch batch slot `i`, while event indices use browser touch identifiers. It resumes the audio context during touch press/release handling. [Godot Web display server](https://github.com/godotengine/godot/blob/4.6-stable/platform/web/display_server_web.cpp#L682-L715)

Consequences and adaptations:

- Checking only `event.canceled` cannot reliably reject browser cancellation in this version. Register a capture-phase canvas `touchcancel` listener that clears mobile gesture state before Godot's regular release callback. Also clear on window blur, hidden-page transition, scene changes, modal opening, and resize/orientation changes. Keep any JavaScriptBridge callback reference alive. Verify callback ordering with an actual cancel event.
- Compute drag and pinch movement from absolute event positions keyed by touch index. This avoids dependence on changed-touch batch ordering and makes motion under alternating two-finger updates explicit.
- Filtering device -1 is correct for Godot emulation, but does not suppress browser-origin device-0 mouse motion. Guard mouse hover/edge-pan or cursor-following effects during a touch gesture if they would conflict.
- Once a second finger participates, latch the gesture as consumed until every participating contact is released. Lifting one finger must not convert the remaining finger into a fresh tap, box-select completion, or building placement.
- Ignore contacts already classified as UI-owned when deciding whether two world fingers form a pinch. Third-finger arrival, duplicate release, unknown index, or focus loss must leave no stuck state and issue no orders.

## CSS size, DPR, viewport scaling, and safe areas

Verified facts:

- `Window.content_scale_size` is a virtual-pixel base size, distinct from physical window size. Larger base dimensions make content appear smaller at the same actual size. Root values default to project viewport settings. [Window scaling reference](https://docs.godotengine.org/en/4.6/classes/class_window.html#class-window-property-content-scale-size)
- Godot's `canvas_items` mode scales 2D layout while drawing at the target resolution; the documentation recommends anchors and `expand` for varying mobile aspect ratios. [Multiple resolutions](https://docs.godotengine.org/en/4.6/tutorials/rendering/multiple_resolutions.html)
- In full-window resize policy 2, Godot 4.6 sizes canvas backing width/height from `window.innerWidth/innerHeight × devicePixelRatio`, and writes corresponding inline CSS dimensions. [Web canvas sizing implementation](https://github.com/godotengine/godot/blob/4.6-stable/platform/web/js/libs/library_godot_display.js#L225-L326)
- DPR relates physical pixels to CSS pixels. Canvas display size and backing-memory dimensions are different quantities. [MDN devicePixelRatio](https://developer.mozilla.org/en-US/docs/Web/API/Window/devicePixelRatio)
- With `viewport-fit=cover`, content can extend into the notch/home-indicator region. CSS `env(safe-area-inset-*)` exposes the needed insets, which should be combined with ordinary margins. [WebKit safe-area guide](https://webkit.org/blog/7929/designing-websites-for-iphone-x/)
- `DisplayServer.get_display_safe_area()` has native Android/iOS implementations; Web receives a fallback, so it is not the Web notch source. [DisplayServer safe area](https://docs.godotengine.org/en/4.6/classes/class_displayserver.html#class-displayserver-method-get-display-safe-area)
- `OS.has_feature("mobile")` is false for Web exports even on phones. Godot documents `web_android` and `web_ios` for this distinction. [Feature tags](https://docs.godotengine.org/en/4.6/tutorials/export/feature_tags.html)

Proposed integration contract:

1. On the mobile Web path, set root `content_scale_size` to the actual canvas CSS bounding rectangle's rounded width/height, with canvas-items scaling and content-scale factor 1. Read geometry again on resize/orientation changes. This makes HUD logical units track CSS pixels even with a DPR-scaled backing canvas. Apply before building/reflowing the mobile HUD.
2. Keep resize policy 2 and the canvas full-viewport for this first pass. Use `width=device-width, initial-scale=1, viewport-fit=cover` and read computed CSS safe-area insets through a small hidden probe element. Pass those numeric CSS insets into Godot HUD margins. Apply safe-area padding once. Do not separately inset/resize the canvas in CSS while policy 2 keeps overwriting its dimensions.
3. Do not multiply Godot event positions by DPR again. The engine already performs browser-to-canvas conversion and viewport scaling. If a CSS-inset canvas is introduced later, revise the resize policy and coordinate contract together.
4. Use `touch-action:none` on the game surface before gestures begin, so camera pinch/drag does not become page pinch/scroll. This disables browser gestures on that surface; provide readable UI and in-game zoom controls. Changes to touch-action during an active gesture do not change that gesture's handling. [MDN touch-action](https://developer.mozilla.org/en-US/docs/Web/CSS/Reference/Properties/touch-action)
5. Enable mobile layout from explicit mobile-Web features and/or a touch/coarse-pointer plus small-CSS-viewport rule, with a deliberate test override. A narrow desktop window alone should not switch PC interaction semantics. Hybrid-device detection remains a heuristic; test mouse and touch in the same session.

## Practical RTS precedents

- Company of Heroes mobile officially offers a persistent Command Panel and a mobile Command Wheel. The panel exposes selected-unit abilities at bottom right; the wheel supports press/drag/release with an explicit center-return cancellation gesture. This is evidence for visible contextual actions and a clear cancel path. It does not establish that RECLAMATION should copy the wheel. [Feral official control guide](https://www.feralinteractive.com/en/faqs/companyofheroes/1.0.2/ios/)
- Feral's ROME: Total War touch design uses familiar pan/pinch gestures; its UI design places frequent battle commands along the bottom and rarer actions in expandable submenus. [Touch design](https://www.feralinteractive.com/en/news/building-rome-the-touch-controls-of-rome-total-war-on-ipad/?platform=mac), [UI design](https://www.feralinteractive.com/en/news/building-rome-the-user-interface-of-rome-total-war-on-ipad/)
- ROME's later mobile update documents a collapsible group grid, target pins, location-based zoom, camera-pan speed adjustment, and a directly accessible Halt action. These support discoverable selection shortcuts and visible order feedback. [Feral Imperium update](https://www.feralinteractive.com/en/games/rometw/android-ios/imperium-update/)
- Company of Heroes' publisher release notes document a Queue Orders option with automatic disabling on unit deselection. This is a concrete mobile precedent for a visible queue state rather than requiring Shift. [Publisher App Store notes](https://apps.apple.com/us/app/company-of-heroes/id1464645812)

RECLAMATION adaptation: keep range-select, command, queue, and cancel visible and labeled; make active modes visibly persistent. Reserve drag for camera movement unless the player explicitly enables range selection. Prefer one-shot range/command modes that return to normal after completion, and clear queue when selection changes unless deliberately retained. A Move/Command button plus tap is a safe fallback when context-sensitive tap would make selecting another friendly entity ambiguous. Keep Stop/Pause reachable. Provide zoom +/- and selection shortcuts as alternatives to pinch and drag.

Aim for at least 44×44 CSS-pixel critical hit areas, preferably around 48–50 where space allows. This adopts the W3C enhanced target-size recommendation as a design target, not a claim of overall accessibility conformance. [W3C target size](https://www.w3.org/WAI/WCAG22/Understanding/target-size-enhanced.html) Single-pointer alternatives to dragging are also useful. [W3C dragging guidance](https://www.w3.org/WAI/WCAG22/Understanding/dragging-movements.html)

## Rendering, audio, and claims about iPhone support

Godot 4.6 Web requires WebAssembly and WebGL 2.0, uses Compatibility rendering, and cannot use its Mobile/Forward+ renderers. Single-threaded Web is the preferred default and specifically improves macOS/iOS compatibility; mobile Web still has performance caveats, and the docs note Safari-specific WebGL issues. Audio may be blocked until a user gesture. Default Sample playback has feature limits, including unsupported audio effects. Keep the existing single-threaded, PWA-disabled release configuration, and test audio after the start tap and after background/resume. [Godot Web export guide](https://docs.godotengine.org/en/4.6/tutorials/export/exporting_for_web.html)

WebGL exposes no portable maximum-VRAM query; browser-vendor guidance recommends budgeting allocations and considering a smaller backing buffer. [MDN WebGL practices](https://developer.mozilla.org/en-US/docs/Web/API/WebGL_API/WebGL_best_practices#estimate_a_per-pixel_vram_budget) A DPR-3 full-window canvas has nine times the pixel count of the same CSS dimensions at DPR 1. This arithmetic is a performance reason to measure/cap rendering cost independently of UI geometry. It is not evidence of a specific phone's memory limit.

Do not advertise a universal Safari memory cap, minimum iPhone model, sustained frame rate, battery behavior, or browser compatibility from viewport emulation. Do not repeat obsolete claims that Godot 4 Web cannot run on iOS at all. Desktop mobile emulation validates layout and event logic; only a real browser/device run validates that device's rendering, performance, interruption, audio, and memory behavior.

## Source inspection observations

Inspected `death_motion_candidate_v036` without launching or editing the engine/game:

- Project viewport is 1440×900 with canvas-items scaling and GL Compatibility.
- Web preset already uses single threading, policy 2, both desktop/mobile texture compression, and PWA disabled.
- `main.gd` handles left-button selection, right-button commands, Shift queueing, wheel zoom, arrow-key pan, and keyboard cancellation. Touch must bridge every one of those functions.
- Selection rectangle drawing and construction preview read mouse position. They need an explicit touch position when a mobile gesture is active.
- Minimap input is mouse-only and distinguishes left camera movement/right orders. Its mobile behavior needs an explicit contract.
- Context button tiles currently have a 72-unit height; simply scaling the entire desktop layout to phone height would produce approximately 31 CSS-pixel height at a 390/900 scale. Mobile requires reflow and new logical dimensions.

## Acceptance cases for the integration lead

- 844×390 and 932×430 at DPR 1/2/3: actual CSS hit size, safe areas, no clipped critical buttons, modal close/cancel, no portrait trap, both landscape directions, browser toolbar resize.
- A UI tap fires once and produces no world action; a world tap selects/commands once. UI-to-world drag and world-to-UI drag produce neither a stray order nor a stray button activation.
- One-finger drag pans with no final selection/order; range-select drag selects with no pan; tap below threshold stays a tap. Thresholds are CSS-equivalent across DPR.
- Pinch alternating one-finger movement, reversed release order, third-finger arrival, and all-fingers-up reset cause no camera jump or final tap. A finger on UI plus one on the world does not start a pinch.
- Browser `touchcancel`, blur, hidden-page transition, resize, and modal opening cancel pending tap/box/build and leave no stuck gesture.
- Build, repair/collect, attack/move, queue, rally, recruit/cancel, selection filters, minimap, pause, options, and save/load remain reachable without keyboard or right click.
- Desktop mouse/keyboard behavior remains intact, including real mouse after touch on a hybrid device.
- Audio starts after user gesture; return from background is tested. Long battle/load/reload and WebGL context loss are separate browser/performance tests. Report physical-device checks as unrun until actually exercised.
