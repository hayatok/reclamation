extends Node3D
## Original procedural art: a disused rail depot being reclaimed at dusk.
## All repeated structural pieces are batched by shape/material in MultiMeshes.

var occlusion_buildings: Array = []
var _capturing_building := false
var _captured_parts: Array[Dictionary] = []
var _building_window_materials: Array[StandardMaterial3D] = []

var _built := false
var _rng := RandomNumberGenerator.new()
var _materials: Dictionary = {}
var _batches: Dictionary = {}
var _surface_textures: Dictionary = {}

func _ready() -> void:
	setup()

func setup() -> void:
	if _built:
		return
	_built = true
	_rng.seed = 640279
	_make_surface_textures()
	_make_materials()
	_make_atmosphere()
	_make_ground()
	_make_district()
	_make_roads()
	_make_props()
	_make_ruins()
	_make_rail_siding()
	_flush_batches()

func _make_surface_textures() -> void:
	# Original, deterministic grayscale surfaces. World triplanar mapping keeps
	# aggregate grain at the same physical scale on walls, slabs and tiny debris.
	for kind in ["masonry", "asphalt", "metal", "marking"]:
		var noise := FastNoiseLite.new()
		noise.seed = 6100 + kind.length() * 71
		noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
		noise.frequency = 0.055
		noise.fractal_octaves = 4
		var grain := FastNoiseLite.new()
		grain.seed = 4702
		grain.frequency = 0.95
		var image := Image.create(128, 128, true, Image.FORMAT_RGB8)
		for y in range(128):
			for x in range(128):
				var broad := noise.get_noise_2d(float(x), float(y))
				var fine := grain.get_noise_2d(float(x), float(y))
				var value := 0.90 + broad * 0.14 + fine * 0.075
				if kind == "metal":
					var streak := noise.get_noise_2d(float(x) * 1.8, float(y) * 0.16)
					value = 0.86 + streak * 0.19 + fine * 0.035
				elif kind == "asphalt":
					value = 0.88 + broad * 0.065 + fine * 0.14
				elif kind == "marking":
					value = 0.78 + broad * 0.20 + fine * 0.14
				value = clampf(value, 0.55, 1.0)
				image.set_pixel(x, y, Color(value, value, value, 1.0))
		image.generate_mipmaps()
		_surface_textures[kind] = ImageTexture.create_from_image(image)

func _material(key: String, hex: String, rough: float = 0.94, glow: float = 0.0, surface: String = "") -> void:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(hex)
	m.roughness = rough
	m.vertex_color_use_as_albedo = true
	m.metallic_specular = 0.22
	if not surface.is_empty():
		m.albedo_texture = _surface_textures[surface]
		m.uv1_triplanar = true
		m.uv1_world_triplanar = true
		m.uv1_scale = Vector3(0.36, 0.36, 0.36)
		m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	if glow > 0.0:
		m.emission_enabled = true
		m.emission = Color(hex)
		m.emission_energy_multiplier = glow
	_materials[key] = m

func _make_materials() -> void:
	_material("ground", "#55554b", 0.98, 0.0, "masonry")
	_material("edge", "#30342f", 1.0, 0.0, "masonry")
	_material("road", "#2d3232", 0.99, 0.0, "asphalt")
	_material("repair", "#41443b", 0.98, 0.0, "asphalt")
	_material("concrete", "#777668", 0.97, 0.0, "masonry")
	_material("concrete_dark", "#575b52", 0.98, 0.0, "masonry")
	_material("concrete_light", "#999787", 0.95, 0.0, "masonry")
	_material("roof", "#424840", 0.96, 0.0, "metal")
	_material("steel", "#49514e", 0.86, 0.0, "metal")
	_material("rust", "#775641", 0.96, 0.0, "metal")
	_material("rust_light", "#927252", 0.95, 0.0, "metal")
	_material("void", "#1e2525")
	_material("glass", "#48514c", 0.58)
	_material("window_lit", "#c9bc96", 0.6, 0.36)
	_material("olive", "#626955", 0.95, 0.0, "metal")
	_material("amber", "#e6c296", 0.6, 1.25)
	_material("paint", "#a5a38d", 0.98, 0.0, "marking")
	_material("yellow", "#ae8d4d", 0.98, 0.0, "marking")
	_material("moss", "#555d48")
	_material("soil", "#383d32", 1.0, 0.0, "asphalt")
	_material("brick", "#755f4d", 1.0, 0.0, "masonry")
	_material("backdrop", "#3a4544")
	_material("soot", "#272a23", 1.0, 0.0, "masonry")
	_material("moss_dark", "#36452c", 1.0)

