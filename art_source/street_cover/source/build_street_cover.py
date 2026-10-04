"""Original RECLAMATION street salvage geometry; Blender 4.3+.
Run: blender -b --python source/build_street_cover.py
No source meshes, textures, or scans from third parties.
"""
import bpy, math, random, json, pathlib, os
from mathutils import Vector
ROOT=pathlib.Path(__file__).resolve().parents[1]
random.seed(682911)
PI=math.pi
STATS={}

def clear():
    bpy.ops.object.select_all(action='SELECT'); bpy.ops.object.delete(use_global=False)

def material():
    m=bpy.data.materials.get('StreetSalvage_Atlas_PBR') or bpy.data.materials.new('StreetSalvage_Atlas_PBR')
    m.use_nodes=True; n=m.node_tree.nodes; n.clear(); l=m.node_tree.links
    out=n.new('ShaderNodeOutputMaterial'); out.location=(700,0)
    bs=n.new('ShaderNodeBsdfPrincipled'); bs.location=(390,0); l.new(bs.outputs['BSDF'],out.inputs['Surface'])
    for key,loc in [('albedo',(-560,220)),('orm',(-560,-100)),('normal',(-560,-410))]:
        t=n.new('ShaderNodeTexImage'); t.name='Street_'+key; t.location=loc
        t.image=bpy.data.images.load(str(ROOT/'assets'/f'street_salvage_{key}.png'),check_existing=True)
        if key!='albedo': t.image.colorspace_settings.name='Non-Color'
        t.image.pack(); t.interpolation='Linear'; t.extension='EXTEND'
        if key=='albedo': l.new(t.outputs['Color'],bs.inputs['Base Color'])
        elif key=='orm':
            s=n.new('ShaderNodeSeparateColor'); s.location=(-170,-100); l.new(t.outputs['Color'],s.inputs['Color'])
            l.new(s.outputs['Green'],bs.inputs['Roughness']); l.new(s.outputs['Blue'],bs.inputs['Metallic'])
        else:
            nn=n.new('ShaderNodeNormalMap'); nn.location=(-40,-360); nn.inputs['Strength'].default_value=.48
            l.new(t.outputs['Color'],nn.inputs['Color']); l.new(nn.outputs['Normal'],bs.inputs['Normal'])
    return m
MAT=None; PARTS=[]

