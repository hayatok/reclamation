# Recognizable bulk resource caches

A native M2 play session restored the frontier depot, gathered food there and built housing and workers at the home base. At normal camera size 50, the frontier's large resource stocks still appeared as a few shallow boxes and scrap strips. The three resource models now use distinct bulk silhouettes: provisions under a partial tarp, strapped structural beams with torn sheet metal, and stripped machinery with an exposed wheel and copper winding.

The models remain within the existing 1.4 m gathering footprint, below the 2 m labels, and grounded at y=0. They keep one shared opaque indexed surface each and the original resource parent, fog/depletion visibility, selection, stock, worker approach and economy rules. They introduce no RNG calls or per-frame processing.

## Acceptance and cost

- Same unedited native play save at 197.80 s, same normal-50 camera and 1180×737 viewport. Independent pixel review accepted clearer separation of all three resource types and nearby workers.
- This improves the resource objects; it does not resolve the broad empty district's overall environmental identity.
- Food 772 triangles, salvage 542, parts 1,488. Geometry instantiation verified bounds, ground contact, cache reuse, one opaque surface and nondegenerate triangles.
- Sixty paused-frame workload samples: draw calls remain 190; rendered primitives rise from 49,931 to 56,585 (+6,654). This is an explicit visual-quality cost, not an FPS improvement. Software rendering is not real GPU/browser benchmarking.
- Existing frontier-depot regression passed, including paid restoration, delivery and other missions. Real browser/phone/Mac interaction and first-time human evaluation remain unverified.

Original source geometry and provenance are in `resource_visuals.gd` and `licenses/Bulk-Resource-Models.md`. This is a development checkpoint after public 0.48.0; no Pages publication is requested.