func _make_atmosphere() -> void:
	var env := WorldEnvironment.new()
	env.name = "DistrictAtmosphere"
	var settings := Environment.new()
	settings.background_mode = Environment.BG_COLOR
	settings.background_color = Color("#343d40")
	settings.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	settings.ambient_light_color = Color("#adb6b9")
	settings.ambient_light_energy = 0.43
	settings.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	settings.tonemap_exposure = 1.08
	settings.fog_enabled = true
	settings.fog_light_color = Color("#4b504a")
	settings.fog_light_energy = 0.55
	settings.fog_density = 0.0038
	settings.glow_enabled = false
	settings.glow_intensity = 0.65
	env.environment = settings
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.name = "LateAfternoonThroughSmog"
	sun.rotation_degrees = Vector3(-48.0, -32.0, 0.0)
	sun.light_color = Color("#edcda0")
	sun.light_energy = 1.25
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 105.0
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	add_child(sun)
	var fill := DirectionalLight3D.new()
	fill.name = "CoolSkyBounce"
	fill.rotation_degrees = Vector3(-32, 138, 0)
	fill.light_color = Color("#8d9ba3")
	fill.light_energy = 0.18
	fill.shadow_enabled = false
	add_child(fill)

func _make_ground() -> void:
	_box(Vector3(0, -0.60, 0), Vector3(66, 0.76, 66), "edge")
	_box(Vector3(0, -0.17, 0), Vector3(64, 0.14, 64), "ground")
	# Exposed concrete retaining edge. No decorative luminous diorama border.
	_box(Vector3(0, -0.39, 32.7), Vector3(65.2, 0.18, 0.28), "concrete_dark")
	_box(Vector3(32.7, -0.39, 0), Vector3(0.28, 0.18, 65.2), "concrete_dark")
	for i in range(9):
		var x := -28.0 + float(i) * 7.0
		_box(Vector3(x, -0.055, 0), Vector3(0.024, 0.012, 64), "concrete_dark")
		_box(Vector3(0, -0.055, x), Vector3(64, 0.012, 0.024), "concrete_dark")
	# Large old loading aprons, kept flat for gameplay sites.
	for p in [Vector3(0,0,8), Vector3(14,0,-5), Vector3(-14,0,-7)]:
		_box(p + Vector3(0,-0.06,0), Vector3(10,0.06,10), "concrete_dark")
		# Faded L-shaped loading marks, rather than bright interface-like boxes.
		for sx in [-1.0, 1.0]:
			for sz in [-1.0, 1.0]:
				_box(p + Vector3(sx * 5,-0.02,sz * 4.2), Vector3(0.09,0.012,1.6), "paint")
				_box(p + Vector3(sx * 4.2,-0.02,sz * 5), Vector3(1.6,0.012,0.09), "paint")
	# Broken off fragments around the outer front lip.
	for i in range(18):
		var x := _rng.randf_range(-31,31)
		_box(Vector3(x,-0.05,31.5), Vector3(_rng.randf_range(0.8,2.5),0.22,0.65), "concrete", Vector3(0,_rng.randf_range(-0.12,0.12),0))

func _make_roads() -> void:
	# T-shaped service roads leave three large industrial lots easy to read.
	_box(Vector3(0,-0.019,1.7), Vector3(63.5,0.055,5.6), "road")
	_box(Vector3(0,-0.014,-14), Vector3(5.6,0.055,27.0), "road")
	_box(Vector3(0,-0.015,22.0), Vector3(62.0,0.055,5.0), "road")
	for x in range(-30,31,4):
		if abs(x) > 3:
			_box(Vector3(x,0.021,1.7), Vector3(1.7,0.014,0.11), "yellow")
		_box(Vector3(x,0.021,22), Vector3(1.7,0.014,0.10), "paint")
	for z in range(-26,-3,4):
		_box(Vector3(0,0.022,z), Vector3(0.11,0.014,1.7), "yellow")
	for side in [-1.0,1.0]:
		_box(Vector3(0,0.02,1.7+side*2.55), Vector3(62.0,0.012,0.09), "paint")
		_box(Vector3(side*2.55,0.023,-14), Vector3(0.09,0.012,25.0), "paint")
		_box(Vector3(0,0.02,22+side*2.24), Vector3(61.0,0.012,0.08), "paint")
	# Zebra crossings in weathered ivory.
	for i in range(7):
		_box(Vector3(-3.65,0.04,-0.45 + i*0.65),Vector3(1.15,0.014,0.29),"paint")
		_box(Vector3(3.65,0.04,-0.45 + i*0.65),Vector3(1.15,0.014,0.29),"paint")
	# Thin curb runs are intentionally broken where routes lead to the lots.
	for x in [-26.0,-19.0,-8.0,8.0,19.0,26.0]:
		for z in [-1.35,4.75,19.2,24.8]:
			_box(Vector3(x,0.07,z),Vector3(4.5,0.18,0.22),"concrete")
	# Drain grates, road repair patches and hairline cracks.
	for x in [-26.0,-19.0,-10.0,11.0,20.0,28.0]:
		_box(Vector3(x,0.025,-0.75),Vector3(0.82,0.016,0.32),"void")
		for j in range(5):
			_box(Vector3(x-0.33+j*0.16,0.04,-0.75),Vector3(0.04,0.014,0.29),"steel")
	for i in range(22):
		var z: float = [1.7,22.0][_rng.randi_range(0,1)] + _rng.randf_range(-1.9,1.9)
		var p := Vector3(_rng.randf_range(-29,29),0.021,z)
		_box(p,Vector3(_rng.randf_range(0.4,2.3),0.01,_rng.randf_range(0.3,0.8)),"repair",Vector3(0,_rng.randf_range(-0.3,0.3),0))
	# Loading stripes outside the front open area.
	for x in [-22.0,22.0]:
		for i in range(7):
			_box(Vector3(x-2.2+i*0.7,0.02,14.4),Vector3(0.18,0.014,3.0),"yellow",Vector3(0,-0.5,0))