def uv_atlas(ob, tiles):
    mesh=ob.data; mesh.update(); uv=mesh.uv_layers.new(name='SalvageAtlas')
    coords=[v.co for v in mesh.vertices]
    lo=[min(c[k] for c in coords) for k in range(3)]; hi=[max(c[k] for c in coords) for k in range(3)]
    delta=[max(.01,hi[k]-lo[k]) for k in range(3)]
    for p in mesh.polygons:
        tile=tiles[p.index] if isinstance(tiles,list) else tiles
        axis=max(range(3),key=lambda a:abs(p.normal[a])); ax=[k for k in range(3) if k!=axis]
        for li in p.loop_indices:
            c=mesh.vertices[mesh.loops[li].vertex_index].co
            u=.025+.95*(c[ax[0]]-lo[ax[0]])/delta[ax[0]]; v=.025+.95*(c[ax[1]]-lo[ax[1]])/delta[ax[1]]
            uv.data[li].uv=((tile%4+u)/4,1-(tile//4+v)/2)
    mesh.materials.append(MAT)

def mesh_obj(name,verts,faces,tiles):
    me=bpy.data.meshes.new(name+'_mesh'); me.from_pydata(verts,[],faces); me.update()
    ob=bpy.data.objects.new(name,me); bpy.context.collection.objects.link(ob); uv_atlas(ob,tiles); PARTS.append(ob); return ob

def bevel(ob,width=.02,segments=1):
    bpy.context.view_layer.objects.active=ob
    mod=ob.modifiers.new('Fracture_edge_catchlight','BEVEL'); mod.width=width; mod.segments=segments; mod.affect='EDGES'
    bpy.ops.object.modifier_apply(modifier=mod.name)

def chunk(name,pos,dim,tile=0,seed=None,rot=0.,damage=.14,bevel_w=.025,top_tile=None):
    rr=random.Random(seed or random.randint(0,1000000)); sx,sy,sz=dim
    # Chamfered irregular plan with displaced fracture corners; not a perfect cube.
    pts=[(-.5,-.34),(-.36,-.5),(.32,-.5),(.5,-.3),(.5,.3),(.30,.5),(-.31,.5),(-.5,.30)]
    if name=='Buckled_asphalt_road_plate':
        pts=[(-.5,-.34),(-.36,-.5),(-.05,-.48),(.09,-.26),(.19,-.48),(.32,-.5),(.5,-.30),(.46,.17),(.25,.15),(.35,.42),(.15,.5),(-.31,.5),(-.5,.30)]
    pts=[(x+rr.uniform(-damage,damage)*.30,y+rr.uniform(-damage,damage)*.30) for x,y in pts]
    verts=[]; n=len(pts)
    for layer in range(3):
        for i,(x,y) in enumerate(pts):
            fact=1.0 if layer==1 else rr.uniform(.85,1.0)
            z=(0 if layer==0 else (.72 if layer==1 else 1.0))*sz
            if layer==2: z+=rr.uniform(-damage,damage)*sz
            xx,yy=x*sx*fact,y*sy*fact
            verts.append((pos[0]+xx*math.cos(rot)-yy*math.sin(rot),pos[1]+xx*math.sin(rot)+yy*math.cos(rot),pos[2]+z))
    faces=[]; tiles=[]
    for layer in range(2):
        for i in range(n):
            faces.append((layer*n+i,layer*n+(i+1)%n,(layer+1)*n+(i+1)%n,(layer+1)*n+i)); tiles.append(tile if layer==0 else (top_tile if top_tile is not None else 1 if tile==0 else tile))
    faces.append(tuple(reversed(range(n)))); tiles.append(tile)
    # Top polygon fan makes a broad irregular fractured surface, not micro-detail.
    center=tuple(sum(verts[2*n+j][k] for j in range(n))/n for k in range(3)); verts.append(center)
    for i in range(n): faces.append((2*n+i,2*n+(i+1)%n,3*n)); tiles.append(top_tile if top_tile is not None else tile)
    ob=mesh_obj(name,verts,faces,tiles)
    if bevel_w: bevel(ob,bevel_w)
    return ob

def tube(name,x0,x1,y,z,r=.44,thick=.055,n=40,rings=7,tile=3,split=False,seed=1):
    rr=random.Random(seed); verts=[]; faces=[]; tiles=[]
    j0=min(.16,(x1-x0)*.09); j1=min(.22,(x1-x0)*.1)
    jag0=[rr.uniform(-j0,j0) for _ in range(n)]; jag1=[rr.uniform(-j1,j1) for _ in range(n)]
    for surface in range(2):
        for j in range(rings):
            t=j/(rings-1)
            for i in range(n):
                a=2*PI*i/n
                xx=x0+(x1-x0)*t+(jag0[i] if j==0 else jag1[i] if j==rings-1 else .015*math.sin(i*3+j))
                radius=r-(thick if surface else 0)+.014*math.sin(i*2+j*.8)
                if split and j>rings-3: radius+=.09*max(0,math.sin(a))
                verts.append((xx,y+math.cos(a)*radius,z+math.sin(a)*radius))
    def idx(s,j,i):return s*rings*n+j*n+i%n
    def present(j,i):
        # Wide missing upper shell with an asymmetrical tear on the middle barrel.
        return not (split and 3<=i<=13 and j>=1)
    for s in range(2):
        for j in range(rings-1):
            for i in range(n):
                if not present(j,i):continue
                f=(idx(s,j,i),idx(s,j,i+1),idx(s,j+1,i+1),idx(s,j+1,i))
                faces.append(f[::-1] if s else f); tiles.append(5 if s else tile)
    for j in (0,rings-1):
        for i in range(n):
            if not present(0 if j==0 else rings-2,i): continue
            endface=(idx(0,j,i),idx(0,j,i+1),idx(1,j,i+1),idx(1,j,i))
            faces.append(endface[::-1] if j==0 else endface); tiles.append(4)
    # Exposed metal thickness along all shell cut boundaries.
    if split:
        for j in range(rings-1):
            for i in range(n):
                if present(j,i) and not present(j,(i+1)%n):
                    k=i+1; faces.append((idx(0,j,k),idx(0,j+1,k),idx(1,j+1,k),idx(1,j,k))); tiles.append(4)
                if not present(j,i) and present(j,(i+1)%n):
                    k=i+1; faces.append((idx(0,j,k),idx(1,j,k),idx(1,j+1,k),idx(0,j+1,k))); tiles.append(4)
        for i in range(n):
            if present(0,i) and not present(1,i): faces.append((idx(0,1,i),idx(1,1,i),idx(1,1,i+1),idx(0,1,i+1))); tiles.append(4)
    ob=mesh_obj(name,verts,faces,tiles)
    for p in ob.data.polygons:p.use_smooth= p.index < 2*(rings-1)*n and tiles[p.index] in (3,5)
    return ob

def cyl_between(name,a,b,r,tile=6,n=8):
    va,vb=Vector(a),Vector(b); axis=(vb-va).normalized(); ref=Vector((0,0,1)) if abs(axis.z)<.9 else Vector((0,1,0)); u=axis.cross(ref).normalized(); v=axis.cross(u).normalized()
    vs=[]
    for p in (va,vb):
        for i in range(n):vs.append(tuple(p+r*(math.cos(2*PI*i/n)*u+math.sin(2*PI*i/n)*v)))
    fs=[tuple(reversed(range(n))),tuple(range(n,n*2))]+[(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)]
    return mesh_obj(name,vs,fs,tile)

def collar(x,y,z,r=.50):
    # Raised weathered coupling has a thick visible lip and six retained bolt heads.
    tube('Heavy_cast_coupling',x-.12,x+.12,y,z,r,.11,n=32,rings=2,tile=6,seed=int(abs(x)*100))
    for i in range(8):
        a=2*PI*i/8+.2
        cyl_between('Coupling_hex_bolt',(x-.16,y+math.cos(a)*r*.96,z+math.sin(a)*r*.96),(x-.11,y+math.cos(a)*r*.96,z+math.sin(a)*r*.96),.041,4,n=6)

def normalize(bounds):
    # Blender X length/Y width/Z up -> glTF and Godot X length/Y up/Z width.
    L,W,H=bounds
    coords=[v.co for ob in PARTS for v in ob.data.vertices]
    lo=[min(c[k] for c in coords) for k in range(3)]; hi=[max(c[k] for c in coords) for k in range(3)]
    for ob in PARTS:
        for v in ob.data.vertices:
            v.co.x=(v.co.x-lo[0])/(hi[0]-lo[0])*L-L/2
            v.co.y=(v.co.y-lo[1])/(hi[1]-lo[1])*W-W/2
            v.co.z=(v.co.z-lo[2])/(hi[2]-lo[2])*H

def export(name,bounds):
    normalize(bounds)
    bpy.ops.object.select_all(action='DESELECT')
    for o in PARTS:o.select_set(True)
    bpy.context.scene['asset_name']=name
    bpy.context.scene['normalized_size_godot']=f'{bounds[0]}, {bounds[2]}, {bounds[1]}'
    bpy.context.scene['origin']='Ground center; Blender X long, Z up; exports Godot X long, Y up'
    bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'source'/f'{name}.blend'))
    bpy.context.view_layer.objects.active=PARTS[0]; bpy.ops.object.join(); ob=bpy.context.object; ob.name=name
    # Collapse duplicate material slots into exactly one glTF primitive.
    ob.data.materials.clear(); ob.data.materials.append(MAT)
    for p in ob.data.polygons:p.material_index=0
    tri=ob.modifiers.new('Export_triangles','TRIANGULATE'); bpy.ops.object.modifier_apply(modifier=tri.name)
    bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
    ob['contract']='Ground origin. +X long axis. Runtime visual only. No collider.'
    ob['normalized_size_godot']=f'{bounds[0]}, {bounds[2]}, {bounds[1]}'
    ob['source']='Original procedural geometry and atlases, created specifically for RECLAMATION.'
    fulltris=len(ob.data.polygons)
    kwargs=dict(export_format='GLB',use_selection=True,export_texcoords=True,export_normals=True,export_materials='EXPORT',export_image_format='AUTO',export_yup=True,export_apply=True,export_extras=True)
    bpy.ops.export_scene.gltf(filepath=str(ROOT/'assets'/f'{name}.glb'),**kwargs)
    lod=ob.copy(); lod.data=ob.data.copy(); bpy.context.collection.objects.link(lod); lod.name=name+'_lod1'
    bpy.ops.object.select_all(action='DESELECT'); lod.select_set(True); bpy.context.view_layer.objects.active=lod
    dec=lod.modifiers.new('LOD1_silhouette_preserving','DECIMATE'); dec.ratio=.40; dec.use_collapse_triangulate=True
    bpy.ops.object.modifier_apply(modifier=dec.name)
    # Decimation may move boundary vertices. Renormalize LOD to the exact placement contract.
    co=[v.co for v in lod.data.vertices]
    low=[min(c[k] for c in co) for k in range(3)]; high=[max(c[k] for c in co) for k in range(3)]
    for vertex in lod.data.vertices:
        for k in range(3):
            vertex.co[k]=(vertex.co[k]-low[k])/(high[k]-low[k])*bounds[k]-(bounds[k]/2 if k<2 else 0)
    bpy.ops.export_scene.gltf(filepath=str(ROOT/'assets'/f'{name}_lod1.glb'),**kwargs)
    STATS[name]={'triangles':fulltris,'lod1_triangles':len(lod.data.polygons),'surfaces':1,'normalized_size_godot':[bounds[0],bounds[2],bounds[1]],'origin':'Ground center','long_axis':'X','texture_atlas':[2048,1024],'pbr_maps':['albedo','ORM','normal']}
    bpy.data.objects.remove(lod,do_unlink=True)
    ob.select_set(True); bpy.context.view_layer.objects.active=ob
    # Render without changing the delivered source scene.
    if not os.getenv("STREET_SKIP_RENDER"): render(name,bounds)
    PARTS.clear()

