"""RECLAMATION: original demolition infected, editable offline mesh generator.

Run: blender --background --factory-startup --python source/build_boss_poses.py
Run source/create_boss_atlas.py with normal Python first. No source is fetched.
All pose vertices are baked in model space; runtime contains no bones. Every
triangle corner receives a stable UV2 ID. The clean Blend is inspectable source.
"""
import argparse
import hashlib
import json
import math
import sys
from pathlib import Path
import bpy
from mathutils import Matrix, Vector

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / 'generated'
REVIEW = ROOT / 'review'
CLIPS = {'idle': (1.8, 2), 'walk': (1.0, 12), 'windup': (1.4, 12),
         'recovery': (.9, 8), 'death': (1.2, 10)}
V = Vector


def mix(a, b, t):
    return a + (b - a) * t


def ease(t):
    return t * t * (3 - 2 * t)


def pose(clip, t):
    """Joint locations in Blender Z-up, -Y-forward; no root travel.

    Last windup and first recovery deliberately share one contact state. Feet
    stay planted during the entire telegraph/contact/recovery. Death loses arm
    support and is baked into a lateral prone fall, with no runtime root topple.
    """
    p = dict(pelvis=V((0, .025, .80)), chest=V((0, -.050, 1.235)),
             head=V((-.015, -.178, 1.470)), shoulder_l=V((-.355, -.015, 1.325)),
             shoulder_r=V((.385, .025, 1.360)), elbow_l=V((-.455, -.03, .990)),
             elbow_r=V((.485, .02, .995)), wrist_l=V((-.505, -.165, .650)),
             wrist_r=V((.545, -.170, .635)), knee_l=V((-.205, -.135, .445)),
             knee_r=V((.215, -.100, .465)), ankle_l=V((-.235, .035, .130)),
             ankle_r=V((.235, .070, .130)))
    rest = {k: v.copy() for k, v in p.items()}
    if clip == 'idle':
        breath = math.cos(t * math.tau)
        for k in ('chest', 'head', 'shoulder_l', 'shoulder_r'):
            p[k].z += breath * .010
            p[k].y += breath * .006
        p['wrist_r'].y += breath * .009
        p['wrist_l'].z -= breath * .005
    elif clip == 'walk':
        a = t * math.tau
        sway, bob = math.sin(a), math.cos(2 * a)
        for k in ('pelvis', 'chest', 'head', 'shoulder_l', 'shoulder_r'):
            p[k].x += sway * .026
            p[k].z += bob * .014
        for side, offset in [('l', 0.), ('r', .5)]:
            phase = (t + offset) % 1
            stride, stance = .54, .62
            half = stride * stance / 2
            if phase < stance:
                travel, lift = -half + stride * phase, 0.
            else:
                u = (phase - stance) / (1 - stance)
                travel, lift = half - 2 * half * ease(u), math.sin(math.pi * u)
            p['ankle_' + side].y += travel
            p['ankle_' + side].z += lift * .072
            p['knee_' + side].y += travel * .46 - lift * .040
            p['knee_' + side].z += lift * .024
            swing = math.sin((t + offset) * math.tau)
            p['wrist_' + side].y += swing * (.13 if side == 'l' else .10)
            p['elbow_' + side].y += swing * .067
            p['wrist_' + side].z += max(0, -swing) * .021
        p['head'].x -= sway * .017
    elif clip in ('windup', 'recovery'):
        gather = {k: v.copy() for k, v in rest.items()}
        high = {k: v.copy() for k, v in rest.items()}
        contact = {k: v.copy() for k, v in rest.items()}
        gather.update(pelvis=V((0, .045, .74)), chest=V((0, .02, 1.24)),
                      head=V((-.025, -.105, 1.465)),
                      shoulder_l=V((-.355, .03, 1.34)), shoulder_r=V((.385, .06, 1.375)),
                      elbow_l=V((-.47, .01, 1.135)), elbow_r=V((.49, .035, 1.185)),
                      wrist_l=V((-.22, -.15, 1.40)), wrist_r=V((.24, -.12, 1.45)))
        high.update(pelvis=V((0, .035, .78)), chest=V((0, .0, 1.27)),
                    head=V((-.025, -.145, 1.475)),
                    shoulder_l=V((-.355, .00, 1.36)), shoulder_r=V((.385, .025, 1.395)),
                    elbow_l=V((-.41, -.045, 1.59)), elbow_r=V((.43, -.025, 1.63)),
                    wrist_l=V((-.22, -.12, 1.83)), wrist_r=V((.22, -.09, 1.88)))
        contact.update(pelvis=V((0, .03, .66)), chest=V((0, -.24, 1.03)),
                       head=V((-.01, -.375, 1.22)),
                       shoulder_l=V((-.355, -.235, 1.115)), shoulder_r=V((.385, -.215, 1.150)),
                       elbow_l=V((-.38, -.425, .78)), elbow_r=V((.40, -.405, .77)),
                       wrist_l=V((-.27, -.585, .42)), wrist_r=V((.29, -.585, .41)),
                       knee_l=V((-.22, -.15, .40)), knee_r=V((.23, -.12, .42)))
        if clip == 'windup':
            keys = [(0., rest), (.34, gather), (.79, high), (1., contact)]
        else:
            # Let weight stay down before bringing the forearms back under the
            # shoulders. The last pose is exactly the unbreathing rest pose.
            keys = [(0., contact), (.20, contact), (1., rest)]
        for (ta, pa), (tb, pb) in zip(keys, keys[1:]):
            if ta <= t <= tb + 1e-7:
                u = ease(max(0, min(1, (t - ta) / (tb - ta))))
                p = {k: pa[k].lerp(pb[k], u) for k in rest}
                break
    elif clip == 'death':
        u = ease(t)
        # Relax the arms asymmetrically before the baked fall: the left arm
        # folds beside the head while the right drops along the flank. Neither
        # hand remains a support under the shoulders in the final corpse.
        low = dict(pelvis=V((.025, .025, .73)), chest=V((-.07, -.10, 1.12)),
                   head=V((-.115, -.235, 1.31)),
                   shoulder_l=V((-.36, -.09, 1.19)), shoulder_r=V((.30, .025, 1.23)),
                   elbow_l=V((-.46, -.08, 1.015)), elbow_r=V((.395, .035, .90)),
                   wrist_l=V((-.38, -.13, 1.23)), wrist_r=V((.265, -.035, .64)),
                   knee_l=V((-.20, -.12, .40)), knee_r=V((.315, .095, .49)),
                   ankle_l=rest['ankle_l'], ankle_r=V((.355, -.01, .23)))
        p = {k: rest[k].lerp(low[k], u) for k in rest}
        p['head'].z += math.sin(t * math.pi * 2) * .026 * (1 - t)
    p['hip_l'] = p['pelvis'] + V((-.145, 0, 0))
    p['hip_r'] = p['pelvis'] + V((.145, 0, 0))
    return p


