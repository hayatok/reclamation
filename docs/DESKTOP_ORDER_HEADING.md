# Selected orders visible in the desktop dock

An ordinary native M2 play sequence restored the frontier warehouse, assigned its workers to food, returned through the minimap and built housing at the home base. The commands worked, but the selection panel showed the same construction category during movement, restoration and gathering. `selection_info` contained the status on a second line that the compact desktop dock clipped.

Selected desktop units now show their existing live order in the command heading. The identity, HP, buttons and queue retain their positions; blocked paths and work-space waits retain the existing status priority. The mobile layout and simulation are unchanged. No new instruction panel or permanent HUD row was added.

## Verification

- Matched native 1180×737 captures of the same earned save and restoration order show the category replaced by 復旧中. Complete saved gameplay state, including RNG, is identical.
- Real native input confirmed the selected worker's gathering order and a subsequent headquarters selection with its normal production controls.
- Focused scene checks cover paused two-worker restoration, refresh invariance, controlled blocked/work-space-wait states, headquarters production queue, combat selection and empty selection. Controlled navigation states test presentation rather than pathfinding.
- Cloud native rendering does not verify real browser, phone, Mac hardware or first-time human play. No performance improvement is claimed.

This is a development checkpoint after public 0.48.0, not a separate Pages release.
