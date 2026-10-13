# Recovered damaged warehouse geometry

The original retained damage generator and unchanged base generator reproduce the missing damaged GLB exactly: SHA256 c885cb01ff9981041d6de5baef701175ccc0817f6506ade0683be0f7436f278e, 200288 bytes. The hash agrees with the independently preserved original source-manifest target. The runtime Godot import description was generated again; it is not claimed byte-identical to the missing description.

The first checkpoint preserved this as an unintegrated asset. Current integration and its limited normal-distance/visibility/save acceptance are documented in docs/nest_damage_stage. The asset does not restore the whole missing former source release.

The original project-owned Python generator uses numpy and Pillow, no external artwork or paid service. Run source/build_infected_warehouse_damaged.py with --output-dir pointing to a separate output directory; keep the base generator beside it. Geometry metadata records two opaque surfaces, 3490 triangles and bounds inside the existing radius. Original material conventions remain unchanged.