func _make_district() -> void:
	# Main rear factories: modules have masonry columns, recesses and damaged crowns.
	_building(Vector3(-23,0,-23),Vector3(12,11.2,11),3,true)
	_building(Vector3(-9.5,0,-26.8),Vector3(10,8.4,8),2,false)
	_building(Vector3(7.8,0,-26.5),Vector3(12,14.6,8.4),4,true)
	_building(Vector3(23.5,0,-22.5),Vector3(11,10.0,11),3,true)
	_building(Vector3(-28.1,0,-7),Vector3(6.4,8.5,14),2,true)
	_building(Vector3(28.2,0,-5),Vector3(6.4,6.8,13),2,false)
	# Front-corner ruins stay low to preserve the isometric playfield view.
	_building(Vector3(-27.5,0,14.5),Vector3(6.0,4.1,7),1,true)
	_building(Vector3(28,0,14),Vector3(5.5,3.2,6.5),1,true)
	# Broken industrial bridge over the rear service road.
	_box(Vector3(-2.9,6.8,-25),Vector3(4.4,0.4,2.7),"rust",Vector3(0,0,-0.10))
	_box(Vector3(2.1,5.65,-25),Vector3(3.0,0.4,2.7),"rust",Vector3(0,0,0.43))
	for z in [-26.15,-23.85]:
		_beam(Vector3(-5.1,8.5,z),Vector3(-0.9,7.9,z),0.13,"steel")
		_beam(Vector3(-5.1,7,z),Vector3(-0.9,6.5,z),0.13,"steel")
		for x in [-4.8,-3.7,-2.6,-1.5]:
			_box(Vector3(x,7.5,z),Vector3(0.10,1.2,0.10),"steel")
	# Rear smokestacks and a dormant crane silhouette.
	for x in [-20.0,19.5]:
		_cylinder(Vector3(x,11,-30),Vector3(0.8,22,0.8),"rust")
		for y in [7.0,12.0,17.0,21.2]:
			_cylinder(Vector3(x,y,-30),Vector3(0.88,0.18,0.88),"steel")
		_cylinder(Vector3(x,22.08,-30),Vector3(0.82,0.15,0.82),"void")
	_crane(Vector3(-30,0,-30))
	# Fogged city silhouette behind the bounded playable city block.
	for i in range(16):
		var x := -54.0+i*7.0
		var h := _rng.randf_range(8,24)
		_box(Vector3(x,h*0.5,-47-_rng.randf_range(0,6)),Vector3(_rng.randf_range(4,7),h,_rng.randf_range(5,9)),"backdrop")
		if i%3 == 0:
			_box(Vector3(x,h+1.4,-48),Vector3(0.18,3.0,0.18),"backdrop")

func _building(p: Vector3, size: Vector3, stories: int, damaged: bool) -> void:
	_captured_parts.clear()
	_capturing_building = true
	_building_geometry(p, size, stories, damaged)
	_capturing_building = false
	_bake_building()

