import bpy, math, random, os, json
from mathutils import Vector
random.seed(78)
from pathlib import Path
ROOT=str(Path(__file__).resolve().parent.parent)
bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
mat=bpy.data.materials.new('Refuge_Atlas_PBR');mat.use_nodes=True
nt=mat.node_tree;bs=nt.nodes.get('Principled BSDF');bs.inputs['Roughness'].default_value=.87
tex=nt.nodes.new('ShaderNodeTexImage');tex.image=bpy.data.images.load(ROOT+'/assets/refuge_atlas.png');nt.links.new(tex.outputs['Color'],bs.inputs['Base Color'])
orm=nt.nodes.new('ShaderNodeTexImage');orm.image=bpy.data.images.load(ROOT+'/assets/refuge_orm.png');orm.image.colorspace_settings.name='Non-Color'
sep=nt.nodes.new('ShaderNodeSeparateColor');nt.links.new(orm.outputs['Color'],sep.inputs[0]);nt.links.new(sep.outputs['Green'],bs.inputs['Roughness']);nt.links.new(sep.outputs['Blue'],bs.inputs['Metallic'])
objects=[]
def finish(o,name,tile,bevel=0):
 o.name=name; bpy.context.view_layer.objects.active=o
 bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
 if bevel:
  m=o.modifiers.new('Soft worn edges','BEVEL');m.width=bevel;m.segments=1;bpy.ops.object.modifier_apply(modifier=m.name)
 o.data.materials.append(mat)
 # Explicit planar UVs per face, inset into atlas tile; no overlap with other tiles.
 uv=o.data.uv_layers.new(name='UVMap') if not o.data.uv_layers else o.data.uv_layers.active
 for poly in o.data.polygons:
  n=poly.normal;axis=max(range(3),key=lambda x:abs(n[x]));axes=[x for x in range(3) if x!=axis]
  vals=[o.data.vertices[o.data.loops[j].vertex_index].co for j in poly.loop_indices]
  mins=[min(v[k] for v in vals) for k in axes];maxs=[max(v[k] for v in vals) for k in axes]
  for j,v in zip(poly.loop_indices,vals):
   q=[(v[k]-lo)/max(hi-lo,.001) for k,lo,hi in zip(axes,mins,maxs)]
   uv.data[j].uv=((tile%4+.035+q[0]*.93)/4,(3-tile//4+.035+q[1]*.93)/4)
 objects.append(o);return o
def box(name,loc,scale,tile=0,bevel=.025,rot=(0,0,0)):
 bpy.ops.mesh.primitive_cube_add(size=1,location=loc,rotation=rot);o=bpy.context.object;o.scale=scale;return finish(o,name,tile,bevel)
def cyl(name,loc,r,depth,tile=1,rot=(0,0,0),vertices=12):
 bpy.ops.mesh.primitive_cylinder_add(vertices=vertices,radius=r,depth=depth,location=loc,rotation=rot);return finish(bpy.context.object,name,tile,.012)
def beam(name,a,b,r=.025,tile=8):
 a=Vector(a);b=Vector(b);o=cyl(name,(a+b)/2,r,(b-a).length,tile);o.rotation_euler=(b-a).to_track_quat('Z','Y').to_euler();return o
# Blender Z up, front Y=-, GLTF maps this to Godot front +Z.
box('Cracked concrete platform',(0,0,.09),(6.65,4.55,.18),3,.055)
for x in [-2.8,-2.1,-1.4,-.7,0,.7,1.4,2.1,2.8]: box('Old timber sleeper',(x,0,.23),(.25,3.7,.17),4)
for y in [-1.2,1.2]: box('Rust rail',(0,y,.34),(6.8,.13,.18),1,.01)
for x in [-1.95,-1.4,1.4,1.95]:
 for y in [-1.25,1.25]:
  cyl('Bogie wheel',(x,y,.58),.34,.16,5,(math.pi/2,0,0));cyl('Wheel hub',(x,y*1.07,.58),.15,.18,1,(math.pi/2,0,0))
box('Rail chassis',(0,0,.79),(5.65,3.08,.25),5)
# asymmetric repaired car shell, visible seam panels and window recesses
box('Refuge shell',(0,0,1.61),(5.25,2.95,1.48),0,.055)
for y in [-1.49,1.49]:
 for x in [-2.05,-1.02,0,1.02,2.05]:
  box('Separate weathered wall panel',(x,y,1.18),(.98,.035,.49),0,.008)
  box('Cream lower belt',(x,y*1.004,1.51),(.98,.035,.12),2,.005)
  box('Window deep frame',(x,y*1.012,1.94),(.79,.085,.54),5,.025)
  box('Dirty amber window',(x,y*1.042,1.94),(.65,.016,.41),6,.005)
  box('Window mullion',(x,y*1.048,1.94),(.035,.035,.42),8,.006)
  box('Window ledge',(x,y*1.045,1.65),(.88,.13,.07),2,.01)
 for x in [-2.58,-1.54,-.52,.52,1.54,2.58]: box('Structural riveted upright',(x,y*1.025,1.66),(.065,.085,1.47),8,.008)
 # patch plates deliberately cross original seams
 for x,z,ang in [(-1.7,1.15,.06),(.55,1.23,-.04)]:
  box('Bolted rust patch',(x,y*1.045,z),(.54,.035,.28),1,.007,(0,ang,0))
  for dx in [-.21,.21]:cyl('Patch bolt',(x+dx,y*1.064,z+.08),.025,.02,8,(math.pi/2,0,0),6)
# Curved segmented metal roof creates authored silhouette
for i in range(7):
 y=(i-3)*.45;z=2.52-.17*(abs(i-3)/3)**1.8;rx=(i-3)*-.072
 box('Curved roof segment',(0,y,z),(5.58,.48,.13),0,.018,(rx,0,0))
for x in [-2.55,-1.3,0,1.3,2.55]:
 for i in range(7):
  y=(i-3)*.45;z=2.60-.17*(abs(i-3)/3)**1.8
  box('Roof retaining strap',(x,y,z),(.07,.47,.035),1,.005,((i-3)*-.072,0,0))
# roof equipment and solar salvage
box('Roof generator',(-1.55,.15,2.86),(1.06,.85,.48),5,.045)
for x in [-1.91,-1.77,-1.63,-1.49,-1.35,-1.21]:box('Cooling fins',(x,.15,3.12),(.045,.80,.055),8,.004)
for x in [.0,.60]:
 box('Salvage solar frame',(x,.38,2.86),(.57,1.2,.08),8,.01,(.13,0,0))
 box('Salvage solar panel',(x,.38,2.91),(.49,1.08,.018),11,.004,(.13,0,0))
 for yy in [-.03,.31,.65]:box('Solar cell seam',(x,yy,2.93),(.47,.015,.012),8,.001)
beam('Radio mast',(1.8,.65,2.47),(1.8,.65,4.36),.034)
beam('Radio crossarm',(1.08,.65,3.99),(2.52,.65,3.99),.026)
for x in [1.18,1.49,1.8,2.11,2.42]:beam('Yagi element',(x,.23,3.99),(x,1.07,3.99),.019)
for end in [(1.05,.12,2.58),(2.48,1.15,2.40)]:beam('Mast guy wire',(1.8,.65,3.74),end,.009,5)
# front service entrance replaces center pane with open dark threshold
box('Door recess',(0,-1.59,1.48),(.74,.085,1.23),5,.015)
box('Sliding door pushed aside',(.67,-1.67,1.46),(.66,.08,1.26),0,.015)
box('Door inset',(.67,-1.723,1.68),(.40,.023,.45),11,.005)
beam('Door grip',(.94,-1.75,1.27),(.94,-1.75,1.51),.027,2)
for i in range(3):box('Entry stair',(0,-2.12+i*.17,.2+i*.18),(1.12,.43,.18),8,.02)
for x in [-.66,.66]:beam('Entry handrail',(x,-2.21,.5),(x,-1.65,1.35),.025,2)
# cloth lean-to, visibly sagged geometry and seams
verts=[]
for row in range(3):
 for col in range(5):
  x=-2.65+col*.59;y=-1.49-row*.45;z=2.37-row*.2-.10*math.sin(col/4*math.pi)
  verts.append((x,y,z))
faces=[]
for r in range(2):
 for c in range(4):
  a=r*5+c;faces.extend([(a,a+1,a+6),(a,a+6,a+5)])
me=bpy.data.meshes.new('Sagging salvage canvas');me.from_pydata(verts,[],faces);me.update();o=bpy.data.objects.new('Canvas awning',me);bpy.context.collection.objects.link(o);finish(o,'Canvas awning',7)
for x in [-2.65,-.29]:beam('Awning support',(x,-2.36,.22),(x,-2.36,1.98),.035,4)
beam('Awning front seam',verts[10],verts[14],.025,2)
# Salvaged planks over a broken rear-side window.
for j in [-1,1]: box('Boarded broken window',(-2.05,1.59,1.93+j*.09),(.83,.055,.105),4,.009,(0,j*.16,0))
# refuge identifier, geometry text with no external font dependency
box('Refuge sign backing',(1.74,-1.63,2.38),(1.59,.10,.43),5,.025)
bpy.ops.object.text_add(location=(1.02,-1.693,2.23),rotation=(math.pi/2,0,0));o=bpy.context.object;o.data.body='REFUGE 07';o.data.size=.23;o.data.extrude=.002;o.data.space_character=1.1;bpy.ops.object.convert(target='MESH');finish(bpy.context.object,'Refuge identification',14)
# barricade sacks, supply barrel, stacked timber crates
for row in range(2):
 for n in range(4-row):
  box('Canvas sandbag',(1.13+n*.45+row*.2,-2.05,.36+row*.24),(.5,.37,.27),9,.10,(0,0,random.uniform(-.10,.10)))
for x,y in [(-2.08,-1.9),(-1.45,-1.95)]:
 box('Field supply crate',(x,y,.48),(.52,.46,.55),4,.025)
 for dx in [-.18,.18]:box('Crate metal strap',(x+dx,y-.235,.48),(.045,.035,.55),8,.005)
for z in [.45,.73]:cyl('Barrel band',(-2.93,.88,z),.26,.045,8)
cyl('Salvage fuel barrel',(-2.93,.88,.58),.25,.68,1)
box('Rear generator',(2.96,.55,.95),(.49,.94,.95),1,.04)
for yy in [.24,.40,.56,.72,.88]:box('Generator louvers',(3.22,yy,1.1),(.035,.045,.47),5,.002)
# rubble grounded around edge, not confetti: localized structural collapse pile
for i in range(10):
 box('Spalled masonry',(-2.75+random.random()*.8,1.53+random.random()*.45,.25+random.random()*.08),(.15+random.random()*.24,.17+random.random()*.22,.12),3,.02,(0,random.uniform(-.18,.18),random.uniform(0,3)))
# Join all static parts into one PBR draw surface; preserve only root-node + mesh.
bpy.ops.object.select_all(action='DESELECT')
for o in objects:o.select_set(True)
bpy.context.view_layer.objects.active=objects[0];bpy.ops.object.join();hero=bpy.context.object;hero.name='Refuge_HQ_LOD0';hero.rotation_euler.z=math.pi;hero.scale=(.92,.91,1);bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
tri=hero.modifiers.new('Triangulated export','TRIANGULATE');bpy.ops.object.modifier_apply(modifier=tri.name)
# Store editable source and primary export.
bpy.ops.file.pack_all()
bpy.ops.wm.save_as_mainfile(filepath=ROOT+'/source/refuge_hq.blend')
bpy.ops.export_scene.gltf(filepath=ROOT+'/assets/refuge_hq.glb',export_format='GLB',use_selection=True,export_texcoords=True,export_normals=True,export_materials='EXPORT',export_yup=True)
hi=len(hero.data.polygons)
# Deliberate mesh LOD with normals/UVs preserved, primarily reducing bevel edges.
dec=hero.modifiers.new('Far silhouette LOD','DECIMATE');dec.ratio=.40;bpy.ops.object.modifier_apply(modifier=dec.name);hero.name='Refuge_HQ_LOD1'
bpy.ops.export_scene.gltf(filepath=ROOT+'/assets/refuge_hq_lod1.glb',export_format='GLB',use_selection=True,export_texcoords=True,export_normals=True,export_materials='EXPORT',export_yup=True)
json.dump({'lod0_triangles':hi,'lod1_triangles':len(hero.data.polygons),'objects':len(objects),'surfaces':1,'texture_atlas':[1024,1024],'source':'original procedural authored geometry and original raster materials','blender':bpy.app.version_string},open(ROOT+'/asset_stats.json','w'),indent=2)
print('REFUGE_BUILD_OK',hi,len(hero.data.polygons))