def render(name,bounds):
    scene=bpy.context.scene; scene.render.engine='CYCLES'; scene.cycles.samples=48
    scene.cycles.use_denoising=False; scene.render.resolution_x=1500; scene.render.resolution_y=940; scene.render.resolution_percentage=100
    scene.world.color=(.19,.19,.19)
    world=scene.world; world.use_nodes=True; world.node_tree.nodes['Background'].inputs['Color'].default_value=(.14,.17,.17,1); world.node_tree.nodes['Background'].inputs['Strength'].default_value=.48
    bpy.ops.mesh.primitive_plane_add(size=200,location=(0,0,-.012)); ground=bpy.context.object; ground.name='Preview_ground_only'
    gm=bpy.data.materials.new('Preview_ground'); gm.diffuse_color=(.095,.111,.105,1); gm.use_nodes=True; gm.node_tree.nodes.get('Principled BSDF').inputs['Base Color'].default_value=(.095,.111,.105,1); gm.node_tree.nodes.get('Principled BSDF').inputs['Roughness'].default_value=.95; ground.data.materials.append(gm)
    for loc,energy,size,col in [((-3,-4,8),1700,7,(1,.85,.66)),((4,5,7),1100,8,(.65,.80,1))]:
        bpy.ops.object.light_add(type='AREA',location=loc); light=bpy.context.object; light.data.energy=energy; light.data.shape='DISK'; light.data.size=size; light.data.color=col; light.rotation_euler=(Vector((0,0,.5))-light.location).to_track_quat('-Z','Y').to_euler()
    bpy.ops.object.camera_add(location=(bounds[0]*.72,-bounds[0]*.9,bounds[0]*.69)); camera=bpy.context.object; camera.rotation_euler=(Vector((0,0,.3))-camera.location).to_track_quat('-Z','Y').to_euler(); camera.data.type='ORTHO'; camera.data.ortho_scale=bounds[0]*1.19; scene.camera=camera
    scene.view_settings.view_transform='AgX'; scene.render.image_settings.file_format='PNG'; scene.render.filepath=str(ROOT/'previews'/f'{name}_blender.png'); bpy.ops.render.render(write_still=True)

