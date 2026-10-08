"""Blender background check of editable source portability and export masters."""
import bpy, json, hashlib
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
reports={}
for name in ('ruined_freight_teal','ruined_freight_oxide','freight_transfer_gantry'):
    path=ROOT/'source'/(name+'.blend')
    bpy.ops.wm.open_mainfile(filepath=str(path))
    author=bpy.data.collections.get('AUTHORING | named editable components')
    export=bpy.data.collections.get('EXPORT_MASTER | one mesh one material')
    assert author and export and len(export.objects)==1
    assert len(author.objects)>=40
    assert all(obj.type=='MESH' for obj in author.objects)
    assert not any(obj.type in ('ARMATURE','LIGHT','CAMERA') for obj in bpy.data.objects)
    images=[]
    for image in bpy.data.images:
        if image.name in ('Render Result','Viewer Node'):continue
        assert image.packed_file is not None,(name,image.name)
        assert image.filepath.startswith('//../assets/'),(name,image.filepath)
        assert tuple(image.size)==(1024,1024),(name,image.size)
        expected=ROOT/'assets'/Path(image.filepath).name
        assert image.packed_file.data==expected.read_bytes(),(name,image.name)
        assert all(p.filepath.startswith('//../assets/') for p in image.packed_files)
        images.append({'name':image.name,'relative_path':image.filepath,'packed':True,'matches_runtime_png':True})
    assert len(images)==2
    assert bpy.context.scene.render.filepath.startswith('//../reports/'),name
    for screen in bpy.data.screens:
        for area in screen.areas:
            for space in area.spaces:
                if space.type=='FILE_BROWSER' and space.params:
                    assert bytes(space.params.directory).startswith(b'//'),name
    reports[name]={'passed':True,'editable_components':len(author.objects),'export_meshes':len(export.objects),
                   'images':images,'bytes':path.stat().st_size,'sha256':hashlib.sha256(path.read_bytes()).hexdigest()}
(ROOT/'reports/blend_validation_report.json').write_text(json.dumps(reports,indent=2)+'\n')
print('PACKED_FREIGHT_SOURCE',json.dumps(reports))