func _bake_building() -> void:
	var solid := SurfaceTool.new()
	var windows := SurfaceTool.new()
	solid.begin(Mesh.PRIMITIVE_TRIANGLES)
	windows.begin(Mesh.PRIMITIVE_TRIANGLES)
	var solid_vertices: int = 0
	var window_vertices: int = 0
	var low := Vector3(INF,INF,INF)
	var high := Vector3(-INF,-INF,-INF)
	var building_index: int = occlusion_buildings.size()
	var wear_rng := RandomNumberGenerator.new()
	wear_rng.seed = 9253 + building_index * 19
	for part: Dictionary in _captured_parts:
		var primitive: PrimitiveMesh
		if part.shape == "cylinder":
			var cylinder := CylinderMesh.new()
			cylinder.top_radius=1.0
			cylinder.bottom_radius=1.0
			cylinder.height=1.0
			cylinder.radial_segments=10
			primitive=cylinder
		else:
			var cube := BoxMesh.new()
			cube.size=Vector3.ONE
			primitive=cube
		var arrays: Array = primitive.get_mesh_arrays()
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		var transform: Transform3D = part.transform
		var normal_basis: Basis = transform.basis.inverse().transposed()
		var is_window: bool = part.mat in ["glass","window_lit"]
		var surface: SurfaceTool = windows if is_window else solid
		var source: StandardMaterial3D = _materials[part.mat]
		var tint: Color = source.albedo_color
		var wear: float = 1.0 if is_window else wear_rng.randf_range(.86,1.0)
		tint *= Color(wear,wear,wear*.985,1.0)
		for j in range(indices.size() if not indices.is_empty() else vertices.size()):
			var index: int = indices[j] if not indices.is_empty() else j
			var vertex: Vector3 = transform * vertices[index]
			low=low.min(vertex)
			high=high.max(vertex)
			surface.set_color(tint)
			surface.set_normal((normal_basis * normals[index]).normalized())
			surface.add_vertex(vertex)
			if is_window: window_vertices+=1
			else: solid_vertices+=1
	var meshes: Array[MeshInstance3D] = []
	var materials: Array[StandardMaterial3D] = []
	for entry in [[solid,solid_vertices,false],[windows,window_vertices,true]]:
		if int(entry[1])==0: continue
		var surface: SurfaceTool = entry[0]
		var is_window: bool = entry[2]
		var material := StandardMaterial3D.new()
		material.vertex_color_use_as_albedo=true
		material.roughness=.58 if is_window else .96
		material.metallic_specular=.22
		if not is_window:
			# Preserve procedural world-space masonry grain on the consolidated shell.
			material.albedo_texture=_surface_textures["masonry"]
			material.uv1_triplanar=true
			material.uv1_world_triplanar=true
			material.uv1_scale=Vector3(.36,.36,.36)
			material.texture_filter=BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		else:
			_building_window_materials.append(material)
		var instance := MeshInstance3D.new()
		instance.name="OccludableBuilding_%02d_%s" % [building_index,"Windows" if is_window else "Shell"]
		surface.set_material(material)
		surface.index()
		instance.mesh=surface.commit()
		instance.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF if is_window else GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		instance.set_meta(&"rest_shadow",instance.cast_shadow)
		add_child(instance)
		meshes.append(instance)
		materials.append(material)
	var bounds := AABB(low,high-low)
	occlusion_buildings.append({"bounds":global_transform*bounds,"local_bounds":bounds,"meshes":meshes,"materials":materials,"alpha":1.0})
	_captured_parts.clear()

