# 0.64.0 — reconstructed usability update

Built from remotely verified fc9f2831 plus five newly reimplemented, individually preserved changes. This is not byte-identical restoration of the lost 1751-file candidate, nor publication of the lost planned 0.83. Public baseline is 0.63.0. Retained power-planning display from fc9f2831 is included.

## Included changes and evidence

- [Fixed mobile Close](acceptance/rebuilt_mobile_close/README.md): visible dismissal outside scrolling content, safe areas and pause ownership.
- [Idle worker selection](acceptance/rebuilt_idle_selection/): clears stale mobile command/append intent without changing workers' work.
- [Temporary expanded map](acceptance/rebuilt_expanded_map/ACCEPTANCE.md): same minimap/fog source, camera-only tap, back/close, interruption quarantine.
- [Optional desktop operation details](acceptance/rebuilt_objective_fold/ACCEPTANCE.md): actual mouse click reduces the tested panel from 249 to 116 pixels while retaining goal, HP, warning and dynamic progress.
- [Stationary infantry spacing](acceptance/rebuilt_stationary_spacing/ACCEPTANCE.md): open ground improves ring separation; wall-adjacent cells preserve the old radius. Existing range, work reservations, navigation, speed and save/load regressions pass.

## Limits

Native Godot 4.6.3 Compatibility/llvmpipe and synthetic touch are not real browser/phone/GPU validation. macOS execution, actual phone ergonomics, human first-time play and audio listening remain unverified. Generic shutdown ObjectDB warnings and modal-replacement outside-tree diagnostics remain; no stuck map or lost selection was observed. No FPS improvement is claimed. Music candidates, missing boss assets and the lost central-substation combat prototype are excluded. Existing mission victory rules remain.

Final distribution must be freshly exported from the exact remotely read-back source commit. Commit and artifact checksums belong in BUILD-PROVENANCE.json generated during packaging, not guessed here.