class Shape:
    """Explicit triangles with semantic region materials and stable indexing."""
    def __init__(self, near):
        self.near = near
        self.vertices, self.triangles, self.tiles, self.parts = [], [], [], []

    def add(self, name, points, faces, tile):
        start = len(self.vertices)
        self.vertices.extend(V(p) for p in points)
        before = len(self.triangles)
        for face in faces:
            for i in range(1, len(face) - 1):
                self.triangles.append((start + face[0], start + face[i], start + face[i + 1]))
                self.tiles.append(tile)
        self.parts.append((name, len(self.triangles) - before))

    def loft(self, name, rings, tile, n=None):
        n = n or (8 if self.near else 5)
        vs = []
        for center, rx, ry in rings:
            vs += [V(center) + V((rx * math.cos(i * math.tau / n), ry * math.sin(i * math.tau / n), 0)) for i in range(n)]
        fs = [tuple(reversed(range(n))), tuple(range((len(rings) - 1) * n, len(rings) * n))]
        for j in range(len(rings) - 1):
            fs += [(j*n+i, j*n+(i+1)%n, (j+1)*n+(i+1)%n, (j+1)*n+i) for i in range(n)]
        self.add(name, vs, fs, tile)

    def ell(self, name, center, scale, tile, n=None, bands=None, basis=None):
        n = n or (7 if self.near else 5)
        bands = bands or (3 if self.near else 2)
        vs = [V((0, 0, -scale[2]))]
        for j in range(1, bands + 1):
            phi = math.pi * j / (bands + 1)
            vs += [V((scale[0] * math.sin(phi) * math.cos(i*math.tau/n),
                      scale[1] * math.sin(phi) * math.sin(i*math.tau/n),
                      -scale[2] * math.cos(phi))) for i in range(n)]
        vs.append(V((0, 0, scale[2])))
        fs = [(0, 1+(i+1)%n, 1+i) for i in range(n)]
        for j in range(bands - 1):
            a = 1 + j*n
            fs += [(a+i, a+(i+1)%n, a+n+(i+1)%n, a+n+i) for i in range(n)]
        top = len(vs) - 1; last = 1+(bands-1)*n
        fs += [(last+i, last+(i+1)%n, top) for i in range(n)]
        self.add(name, [V(center)+(basis @ v if basis else v) for v in vs], fs, tile)

    def limb(self, name, a, b, radii, tile, n=None):
        a, b = V(a), V(b)
        axis = (b - a).normalized()
        across = axis.cross(V((0, 1, 0))).normalized()
        other = axis.cross(across).normalized()
        n = n or (7 if self.near else 5)
        vs = []
        for t, rx, ry in radii:
            c = a.lerp(b, t)
            vs += [c + across * (rx * math.cos(i*math.tau/n)) + other * (ry*math.sin(i*math.tau/n)) for i in range(n)]
        fs = [tuple(reversed(range(n))), tuple(range((len(radii)-1)*n, len(radii)*n))]
        for j in range(len(radii)-1):
            fs += [(j*n+i, j*n+(i+1)%n, (j+1)*n+(i+1)%n, (j+1)*n+i) for i in range(n)]
        self.add(name, vs, fs, tile)

    def panel(self, name, points, tile, thick=.014):
        n = len(points)
        vs = [V(p) + V((0, dy, 0)) for dy in (-thick/2, thick/2) for p in points]
        fs = [tuple(reversed(range(n))), tuple(range(n, n*2))]
        fs += [(i, (i+1)%n, (i+1)%n+n, i+n) for i in range(n)]
        self.add(name, vs, fs, tile)


