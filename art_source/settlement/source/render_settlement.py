import bpy,math
from pathlib import Path
from mathutils import Vector
P=Path(__file__).resolve().parent.parent
for name in ['house','depot','barracks','vehicle_workshop','garden']:
 bpy.ops.wm.open_mainfile(filepath=str(P/'source'/f'{name}.blend'))
 scene=bpy.context.scene;scene.render.engine='CYCLES';scene.cycles.samples=64
 scene.cycles.use_denoising=False;scene.render.resolution_x=1100;scene.render.resolution_y=900;scene.render.resolution_percentage=100
 scene.world.color=(.23,.26,.22)
 scene.view_settings.view_transform='AgX'
 # Matte ground beyond the bounded prefab is review scenery only.
 bpy.ops.mesh.primitive_plane_add(size=200,location=(0,0,-.014));plane=bpy.context.object;plane.name='REVIEW ONLY ground'
 m=bpy.data.materials.new('REVIEW ONLY');m.diffuse_color=(.21,.245,.19,1);m.use_nodes=True;m.node_tree.nodes.get('Principled BSDF').inputs['Base Color'].default_value=(.21,.245,.19,1);m.node_tree.nodes.get('Principled BSDF').inputs['Roughness'].default_value=.92;plane.data.materials.append(m)
 for loc,energy,size,color in [((3,4,8),1500,5,(1,.88,.70)),((-4,1,4),800,5,(.72,.85,1)),((2,-5,6),1000,4,(.92,1,.87))]:
  bpy.ops.object.light_add(type='AREA',location=loc);o=bpy.context.object;o.data.energy=energy;o.data.shape='DISK';o.data.size=size;o.data.color=color;o.rotation_euler=(Vector((0,0,1))-o.location).to_track_quat('-Z','Y').to_euler()
 bpy.ops.object.camera_add(location=(6.5,9,7.2));cam=bpy.context.object;target=Vector((0,0,1.1 if name!='garden' else .35));cam.rotation_euler=(target-cam.location).to_track_quat('-Z','Y').to_euler();cam.data.type='ORTHO';cam.data.ortho_scale={'house':4.9,'depot':5.3,'barracks':6.7,'vehicle_workshop':7.2,'garden':5.7}[name];scene.camera=cam
 scene.render.filepath=str(P/'previews'/f'{name}_blender_front.png');bpy.ops.render.render(write_still=True)
 print('RENDERED',name,flush=True)
