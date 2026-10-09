# Remembering a discovered infection source

Ordinary scouting play found the infection source, then lost its four-person squad during an attack. The discovered structure disappeared completely from the battlefield, while known ordinary ruins remained dimly visible and the minimap retained the objective marker.

The discovered static structure now retains its last observed shape under the existing explored-terrain fog. Unknown structures remain hidden. Current HP remains hidden outside sight; alarm illumination and structural changes do not update the remembered appearance. Returning friendly vision restores the current appearance. No targeting, damage, emergence timing, resources, save schema or unit visibility rules change.

The same unedited scout-loss save was rendered with the former visibility setting and the corrected setting. Complete saved simulation states match. The normal-distance image now contains a subdued building landmark. Draw calls in this paused native scene rise196→200, including shadow rendering; this is a visibility improvement with a small additional draw workload, not a performance improvement. The initial capture helper left the HUD unrefreshed; the final images explicitly refresh its derived display.

Focused checks cover discovery, hidden alarms, remembered structural shape, restored sight and unchanged saved state; existing frontier integration checks pass. Independent code/image review accepted the bounded change. Native cloud rendering and controlled presentation comparison do not establish real phone/browser/GPU performance or first-time human usability.
