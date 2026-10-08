"""Original ruined freight cover + civilian transfer gantry for RECLAMATION.

Blender 4.3+; run after create_freight_atlas.py:
  blender --background --threads 2 --python source/build_freight_yard.py
Append -- --render for three optional CPU review renders. All writes stay inside
this art directory. Runtime meshes use metres and Godot Y up, ground Y = 0.
"""
import bpy, bmesh, math, json, struct, random, sys
from pathlib import Path
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[1]
ASSETS = ROOT / 'assets'
PI = math.pi
TEX = {k: 'freight_yard_' + k + '.png' for k in ('albedo', 'orm')}
REPORTS = {}
PARTS = []

def reset(name):
    global PARTS, AUTHOR, MAT
    for obj in list(bpy.data.objects):
        bpy.data.objects.remove(obj, do_unlink=True)
    for col in list(bpy.data.collections):
        if col.name != 'Collection': bpy.data.collections.remove(col)
    for mat in list(bpy.data.materials): bpy.data.materials.remove(mat)
    for image in list(bpy.data.images):
        if image.name not in ('Render Result', 'Viewer Node'): bpy.data.images.remove(image)
    random.seed(1040820)
    PARTS = []
    AUTHOR = bpy.data.collections.new('AUTHORING | named editable components')
    bpy.context.scene.collection.children.link(AUTHOR)
    MAT = bpy.data.materials.new('FreightYard_SharedAtlas_PBR')
    MAT.use_nodes = True
    # Folded steel sheets are visible from both sides without duplicate surfaces.
    MAT.use_backface_culling = False
    nodes, links = MAT.node_tree.nodes, MAT.node_tree.links
    bs = nodes.get('Principled BSDF')
    bs.inputs['Specular IOR Level'].default_value = .20
    for kind in TEX:
        tex = nodes.new('ShaderNodeTexImage'); tex.name = kind
        tex.image = bpy.data.images.load(str(ASSETS/TEX[kind]), check_existing=False)
        tex.image.colorspace_settings.name = 'sRGB' if kind == 'albedo' else 'Non-Color'
        tex.image.pack(); tex.image.filepath = '//../assets/' + TEX[kind]
        for packed in tex.image.packed_files: packed.filepath = tex.image.filepath
        tex.extension = 'EXTEND'
        if kind == 'albedo': links.new(tex.outputs['Color'], bs.inputs['Base Color'])
        else:
            sep = nodes.new('ShaderNodeSeparateColor')
            links.new(tex.outputs['Color'], sep.inputs['Color'])
            links.new(sep.outputs['Green'], bs.inputs['Roughness'])
            links.new(sep.outputs['Blue'], bs.inputs['Metallic'])

