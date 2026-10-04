import bpy,json
from pathlib import Path
P=Path(__file__).resolve().parent.parent
out=[]
for name in ['house','depot','barracks','vehicle_workshop','garden']:
 bpy.ops.wm.open_mainfile(filepath=str(P/'source'/f'{name}.blend'))
 images=[im for im in bpy.data.images if im.source=='FILE' and im.users>0]
 assert len(images)>=3
 assert all(im.packed_file is not None for im in images)
 heroes=[o for o in bpy.context.scene.objects if o.type=='MESH' and o.name==name+'_LOD0']
 assert len(heroes)==1
 h=heroes[0]
 assert len(h.data.materials)==1 and h.location.length<.0001
 assert len(h.data.uv_layers.active.data)>0
 editable=[c for c in bpy.data.collections if c.name.startswith('AUTHORING') and len(c.objects)>0]
 assert len(editable)==1 and len(editable[0].objects)>20
 out.append({'name':name,'packed_images':[im.name for im in images],'editable_components':len(editable[0].objects),'hero_triangles':len(h.data.polygons),'one_material':True,'origin':[0,0,0]})
(P/'reports'/'packed_source_checks.json').write_text(json.dumps({'pass':True,'sources':out},indent=2))
print('SETTLEMENT_PACKED_SOURCE_PASS')
