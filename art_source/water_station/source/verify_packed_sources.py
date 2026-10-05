"""Verify reopenable .blend, editable components and packed image dependencies."""
import bpy,json,pathlib
ROOT=pathlib.Path(__file__).resolve().parents[1]
for folder in ('assets', 'reports', 'previews', 'source'):
    (ROOT/folder).mkdir(parents=True, exist_ok=True)
bpy.ops.wm.open_mainfile(filepath=str(ROOT/'source'/'water_station.blend'))
assert not bpy.data.libraries
imgs=[x for x in bpy.data.images if x.type=='IMAGE']
assert len(imgs)==3 and all(x.packed_file for x in imgs)
assert all(x.filepath.startswith('//../assets/') for x in imgs)
assert all(packed.filepath.startswith('//../assets/') for image in imgs for packed in image.packed_files)
raw=(ROOT/'source'/'water_station.blend').read_bytes()
assert all(path not in raw for path in (b'/workspace/',b'/home/',b'/tmp/')), 'Absolute path metadata in distributable source'
for screen in bpy.data.screens:
    for area in screen.areas:
        for space in area.spaces:
            if space.type=='FILE_BROWSER' and space.params:
                assert space.params.directory in (b'',b'//'),space.params.directory
author=bpy.data.collections['AUTHORING | editable original components']
assert len(author.objects)>140 and author.hide_viewport and author.hide_render
assert all(len(o.data.uv_layers)==1 and o.data.uv_layers[0].name=='MunicipalAtlas' for o in author.objects)
export=bpy.data.collections['EXPORT_MASTER | runtime single surface'];assert len(export.objects)==1
master=export.objects[0];assert len(master.material_slots)==1 and len(master.data.polygons)<=10000
report={'editable_components':len(author.objects),'packed_images':len(imgs),'external_blender_libraries':0,'uniform_uv_layer':'MunicipalAtlas','export_triangles':len(master.data.polygons),'source_reopen_pass':True,'packed_file_paths_relative':True,'saved_browser_paths_relative':True,'binary_absolute_path_scan_pass':True}
(ROOT/'reports'/'packed_source_validation.json').write_text(json.dumps(report,indent=2)+'\n');print(json.dumps(report))