## Compatibility renderer supported. Each building owns its materials; no shared-world fade.
func set_building_fade(index: int, alpha: float) -> void:
	if index<0 or index>=occlusion_buildings.size(): return
	alpha=clampf(alpha,0.0,1.0) if is_finite(alpha) else 1.0
	var building: Dictionary = occlusion_buildings[index]
	if absf(float(building.alpha)-alpha)<.001: return
	building.alpha=alpha
	for material: StandardMaterial3D in building.materials:
		var color: Color = material.albedo_color
		color.a=alpha
		material.albedo_color=color
		material.transparency=BaseMaterial3D.TRANSPARENCY_DISABLED if alpha>=.999 else BaseMaterial3D.TRANSPARENCY_ALPHA
	for mesh: MeshInstance3D in building.meshes:
		mesh.cast_shadow=mesh.get_meta(&"rest_shadow") if alpha>=.999 else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func _building_geometry(p: Vector3, size: Vector3, stories: int, damaged: bool) -> void:
	# Ruined hollow shells, not pristine blocks with decorative damage on top.
	# Existing locations and bounding footprints are retained; all pieces are render-only.
	var wall := "concrete_dark" if p.x > 0 else "concrete"
	var bays := maxi(3,int(size.x / 2.0))
	var bay_width: float = size.x / float(bays)
	var storey_height: float = size.y / float(stories)
	var severe: bool = damaged and (p.x > 0 or p.z > -15)
	var breach_start: int = maxi(1, bays - (3 if severe else 2))
	var front: float = size.z * .5
	var side: float = size.x * .5
	_box(p+Vector3(0,.20,0),Vector3(size.x+.35,.4,size.z+.35),"concrete_dark")
	# Back wall remains in place to provide dark interiors behind missing rooms.
	_box(p+Vector3(0,size.y*.44,-front+.16),Vector3(size.x,size.y*.88,.32),"soot")
	_box(p+Vector3(-side+.15,size.y*.44,0),Vector3(.3,size.y*.88,size.z),wall)
	for floor_index in range(stories+1):
		var y:float=maxf(.25,float(floor_index)*storey_height)
		var upper:bool=floor_index>=stories-1
		# Half the roof is completely absent. Remaining slabs expose open floor plates.
		var slab_width:float=size.x*(.47 if upper and damaged else .93)
		var slab_x:float=-size.x*.25 if upper and damaged else 0.0
		_box(p+Vector3(slab_x,y,0),Vector3(slab_width,.22,size.z*.94),"soot" if floor_index==stories else "concrete_dark")
		if floor_index>0 and floor_index<stories:
			_box(p+Vector3(size.x*.28,y-.25,size.z*.10),Vector3(size.x*.34,.22,size.z*.62),"concrete",Vector3(.08,.06,.15 if floor_index%2 else -.18))
	# Masonry piers and intact bays contrast with two-storey open breaches.
	for bay in range(bays):
		var x:float=-side+(float(bay)+.5)*bay_width
		var broken:bool=damaged and bay>=breach_start
		var height:float=size.y-(storey_height*(.58+float(bay%2)*.6) if broken else 0.0)
		_box(p+Vector3(x-bay_width*.48,height*.5,front),Vector3(.26,height,.42),"concrete_dark" if broken else wall)
		for level in range(stories):
			var y:float=float(level)*storey_height
			var breached:bool=broken and level>=maxi(0,stories-2)
			if not breached:
				_box(p+Vector3(x,y+.48,front),Vector3(bay_width-.24,.95,.30),"brick" if (bay+level)%3==0 else wall)
				_box(p+Vector3(x,y+storey_height-.23,front),Vector3(bay_width-.23,.43,.33),"soot" if (bay+level)%3==1 else wall)
				_box(p+Vector3(x,y+storey_height*.57,front-.09),Vector3(bay_width-.35,storey_height*.48,.035),"void")
				# Surviving mullions are bent/missing; glass is rarely present.
				if (bay+level)%3==0:
					_box(p+Vector3(x,y+storey_height*.56,front+.02),Vector3(.06,storey_height*.48,.06),"rust",Vector3(0,0,.11))
				elif (bay+level)%4==0:
					_box(p+Vector3(x-.2,y+storey_height*.58,front-.06),Vector3(bay_width*.35,storey_height*.28,.025),"glass")
			else:
				# Broken sill stubs and crooked reinforcement delineate the missing facade.
				_box(p+Vector3(x-bay_width*.27,y+.3,front),Vector3(bay_width*.38,.55,.36),"brick",Vector3(0,0,-.16))
				_beam(p+Vector3(x-.15,y+.15,front),p+Vector3(x+.2,y+storey_height*.7,front+.12),.045,"rust")
				_box(p+Vector3(x,y+.20,front-.9),Vector3(bay_width*.8,.18,1.7),"soot",Vector3(.17,0,.09))
		# Broad soot columns interrupt the remaining pale facade at gameplay zoom.
		if bay%2==0 and not broken:
			_box(p+Vector3(x-bay_width*.42,size.y*.40,front+.23),Vector3(.43,size.y*.69,.018),"soot")
		if broken:
			_beam(p+Vector3(x,height,front),p+Vector3(x+.20,height+1.1,front-.12),.05,"rust")
	# Visible east wall gets a large missing upper corner rather than uniform windows.
	var side_bays:int=maxi(3,int(size.z/2.3))
	var side_width:float=size.z/float(side_bays)
	for bay in range(side_bays):
		var z:float=-front+(float(bay)+.5)*side_width
		var upper_missing:bool=damaged and bay>=side_bays-2
		var height:float=size.y*.52 if upper_missing else size.y*.92
		_box(p+Vector3(side,height*.5,z-side_width*.47),Vector3(.35,height,.25),wall)
		for level in range(stories):
			if upper_missing and level>=maxi(1,stories-1):continue
			var y:float=float(level)*storey_height
			_box(p+Vector3(side,y+.5,z),Vector3(.30,.95,side_width-.20),"soot" if bay%2==0 else wall)
			_box(p+Vector3(side,y+storey_height-.23,z),Vector3(.31,.4,side_width-.2),wall)
			_box(p+Vector3(side+.025,y+storey_height*.57,z),Vector3(.035,storey_height*.48,side_width-.3),"void")
	# Fallen roofing bends INTO the existing footprint and changes the dominant skyline.
	if damaged:
		_box(p+Vector3(size.x*.19,size.y*.73,size.z*.05),Vector3(size.x*.46,.24,size.z*.72),"roof",Vector3(.22,.08,-.38))
		_box(p+Vector3(size.x*.32,.48,front-.50),Vector3(size.x*.42,.32,1.8),"concrete",Vector3(.21,.2,-.14))
		for i in range(4):
			_box(p+Vector3(size.x*.13+float(i)*.42,.30+float(i%2)*.15,front-.12),Vector3(.75,.45,.68),"brick" if i%2 else "concrete_dark",Vector3(.12,float(i)*.5,.12))
	# Large, irregular overgrowth strips climb two bays rather than tiny ground confetti.
	for section in range(2):
		var x:float=-side+bay_width*(.25+float(section)*1.35)
		var vine_height:float=size.y*(.59 if section==0 else .36)
		_box(p+Vector3(x,vine_height*.5,front+.27),Vector3(.15,vine_height,.10),"moss_dark",Vector3(0,0,.08))
		for clump in range(5):
			var y:float=.5+float(clump)*vine_height*.19
			_box(p+Vector3(x+sin(float(clump)*2)*.28,y,front+.31),Vector3(.65+float(clump%2)*.32,.64,.22),"moss_dark" if clump%2 else "moss",Vector3(0,.15,float(clump)*.16))
	# Remaining corrugated shutter is visibly buckled and canopy has dropped one end.
	_box(p+Vector3(-size.x*.20,.95,front+.1),Vector3(1.8,1.6,.1),"rust",Vector3(0,0,.09))
	_box(p+Vector3(-size.x*.20,1.86,front+.45),Vector3(2.5,.12,1.1),"rust",Vector3(.16,0,-.18))

