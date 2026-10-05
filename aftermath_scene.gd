extends Node3D
## Original, bounded post-win scenery. No collision, signals to gameplay, RNG,
## navigation, input capture, timers, rewards or references to real units.
## Add under the identity world root, then setup(zero_based_mission, positions).
## All characters and props here belong only to this presentation.

const Actors = preload("res://actor_visuals.gd")
const Structures = preload("res://structure_visuals.gd")
const DURATION := 5.6
const DEFAULT_PUMP := Vector3(-14, 0, -7)
const DEFAULT_ARRIVAL := Vector3(20, 0, 22)
const DEFAULT_STREET := Vector3(-9.5, 0, -17.5)
const WARM := Color("e2b879")
const DARK := Color("343e3c")
const STEEL := Color("77837d")
const WOOD := Color("aa9470")

var mission_index: int = 0
var focal_point := Vector3.ZERO
var camera_focus := Vector3.ZERO
var camera_size: float = 34.0
var elapsed: float = 0.0
var complete: bool = false
var _actors: Array[Node3D] = []
var _props: Array[Node3D] = []
var _window_materials: Array[StandardMaterial3D] = []
var _window_people: Array[Node3D] = []
var _lights: Array[OmniLight3D] = []
var _water: MeshInstance3D
var _stream: MeshInstance3D
var _truck: Node3D
var _cargo: Node3D
var _has_convoy: bool = false
var _delivery_basis := Basis.IDENTITY
var _receiving_center := Vector3.ZERO
var _materials: Dictionary = {}
var _prop_meshes: Dictionary = {}

## World positions, in metres: pump (existing station root), arrival (new cosmetic
## truck stop, beside the actual convoy), street (north factory forecourt).
## Optional window_origins: up to three WORLD-space pane centers on real facades.
## Default panes align to world_art's intact building at (-9.5, 0, -26.8).
## The caller owns camera/UI and world_art.restore_district_lights().
func setup(index: int, world_positions: Dictionary = {}) -> void:
	set_process(false)
	for child in get_children():
		remove_child(child)
		child.free()
	_actors.clear()
	_props.clear()
	_window_materials.clear()
	_window_people.clear()
	_lights.clear()
	_water = null
	_stream = null
	_truck = null
	_cargo = null
	rotation = Vector3.ZERO
	_has_convoy = false
	mission_index = clampi(index, 0, 2)
	elapsed = 0.0
	complete = false
	match mission_index:
		0:
			position = _ground(world_positions.get("pump"), DEFAULT_PUMP)
			focal_point = position + Vector3(-.3, 0, 1.1)
			_build_water()
		1:
			_has_convoy = is_instance_valid(world_positions.get("convoy_node")) and world_positions.get("convoy_node") is Node3D
			position = _ground(world_positions.get("convoy", world_positions.get("arrival")), DEFAULT_ARRIVAL)
			focal_point = position + Vector3(-.4, 0, -1.1)
			_delivery_basis = Basis.IDENTITY
			if _has_convoy:
				var convoy: Node3D = world_positions["convoy_node"]
				# Read the real vehicle's pose once; never change it or retain it.
				position = _ground(convoy.global_position, position)
				_delivery_basis = Basis(Vector3.UP, convoy.global_rotation.y + PI/2.0)
				rotation.y = convoy.global_rotation.y + PI/2.0
				focal_point = position + _delivery_basis * Vector3(-1.6,0,-1.4)
			_choose_receiving_area(world_positions.get("occupied_positions", []),world_positions.get("building_positions", []))
			focal_point = position.lerp(position+_delivery_basis*_receiving_center,.55)
			_build_delivery()
		2:
			position = _ground(world_positions.get("street"), DEFAULT_STREET)
			focal_point = position + Vector3(0, 1, -1.4)
			_build_street(world_positions)
	camera_focus = focal_point
	camera_size = [30.0,34.0,38.0][mission_index]
	sample_at(0.0)
	set_process(true)

func _process(delta: float) -> void:
	if not is_finite(delta) or delta < 0.0:
		return
	sample_at(elapsed + minf(delta, .25))
	if complete:
		set_process(false)

## Public deterministic review hook. Seeking never modifies gameplay or uses RNG.
## The last pose remains visible after the short sequence; no awaited signal.
func sample_at(seconds: float) -> void:
	elapsed = clampf(seconds, 0.0, DURATION) if is_finite(seconds) else 0.0
	complete = elapsed >= DURATION
	if _actors.size() != 3:
		return
	match mission_index:
		0: _sample_water(elapsed)
		1: _sample_delivery(elapsed)
		2: _sample_street(elapsed)

