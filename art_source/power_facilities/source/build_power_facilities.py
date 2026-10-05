"""Original RECLAMATION civilian power facilities, Blender 4.3+.

Two editable models with one runtime PBR surface each. Geometry is authored here;
the existing project salvage atlas is reused unchanged. Public reference pages
in PROVENANCE.md informed functional forms, never geometry or texture inputs.
Run: blender --background --threads 2 --python source/build_power_facilities.py
Set RECLAMATION_SHARED_MODELS to an existing project's assets/models directory.
"""
import bpy, bmesh, math, random, json, os, struct, shutil, hashlib
from pathlib import Path
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[1]
PROJECT = ROOT.parents[1]
RUNTIME = PROJECT / 'assets/models'
SHARED = Path(os.environ.get('RECLAMATION_SHARED_MODELS', str(RUNTIME)))
PI = math.pi
PARTS = []
REPORTS = {}
TEX = {k: f'ammo_workshop_salvage_{k}.png' for k in ('albedo', 'orm', 'normal')}
for directory in (ROOT/'source', ROOT/'reports', RUNTIME):
    directory.mkdir(parents=True, exist_ok=True)

def reset(asset):
    global PARTS, AUTHOR, MAT
    for existing in list(bpy.data.objects): bpy.data.objects.remove(existing, do_unlink=True)
    for c in list(bpy.data.collections):
        if c.name != 'Collection': bpy.data.collections.remove(c)
    for mat in list(bpy.data.materials): bpy.data.materials.remove(mat)
    for image in list(bpy.data.images):
        if image.name not in ('Render Result', 'Viewer Node'): bpy.data.images.remove(image)
    PARTS = []
    random.seed(610533)
    AUTHOR = bpy.data.collections.new('AUTHORING | editable components')
    bpy.context.scene.collection.children.link(AUTHOR)
    MAT = bpy.data.materials.new(asset+' | existing shared salvage PBR')
    MAT.use_nodes = True
    MAT.use_backface_culling = True
    nodes = MAT.node_tree.nodes; links = MAT.node_tree.links
    bs = nodes.get('Principled BSDF')
    bs.inputs['Specular IOR Level'].default_value = .22
    for kind in ('albedo', 'orm', 'normal'):
        file = SHARED / TEX[kind]
        assert file.is_file(), file
        if file.resolve() != (RUNTIME/TEX[kind]).resolve(): shutil.copy2(file, RUNTIME/TEX[kind])
        tex = nodes.new('ShaderNodeTexImage'); tex.name = kind
        tex.image = bpy.data.images.load(str(file), check_existing=False)
        tex.image.colorspace_settings.name = 'sRGB' if kind == 'albedo' else 'Non-Color'
        tex.image.pack()
        tex.image.filepath = '//../../../assets/models/'+TEX[kind]
        for packed in tex.image.packed_files: packed.filepath = tex.image.filepath
        tex.extension = 'EXTEND'
        if kind == 'albedo': links.new(tex.outputs['Color'], bs.inputs['Base Color'])
        elif kind == 'orm':
            sep = nodes.new('ShaderNodeSeparateColor')
            links.new(tex.outputs['Color'], sep.inputs['Color'])
            links.new(sep.outputs['Green'], bs.inputs['Roughness'])
            links.new(sep.outputs['Blue'], bs.inputs['Metallic'])
        else:
            norm = nodes.new('ShaderNodeNormalMap'); norm.inputs['Strength'].default_value = .35
            links.new(tex.outputs['Color'], norm.inputs['Color']); links.new(norm.outputs['Normal'], bs.inputs['Normal'])

