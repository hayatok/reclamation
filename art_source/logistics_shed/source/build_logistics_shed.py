"""Original RECLAMATION logistics-shed pair, October 2026.

Run: blender --background --threads 2 --python source/build_logistics_shed.py
No downloaded assets. Uses the original repository's settlement atlas, unchanged.
Metres; Blender +Y is forward, exported as glTF/Godot -Z. Ground origin.
The opposite end is also a loading bay, readable from the normal +X/+Z camera.
"""
import bpy, bmesh, math, random, json, struct, hashlib, argparse, sys
from pathlib import Path
from mathutils import Vector

ROOT = Path(__file__).resolve().parent.parent
ASSETS = ROOT / 'assets'
REVIEW = ROOT / 'review'
SOURCE = ROOT / 'source'
parser=argparse.ArgumentParser(description=__doc__)
parser.add_argument('--atlas-dir',type=Path,default=ASSETS,help='Directory containing the three original barracks_settlement PNG maps')
parser.add_argument('--output-dir',type=Path,default=ROOT,help='Output package root, containing assets/source/review')
args=parser.parse_args(sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else [])
ATLAS=args.atlas_dir.resolve()
ROOT=args.output_dir.resolve()
ASSETS,REVIEW,SOURCE=ROOT/'assets',ROOT/'review',ROOT/'source'
for folder in [ASSETS,REVIEW,SOURCE]:folder.mkdir(parents=True,exist_ok=True)
random.seed(20261009)
parts = []
stats = {}

def reset():
    global parts
    for obj in list(bpy.data.objects):bpy.data.objects.remove(obj,do_unlink=True)
    parts = []

def material():
    mat = bpy.data.materials.get('RECLAMATION | reclaimed civilian logistics')
    if mat: return mat
    mat = bpy.data.materials.new('RECLAMATION | reclaimed civilian logistics')
    mat.use_nodes = True
    n, links = mat.node_tree.nodes, mat.node_tree.links
    bs = n.get('Principled BSDF')
    for key, space in [('albedo','sRGB'), ('orm','Non-Color'), ('normal','Non-Color')]:
        tex = n.new('ShaderNodeTexImage')
        tex.name = key
        tex.image = bpy.data.images.load(str(ATLAS / ('barracks_settlement_'+key+'.png')), check_existing=True)
        tex.image.colorspace_settings.name = space
    links.new(n['albedo'].outputs['Color'], bs.inputs['Base Color'])
    split = n.new('ShaderNodeSeparateColor')
    links.new(n['orm'].outputs['Color'], split.inputs[0])
    links.new(split.outputs['Green'], bs.inputs['Roughness'])
    links.new(split.outputs['Blue'], bs.inputs['Metallic'])
    normal = n.new('ShaderNodeNormalMap')
    normal.inputs['Strength'].default_value = .30
    links.new(n['normal'].outputs['Color'], normal.inputs['Color'])
    links.new(normal.outputs[0], bs.inputs['Normal'])
    bs.inputs['Roughness'].default_value = .90
    return mat

