extends RefCounted
## Three original freight ruins, authored in meters at the existing shell sizes.
## All parts go through world_art's normal capture/bake path: one solid mesh and
## optional glazing per shell, with the same independent materials and fade API.
## No collision, gameplay nodes, lights, labels, random calls or outside props.

static func handles(shell_id: String) -> bool:
	return shell_id in ["freight_warehouse", "freight_annex", "freight_office"]

static func build(world, shell: Dictionary) -> void:
	world._captured_parts.clear()
	world._capturing_building = true
	match String(shell.id):
		"freight_warehouse":
			_warehouse(world, shell.pos, shell.size / Vector3(12, 6.8, 11))
		"freight_annex":
			_annex(world, shell.pos, shell.size / Vector3(11, 5.4, 9))
		"freight_office":
			_dispatch(world, shell.pos, shell.size / Vector3(12, 8.2, 12))
	world._capturing_building = false
	world._bake_building()

static func _part(world, p: Vector3, scale: Vector3, at: Vector3, size: Vector3,
		material: String, rotation: Vector3 = Vector3.ZERO) -> void:
	# Scale in the panel's local axes before pitching it. Global-axis scaling of a
	# rotated long roof box would widen it past the unchanged foundation.
	var basis := Basis.from_euler(rotation) * Basis.from_scale(size * scale)
	world._add_instance("box", material, Transform3D(basis, p + at * scale))

static func _beam(world, p: Vector3, scale: Vector3, a: Vector3, b: Vector3,
		width: float, material: String = "rust") -> void:
	world._beam(p + a * scale, p + b * scale, width, material)

static func _roof_pitch(world, p: Vector3, scale: Vector3, a: Vector2,
		b: Vector2, z: float, depth: float, material: String = "roof") -> void:
	# A continuous broad pitched sheet. Its X/Y endpoints define the roof profile.
	var delta := b - a
	_part(world, p, scale, Vector3((a.x + b.x) * 0.5, (a.y + b.y) * 0.5, z),
		Vector3(delta.length(), 0.22, depth), material, Vector3(0, 0, delta.angle()))

static func _warehouse(w, p: Vector3, s: Vector3) -> void:
	# Three sawtooth trusses and three tall loading mouths, with one roof bay gone.
	# The missing southeast sheet reveals the interior instead of a second floor.
	_part(w, p, s, Vector3(0, 0.22, 0), Vector3(12.15, 0.40, 11.15), "concrete_dark")
	_part(w, p, s, Vector3(0, 0.20, 5.72), Vector3(11.85, 0.34, 0.88), "concrete")
	_part(w, p, s, Vector3(0, 2.15, -5.18), Vector3(11.65, 4.05, 0.38), "soot")
	_part(w, p, s, Vector3(-5.69, 2.18, 0), Vector3(0.40, 4.10, 10.50), "concrete")
	_part(w, p, s, Vector3(-5.46, 0.75, 0), Vector3(0.08, 0.98, 10.10), "rust")
	# Four massive pier silhouettes frame openings about 3.25 m wide and 3.7 m tall.
	for x: float in [-5.62, -1.90, 1.90, 5.62]:
		var height: float = 3.62 if x > 5.0 else 4.25
		_part(w, p, s, Vector3(x, 0.20 + height * 0.5, 5.04), Vector3(0.52, height, 0.58), "concrete")
		_part(w, p, s, Vector3(x, 0.68, 5.08), Vector3(0.64, 0.94, 0.63), "concrete_dark")
	_part(w, p, s, Vector3(-1.85, 4.30, 5.00), Vector3(7.95, 0.54, 0.55), "concrete")
	_beam(w, p, s, Vector3(1.95, 4.28, 5.0), Vector3(5.53, 3.48, 5.0), 0.32)
	# The east face stays open between braced frames; no apartment window rhythm.
	for z: float in [-4.98, -1.45, 2.05]:
		_part(w, p, s, Vector3(5.67, 2.25, z), Vector3(0.40, 4.12, 0.43), "concrete_dark")
	_part(w, p, s, Vector3(5.63, 0.75, -3.25), Vector3(0.33, 1.10, 3.48), "concrete")
	_beam(w, p, s, Vector3(5.63, 0.48, -4.90), Vector3(5.63, 4.26, -1.43), 0.23)
	_beam(w, p, s, Vector3(5.63, 4.26, -4.90), Vector3(5.63, 4.26, 1.94), 0.27)
	# Two intact asymmetric teeth: 1.8 m rises read in silhouette at normal zoom.
	for tooth in range(2):
		var left: float = -5.78 + float(tooth) * 3.82
		var right: float = left + 3.70
		_roof_pitch(w, p, s, Vector2(left, 4.55), Vector2(right, 6.52), -0.08, 10.38)
		_part(w, p, s, Vector3(right - 0.06, 5.39, -0.08), Vector3(0.16, 1.68, 10.34), "void")
		_part(w, p, s, Vector3(right + 0.03, 4.58, -0.08), Vector3(0.28, 0.23, 10.44), "rust")
		for z: float in [-4.93, 0.02, 4.98]:
			_beam(w, p, s, Vector3(left, 4.43, z), Vector3(right, 6.43, z), 0.22)
			_beam(w, p, s, Vector3(left, 4.40, z), Vector3(right, 4.40, z), 0.24, "steel")
			_beam(w, p, s, Vector3(right, 4.40, z), Vector3(right, 6.43, z), 0.24)
	# Rear remnant of the third tooth, a large hole, and an inward fallen roof sheet.
	_roof_pitch(w, p, s, Vector2(1.90, 4.55), Vector2(5.63, 6.52), -3.11, 4.18, "rust")
	_part(w, p, s, Vector3(5.56, 5.40, -3.12), Vector3(0.15, 1.65, 4.16), "void")
	_beam(w, p, s, Vector3(1.93, 4.45, 1.72), Vector3(5.53, 6.39, 1.72), 0.28)
	_beam(w, p, s, Vector3(1.92, 4.40, 4.92), Vector3(4.64, 3.04, 4.70), 0.29)
	_roof_pitch(w, p, s, Vector2(2.32, 2.56), Vector2(5.22, 0.72), 2.66, 3.48, "rust")
	# One rolled shutter and a broad breach slab make the abandonment legible.
	_part(w, p, s, Vector3(-3.78, 3.75, 5.12), Vector3(3.04, 0.56, 0.26), "rust")
	_part(w, p, s, Vector3(-3.80, 0.96, 4.74), Vector3(2.85, 1.35, 0.17), "rust", Vector3(0.12, 0, -0.06))
	_part(w, p, s, Vector3(3.80, 0.51, 4.92), Vector3(2.74, 0.40, 0.91), "concrete", Vector3(0.14, 0.08, -0.08))