def build_geometry(p, near=True):
    s = Shape(near)
    pelvis, chest, head = p['pelvis'], p['chest'], p['head']
    down = chest - pelvis
    # Continuous bell-shaped torso and upper trapezius establish the silhouette.
    s.loft('Torn ochre civilian work coat', [(pelvis+V((0, 0, -.035)), .225, .150),
           (pelvis.lerp(chest, .40), .275, .167), (chest, .347, .188),
           (chest+V((0, .035, .145)), .285, .175)], 4, 8 if near else 5)
    s.ell('Hunched bare shoulder yoke', chest+V((.012, .055, .154)), (.355, .190, .156), 1,
          8 if near else 5, 3 if near else 2)
    s.ell('Faded blue work trouser seat', pelvis+V((0, .015, -.035)), (.236, .158, .143), 8,
          7 if near else 5, 2)
    # The exposed sternum and unmatched remnants make a readable torn garment.
    def torso_pt(x, height, y):
        return pelvis.lerp(chest, height)+V((x, y, 0))
    s.panel('Exposed irregular sternum', [torso_pt(-.095,1.31,-.180), torso_pt(.11,1.28,-.189),
            torso_pt(.064,.81,-.195),torso_pt(.102,.62,-.190),torso_pt(-.025,.47,-.180),
            torso_pt(-.071,.86,-.198)], 0, .006)
    if near:
        s.panel('Dark open coat left edge', [torso_pt(-.145,1.30,-.181),torso_pt(-.089,1.28,-.198),
                torso_pt(-.06,.55,-.192),torso_pt(-.106,.58,-.186)], 5)
        s.panel('Coat pale frayed right seam', [torso_pt(.11,1.30,-.193),torso_pt(.13,1.27,-.190),
                torso_pt(.082,.73,-.204),torso_pt(.066,.76,-.205)], 6, .009)
    hem = pelvis+V((0,-.15,-.055))
    for i in range(3 if near else 2):
        x = (-.17 + i*.14) if near else (-.16+i*.28)
        s.panel('Uneven hanging coat tail', [hem+V((x-.065,.018,.13)),hem+V((x+.055,.005,.12)),
                hem+V((x+.026,-.022,-.08-(i%2)*.045)),hem+V((x-.054,0,-.022))], 5 if i==1 else 4)
    # Head is recessed into the broad yoke, with a readable face at RTS scale.
    s.limb('Thick folded neck', chest+V((0,-.085,.10)),head+V((0,.02,-.09)),
           [(0,.095,.08),(1,.073,.075)],1,6 if near else 4)
    s.ell('Asymmetric infected skull',head,(.116,.119,.143),0,8 if near else 5,3 if near else 2)
    s.ell('Dead heavy brow',head+V((-.006,-.106,.030)),(.110,.040,.039),1,6 if near else 4,1)
    s.ell('Sagging jaw',head+V((.009,-.045,-.102)),(.080,.090,.055),2,6 if near else 4,1)
    s.ell('Hollow slack mouth',head+V((.006,-.124,-.069)),(.055,.014,.028),7,6 if near else 4,1)
    if near:
        for x in (-.046,.046):
            s.ell('Sunken socket',head+V((x,-.114,.001)),(.028,.022,.021),7,5,1)
        s.ell('Bruised temple',head+V((.081,-.051,.047)),(.026,.074,.069),3,5,1)
        s.ell('Matted scalp',head+V((-.020,.025,.118)),(.091,.094,.026),7,6,1)
    # Large hanging arms: sleeves stop above the swollen uncovered forearms.
    for side, sign in [('l',-1),('r',1)]:
        shoulder, elbow, wrist = (p[k+'_'+side] for k in ('shoulder','elbow','wrist'))
        axis = (wrist-elbow).normalized()
        right = side == 'r'
        s.ell('Unequal deltoid '+side,shoulder,(.167 if right else .145,.153,.160),1 if right else 4,
              6 if near else 4,2 if near else 1)
        s.limb('Torn short coat sleeve '+side,shoulder,elbow,
               [(0,.141,.138),(.42,.133,.120),(.73,.102,.098)] if near else [(0,.14,.14),(.76,.10,.10)],
               5 if right else 4,6 if near else 4)
        s.limb('Exposed upper arm '+side,shoulder,elbow,[(.63,.087,.092),(1,.110,.100)],0,6 if near else 4)
        s.limb('Swollen demolition forearm '+side,elbow,wrist,
               [(0,.101,.105),(.27,.185 if right else .142,.155 if right else .125),
                (.68,.170 if right else .138,.143 if right else .12),(1,.124 if right else .102,.105)]
               if near else [(0,.106,.105),(.40,.186 if right else .143,.156 if right else .126),(1,.124 if right else .102,.105)],
               0 if right else 1,8 if near else 5)
        hand = wrist + axis*.10
        basis = axis.to_track_quat('Z','Y').to_matrix()
        s.ell('Heavy fused knuckles '+side,hand,(.147 if right else .121,.096,.143),1,6 if near else 4,2 if near else 1,basis)
        if near:
            for i in range(3):
                finger = hand+V(((i-1)*.058,-.043,0)) + axis*.089
                s.ell('Blunt curled finger '+side,finger,(.035,.046,.080),2,5,1,basis)
            s.ell('Split wrist bruise '+side,elbow.lerp(wrist,.52)+V((sign*.065,-.123,.005)),(.082,.018,.097),3,5,1,basis)
        # Irregular broken concrete is embedded in flesh, never a plate suit.
        for i in range((3 if right else 1) if near else 1):
            along = .25+i*.21
            pos = elbow.lerp(wrist,along)+V((sign*(.12 if right else .105),-.038+(i%2)*.065,0))
            s.ell('Broken embedded concrete '+side+str(i),pos,(.095 if right else .075,.115,.125),
                  12 if i%2==0 else 13,5 if near else 4,1,basis)
        if near and right:
            # Bent two-legged rebar hoop, deliberately broken and asymmetric.
            q = elbow.lerp(wrist,.49)+V((.165,.03,0))
            for a,b in [(q+V((.04,-.075,.13)),q+V((.085,-.075,.18))),
                        (q+V((.085,-.075,.18)),q+V((.11,.055,.10))),
                        (q+V((.11,.055,.10)),q+V((.04,.055,-.01)))]:
                s.limb('Rusty embedded rebar',a,b,[(0,.014,.014),(1,.014,.014)],11,4)
        hip,knee,ankle = (p[k+'_'+side] for k in ('hip','knee','ankle'))
        s.limb('Baggy worn trouser thigh '+side,hip,knee,[(0,.130,.132),(.5,.123,.123),(1,.095,.096)]
               if near else [(0,.132,.13),(1,.095,.095)],8,6 if near else 4)
        s.ell('Separated bent knee '+side,knee,(.099,.098,.099),0 if right else 9,6 if near else 4,1)
        s.limb('Worn trouser calf '+side,knee,ankle,[(0,.095,.093),(.45,.091,.085),(1,.071,.067)]
               if near else [(0,.095,.093),(1,.071,.067)],8,6 if near else 4)
        s.ell('Heavy flat work shoe '+side,ankle+V((sign*.008,-.063,-.068)),(.118,.178,.073),10,
              8 if near else 5,2 if near else 1)
        if near:
            s.ell('Worn toe cap '+side,ankle+V((sign*.008,-.191,-.059)),(.102,.048,.038),14,6,1)
    if near:
        s.ell('Shoulder concrete shard',p['shoulder_r']+V((.076,.08,.099)),(.091,.094,.112),13,5,1)
        for dx,dy,dz in [(.045,.02,.11),(.095,.07,.09)]:
            base=p['shoulder_r']+V((dx,dy,dz))
            s.limb('Shoulder rust bar',base,base+V((.035,.035,.125)),[(0,.012,.012),(1,.010,.010)],11,4)
    return s


