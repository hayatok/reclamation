import bpy
from pathlib import Path
P=Path(__file__).resolve().parent.parent
def sanitize_uv(o):
 # Decimation may extrapolate corner UVs; keep each triangle in its original atlas tile.
 uv=o.data.uv_layers.active
 for face in o.data.polygons:
  coords=[uv.data[k].uv.copy() for k in face.loop_indices]
  xs=sorted(max(0,min(3,int(q.x*4))) for q in coords);ys=sorted(max(0,min(3,int(q.y*4))) for q in coords)
  x=xs[len(xs)//2];y=ys[len(ys)//2]
  for k in face.loop_indices:
   q=uv.data[k].uv;q.x=max((x+.03)/4,min((x+.97)/4,q.x));q.y=max((y+.03)/4,min((y+.97)/4,q.y))

for name in ['supply_truck','evacuation_carrier']:
 bpy.ops.wm.open_mainfile(filepath=str(P/'source'/f'{name}.blend'))
 hero=[o for o in bpy.context.scene.objects if o.type=='MESH' and 'LOD0' in o.name][0]
 bpy.ops.object.select_all(action='DESELECT');hero.select_set(True);bpy.context.view_layer.objects.active=hero
 for n,ratio in [(1,.44),(2,.45)]:
  dec=hero.modifiers.new('Validated explicit mesh LOD','DECIMATE');dec.ratio=ratio;bpy.ops.object.modifier_apply(modifier=dec.name)
  hero.data.validate(clean_customdata=True);hero.data.update();sanitize_uv(hero);hero.name=name+'_LOD'+str(n)
  bpy.ops.export_scene.gltf(filepath=str(P/'assets'/f'{name}_lod{n}.glb'),export_format='GLB',use_selection=True,export_texcoords=True,export_normals=True,export_tangents=True,export_materials='EXPORT',export_yup=True)
print('VALIDATED_LOD_EXPORT_OK')
