import bpy,math
from mathutils import Vector
from pathlib import Path
P=Path(__file__).resolve().parent.parent
for name in ['supply_truck','evacuation_carrier']:
 for view,loc in [('front',(-5.2,6.2,4.4)),('rear',(5.2,-6.2,4.2))]:
  bpy.ops.wm.open_mainfile(filepath=str(P/'source'/f'{name}.blend'))
  s=bpy.context.scene;s.render.engine='CYCLES';s.cycles.samples=48;s.cycles.use_denoising=False
  s.render.resolution_x=1000;s.render.resolution_y=850;s.render.resolution_percentage=100
  s.world.use_nodes=True;s.world.node_tree.nodes.get('Background').inputs['Color'].default_value=(.25,.30,.33,1);s.world.node_tree.nodes.get('Background').inputs['Strength'].default_value=.48
  s.view_settings.view_transform='AgX'
  bpy.ops.mesh.primitive_plane_add(size=200,location=(0,0,-.014));ground=bpy.context.object
  m=bpy.data.materials.new('Studio neutral ground');m.diffuse_color=(.16,.175,.16,1);ground.data.materials.append(m)
  for l,power,size,col in [((-3,5,7),1050,5,(1,.89,.72)),((4,-4,5),900,4,(.68,.82,1))]:
   bpy.ops.object.light_add(type='AREA',location=l);o=bpy.context.object;o.data.energy=power;o.data.shape='DISK';o.data.size=size;o.data.color=col;o.rotation_euler=(Vector((0,0,1))-o.location).to_track_quat('-Z','Y').to_euler()
  bpy.ops.object.camera_add(location=loc);o=bpy.context.object;o.rotation_euler=(Vector((0,0,1.0))-o.location).to_track_quat('-Z','Y').to_euler();o.data.type='ORTHO';o.data.ortho_scale=4.55;s.camera=o
  s.render.filepath=str(P/'previews'/f'{name}_{view}_blender.png');bpy.ops.render.render(write_still=True)
print('BLENDER_VEHICLE_ART_REVIEW_SAVED')
