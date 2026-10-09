"""Build original RECLAMATION armored infected in an isolated art package.

Owned atlas and stable UV2 corner-ID export conventions are reused. Geometry,
industrial-worker silhouette and weighted motion are original. Blender is an
offline authoring dependency: runtime has shared pose meshes and zero bones.
"""
import hashlib
import json
import math
import sys
import time
from pathlib import Path
import bpy
from mathutils import Matrix, Vector

ROOT=Path(__file__).resolve().parent.parent
SOURCE,ASSETS,VALIDATION=ROOT/'source',ROOT/'assets',ROOT/'validation'
sys.path.insert(0,str(SOURCE))
from heavy_gait import HeavyGait, STRIDE, SPEED, STANCE
CLIPS={'idle':(1.8,2),'walk':(STRIDE/SPEED,12),'attack':(.9,8),'death':(1.2,10)}
PARTS=[]


def digest(path):return hashlib.sha256(path.read_bytes()).hexdigest()


def finish(obj,name,tile,bone):
    obj.name=name
    bpy.context.view_layer.objects.active=obj
    bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    obj.data.materials.append(MATERIAL)
    uv=obj.data.uv_layers.active or obj.data.uv_layers.new(name='UVMap')
    for polygon in obj.data.polygons:
        axis=max(range(3),key=lambda i:abs(polygon.normal[i]))
        axes=[i for i in range(3) if i!=axis]
        values=[obj.data.vertices[obj.data.loops[j].vertex_index].co for j in polygon.loop_indices]
        lo=[min(v[k] for v in values) for k in axes]
        hi=[max(v[k] for v in values) for k in axes]
        for j,v in zip(polygon.loop_indices,values):
            q=[(v[k]-a)/max(b-a,.0001) for k,a,b in zip(axes,lo,hi)]
            uv.data[j].uv=((tile%4+.06+q[0]*.88)/4,(3-tile//4+.06+q[1]*.88)/4)
    group=obj.vertex_groups.new(name=bone)
    group.add(list(range(len(obj.data.vertices))),1,'REPLACE')
    PARTS.append(obj)
    return obj


def ell(name,loc,scale,tile,bone,segments=7,rings=3):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=segments,ring_count=rings,radius=1,location=loc)
    obj=bpy.context.object
    obj.scale=scale
    return finish(obj,name,tile,bone)


def taper(name,a,b,r1,r2,tile,bone,vertices=6):
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


def panel(name,points,tile,bone,depth=.024):
    verts=[(x,y+dy,z) for dy in [-depth/2,depth/2] for x,y,z in points]
    n=len(points)
    faces=[tuple(reversed(range(n))),tuple(range(n,n*2))]
    faces += [(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)]
    return poly(name,verts,faces,tile,bone)


def loft(name,rings,tile,bone,segments=8):
    verts=[]
    for z,cx,cy,rx,ry in rings:
        verts.extend((cx+rx*math.cos(i*math.tau/segments),cy+ry*math.sin(i*math.tau/segments),z) for i in range(segments))
    faces=[tuple(reversed(range(segments))),tuple(range((len(rings)-1)*segments,len(rings)*segments))]
    for j in range(len(rings)-1):
        faces += [(j*segments+i,j*segments+(i+1)%segments,(j+1)*segments+(i+1)%segments,(j+1)*segments+i) for i in range(segments)]
    return poly(name,verts,faces,tile,bone)


def triangulate(obj):
    bpy.context.view_layer.objects.active=obj
    modifier=obj.modifiers.new('Fixed rest triangles','TRIANGULATE')
    while obj.modifiers.find(modifier.name)>0:bpy.ops.object.modifier_move_up(modifier=modifier.name)
    bpy.ops.object.modifier_apply(modifier=modifier.name)
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
    MATERIAL=bpy.data.materials.new('Armored_Industrial_Worker_Owned_Atlas')
    MATERIAL.use_nodes=True
    bs=MATERIAL.node_tree.nodes.get('Principled BSDF')
    bs.inputs['Roughness'].default_value=.93
    texture=MATERIAL.node_tree.nodes.new('ShaderNodeTexImage')
    texture.image=bpy.data.images.load(str(ASSETS/'heavy_atlas.png'))
    texture.image.pack()
    texture.image.filepath='//../assets/heavy_atlas.png'
    MATERIAL.node_tree.links.new(texture.outputs['Color'],bs.inputs['Base Color'])
    # Burdened trapezoid worker vest: long apron and broad sloped shoulders, with
    # a shallow warm bib against cold dark overalls. No matched armor suit.
    loft('Broad creased worker torso',[(.93,0,.025,.205,.145),(1.14,0,.025,.265,.17),(1.31,-.012,.015,.294,.162),(1.39,-.02,.012,.215,.135)],7,'spine')
    ell('Heavy overalls pelvis',(0,.025,.90),(.225,.15,.145),8,'hips',8,3)
    panel('Upper patched protective bib',[(-.19,-.158,1.32),(.18,-.16,1.35),(.245,-.15,1.20),(.17,-.178,1.035),(-.20,-.16,1.08)],9,'spine',.028)
    panel('Left uneven apron skirt',[(.005,-.171,1.10),(.207,-.150,1.12),(.225,-.138,.75),(.157,-.160,.66),(.030,-.174,.76)],4,'hips')
    panel('Right torn apron skirt',[(-.213,-.148,1.10),(-.012,-.174,1.10),(-.026,-.175,.81),(-.095,-.155,.72),(-.202,-.13,.84)],9,'hips')
    panel('Large diagonal repair patch',[(-.177,-.182,1.23),(-.039,-.192,1.20),(-.005,-.19,1.045),(-.15,-.185,1.07)],10,'spine',.012)
    panel('Pale worn upper bib lip',[(-.19,-.178,1.31),(.177,-.18,1.34),(.17,-.182,1.30),(-.19,-.178,1.27)],13,'spine',.012)
    # One curved sheet-metal shoulder: a single unequal silhouette accent.
    loft('Bent left salvage shoulder',[(1.23,.283,.005,.105,.16),(1.37,.292,.015,.16,.16),(1.43,.26,.015,.105,.12)],9,'chest',7)
    panel('Dark shoulder strap',[(.16,-.117,1.40),(.224,-.12,1.38),(.19,-.180,1.08),(.135,-.180,1.10)],5,'spine',.018)
    ell('Torn bare right shoulder',(-.286,-.01,1.32),(.089,.094,.116),0,'chest',7,3)
    taper('Exposed neck',(0,-.07,1.40),(0,-.135,1.48),.066,.062,1,'neck',6)
    ell('Blunt infected skull',(0,-.15,1.57),(.119,.113,.137),0,'head',8,4)
    ell('Matted short scalp',(-.018,-.12,1.662),(.12,.101,.053),5,'head',7,3)
    ell('Heavy dead brow',(0,-.245,1.60),(.11,.034,.041),1,'head',7,3)
    ell('Exposed pale dragging jaw',(.014,-.217,1.462),(.085,.075,.052),2,'head',7,3)
    ell('Open black mouth',(.008,-.276,1.50),(.068,.015,.035),5,'head',6,3)
    for x in [-.048,.048]:ell('Hollow eye socket',(x,-.254,1.575),(.029,.023,.025),5,'head',5,3)
    ell('Jaw infected tear',(-.073,-.228,1.499),(.029,.035,.052),6,'head',5,3)
    bones={'root':((0,0,0),(0,0,.2),None),'hips':((0,0,.90),(0,0,1.02),'root'),
      'spine':((0,0,1.02),(0,-.02,1.29),'hips'),'chest':((0,-.02,1.29),(0,-.08,1.43),'spine'),
      'neck':((0,-.08,1.43),(0,-.135,1.49),'chest'),'head':((0,-.135,1.49),(0,-.15,1.66),'neck')}
    for side,sign in [('L',1),('R',-1)]:
        shoulder=(sign*.296,-.01,1.32)
        elbow=(sign*.365,-.035,1.045)
        wrist=(sign*.385,-.105,.800)
        hip=(sign*.145,.01,.895)
        knee=(sign*.168,-.02,.50)
        ankle=(sign*.17,.018,.10)
        bones.update({f'upper_arm.{side}':(shoulder,elbow,'chest'),f'forearm.{side}':(elbow,wrist,f'upper_arm.{side}'),
          f'hand.{side}':(wrist,(sign*.385,-.15,.665),f'forearm.{side}'),f'thigh.{side}':(hip,knee,'hips'),
          f'shin.{side}':(knee,ankle,f'thigh.{side}'),f'foot.{side}':(ankle,(sign*.17,-.17,.055),f'shin.{side}')})
        taper('Heavy sleeve '+side,shoulder,elbow,.107 if side=='L' else .085,.078,7 if side=='L' else 0,'upper_arm.'+side,7)
        ell('Articulated exposed elbow '+side,elbow,(.071,.065,.062),1,'forearm.'+side,6,3)
        taper('Bared thick forearm '+side,elbow,wrist,.073,.047,0,'forearm.'+side,7)
        ell('Large infected palm '+side,(sign*.385,-.115,.761),(.065,.042,.084),0,'hand.'+side,6,3)
        for finger in range(3):
            x=sign*.385+(finger-1)*.037
            taper('Hooked finger '+side,(x,-.125,.744),(x,-.194,.658+(finger%2)*.012),.015,.010,1,'hand.'+side,5)
        taper('Splayed thumb '+side,(sign*.339,-.13,.774),(sign*.302,-.18,.703),.019,.011,0,'hand.'+side,5)
        taper('Bulky overall thigh '+side,hip,knee,.133,.096,8,'thigh.'+side,7)
        ell('Knee joint '+side,knee,(.094,.088,.083),1 if side=='R' else 8,'shin.'+side,6,3)
        taper('Work trouser calf '+side,knee,ankle,.094,.067,8,'shin.'+side,7)
        # Only one wrapped knee, retaining uneven civilian protection.
        if side=='L':
            panel('Salvaged left knee pad',[(.086,-.094,.555),(.25,-.094,.55),(.244,-.106,.41),(.095,-.103,.40)],4,'shin.L',.024)
        ell('Flat heavy work boot '+side,(sign*.17,-.067,.059),(.099,.173,.061),5,'foot.'+side,8,3)
        taper('Scuffed boot toe '+side,(sign*.17-.078,-.19,.052),(sign*.17+.078,-.19,.052),.017,.017,12,'foot.'+side,5)
    bpy.ops.object.select_all(action='DESELECT')
    for obj in PARTS:obj.select_set(True)
    bpy.context.view_layer.objects.active=PARTS[0]
    bpy.ops.object.join()
    mesh=bpy.context.object
    mesh.name='Armored_Original_Industrial_Worker'
    bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
    triangulate(mesh)
    data=bpy.data.armatures.new('Armored_Offline_Articulation')
    rig=bpy.data.objects.new('Armored_Offline_Articulation',data)
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
    modifier=mesh.modifiers.new('Offline weighted worker articulation','ARMATURE')
    modifier.object=rig
    mesh.parent=rig
    rig.rotation_euler.z=math.pi
    for bone in rig.pose.bones:bone.rotation_mode='XYZ'
    return rig,mesh


def main():
    started=time.monotonic()
    for directory in (SOURCE,ASSETS,VALIDATION):directory.mkdir(parents=True,exist_ok=True)
    rig,near=build_model()
    assert len(near.data.polygons)<=1500,len(near.data.polygons)
    far=near.copy()
    far.data=near.data.copy()
    far.name='Armored_Far_Rest'
    bpy.context.collection.objects.link(far)
    for modifier in list(far.modifiers):far.modifiers.remove(modifier)
    bpy.context.view_layer.objects.active=far
    decimate=far.modifiers.new('Single rest topology far silhouette','DECIMATE')
    decimate.ratio=380/len(near.data.polygons)
    decimate.use_collapse_triangulate=True
    bpy.ops.object.modifier_apply(modifier=decimate.name)
    triangulate(far)
    assert len(far.data.polygons)<=400,len(far.data.polygons)
    modifier=far.modifiers.new('Offline original rig','ARMATURE')
    modifier.object=rig
    gait=HeavyGait(rig,near)
    manifest={'status':'isolated_original_armored_candidate','generator':'source/build_heavy_poses.py',
      'model':'Original quarantined industrial worker; ordinary armored only, boss excluded',
      'runtime_bones':0,'editable_bones':len(rig.data.bones),'pose_count':sum(v[1] for v in CLIPS.values()),
      'forward':'Godot -Z','units':'meters','atlas_source':'Owned infected_reconstruction/assets/infected_atlas.png',
      'atlas_sha256':digest(ASSETS/'heavy_atlas.png'),'blender_version':bpy.app.version_string,
      'walk_stride_m':STRIDE,'walk_speed_mps_unchanged':SPEED,'stance_fraction':STANCE,
      'runtime_contract':'Measured displacement / stride; shared UV2-paired pose shader; one surface; no runtime Skeleton3D',
      'contact_contract':'attack_00 is contact; 0.9 s cooldown and immediate damage unchanged',
      'death_contract':'No planar root motion; single baked topple, supplied with CorpseMotion baked_world',
      'clips':{k:{'duration':d,'loop':k in ('idle','walk'),'poses':[f'{k}_{i:02}' for i in range(c)]} for k,(d,c) in CLIPS.items()},'lods':{}}
    for label,obj in [('near',near),('far',far)]:
        count,side=corners(obj)
        manifest['lods'][label]={'triangles_per_pose':len(obj.data.polygons),'expected_imported_vertices_per_pose':count,
          'uv2_grid_side':side,'topology_sha256':topology(obj.data)}
    # Source is the complete, public-safe generator. Do not save private Blender
    # screen/UI/workspace state; regenerating it needs only this package.
    for label,obj in [('near',near),('far',far)]:
        baked=[]
        samples=[]
        for clip,(duration,count) in CLIPS.items():
            for frame in range(count):
                phase=frame/count if clip in ('idle','walk') else frame/(count-1)
                if clip=='idle':phase+=.25
                gait.pose(phase,clip)
                deps=bpy.context.evaluated_depsgraph_get()
                data=bpy.data.meshes.new_from_object(obj.evaluated_get(deps),preserve_all_data_layers=True,depsgraph=deps)
                assert topology(data)==manifest['lods'][label]['topology_sha256']
                data.transform(obj.matrix_world)
                low=min(v.co.z for v in data.vertices)
                correction=max(0.,-low)
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
        filename='armored_baked_poses'+('_far' if label=='far' else '')+'.glb'
        bpy.ops.export_scene.gltf(filepath=str(ASSETS/filename),export_format='GLB',use_selection=True,
          export_animations=False,export_skins=False,export_morph=False,export_texcoords=True,
          export_normals=True,export_tangents=False,export_yup=True,export_materials='EXPORT',
          export_image_format='AUTO',export_draco_mesh_compression_enable=False,
          export_cameras=False,export_lights=False,export_extras=False)
        manifest['lods'][label].update(file='assets/'+filename,bytes=(ASSETS/filename).stat().st_size,
          sha256=digest(ASSETS/filename),samples=samples)
        for pose in baked:
            data=pose.data
            bpy.data.objects.remove(pose,do_unlink=True)
            bpy.data.meshes.remove(data)
    manifest['generator_sha256']=digest(Path(__file__))
    manifest['motion_sha256']=digest(SOURCE/'heavy_gait.py')
    manifest['elapsed_seconds']=round(time.monotonic()-started,3)
    (ROOT/'armored_manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
    (VALIDATION/'authoring_diagnostics.json').write_text(json.dumps(gait.diagnostics,indent=2)+'\n')
    print('ARMORED_BUILD_OK',json.dumps({k:{i:v[i] for i in ('triangles_per_pose','bytes')} for k,v in manifest['lods'].items()}))

if __name__=='__main__':main()
