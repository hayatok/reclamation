"""Build RECLAMATION's original ruined civilian water booster station.
Blender 4.3.2, metre units. No imported geometry or third-party texture inputs.
Run from anywhere: blender --background --threads 4 --python source/build_water_station.py
Set WATER_RENDER=1 for a CPU Cycles editorial preview. Godot review is authoritative.
"""
import bpy, bmesh, math, random, json, os
from pathlib import Path
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[1]
for folder in ('assets', 'reports', 'previews', 'source'):
    (ROOT/folder).mkdir(parents=True, exist_ok=True)
random.seed(610505)
PARTS=[]
PI=math.pi
for o in list(bpy.data.objects):bpy.data.objects.remove(o,do_unlink=True)
for c in list(bpy.data.collections):
    if c.name!='Collection':bpy.data.collections.remove(c)
author=bpy.data.collections.new('AUTHORING | editable original components');bpy.context.scene.collection.children.link(author)
mat=bpy.data.materials.new('WaterStation | original weathered municipal atlas');mat.use_nodes=True
n=mat.node_tree.nodes;l=mat.node_tree.links;n.clear()
bs=n.new('ShaderNodeBsdfPrincipled');out=n.new('ShaderNodeOutputMaterial');l.new(bs.outputs['BSDF'],out.inputs['Surface']);bs.inputs['Specular IOR Level'].default_value=.22
for name,col in [('albedo','sRGB'),('orm','Non-Color'),('normal','Non-Color')]:
    tx=n.new('ShaderNodeTexImage');tx.name='water_station_'+name;tx.image=bpy.data.images.load(str(ROOT/'assets'/f'water_station_{name}.png'));tx.image.colorspace_settings.name=col;tx.image.pack();tx.extension='EXTEND'
    tx.image.filepath='//../assets/'+f'water_station_{name}.png'
    for packed in tx.image.packed_files:packed.filepath=tx.image.filepath
    if name=='albedo':l.new(tx.outputs['Color'],bs.inputs['Base Color'])
    elif name=='orm':
        sep=n.new('ShaderNodeSeparateColor');l.new(tx.outputs['Color'],sep.inputs['Color']);l.new(sep.outputs['Green'],bs.inputs['Roughness']);l.new(sep.outputs['Blue'],bs.inputs['Metallic'])
    else:
        norm=n.new('ShaderNodeNormalMap');norm.inputs['Strength'].default_value=.35;l.new(tx.outputs['Color'],norm.inputs['Color']);l.new(norm.outputs['Normal'],bs.inputs['Normal'])