def bake_death_collapse(shape, t):
    """Fall once in the offline mesh, ending in a limp asymmetric side-prone pose.

    Runtime node transform remains identity. The fixed grounding adjustment
    keeps the lower shoulder/hip on the floor throughout the fall; no separate
    gameplay root translation or second corpse rotation is required.
    """
    u=ease(max(0.,min(1.,(t-.10)/.78)))
    pitch=Matrix.Rotation(1.44*u,3,'X')
    twist=Matrix.Rotation(.27*u,3,'Z')
    roll=Matrix.Rotation(-.11*u,3,'Y')
    rotation=roll @ pitch @ twist
    transformed=[rotation @ v for v in shape.vertices]
    ground=min(v.z for v in transformed)
    settle=ease(max(0.,min(1.,(t-.45)/.55)))
    result=[]
    for v in transformed:
        height=v.z-ground
        # Flesh, loose clothing and bent joints lose their rigid supporting
        # arch as the shoulder takes the weight. Smooth compression preserves
        # volume order and avoids coincident flattened triangle layers.
        relaxed=.62*height*height/(height+.13) if height>0 else 0.
        v.z=-.011+mix(height,relaxed,settle)
        result.append(v)
    shape.vertices=result


def make_material():
    mat=bpy.data.materials.new('Original_Demolition_Infected_Atlas')
    mat.use_nodes=True
    bs=mat.node_tree.nodes.get('Principled BSDF')
    bs.inputs['Roughness'].default_value=.93
    tex=mat.node_tree.nodes.new('ShaderNodeTexImage')
    tex.image=bpy.data.images.load(str(OUT/'demolition_boss_atlas.png'))
    tex.image.pack()
    tex.image.filepath='//demolition_boss_atlas.png'
    mat.node_tree.links.new(tex.outputs['Color'],bs.inputs['Base Color'])
    return mat