func _ground(value: Variant, fallback: Vector3) -> Vector3:
	if not value is Vector3 or not value.is_finite():
		return fallback
	if absf(value.x) > 26.0 or absf(value.z) > 26.0:
		return fallback
	return Vector3(value.x, 0, value.z)

func _material(key: String, color: Color, glow: float = 0.0) -> StandardMaterial3D:
	if _materials.has(key):
		return _materials[key]
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = .86
	material.metallic_specular = .12
	if glow > 0.0:
		material.emission_enabled = true
		material.emission = color
		material.emission_energy_multiplier = glow
	_materials[key] = material
	return material

func _vertex_material() -> StandardMaterial3D:
	var material := _material("props", Color.WHITE)
	material.vertex_color_use_as_albedo = true
	return material

func _mesh_node(parent: Node3D, mesh: Mesh, node_name: String, at := Vector3.ZERO) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = node_name
	node.mesh = mesh
	node.position = at
	parent.add_child(node)
	return node

func _batch(parent: Node3D, node_name: String, boxes: Array, rods: Array = []) -> MeshInstance3D:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for item in boxes:
		Structures.b(surface, item[0], item[1], item[2])
	for item in rods:
		Structures.beam(surface, item[0], item[1], item[2], item[3], 8)
	surface.set_material(_vertex_material())
	surface.index()
	return _mesh_node(parent, surface.commit(), node_name)

func _prop(kind: String, parent: Node3D, at: Vector3) -> Node3D:
	var root := Node3D.new()
	root.name = "WaterPail" if kind == "pail" else "ReliefCrate"
	root.position = at
	parent.add_child(root)
	if not _prop_meshes.has(kind):
		var surface := SurfaceTool.new()
		surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		if kind == "pail":
			# Open, broad enamel pail with a real rim and bail, no opaque top lid.
			var radius: float = .22
			for side in 10:
				var a: float = TAU * side / 10.0
				var b: float = TAU * (side + 1) / 10.0
				var lo_a := Vector3(cos(a) * .17, -.20, sin(a) * .17)
				var lo_b := Vector3(cos(b) * .17, -.20, sin(b) * .17)
				var hi_a := Vector3(cos(a) * radius, .20, sin(a) * radius)
				var hi_b := Vector3(cos(b) * radius, .20, sin(b) * radius)
				Actors._quad(surface, lo_a, hi_a, hi_b, lo_b, Color("a3afa0"))
				Actors._quad(surface, hi_a * Vector3(.88, 1, .88), lo_a, lo_b, hi_b * Vector3(.88, 1, .88), DARK)
				Structures.beam(surface, hi_a, hi_b, .021, STEEL, 6)
			Structures.beam(surface, Vector3(-.23,.15,0), Vector3(-.20,.42,0), .023, DARK, 6)
			Structures.beam(surface, Vector3(.23,.15,0), Vector3(.20,.42,0), .023, DARK, 6)
			Structures.beam(surface, Vector3(-.20,.42,0), Vector3(.20,.42,0), .025, DARK, 6)
		else:
			Structures.b(surface, Vector3(.72,.48,.54), Vector3.ZERO, WOOD)
			for x in [-.28,.28]:
				Structures.b(surface, Vector3(.065,.52,.59), Vector3(x,0,0), DARK)
			for y in [-.16,.16]:
				Structures.b(surface, Vector3(.78,.055,.60), Vector3(0,y,0), WOOD.lightened(.14))
			# Broad faded pale inventory patch, not an interface icon or medical cross.
			Structures.b(surface, Vector3(.22,.17,.012), Vector3(0,.03,-.281), Color("d1c8ab"))
		surface.set_material(_vertex_material())
		surface.index()
		_prop_meshes[kind] = surface.commit()
	_mesh_node(root, _prop_meshes[kind], "Geometry")
	return root

func _civilian(node_name: String) -> Node3D:
	var actor := Node3D.new()
	actor.name = node_name
	add_child(actor)
	Actors.add_human(actor, "worker")
	# Reuse the unarmed left-hand mesh on this private right-hand instance. The
	# shared source meshes and all actual game workers retain their tools.
	var visual: Node3D = actor.get_meta(&"actor_visuals")
	var right_arm: Node3D = visual.get_meta(&"arm_r")
	(right_arm.get_node("Geometry") as MeshInstance3D).mesh = Actors.mesh_for("worker", "armL")
	_actors.append(actor)
	return actor

