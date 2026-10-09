"""Build an original ruined-civilian runner and shared, articulated baked poses.

Reuses only the project's owned atlas and the corner-ID export convention.
All runner geometry, proportions, rig and motion are authored here. Blender
is offline only; runtime has no bones, skin, physics, or per-actor materials.
"""
import hashlib
import json
import math
import sys
import time
from pathlib import Path

import bpy
from mathutils import Matrix, Vector

ROOT = Path(__file__).resolve().parent.parent
SOURCE, ASSETS = ROOT/'source', ROOT/'assets'
RUNTIME_MODELS = ROOT.parents[1]/'assets/models'
sys.path.insert(0,str(SOURCE))
from runner_gait import RunnerGait, STRIDE, STANCE
CLIPS={'idle':(1.6,2),'run':(STRIDE/2.7,12),'attack':(.8,6),'death':(1.2,8)}
PARTS=[]


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def finish(obj,name,tile,bone):
    obj.name=name
    bpy.context.view_layer.objects.active=obj
    bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    obj.data.materials.append(MATERIAL)
    uv=obj.data.uv_layers.active or obj.data.uv_layers.new(name='UVMap')
    for poly in obj.data.polygons:
        axis=max(range(3),key=lambda i:abs(poly.normal[i]))
        axes=[i for i in range(3) if i!=axis]
        values=[obj.data.vertices[obj.data.loops[j].vertex_index].co for j in poly.loop_indices]
        lo=[min(v[k] for v in values) for k in axes]
        hi=[max(v[k] for v in values) for k in axes]
        for j,v in zip(poly.loop_indices,values):
            q=[(v[k]-a)/max(b-a,.0001) for k,a,b in zip(axes,lo,hi)]
            uv.data[j].uv=((tile%4+.06+q[0]*.88)/4,(3-tile//4+.06+q[1]*.88)/4)
    group=obj.vertex_groups.new(name=bone)
    group.add(list(range(len(obj.data.vertices))),1,'REPLACE')
    PARTS.append(obj)
    return obj


def ell(name,loc,scale,tile,bone,segments=8,rings=4):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=segments,ring_count=rings,radius=1,location=loc)
    obj=bpy.context.object
    obj.scale=scale
    return finish(obj,name,tile,bone)


def taper(name,a,b,r1,r2,tile,bone,vertices=7):
    a,b=Vector(a),Vector(b)
    bpy.ops.mesh.primitive_cone_add(vertices=vertices,radius1=r1,radius2=r2,depth=(b-a).length,location=(a+b)/2)
    obj=bpy.context.object
    obj.rotation_euler=(b-a).to_track_quat('Z','Y').to_euler()
    return finish(obj,name,tile,bone)


def poly(name,verts,faces,tile,bone):
    data=bpy.data.meshes.new(name)
    data.from_pydata(verts,[],faces)
    data.update()
    obj=bpy.data.objects.new(name,data)
    bpy.context.collection.objects.link(obj)
    return finish(obj,name,tile,bone)


def rag(name,points,tile,bone,thickness=.016):
    points=[Vector(v) for v in points]
    verts=[tuple(v+Vector((0,dy,0))) for dy in [-thickness/2,thickness/2] for v in points]
    n=len(points)
    faces=[tuple(reversed(range(n))),tuple(range(n,n*2))]
    faces += [(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)]
    return poly(name,verts,faces,tile,bone)


def triangulate(obj):
    bpy.context.view_layer.objects.active=obj
    tri=obj.modifiers.new('Fixed rest triangles','TRIANGULATE')
    while obj.modifiers.find(tri.name)>0:bpy.ops.object.modifier_move_up(modifier=tri.name)
    bpy.ops.object.modifier_apply(modifier=tri.name)
    obj.data.validate(verbose=False)


def topology(data):
    return hashlib.sha256(json.dumps([data.loops[i].vertex_index for p in data.polygons for i in p.loop_indices]).encode()).hexdigest()


def corners(obj):
    ids=obj.data.uv_layers.new(name='CornerID')
    count=len(obj.data.loops)
    side=math.ceil(math.sqrt(count))
    for i in range(count):ids.data[i].uv=((i%side+.5)/side,1-(i//side+.5)/side)
    obj.data.uv_layers.active_index=0
    obj.data.uv_layers[0].active_render=True
    return count,side


def build_model():
    global MATERIAL
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.object.delete(use_global=False)
    MATERIAL=bpy.data.materials.new('Runner_Ruined_Civilian_Atlas')
    MATERIAL.use_nodes=True
    bs=MATERIAL.node_tree.nodes.get('Principled BSDF')
    bs.inputs['Roughness'].default_value=.91
    # Establish a relative image base before loading. Starting with an absolute
    # path can leave its old bytes inside Blender's fixed-size path buffers.
    bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE/'runner_original_rig.blend'))
    texture=MATERIAL.node_tree.nodes.new('ShaderNodeTexImage')
    texture.image=bpy.data.images.load('//../assets/runner_atlas.png')
    MATERIAL.node_tree.links.new(texture.outputs['Color'],bs.inputs['Base Color'])
    # Civilian work jacket collapses across the back; missing right front and
    # one sleeve expose a narrow ribcage. The shape is not the normal mesh.
    ell('Narrow exposed ribcage',(0,-.015,1.13),(.155,.113,.245),1,'spine')
    ell('Bunched jacket across back',(-.025,.048,1.21),(.224,.105,.212),10,'spine')
    ell('Raised left jacket shoulder',(.22,-.055,1.285),(.108,.12,.125),10,'chest')
    ell('Exposed sharp right shoulder',(-.223,-.065,1.28),(.071,.087,.092),0,'chest')
    rag('Long torn left front jacket',[(.035,-.132,1.30),(.208,-.114,1.28),(.186,-.122,.985),(.105,-.146,.90),(.07,-.138,1.08)],10,'spine')
    rag('Split right jacket edge',[(-.17,.095,1.27),(-.222,.015,1.17),(-.22,-.01,.975),(-.15,.035,1.035)],10,'spine')
    rag('Unequal rear jacket tail',[(-.17,.14,1.04),(.17,.14,1.04),(.14,.157,.925),(.05,.16,.955),(-.03,.175,.835),(-.15,.145,.91)],10,'spine')
    # Bold openings and rags hold up at 20-35 px actor height.
    for z in [1.12,1.19,1.26]:
        taper('Visible angular rib',(-.13,-.098,z),(.03,-.125,z+.012),.017,.020,2,'spine',5)
    ell('Trousers pelvis',(0,.005,.89),(.179,.123,.14),8,'hips')
    taper('Neck tendon',(0,-.13,1.43),(0,-.20,1.52),.056,.066,0,'neck',7)
    ell('Long gaunt skull',(0,-.235,1.578),(.112,.113,.137),0,'head',10,5)
    ell('Dark uneven close hair',(0,-.209,1.671),(.114,.095,.060),5,'head')
    ell('Projected brow',(.0,-.333,1.61),(.107,.028,.033),1,'head')
    ell('Hanging angular jaw',(.014,-.279,1.468),(.079,.071,.047),2,'head')
    ell('Open mouth',(0,-.34,1.499),(.061,.016,.035),5,'head',8,3)
    for x in [-.047,.047]:
        ell('Deep eye socket',(x,-.328,1.577),(.032,.021,.027),5,'head',6,3)
    taper('Nose',(.005,-.327,1.598),(.005,-.365,1.54),.015,.023,1,'head',5)
    ell('Cheek tear',(-.071,-.303,1.527),(.032,.027,.046),6,'head',6,3)
    bones={
      'root':((0,0,0),(0,0,.2),None),
      'hips':((0,0,.90),(0,0,1.02),'root'),
      'spine':((0,0,1.02),(0,-.06,1.28),'hips'),
      'chest':((0,-.06,1.28),(0,-.13,1.43),'spine'),
      'neck':((0,-.13,1.43),(0,-.20,1.52),'chest'),
      'head':((0,-.20,1.52),(0,-.20,1.70),'neck')}
    for side,sign in [('L',1),('R',-1)]:
        shoulder=(sign*.235,-.06,1.29)
        elbow=(sign*.32,-.06,1.025)
        wrist=(sign*.345,-.12,.78)
        fingers=(sign*.35,-.165,.655)
        hip=(sign*.115,0,.875)
        knee=(sign*.128,-.02,.49)
        ankle=(sign*.135,.018,.105)
        bones.update({f'upper_arm.{side}':(shoulder,elbow,'chest'),f'forearm.{side}':(elbow,wrist,f'upper_arm.{side}'),f'hand.{side}':(wrist,fingers,f'forearm.{side}'),f'thigh.{side}':(hip,knee,'hips'),f'shin.{side}':(knee,ankle,f'thigh.{side}'),f'foot.{side}':(ankle,(sign*.135,-.16,.055),f'shin.{side}')})
        if side=='L':
            taper('Left hanging sleeve',shoulder,elbow,.094,.077,10,'upper_arm.L')
            rag('Sleeve torn tab',[(.335,-.075,1.07),(.385,-.07,1.035),(.385,-.081,.94),(.35,-.079,.99)],10,'upper_arm.L')
        else:
            taper('Bare upper right arm',shoulder,elbow,.063,.048,0,'upper_arm.R')
        ell('Angular elbow '+side,elbow,(.052,.059,.058),1,'forearm.'+side,6,3)
        taper('Sinewed forearm '+side,elbow,wrist,.055,.035,0,'forearm.'+side)
        ell('Long claw palm '+side,wrist,(.051,.035,.083),0,'hand.'+side,6,3)
        for k in range(3):
            x=sign*.345+(k-1)*.029
            taper('Claw finger '+side,(x,-.14,.746),(x,-.182,.648+(k%2)*.017),.012,.008,1,'hand.'+side,5)
        taper('Splayed thumb '+side,(sign*.309,-.14,.77),(sign*.278,-.175,.703),.014,.008,0,'hand.'+side,5)
        taper('Torn trouser thigh '+side,hip,knee,.110,.076,8,'thigh.'+side)
        ell('Exposed knee '+side,knee,(.078,.075,.068),0,'shin.'+side,7,3)
        # Left trouser is torn above its calf; the right has a long dark cuff.
        if side=='L':
            taper('Bare left shin',knee,ankle,.052,.037,1,'shin.L')
            rag('Left knee trouser flap',[(.078,-.091,.56),(.183,-.093,.55),(.171,-.099,.445),(.108,-.095,.49)],8,'thigh.L')
        else:
            taper('Right lower trouser',knee,ankle,.075,.052,8,'shin.R')
        ell('Battered sneaker '+side,(sign*.135,-.061,.060),(.075,.154,.061),5,'foot.'+side,8,4)
        taper('Worn shoe toe edge '+side,(sign*.135-.056,-.172,.054),(sign*.135+.056,-.172,.054),.015,.015,13,'foot.'+side,5)
    bpy.ops.object.select_all(action='DESELECT')
    for obj in PARTS:obj.select_set(True)
    bpy.context.view_layer.objects.active=PARTS[0]
    bpy.ops.object.join()
    mesh=bpy.context.object
    mesh.name='Runner_Original_Civilian_Skinned'
    bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
    triangulate(mesh)
    data=bpy.data.armatures.new('Runner_Original_Rig')
    rig=bpy.data.objects.new('Runner_Original_Rig',data)
    bpy.context.collection.objects.link(rig)
    mesh.select_set(False)
    rig.select_set(True)
    bpy.context.view_layer.objects.active=rig
    bpy.ops.object.mode_set(mode='EDIT')
    for name,(a,b,parent) in bones.items():
        bone=data.edit_bones.new(name)
        bone.head,bone.tail=a,b
        if parent:bone.parent=data.edit_bones[parent]
    bpy.ops.object.mode_set(mode='OBJECT')
    modifier=mesh.modifiers.new('Offline runner articulation','ARMATURE')
    modifier.object=rig
    mesh.parent=rig
    rig.rotation_euler.z=math.pi
    for bone in rig.pose.bones:bone.rotation_mode='XYZ'
    return rig,mesh


def main():
    started=time.monotonic()
    rig,near=build_model()
    far=near.copy()
    far.data=near.data.copy()
    far.name='Runner_Far_Rest'
    bpy.context.collection.objects.link(far)
    for modifier in list(far.modifiers):far.modifiers.remove(modifier)
    bpy.context.view_layer.objects.active=far
    decimate=far.modifiers.new('Single rest-pose distant simplification','DECIMATE')
    decimate.ratio=.25
    decimate.use_collapse_triangulate=True
    bpy.ops.object.modifier_apply(modifier=decimate.name)
    triangulate(far)
    modifier=far.modifiers.new('Offline original rig','ARMATURE')
    modifier.object=rig
    gait=RunnerGait(rig,near)
    manifest={'status':'isolated_original_runner_candidate','generator':'source/build_runner_poses.py',
      'model':'Original ruined-civilian runner; owned project atlas reused',
      'runtime_bones':0,'editable_bones':len(rig.data.bones),'pose_count':sum(v[1] for v in CLIPS.values()),
      'forward':'Godot -Z','units':'meters','source_atlas':'../infected_reconstruction/assets/infected_atlas.png',
      'atlas_sha256':digest(ASSETS/'runner_atlas.png'),'blender_version':bpy.app.version_string,
      'run_stride_m':STRIDE,'run_speed_mps_unchanged':2.7,'stance_fraction':STANCE,
      'clips':{k:{'duration':d,'loop':k in ['idle','run'],'poses':[f'{k}_{i:02}' for i in range(c)]} for k,(d,c) in CLIPS.items()},'lods':{}}
    for label,obj in [('near',near),('far',far)]:
        count,side=corners(obj)
        manifest['lods'][label]={'triangles_per_pose':len(obj.data.polygons),'expected_imported_vertices_per_pose':count,
                               'uv2_grid_side':side,'topology_sha256':topology(obj.data)}
    gait.pose(.0,'run')
    far.hide_render=True
    far.hide_set(True)
    for image in bpy.data.images:
        if image.name.startswith('runner_atlas'):image.filepath='//../assets/runner_atlas.png'
    bpy.ops.file.pack_all()
    for image in bpy.data.images:
        for packed in image.packed_files:
            # Clear unused fixed-size path-buffer bytes before a shorter path.
            packed.filepath = " " * 1023
            packed.filepath = "//../assets/runner_atlas.png"
    # Editable rig and mesh are retained; generator carries the exact clip source.
    bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE/'runner_original_rig.blend'))
    far.hide_render=False
    far.hide_set(False)
    for label,obj in [('near',near),('far',far)]:
        baked=[]
        samples=[]
        for clip,(duration,count) in CLIPS.items():
            for frame in range(count):
                phase=(frame/count if clip in ['idle','run'] else frame/(count-1))
                gait.pose(phase,clip)
                deps=bpy.context.evaluated_depsgraph_get()
                data=bpy.data.meshes.new_from_object(obj.evaluated_get(deps),preserve_all_data_layers=True,depsgraph=deps)
                assert topology(data)==manifest['lods'][label]['topology_sha256']
                data.transform(obj.matrix_world)
                low=min(v.co.z for v in data.vertices)
                # Preserve the brief flight: never pull raised shoes to ground.
                correction=max(0.0,-low)
                data.transform(Matrix.Translation((0,0,correction)))
                assert not data.validate(verbose=True)
                name=f'{clip}_{frame:02}'
                pose=bpy.data.objects.new(name,data)
                bpy.context.collection.objects.link(pose)
                assert pose.name==name
                baked.append(pose)
                samples.append({'name':name,'min_height_m':min(v.co.z for v in data.vertices),
                                'max_height_m':max(v.co.z for v in data.vertices),'floor_correction_m':correction})
        bpy.ops.object.select_all(action='DESELECT')
        for pose in baked:pose.select_set(True)
        bpy.context.view_layer.objects.active=baked[0]
        filename='runner_baked_poses'+('_far' if label=='far' else '')+'.glb'
        bpy.ops.export_scene.gltf(filepath=str(RUNTIME_MODELS/filename),export_format='GLB',use_selection=True,
          export_animations=False,export_skins=False,export_morph=False,export_texcoords=True,
          export_normals=True,export_tangents=False,export_yup=True,export_materials='EXPORT',
          export_image_format='AUTO',export_draco_mesh_compression_enable=False,
          export_cameras=False,export_lights=False,export_extras=False)
        manifest['lods'][label].update(file='../../assets/models/'+filename,bytes=(RUNTIME_MODELS/filename).stat().st_size,
                                     sha256=digest(RUNTIME_MODELS/filename),samples=samples)
        for pose in baked:
            data=pose.data
            bpy.data.objects.remove(pose,do_unlink=True)
            bpy.data.meshes.remove(data)
    manifest['generator_sha256']=digest(Path(__file__))
    manifest['motion_sha256']=digest(SOURCE/'runner_gait.py')
    manifest['editable_rig_sha256']=digest(SOURCE/'runner_original_rig.blend')
    manifest['elapsed_seconds']=round(time.monotonic()-started,3)
    (ROOT/'runner_manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
    (ROOT/'validation/authoring_diagnostics.json').write_text(json.dumps(gait.diagnostics,indent=2)+'\n')
    print('RUNNER_BUILD_OK',json.dumps({k:{i:v[i] for i in ['triangles_per_pose','bytes']} for k,v in manifest['lods'].items()}))


if __name__=='__main__':main()
