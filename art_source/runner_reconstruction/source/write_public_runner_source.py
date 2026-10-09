"""Export only editable runner scene datablocks, omitting Blender UI history.

Usage:
  blender --background --factory-startup --python write_public_runner_source.py -- input.blend output.blend

The atlas remains packed. Its already-relative path is preserved so copying the
source/assets tree does not expose machine-specific image or file-browser paths.
No runtime GLB, source input, mesh, rig, or material appearance is changed.
"""
import hashlib
import json
import sys
from pathlib import Path

import bpy

args=sys.argv[sys.argv.index('--')+1:]
source,destination=map(lambda p:Path(p).resolve(),args[:2])
assert source!=destination,'Preserve the original input'
source_sha=hashlib.sha256(source.read_bytes()).hexdigest()
bpy.ops.wm.open_mainfile(filepath=str(source),load_ui=False)
rig=bpy.data.objects['Runner_Original_Rig']
mesh=bpy.data.objects['Runner_Original_Civilian_Skinned']
scene=next(scene for scene in bpy.data.scenes if rig.name in scene.objects)
assert len(rig.data.bones)==18 and len(mesh.data.polygons)==1328
assert not bpy.data.libraries,'External libraries must not be included'
# Render destination is authoring metadata, not visible scene appearance.
scene.render.filepath=' '*1023
scene.render.filepath='//renders/'
for image in bpy.data.images:
    if image.name.startswith('runner_atlas'):
        image.filepath=' '*1023
        image.filepath='//../assets/runner_atlas.png'
        for packed in image.packed_files:
            packed.filepath=' '*1023
            packed.filepath='//../assets/runner_atlas.png'
# Existing relative paths remain unchanged. RELATIVE would remap the old input
# directory into the output and could reintroduce machine-specific components.
# Writing only a scene recursively includes its rig, meshes, collection,
# materials, world and packed image, without Screens or WindowManager UI state.
bpy.data.libraries.write(str(destination),{scene},path_remap='NONE',fake_user=True,compress=False)
assert hashlib.sha256(source.read_bytes()).hexdigest()==source_sha
raw=destination.read_bytes()
for forbidden in [b'/workspace/',b'/home/',b'/Users/',b'/tmp/',b'runner_art_candidate',b'azquez/',b'onfig/',b'lender/']:
    assert forbidden not in raw,repr(forbidden)
print('RUNNER_PUBLIC_DATABLOCK_WRITE_PASS',json.dumps({'source_unchanged':True,'scene':scene.name,'bones':len(rig.data.bones),'near_triangles':len(mesh.data.polygons),'bytes':len(raw),'sha256':hashlib.sha256(raw).hexdigest(),'private_path_scan_passed':True}))
