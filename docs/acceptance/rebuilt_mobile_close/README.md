# Rebuilt fixed mobile dismissal

This is new work based on verified fc9f2831. It does not restore the lost 1751-file source or its former 0.83 candidate. The incomplete recovered aftermath/boss assets are not overlaid into this runnable baseline.

The existing M2 selection details placed Close at y451 on an844x390 landscape viewport, below the initially visible page. A96x48 Close button now remains in a fixed header outside the scrolling details. The title truncates on narrow screens; existing detailed selection information remains in the scroll body. Bottom Close remains available.

Native Godot synthetic touch opened selection, scrolled the body, closed it, reopened twice while preserving an existing pause, rotated to390x844 with controlled top/bottom safe insets, closed again, and saved/reloaded. Full checkpoint data before/after the first close matched; no world command was issued. Before/after/portrait images were inspected. This is not physical-phone or browser acceptance. Sound fell back to Dummy.

A separate headless check booted all three baseline operations, selected HQ commands, and saved/reloaded each. The usual shutdown ObjectDB warning remains. An initial review script selected the old bottom Close instead of the new header control; that harness mistake was corrected before the successful run. No balance, unit timing, mission or art change is included.

Run the mobile check with --touch-ui --touch-ui-size=844x390 on native Godot; output is under user://rebuilt_mobile_close. The baseline check uses a separate user-data directory.