func _crane(p: Vector3) -> void:
	for dx in [-0.9,0.9]:
		for dz in [-0.9,0.9]:
			_box(p+Vector3(dx,9,dz),Vector3(0.18,18,0.18),"rust")
	for i in range(6):
		var y := float(i)*3
		for dz in [-0.9,0.9]:
			_beam(p+Vector3(-0.9,y,dz),p+Vector3(0.9,y+3,dz),0.11,"rust")
		_box(p+Vector3(0,y,0),Vector3(2.2,0.14,2.2),"steel")
	_box(p+Vector3(5,18,0),Vector3(14,0.20,0.6),"rust_light")
	_box(p+Vector3(5,19.1,0),Vector3(14,0.14,0.4),"rust")
	for i in range(7):
		_beam(p+Vector3(-2+i*2,18,0),p+Vector3(i*2,19.1,0),0.10,"rust")
	_beam(p+Vector3(10,18,0),p+Vector3(10,11,0),0.035,"steel")
	_box(p+Vector3(-1.6,17.3,0),Vector3(2.4,1.6,2.0),"steel")

func _make_props() -> void:
	# Amber pools of light along the old service roads.
	for p in [Vector3(-20,0,5.5),Vector3(21,0,5.5),Vector3(-7,0,18.5),Vector3(10,0,18.5),Vector3(-4,0,-18)]:
		_box(p+Vector3(0,0.22,0),Vector3(0.65,0.45,0.65),"concrete")
		_cylinder(p+Vector3(0,2.5,0),Vector3(0.12,5.0,0.12),"steel")
		_box(p+Vector3(0.65,5,0),Vector3(1.5,0.10,0.10),"steel")
		_box(p+Vector3(1.25,4.96,0),Vector3(0.75,0.14,0.35),"steel")
		_box(p+Vector3(1.25,4.87,0),Vector3(0.64,0.045,0.29),"amber")
		var lamp := OmniLight3D.new()
		lamp.position = p+Vector3(1.25,4.65,0)
		lamp.light_color = Color("#dfbb88")
		lamp.light_energy = 0.65
		lamp.omni_range = 7.5
		lamp.omni_attenuation = 1.35
		lamp.shadow_enabled = false
		add_child(lamp)
	# Railings and striped safety bollards at front loading lane.
	for x in [-24.0,-15.0,16.0,25.0]:
		for j in range(4):
			_box(Vector3(x-1.8+j*1.2,0.52,27),Vector3(0.1,1.1,0.1),"steel")
		_box(Vector3(x,0.8,27),Vector3(4.0,0.13,0.13),"rust")
		_box(Vector3(x,0.3,27),Vector3(4.0,0.09,0.10),"steel")
	for p in [Vector3(-19,0,-1.5),Vector3(-9,0,-1.5),Vector3(9,0,-1.5),Vector3(19,0,-1.5),Vector3(-4,0,6),Vector3(4,0,6)]:
		_cylinder(p+Vector3(0,0.43,0),Vector3(0.16,0.9,0.16),"yellow")
		_cylinder(p+Vector3(0,0.62,0),Vector3(0.165,0.2,0.165),"steel")
	# Old freight containers deliberately confined to side strips.
	_container(Vector3(-25,0,6),Vector3(3.2,2.4,4.2),"rust")
	_container(Vector3(24,0,8.3),Vector3(3,2.25,4.8),"olive")
	# Exposed rear district pipework.
	for x in [-17.0,17.0]:
		_beam(Vector3(x,1,-17.5),Vector3(x,4.5,-17.5),0.30,"rust")
		_beam(Vector3(x,4.5,-17.5),Vector3(x,4.5,-23),0.30,"rust")
		for z in [-18.2,-20.2,-22.2]:
			_box(Vector3(x,2.2,z),Vector3(0.10,4.4,0.10),"steel")
	# A few broken utility poles and restrained cables frame the playfield.
	for p in [Vector3(-23,0,19),Vector3(24,0,20),Vector3(-25,0,-15)]:
		_box(p+Vector3(0,3.2,0),Vector3(0.20,6.4,0.20),"rust")
		_box(p+Vector3(0,5.8,0),Vector3(2.0,0.14,0.14),"steel")
		for x in [-0.72,0.72]:
			_box(p+Vector3(x,5.95,0),Vector3(0.18,0.26,0.18),"concrete_light")
	# Sparse bushes and reclaimed cracks; flat clumps cannot obscure units.
	for p in [Vector3(-19,0,12),Vector3(19,0,15.5),Vector3(-22,0,-15),Vector3(23,0,-13),Vector3(-18,0,26),Vector3(13,0,27)]:
		for i in range(7):
			_box(p+Vector3(_rng.randf_range(-1.4,1.4),0.12,_rng.randf_range(-0.8,0.8)),Vector3(_rng.randf_range(0.35,0.8),_rng.randf_range(0.12,0.40),_rng.randf_range(0.35,0.8)),"moss",Vector3(0,_rng.randf()*PI,0))