func _pose(actor: Node3D, time: float, from: Vector3, to: Vector3, start: float, stop: float, facing: Vector3, carrying: bool = false) -> void:
	var progress: float = smoothstep(start, stop, time)
	actor.position = from.lerp(to, progress)
	actor.position.y = maxf(actor.position.y, .025)
	var moving: bool = time > start and time < stop and from.distance_squared_to(to) > .01
	var direction: Vector3 = to - from if moving else facing
	direction.y = 0
	if direction.length_squared() > .001:
		actor.rotation.y = atan2(-direction.x, -direction.z)
	Actors.pose(actor, time * 7.5, moving)
	if carrying:
		var visual: Node3D = actor.get_meta(&"actor_visuals")
		var left: Node3D = visual.get_meta(&"arm_l")
		var right: Node3D = visual.get_meta(&"arm_r")
		left.rotation.x = .36
		right.rotation.x = .36

func _greet(actor: Node3D, amount: float) -> void:
	var visual: Node3D = actor.get_meta(&"actor_visuals")
	var arm: Node3D = visual.get_meta(&"arm_l")
	arm.rotation.z = -1.6 * amount
	arm.rotation.x = .22 * amount

func _build_water() -> void:
	var surface := BoxMesh.new()
	surface.size = Vector3(1.60, .014, .58)
	_water = _mesh_node(self, surface, "ReturnedWater", Vector3(-.785,.332,1.445))
	_water.material_override = _material("water", Color("71a7aa"), .17)
	_water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var flow := CylinderMesh.new()
	flow.top_radius = .085
	flow.bottom_radius = .105
	flow.height = .36
	flow.radial_segments = 8
	flow.rings = 1
	_stream = _mesh_node(self, flow, "OutletFlow", Vector3(-1.13,.54,1.12))
	_stream.material_override = _material("flow", Color("a1c7be"), .14)
	_stream.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for i in 3:
		var actor := _civilian("WaterCollector%d" % (i + 1))
		var pail := _prop("pail", actor, Vector3(.35,.47,-.27))
		_props.append(pail)
	# A couple of filled cans stay on the dry apron; single merged mesh.
	_batch(self, "CollectedWaterCans", [
		[Vector3(.34,.52,.28), Vector3(-2.65,.285,1.55), Color("869b8c")],
		[Vector3(.16,.055,.12), Vector3(-2.65,.57,1.55), DARK],
		[Vector3(.34,.48,.28), Vector3(-3.05,.265,1.65), Color("b0a27b")],
		[Vector3(.16,.055,.12), Vector3(-3.05,.53,1.65), DARK]
	])

func _sample_water(t: float) -> void:
	var returned: float = smoothstep(.10, 1.50, t)
	_water.visible = t > .1
	_water.position.y = lerpf(.332,.405,returned)
	_stream.visible = t > .12
	_stream.scale = Vector3(.75 + returned*.25, .65 + returned*.35, .75 + returned*.25)
	_stream.position.y = .71 - .18 * _stream.scale.y
	_pose(_actors[0], t, Vector3(-2.6,0,3.25), Vector3(-1.15,0,2.38), .2, 1.75, Vector3(0,0,-1), true)
	_pose(_actors[1], t, Vector3(.75,0,4.2), Vector3(.10,0,2.72), .6, 2.7, Vector3(-.35,0,-1))
	_pose(_actors[2], t, Vector3(-4.2,0,2.5), Vector3(-2.8,0,2.55), .4, 2.6, Vector3(1,0,-.4))
	# One readable scoop, then the filled pail rises into the collector's hands.
	var scoop: float = smoothstep(1.8,2.45,t) * (1.0-smoothstep(3.4,4.2,t))
	_props[0].position = Vector3(.03, .72-.25*scoop, -.41-.18*scoop)
	_props[0].rotation.z = -.24*scoop
	var visual: Node3D = _actors[0].get_meta(&"actor_visuals")
	var body: Node3D = visual.get_meta(&"body")
	body.rotation.x = -.12*scoop
	_greet(_actors[2], sin(clampf((t-3.3)/1.3,0,1)*PI)*.42)