clear(); MAT=material()
# WATER MAIN: three disconnected, visibly hollow sections on fractured utility bedding.
for i,(x,l,y) in enumerate([(-3.75,2.30,-.25),(-1.45,2.1,.25),(1.0,2.2,-.12),(3.52,2.45,.08)]):
    chunk('Broken_utility_bedding',(x,y,.025),(l,1.90,.24),0,seed=110+i,damage=.28,bevel_w=.025,top_tile=0)
for i,x in enumerate([-3.7,-.4,3.8]):
    for side in [-1,1]:chunk('Cracked_pipe_cradle',(x,side*.37,.19),(.63,.74,.37),0,seed=160+i+int(side),damage=.19,bevel_w=.024,top_tile=1)
tube('Ruptured_main_left',-4.60,-1.05,-.08,.73,.43,.060,n=40,rings=9,seed=145)
tube('Peeled_main_middle',-.19,2.34,.04,.61,.43,.057,n=40,rings=7,seed=791,split=True)
tube('Ruptured_main_right',3.01,4.64,.09,.69,.43,.058,n=40,rings=6,seed=891)
collar(-3.85,-.08,.73,.485); collar(3.77,.09,.69,.485)
# Damaged peeled-back iron plate; broad displaced sheet distinct from rubble.
mesh_obj('Detached_curved_shell',[(.48,.36,.76),(.76,.61,.88),(1.11,.64,.84),(1.8,.55,.61),(1.97,.35,.57),(1.14,.48,.67),(.48,.36,.71),(.76,.61,.83),(1.11,.64,.79),(1.8,.55,.56),(1.97,.35,.52),(1.14,.48,.62)],[(0,1,2,3,4,5),(11,10,9,8,7,6)]+[(i,(i+1)%6,(i+1)%6+6,i+6) for i in range(6)],3)
# One broken service pipe, visibly terminated, occupies the bedding rather than spill outside.
cyl_between('Broken_service_run',(-3.7,.72,.31),(-.93,.79,.36),.095,6,n=12)
cyl_between('Bent_service_elbow',(-.93,.79,.36),(-.71,.67,.48),.095,4,n=12)
for i in range(34):
    rr=random.Random(334+i); x=rr.uniform(-4.6,4.6); y=rr.choice([-1,1])*rr.uniform(.61,.95)
    chunk('Concrete_spall_%02d'%i,(x,y,.012),(rr.uniform(.20,.64),rr.uniform(.20,.44),rr.uniform(.13,.33)),rr.choice([0,1,7]),seed=900+i,rot=rr.uniform(-1,1),damage=.31,bevel_w=.012)