func _container(p: Vector3, size: Vector3, mat: String) -> void:
	_box(p+Vector3(0,size.y*0.5,0),size,mat)
	for i in range(10):
		var z := -size.z*0.5+i*size.z/9.0
		for x in [-size.x*0.5-0.02,size.x*0.5+0.02]:
			_box(p+Vector3(x,size.y*0.5,z),Vector3(0.06,size.y,0.055),"steel")
	_box(p+Vector3(0,size.y+0.025,0),Vector3(size.x+0.10,0.1,size.z+0.10),"roof")
	_box(p+Vector3(0,size.y*0.5,size.z*0.5+0.06),Vector3(0.045,size.y,0.07),"steel")
	for x in [-size.x*0.35,size.x*0.35]:
		_box(p+Vector3(x,size.y*0.5,size.z*0.5+0.06),Vector3(0.065,size.y*0.88,0.075),"steel")

func _make_ruins() -> void:
	# Localized debris fields, rather than visual noise over the entire map.
	for center in [Vector3(-21,0,-15),Vector3(22,0,-15),Vector3(-24,0,12),Vector3(24,0,17),Vector3(-13,0,-21),Vector3(13,0,-21),Vector3(-28,0,25),Vector3(28,0,26)]:
		_box(center+Vector3(0,-0.01,0),Vector3(5,0.035,3.3),"soil",Vector3(0,_rng.randf_range(-0.4,0.4),0))
		for i in range(19):
			var s := _rng.randf_range(0.20,0.9)
			var offset := Vector3(_rng.randf_range(-2.2,2.2),s*0.25,_rng.randf_range(-1.4,1.4))
			var mat: String = ["concrete","concrete_dark","brick","rust"][_rng.randi_range(0,3)]
			_box(center+offset,Vector3(s*1.3,s*0.55,s*0.8),mat,Vector3(_rng.randf_range(-0.3,0.3),_rng.randf()*PI,_rng.randf_range(-0.3,0.3)))
		for i in range(3):
			_box(center+Vector3(_rng.randf_range(-1.6,1.6),0.24,_rng.randf_range(-1,1)),Vector3(2.2,0.09,0.13),"rust",Vector3(0,_rng.randf()*PI,_rng.randf_range(-0.22,0.22)))
	# A collapsed wall with exposed steel ribs on the rear-left loading yard.
	for i in range(6):
		var h := _rng.randf_range(0.5,1.8)
		_box(Vector3(-19+i*0.72,h*0.5,-19),Vector3(0.68,h,0.38),"concrete_light")
		_box(Vector3(-19+i*0.72,h+0.3,-19),Vector3(0.04,0.6,0.04),"rust")

func _make_rail_siding() -> void:
	# A derelict freight siding identifies the district's working history.
	# It stays at the front perimeter, away from every gameplay footprint.
	_box(Vector3(0,-0.035,28.5),Vector3(60,0.08,2.65),"soil")
	for i in range(36):
		var x := -29.0 + float(i) * 1.66
		_box(Vector3(x,0.075,28.5),Vector3(0.22,0.18,2.25),"roof",Vector3(0,_rng.randf_range(-0.025,0.025),0))
		for z in [27.9,29.1]:
			_box(Vector3(x,0.18,z),Vector3(0.32,0.055,0.27),"rust")
	for z in [27.9,29.1]:
		_box(Vector3(0,0.24,z),Vector3(60,0.10,0.11),"rust_light")
		_box(Vector3(0,0.19,z),Vector3(60,0.06,0.07),"steel")
	for x in [-29.5,29.5]:
		for z in [27.95,29.05]:
			_beam(Vector3(x,0.2,z),Vector3(x+0.5,1.0,z),0.12,"steel")
		_box(Vector3(x+0.5,0.98,28.5),Vector3(0.18,0.26,1.6),"rust")
		_box(Vector3(x+0.59,0.99,28.5),Vector3(0.035,0.12,1.15),"yellow")
	# Faded repair seams and irregular fracture lines remain subtle under units.
	for origin in [Vector3(-17,0.04,17),Vector3(18,0.04,-14),Vector3(-7,0.04,25),Vector3(22,0.04,0)]:
		var p: Vector3 = origin
		for i in range(4):
			var q := p+Vector3(_rng.randf_range(0.3,0.85),0,_rng.randf_range(-0.5,0.5))
			_beam(p,q,0.026,"void")
			p = q
	# Perimeter jersey barriers: low, functional, weathered ochre corners.
	for p in [Vector3(-25,0,25.5),Vector3(-19,0,25.5),Vector3(20,0,25.5),Vector3(26,0,25.5)]:
		_box(p+Vector3(0,0.23,0),Vector3(2.9,0.46,0.63),"concrete_dark")
		_box(p+Vector3(0,0.65,0),Vector3(2.75,0.44,0.33),"concrete")
		for x in [-1.1,1.1]:
			_box(p+Vector3(x,0.66,0.178),Vector3(0.26,0.28,0.02),"yellow")