def finish(o, name, tile, bevel=0):
    o.name = name
    bpy.context.view_layer.objects.active = o
    o.select_set(True)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    bm = bmesh.new(); bm.from_mesh(o.data)
    bmesh.ops.remove_doubles(bm, verts=list(bm.verts), dist=.000001)
    bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
    bm.to_mesh(o.data); bm.free()
    if bevel:
        mod = o.modifiers.new('Small worn edge', 'BEVEL')
        mod.width = bevel; mod.segments = 1
        bpy.ops.object.modifier_apply(modifier=mod.name)
    o.data.materials.clear(); o.data.materials.append(material())
    o.data.update()
    uv = o.data.uv_layers.active or o.data.uv_layers.new(name='UVMap')
    mins = [min(v.co[k] for v in o.data.vertices) for k in range(3)]
    maxs = [max(v.co[k] for v in o.data.vertices) for k in range(3)]
    off = random.random()*.06
    for f in o.data.polygons:
        axis = max(range(3), key=lambda k: abs(f.normal[k]))
        axes = [k for k in range(3) if k != axis]
        for li in f.loop_indices:
            v = o.data.vertices[o.data.loops[li].vertex_index].co
            # Cover the same authored atlas swatch; individual proportions do not bleed.
            q = [.06+off+.82*(v[k]-mins[k])/max(maxs[k]-mins[k],.001) for k in axes]
            uv.data[li].uv = ((tile%4+q[0])/4, (3-tile//4+q[1])/4)
    parts.append(o); o.select_set(False)
    return o

def mesh(name, verts, faces, tile=0, bevel=0):
    m = bpy.data.meshes.new(name)
    m.from_pydata(verts, [], faces); m.update()
    o = bpy.data.objects.new(name, m); bpy.context.collection.objects.link(o)
    return finish(o, name, tile, bevel)

def box(name, loc, dims, tile=0, bevel=0, rot=(0,0,0)):
    bpy.ops.mesh.primitive_cube_add(size=1, location=loc, rotation=rot)
    o = bpy.context.object; o.scale = dims
    return finish(o, name, tile, bevel)

def beam(name, a, b, width=.09, depth=None, tile=1, bevel=0):
    a,b = Vector(a),Vector(b)
    o = box(name, (a+b)/2, (width,depth or width,(b-a).length), tile, bevel)
    o.rotation_euler = (b-a).to_track_quat('Z','Y').to_euler()
    return o

def cylinder(name, loc, radius, height, tile=6, sides=10, rot=(0,0,0)):
    bpy.ops.mesh.primitive_cylinder_add(vertices=sides, radius=radius, depth=height, location=loc, rotation=rot)
    return finish(bpy.context.object, name, tile)

def slab(name, polygon, bottom, top, tile=10):
    n=len(polygon)
    verts=[(x,y,z) for z in (bottom,top) for x,y in polygon]
    faces=[tuple(range(n-1,-1,-1)), tuple(range(n,n*2))]
    faces += [(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)]
    return mesh(name,verts,faces,tile)

def roof_z(x,y):
    # Low, asymmetric industrial gable. Not a domestic pitched cottage.
    return 2.74 - (abs(x+.32)*(.29 if x < -.32 else .31))

def roof_sheet(name,x0,x1,y0,y1,tile=0,broken=False,sag=0,zoffset=0):
    # Geometric corrugation is intentionally broad enough to survive the RTS camera.
    steps=max(4,round((x1-x0)/.13)*2)
    rows=3 if broken else 1
    verts=[]
    for j in range(rows+1):
        y=y0+(y1-y0)*j/rows
        for i in range(steps+1):
            x=x0+(x1-x0)*i/steps
            yy=y
            if broken and j==0:
                yy += [0,.08,-.035,.12,-.07,.035][i%6]
            z=roof_z(x,yy) + (.028 if i%2 else 0) + zoffset
            if sag: z-=sag*math.sin(math.pi*(x-x0)/(x1-x0))*math.sin(math.pi*j/max(rows,1))
            verts.append((x,yy,z))
    n=steps+1
    faces=[(j*n+i,j*n+i+1,(j+1)*n+i+1,(j+1)*n+i) for j in range(rows) for i in range(steps)]
    o=mesh(name,verts,faces,tile)
    # Double-sided material keeps ragged sheet undersides, no hollow-cube roof bulk.
    return o

def wall_sheet(name,x,y0,y1,z0,z1,tile=0,broken=False):
    count=max(4,round((y1-y0)/.14)*2)
    verts=[]
    for row,z in enumerate((z0,z1)):
        for i in range(count+1):
            y=y0+(y1-y0)*i/count
            zz=z+(0 if not broken or row==0 else [.03,-.08,.07,-.04,.01][i%5])
            verts.append((x+(.025 if i%2 else 0),y,zz))
    n=count+1
    return mesh(name,verts,[(i,i+1,n+i+1,n+i) for i in range(count)],tile)

def tarp(name,x0,x1,y0,y1):
    nx,ny=6,5
    verts=[]
    for j in range(ny+1):
        t=j/ny; y=y0+(y1-y0)*t
        for i in range(nx+1):
            s=i/nx; x=x0+(x1-x0)*s
            z=roof_z(x,y)+.092-.024*math.sin(math.pi*s)*math.sin(math.pi*t)
            verts.append((x,y,z))
    faces=[]
    for j in range(ny):
        for i in range(nx):
            a=j*(nx+1)+i; faces.append((a,a+1,a+nx+2,a+nx+1))
    mesh(name,verts,faces,4)
    for a,b in [((x0,y0),(x1,y0)),((x0,y1),(x1,y1)),((x0,y0),(x0,y1)),((x1,y0),(x1,y1))]:
        beam('Tarp doubled stitched hem',(a[0],a[1],roof_z(*a)+.098),(b[0],b[1],roof_z(*b)+.098),.025,.025,4)
    # Tie-downs cross onto neighboring sound sheet and fasten to the eave.
    for y in [y0+.10,y1-.10]:
        beam('Salvaged timber tarp tie',(x1-.09,y,roof_z(x1-.09,y)+.115),(1.67,y,roof_z(1.67,y)+.045),.045,.025,3)

def pallet(name,x,y,z,w=.73,d=.65,broken=False):
    for xx in [-w*.34,w*.34]:box(name+' bearer',(x+xx,y,z+.046),(.095,d,.09),3)
    for i in range(5):
        if broken and i==2:continue
        box(name+' plank',(x-w*.4+i*w*.2,y,z+.116),(w*.18,d,.052),3,.003,rot=(0,0,.03 if broken and i==0 else 0))

def crate(name,x,y,z,w=.66,d=.62,h=.55,tilt=0):
    # Solid contents with coarse seams and recognizable timber battens.
    box(name+' wooden body',(x,y,z+h/2),(w,d,h),3,.013,rot=(0,0,tilt))
    for side in [-1,1]:
        yy=y+side*(d/2+.014)
        for zz in [z+.06,z+h-.06]:box(name+' horizontal batten',(x,yy,zz),(w+.025,.035,.075),3,.002)
        for xx in [x-w*.36,x+w*.36]:box(name+' corner strap',(xx,yy,z+h/2),(.042,.040,h+.012),0)
    for xx in [x-w*.36,x+w*.36]:box(name+' top strap',(xx,y,z+h+.015),(.042,d,.025),0)
    for side in [-1,1]:
        box(name+' faded cargo panel',(x,y+side*(d/2+.038),z+h*.53),(w*.30,.009,h*.23),8)

def sack(name,x,y,z,scale=(.58,.42,.32)):
    # Low-poly bound provisions, with visibly softened silhouette.
    bpy.ops.mesh.primitive_uv_sphere_add(segments=10,ring_count=5,radius=.5,location=(x,y,z))
    o=bpy.context.object;o.scale=scale
    finish(o,name,4)
    beam(name+' binding',(x-scale[0]*.30,y,z+scale[2]*.40),(x+scale[0]*.30,y,z+scale[2]*.40),.025,.018,3)

def drum(name,x,y,z):
    cylinder(name,(x,y,z+.33),.22,.66,0,12)
    for h in [.13,.53]:cylinder(name+' hoop',(x,y,z+h),.23,.038,1,12)
    cylinder(name+' bung',(x+.07,y,z+.67),.035,.015,6,8)

def foundation():
    slab('Old chipped loading slab',[(-1.80,-1.39),(-1.61,-1.60),(1.52,-1.60),(1.80,-1.34),(1.78,1.43),(1.59,1.60),(-1.64,1.60),(-1.80,1.34)],0,.085,10)
    slab('Stained warehouse floor',[(-1.49,-1.40),(1.49,-1.40),(1.49,1.37),(-1.49,1.37)],.087,.145,10)
    for side in [-1,1]:
        for x in [-1.37,1.37]:box('Old masonry pier',(x,side*1.23,.18),(.24,.29,.18),10,.014)
    # Empty pale threshold gives a clear usable center lane.
    for y in [-1.41,1.43]:box('Worn loading threshold',(0,y,.141),(1.55,.19,.08),10,.01)

def frame(abandoned):
    for x in [-1.40,1.40]:
        for y in [-1.23,1.23]:
            z=roof_z(x,y)-.065
            if abandoned and x>0 and y<0:
                beam('Bent rusted visible corner post',(x,y,.25),(x-.075,y+.04,z-.12),.14,.13,1)
            else:beam('Surviving steel corner post',(x,y,.23),(x,y,z),.14,.13,1)
        beam('Longitudinal warehouse eave',(x,-1.37,roof_z(x,0)-.08),(x,1.38,roof_z(x,0)-.08),.12,.12,1)
    for y in [-1.27,1.27]:
        beam('Wide loading-bay header',(-1.47,y,2.05),(1.47,y,2.05),.15,.15,1)
        beam('Gable structural tie',(-1.45,y,2.08),(-.32,y,2.69),.09,.08,1)
        beam('Gable structural tie',(-.32,y,2.69),(1.45,y,2.08),.09,.08,1)
        beam('Gable vertical brace',(-.32,y,2.09),(-.32,y,2.68),.065,.065,1)
    beam('Roof ridge rail',(-.32,-1.48,2.70),(-.32,1.47,2.70),.09,.09,1)
    # Four visible timber replacement joists; broken ones remain on the shell.
    for y in [-1.37,-.45,.50,1.38]:
        beam('Left half roof rafter',(-1.67,y,roof_z(-1.67,y)-.04),(-.32,y,2.70),.075,.08,3)
        if abandoned and y<0:
            beam('Snapped roof rafter',(-.32,y,2.70),(.33,y+.055,roof_z(.33,y)-.10),.080,.075,3)
            beam('Broken rafter remnant',(1.33,y,roof_z(1.33,y)-.08),(1.67,y,roof_z(1.67,y)-.05),.08,.075,3)
        else:beam('Reclaimed roof rafter',(-.32,y,2.70),(1.67,y,roof_z(1.67,y)-.04),.085,.08,3)
    # Short open braces support the shed without filling its loading apertures.
    for x in [-1.4,1.4]:
        for y in [-1.23,1.23]:
            beam('Timber knee support',(x,y,1.60),(x*.72,y,2.04),.09,.08,3)

def walls(abandoned):
    # Cargo shed: salvaged partial side skin, open through-loading at both ends.
    wall_sheet('Old slate side skin',-1.47,-1.28,1.31,.22,1.89,0,abandoned)
    wall_sheet('Short rust side patch',1.45,.31,1.27,.25,1.93,1,abandoned)
    wall_sheet('Visible loading side half wall',1.45,-1.29,.30,.24,.72 if not abandoned else .62,0,abandoned)
    for x in [-1.49,1.49]:
        box('Side wall lower timber batten',(x,.02,.45),(.055,2.64,.13),3)
    box('Side sheet high timber batten',(-1.49,.02,1.65),(.055,2.64,.11),3)
    # Narrow slatted wings preserve a genuinely wide, dark, open bay.
    for y in [-1.30,1.30]:
        for x in [-1.20,1.20]:
            for i in range(5):
                if abandoned and y<0 and x>0 and i>2:continue
                box('Bay weatherboard wing',(x,y,.42+i*.29),(.35,.055,.255),3,.003)

def roofs(abandoned):
    if abandoned:
        roof_sheet('Surviving oxide roof',-1.69,-.32,-1.49,1.49,1,False)
        roof_sheet('Ragged far roof remnant',-.32,1.69,.37,1.49,0,True,.07)
        roof_sheet('Torn eave fringe',1.35,1.69,-1.39,.37,1,True,.06)
        # Folded sheet in the roof opening catches the edge light and shows collapse.
        mesh('Peeled corrugated roof tongue',[(.0,.37,2.67),(.48,.33,2.55),(.52,-.15,2.15),(.05,-.24,2.21)],[(0,1,2,3)],1)
        # Broken ridge section is visible over the opening.
        beam('Bent ridge flashing',(-.34,-1.47,2.76),(-.16,-.82,2.84),.055,.055,1)
    else:
        roof_sheet('Reused oxide left roof',-1.69,-.32,-1.49,1.49,1)
        roof_sheet('Salvaged slate loading-bay roof',-.32,1.69,-1.49,.40,0)
        roof_sheet('Old grey far roof',-.32,1.69,.40,1.49,2)
        tarp('Broad tied canvas roof repair',-.23,1.20,-1.40,-.27)
        # Large slate patch overlaps the retained rusty plane, so repair reads as reuse.
        roof_sheet('Overlapping salvaged roof patch',-1.43,-.42,-.68,.60,0,zoffset=.045)
        for y in [-1.46,1.46]:
            beam('Repaired roof fascia',(-1.69,y,roof_z(-1.69,y)),(-.32,y,2.76),.070,.045,1)
            beam('Repaired roof fascia',(-.32,y,2.76),(1.69,y,roof_z(1.69,y)),.070,.045,1)
        beam('Reclaimed continuous ridge cap',(-.32,-1.51,2.78),(-.32,1.51,2.78),.11,.075,2)

def broken_stock():
    pallet('Broken shipping pallet',.75,-.87,.16,.75,.68,True)
    crate('Abandoned split crate',-.90,.65,.18,.72,.58,.60)
    # Large bowed boards close the two loading entries; no texture-only damage.
    for y in [-1.34,1.34]:
        beam('Boarded broken loading entry',(-1.02,y,.48),(1.02,y,1.69),.16,.072,3)
        beam('Boarded broken loading entry',(1.04,y,.49),(-.98,y,1.53),.18,.060,3)
        box('Loose closure plank',(-.19,y+.025,1.04),(1.83,.055,.16),3,.003,rot=(0,.02,-.075))
    for a,b in [((-.9,-.57,.18),(.64,.11,.27)),((.25,-1.10,.20),(.76,.72,.23)),((-.80,-.22,.18),(.17,-.87,.21))]:
        beam('Fallen rough timber',a,b,.14,.075,3)
    # Crumpled wall panel lies within the loading slab, visible through the hole.
    mesh('Collapsed rust sheet',[(.30,-1.06,.18),(1.30,-.94,.18),(1.12,-.58,.65),(.53,-.39,.54)],[(0,1,2,3)],1)
    for x,y,z,r in [(-1.2,-1.16,.14,.10),(1.37,-1.25,.15,.12),(.77,.07,.16,.09)]:
        bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1,radius=r,location=(x,y,z))
        finish(bpy.context.object,'Loose masonry fragment',10)

def repaired_stock():
    # Keep a clean .95 m center path and group supplies at the sides.
    pallet('Repaired near shipping pallet',-.90,-.76,.16,.78,.76)
    crate('Near shipping crate',-.90,-.76,.32,.71,.66,.59)
    crate('Upper near supply crate',-.94,-.75,.93,.58,.58,.47)
    pallet('Far shipping pallet',-.88,.65,.16,.80,.73)
    crate('Far shipping crate',-.88,.65,.32,.72,.66,.65)
    crate('Upper far provision crate',-.87,.65,.98,.54,.53,.41)
    pallet('Visible side stock pallet',1.00,-.42,.16,.62,.64)
    crate('Visible side transfer crate',1.00,-.44,.32,.59,.58,.53)
    sack('Canvas grain provision',1.01,-.44,1.015,(.56,.44,.31))
    drum('Salvaged water reserve',1.03,.56,.17)
    # Original civilian cargo pictogram, no military or branded signage.
    for y in [-1.355,1.355]:
        box('Reused loading-bay sign',(.05,y,1.985),(.62,.075,.31),0,.008)
        s=1 if y>0 else -1
        for x in [-.14,.24]:box('Cargo mark upright',(x,y+s*.046,1.985),(.036,.014,.19),8)
        for z in [1.897,2.071]:box('Cargo mark horizontal',(.05,y+s*.046,z),(.41,.014,.032),8)
        beam('Cargo mark diagonal',(-.12,y+s*.050,1.91),(.22,y+s*.050,2.059),.03,.012,8)

def export_asset(name):
    bpy.ops.object.select_all(action='DESELECT')
    authoring=bpy.data.collections.new('EDITABLE | '+name)
    bpy.context.scene.collection.children.link(authoring)
    copies=[]
    for o in parts:
        for c in list(o.users_collection):c.objects.unlink(o)
        authoring.objects.link(o)
        cp=o.copy();cp.data=o.data.copy();bpy.context.scene.collection.objects.link(cp);copies.append(cp)
    authoring.hide_viewport=True;authoring.hide_render=True
    for o in copies:o.select_set(True)
    bpy.context.view_layer.objects.active=copies[0]
    bpy.ops.object.join()
    hero=bpy.context.object;hero.name=name+'_LOD0'
    bpy.context.scene.cursor.location=(0,0,0)
    bpy.ops.object.origin_set(type='ORIGIN_CURSOR')
    bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
    tri=hero.modifiers.new('Deterministic export triangulation','TRIANGULATE')
    bpy.ops.object.modifier_apply(modifier=tri.name)
    hero.data.validate();hero.data.update()
    coords=[v.co for v in hero.data.vertices]
    mn=[min(v[k] for v in coords) for k in range(3)]
    mx=[max(v[k] for v in coords) for k in range(3)]
    tri_count=len(hero.data.polygons)
    assert tri_count<=5500,(name,tri_count)
    assert mn[2]>=-.00001 and mx[2]<=3.1,(name,mn,mx)
    assert mn[0]>=-1.80001 and mx[0]<=1.80001 and mn[1]>=-1.60001 and mx[1]<=1.60001,(name,mn,mx)
    stats[name]={'triangles':tri_count,'authoring_components':len(parts),'blender_bounds_min':mn,'blender_bounds_max':mx,'godot_bounds_min':[mn[0],mn[2],-mx[1]],'godot_bounds_max':[mx[0],mx[2],-mn[1]],'meshes':1,'materials':1,'primitives':1,'primary_forward':'-Z','texture_source':'original shared barracks_settlement atlas (unchanged)'}
    bpy.context.preferences.filepaths.save_version=0
    bpy.ops.file.pack_all()
    # Packed authoring files also retain portable, public-safe image paths.
    for image in bpy.data.images:
        if image.packed_file and 'barracks_settlement_' in image.name:
            image.filepath='//../assets/'+Path(image.filepath).name
    bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE/(name+'.blend')))
    bpy.ops.export_scene.gltf(filepath=str(ASSETS/(name+'.glb')),export_format='GLB',use_selection=True,export_texcoords=True,export_normals=True,export_materials='EXPORT',export_yup=True,export_tangents=True)
    externalize_textures(ASSETS/(name+'.glb'))
    print('ASSET_READY '+name+' '+json.dumps(stats[name]),flush=True)
    return hero

