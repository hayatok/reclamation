"""Build one isolated original RECLAMATION road-rubble geometry comparison.

Run with Blender 4.3+:
  blender -b --python art_source/street_cover/source/build_rubble_revision.py -- --game-root .

Reads the existing runtime material and unchanged atlas. Writes only the near GLB
and contract.json beside this script. No blend file, preview, LOD, or game edits.
The GLB deliberately uses the same relative atlas image URIs as the runtime asset;
stage it alongside the existing images in assets/models for the native comparison.
"""
import argparse
import hashlib
import json
import math
import pathlib
import random
import struct
import sys
import tempfile

import bpy


NAME = 'shattered_road_obstruction'
BOUNDS = (6.0, 2.5, 0.9)  # Blender X/Y/Z; exported Godot X/Y/Z is 6/.9/2.5.
PARTS = []
ATLAS_HASHES = {
    'ruptured_water_main_street_salvage_albedo.png': '4a4253a92dd9e3d6f1314615e4a709d8c94ffbe8129a6fb71f2c95ac5bcdc78d',
    'ruptured_water_main_street_salvage_orm.png': 'f06c3d018f7e1cdc94f6043742ef6d7e3bf1ec540505b0adfb0dd3c61c95b990',
    'ruptured_water_main_street_salvage_normal.png': '909923be3862bdea132f146bde38ca7048179a8016e0211ca77042fb8c802439',
}


def read_glb(path):
    data = path.read_bytes()
    magic, version, size = struct.unpack_from('<4sII', data)
    assert magic == b'glTF' and version == 2 and size == len(data)
    json_size, json_type = struct.unpack_from('<II', data, 12)
    assert json_type == 0x4E4F534A
    doc = json.loads(data[20:20 + json_size])
    binary_size, binary_type = struct.unpack_from('<II', data, 20 + json_size)
    assert binary_type == 0x004E4942
    binary = data[28 + json_size:28 + json_size + binary_size]
    return doc, binary


def write_glb(path, doc, binary):
    doc['buffers'] = [{'byteLength': len(binary)}]
    body = json.dumps(doc, separators=(',', ':'), ensure_ascii=True).encode()
    body += b' ' * (-len(body) % 4)
    binary += b'\0' * (-len(binary) % 4)
    result = struct.pack('<4sII', b'glTF', 2, 28 + len(body) + len(binary))
    result += struct.pack('<II', len(body), 0x4E4F534A) + body
    result += struct.pack('<II', len(binary), 0x004E4942) + binary
    path.write_bytes(result)


