extends RefCounted
const Shape=preload("res://actor_visuals.gd")
static var meshes:Dictionary={}
static func add_resource(parent:Node3D,kind:String)->void:
 if not meshes.has(kind):
  var st=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
  if kind=="food":
   for x in [-.7,.35]:
    Shape._box(st,Vector3(.95,.6,.85),Vector3(x,.3,0),Color("796045"),Vector3.ZERO)
    for i in 5:
     Shape._prism(st,.16,.12,.25,Vector3(x-.3+(i%3)*.3,.71,-.22+floori(i/3.0)*.4),Color("969a53") if i%2==0 else Color("a06447"),6)
   Shape._box(st,Vector3(.9,.16,.65),Vector3(.55,.85,.55),Color("bcb291"),Vector3(0,.2,.08))
  elif kind=="parts":
   for i in 4:
    var p=Vector3((i%2)*.7-.45,.3,floori(i/2.0)*.65-.4)
    Shape._box(st,Vector3(.55,.6,.5),p,Color("46565b"),Vector3(0,.13*i,.1))
    Shape._box(st,Vector3(.42,.08,.3),p+Vector3(0,.34,0),Color("749b89"),Vector3.ZERO)
    Shape._prism(st,.12,.12,.42,p+Vector3(.12,.42,0),Color("a0784b"),8)
  else:
   for i in 7:
    Shape._box(st,Vector3(1.35,.2,.45),Vector3((i%3)*.45-.45,.18+floori(i/3.0)*.27,(i%2)*.65-.4),Color("656b65") if i%2 else Color("7f5840"),Vector3(.05*i,.4*i,.09*i))
  var mat=StandardMaterial3D.new();mat.vertex_color_use_as_albedo=true;mat.roughness=.96
  st.set_material(mat);st.index();meshes[kind]=st.commit()
 var n=MeshInstance3D.new();n.mesh=meshes[kind];parent.add_child(n)