def externalize_textures(path):
    # Keep both meshes on the game's existing shared atlas; do not duplicate embedded PNGs.
    raw=path.read_bytes();jslen=struct.unpack_from('<I',raw,12)[0]
    doc=json.loads(raw[20:20+jslen]);binstart=20+jslen
    binlen=struct.unpack_from('<I',raw,binstart)[0];binary=raw[binstart+8:binstart+8+binlen]
    image_views={im['bufferView'] for im in doc.get('images',[]) if 'bufferView' in im}
    used=set()
    for a in doc.get('accessors',[]):
        if 'bufferView' in a:used.add(a['bufferView'])
    assert not image_views & used
    new_views=[];mapping={};newbin=bytearray()
    for i,v in enumerate(doc['bufferViews']):
        if i in image_views:continue
        while len(newbin)%4:newbin.append(0)
        off=v.get('byteOffset',0);length=v['byteLength'];vv=dict(v);vv['byteOffset']=len(newbin)
        newbin.extend(binary[off:off+length]);mapping[i]=len(new_views);new_views.append(vv)
    for a in doc['accessors']:
        if 'bufferView' in a:a['bufferView']=mapping[a['bufferView']]
    for im in doc.get('images',[]):
        nm=im.get('name','')
        key=next(k for k in ['albedo','normal','orm'] if k in nm)
        im.pop('bufferView',None);im['uri']='barracks_settlement_'+key+'.png'
    doc['bufferViews']=new_views
    while len(newbin)%4:newbin.append(0)
    doc['buffers'][0]['byteLength']=len(newbin)
    js=json.dumps(doc,separators=(',',':')).encode()
    while len(js)%4:js+=b' '
    total=12+8+len(js)+8+len(newbin)
    path.write_bytes(struct.pack('<III',0x46546c67,2,total)+struct.pack('<II',len(js),0x4e4f534a)+js+struct.pack('<II',len(newbin),0x004e4942)+newbin)