static func _annex(w, p: Vector3, s: Vector3) -> void:
	# Low gabled transshipment shed. Most of the near/east roof has folded inside.
	_part(w, p, s, Vector3(0, 0.20, 0), Vector3(11.12, 0.36, 9.12), "concrete_dark")
	_part(w, p, s, Vector3(0, 0.20, 4.73), Vector3(10.80, 0.34, 0.85), "concrete")
	_part(w, p, s, Vector3(0, 1.63, -4.19), Vector3(10.54, 2.92, 0.36), "soot")
	_part(w, p, s, Vector3(-5.17, 1.63, -0.04), Vector3(0.36, 2.92, 8.30), "concrete")
	for x: float in [-5.03, -0.63, 4.97]:
		var height: float = 2.12 if x > 4.0 else 3.14
		_part(w, p, s, Vector3(x, 0.20 + height * 0.5, 4.02), Vector3(0.50, height, 0.58), "concrete")
	_part(w, p, s, Vector3(-2.82, 3.16, 4.04), Vector3(4.78, 0.38, 0.50), "rust")
	_part(w, p, s, Vector3(-3.03, 1.14, 3.86), Vector3(3.32, 1.86, 0.17), "rust", Vector3(0.12, 0, -0.08))
	# Wide left pitch plus only the far end of the right pitch retain the old gable.
	_roof_pitch(w, p, s, Vector2(-5.22, 3.42), Vector2(-0.72, 5.11), -0.04, 8.24)
	_roof_pitch(w, p, s, Vector2(-0.67, 5.11), Vector2(5.19, 3.33), -2.56, 3.18, "rust")
	for z: float in [-3.95, 0.14, 3.94]:
		_beam(w, p, s, Vector3(-5.04, 3.23, z), Vector3(-0.68, 4.96, z), 0.24)
		_beam(w, p, s, Vector3(-5.04, 3.16, z), Vector3(-0.61, 3.16, z), 0.23, "steel")
		_beam(w, p, s, Vector3(-0.68, 3.16, z), Vector3(-0.68, 4.95, z), 0.22)
	_beam(w, p, s, Vector3(-0.61, 4.98, -3.97), Vector3(5.08, 3.19, -3.97), 0.24)
	_beam(w, p, s, Vector3(5.08, 0.43, -3.97), Vector3(5.08, 3.20, -3.97), 0.30)
	_beam(w, p, s, Vector3(-0.59, 4.89, 3.89), Vector3(2.18, 3.38, 3.83), 0.26)
	_beam(w, p, s, Vector3(2.18, 3.38, 3.83), Vector3(4.91, 0.68, 3.60), 0.26)
	# Collapse is one large form, not a cloud of tiny rubble instances.
	_roof_pitch(w, p, s, Vector2(-0.07, 3.95), Vector2(4.62, 0.77), 1.01, 3.63, "rust")
	_part(w, p, s, Vector3(4.77, 0.81, -0.74), Vector3(0.28, 1.26, 2.22), "concrete_dark", Vector3(0, 0, -0.12))
	_part(w, p, s, Vector3(2.31, 0.40, 3.92), Vector3(3.68, 0.35, 0.69), "concrete", Vector3(0.15, -0.13, 0.07))