def atlas_uv(ob, face_tiles):
    mesh = ob.data
    mesh.update()
    uv = mesh.uv_layers.new(name='SalvageAtlas')
    low = [min(v.co[k] for v in mesh.vertices) for k in range(3)]
    high = [max(v.co[k] for v in mesh.vertices) for k in range(3)]
    span = [max(0.01, high[k] - low[k]) for k in range(3)]
    for face in mesh.polygons:
        tile = face_tiles[face.index]
        normal_axis = max(range(3), key=lambda k: abs(face.normal[k]))
        axes = [k for k in range(3) if k != normal_axis]
        for loop_index in face.loop_indices:
            p = mesh.vertices[mesh.loops[loop_index].vertex_index].co
            u = 0.025 + 0.95 * (p[axes[0]] - low[axes[0]]) / span[axes[0]]
            v = 0.025 + 0.95 * (p[axes[1]] - low[axes[1]]) / span[axes[1]]
            uv.data[loop_index].uv = ((tile % 4 + u) / 4, 1 - (tile // 4 + v) / 2)
    mesh.materials.append(MATERIAL)


def fragment(name, centre, size, seed, rotation=0, top_tile=1, side_tile=0,
             pitch=(0, 0), ridge=0.06, bevel_width=0.018, slab=False):
    """Closed original irregular solid, with broad planar fracture faces.

    Slabs retain a thin asphalt cap and exposed concrete fracture thickness.
    Raised middle vertices describe buckling or a rubble crest, never a basin.
    """
    rng = random.Random(seed)
    outline = [(-.50, -.26), (-.32, -.50), (.10, -.47), (.43, -.35),
               (.50, -.04), (.38, .39), (.07, .50), (-.36, .35)]
    outline = [(x + rng.uniform(-.045, .045), y + rng.uniform(-.04, .04))
               for x, y in outline]
    vertices = []
    count = len(outline)
    for layer in range(3):
        for x, y in outline:
            # Layer 1 is the broken shoulder; the crown shrinks irregularly.
            factor = (rng.uniform(.84, .95) if layer == 0 else
                      1.0 if layer == 1 else rng.uniform(.74, .94))
            if slab:
                factor = (rng.uniform(.91, .98) if layer == 0 else
                          1.0 if layer == 1 else rng.uniform(.86, .97))
            px, py = x * size[0] * factor, y * size[1] * factor
            pz = (0, .72, 1)[layer] * size[2]
            if layer == 2:
                pz += rng.uniform(-.13, .11) * size[2]
            pz += px * pitch[0] + py * pitch[1]
            c, s = math.cos(rotation), math.sin(rotation)
            vertices.append((centre[0] + px * c - py * s,
                             centre[1] + px * s + py * c,
                             centre[2] + pz))
    faces, tiles = [], []
    for layer in range(2):
        for i in range(count):
            faces.append((layer * count + i, layer * count + (i + 1) % count,
                          (layer + 1) * count + (i + 1) % count,
                          (layer + 1) * count + i))
            tiles.append(side_tile if layer == 0 else 1)
    faces.append(tuple(reversed(range(count))))
    tiles.append(side_tile)
    crown = [sum(vertices[2 * count + i][k] for i in range(count)) / count
             for k in range(3)]
    crown[0] += size[0] * .045
    crown[1] -= size[1] * .055
    crown[2] += ridge
    vertices.append(tuple(crown))
    for i in range(count):
        faces.append((2 * count + i, 2 * count + (i + 1) % count, 3 * count))
        tiles.append(top_tile)
    mesh = bpy.data.meshes.new(name + '_mesh')
    mesh.from_pydata(vertices, [], faces)
    mesh.update()
    ob = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(ob)
    atlas_uv(ob, tiles)
    if bevel_width:
        bpy.context.view_layer.objects.active = ob
        modifier = ob.modifiers.new('Broad_fracture_edge', 'BEVEL')
        modifier.width = bevel_width
        modifier.segments = 1
        bpy.ops.object.modifier_apply(modifier=modifier.name)
    PARTS.append(ob)
    return ob


def build_geometry():
    # Four interlocking but separately sheared foundations keep the full route
    # visibly blocked. The ends taper, and both long sides have broad setbacks.
    bases = [(-2.10, -.13, 1.65, 1.64, .36, -.19),
             (-.83, .15, 1.98, 1.78, .51, .16),
             (.71, -.08, 1.92, 1.78, .47, -.25),
             (2.08, .10, 1.47, 1.44, .31, .28)]
    for i, (x, y, length, width, height, turn) in enumerate(bases):
        fragment('Sheared_foundation_%02d' % i, (x, y, .015),
                 (length, width, height), 3200 + i, turn,
                 top_tile=0, ridge=.07)

    # Three broad asphalt road plates lie at different heights and inclinations.
    # Their dark faces reach different outer edges instead of enclosing a dark
    # central strip within a continuous pale rim.
    plates = [(-1.55, -.37, .34, 1.99, 1.16, .20, -.23, .13, .20),
              (.10, .43, .35, 1.53, 1.18, .21, .46, -.14, -.18),
              (1.70, -.20, .27, 1.70, 1.07, .22, -.38, -.11, .20)]
    for i, (x, y, z, length, width, height, turn, px, py) in enumerate(plates):
        fragment('Displaced_asphalt_slab_%02d' % i, (x, y, z),
                 (length, width, height), 3300 + i, turn,
                 top_tile=2, side_tile=0, pitch=(px, py), ridge=.045,
                 bevel_width=.014, slab=True)

    # Broad exposed concrete chunks cross the former hollow-looking centre.
    # They form an uneven filled crest, with one tall fractured piece and two
    # low diagonal falls. These are substantial rubble, not extra micro-detail.
    chunks = [(-.70, -.04, .39, 1.22, .90, .28, .54, .13, -.07),
              (.48, -.12, .35, 1.26, 1.03, .38, -.35, -.09, .11),
              (1.43, .47, .25, 1.06, .83, .30, .70, -.10, .06)]
    for i, (x, y, z, length, width, height, turn, px, py) in enumerate(chunks):
        fragment('Exposed_concrete_crest_%02d' % i, (x, y, z),
                 (length, width, height), 3400 + i, turn,
                 top_tile=1, pitch=(px, py), ridge=.085, bevel_width=.018)

    # Only two displaced curb remnants survive. Neither continues a long rim.
    fragment('Displaced_curb_end', (-2.47, .20, .055), (.69, .46, .33),
             3501, -.51, top_tile=1, ridge=.025)
    fragment('Fallen_curb_crosspiece', (.97, -.60, .16), (.87, .39, .26),
             3502, .68, top_tile=1, pitch=(.09, .03), ridge=.025)

    # Low, larger detached fall pieces leave deliberate long gaps along both
    # edges. The core occupies these setbacks so they cannot suggest a walkway.
    fall = [(-2.34, -.66, .045, .74, .61, .19, .25, 0),
            (-1.55, .69, .030, .90, .66, .24, -.40, 1),
            (-.23, -.81, .020, .84, .55, .19, -.27, 2),
            (.50, .83, .030, .82, .58, .23, .34, 0),
            (1.86, -.70, .020, .78, .57, .17, .51, 1),
            (2.52, .52, .015, .63, .62, .19, -.21, 7)]
    for i, (x, y, z, length, width, height, turn, tile) in enumerate(fall):
        fragment('Detached_road_fall_%02d' % i, (x, y, z),
                 (length, width, height), 3600 + i, turn,
                 top_tile=tile, side_tile=tile, ridge=.025, bevel_width=.012)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--game-root', type=pathlib.Path,
                        default=pathlib.Path(__file__).resolve().parents[3])
    parser.add_argument('--output-dir', type=pathlib.Path,
                        default=pathlib.Path(__file__).resolve().parents[1] / 'generated_rubble')
    args = parser.parse_args(sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else [])
    model_dir = args.game_root / 'assets' / 'models'
    baseline_path = model_dir / (NAME + '.glb')
    baseline, _ = read_glb(baseline_path)
    assert len(baseline['materials']) == 1
    for image in baseline['images']:
        uri = image['uri']
        assert uri in ATLAS_HASHES
        assert hashlib.sha256((model_dir / uri).read_bytes()).hexdigest() == ATLAS_HASHES[uri]

    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.object.delete(use_global=False)
    global MATERIAL
    MATERIAL = bpy.data.materials.new('StreetSalvage_Atlas_PBR')
    MATERIAL.use_nodes = True
    build_geometry()

    lower = [min(v.co[k] for ob in PARTS for v in ob.data.vertices) for k in range(3)]
    upper = [max(v.co[k] for ob in PARTS for v in ob.data.vertices) for k in range(3)]
    for ob in PARTS:
        for vertex in ob.data.vertices:
            for k in range(3):
                vertex.co[k] = ((vertex.co[k] - lower[k]) / (upper[k] - lower[k]) * BOUNDS[k]
                                - (BOUNDS[k] / 2 if k < 2 else 0))
    bpy.ops.object.select_all(action='DESELECT')
    for ob in PARTS:
        ob.select_set(True)
    bpy.context.view_layer.objects.active = PARTS[0]
    bpy.ops.object.join()
    ob = bpy.context.object
    ob.name = NAME
    ob.data.name = 'Broken_road_rubble_crest'
    ob.data.materials.clear()
    ob.data.materials.append(MATERIAL)
    for face in ob.data.polygons:
        face.material_index = 0
    modifier = ob.modifiers.new('Export_triangles', 'TRIANGULATE')
    bpy.ops.object.modifier_apply(modifier=modifier.name)
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    triangles = len(ob.data.polygons)
    baseline_primitive = baseline['meshes'][0]['primitives'][0]
    baseline_triangles = baseline['accessors'][baseline_primitive['indices']]['count'] // 3
    assert triangles <= baseline_triangles
    assert all(math.isfinite(c) for v in ob.data.vertices for c in v.co)
    assert all(0 <= c <= 1 for uv in ob.data.uv_layers.active.data for c in uv.uv)

    args.output_dir.mkdir(parents=True, exist_ok=True)
    output = args.output_dir / (NAME + '.glb')
    # The transient export has geometry and UVs only. Reuse the baseline material
    # table verbatim so the delivered asset references the untouched runtime atlas.
    with tempfile.TemporaryDirectory(prefix='reclamation_cover_export_') as temp:
        raw = pathlib.Path(temp) / 'geometry.glb'
        bpy.ops.export_scene.gltf(filepath=str(raw), export_format='GLB',
                                  use_selection=True, export_texcoords=True,
                                  export_normals=True, export_materials='EXPORT',
                                  export_yup=True, export_apply=True, export_extras=False)
        doc, binary = read_glb(raw)
    for key in ('materials', 'textures', 'images', 'samplers'):
        doc[key] = baseline[key]
    assert len(doc['meshes']) == 1 and len(doc['meshes'][0]['primitives']) == 1
    primitive = doc['meshes'][0]['primitives'][0]
    primitive['material'] = 0
    position = doc['accessors'][primitive['attributes']['POSITION']]
    assert all(abs(a - b) < 1e-6 for a, b in zip(position['min'], (-3, 0, -1.25)))
    assert all(abs(a - b) < 1e-6 for a, b in zip(position['max'], (3, .9, 1.25)))
    doc['nodes'][0]['extras'] = {
        'contract': 'Ground origin. +X long axis. Runtime visual only. No collider.',
        'normalized_size_godot': '6, 0.9, 2.5',
        'source': 'Original procedural geometry and unchanged RECLAMATION atlas.',
    }
    write_glb(output, doc, binary)
    contract = {
        'asset': NAME,
        'variant': 'filled broken crest; displaced broad slabs; interrupted curb remains',
        'triangles': triangles,
        'baseline_triangles': baseline_triangles,
        'surfaces': 1,
        'bounds_godot': [6, .9, 2.5],
        'origin': [0, 0, 0],
        'ground_y': 0,
        'long_axis': '+X',
        'uv': 'SalvageAtlas; finite and in [0,1]',
        'material': 'exact baseline PBR material and relative atlas image URIs',
        'atlas_sha256': ATLAS_HASHES,
        'baseline_glb_sha256': hashlib.sha256(baseline_path.read_bytes()).hexdigest(),
        'candidate_glb_sha256': hashlib.sha256(output.read_bytes()).hexdigest(),
        'generator_sha256': hashlib.sha256(pathlib.Path(__file__).read_bytes()).hexdigest(),
        'native_comparison': 'pending; one candidate only',
    }
    (args.output_dir / 'contract.json').write_text(json.dumps(contract, indent=2) + '\n')
    print('STREET_COVER_CANDIDATE_PASS', json.dumps(contract, separators=(',', ':')))


if __name__ == '__main__':
    main()
