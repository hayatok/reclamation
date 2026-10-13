# Temporary mobile map

New reconstruction from verified checkpoint 447b9934, not a recovery of the lost prior implementation.

The selection sheet has a Map button. It reuses the existing minimap, expanding the 104-pixel landscape map to 300 × 250 pixels at 844 × 390. Portrait is approximately 352 × 293 at 390 × 844 with safe insets. Map taps move the camera only. The fixed header closes to play; Back returns to selection. Fog, visible units and remembered objectives are drawn by the existing minimap without a second information source.

Native Godot 4.6.3 Compatibility/llvmpipe synthetic touch passed camera navigation, multiple-finger rejection, drag cancellation, rotation during touch, browser touchcancel and blur followed by ordinary release, repeated open/back, fixed close, selection and serialized orders unchanged, pause preserved, save/load. Existing font coverage check passed. Screen images were inspected at both sizes. No real phone, browser or GPU performance claim. Native audio used Dummy fallback. Modal replacement emits three can_process outside-tree diagnostics; no lost map, stuck input or order mutation was observed.

The test sets fresh M2 paused and disables simulation to compare input effects exactly. It does not prove normal campaign completion or human usability.