static func _dispatch(w, p: Vector3, s: Vector3) -> void:
	# An off-center dispatch tower overlooks a long, low loading wing. Upper ribbon
	# windows are concentrated on the tower; the wing remains one tall open storey.
	_part(w, p, s, Vector3(0, 0.21, 0), Vector3(12.14, 0.38, 12.12), "concrete_dark")
	_part(w, p, s, Vector3(0.02, 0.23, 6.22), Vector3(11.85, 0.38, 0.87), "concrete")
	# Tower: broad plaster planes, upper observation slot, and a broken roof corner.
	_part(w, p, s, Vector3(-3.55, 3.95, -5.37), Vector3(4.51, 7.50, 0.38), "concrete")
	_part(w, p, s, Vector3(-5.62, 3.95, -1.46), Vector3(0.38, 7.50, 7.75), "concrete")
	_part(w, p, s, Vector3(-3.57, 0.79, 2.45), Vector3(4.48, 1.15, 0.38), "concrete_dark")
	_part(w, p, s, Vector3(-3.57, 4.73, 2.44), Vector3(4.48, 1.40, 0.38), "concrete")
	_part(w, p, s, Vector3(-3.57, 6.11, 2.37), Vector3(4.18, 1.34, 0.18), "void")
	_part(w, p, s, Vector3(-3.57, 7.08, 2.44), Vector3(4.50, 0.60, 0.42), "concrete")
	for x: float in [-5.60, -1.48]:
		_part(w, p, s, Vector3(x, 3.93, 2.41), Vector3(0.37, 7.50, 0.42), "concrete")
	# Two broad openings expose the hollow lower tower and differentiate its scale.
	_part(w, p, s, Vector3(-3.59, 2.72, 2.48), Vector3(0.34, 2.74, 0.39), "concrete_dark")
	_part(w, p, s, Vector3(-3.58, 3.86, -1.45), Vector3(4.21, 0.25, 7.35), "concrete_dark")
	_part(w, p, s, Vector3(-1.51, 2.53, -1.45), Vector3(0.33, 4.62, 7.64), "soot")
	_part(w, p, s, Vector3(-1.49, 4.81, -1.45), Vector3(0.40, 1.22, 7.66), "concrete")
	_part(w, p, s, Vector3(-1.44, 6.11, -1.45), Vector3(0.18, 1.34, 7.34), "void")
	_part(w, p, s, Vector3(-1.46, 7.08, -1.46), Vector3(0.42, 0.60, 7.75), "concrete")
	# Just two surviving panes; there is no illumination or new shared material.
	_part(w, p, s, Vector3(-4.42, 6.15, 2.48), Vector3(1.28, 0.97, 0.03), "glass")
	_part(w, p, s, Vector3(-1.33, 6.16, -3.72), Vector3(0.03, 0.97, 1.44), "glass")
	for z: float in [-5.16, -1.50, 2.26]:
		_part(w, p, s, Vector3(-1.35, 6.10, z), Vector3(0.18, 1.39, 0.19), "rust")
	_part(w, p, s, Vector3(-3.93, 7.61, -1.48), Vector3(3.78, 0.30, 7.91), "roof")
	_part(w, p, s, Vector3(-1.91, 7.59, -3.64), Vector3(0.87, 0.27, 3.58), "roof")
	_part(w, p, s, Vector3(-5.35, 7.90, -2.19), Vector3(0.33, 0.51, 6.18), "concrete_dark")
	# Wing extends to the same foundation edge with two large south loading bays.
	_part(w, p, s, Vector3(2.11, 1.82, -5.42), Vector3(7.32, 3.24, 0.34), "soot")
	_part(w, p, s, Vector3(5.57, 1.09, -1.19), Vector3(0.36, 1.70, 8.44), "concrete")
	for x: float in [-1.11, 2.22, 5.53]:
		_part(w, p, s, Vector3(x, 1.88, 5.62), Vector3(0.48, 3.38, 0.57), "concrete")
	_part(w, p, s, Vector3(2.22, 3.48, 5.58), Vector3(7.13, 0.49, 0.50), "concrete")
	_part(w, p, s, Vector3(0.49, 3.04, 5.59), Vector3(2.67, 0.51, 0.26), "rust")
	# A long shallow roof contrasts with the tower's vertical mass; one corner gone.
	_part(w, p, s, Vector3(0.29, 3.75, 0.07), Vector3(3.39, 0.25, 11.12), "roof", Vector3(0, 0, -0.035))
	_part(w, p, s, Vector3(3.86, 3.62, -2.18), Vector3(3.56, 0.25, 6.63), "rust", Vector3(0, 0, -0.035))
	for z: float in [-5.21, -0.67, 5.36]:
		_beam(w, p, s, Vector3(-1.25, 3.47, z), Vector3(5.57, 3.37, z), 0.25, "steel")
	for z: float in [-5.12, -0.69, 4.63]:
		_part(w, p, s, Vector3(5.57, 1.91, z), Vector3(0.35, 3.31, 0.39), "concrete_dark")
	_roof_pitch(w, p, s, Vector2(2.43, 2.71), Vector2(5.04, 0.76), 3.17, 3.52, "rust")
	_part(w, p, s, Vector3(4.05, 0.49, 5.43), Vector3(2.42, 0.38, 0.87), "concrete", Vector3(0.13, 0.08, -0.10))