def mesh_object(shape, name, mat):
    # Flip X and Y, producing Godot -Z forward after glTF's Z-up conversion.
    points=[(-v.x,-v.y,v.z) for v in shape.vertices]
    data=bpy.data.meshes.new(name)
    data.from_pydata(points,[],shape.triangles)
    data.update()
    uv=data.uv_layers.new(name='UVMap')
    ids=data.uv_layers.new(name='CornerID')
    count=len(data.loops); grid=math.ceil(math.sqrt(count))
    for polygon,tile in zip(data.polygons,shape.tiles):
        polygon.use_smooth=tile in (0,1,2,3)
        # Fixed face UVs independent of pose; UV2 corner IDs are also stable.
        for n,loop in enumerate(polygon.loop_indices):
            u,v=((.08,.08),(.92,.08),(.50,.92))[n]
            uv.data[loop].uv=((tile%4+u)/4,(3-tile//4+v)/4)
            ids.data[loop].uv=((loop%grid+.5)/grid,1-(loop//grid+.5)/grid)
    data.uv_layers.active_index=0
    data.uv_layers[0].active_render=True
    data.materials.append(mat)
    obj=bpy.data.objects.new(name,data)
    bpy.context.collection.objects.link(obj)
    return obj


def render_reviews(obj):
    scene=bpy.context.scene
    scene.render.engine='CYCLES'
    scene.cycles.samples=16
    scene.cycles.use_denoising=False
    scene.render.resolution_x=640;scene.render.resolution_y=640
    scene.render.resolution_percentage=100
    scene.world.color=(.12,.12,.12)
    scene.view_settings.view_transform='Standard'
    world=scene.world;world.use_nodes=True
    world.node_tree.nodes['Background'].inputs[0].default_value=(.075,.085,.090,1)
    world.node_tree.nodes['Background'].inputs[1].default_value=.65
    for name,loc,power,size in [('Key',(-3,-4,6),600,4),('Fill',(3,2,4),320,3)]:
        data=bpy.data.lights.new(name,'AREA');data.energy=power;data.shape='DISK';data.size=size
        o=bpy.data.objects.new(name,data);scene.collection.objects.link(o);o.location=loc
        o.rotation_euler=(V((0,0,.8))-o.location).to_track_quat('-Z','Y').to_euler()
    cam_data=bpy.data.cameras.new('ReviewCamera');cam=bpy.data.objects.new('ReviewCamera',cam_data)
    scene.collection.objects.link(cam);scene.camera=cam;cam_data.type='ORTHO';cam_data.ortho_scale=2.3
    # Geometry has already been rotated, so positive Y is the model's front.
    for name,loc in [('three_quarter',(-3.1,4.5,3.0)),('front',(0,5,2.0)),('back',(0,-5,2.0)),('rts',(-3,4,5.2))]:
        cam.location=loc;cam.rotation_euler=(V((0,0,.82))-cam.location).to_track_quat('-Z','Y').to_euler()
        scene.render.filepath=str(REVIEW/(name+'.png'))
        bpy.ops.render.render(write_still=True)


def main():
    parser=argparse.ArgumentParser()
    parser.add_argument('--preview-only',action='store_true')
    parser.add_argument('--render',action='store_true')
    args=parser.parse_args(sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else [])
    OUT.mkdir(exist_ok=True);REVIEW.mkdir(exist_ok=True)
    bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
    mat=make_material()
    manifest={'revision':'original_demolition_boss_v2_death_readability','forward':'Godot -Z','units':'meters',
              'runtime_bones':0,'root_translation':False,'pose_count':44,
              'walk_stride_m':.54,'walk_stance_fraction':.62,
              'clips':{k:{'duration':v[0],'frames':v[1],'loop':k in ('idle','walk')} for k,v in CLIPS.items()},
              'attack_contact':'windup_11 equals recovery_00 exactly; damage is a runtime event',
              'death':'asymmetric limp side-prone fall baked once; no runtime root topple','lods':{}}
    preview=None
    for lod,near in [('near',True),('far',False)]:
        objs=[];topology=None
        for clip,(_,count) in CLIPS.items():
            for frame in range(count):
                if args.preview_only and (clip!='idle' or frame!=0 or not near):continue
                t=frame/count if clip in ('idle','walk') else frame/(count-1)
                shape=build_geometry(pose(clip,t),near)
                if clip=='death':bake_death_collapse(shape,t)
                obj=mesh_object(shape,f'{clip}_{frame:02d}',mat);objs.append(obj)
                if preview is None:preview=obj
                h=hashlib.sha256(json.dumps(shape.triangles).encode()).hexdigest()
                if topology is None:topology=h
                assert h==topology,'Pose topology changed'
                assert len(shape.triangles)<=(1500 if near else 500),(lod,len(shape.triangles))
                obj['semantic_parts']=json.dumps(shape.parts)
        if not objs:continue
        if args.preview_only:continue
        bpy.ops.object.select_all(action='DESELECT')
        for obj in objs:obj.select_set(True)
        path=OUT/f'demolition_boss_{lod}.glb'
        bpy.ops.export_scene.gltf(filepath=str(path),export_format='GLB',use_selection=True,
            export_animations=False,export_skins=False,export_yup=True,export_texcoords=True,
            export_normals=True,export_tangents=False,export_materials='EXPORT',export_extras=False)
        assert path.stat().st_size<10_000_000,path.stat().st_size
        manifest['lods'][lod]={'triangles':len(objs[0].data.polygons),'corners':len(objs[0].data.loops),
                             'topology_sha256':topology,'file':path.name,'bytes':path.stat().st_size}
        for obj in objs:obj.hide_render=True;obj.hide_viewport=True
    if preview:
        preview.hide_render=False;preview.hide_viewport=False
        bpy.context.view_layer.objects.active=preview
        bpy.ops.object.select_all(action='DESELECT');preview.select_set(True)
    (OUT/'boss_manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
    sys.path.insert(0,str(ROOT/'source'))
    from finalize_boss_glbs import finalize_all
    finalize_all()
    # Optional local inspection file. Distribute the reproducible Python and
    # atlas; Blender's factory UI data can retain environment-local paths.
    bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'demolition_boss_source.blend'))
    if args.render and preview:render_reviews(preview)
    print(json.dumps(manifest,indent=2))


if __name__=='__main__':main()
