extends Node3D
## Original civilian apocalypse hero props. Cosmetic only: no collisions or navigation edits.
const S = preload("res://structure_visuals.gd")
const A = preload("res://actor_visuals.gd")
const RUST = Color("7e4934")
const ASH = Color("393c32")
const CANVAS = Color("a1916c")
const MOSS = Color("63734b")
var _built := false
var _fire: OmniLight3D
var _fire_mesh: MeshInstance3D
var _time := 0.0

func setup(_mission = null) -> void:
	if _built: return
	_built=true
	var st=_start()
	_bus(st)
	_finish(st,"BurnedEvacuationBus",Vector3(-27,0,-7),-.12)
	st=_start()
	_checkpoint(st)
	_finish(st,"BreachedQuarantineGate",Vector3(1,0,-27.7),0)
	st=_start()
	_ruin(st)
	_finish(st,"CollapsedTenement",Vector3(28,0,9),PI*.5)
	st=_start()
	_camp(st)
	_finish(st,"SurvivorShelter",Vector3(-1.3,0,10.5),-.2)
	_sign("EVACUATION\nROUTE CLOSED",Vector3(-24.8,2,-10.8),Vector3(0,.35,.12),.012,Color("c4b48a"))
	_sign("QUARANTINE",Vector3(1,4.2,-27.38),Vector3.ZERO,.019,Color("c6b58c"))
	_sign("KEEP OUT",Vector3(5.9,1.7,-27.15),Vector3(0,0,.12),.012,Color("b38662"))
	_sign("WE ARE STILL HERE",Vector3(27.52,2.3,9),Vector3(0,-PI*.5,0),.012,Color("bdac8b"))
	_make_fire(Vector3(.1,.15,10.3))
	if int(_mission)==1:
		st=_start()
		_camp(st)
		_finish(st,"EasternRefuge",Vector3(26,0,19),PI*.5)
		_sign("REFUGE / WATER",Vector3(25,2.8,17.5),Vector3.ZERO,.018,Color("c2c698"))

func _start() -> SurfaceTool:
	var st:=SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	return st

func _finish(st:SurfaceTool, label:String, pos:Vector3, yaw:float) -> void:
	var material:=StandardMaterial3D.new()
	material.vertex_color_use_as_albedo=true
	material.roughness=1.0
	st.set_material(material)
	st.index()
	var mesh:=MeshInstance3D.new()
	mesh.name=label
	mesh.mesh=st.commit()
	mesh.position=pos
	mesh.rotation.y=yaw
	add_child(mesh)

func _bus(st:SurfaceTool) -> void:
	# Long recognizable civilian evacuation bus, hollow windows and broken roof.
	S.b(st,Vector3(2.8,.35,7.7),Vector3(0,.57,0),ASH)
	S.b(st,Vector3(2.70,.80,7.35),Vector3(0,1.02,0),Color("947641"))
	for x in [-1.37,1.37]:
		for z in [-2.5,2.4]:
			S.beam(st,Vector3(x-.16,.50,z),Vector3(x+.16,.5,z),.52,Color("242722"),10)
			S.beam(st,Vector3(x-.17,.50,z),Vector3(x+.17,.5,z),.24,RUST,8)
		# Pillars, dirty paint stripes, missing glass, charred frame.
		S.b(st,Vector3(.13,.12,7.4),Vector3(x,2.3,0),RUST)
		S.b(st,Vector3(.08,.16,7.3),Vector3(x,1.22,0),CANVAS.darkened(.25))
		for z in [-3.45,-2.3,-1.15,0,1.15,2.3,3.45]:
			S.b(st,Vector3(.12,1.15,.10),Vector3(x,1.80,z),ASH)
		for z in [-2.8,-1.6,1.7,2.8]:
			S.b(st,Vector3(.03,.64,.70),Vector3(x,1.87,z),Color("252d27"))
	# Missing center roof section and torn sheet hanging from rear.
	S.b(st,Vector3(2.9,.18,2.8),Vector3(0,2.43,-2.45),ASH,Vector3(.04,0,.06))
	S.b(st,Vector3(2.8,.12,1.4),Vector3(.13,2.33,2.9),RUST,Vector3(-.12,.06,.07))
	S.b(st,Vector3(2.4,.06,.9),Vector3(.1,1.93,1.9),RUST,Vector3(.58,0,.1))
	S.b(st,Vector3(2.75,.82,.1),Vector3(0,1.88,-3.7),ASH)
	for x in [-.68,.68]: S.b(st,Vector3(1.02,.55,.03),Vector3(x,1.94,-3.77),Color("4e5342"))
	S.b(st,Vector3(2.95,.2,.26),Vector3(.04,.65,-3.86),CANVAS.darkened(.5),Vector3(0,.06,.05))
	for x in [-.99,.99]: S.b(st,Vector3(.28,.2,.04),Vector3(x,1.03,-3.78),Color("b7a578"))
	for z in [-1.1,.1,1.3]:
		for x in [-.68,.68]: S.b(st,Vector3(.58,.5,.40),Vector3(x,1.1,z),RUST.darkened(.24))
	# Burst pavement and tall weeds make the wreck grounded in the abandoned street.
	for i in 9:
		var x:float=sin(i*2.4)*1.8
		var z:float=cos(i*1.9)*4.2
		S.b(st,Vector3(.6,.15,.5),Vector3(x,.13,z),ASH,Vector3(.1,i*.53,.07))
		_weed(st,Vector3(x,.15,z),.55+float(i%3)*.25)