func _box(pos: Vector3, size: Vector3, mat: String, rot: Vector3 = Vector3.ZERO) -> void:
	var basis := Basis.from_euler(rot).scaled(size)
	_add_instance("box",mat,Transform3D(basis,pos))

func _cylinder(pos: Vector3, size: Vector3, mat: String) -> void:
	_add_instance("cylinder",mat,Transform3D(Basis.IDENTITY.scaled(size),pos))

func _beam(a: Vector3, b: Vector3, thickness: float, mat: String) -> void:
	var axis := b-a
	var length := axis.length()
	if length < 0.001:
		return
	var up := axis/length
	var helper := Vector3.RIGHT if absf(up.dot(Vector3.RIGHT)) < 0.95 else Vector3.FORWARD
	var right := helper.cross(up).normalized()
	var back := right.cross(up).normalized()
	var basis := Basis(right*thickness,up*length,back*thickness)
	_add_instance("box",mat,Transform3D(basis,(a+b)*0.5))

func _add_instance(shape: String, mat: String, transform: Transform3D) -> void:
	if _capturing_building:
		_captured_parts.append({"shape":shape,"mat":mat,"transform":transform})
		return
	var key := shape+":"+mat
	if not _batches.has(key):
		_batches[key] = []
	_batches[key].append(transform)

func _flush_batches() -> void:
	for key in _batches:
		var parts: PackedStringArray = key.split(":")
		var shape := parts[0]
		var mat := parts[1]
		var mesh: PrimitiveMesh
		if shape == "cylinder":
			var cylinder := CylinderMesh.new()
			cylinder.top_radius = 1.0
			cylinder.bottom_radius = 1.0
			cylinder.height = 1.0
			cylinder.radial_segments = 10
			mesh = cylinder
		else:
			var cube := BoxMesh.new()
			cube.size = Vector3.ONE
			mesh = cube
		mesh.material = _materials[mat]
		var batch := MultiMesh.new()
		batch.transform_format = MultiMesh.TRANSFORM_3D
		batch.use_colors = true
		batch.mesh = mesh
		batch.instance_count = _batches[key].size()
		var wear_rng := RandomNumberGenerator.new()
		wear_rng.seed = 9253 + mat.length() * 18
		for i in range(batch.instance_count):
			batch.set_instance_transform(i,_batches[key][i])
			# Low-contrast tonal variation breaks mass-produced miniature repetition.
			var wear := wear_rng.randf_range(0.86, 1.0)
			if mat in ["window_lit", "amber", "backdrop", "road", "ground"]:
				wear = 1.0
			batch.set_instance_color(i, Color(wear, wear, wear * 0.985, 1.0))
		var node := MultiMeshInstance3D.new()
		node.name = "District_"+shape+"_"+mat
		node.multimesh = batch
		if mat in ["glass","void","window_lit","amber","paint","yellow","road","repair","soil","backdrop"]:
			node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(node)
	_batches.clear()

func restore_district_lights() -> void:
	# Independent glass materials brighten without racing the occlusion fade alpha.
	var surfaces: Array[StandardMaterial3D] = []
	for key in ["glass", "window_lit"]: surfaces.append(_materials[key])
	surfaces.append_array(_building_window_materials)
	for surface: StandardMaterial3D in surfaces:
		surface.emission_enabled=true
		surface.emission=Color("e3b86b")
		var start: Color = surface.albedo_color
		var target := Color("d3b16e")
		var tween=create_tween().set_parallel(true)
		tween.tween_property(surface,"emission_energy_multiplier",1.8,1.8)
		tween.tween_method(func(progress: float):
			var current: Color = surface.albedo_color
			current.r=lerpf(start.r,target.r,progress)
			current.g=lerpf(start.g,target.g,progress)
			current.b=lerpf(start.b,target.b,progress)
			surface.albedo_color=current
		,0.0,1.0,1.8)