def render_asset(hero,name):
    scene=bpy.context.scene
    # Orthographic direction matches the actual gameplay camera (37,48,43).
    scene.render.engine='CYCLES'
    scene.cycles.samples=64;scene.cycles.use_denoising=False
    scene.render.resolution_x=384;scene.render.resolution_y=384;scene.render.resolution_percentage=100
    scene.render.image_settings.file_format='PNG';scene.render.image_settings.color_mode='RGBA'
    scene.render.film_transparent=True
    scene.world.color=(.24,.28,.30)
    scene.view_settings.view_transform='Standard'
    scene.view_settings.look='Medium High Contrast' if 'Medium High Contrast' in [i.identifier for i in scene.view_settings.bl_rna.properties['look'].enum_items] else 'None'
    scene.view_settings.exposure=0;scene.view_settings.gamma=1
    bpy.ops.object.camera_add(location=(7.4,-8.6,10.88))
    camera=bpy.context.object;camera.name='Review | normal gameplay direction'
    target=Vector((0,0,1.28));camera.rotation_euler=(target-camera.location).to_track_quat('-Z','Y').to_euler()
    camera.data.type='ORTHO';camera.data.ortho_scale=5.20;scene.camera=camera
    bpy.ops.object.light_add(type='AREA',location=(-3,-4,9))
    key=bpy.context.object;key.data.energy=600;key.data.shape='DISK';key.data.size=5
    key.rotation_euler=(Vector((0,0,1))-key.location).to_track_quat('-Z','Y').to_euler()
    bpy.ops.object.light_add(type='AREA',location=(5,1,5))
    fill=bpy.context.object;fill.data.energy=180;fill.data.size=4
    fill.rotation_euler=(Vector((0,0,1))-fill.location).to_track_quat('-Z','Y').to_euler()
    scene.render.filepath=str(REVIEW/(name+'_isolated.png'))
    bpy.ops.render.render(write_still=True)
    if name=='depot':
        scene.render.resolution_x=256;scene.render.resolution_y=256
        scene.render.filepath=str(ASSETS/'portrait_depot.png')
        bpy.ops.render.render(write_still=True)
    print('RENDER_READY '+name,flush=True)

def build(name,abandoned):
    reset();foundation();frame(abandoned);walls(abandoned);roofs(abandoned)
    broken_stock() if abandoned else repaired_stock()
    return export_asset(name)

if __name__=='__main__':
    # Both first-pass artifacts are exported before any review render begins.
    for name,abandoned in [('abandoned_depot',True),('depot',False)]:
        build(name,abandoned)
    (ROOT/'asset_stats.json').write_text(json.dumps(stats,indent=2)+'\n')
    for name in ['abandoned_depot','depot']:
        bpy.ops.wm.open_mainfile(filepath=str(SOURCE/(name+'.blend')))
        render_asset(bpy.data.objects[name+'_LOD0'],name)
    print('BUILD_FINISHED',flush=True)