func _checkpoint(st:SurfaceTool) -> void:
	# Open breach in center, old checkpoint edges only. No gameplay blockers.
	for x in [-5.1,5.1]:
		S.b(st,Vector3(3.3,.5,1.1),Vector3(x,.3,0),Color("8a8470"))
		S.b(st,Vector3(3.0,.7,.6),Vector3(x,.85,0),Color("aaa18a"))
		for dx in [-1.1,-.3,.5,1.3]: S.b(st,Vector3(.37,.5,.03),Vector3(x+dx,.85,.32),RUST,Vector3(0,0,.35))
		S.beam(st,Vector3(x,.3,0),Vector3(x,4.0,0),.10,ASH)
		for dx in [-1.5,-.75,0,.75,1.5]:
			S.beam(st,Vector3(x+dx,1.2,0),Vector3(x+dx,3.3,0),.025,ASH)
		for y in [1.5,2,2.5,3]: S.beam(st,Vector3(x-1.6,y,0),Vector3(x+1.6,y,0),.021,ASH)
	S.b(st,Vector3(11.7,.70,.12),Vector3(0,4.15,0),ASH,Vector3(0,0,.03))
	S.b(st,Vector3(5.2,.58,.03),Vector3(0,4.15,.09),RUST.darkened(.25))
	# Fallen swinging gate and bent boom lie beside, rather than across, the opening.
	S.b(st,Vector3(3.2,.10,1.9),Vector3(-6.2,.25,1.9),ASH,Vector3(.10,.4,.12))
	S.beam(st,Vector3(4,.45,.6),Vector3(7.4,.2,2.7),.08,CANVAS)
	for pos in [Vector3(-7,.1,1),Vector3(7,.1,-1),Vector3(-3.8,.1,-.7)]: _weed(st,pos,1.3)

func _ruin(st:SurfaceTool) -> void:
	# A civilian tenement shell with broken floors, exposed brick, rebar and vines.
	S.b(st,Vector3(7.0,.25,4.2),Vector3(0,.15,0),Color("706c5c"))
	for x in [-3,-1,1,3]:
		S.b(st,Vector3(.38,4.7,.55),Vector3(x,2.47,0),Color("796959"))
		S.beam(st,Vector3(x,4.6,0),Vector3(x+.15,5.7,.1),.035,ASH)
	for y in [1.9,3.7]:
		S.b(st,Vector3(6.3,.32,.65),Vector3(0,y,0),Color("8f8570"))
	for x in [-2,2]:
		S.b(st,Vector3(1.6,.95,.35),Vector3(x,.75,0),RUST.darkened(.07))
		S.b(st,Vector3(1.4,.60,.3),Vector3(x,2.35,0),RUST.darkened(.15))
	S.b(st,Vector3(2.9,.22,2.5),Vector3(-1.55,3.65,-.8),Color("575c4d"),Vector3(-.16,0,-.18))
	S.b(st,Vector3(3,.25,1.8),Vector3(1.5,.75,.4),Color("6b6959"),Vector3(.14,.2,.29))
	for i in 14:
		var x:float=sin(i*2.3)*3
		var z:float=cos(i*1.7)*1.5
		S.b(st,Vector3(.35+float(i%3)*.21,.28,.46),Vector3(x,.35,z),RUST if i%2 else CANVAS.darkened(.4),Vector3(.2,i*.6,.12))
	for x in [-2.8,.8,2.8]:
		for y in [.5,1.2,1.9,2.6,3.3]: _weed(st,Vector3(x,y,.35),.75)

