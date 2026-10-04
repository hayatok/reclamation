import bpy, math
from mathutils import Vector,Matrix
from pathlib import Path
P=str(Path(__file__).resolve().parent.parent)
bpy.ops.wm.open_mainfile(filepath=P+'/source/infected_civilian.blend')
rig=bpy.data.objects.get('Infected_Rig');skin=bpy.data.objects.get('Infected_Civilian_Skinned')
for t in rig.animation_data.nla_tracks:t.mute=True
for i,(clip,frame) in enumerate([('idle',12),('walk',9),('attack',12),('death',36)]):
 rig.animation_data.action=bpy.data.actions[clip];bpy.context.scene.frame_set(frame);deps=bpy.context.evaluated_depsgraph_get();ev=skin.evaluated_get(deps);me=bpy.data.meshes.new_from_object(ev,depsgraph=deps);me.transform(skin.matrix_world);lowest=min(v.co.z for v in me.vertices);me.transform(Matrix.Translation(((i-1.5)*1.25,0,max(0,-lowest))))
 o=bpy.data.objects.new(clip,me);bpy.context.collection.objects.link(o)
rig.hide_render=True;skin.hide_render=True
s=bpy.context.scene;s.render.engine='CYCLES';s.cycles.samples=24;s.cycles.use_denoising=False;s.render.resolution_x=1400;s.render.resolution_y=800;s.render.resolution_percentage=100;s.world.color=(.25,.27,.25)
bpy.ops.mesh.primitive_plane_add(size=200);o=bpy.context.object;o.location.z=-.02;m=bpy.data.materials.new('Ground');m.diffuse_color=(.13,.145,.13,1);o.data.materials.append(m)
for loc,power,size,color in [((1,3,9),1900,7,(1,.83,.63)),((-7,-3,5),1100,8,(.65,.79,1))]:
 bpy.ops.object.light_add(type='AREA',location=loc);l=bpy.context.object;l.data.energy=power;l.data.shape='DISK';l.data.size=size;l.data.color=color;l.rotation_euler=(Vector((0,0,1))-l.location).to_track_quat('-Z','Y').to_euler()
bpy.ops.object.camera_add(location=(2,7,3.2));c=bpy.context.object;c.rotation_euler=(Vector((0,0,.65))-c.location).to_track_quat('-Z','Y').to_euler();c.data.type='ORTHO';c.data.ortho_scale=6.2;s.camera=c;s.render.filepath=P+'/previews/infected_pose_sheet_blender.png';bpy.ops.render.render(write_still=True)
