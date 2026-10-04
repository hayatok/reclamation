import bpy,json
from pathlib import Path
P=Path(__file__).resolve().parent.parent
bpy.ops.wm.open_mainfile(filepath=str(P/'source'/'siege_cart.blend'))
images=[i for i in bpy.data.images if i.source=='FILE']
assert len(images)==3
assert all(i.packed_file is not None for i in images)
assert len(bpy.data.libraries)==0
col=bpy.data.collections['EDITABLE_COMPONENTS']
assert len(col.objects)==426
assert bpy.data.objects['Siege_Cart_LOD0'].location.length < 0.00001
report={'pass':True,'packed_images':[i.name for i in images],'linked_libraries':0,'editable_components':len(col.objects),'export_master_triangles':len(bpy.data.objects['Siege_Cart_LOD0'].data.polygons)}
json.dump(report,open(P/'reports'/'packed_source_check.json','w'),indent=2)
print('PACKED_EDITABLE_SOURCE_CHECK_PASS',report)