func _camp(st:SurfaceTool) -> void:
	# A patched tarp tent, sleeping roll, water can, cooking crate and hand-carried supplies.
	var left:=Vector3(-1.1,.35,-.7)
	var right:=Vector3(1.1,.35,-.7)
	var peak:=Vector3(0,1.7,-.7)
	A._quad(st,left,peak,peak+Vector3(0,0,1.5),left+Vector3(0,0,1.5),CANVAS)
	A._quad(st,peak,right,right+Vector3(0,0,1.5),peak+Vector3(0,0,1.5),CANVAS.darkened(.15))
	A._triangle(st,left,right,peak,Color("685f49"))
	S.b(st,Vector3(.5,.035,.48),Vector3(-.45,1.12,.1),RUST,Vector3(0,0,.84))
	for z in [-.75,.85]: S.beam(st,Vector3(0,.1,z),Vector3(0,1.73,z),.035,ASH)
	for x in [-1.2,1.2]: S.beam(st,Vector3(x,.1,.8),Vector3(x*.7,.7,.8),.016,ASH)
	S.b(st,Vector3(.55,.16,1.15),Vector3(.2,.15,.2),Color("667457"))
	S.b(st,Vector3(.40,.35,.32),Vector3(1.0,.25,.65),Color("778a78"))
	S.b(st,Vector3(.18,.065,.08),Vector3(1,.46,.65),ASH)
	S.b(st,Vector3(.42,.4,.45),Vector3(-1,.25,.9),RUST.darkened(.1))
	S.p(st,.16,.16,.25,Vector3(-1,.58,.9),ASH,8)

func _weed(st:SurfaceTool,pos:Vector3,height:float) -> void:
	for i in 3:
		var angle:float=i*2.1
		var tip:=pos+Vector3(cos(angle)*.30,height,sin(angle)*.30)
		var side:=Vector3(sin(angle)*.13,0,cos(angle)*.13)
		A._triangle(st,pos-side,pos+side,tip,MOSS.darkened(float(i)*.1))
		A._triangle(st,pos+side,pos-side,tip,MOSS)

func _sign(text:String,pos:Vector3,angles:Vector3,pixel:float,color:Color) -> void:
	var sign:=Label3D.new()
	sign.text=text
	sign.font_size=32
	sign.pixel_size=pixel
	sign.modulate=color
	sign.outline_size=0
	sign.position=pos
	sign.rotation=angles
	add_child(sign)

func _make_fire(pos:Vector3) -> void:
	var st=_start()
	S.p(st,.30,.28,.62,Vector3(0,.31,0),RUST,10)
	for y in [.13,.48]: S.p(st,.315,.315,.045,Vector3(0,y,0),ASH,10)
	_finish(st,"BurnBarrel",pos,0)
	_fire_mesh=MeshInstance3D.new()
	var flame:=PrismMesh.new()
	flame.size=Vector3(.35,.57,.35)
	_fire_mesh.mesh=flame
	var material:=StandardMaterial3D.new()
	material.albedo_color=Color("d88c36")
	material.emission_enabled=true
	material.emission=Color("db6a23")
	material.emission_energy_multiplier=1.7
	_fire_mesh.material_override=material
	_fire_mesh.position=pos+Vector3(0,.78,0)
	add_child(_fire_mesh)
	_fire=OmniLight3D.new()
	_fire.position=pos+Vector3(0,1,0)
	_fire.light_color=Color("f6a347")
	_fire.omni_range=3.5
	_fire.light_energy=.65
	add_child(_fire)

func _process(delta:float) -> void:
	if not is_instance_valid(_fire): return
	_time+=delta
	var flutter:float=sin(_time*13)*.13+sin(_time*23)*.06
	_fire.light_energy=.65+flutter
	_fire_mesh.scale=Vector3(1.0-flutter,.9+flutter,1.0-flutter)
