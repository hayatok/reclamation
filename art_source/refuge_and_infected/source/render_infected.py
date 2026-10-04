import bpy, math
from mathutils import Vector
from pathlib import Path
P=str(Path(__file__).resolve().parent.parent)
bpy.ops.wm.open_mainfile(filepath=P+'/source/infected_civilian.blend')
s=bpy.context.scene;s.render.engine='CYCLES';s.cycles.samples=24;s.cycles.use_denoising=False
s.render.resolution_x=1000;s.render.resolution_y=800;s.render.resolution_percentage=100
s.world.color=(.25,.27,.25)
bpy.ops.mesh.primitive_plane_add(size=200);o=bpy.context.object;o.location.z=-.02
m=bpy.data.materials.new('Ground');m.diffuse_color=(.13,.145,.13,1);o.data.materials.append(m)
for loc,power,size,color in [((1,3,9),1900,7,(1,.83,.63)),((-7,-3,5),1100,8,(.65,.79,1))]:
 bpy.ops.object.light_add(type='AREA',location=loc);l=bpy.context.object;l.data.energy=power;l.data.shape='DISK';l.data.size=size;l.data.color=color;l.rotation_euler=(Vector((0,0,1))-l.location).to_track_quat('-Z','Y').to_euler()
bpy.ops.object.camera_add(location=(2.4,4,2.3));c=bpy.context.object;c.rotation_euler=(Vector((0,0,.83))-c.location).to_track_quat('-Z','Y').to_euler();c.data.type='ORTHO';c.data.ortho_scale=2.35;s.camera=c
s.render.filepath=P+'/previews/infected_blender.png';bpy.ops.render.render(write_still=True)
