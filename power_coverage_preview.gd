extends Node3D
## Cosmetic electrical coverage. The caller supplies known source positions only.
## One shared fixed-radius ring batch and one optional connection quad.
const REACH:float=22.0
const SEGMENTS:int=64
const WIDTH:float=.12
const LIFT:float=.07
var rings:MultiMeshInstance3D
var line:MeshInstance3D
var line_mesh:ArrayMesh
var last_origins:Array=[]
var last_colors:Array=[]
var last_link:Array=[]
var rebuilds:int=0
func _init():
 top_level=true;visible=false;set_process(false);set_physics_process(false)
func _ready():_ensure()
func _material()->StandardMaterial3D:
 var m=StandardMaterial3D.new();m.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
 m.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;m.vertex_color_use_as_albedo=true
 m.cull_mode=BaseMaterial3D.CULL_DISABLED;m.depth_draw_mode=BaseMaterial3D.DEPTH_DRAW_DISABLED
 m.no_depth_test=false;m.render_priority=0
 return m
func _ensure():
 if is_instance_valid(rings):return
 var vertices=PackedVector3Array()
 for i in SEGMENTS:
  var a=float(i)/SEGMENTS*TAU;var b=(float(i)+.62)/SEGMENTS*TAU
  var p=Vector3(cos(a),0,sin(a));var q=Vector3(cos(b),0,sin(b))
  var outer=REACH+WIDTH*.5;var inner=REACH-WIDTH*.5
  vertices.append_array(PackedVector3Array([p*inner,p*outer,q*outer,p*inner,q*outer,q*inner]))
 var arrays=[];arrays.resize(Mesh.ARRAY_MAX);arrays[Mesh.ARRAY_VERTEX]=vertices
 var mesh=ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
 rings=MultiMeshInstance3D.new();rings.name="PowerCoverageRings";rings.multimesh=MultiMesh.new()
 rings.multimesh.transform_format=MultiMesh.TRANSFORM_3D;rings.multimesh.use_colors=true;rings.multimesh.mesh=mesh
 rings.material_override=_material();rings.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;rings.gi_mode=GeometryInstance3D.GI_MODE_DISABLED
 add_child(rings)
 line=MeshInstance3D.new();line.name="PowerConnection";line_mesh=ArrayMesh.new();line.mesh=line_mesh
 line.material_override=_material();line.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;line.gi_mode=GeometryInstance3D.GI_MODE_DISABLED;add_child(line)
func clear_preview():visible=false
func set_plan(origins:Array,colors:Array,start:Vector3=Vector3.INF,end:Vector3=Vector3.INF,tint:Color=Color.WHITE):
 _ensure()
 if origins.size()!=colors.size():clear_preview();return
 for p in origins:
  if not p is Vector3 or not p.is_finite():clear_preview();return
 if origins!=last_origins or colors!=last_colors:
  rings.multimesh.instance_count=origins.size()
  for i in origins.size():
   rings.multimesh.set_instance_transform(i,Transform3D(Basis.IDENTITY,origins[i]+Vector3.UP*LIFT))
   rings.multimesh.set_instance_color(i,colors[i])
  last_origins=origins.duplicate();last_colors=colors.duplicate();rebuilds+=1
 var valid=start.is_finite() and end.is_finite() and Vector2(start.x-end.x,start.z-end.z).length_squared()>.0001
 line.visible=valid
 if valid and last_link!=[start,end,tint]:
  var a=Vector3(start.x,LIFT,start.z);var b=Vector3(end.x,LIFT,end.z)
  var side=(b-a).normalized().cross(Vector3.UP)*WIDTH*.5
  var arrays=[];arrays.resize(Mesh.ARRAY_MAX)
  arrays[Mesh.ARRAY_VERTEX]=PackedVector3Array([a-side,a+side,b+side,a-side,b+side,b-side])
  arrays[Mesh.ARRAY_COLOR]=PackedColorArray([tint,tint,tint,tint,tint,tint])
  line_mesh.clear_surfaces();line_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
  last_link=[start,end,tint]
 visible=not origins.is_empty() or valid
func debug_state()->Dictionary:
 return {"visible":visible,"rings":last_origins.size() if visible else 0,"ring_triangles":SEGMENTS*2,"ring_batches":1,"link_triangles":2 if is_instance_valid(line) and line.visible and visible else 0,"rebuilds":rebuilds}