def finish(o,name,tile=0,bevel=0,smooth=False):
    o.name=name;bpy.context.view_layer.objects.active=o;o.select_set(True)
    bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    if bevel:
        mod=o.modifiers.new('Worn_edge_catchlight','BEVEL');mod.width=bevel;mod.segments=1;mod.affect='EDGES';bpy.ops.object.modifier_apply(modifier=mod.name)
    bm=bmesh.new();bm.from_mesh(o.data);bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bm.to_mesh(o.data);bm.free();o.data.update()
    o.data.materials.clear();o.data.materials.append(mat)
    uv=o.data.uv_layers.active or o.data.uv_layers.new(name='MunicipalAtlas')
    uv.name='MunicipalAtlas'
    lo=[min(v.co[k] for v in o.data.vertices) for k in range(3)];hi=[max(v.co[k] for v in o.data.vertices) for k in range(3)]
    for f in o.data.polygons:
        f.material_index=0
        if smooth and len(f.vertices)<=4:f.use_smooth=True
        axis=max(range(3),key=lambda k:abs(f.normal[k]));ax=[k for k in range(3) if k!=axis]
        d=max(.0001,max(hi[k]-lo[k] for k in ax))
        for li in f.loop_indices:
            v=o.data.vertices[o.data.loops[li].vertex_index].co
            q=[.045+(v[k]-lo[k])/d*.91 for k in ax]
            uv.data[li].uv=((tile%4+q[0])/4,1-(tile//4+q[1])/4)
    for c in list(o.users_collection):c.objects.unlink(o)
    author.objects.link(o);PARTS.append(o);o.select_set(False);return o

def mesh(name,verts,faces,tile=0,bevel=0,smooth=False):
    me=bpy.data.meshes.new(name);me.from_pydata(verts,[],faces);me.update();o=bpy.data.objects.new(name,me);bpy.context.collection.objects.link(o);return finish(o,name,tile,bevel,smooth)
def box(name,pos,dims,tile=0,bevel=.012,rot=(0,0,0)):
    bpy.ops.mesh.primitive_cube_add(size=1,location=pos,rotation=rot);o=bpy.context.object;o.scale=dims;return finish(o,name,tile,bevel)
def cyl(name,pos,r,h,tile=4,n=16,rot=(0,0,0),bevel=0):
    bpy.ops.mesh.primitive_cylinder_add(vertices=n,radius=r,depth=h,location=pos,rotation=rot);return finish(bpy.context.object,name,tile,bevel)
def beam(name,a,b,r=.03,tile=4,n=8):
    a,b=Vector(a),Vector(b);o=cyl(name,(a+b)/2,r,(b-a).length,tile,n);o.rotation_euler=(b-a).to_track_quat('Z','Y').to_euler();return o

def lathe(name,pos,profile,tile=2,n=24,axis='Z'):
    vs=[]
    for z,r in profile:
        for i in range(n):
            a=2*PI*i/n;v=Vector((r*math.cos(a),r*math.sin(a),z))
            if axis=='Y':v=Vector((v.x,v.z,v.y))
            if axis=='X':v=Vector((v.z,v.y,v.x))
            vs.append(tuple(Vector(pos)+v))
    fs=[]
    for j in range(len(profile)-1):
        for i in range(n):fs.append((j*n+i,j*n+(i+1)%n,(j+1)*n+(i+1)%n,(j+1)*n+i))
    fs.extend([tuple(reversed(range(n))),tuple(range((len(profile)-1)*n,len(profile)*n))])
    o=mesh(name,vs,fs,tile,smooth=True)
    for f in o.data.polygons:
        if f.index >= (len(profile)-1)*n:continue
        row=f.index//n;col=f.index%n
        for li,(uu,vv) in zip(f.loop_indices,[(col/n,row/(len(profile)-1)),((col+1)/n,row/(len(profile)-1)),((col+1)/n,(row+1)/(len(profile)-1)),(col/n,(row+1)/(len(profile)-1))]):
            o.data.uv_layers.active.data[li].uv=((tile%4+.045+.91*uu)/4,1-(tile//4+.045+.91*vv)/4)
    return o

def tube_path(name,pts,r=.13,tile=2,n=12):
    vs=[];pts=[Vector(p) for p in pts]
    for i,p in enumerate(pts):
        axis=(pts[min(i+1,len(pts)-1)]-pts[max(i-1,0)]).normalized();ref=Vector((0,0,1)) if abs(axis.z)<.9 else Vector((1,0,0));u=axis.cross(ref).normalized();v=axis.cross(u)
        for j in range(n):vs.append(tuple(p+r*(u*math.cos(2*PI*j/n)+v*math.sin(2*PI*j/n))))
    fs=[]
    for i in range(len(pts)-1):
        for j in range(n):fs.append((i*n+j,i*n+(j+1)%n,(i+1)*n+(j+1)%n,(i+1)*n+j))
    fs.extend([tuple(reversed(range(n))),tuple(range((len(pts)-1)*n,len(pts)*n))]);return mesh(name,vs,fs,tile,smooth=True)

def ring(name,pos,r=.3,minor=.045,tile=4,axis='Z',segments=20):
    bpy.ops.mesh.primitive_torus_add(major_segments=segments,minor_segments=6,location=pos,major_radius=r,minor_radius=minor)
    o=bpy.context.object
    if axis=='Y':o.rotation_euler.x=PI/2
    if axis=='X':o.rotation_euler.y=PI/2
    return finish(o,name,tile,smooth=True)

def flange(name,a,b,r=.23,tile=4,n=16,bolts=4):
    a,b=Vector(a),Vector(b);axis=(b-a).normalized();beam(name,a,b,r,tile,n)
    ref=Vector((0,0,1)) if abs(axis.z)<.9 else Vector((1,0,0));u=axis.cross(ref).normalized();v=axis.cross(u)
    for i in range(bolts):
        delta=(math.cos(2*PI*(i+.125)/bolts)*u+math.sin(2*PI*(i+.125)/bolts)*v)*r*.80
        beam(name+'_retained_bolt',b+delta,b+delta+axis*.035,.033,12,6)

def extrude(name,outline,depth,y,tile=0,bevel=0):
    L=len(outline);vs=[(x,y-depth/2,z) for x,z in outline]+[(x,y+depth/2,z) for x,z in outline];fs=[tuple(reversed(range(L))),tuple(range(L,L*2))]+[(i,(i+1)%L,(i+1)%L+L,i+L) for i in range(L)];return mesh(name,vs,fs,tile,bevel)

def slab(name,outline,z,h,tile=0):
    L=len(outline);vs=[(x,y,z) for x,y in outline]+[(x,y,z+h) for x,y in outline];fs=[tuple(reversed(range(L))),tuple(range(L,L*2))]+[(i,(i+1)%L,(i+1)%L+L,i+L) for i in range(L)];return mesh(name,vs,fs,tile,.012)

def front_decal(name,x,y,z,w,h,tile):
    o=mesh(name,[(x-w/2,y,z-h/2),(x+w/2,y,z-h/2),(x+w/2,y,z+h/2),(x-w/2,y,z+h/2)],[(0,1,2,3)],tile)
    # Front is Blender -Y; assign full tile including authored pictograms.
    for li,xy in zip(o.data.polygons[0].loop_indices,[(.01,.99),(.99,.99),(.99,.01),(.01,.01)]):o.data.uv_layers.active.data[li].uv=((tile%4+xy[0])/4,1-(tile//4+xy[1])/4)
    return o

# BROAD SHAPES: chipped utility pad, rear tank, exposed pump, front collection basin.
slab('Broken concrete utility pad',[(-2.12,-1.83),(-1.86,-2.12),(1.63,-2.12),(2.12,-1.82),(2.12,1.62),(1.89,2.12),(-1.8,2.12),(-2.12,1.84)],0,.18,0)
# Two floor fracture gaps are real irregular dark seams, visible even with no normal map.
mesh('Settled slab fissure A',[(-2.02,-.84,.192),(-1.40,-.78,.192),(-1.03,-.90,.192),(-.68,-.56,.192),(-.74,-.50,.192),(-1.06,-.83,.192),(-1.41,-.71,.192),(-2.02,-.78,.192)],[(0,1,2,3,4,5,6,7)],8)
mesh('Settled slab fissure B',[(.84,1.94,.192),(1.02,1.17,.192),(1.70,.68,.192),(2.04,.72,.192),(2.04,.79,.192),(1.70,.75,.192),(1.09,1.20,.192),(.92,1.94,.192)],[(0,1,2,3,4,5,6,7)],8)
# Ruined masonry service enclosure at the rear; staggered broken top leaves tank exposed.
for row in range(8):
    z=.31+row*.225
    for col in range(6):
        x=-.08+col*.33+(.15 if row%2 else 0)
        if x>1.92 or (row>=5 and x<.52) or (row>=7 and x<1.18):continue
        if 1<=row<=4 and .55<x<1.26:continue  # open service window, actual negative space
        box('Rear service wall brick %02d %02d'%(row,col),(x,1.66,z),(.318,.29,.213),6,.009,rot=(0,0,random.uniform(-.012,.012)))
# Mortar bands and missing plaster retain a large readable wall plane.
box('Rear wall concrete footing',(.88,1.66,.245),(2.30,.40,.15),1,.018)
extrude('Broken old plaster skin',[(-.10,.42),(.32,.42),(.32,1.16),(.62,1.16),(.53,1.52),(.24,1.46),(.21,1.63),(-.10,1.60)],.035,1.491,3,.008)
box('Window old lintel',(1.0,1.65,1.56),(.9,.38,.12),1,.018)
# Main 2.86m pressure vessel: domed shoulders, welded skirt, split retaining straps.
for dx in [-.36,.36]:
    for dy in [-.30,.30]:box('Tank splayed support foot',(-.96+dx,.60+dy,.35),(.15,.16,.36),4,.015)
lathe('Municipal pressure tank domed shell',(-.96,.60,0),[(.43,.35),(.50,.49),(.67,.59),(2.18,.59),(2.37,.56),(2.52,.43),(2.61,.24),(2.64,.10)],2,28)
for z in [.73,2.10]:lathe('Oxidized tank retention band',(-.96,.60,z),[(-.05,.594),(-.035,.616),(.035,.616),(.05,.594)],4,28)
lathe('Tank welded bottom cap',(-.96,.60,0),[(.40,.24),(.43,.35),(.50,.49)],5,24)
cyl('Inspection neck',(-.96,.60,2.70),.185,.17,4,16)
cyl('Inspection hatch plate',(-.96,.60,2.81),.235,.07,3,16,bevel=.015)
for x in [-1.06,-.86]:beam('Inspection hatch handle leg',(x,.60,2.85),(x,.60,2.94),.02,4,8)
beam('Inspection hatch handle bridge',(-1.06,.60,2.94),(-.86,.60,2.94),.02,4,8)
# Cream municipal stencil band and large drop badge survive on the old tank.
box('Tank municipal badge backing',(-.96,.002,1.51),(.45,.04,.54),3,.015)
front_decal('Tank drop service number badge',-.96,-.021,1.51,.40,.49,13)
# Tank scar: replacement steel panel strapped around the lower front.
extrude('Tank riveted repair patch',[(-1.38,.97),(-.75,.91),(-.71,1.21),(-1.37,1.29)],.025,.044,5,.008)
for x,z in [(-1.32,1.03),(-.82,.99),(-1.31,1.22),(-.80,1.17)]:beam('Tank patch rivet',(x,.025,z),(x,-.005,z),.025,12,6)
# Pump skid and masonry pedestal keep the heavy motor visibly supported.
box('Pump concrete pedestal',(.78,-.10,.33),(1.55,1.95,.31),1,.045)
for x in [.27,1.29]:box('Pump iron skid rail',(x,-.12,.54),(.15,1.79,.12),4,.012)
for y in [-.76,.51]:box('Pump transverse skid',(.78,y,.64),(1.30,.19,.12),5,.012)
for x in [.36,1.17]:box('Motor cast mounting foot',(x,.08,.76),(.23,.87,.17),2,.018)
# Axial electric motor, shaped instead of a cylinder: tapered end bell and ribbed central housing.
lathe('Pump electric motor barrel',(.77,0,1.12),[(-.49,.25),(-.42,.34),(-.31,.375),(.35,.375),(.45,.33),(.56,.29)],2,24,axis='Y')
for i in range(11):
    a=2*PI*i/11
    if math.sin(a)<-.65:continue
    x=.77+math.cos(a)*.389;z=1.12+math.sin(a)*.389
    box('Motor deep cast cooling fin',(x,.02,z),(.045,.62,.085),4,.008,rot=(0,a-PI/2,0))
lathe('Motor ventilated rear bell',(.77,0,1.12),[(.50,.29),(.57,.32),(.68,.31),(.71,.265)],4,24,axis='Y')
for x in [.62,.72,.82,.92]:box('Motor back ventilation slit',(x,.716,1.12),(.033,.01,.36),8,0)
box('Motor old junction box',(1.03,.13,1.50),(.43,.43,.22),2,.025)
box('Junction field replacement lid',(1.03,.13,1.63),(.47,.48,.055),3,.01)
# Asymmetric cast scroll housing / centrifugal volute facing the basin.
outline=[]
for i in range(20):
    a=2*PI*i/20;rad=.39+.10*(i/20);outline.append((.77+math.cos(a)*rad,1.08+math.sin(a)*rad))
extrude('Centrifugal pump spiral volute',outline,.36,-.72,2,.025)
flange('Pump face bearing cover',(.77,-.905,1.08),(.77,-.965,1.08),.26,4,20,6)
beam('Pump central bearing cap',(.77,-.97,1.08),(.77,-1.022,1.08),.125,3,16)
# Curving distribution pipe: curved elbows, repair sleeve and copper salvage clamps.
pts=[(-.38,.59,.90),(-.08,.59,.90),(.09,.57,.96),(.19,.48,1.09),(.23,.28,1.17),(.23,-.06,1.17),(.18,-.34,1.17),(.05,-.49,1.17),(-.13,-.53,1.17),(-.52,-.53,1.17),(-.82,-.59,1.15),(-1.02,-.75,1.04),(-1.13,-.92,.87),(-1.13,-1.11,.71)]
tube_path('Swept municipal distribution pipe',pts,.145,2,12)
tube_path('Pump volute discharge branch',[(-.14,-.53,1.17),(.06,-.55,1.17),(.22,-.63,1.15),(.35,-.74,1.10)],.125,2,12)
flange('Tank service union',(-.35,.59,.90),(-.23,.59,.90),.22,4,16,4)
flange('Patched distribution sleeve',(-.61,-.55,1.17),(-.41,-.53,1.17),.19,5,16,4)
# Upright handwheel, broad open center and four spokes make its purpose legible.
lathe('Gate valve barrel',(-.65,-.53,1.17),[(-.15,.18),(-.08,.20),(.10,.20),(.17,.14)],4,16,axis='X')
beam('Gate valve stem',(-.65,-.53,1.22),(-.65,-.53,1.67),.043,12,8)
ring('Weathered red handwheel',(-.65,-.53,1.72),.26,.043,9,'Z',20)
for a in [0,PI/2,PI,3*PI/2]:beam('Handwheel spoke',(-.65,-.53,1.72),(-.65+math.cos(a)*.25,-.53+math.sin(a)*.25,1.72),.024,9,6)
cyl('Handwheel boss',(-.65,-.53,1.72),.067,.09,12,8)
# Pressure gauge is angled toward the working side; large cream disc and authored needle.
beam('Gauge feed',(-.17,.47,1.05),(-.17,.47,1.70),.025,12,8)
beam('Pressure gauge cast body',(-.17,.48,1.78),(-.17,.38,1.78),.16,4,20)
front_decal('Pressure dial',-.17,.371,1.78,.28,.28,14)
# Front basin: a low salvaged concrete drain with one collapsed lip, water dark and matte.
slab('Basin bottom slab',[(-1.76,-1.85),(.15,-1.85),(.25,-1.04),(-1.67,-.95)],.20,.10,1)
extrude('Basin cracked front rim',[(-1.78,.30),(.15,.30),(.15,.51),(-.40,.50),(-.56,.39),(-.67,.48),(-1.05,.49),(-1.15,.42),(-1.26,.53),(-1.78,.54)],.15,-1.86,1,.018)
box('Basin surviving left rim',(-1.76,-1.43,.40),(.16,.97,.39),0,.018)
box('Basin short right rim',(.18,-1.60,.37),(.16,.55,.30),0,.016)
box('Basin back rim',(-.76,-1.04,.36),(1.76,.15,.28),0,.018)
mesh('Basin stagnant water',[(-1.64,-1.77,.318),(.07,-1.77,.318),(.07,-1.12,.318),(-1.64,-1.12,.318)],[(0,1,2,3)],10)
# Grating lies across only half the basin and leaves the dark collecting volume readable.
for y in [-1.72,-1.25]:box('Bent basin grate side',(-.21,y,.555),(.68,.035,.055),4,.004,rot=(0,.04,0))
for x in [-.52,-.38,-.24,-.10,.04]:box('Basin grate bar',(x,-1.48,.55),(.036,.56,.035),4,0,rot=(0,.04,0))
# Rear civilian control box, exposed wire, a mismatched corrugated drip awning.
box('Old service electrical cabinet',(1.51,1.20,1.18),(.59,.31,.87),3,.025)
box('Cabinet inset worn steel door',(1.51,1.031,1.18),(.50,.035,.76),2,.012)
box('Cabinet dark lamp bezel',(1.36,1.004,1.36),(.14,.025,.14),8,.009)
box('Unlit flow status lens',(1.36,.984,1.36),(.09,.013,.09),12,.007)
beam('Cabinet door latch',(1.69,1.002,1.16),(1.69,.97,1.16),.038,4,8)
for z in [.93,1.00,1.07]:box('Cabinet lower vent',(1.49,1.003,z),(.25,.016,.018),8,0)
tube_path('Exposed salvaged pump power lead',[(1.51,1.14,.79),(1.52,.96,.64),(1.54,.71,.47),(1.42,.45,.49),(1.27,.23,.71),(1.20,.13,1.42)],.023,8,6)
# Broken awning contains a missing corner and visible corrugation, no pristine factory canopy.
vs=[];cols=12
for j,y in enumerate([.84,1.67]):
    for i in range(cols+1):
        x=.14+i*.15;z=2.08+(y-.84)*.15+(.026 if i%2 else 0)
        if j==0 and i>9:yval=y+.19*(i-9)
        else:yval=y
        vs.append((x,yval,z))
fs=[(i,i+1,cols+2+i,cols+1+i) for i in range(cols)]
roof=mesh('Bent patchwork corrugated rain awning',vs,fs,5)
solid=roof.modifiers.new('Thin salvaged sheet edge','SOLIDIFY');solid.thickness=.025;bpy.context.view_layer.objects.active=roof;bpy.ops.object.modifier_apply(modifier=solid.name)
for x in [.25,1.71]:beam('Awning simple salvaged support',(x,1.58,1.53),(x,.93,2.07),.035,4,8)
box('Awning mismatched repair strip',(.50,1.18,2.157),(.42,.57,.028),3,.004,rot=(.15,0,-.08))
# Loose utility hose and masonry spall remain completely inside the site's walk exclusion.
pts=[]
for i in range(18):
    a=PI*.05+i/17*PI*1.88;pts.append((1.48+.33*math.cos(a),-1.47+.31*math.sin(a),.24+.012*math.sin(i)))
tube_path('Coiled scavenged service hose',pts,.043,8,6)
beam('Hose brass end',(1.82,-1.40,.25),(1.94,-1.36,.25),.057,12,8)
rr=random.Random(891)
for i,(x,y) in enumerate([(-1.82,1.54),(-1.65,1.77),(-1.77,-.38),(-1.88,-.18),(.38,1.74),(.71,1.88),(1.44,-.98),(1.66,-.81),(1.91,.60),(-.38,-1.98),(.27,-1.84)]):
    dims=(rr.uniform(.13,.31),rr.uniform(.13,.26),rr.uniform(.07,.17));box('Broken masonry fragment %02d'%i,(x,y,.19+dims[2]/2),dims,rr.choice([1,6,7]),.018,rot=(rr.uniform(-.10,.10),rr.uniform(-.08,.08),rr.uniform(-1,1)))
# Two coarse grass tufts, subordinate to the industrial shapes.
for x,y in [(-1.88,.98),(1.93,.18)]:
    for i in range(3):
        ang=i*2.1;mesh('Dead basin weeds',[(x-.045*math.cos(ang),y-.045*math.sin(ang),.19),(x+.045*math.cos(ang),y+.045*math.sin(ang),.19),(x+.07*math.cos(ang),y+.07*math.sin(ang),.50-i*.045)],[(0,1,2)],11)
# Preserve all individual authored pieces, alongside the joined one-surface export master.
export_col=bpy.data.collections.new('EXPORT_MASTER | runtime single surface');bpy.context.scene.collection.children.link(export_col)
clones=[]
for o in PARTS:
    c=o.copy();c.data=o.data.copy();export_col.objects.link(c);clones.append(c)
bpy.ops.object.select_all(action='DESELECT')
for o in clones:o.select_set(True)
bpy.context.view_layer.objects.active=clones[0];bpy.ops.object.join();master=bpy.context.object;master.name='water_station'
bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
master.data.materials.clear();master.data.materials.append(mat)
for f in master.data.polygons:f.material_index=0
tri=master.modifiers.new('Triangulated runtime','TRIANGULATE');bpy.ops.object.modifier_apply(modifier=tri.name)
master['provenance']='Original procedural geometry and original deterministic atlas; created for RECLAMATION, 2026-10-05.'
master['contract']='Visual only, metres, ground Y=0 in Godot, no collision/navigation nodes; within 4.5m square.'
master['hook']='Optional restored lens at Godot (1.36, 1.36, -0.972); forward normal +Z. No gameplay effects.'
lo=[min(v.co[k] for v in master.data.vertices) for k in range(3)];hi=[max(v.co[k] for v in master.data.vertices) for k in range(3)]
tris=len(master.data.polygons)
assert tris<=10000,(tris,'Triangle budget exceeded')
assert max(abs(lo[0]),abs(hi[0]),abs(lo[1]),abs(hi[1]))<=2.25,(lo,hi)
assert abs(lo[2])<.001,lo
kwargs=dict(export_format='GLB',use_selection=True,export_texcoords=True,export_normals=True,export_materials='EXPORT',export_image_format='AUTO',export_yup=True,export_apply=True,export_extras=True)
bpy.ops.export_scene.gltf(filepath=str(ROOT/'assets'/'water_station.glb'),**kwargs)
# Explicit lower-detail archive plus Godot's automatic generated LODs on main import.
lod=master.copy();lod.data=master.data.copy();export_col.objects.link(lod);lod.name='water_station_lod1'
master.select_set(False);lod.select_set(True);bpy.context.view_layer.objects.active=lod
mod=lod.modifiers.new('Silhouette preserving half detail','DECIMATE');mod.ratio=.48;mod.use_collapse_triangulate=True;bpy.ops.object.modifier_apply(modifier=mod.name)
bpy.ops.export_scene.gltf(filepath=str(ROOT/'assets'/'water_station_lod1.glb'),**kwargs)
lod_tris=len(lod.data.polygons);bpy.data.objects.remove(lod,do_unlink=True)
master.select_set(True);bpy.context.view_layer.objects.active=master
author.hide_render=True;author.hide_viewport=True
scene=bpy.context.scene;scene.unit_settings.system='METRIC'
scene['authoring']='Unhide AUTHORING and hide EXPORT_MASTER to edit components; packed images, no external mesh dependencies.'
scene['restoration_note']='New original later-art rebuild. Not an exact recovered historical asset.'
scene['godot_bounds']=json.dumps({'min':[lo[0],lo[2],-hi[1]],'max':[hi[0],hi[2],-lo[1]]})
scene.render.filepath='//../previews/water_station_blender.png'
# Packed image metadata and saved editor directories must also stay portable.
for screen in bpy.data.screens:
    for area in screen.areas:
        for space in area.spaces:
            if space.type=='FILE_BROWSER' and space.params:
                space.params.directory=b'//'
                space.params.filename=''
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'source'/'water_station.blend'))
report={'asset':'water_station','date':'2026-10-05','original_components':len(PARTS),'triangles':tris,'lod1_triangles':lod_tris,'surfaces':1,'materials':1,'godot_aabb_min':[lo[0],lo[2],-hi[1]],'godot_aabb_max':[hi[0],hi[2],-lo[1]],'atlas_size':[1024,1024],'packed_maps':['albedo','ORM','normal'],'collision_nodes':0,'license_notice':'See PROVENANCE.md; no license grant invented.'}
(ROOT/'reports'/'geometry_report.json').write_text(json.dumps(report,indent=2)+'\n');print(json.dumps(report))
if os.getenv('WATER_RENDER')=='1':
    scene.render.engine='CYCLES';scene.cycles.samples=48;scene.cycles.use_denoising=False;scene.render.resolution_x=1440;scene.render.resolution_y=1050;scene.render.resolution_percentage=100
    world=bpy.data.worlds.new('Editorial preview world');scene.world=world;world.use_nodes=True;world.node_tree.nodes['Background'].inputs['Color'].default_value=(.16,.20,.18,1);world.node_tree.nodes['Background'].inputs['Strength'].default_value=.55
    bpy.ops.mesh.primitive_plane_add(size=100,location=(0,0,-.025));g=bpy.context.object;gm=bpy.data.materials.new('Preview only ground');gm.diffuse_color=(.10,.12,.105,1);g.data.materials.append(gm)
    for loc,power,size,col in [((-3,-4,8),1800,7,(1,.85,.69)),((4,4,7),1400,8,(.71,.83,1))]:
        bpy.ops.object.light_add(type='AREA',location=loc);light=bpy.context.object;light.data.energy=power;light.data.size=size;light.data.color=col;light.rotation_euler=(Vector((0,0,1))-light.location).to_track_quat('-Z','Y').to_euler()
    bpy.ops.object.camera_add(location=(7.4,-8.6,9.6));cam=bpy.context.object;cam.rotation_euler=(Vector((0,0,1.12))-cam.location).to_track_quat('-Z','Y').to_euler();cam.data.type='ORTHO';cam.data.ortho_scale=6.4;scene.camera=cam
    scene.view_settings.view_transform='AgX';scene.render.image_settings.file_format='PNG';scene.render.filepath=str(ROOT/'previews'/'water_station_blender.png');bpy.ops.render.render(write_still=True)
