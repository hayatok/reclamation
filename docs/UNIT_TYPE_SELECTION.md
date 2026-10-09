# Select a specialist group without repeated tiny unit clicks

The earned frontier army has twelve survivors, two grenadiers and one siege cart. Previously a mixed selection could only be replaced with all combat units or individually picked units. A rectangle around the two grenadiers also catches neighboring survivors.

- Desktop: double-click a friendly unit to select its exact kind within the camera viewport. Shift adds that visible kind to the existing selection. Single-click, box selection, production, targeting and orders retain their existing behavior.
- Touch layout: open Selection / Details while multiple kinds are selected. The existing popup offers 48-pixel type buttons with counts. A button narrows the current selection only; it does not recruit off-selection units. No permanent buttons or new touch gesture are added.
- Dead, queued-for-deletion and convoy actors are excluded. Modal choices block desktop selection. No path, fog, combat, economy or random-state queries are introduced.

## Verification

On the same paused, normally earned M2 state, actual cloud-native mouse double-click selected both grenadiers. A normal single click selected one survivor; Shift-double-click added both grenadiers. At synthetic 844×390, the actual popup button selected the two grenadiers and closed the popup. At 390×844, selecting the siege-cart button selected that one cart. Full saved game data, excluding selection, remained exactly equal through these native actions. Headless integration also verifies release retention, card blocking, selection-only filtering and save/reload. Semantic queries cover camera boundaries, actor validity and reference identity.

Japanese runtime font was regenerated for the new label, preserving the original licensed font source. Screenshots show the label and all three type buttons without clipping. The popup scrolls on landscape screens; no real phone/browser gesture or hardware performance claim is made. The selection query runs only on the explicit action, with a linear scan over friendly units; no per-frame render or simulation work is added.

## Design reference

The official Age of Empires II control guide documents double-click selection of same-type units on screen and information about multiple selected units: https://www.ageofempires.com/learn-to-play/control-resources-aoe2/ . RECLAMATION uses its own UI and art. The mobile current-selection filter is this game's adaptation.