for i in range(7):
    x=-4+i*1.25; cyl_between('Snapped_rebar', (x,-.8,.2),(x+.25,-.73,.37),.018,4,n=6)
export('ruptured_water_main',(10,2.4,1.25))

clear(); MAT=material()
# ROAD OBSTRUCTION: heavy broken asphalt/concrete with deliberate central collapsed mass.
# Wide stacked plates define cover height while jagged chunks soften its footprint.
slabs=[(-2.02,-.05,1.7,1.65,.41,.02),(-.49,.05,1.66,1.95,.49,.14),(1.30,-.03,1.88,1.61,.48,-.13),(2.36,.20,1.04,1.49,.29,.20)]
for i,(x,y,sx,sy,h,rot) in enumerate(slabs):
    chunk('Fractured_concrete_foundation',(x,y,.018),(sx,sy,h),0,seed=200+i,rot=rot,damage=.22,bevel_w=.03,top_tile=1)
# Wide buckled top plates, with pitch as displaced vertices, never a clean full-length slab.
for i,(x,y,sx,sy,h,rot) in enumerate([(-1.65,-.06,1.97,1.34,.17,-.07),(.25,.13,1.55,1.61,.17,.22),(1.7,-.14,1.53,1.21,.16,-.18)]):
    ob=chunk('Buckled_asphalt_road_plate',(x,y,.51 if i==1 else .43),(sx,sy,h),2,seed=300+i,rot=rot,damage=.28,bevel_w=.018,top_tile=2)
    for v in ob.data.vertices:v.co.z+=(v.co.x-x)*(.07 if i!=1 else -.095)
# Sheared curb remnants: a staggered pale run, each separately broken, with no bright stripe.
for i in range(4):
    chunk('Sheared_curb_remnant',(-2.15+i*1.17,-.77,.15),(.84,.37,.43 if i%2 else .33),0,seed=441+i,rot=(-.04 if i%2 else .05),damage=.24,bevel_w=.024,top_tile=1)
for i in range(44):
    rr=random.Random(511+i); x=rr.uniform(-2.67,2.68); y=rr.choice([-1,1])*rr.uniform(.62,.98)
    chunk('Mixed_road_spall_%02d'%i,(x,y,.01),(rr.uniform(.18,.60),rr.uniform(.17,.41),rr.uniform(.12,.33)),rr.choice([0,1,2,7]),seed=900+i,rot=rr.uniform(-1,1),damage=.32,bevel_w=.012)
# Embedded fractured aggregate and small iron grating fragment, consolidated into single surface.
for i in range(7):
    rr=random.Random(1451+i)
    chunk('Embedded_aggregate',(rr.uniform(-2.35,2.4),rr.uniform(-.60,.6),.55),(rr.uniform(.15,.30),rr.uniform(.16,.30),rr.uniform(.12,.22)),1,seed=700+i,damage=.3,bevel_w=.009)
for i in range(5):cyl_between('Exposed_foundation_rebar',(-.84+i*.18,.77,.33),(-.74+i*.18,.85,.51),.015,4,n=6)
export('shattered_road_obstruction',(6,2.5,.9))
(ROOT/'asset_stats.json').write_text(json.dumps(STATS,indent=2))
print('STREET_COVER_BUILD_PASS',json.dumps(STATS))
