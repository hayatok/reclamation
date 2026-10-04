"""Render the actual source mesh, never a concept proxy or painted icon."""
import bpy
from mathutils import Vector
from pathlib import Path
P=Path(__file__).resolve().parent.parent
bpy.ops.wm.open_mainfile(filepath=str(P/'source'/'siege_cart.blend'))
s=bpy.context.scene;s.render.engine='CYCLES';s.cycles.samples=32;s.cycles.use_denoising=False
s.render.resolution_percentage=100;s.render.image_settings.file_format='PNG';s.render.image_settings.color_mode='RGBA'
s.world.use_nodes=True;s.world.node_tree.nodes.get('Background').inputs['Color'].default_value=(.23,.28,.32,1);s.world.node_tree.nodes.get('Background').inputs['Strength'].default_value=.62
s.view_settings.view_transform='AgX'
for loc,power,size,col in [((-3,5,7),1200,5,(1,.88,.72)),((4,-3,5),1100,4,(.67,.82,1))]:
 bpy.ops.object.light_add(type='AREA',location=loc);o=bpy.context.object;o.data.energy=power;o.data.size=size;o.data.color=col;o.rotation_euler=(Vector((0,0,1))-o.location).to_track_quat('-Z','Y').to_euler()
bpy.ops.object.camera_add(location=(-5,6.7,4.8));camera=bpy.context.object;camera.data.type='ORTHO';camera.data.ortho_scale=4.85;s.camera=camera
bpy.ops.mesh.primitive_plane_add(size=200,location=(0,0,-.016));ground=bpy.context.object;m=bpy.data.materials.new('Preview ground only');m.diffuse_color=(.12,.15,.15,1);ground.data.materials.append(m)
for name,loc in [('front',(-5,6.7,4.8)),('rear',(5,-6.7,4.6))]:
 camera.location=loc;camera.rotation_euler=(Vector((0,0,1.0))-camera.location).to_track_quat('-Z','Y').to_euler()
 s.render.resolution_x=900;s.render.resolution_y=800;s.render.film_transparent=False;s.render.filepath=str(P/'previews'/f'siege_cart_{name}.png');bpy.ops.render.render(write_still=True)
ground.hide_render=True;s.render.film_transparent=True;s.render.resolution_x=256;s.render.resolution_y=256;camera.data.ortho_scale=4.4
camera.location=(-5,6.7,4.8);camera.rotation_euler=(Vector((0,0,1.0))-camera.location).to_track_quat('-Z','Y').to_euler();s.cycles.samples=48
s.render.filepath=str(P/'icons'/'siegecart_portrait.png');bpy.ops.render.render(write_still=True)
print('ACTUAL_MODEL_PREVIEW_AND_ALPHA_ICON_OK')
