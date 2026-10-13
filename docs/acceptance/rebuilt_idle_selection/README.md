# Idle worker selection clears old touch orders

New reconstruction on the verified fixed-close checkpoint23d606bb. The original lost078/083 code was not recovered.

In native M2 at844x390, synthetic touches selected military, enabled Order and Append, then pressed the top Idle worker button. Before the fix the worker was selected but touch mode remained ORDER and append remained true; the next world tap would follow the old command mode instead of contextual selection. The HUD still said to tap a destination.

When a waiting worker is actually selected, the existing mobile cancel-command path now resets touch mode and append. This reuses gesture quarantine and does not issue Stop or erase unit tasks/routes. With the same input sequence, mode is now CONTEXT, append is false, and the HUD shows the selected worker. All serialized unit data remained identical; repeated idle cycling and save/reload passed. The PC branch (mobile_input is null) uses the unchanged selection code. An existing mixed mobile/PC harness was accidentally run without its required touch arguments: its early worker-selection checks passed, then it failed on the absent mobile HUD. That run is not counted as a regression pass. A subsequent bounded PC-only extraction of those existing checks completed with zero failures, including Shift+period, cargo/orders preservation and save/resume. Physical-phone/browser operation remains unverified.

One runtime line changed, in select_idle_worker. Empty selection, unit capabilities, economic rules and command costs are unchanged. The native sound backend used Dummy. Images show the actual before/after command state, not a new tutorial or panel.
