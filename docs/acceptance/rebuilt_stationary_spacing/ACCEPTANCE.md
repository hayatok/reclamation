# Stationary infantry readability

New reconstruction from current source, not recovered lost implementation.

Open-ground infantry settling uses a 0.70m radius rather than 0.55m so the 1.33m selection-ring diameter is no longer larger than the settled pair distance. Within one navigation cell of a wall/boundary, the old 0.55m radius is retained. This bounded check is cached per actor per simulation preparation. Existing maximum movement, target/range, worker reservation, blocked-path and escort exclusions remain. No enemy count, damage, upgrade or route destination was changed.

Same earned M2 assault save, ordinary Stop on the nine combatants on the eastern front, same size-50 camera and one second of simulation: pairs closer than the ring diameter decrease from 9 to 0. Largest displacement is 0.393m; elapsed time, kills and enemy count match. Both actual normal-distance images were inspected. This is modest separation/readability, not a new formation system or a full balance run.

An initial six-second observation reached victory before the picture and was excluded. A first universal radius increase worsened one-cell corridor crowding and was rejected. Final wall-aware version passes the existing 36-check movement/focus/stop/save-load/corridor suite and 14-check worker/convoy/reservation/speed/grid suite. Native Compatibility renderer used llvmpipe; real browser/phone/GPU and subjective human play remain untested. Extra cell lookups are bounded and cached; no FPS improvement is claimed.
