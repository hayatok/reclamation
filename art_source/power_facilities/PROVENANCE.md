# RECLAMATION civilian power facilities: original source and provenance

This pass authors two new original assets for RECLAMATION on 2026-10-05. It distinguishes the final-mission central transmission station from the refuge transformer substation. These are new designs for the game's established setting, not an exact recovery of earlier missing models.

The component geometry, arrangement, low-poly profiles, UV placement, damage, repairs, and solid-geometry electricity pictogram were authored in `source/build_power_facilities.py`. No downloaded mesh, scan, photograph, stock texture, external logo, or generated-image input is included. The generator follows the project's existing Blender component-authoring approach; it preserves editable individual parts alongside one joined runtime mesh.

## Existing material reused

Both assets reuse the existing original RECLAMATION salvage atlas without altering its pixels. Their GLBs reference `ammo_workshop_salvage_albedo.png`, `ammo_workshop_salvage_orm.png`, and `ammo_workshop_salvage_normal.png` already shipped in `assets/models`. These are the same byte-identical maps found in `art_source/defenses/assets`; the original generator remains `art_source/defenses/source/create_atlas.py`. This pass creates no second atlas and embeds no image bytes in its runtime GLBs. Packed copies in the editable Blender files keep the source portable.

## Public functional-form references

Primary manufacturer material was consulted only to understand recognizable civilian utility forms. These pages and their pictures remain the property of their respective holders; no reference image, brand, exact manufactured product, or engineering design is reproduced or distributed with these assets.

- Hitachi Energy, [Vertical-break disconnectors DDV](https://www.hitachienergy.com/uk-ie/en/products-and-solutions/disconnectors/vertical-break-disconnectors-up-to-245-kv), accessed 2026-10-05. The raised blade, separated contact jaw and insulator-supported open current path informed the central station's silhouette. [Manufacturer product image](https://everywhere.products.hitachienergy.com/webimages/public/default/product/9AAF409713/preview).
- Siemens Energy, [Power transformers brochure](https://assets.siemens-energy.com/dam/6813d44e-8a11-47a5-bef3-b13a00f783df/Power-Transformers-Brochure_SE-Final-pdf_Original%20file.pdf), accessed 2026-10-05. Tank-mounted radiator banks, upper bushings and oil conservator informed the refuge unit's broad, solid shape.
- Hitachi Energy, [Non-condenser porcelain bushings](https://www.hitachienergy.com/us/en/products-and-solutions/insulation-and-components/transformer-insulation-components/transformer-bushings/bushings-product-selection/non-condenser-porcelain-bushings), accessed 2026-10-05. Ribbed porcelain around the conductor informed the deliberately exaggerated low-poly bushing profiles.

Chipped concrete, old masonry, corroded steel, exposed control leads, replaced straps and mismatched cabinet doors tie them to ruined civilian infrastructure being restored by a refuge community.

This document records provenance; it does not establish or change copyright licensing. No new CC0, MIT, Creative Commons or other blanket license grant is asserted. Distribution and use remain subject to the project's applicable ownership, agreements and license terms. Blender and Godot identify authoring and validation tools, not asset authors or licensors.
