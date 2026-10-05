extends Control
## Render the finished station, unchanged, into an alpha-bearing 256px UI portrait.
## Launch this scene normally; it writes the PNG after 24 frames and exits.
var model_kind:String="central_station"
var output_path:String
var portrait_viewport: SubViewport
var frames: int = 0

func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--power-kind="):model_kind=arg.trim_prefix("--power-kind=")
	assert(model_kind in ["central_station","substation"])
	output_path="res://assets/ui/portrait_"+model_kind+".png"
	var background := ColorRect.new()
	background.color = Color("222b2a")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	var preview := SubViewportContainer.new()
	preview.position = Vector2(40, 60)
	preview.size = Vector2(256, 256)
	preview.stretch = false
	add_child(preview)
	portrait_viewport = SubViewport.new()
	portrait_viewport.size = Vector2i(256, 256)
	portrait_viewport.transparent_bg = true
	portrait_viewport.own_world_3d = true
	portrait_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	portrait_viewport.msaa_3d = Viewport.MSAA_4X
	preview.add_child(portrait_viewport)
	var world := Node3D.new()
	portrait_viewport.add_child(world)
	var model := (load("res://assets/models/"+model_kind+".glb") as PackedScene).instantiate() as Node3D
	world.add_child(model)
	var environment := WorldEnvironment.new()
	var settings := Environment.new()
	settings.background_mode = Environment.BG_COLOR
	settings.background_color = Color(0, 0, 0, 0)
	settings.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	settings.ambient_light_color = Color("a9b6c0")
	settings.ambient_light_energy = 0.53
	settings.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	settings.tonemap_exposure = 1.0
	environment.environment = settings
	world.add_child(environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48, -32, 0)
	sun.light_color = Color("dfddce")
	sun.light_energy = 1.08
	sun.shadow_enabled = true
	world.add_child(sun)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-32, 138, 0)
	fill.light_color = Color("8d9ba3")
	fill.light_energy = 0.22
	world.add_child(fill)
	var camera := Camera3D.new()
	world.add_child(camera)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.position = Vector3(37, 48, 43)
	camera.look_at(Vector3.ZERO)
	camera.current = true
	# Fit the actual mesh vertices, not the AABB's empty upper corners.
	var points: Array[Vector3] = []
	collect_vertices(model, points)
	var low := Vector2(INF, INF)
	var high := Vector2(-INF, -INF)
	for point in points:
		var projected := Vector2(point.dot(camera.global_basis.x), point.dot(camera.global_basis.y))
		low = low.min(projected)
		high = high.max(projected)
	var center := (low + high) * 0.5
	var target := camera.global_basis.x * center.x + camera.global_basis.y * center.y
	camera.position = target + Vector3(37, 48, 43)
	camera.look_at(target)
	camera.size = maxf(high.x-low.x, high.y-low.y) * 1.12
	print("POWER_FACILITY_PORTRAIT_FRAMING size=", camera.size, " projected_bounds=", low, "..", high)

func collect_vertices(node: Node, output: Array[Vector3]) -> void:
	if node is MeshInstance3D:
		var instance := node as MeshInstance3D
		for surface in range(instance.mesh.get_surface_count()):
			var vertices: PackedVector3Array = instance.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]
			for vertex in vertices:
				output.append(instance.global_transform * vertex)
	for child in node.get_children():
		collect_vertices(child, output)

func _process(_delta: float) -> void:
	frames += 1
	if frames == 24:
		await RenderingServer.frame_post_draw
		var image := portrait_viewport.get_texture().get_image()
		var result := image.save_png(output_path)
		print("POWER_FACILITY_PORTRAIT_CAPTURE ", result, " ", ProjectSettings.globalize_path(output_path), " ", image.get_size(), " alpha=", image.detect_alpha())
		get_tree().quit(0 if result == OK else 1)