def finish(o, name, tile=0, bevel=0, smooth=False):
    o.name = name
    bpy.context.view_layer.objects.active = o
    o.select_set(True)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    if bevel:
        mod = o.modifiers.new('Small worn edge bevel', 'BEVEL')
        mod.width = min(bevel, min(o.dimensions)*.40); mod.segments = 1
        bpy.ops.object.modifier_apply(modifier=mod.name)
    bm = bmesh.new(); bm.from_mesh(o.data)
    bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces)); bm.to_mesh(o.data); bm.free()
    o.data.update(); o.data.materials.clear(); o.data.materials.append(MAT)
    uv = o.data.uv_layers.active or o.data.uv_layers.new(name='SalvageAtlas')
    uv.name = 'SalvageAtlas'
    lo = [min(v.co[k] for v in o.data.vertices) for k in range(3)]
    hi = [max(v.co[k] for v in o.data.vertices) for k in range(3)]
    offset = random.uniform(.025, .10)
    for face in o.data.polygons:
        face.material_index = 0
        face.use_smooth = smooth and len(face.vertices) == 4
        axis = max(range(3), key=lambda k: abs(face.normal[k])); ax = [k for k in range(3) if k != axis]
        d = max(.0001, max(hi[k]-lo[k] for k in ax))
        for li in face.loop_indices:
            v = o.data.vertices[o.data.loops[li].vertex_index].co
            q = [offset+(v[k]-lo[k])/d*.84 for k in ax]
            uv.data[li].uv = ((tile%4+q[0])/4, (3-tile//4+q[1])/4)
    for c in list(o.users_collection): c.objects.unlink(o)
    AUTHOR.objects.link(o); PARTS.append(o); o.select_set(False)
    return o

def mesh(name, vs, fs, tile=0, bevel=0, smooth=False):
    me = bpy.data.meshes.new(name); me.from_pydata(vs, [], fs); me.update()
    o = bpy.data.objects.new(name, me); bpy.context.collection.objects.link(o)
    return finish(o, name, tile, bevel, smooth)

def box(name, p, dims, tile=0, bevel=0, rot=(0,0,0)):
    bpy.ops.mesh.primitive_cube_add(size=1, location=p, rotation=rot)
    o = bpy.context.object; o.scale = dims
    return finish(o, name, tile, bevel)

def cyl(name, p, r, h, tile=2, n=8, rot=(0,0,0)):
    bpy.ops.mesh.primitive_cylinder_add(vertices=n, radius=r, depth=h, location=p, rotation=rot)
    return finish(bpy.context.object, name, tile, smooth=True)

def beam(name, a, b, r=.04, tile=2, n=6):
    a,b = Vector(a),Vector(b)
    o = cyl(name, (a+b)/2, r, (b-a).length, tile, n)
    o.rotation_euler = (b-a).to_track_quat('Z', 'Y').to_euler()
    return o

def squarebeam(name, a, b, w=.08, d=.10, tile=1):
    a,b = Vector(a),Vector(b)
    o = box(name, (a+b)/2, (w,d,(b-a).length), tile)
    o.rotation_euler = (b-a).to_track_quat('Z', 'Y').to_euler()
    return o

def section(name, a, b, width=.18, depth=.20, thick=.045, tile=1):
    # Actual open I profile; side slots catch light and remain negative space.
    w,h,t = width/2,depth/2,thick/2
    outline = [(-w,-h),(w,-h),(w,-h+thick),(t,-h+thick),(t,h-thick),(w,h-thick),(w,h),(-w,h),(-w,h-thick),(-t,h-thick),(-t,-h+thick),(-w,-h+thick)]
    a,b=Vector(a),Vector(b); q=(b-a).to_track_quat('Z','Y'); count=len(outline)
    vs=[tuple(base+q@Vector((x,y,0))) for base in (a,b) for x,y in outline]
    fs=[tuple(reversed(range(count))),tuple(range(count,count*2))]
    fs += [(i,(i+1)%count,(i+1)%count+count,i+count) for i in range(count)]
    return mesh(name,vs,fs,tile)

def lathe(name, p, profile, tile=8, n=8, axis='Z'):
    vs=[]
    for z,r in profile:
        for i in range(n):
            v=Vector((r*math.cos(2*PI*i/n), r*math.sin(2*PI*i/n), z))
            if axis=='X': v=Vector((v.z,v.y,v.x))
            if axis=='Y': v=Vector((v.x,v.z,v.y))
            vs.append(tuple(Vector(p)+v))
    fs=[(j*n+i,j*n+(i+1)%n,(j+1)*n+(i+1)%n,(j+1)*n+i) for j in range(len(profile)-1) for i in range(n)]
    fs += [tuple(reversed(range(n))),tuple(range((len(profile)-1)*n,len(profile)*n))]
    return mesh(name,vs,fs,tile,smooth=True)

def insulator(name,x,y,z,h=.63,r=.16,ribs=4,tile=8):
    # Porcelain sheds are actual tapered geometry, not painted horizontal lines.
    profile=[(0,r*.60)]
    for i in range(ribs):
        zz=.045+i*(h-.09)/ribs
        profile.extend([(zz,r*.59),(zz+.025,r),(zz+.075,r*.68)])
    profile.extend([(h-.025,r*.48),(h,r*.46)])
    return lathe(name,(x,y,z),profile,tile,8)

def pipe(name,points,r=.035,tile=6,n=6):
    vs=[]; points=[Vector(p) for p in points]
    for i,p in enumerate(points):
        axis=(points[min(i+1,len(points)-1)]-points[max(i-1,0)]).normalized()
        ref=Vector((0,0,1)) if abs(axis.z)<.9 else Vector((1,0,0))
        u=axis.cross(ref).normalized();v=axis.cross(u)
        vs += [tuple(p+r*(u*math.cos(2*PI*j/n)+v*math.sin(2*PI*j/n))) for j in range(n)]
    fs=[(i*n+j,i*n+(j+1)%n,(i+1)*n+(j+1)%n,(i+1)*n+j) for i in range(len(points)-1) for j in range(n)]
    fs += [tuple(reversed(range(n))),tuple(range((len(points)-1)*n,len(points)*n))]
    return mesh(name,vs,fs,tile,smooth=True)

def slab():
    # Same inherited 4.2 x 3.5 metre footprint; chipped corners shorten the radius.
    outline=[(-2.1,-1.43),(-1.85,-1.75),(1.83,-1.75),(2.1,-1.48),(2.1,1.52),(1.82,1.75),(-1.92,1.75),(-2.1,1.49)]
    n=len(outline); vs=[(x,y,z) for z in (0,.20) for x,y in outline]
    fs=[tuple(reversed(range(n))),tuple(range(n,2*n))]+[(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)]
    mesh('Chipped municipal concrete pad',vs,fs,10)
    for points in [[(-2.03,-.52),(-1.49,-.56),(-1.17,-.86),(-.88,-.91)],[(.80,1.68),(.91,1.15),(1.31,.91),(2.06,.99)]]:
        for a,b in zip(points,points[1:]): squarebeam('Dark settled slab fracture',(a[0],a[1],.203),(b[0],b[1],.203),.025,.008,9)
    # Different sized fragments and crooked bricks communicate a salvage site.
    for i,(x,y) in enumerate([(-1.89,1.30),(-1.76,1.50),(1.89,-1.28),(1.66,-1.52),(-1.82,-1.35),(1.88,.49)]):
        box('Loose old masonry fragment '+str(i),(x,y,.27),(.18+random.random()*.13,.14+random.random()*.1,.12),12 if i%2 else 10,.014,(0,0,random.uniform(-.6,.6)))

def warning(name,x,y,z,w=.28,h=.31):
    # Original solid geometry lightning mark; no font, image, decal transparency.
    box(name+' worn amber plate',(x,y,z),(w,.022,h),15,.01)
    points=[(-.015,.12),(-.078,-.020),(-.016,-.012),(-.052,-.123),(.084,.046),(.017,.032)]
    mesh(name+' lightning pictogram',[(x+px,y-.014,z+pz) for px,pz in points],[(0,1,2,3,4,5)],9)

def control_box(x,y,z,w=.55,h=.83):
    box('Recovered civilian switch cabinet',(x,y,z),(w,.39,h),8,.025)
    box('Mismatched cabinet door',(x,y-.212,z),(w*.86,.027,h*.84),0,.015)
    for zz in [z-h*.28,z-h*.21,z-h*.14]: box('Cabinet ventilation slot',(x,y-.231,zz),(w*.48,.012,.026),9)
    beam('Cabinet latch',(x+w*.29,y-.247,z),(x+w*.29,y-.247,z+.13),.022,2)
    warning('Electricity hazard',x-w*.08,y-.245,z+h*.20,.24,.28)

def central_station():
    reset('central_station'); slab()
    # Tall open steel portals and three parallel copper rails form the silhouette.
    for y in (-.34,1.05):
        for x in (-1.55,1.55):
            box('Gantry cracked concrete shoe',(x,y,.32),(.48,.43,.26),10,.022)
            box('Gantry anchor plate',(x,y,.47),(.40,.34,.05),2)
            section('Weathered open I-section gantry column',(x,y,.49),(x,y,2.54),.19,.21,.045,1)
        section('Transmission gantry cross member',(-1.70,y,2.56),(1.70,y,2.56),.20,.22,.05,0)
        for x in (-1.55,1.55):
            squarebeam('Gantry knee reinforcement',(x,y,2.02),(x-math.copysign(.45,x),y,2.50),.073,.09,2)
    # Unequal side braces suggest an old repaired installation, not a weapon rack.
    squarebeam('Original side diagonal brace',(-1.55,-.34,.76),(-1.55,1.05,2.30),.065,.07,1)
    squarebeam('Replacement side diagonal brace',(1.55,-.34,.91),(1.55,1.05,2.28),.080,.07,2)
    for phase,x in enumerate((-.96,0,.96)):
        for y in (-.34,1.05):
            insulator('Ribbed bus support phase '+str(phase+1),x,y,2.68,.45,.18,3,8)
            cyl('Bus clamp socket',(x,y,3.145),.13,.06,2,8)
        beam('Copper transmission busbar phase '+str(phase+1),(x,-.80,3.20),(x,1.39,3.20),.058,7,8)
        box('Bus expansion splice',(x,.47,3.20),(.17,.28,.10),2)
        # Three visibly raised disconnect blades, with hinge and separated jaw.
        box('Disconnector hinge bracket',(x,-.76,3.20),(.24,.17,.14),2)
        squarebeam('Raised air-break disconnect blade',(x,-.81,3.23),(x,-1.34,3.73),.075,.085,7)
        box('Open contact jaw',(x,-.43,2.57),(.18,.24,.12),2)
        insulator('Lower switch terminal porcelain',x,-.43,1.89,.63,.20,4,8)
        box('Switch support plinth',(x,-.43,1.17),(.23,.25,1.43),0,.012)
        pipe('Switch operating linkage',[(x,-.50,.37),(x,-.50,1.09),(x,-.42,1.76)],.023,2)
    section('Switch common support channel',(-1.45,-.43,.53),(1.43,-.43,.53),.14,.18,.04,1)
    control_box(-.52,.38,.80,.66,.98)
    for x in (-.71,-.34): box('Cabinet salvaged standoff',(x,.38,.29),(.08,.17,.18),1)
    pipe('Cabinet exposed control cable',[(-.51,.38,.33),(-.47,.64,.24),(.66,.73,.24),(1.48,.78,.31),(1.51,.78,.93)],.038,6)
    # Broken brick service enclosure occupies one rear corner; no enclosing shed.
    for row in range(4):
        for col in range(4 if row<2 else 2):
            box('Ruined control-house brick',( -.81+col*.34+(row%2)*.12,1.49,.32+row*.22),(.32,.27,.21),12,0)
    box('Salvaged control-house coping',(-.42,1.49,1.06),(.94,.32,.12),10,.02,(0,.06,0))
    export('central_station')

def substation():
    reset('substation'); slab()
    # A solid oil transformer mass with two broad fin banks; no gantry or shed.
    box('Old containment well shadow',(0,.12,.212),(3.28,2.48,.018),9)
    for y in (-1.16,1.41): box('Broken containment curb',(0,y,.32),(3.4,.17,.24),10,.015)
    for x in (-1.64,1.64): box('Containment side curb',(x,.10,.30),(.17,2.37,.20),10,.015)
    for x in (-.49,.49): section('Transformer raised skid',(x,-.97,.43),(x,1.12,.43),.19,.23,.045,1)
    box('Oil transformer chamfered main tank',(0,.15,1.20),(1.65,1.67,1.43),0,.12)
    box('Heavy tank base seam',(0,.15,.56),(1.74,1.76,.12),1,.015)
    box('Tank wide bolted lid',(0,.15,1.94),(1.86,1.86,.17),0,.045)
    # Eight large radial fins per bank, each with chamfered vertical corners.
    for side in (-1,1):
        for i in range(8):
            y=-.73+i*.235
            box('Radiator plate bank '+str(side)+' fin '+str(i),(side*1.15,y,1.16),(.64,.061,1.14),0 if i%3 else 1,.012)
        for z in (.70,1.63):
            beam('Radiator horizontal header',(side*1.14,-.86,z),(side*1.14,1.00,z),.081,0,8)
            pipe('Bent radiator return pipe',[(side*.74,.69,z),(side*.91,.69,z),(side*1.14,.69,z-.07 if z>1 else z+.07)],.071,1,8)
    for i,x in enumerate((-.58,0,.58)):
        cyl('Transformer high-voltage bushing collar',(x,-.30,2.07),.20,.13,2,10)
        insulator('Transformer tall porcelain bushing '+str(i+1),x,-.30,2.13,.71,.20,5,8)
        beam('Bushing copper terminal',(x,-.30,2.84),(x,-.30,2.98),.052,7)
        # Broad arcing leads slope towards the terminal box, readable in silhouette.
        pipe('Repaired low-voltage cable '+str(i+1),[(x,-.30,2.98),(x,-.70,2.85),(x,-.99,2.39),(x,-1.04,1.25)],.029,6)
    # Horizontal conservator is visually unmistakable from the central switchyard.
    for x in (-.54,.54): squarebeam('Conservator support bracket',(x,.78,1.99),(x,.78,2.36),.09,.09,1)
    lathe('Rounded oil conservator vessel',(0,.82,2.49),[(-.90,.16),(-.83,.27),(-.71,.31),(.71,.31),(.83,.27),(.90,.16)],0,12,'X')
    for x in (-.59,.59): lathe('Conservator replacement retaining band',(x,.82,2.49),[(-.027,.318),(.027,.318)],1,12,'X')
    pipe('Conservator oil return',[(.68,.82,2.31),(.81,.89,2.17),(.78,.92,1.86)],.049,2,8)
    cyl('Oil filling capped neck',(.26,.82,2.82),.087,.12,2,8)
    control_box(.02,-1.02,1.02,.89,.71)
    box('Tank faded municipal identification plate',(0,-.708,1.43),(.61,.027,.29),8,.012)
    for x in (-.21,0,.21): box('Identification stamped bars',(x,-.726,1.43),(.071,.012,.14),0)
    # Dented patch and a replacement diagonal strap tell a civilian repair story.
    box('Riveted rust repair patch',(.59,-.711,.80),(.33,.03,.38),1,.007,(0,0,.04))
    for x in (.47,.72):
        for z in (.67,.93): beam('Retained tank patch fastener',(x,-.728,z),(x,-.753,z),.025,2,6)
    for x in (-.80,.80):
        beam('Grounding riser',(x,.97,.44),(x,.97,1.43),.022,7)
    pipe('Loose service cable on pad',[(.78,-1.43,.25),(1.01,-1.53,.25),(1.37,-1.42,.25),(1.40,-1.23,.25),(1.16,-1.16,.25),(.91,-1.28,.25)],.037,6)
    export('substation')

def externalize_glb(file):
    """Remove embedded texture bytes and reference the existing shared atlas.

    Geometry bufferViews are repacked rather than retaining unreachable image
    payloads. Material texture roles, never exporter-generated names, are used.
    """
    data=file.read_bytes(); magic,version,total=struct.unpack_from('<III',data,0)
    assert magic==0x46546C67 and version==2 and total==len(data)
    jl,jt=struct.unpack_from('<II',data,12); doc=json.loads(data[20:20+jl]); off=20+jl
    bl,bt=struct.unpack_from('<II',data,off); binary=data[off+8:off+8+bl]
    mat=doc['materials'][0]; pbr=mat['pbrMetallicRoughness']
    roles={'albedo':pbr['baseColorTexture'],'orm':pbr['metallicRoughnessTexture'],'normal':mat['normalTexture']}
    sources={doc['textures'][ref['index']]['source']:TEX[kind] for kind,ref in roles.items()}
    assert len(sources)==3
    image_views={image['bufferView'] for image in doc['images'] if 'bufferView' in image}
    packed=bytearray(); new_views=[]; mapping={}
    for old,view in enumerate(doc['bufferViews']):
        if old in image_views: continue
        while len(packed)%4: packed.append(0)
        new=dict(view); new['byteOffset']=len(packed)
        packed.extend(binary[view.get('byteOffset',0):view.get('byteOffset',0)+view['byteLength']])
        mapping[old]=len(new_views); new_views.append(new)
    for accessor in doc['accessors']:
        if 'bufferView' in accessor: accessor['bufferView']=mapping[accessor['bufferView']]
    doc['bufferViews']=new_views
    doc['images']=[{'uri':sources[i], 'name':Path(sources[i]).stem} for i in range(len(doc['images']))]
    doc['buffers']=[{'byteLength':len(packed)}]
    doc.get('asset',{})['copyright']='Original RECLAMATION geometry; existing project salvage atlas. See provenance; no license grant asserted.'
    while len(packed)%4: packed.append(0)
    jb=json.dumps(doc,separators=(',',':')).encode(); jb+=b' '*((-len(jb))%4)
    out=struct.pack('<III',0x46546C67,2,12+8+len(jb)+8+len(packed))+struct.pack('<II',len(jb),0x4E4F534A)+jb+struct.pack('<II',len(packed),0x004E4942)+packed
    file.write_bytes(out)

def export(name):
    col=bpy.data.collections.new('EXPORT_MASTER | one runtime surface')
    bpy.context.scene.collection.children.link(col)
    copies=[]
    for o in PARTS:
        c=o.copy();c.data=o.data.copy();col.objects.link(c);copies.append(c)
    bpy.ops.object.select_all(action='DESELECT')
    for o in copies:o.select_set(True)
    bpy.context.view_layer.objects.active=copies[0];bpy.ops.object.join();master=bpy.context.object;master.name=name
    bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
    master.data.materials.clear();master.data.materials.append(MAT)
    for f in master.data.polygons:f.material_index=0
    tri=master.modifiers.new('Runtime triangles','TRIANGULATE');bpy.ops.object.modifier_apply(modifier=tri.name)
    lo=[min(v.co[k] for v in master.data.vertices) for k in range(3)]; hi=[max(v.co[k] for v in master.data.vertices) for k in range(3)]
    radius=max(math.hypot(v.co.x,v.co.y) for v in master.data.vertices)
    triangles=len(master.data.polygons)
    assert triangles<=4000,(name,triangles)
    assert radius<3.0,(name,radius)
    assert lo[0]>=-2.11 and hi[0]<=2.11 and lo[1]>=-1.76 and hi[1]<=1.76,(lo,hi)
    assert abs(lo[2])<.001 and hi[2]<4.0,(lo,hi)
    master['provenance']='Original RECLAMATION civilian power facility, 2026-10-05. Existing salvage atlas reused unchanged.'
    master['contract']='Visual only. One PBR surface; metres; Godot Y up and ground Y=0. No collision, scripts, animation or lights.'
    bpy.ops.export_scene.gltf(filepath=str(RUNTIME/(name+'.glb')),export_format='GLB',use_selection=True,export_texcoords=True,export_normals=True,export_materials='EXPORT',export_image_format='AUTO',export_yup=True,export_apply=True,export_extras=True)
    externalize_glb(RUNTIME/(name+'.glb'))
    AUTHOR.hide_render=True;AUTHOR.hide_viewport=True
    scene=bpy.context.scene;scene.unit_settings.system='METRIC'
    scene['authoring']='Hide EXPORT_MASTER and unhide AUTHORING to edit named pieces. Preserve manual edits before regeneration.'
    scene['provenance']='See ../PROVENANCE.md. New original asset; not an exact recovered historical model.'
    scene['runtime_material']='External URI textures refer to the existing ammo_workshop_salvage maps in assets/models.'
    # Public source must not retain machine-specific paths in Blender UI metadata.
    for screen in bpy.data.screens:
        for area in screen.areas:
            for space in area.spaces:
                if space.type=='FILE_BROWSER' and space.params:
                    space.params.directory=b'//';space.params.filename=''
    bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'source'/(name+'.blend')))
    REPORTS[name]={'triangles':triangles,'components':len(PARTS),'surface_count':1,'material_count':1,'ground_radius':radius,'godot_aabb_min':[lo[0],lo[2],-hi[1]],'godot_aabb_max':[hi[0],hi[2],-lo[1]],'runtime_bytes':(RUNTIME/(name+'.glb')).stat().st_size,'texture_uris':TEX,'embedded_image_bytes':0}
    print('POWER_ASSET',json.dumps(REPORTS[name]))

central_station()
substation()
(ROOT/'reports/geometry_report.json').write_text(json.dumps(REPORTS,indent=2)+'\n')
print('Built two original power facilities.')