func _choose_receiving_area(occupied: Variant, built: Variant) -> void:
	# A small authored set on the south/west road or apron, away from the east
	# facade and map edge. Read positions once; never invoke gameplay/navigation.
	var candidates: Array[Vector3] = [
		Vector3(-5.8,0,3.0), Vector3(-3.3,0,5.6), Vector3(-6.5,0,0),
		Vector3(0,0,6.0), Vector3(-7.0,0,4.5), Vector3(-8.0,0,1.0)
	]
	var people: Array = occupied if occupied is Array else []
	var buildings: Array = built if built is Array else []
	var chosen := position+Vector3(-5.8,0,3.0)
	var best_score: float = -INF
	for offset in candidates:
		var center: Vector3 = position+offset
		# The whole receiving group stays on the ground, inside the outer rail.
		if center.x < -28 or center.x > 27 or center.z < -28 or center.z > 24.3:
			continue
		var clearance: float = 7.0
		var crowd_penalty: float = 0.0
		for value in people:
			if not value is Vector3 or not value.is_finite():
				continue
			var distance: float = _receiving_clearance(center,value)
			clearance = minf(clearance,distance)
			crowd_penalty += maxf(0.0,1.8-distance)
		for value in buildings:
			if not value is Vector3 or not value.is_finite():
				continue
			var distance: float = _receiving_clearance(center,value)-2.8
			clearance = minf(clearance,distance)
			crowd_penalty += maxf(0.0,1.4-distance)*2.0
		var score: float = clearance-crowd_penalty*.8-offset.length()*.055
		if score > best_score:
			best_score = score
			chosen = center
	_receiving_center = _delivery_basis.inverse()*(chosen-position)

func _receiving_clearance(center: Vector3, other: Vector3) -> float:
	var clearance: float = INF
	for at in [center,center+Vector3(2.0,0,-.15),center+Vector3(.65,0,1.45)]:
		clearance = minf(clearance,Vector2(other.x-at.x,other.z-at.z).length())
	return clearance

func _receiving(offset: Vector3) -> Vector3:
	return _receiving_center+_delivery_basis.inverse()*offset

func _build_delivery() -> void:
	_truck = Node3D.new()
	_truck.name = "ArrivingReliefTruck"
	add_child(_truck)
	if not _has_convoy:
		Structures.add_vehicle(_truck, "truck")
	_truck.rotation.y = -PI/2.0
	_cargo = _prop("crate", self, Vector3.ZERO)
	for title in ["CargoUnloader", "WaitingReceiver", "ArrivalGreeter"]:
		_civilian(title)
	var receiving := Node3D.new()
	receiving.name = "ClearReceivingArea"
	receiving.position = _receiving_center
	receiving.rotation.y = -rotation.y
	add_child(receiving)
	_prop("crate", receiving, Vector3(.65,.265,-.65))
	_prop("crate", receiving, Vector3(1.5,.265,-.65))
	_prop("crate", receiving, Vector3(1.1,.78,-.65))
	_batch(receiving, "UnloadPallet", [
		[Vector3(2.0,.07,.16),Vector3(1.05,.08,-.93),WOOD.darkened(.2)],
		[Vector3(2.0,.07,.16),Vector3(1.05,.08,-.35),WOOD.darkened(.2)]
	])

func _sample_delivery(t: float) -> void:
	_truck.position = Vector3(0 if _has_convoy else lerpf(-6.0,0.0,smoothstep(0,1.9,t)), .025, 0)
	# Actual convoy is already stopped. The cosmetic loader carries from its
	# rear to a separate clear receiving group; the escort army stays untouched.
	var pickup_start: float = .10 if _has_convoy else 1.85
	var pickup_stop: float = .70 if _has_convoy else 2.55
	var carry_start: float = 1.15 if _has_convoy else 3.05
	var carry_stop: float = 4.80
	var toward_pile: Vector3 = _delivery_basis.inverse()*Vector3(0,0,1)
	_pose(_actors[0], t, Vector3(-2.9,0,-1.65), Vector3(-2.9,0,0), pickup_start,pickup_stop,Vector3(1,0,0),true)
	if t >= carry_start:
		_pose(_actors[0],t,Vector3(-2.9,0,0),_receiving(Vector3(0,0,-.70)),carry_start,carry_stop,toward_pile,true)
	var receiver: Vector3 = _receiving(Vector3(2.0,0,-.15))
	var greeter: Vector3 = _receiving(Vector3(.65,0,1.45))
	_pose(_actors[1],t,_receiving(Vector3(2.15,0,-1.4)),receiver,.25,1.8,_receiving_center-receiver)
	_pose(_actors[2],t,_receiving(Vector3(.2,0,2.0)),greeter,.3,1.5,-greeter)
	_greet(_actors[2], smoothstep(.8,1.3,t)*(1.0-smoothstep(2.8,3.5,t))*.85)
	var bed := _truck.position + (Vector3(-1.70,.85,0) if _has_convoy else Vector3(-1.2,1.50,0))
	var hands: Vector3 = _actors[0].transform * Vector3(0,.81,-.48)
	var lifted: float = smoothstep(pickup_stop-.05,carry_start-.1,t)
	_cargo.position = bed.lerp(hands,lifted)
	_cargo.rotation.y = lerp_angle(-PI/2.0,_actors[0].rotation.y,lifted)
	var placed: float = smoothstep(4.8,5.5,t)
	_cargo.position = _cargo.position.lerp(_receiving(Vector3(0,.265,0)),placed)
	_greet(_actors[1], sin(clampf((t-4.4)/1.2,0,1)*PI)*.33)

