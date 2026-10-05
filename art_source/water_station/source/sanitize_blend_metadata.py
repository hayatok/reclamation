"""Make saved Blender path metadata portable, without touching asset content.
Run in Blender: blender --background --python source/sanitize_blend_metadata.py
"""
import bpy,hashlib,json,pathlib,struct
ROOT=pathlib.Path(__file__).resolve().parents[1]
path=ROOT/'source'/'water_station.blend'
bpy.ops.wm.open_mainfile(filepath=str(path))
def content_hashes():
    h=hashlib.sha256()
    for ob in sorted(bpy.data.objects,key=lambda o:o.name):
        if ob.type!='MESH':continue
        h.update(ob.name.encode())
        for row in ob.matrix_world:h.update(struct.pack('<4f',*row))
        for vertex in ob.data.vertices:h.update(struct.pack('<3f',*vertex.co))
        for polygon in ob.data.polygons:h.update(str(tuple(polygon.vertices)).encode())
        for layer in ob.data.uv_layers:
            h.update(layer.name.encode())
            for item in layer.data:h.update(struct.pack('<2f',*item.uv))
    images={image.name:hashlib.sha256(image.packed_file.data).hexdigest() for image in bpy.data.images if image.type=='IMAGE'}
    return {'geometry_uv_transforms_sha256':h.hexdigest(),'packed_image_sha256':images}
before=content_hashes()
for image in bpy.data.images:
    if image.type!='IMAGE':continue
    relative='//../assets/'+pathlib.Path(image.filepath).name
    image.filepath=relative
    for packed in image.packed_files:packed.filepath=relative
for screen in bpy.data.screens:
    for area in screen.areas:
        for space in area.spaces:
            if space.type=='FILE_BROWSER' and space.params:
                space.params.directory=b'//'
                space.params.filename=''
bpy.context.preferences.filepaths.save_version=0
bpy.ops.wm.save_as_mainfile(filepath=str(path))
bpy.ops.wm.open_mainfile(filepath=str(path))
after=content_hashes()
assert before==after, 'Metadata sanitation changed asset content'
raw=path.read_bytes()
patterns=[b'/workspace/',b'/home/',b'/tmp/']
assert all(pattern not in raw for pattern in patterns),'Absolute path remains in saved .blend'
report={'metadata_only':True,'source_reopen_pass':True,'content_hashes_unchanged':True,'content_hashes':after,'forbidden_path_counts':{pattern.decode():raw.count(pattern) for pattern in patterns},'blend_sha256':hashlib.sha256(raw).hexdigest()}
(ROOT/'reports').mkdir(exist_ok=True)
(ROOT/'reports'/'portable_metadata_validation.json').write_text(json.dumps(report,indent=2)+'\n')
print(json.dumps(report,indent=2))
