extends Node3D
## Original procedural art: a disused rail depot being reclaimed at dusk.
## All repeated structural pieces are batched by shape/material in MultiMeshes.

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
	var wall := "concrete_dark" if p.x > 0 else "concrete"
	_box(p+Vector3(0,size.y*0.5,0),size,wall)
	_box(p+Vector3(0,0.28,0),Vector3(size.x+0.45,0.55,size.z+0.45),"concrete_light")
	_box(p+Vector3(0,size.y-0.08,0),Vector3(size.x+0.32,0.25,size.z+0.32),"roof")
	# Roof recess and discontinuous parapet.
	_box(p+Vector3(0,size.y+0.04,0),Vector3(size.x-0.5,0.1,size.z-0.5),"void")
	for sx in [-1.0,1.0]:
		_box(p+Vector3(sx*(size.x*0.5-0.12),size.y+0.25,0),Vector3(0.25,0.6,size.z),wall)
	_box(p+Vector3(0,size.y+0.25,-size.z*0.5+0.12),Vector3(size.x,0.6,0.25),wall)
	_box(p+Vector3(-size.x*0.25,size.y+0.25,size.z*0.5-0.12),Vector3(size.x*0.5,0.6,0.25),wall)
	# Windows are dark inset fields with fine projecting mullions.
	var bays := maxi(2,int(size.x/2.0))
	for level in range(stories):
		var y := 1.6 + level*((size.y-1.8)/maxi(1,stories))
		_box(p+Vector3(0,y+0.98,size.z*0.5+0.035),Vector3(size.x+0.12,0.16,0.10),"concrete_light")
		for bay in range(bays):
			var x := -size.x*0.5+(bay+0.5)*size.x/bays
			var width := size.x/bays-0.48
			_box(p+Vector3(x,y,size.z*0.5+0.025),Vector3(width,1.35,0.06),"void")
			if _rng.randf() < 0.10:
				_box(p+Vector3(x-width*0.17,y+0.04,size.z*0.5+0.064),Vector3(width*0.54,1.15,0.028),"window_lit")
			else:
				_box(p+Vector3(x,y+0.2,size.z*0.5+0.064),Vector3(width*0.86,0.6,0.03),"glass")
			_box(p+Vector3(x,y,size.z*0.5+0.09),Vector3(0.08,1.36,0.08),"steel")
			_box(p+Vector3(x,y+0.02,size.z*0.5+0.09),Vector3(width,0.065,0.08),"steel")
		# Visible east facade.
		var side_bays := maxi(2,int(size.z/2.3))
		for bay in range(side_bays):
			var z := -size.z*0.5+(bay+0.5)*size.z/side_bays
			_box(p+Vector3(size.x*0.5+0.02,y,z),Vector3(0.06,1.25,size.z/side_bays-0.5),"void")
			if _rng.randf() < 0.055:
				_box(p+Vector3(size.x*0.5+0.065,y,z),Vector3(0.025,0.92,0.65),"window_lit")
	for bay in range(bays+1):
		var x := -size.x*0.5+bay*size.x/bays
		_box(p+Vector3(x,size.y*0.5,size.z*0.5+0.1),Vector3(0.18,size.y,0.22),"concrete_light")
	# Shutter, canopy, vents, exterior conduit and rooftop machinery.
	_box(p+Vector3(size.x*0.22,0.95,size.z*0.5+0.10),Vector3(2.0,1.8,0.10),"steel")
	for j in range(7):
		_box(p+Vector3(size.x*0.22,0.2+j*0.23,size.z*0.5+0.18),Vector3(1.94,0.035,0.08),"rust")
	_box(p+Vector3(size.x*0.22,2.13,size.z*0.5+0.65),Vector3(2.8,0.12,1.4),"rust")
	_box(p+Vector3(-size.x*0.42,size.y*0.5,size.z*0.5+0.24),Vector3(0.1,size.y,0.1),"rust_light")
	_box(p+Vector3(-size.x*0.18,size.y+0.5,-size.z*0.12),Vector3(2.1,0.85,1.45),"steel")
	for j in range(6):
		_box(p+Vector3(-size.x*0.18-0.78+j*0.3,size.y+0.94,-size.z*0.12),Vector3(0.08,0.03,1.3),"rust")
	# Tall narrow sign housing evokes an old Japanese workshop without illegible text.
	_box(p+Vector3(size.x*0.46,size.y*0.60,size.z*0.5+0.35),Vector3(0.5,2.6,0.48),"steel")
	_box(p+Vector3(size.x*0.46,size.y*0.60,size.z*0.5+0.605),Vector3(0.31,2.27,0.03),"yellow")
	for j in range(3):
		_box(p+Vector3(size.x*0.46,size.y*0.60-0.6+j*0.62,size.z*0.5+0.63),Vector3(0.23,0.05,0.02),"void")
	if damaged:
		# Jagged exposed upper-floor skeleton and fallen slab.
		var roof_y := size.y+0.4
		for j in range(3):
			_box(p+Vector3(size.x*0.24+j*0.63,roof_y+_rng.randf_range(0.15,0.8),size.z*0.38),Vector3(0.18,_rng.randf_range(0.8,2.2),0.18),"rust")
		_box(p+Vector3(size.x*0.3,size.y+0.37,size.z*0.05),Vector3(size.x*0.5,0.18,size.z*0.34),"concrete_light",Vector3(0.11,0.13,-0.12))
		_box(p+Vector3(-size.x*0.22,0.50,size.z*0.5+1.20),Vector3(2.5,0.36,1.5),"concrete",Vector3(0.27,-0.25,-0.16))

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