func _build_street(world_positions: Dictionary) -> void:
	# Panes sit inside three intact bays of the actual north facade. They are
	# narrowly bounded inserts, never another building or replacement world.
	var defaults: Array[Vector3] = [Vector3(-13.5,2.394,-22.85),Vector3(-9.5,2.394,-22.85),Vector3(-5.5,2.394,-22.85)]
	var requested: Variant = world_positions.get("window_origins", defaults)
	var windows: Array = requested if requested is Array else defaults
	for i in mini(windows.size(),3):
		var center: Vector3 = windows[i] if windows[i] is Vector3 and windows[i].is_finite() else defaults[i]
		if center.distance_to(position) > 12.0 or center.y < 1.3 or center.y > 6.0:
			continue
		var pane := BoxMesh.new()
		pane.size = Vector3(1.58,1.93,.018)
		var instance := _mesh_node(self,pane,"OccupiedWindow%d" % i,center-position)
		var material := StandardMaterial3D.new()
		material.albedo_color = Color("493f30")
		material.roughness = 1.0
		material.emission_enabled = true
		material.emission = WARM
		material.emission_energy_multiplier = 0
		instance.material_override = material
		instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_window_materials.append(material)
		var person := Node3D.new()
		person.name = "ResidentAtWindow%d" % i
		person.position = center-position+Vector3(-.22+float(i%2)*.4,-.54,.055)
		add_child(person)
		_batch(person,"ResidentSilhouette",[
			[Vector3(.35,.60,.13),Vector3(0,.17,0),Color("4b4a3d")],
			[Vector3(.12,.38,.11),Vector3(-.22,.08,0),Color("4b4a3d")],
			[Vector3(.12,.38,.11),Vector3(.22,.08,0),Color("4b4a3d")]
		],[[Vector3(0,.56,0),Vector3(0,.80,0),.145,Color("71644c")]])
		_window_people.append(person)
	# Salvaged civilian street lamps: merged pole, base and hood geometry, two
	# shadowless local lights. Existing world lights are left alone.
	for at in [Vector3(-3.3,0,.2),Vector3(2.9,0,1.3)]:
		_batch(self,"RestoredStreetLamp",[
			[Vector3(.46,.28,.46),at+Vector3(0,.14,0),Color("807e6b")],
			[Vector3(.92,.14,.48),at+Vector3(.37,3.55,0),DARK],
			[Vector3(.73,.04,.35),at+Vector3(.37,3.465,0),WARM]
		],[[at+Vector3(0,.28,0),at+Vector3(0,3.52,0),.065,STEEL]])
		var light := OmniLight3D.new()
		light.position = at+Vector3(.37,3.3,0)
		light.light_color = WARM
		light.light_energy = 0
		light.omni_range = 5.0
		light.omni_attenuation = 1.25
		light.shadow_enabled = false
		add_child(light)
		_lights.append(light)
	for title in ["StreetResident", "ReturningResident", "DoorwayNeighbor"]:
		_civilian(title)
	_prop("crate", self, Vector3(2.0,.265,-3.65))
	_prop("pail", self, Vector3(2.65,.225,-3.65))

func _sample_street(t: float) -> void:
	for i in _window_materials.size():
		var warm: float = smoothstep(.3+float(i)*.6,1.25+float(i)*.6,t)
		_window_materials[i].albedo_color = Color("493f30").lerp(WARM,warm)
		_window_materials[i].emission_energy_multiplier = warm*.50
		_window_people[i].visible = warm > .10
	for i in _lights.size():
		_lights[i].light_energy = smoothstep(.2+float(i)*.5,1.3+float(i)*.5,t)*1.15
	_pose(_actors[0],t,Vector3(-1.9,0,3.4),Vector3(-1.45,0,.1),.25,3.25,Vector3(1,0,-.3))
	_pose(_actors[1],t,Vector3(3.4,0,.15),Vector3(.9,0,-.8),.75,3.9,Vector3(-1,0,.1))
	_pose(_actors[2],t,Vector3(.7,0,-4.3),Vector3(1.6,0,-2.6),1.25,3.6,Vector3(-1,0,1))
	_greet(_actors[2],smoothstep(3.4,3.85,t)*(1.0-smoothstep(4.65,5.3,t))*.70)