def finish(o, name, tile=0):
    o.name = name
    bpy.context.view_layer.objects.active = o
    o.select_set(True)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    bm = bmesh.new(); bm.from_mesh(o.data)
    bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces)); bm.to_mesh(o.data); bm.free()
    o.data.update(); o.data.materials.clear(); o.data.materials.append(MAT)
    uv = o.data.uv_layers.active or o.data.uv_layers.new(name='FreightAtlas')
    uv.name = 'FreightAtlas'
    lo = [min(v.co[k] for v in o.data.vertices) for k in range(3)]
    hi = [max(v.co[k] for v in o.data.vertices) for k in range(3)]
    # Each component projects inside a single tile, staying clear of its gutter.
    for face in o.data.polygons:
        axis = max(range(3), key=lambda k: abs(face.normal[k]))
        ax = [k for k in range(3) if k != axis]
        for li in face.loop_indices:
            v = o.data.vertices[o.data.loops[li].vertex_index].co
            q = [.075+(v[k]-lo[k])/max(.001,hi[k]-lo[k])*.85 for k in ax]
            uv.data[li].uv = ((tile%4+q[0])/4, (3-tile//4+q[1])/4)
    for col in list(o.users_collection): col.objects.unlink(o)
    AUTHOR.objects.link(o); PARTS.append(o); o.select_set(False)
    return o

def mesh(name, verts, faces, tile=0):
    me = bpy.data.meshes.new(name); me.from_pydata(verts, [], faces); me.update()
    o = bpy.data.objects.new(name, me); bpy.context.collection.objects.link(o)
    return finish(o, name, tile)

def box(name, p, dims, tile=0, rot=(0,0,0)):
    bpy.ops.mesh.primitive_cube_add(size=1, location=p, rotation=rot)
    o = bpy.context.object; o.scale = dims
    return finish(o, name, tile)

def cyl(name, p, radius, height, tile=2, sides=8, rot=(0,0,0)):
    bpy.ops.mesh.primitive_cylinder_add(vertices=sides, radius=radius, depth=height, location=p, rotation=rot)
    return finish(bpy.context.object, name, tile)

def beam(name, a, b, radius=.025, tile=9, sides=6):
    a,b = Vector(a),Vector(b)
    o = cyl(name,(a+b)/2,radius,(b-a).length,tile,sides)
    o.rotation_euler = (b-a).to_track_quat('Z','Y').to_euler()
    return o

def squarebeam(name, a, b, width=.07, depth=.07, tile=9):
    a,b = Vector(a),Vector(b)
    o = box(name,(a+b)/2,(width,depth,(b-a).length),tile)
    o.rotation_euler = (b-a).to_track_quat('Z','Y').to_euler()
    return o

def section(name,a,b,width=.20,depth=.23,thick=.045,tile=0):
    w,h,t = width/2,depth/2,thick/2
    ring = [(-w,-h),(w,-h),(w,-h+thick),(t,-h+thick),(t,h-thick),
            (w,h-thick),(w,h),(-w,h),(-w,h-thick),(-t,h-thick),(-t,-h+thick),(-w,-h+thick)]
    a,b = Vector(a),Vector(b); q=(b-a).to_track_quat('Z','Y'); n=len(ring)
    verts=[tuple(p+q@Vector((x,y,0))) for p in (a,b) for x,y in ring]
    faces=[tuple(reversed(range(n))),tuple(range(n,2*n))]
    faces += [(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)]
    return mesh(name,verts,faces,tile)

def pipe(name,points,radius=.025,tile=9,sides=6):
    points=[Vector(p) for p in points]; verts=[]
    for i,p in enumerate(points):
        axis=(points[min(i+1,len(points)-1)]-points[max(0,i-1)]).normalized()
        ref=Vector((0,0,1)) if abs(axis.z)<.9 else Vector((1,0,0))
        u=axis.cross(ref).normalized();v=axis.cross(u)
        verts += [tuple(p+radius*(u*math.cos(2*PI*j/sides)+v*math.sin(2*PI*j/sides))) for j in range(sides)]
    faces=[(i*sides+j,i*sides+(j+1)%sides,(i+1)*sides+(j+1)%sides,(i+1)*sides+j) for i in range(len(points)-1) for j in range(sides)]
    faces += [tuple(reversed(range(sides))),tuple(range((len(points)-1)*sides,len(points)*sides))]
    return mesh(name,verts,faces,tile)

def slab(name,outline,height=.16,tile=7):
    n=len(outline); verts=[(x,y,z) for z in (0,height) for x,y in outline]
    faces=[tuple(reversed(range(n))),tuple(range(n,2*n))]
    faces += [(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)]
    return mesh(name,verts,faces,tile)

def folded_sheet(name,xs,ys,zrows,tile=0):
    """A designed folded surface, deliberately never an intact flat box lid."""
    nx,ny=len(xs),len(ys)
    verts=[(x,y,zrows[j][i]) for j,y in enumerate(ys) for i,x in enumerate(xs)]
    faces=[(j*nx+i,j*nx+i+1,(j+1)*nx+i+1,(j+1)*nx+i) for j in range(ny-1) for i in range(nx-1)]
    return mesh(name,verts,faces,tile)

def ruined_cover(variant=0):
    name='ruined_freight_teal' if variant==0 else 'ruined_freight_oxide'
    reset(name); paint=0 if variant==0 else 1
    # Continuous surviving chassis retains an honest, fully blocked footprint.
    box('Dark crushed cargo bed',(0,0,.115),(5.80,2.32,.15),4)
    for y in (-1.205,1.205):
        box('Surviving lower side sill',(0,y,.07),(6,.09,.14),9)
    for x in (-2.94,2.94):
        box('End chassis beam',(x,0,.08),(.12,2.50,.16),9)
        for y in (-1.17,1.17):
            box('Cast corner socket',(x,y,.16),(.12,.16,.15),2)
    # Large asymmetric sag, with creased sheets and ribs following the damage.
    def roofline(x,side):
        if variant==0:
            return 1.16-.40*math.exp(-((x+.18+side*.20)/.95)**2)+.045*math.sin(x*3+side)
        return 1.10-.40*math.exp(-((x-.95-side*.17)/.78)**2)+.08*math.sin(x*2.1+side)
    count=36
    for side in (-1,1):
        verts=[]
        for row in range(3):
            for i in range(count+1):
                x=-2.82+5.64*i/count
                top=roofline(x,side)
                zz=[.18,.54+(.045*math.sin(x*2)),top][row]
                corr=.033 if i%3==1 else -.015
                dent=(.13*math.exp(-((x-(.2 if variant==0 else 1.1))/.6)**2)) if row==1 else .01
                yy=side*(1.18+corr-dent)
                verts.append((x,yy,zz))
        faces=[]
        for row in range(2):
            for i in range(count):
                # A torn opening reaches the upper rim; the dark cargo remains below.
                if side==-1 and row==1 and ((variant==0 and 18<=i<=21) or (variant==1 and 27<=i<=30)): continue
                a=row*(count+1)+i;faces.append((a,a+1,a+count+2,a+count+1))
        mesh('Buckled corrugated side skin '+str(side),verts,faces,paint)
        # Bent upper rail uses a few broad bends that remain legible at game scale.
        xs=[-2.86,-1.75,-.7,.25,1.10,2.1,2.86]
        for i in range(len(xs)-1):
            if side==-1 and i==3: continue
            squarebeam('Bent upper side rail',
                       (xs[i],side*1.165,roofline(xs[i],side)+.025),
                       (xs[i+1],side*1.165,roofline(xs[i+1],side)+.025),.055,.06,10)
    for x in (-2.88,2.88):
        for y in (-1.16,1.16):
            h=1.29 if x<0 and y>0 else roofline(x,1 if y>0 else -1)
            squarebeam('Surviving corner post',(x,y,.12),(x-.035,y*.97,h),.095,.09,paint)
    # Roof survives in folded islands, separated by a genuine central black void.
    if variant==0:
        folded_sheet('Forward roof peeled and folded inward',[-2.80,-2.15,-1.2,-.54],[-1.12,-.47,.44,1.10],
                     [[1.10,1.00,.95,.82],[1.09,.98,.74,.48],[1.15,1.10,.88,.43],[1.18,1.04,.93,.91]],paint)
        folded_sheet('Rear roof collapsed over cargo',[.44,1.1,1.98,2.79],[-1.08,-.25,.51,1.10],
                     [[.72,.88,1.11,1.09],[.38,.58,.90,1.00],[.50,.70,.98,1.08],[.88,1.00,1.12,1.15]],1)
        folded_sheet('Rupture flap standing off rim',[-.65,-.30,.05],[-1.06,-.74,-.48],
                     [[.80,.70,.82],[1.15,1.22,1.08],[1.04,1.14,.90]],10)
    else:
        folded_sheet('Roof torn to one broad surviving flap',[-2.8,-1.83,-.73,.40],[-1.10,-.34,.50,1.10],
                     [[1.19,1.1,.98,.86],[1.11,.72,.85,.52],[1.16,.94,.74,.40],[1.15,1.13,1.02,.90]],paint)
        folded_sheet('Collapsed far roof island',[1.20,1.89,2.79],[-1.08,-.23,.48,1.10],
                     [[.64,.90,1.17],[.33,.72,1.09],[.57,.90,1.10],[.88,1.13,1.15]],0)
        folded_sheet('Raised torn roof seam',[.16,.60,.92],[-1.0,-.68,-.32],
                     [[.85,.62,.68],[1.17,1.08,.86],[1.10,.81,.69]],10)
    # Crumpled closed end: long folded channels, not a rectangular cap.
    ys=[-1.08,-.88,-.66,-.44,-.22,0,.22,.44,.66,.88,1.08]
    vs=[]
    for row in range(3):
        for i,y in enumerate(ys):
            vs.append((-2.84+(.02 if i%2 else 0)+(.14 if row==1 else 0),y,[.20,.59,1.13-.12*abs(y)][row]))
    mesh('Crushed closed end with folded corrugations',vs,[(j*len(ys)+i,j*len(ys)+i+1,(j+1)*len(ys)+i+1,(j+1)*len(ys)+i) for j in range(2) for i in range(len(ys)-1)],paint)
    # Original double doors now tilted inward at different angles, staying inside.
    for door, y in enumerate((-.56,.50)):
        x=2.70 if door==0 else 2.39
        h=.93 if door==0 else .66
        o=box('Bent inward freight door '+str(door),(x,y,.20+h/2),(.055,.92,h),paint if door==0 else 10, (0,.17 if door==0 else -.30,.08))
        for yy in (y-.28,y+.28):
            beam('Distorted door locking rod',(x+.055,yy,.25),(x-.06,yy,.20+h*.91),.019,2,6)
        for zz in (.31,.73):
            box('Door hinge stub',(2.83,1.03 if door else -1.03,zz),(.1,.09,.09),10)
    # Broken roof cross-stays, conspicuous against the cavity.
    for x in (-1.45,.06,1.52):
        squarebeam('Roof cross stay folded into cavity',(x,-1.08,.99),(x+.18,.08,.46),.07,.055,10)
        squarebeam('Roof cross stay surviving half',(x+.18,.08,.46),(x+.22,1.06,.96),.07,.055,9)
    for i,(x,y,z) in enumerate([(-.2,.18,.30),(.72,.50,.28),(-.60,-.44,.23)]):
        box('Cargo fragments retained inside hull '+str(i),(x,y,z),(.60,.53,.25),3 if i%2==0 else 8, (0,.04*(i-1),.14*(i-1)))
    export(name,limit=1200,bounds=(3,1.25,1.30))

def crate(name,p,dims,tilt=0):
    x,y,z=p;w,d,h=dims
    box(name+' dark inner cargo',(x,y,z+h*.47),(w*.92,d*.92,h*.90),4)
    # Open plank gaps and diagonal strapping define recognizable rough cargo.
    for side in (-1,1):
        for row in range(4):
            zz=z+(row+.5)*h/4
            box(name+' side timber',(x,y+side*d*.48,zz),(w,.05,h/4-.027),3)
        for xx in (x-w*.40,x+w*.40):
            box(name+' end upright',(xx,y+side*d*.49,z+h*.50),(.09,.07,h+.04),11)
        squarebeam(name+' diagonal strap',(x-w*.43,y+side*d*.51,z+.10),(x+w*.43,y+side*d*.51,z+h-.10),.058,.042,9)
    for side in (-1,1):
        for row in range(4):
            box(name+' end board',(x+side*w*.48,y,z+(row+.5)*h/4),(.05,d,h/4-.027),3)
    for k in range(4):
        box(name+' lid plank',(x-w*.38+k*w*.25,y,z+h),(w*.235,d,.045),3)

def gantry():
    name='freight_transfer_gantry';reset(name)
    slab('Chipped loading apron',[(-2.10,-1.43),(-1.83,-1.75),(1.84,-1.75),(2.10,-1.46),(2.10,1.48),(1.89,1.75),(-1.88,1.75),(-2.10,1.45)],.15)
    # Civilian A-frame end supports and an open bridge; never a solid roof block.
    for x in (-1.64,1.64):
        for y in (-1.08,1.08):
            box('Gantry footing',(x,y,.245),(.45,.43,.19),7)
            box('Bolted foot plate',(x,y,.365),(.38,.34,.045),10)
            section('Splayed surviving gantry leg',(x,y,.39),(x,y*.48,2.89),.17,.20,.037,0)
            for dx in (-.115,.115):
                for dy in (-.10,.10):
                    cyl('Footing exposed anchor',(x+dx,y+dy,.397),.034,.022,2,6)
            box('Civilian faded leg paint band',(x,y*.74,1.72),(.182,.22,.20),5)
        section('A-frame head tie',(x,-.63,2.89),(x,.63,2.89),.16,.18,.036,10)
        section('A-frame lower tie',(x,-.99,.88),(x,.99,.88),.10,.12,.027,9)
        squarebeam('End-frame diagonal repair',(x,-.92,1.03),(x,.44,2.70),.065,.065,2)
    for y in (-.52,.52):
        section('Overhead open bridge top chord',(-1.97,y,3.06),(1.97,y,3.06),.20,.23,.042,0)
        section('Overhead hoist running flange',(-1.85,y,2.61),(1.85,y,2.61),.18,.12,.034,10)
        for i in range(6):
            x=-1.82+i*.61
            squarebeam('Lattice bridge diagonal',(x,y,2.66),(x+.59,y,3.01),.048,.052,2 if i==4 else 10)
        for x in (-1.64,1.64):
            squarebeam('Knee brace',(x,y*.98,2.1),(x-math.copysign(.49,x),y,2.62),.075,.075,9)
    for x in (-1.8,-.60,.60,1.8):
        squarebeam('Bridge transverse roof purlin',(x,-.73,3.17),(x,.79,3.17),.065,.055,9)
    # Only half a corrugated rain shelter survives, folded down on one end.
    xs=[-1.98,-1.56,-1.12,-.68,-.23,.20]
    ys=[-.83,-.68,-.52,-.36,-.20,-.04,.12,.28,.44,.60,.80]
    rows=[]
    for j,y in enumerate(ys):
        rows.append([3.24+(0.025 if j%2 else 0)-.12*max(0,x+.5)-.09*abs(y) for x in xs])
    folded_sheet('Damaged corrugated rain hood',xs,ys,rows,1)
    folded_sheet('Peeled shelter corner',[.22,.62,.95],[.15,.46,.79],
                 [[2.84,2.88,2.78],[3.21,3.10,2.92],[3.24,3.21,3.00]],0)
    # Rolling trolley and a horizontal geared drum, visible through missing roof.
    box('Hoist trolley carriage',(.40,0,2.77),(.76,.92,.13),9)
    for x in (.11,.70):
        for y in (-.47,.47):
            cyl('Trolley flanged wheel',(x,y,2.69),.12,.08,2,10,(PI/2,0,0))
    cyl('Weathered winch drum',(.40,0,2.94),.19,.68,9,12,(PI/2,0,0))
    for y in (-.37,.37):
        cyl('Winch spool flange',(.40,y,2.94),.245,.05,10,12,(PI/2,0,0))
    for y in (-.25,-.13,-.01,.11,.23):
        cyl('Coarse cable wound on drum',(.40,y,2.94),.20,.027,13,10,(PI/2,0,0))
    cyl('Geared electric hoist motor',(.90,.13,2.90),.15,.45,0,10,(PI/2,0,0))
    for y in (-.02,.08,.18,.28):
        cyl('Motor cooling rib',(.90,y,2.90),.18,.024,9,10,(PI/2,0,0))
    # A hanging crooked lower block and heavy open hook read from the RTS camera.
    pipe('Slack hoist cable left',[(.22,-.17,2.74),(.15,-.19,2.30),(.22,-.22,1.80),(.34,-.24,1.51)],.023,13,6)
    pipe('Slack hoist cable right',[(.54,-.17,2.74),(.65,-.19,2.27),(.54,-.22,1.81),(.40,-.24,1.51)],.023,13,6)
    box('Lower hoist block',(.36,-.24,1.56),(.36,.25,.28),5,(0,.06,-.08))
    cyl('Lower pulley exposed hub',(.36,-.38,1.56),.095,.045,2,10,(PI/2,0,0))
    pipe('Open cargo hook',[(.36,-.24,1.42),(.34,-.24,1.29),(.27,-.24,1.15),(.32,-.24,1.04),(.47,-.24,1.03),(.56,-.24,1.12),(.52,-.24,1.19)],.045,2,7)
    # Repaired side controls and a slack lead; no military symbol or identity.
    box('Recovered civilian hoist switch box',(-1.66,-.30,1.02),(.47,.34,.62),6)
    box('Mismatched cabinet front',(-1.66,-.486,1.02),(.41,.027,.55),0)
    for z in (.87,.94):
        box('Cabinet vent',(-1.66,-.505,z),(.24,.015,.023),4)
    box('Dark readiness lens housing',(-1.66,-.516,1.16),(.28,.036,.13),9)
    box('Inactive amber readiness lens',(-1.66,-.54,1.16),(.21,.013,.075),14)
    pipe('Sagging hoist service cable',[(-1.65,-.20,1.31),(-1.43,-.16,1.69),(-1.28,-.09,2.0),(-1.0,0,2.19),(-.44,.04,2.16),(.06,.08,2.36),(.83,.08,2.70)],.022,13,6)
    # Storage is inside the already blocked apron. The front work edge stays tidy.
    for y in (.50,1.05):
        box('Pallet load bearing runner',(-.57,y,.25),(1.65,.16,.18),3)
    for x in (-1.25,-.87,-.49,-.11):
        box('Pallet cross board',(x,.77,.36),(.29,.98,.06),3)
    crate('Salvaged transfer crate',(-.65,.79,.40),(1.24,.88,.69))
    box('Canvas protected smaller parcel',(-.50,.82,1.21),(.76,.61,.24),8,(0,.03,-.09))
    for x in (-.73,-.30):
        box('Canvas parcel tied strap',(x,.82,1.343),(.046,.63,.023),9,(0,0,-.09))
    # Pipe bundle preserves an open recognizable freight silhouette beside crate.
    for y,z in [( .75,.40),(1.01,.40),(1.27,.40),(.88,.61),(1.14,.61)]:
        pipe('Freight pipe cargo',[(.47,y,z),(1.31,y,z)],.115,2,8)
    for x in (.57,1.20):
        squarebeam('Pipe bundle lower batten',(x,.52,.21),(x,1.48,.21),.14,.09,3)
        pipe('Pipe bundle binding',[(x,.61,.28),(x,.67,.67),(x,1.24,.72),(x,1.40,.38)],.025,10,6)
    # Worn loading marker uses geometry, never text or a borrowed brand.
    box('Freight handling pictogram backing',(-1.65,-.655,2.30),(.42,.035,.35),6)
    for xx in (-1.74,-1.56):
        box('Freight upward handling arrow stem',(xx,-.680,2.28),(.033,.01,.15),9)
        mesh('Freight upward handling arrow tip',[(xx-.069,-.687,2.31),(xx+.069,-.687,2.31),(xx,-.687,2.40)],[(0,1,2)],9)
    for x in (-1.90,1.88):
        box('Faded apron work edge',(x,-1.32,.157),(.065,.41,.012),5)
    # Only three large retained chunks, away from the approach edges.
    for i,(x,y) in enumerate([(1.78,1.48),(1.53,1.48),(-1.85,1.43)]):
        box('Retained concrete fragment',(x,y,.22),(.20,.23,.14),7,(0,.06,.2*(i-1)))
    export(name,limit=4000,bounds=(2.10,1.75,3.4))

def externalize_glb(path):
    data=path.read_bytes();magic,version,total=struct.unpack_from('<III',data)
    assert magic==0x46546C67 and version==2 and total==len(data)
    jl,jt=struct.unpack_from('<II',data,12);doc=json.loads(data[20:20+jl]);off=20+jl
    bl,bt=struct.unpack_from('<II',data,off);binary=data[off+8:off+8+bl]
    pbr=doc['materials'][0]['pbrMetallicRoughness']
    refs={'albedo':pbr['baseColorTexture'],'orm':pbr['metallicRoughnessTexture']}
    sources={doc['textures'][ref['index']]['source']:TEX[k] for k,ref in refs.items()}
    image_views={im['bufferView'] for im in doc['images'] if 'bufferView' in im}
    packed=bytearray();views=[];mapping={}
    for old,view in enumerate(doc['bufferViews']):
        if old in image_views:continue
        while len(packed)%4:packed.append(0)
        new=dict(view);new['byteOffset']=len(packed)
        packed.extend(binary[view.get('byteOffset',0):view.get('byteOffset',0)+view['byteLength']])
        mapping[old]=len(views);views.append(new)
    for a in doc['accessors']:
        if 'bufferView' in a:a['bufferView']=mapping[a['bufferView']]
    doc['bufferViews']=views
    doc['images']=[{'uri':sources[i],'name':Path(sources[i]).stem} for i in range(len(doc['images']))]
    doc['buffers']=[{'byteLength':len(packed)}]
    # Explicit minification contract; Godot must also import PNG mipmaps.
    for sampler in doc.get('samplers',[]):
        sampler.update({'magFilter':9729,'minFilter':9987,'wrapS':33071,'wrapT':33071})
    doc['asset']['copyright']='Original RECLAMATION freight geometry and atlas, 2026-10-08. See PROVENANCE.md; no license grant asserted.'
    while len(packed)%4:packed.append(0)
    jb=json.dumps(doc,separators=(',',':')).encode();jb+=b' '*((-len(jb))%4)
    out=struct.pack('<III',0x46546C67,2,12+8+len(jb)+8+len(packed))+struct.pack('<II',len(jb),0x4E4F534A)+jb+struct.pack('<II',len(packed),0x004E4942)+packed
    path.write_bytes(out)

def render_preview(name,master):
    scene=bpy.context.scene
    scene.render.engine='CYCLES';scene.cycles.samples=32;scene.cycles.use_denoising=False
    scene.render.threads_mode='FIXED';scene.render.threads=2
    scene.render.resolution_x=1000;scene.render.resolution_y=780;scene.render.resolution_percentage=100
    scene.world.use_nodes=True
    scene.world.node_tree.nodes['Background'].inputs[0].default_value=(.18,.21,.20,1)
    scene.world.node_tree.nodes['Background'].inputs[1].default_value=.7
    for p,size,power in [((2,-4,7),6,1100),((-4,1,5),5,700)]:
        bpy.ops.object.light_add(type='AREA',location=p);light=bpy.context.object
        light.data.energy=power;light.data.shape='DISK';light.data.size=size
        light.rotation_euler=(Vector((0,0,.8))-light.location).to_track_quat('-Z','Y').to_euler()
    bpy.ops.object.camera_add(location=(7,-9,6.3))
    camera=bpy.context.object;target=Vector((0,0,1.1 if 'gantry' in name else .45))
    camera.rotation_euler=(target-camera.location).to_track_quat('-Z','Y').to_euler()
    camera.data.type='ORTHO';camera.data.ortho_scale=6.8 if 'gantry' in name else 7.5
    scene.camera=camera
    scene.view_settings.view_transform='AgX'
    scene.render.film_transparent=False
    scene.render.image_settings.file_format='PNG'
    scene.render.filepath=str(ROOT/'reports'/(name+'_review.png'))
    bpy.ops.render.render(write_still=True)

def export(name,limit,bounds):
    col=bpy.data.collections.new('EXPORT_MASTER | one mesh one material')
    bpy.context.scene.collection.children.link(col)
    copies=[]
    for part in PARTS:
        cp=part.copy();cp.data=part.data.copy();col.objects.link(cp);copies.append(cp)
    bpy.ops.object.select_all(action='DESELECT')
    for cp in copies:cp.select_set(True)
    bpy.context.view_layer.objects.active=copies[0];bpy.ops.object.join()
    master=bpy.context.object;master.name=name
    bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
    master.data.materials.clear();master.data.materials.append(MAT)
    for face in master.data.polygons:face.material_index=0
    tri=master.modifiers.new('Runtime triangulation','TRIANGULATE');bpy.ops.object.modifier_apply(modifier=tri.name)
    verts=[v.co for v in master.data.vertices]
    lo=[min(v[k] for v in verts) for k in range(3)];hi=[max(v[k] for v in verts) for k in range(3)]
    count=len(master.data.polygons)
    assert count<=limit,(name,count,limit)
    assert lo[0]>=-bounds[0]-.0001 and hi[0]<=bounds[0]+.0001,(name,lo,hi,bounds)
    assert lo[1]>=-bounds[1]-.0001 and hi[1]<=bounds[1]+.0001,(name,lo,hi,bounds)
    assert abs(lo[2])<.0001 and hi[2]<=bounds[2]+.0001,(name,lo,hi,bounds)
    master['provenance']='Original RECLAMATION ruined civilian freight asset, 2026-10-08. See PROVENANCE.md.'
    master['contract']='Visual only; metres; Godot Y up; ground origin; no collision, scripts, lights, rigs or animation.'
    path=ASSETS/(name+'.glb')
    bpy.ops.export_scene.gltf(filepath=str(path),export_format='GLB',use_selection=True,export_texcoords=True,export_normals=True,export_materials='EXPORT',export_image_format='AUTO',export_yup=True,export_apply=True,export_extras=True)
    externalize_glb(path)
    AUTHOR.hide_render=True;AUTHOR.hide_viewport=True
    scene=bpy.context.scene;scene.unit_settings.system='METRIC'
    scene['authoring']='Unhide AUTHORING and hide EXPORT_MASTER to edit named components. Regeneration replaces manual edits.'
    scene['provenance']='Original freight geometry and atlas; no external asset inputs. See ../PROVENANCE.md.'
    scene['runtime_contract']='One mesh, one PBR material; 1024 px original atlas shared between all three GLBs.'
    scene.render.filepath='//../reports/'+name+'_review.png'
    for screen in bpy.data.screens:
        for area in screen.areas:
            for space in area.spaces:
                if space.type=='FILE_BROWSER' and space.params:
                    space.params.directory=b'//';space.params.filename=''
    bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'source'/(name+'.blend')))
    REPORTS[name]={'triangles':count,'editable_components':len(PARTS),'surface_count':1,'material_count':1,
        'godot_aabb_min':[lo[0],lo[2],-hi[1]],'godot_aabb_max':[hi[0],hi[2],-lo[1]],
        'runtime_bytes':path.stat().st_size,'texture_uris':TEX,'embedded_image_bytes':0,
        'physics':False,'skeleton':False,'animations':False,'lights':False}
    print('FREIGHT_ASSET',json.dumps(REPORTS[name]))
    if '--render' in sys.argv:render_preview(name,master)

if __name__=='__main__':
    for d in ('assets','source','reports'):(ROOT/d).mkdir(exist_ok=True)
    ruined_cover(0);ruined_cover(1);gantry()
    (ROOT/'reports/geometry_report.json').write_text(json.dumps(REPORTS,indent=2)+'\n')
    print('Built original freight covers and cargo transfer gantry.')
