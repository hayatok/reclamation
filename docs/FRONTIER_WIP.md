# M2 frontier integration checkpoint

This is an unaccepted development checkpoint after v0.42. It replaces operation 2's escort goal with exploration and destruction of an infected source. It is not a completed release or a recreation of a previously lost build.

## Implemented

The playable district expands from 60×60m to 192×160m, with 200×168m terrain, two canal bridges and four separated ruin districts. The camera remains at normal RTS scale. Headquarters, starter resources, production exits, orders, escort destinations, camera limits and desktop/touch minimap mapping use a shared mission configuration. Operations 1 and 3 keep their existing dimensions and goals.

Workers can expand to two distant finite resource groups and use ordinary depots and defenses. Total authored food/salvage/parts remain 4800/6600/2800. Exploration stores current sight separately from remembered terrain. Unknown mobile enemies are excluded from rendering, selection, auto-targeting and minimap markers. The infected structure is only remembered after actual friendly sight; current visual/health disappears when sight is lost. A small 48×40 mask and one minimap background texture avoid a draw call per fog cell.

Two dormant packs wake on proximity or damage. Raids physically emerge from the infected structure's doors; a first attack causes a three-second alarm and a bounded emergence. Existing combat damage and ammunition values remain. The structure accepts rifle and artillery damage, including existing secondary splash reduction. Destroying it wins only after the same simulation step's headquarters-survival check. The old escort/hold victory and mission controls are absent from this operation.

M2 uses a new checkpoint schema with explored cells, discovered-structure memory, encounter clocks, camp membership and explicit structure focus targets. Invalid data is checked before replacement of live entities. No compatibility/migration requirement is imposed.

## Evidence and remaining gates

Actual Godot 4.6.3 main-scene integration passed startup, broad movement, hidden target exclusion, sight discovery, structure focus-fire, save/reload without duplicate camps, single artillery damage, and simultaneous HQ/nest death resolving as defeat. Separate bounds, encounter, fog/minimap and checkpoint fixtures passed. These are controlled engineering fixtures, not ordinary earned play or evidence that the mission is fun or balanced.

Native Compatibility/llvmpipe captures show the home at normal scale, fully hidden unknown structures, a deliberately positioned scout revealing the nest, and dim remembered terrain after the scout leaves. The scout positions in this visual fixture are controlled. They do not establish a successful scouting journey. The infected structure currently uses a simple original placeholder and the new ground has a visible striping issue under investigation.

Before acceptance: ordinary-resource exploration, expansion, regrouping after scout loss, assault and victory/failure; actual touch/minimap flow; M1/M3 integration regression; large-map navigation/frame measurements; refined infected-source art and final normal-camera review. Real phone, Mac, Web gameplay, target GPU performance, human first-play enjoyment and audio audition remain unverified. The cloud browser has no WebGL2; no security setting bypass was attempted.

Earlier small freight-resource and early-departure experiments remain archived as experiments. They are superseded by this wider-map direction and are not proof of its balance.
