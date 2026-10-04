import bpy,math
from pathlib import Path
from mathutils import Vector
P=Path(__file__).resolve().parent.parent
for name in ['house','depot','barracks','vehicle_workshop','garden']:
 bpy.ops.wm.open_mainfile(filepath=str(P/'source'/f'{name}.blend'))
 scene=bpy.context.scene;scene.render.engine='CYCLES';scene.cycles.samples=48
 scene.cycles.use_denoising=False;scene.render.resolution_x=256;scene.render.resolution_y=256;scene.render.resolution_percentage=100
 scene.world.color=(.23,.26,.22)
 scene.view_settings.view_transform='AgX'
 scene.render.film_transparent=True;scene.render.image_settings.file_format="PNG";scene.render.image_settings.color_mode="RGBA"
 for loc,energy,size,color in [((3,4,8),1500,5,(1,.88,.70)),((-4,1,4),800,5,(.72,.85,1)),((2,-5,6),1000,4,(.92,1,.87))]:
  bpy.ops.object.light_add(type='AREA',location=loc);o=bpy.context.object;o.data.energy=energy;o.data.shape='DISK';o.data.size=size;o.data.color=color;o.rotation_euler=(Vector((0,0,1))-o.location).to_track_quat('-Z','Y').to_euler()
 bpy.ops.object.camera_add(location=(6.5,9,7.2));cam=bpy.context.object;target=Vector((0,0,1.1 if name!='garden' else .35));cam.rotation_euler=(target-cam.location).to_track_quat('-Z','Y').to_euler();cam.data.type='ORTHO';cam.data.ortho_scale={'house':4.9,'depot':5.3,'barracks':6.7,'vehicle_workshop':7.2,'garden':5.7}[name];scene.camera=cam
 scene.render.filepath=str(P/'icons'/f'portrait_{name}.png');bpy.ops.render.render(write_still=True)
 print('RENDERED',name,flush=True)
