extends SceneTree
const Structures = preload("res://structure_visuals.gd")
func _initialize() -> void:
 call_deferred("run")
func run() -> void:
 for kind in ["central_station", "substation"]:
  var parent := Node3D.new()
  root.add_child(parent)
  parent.position = Vector3(17, 0, 14)
  parent.rotation.y = 0.3
  var original := parent.transform
  assert(Structures.add_site(parent, kind))
  Structures.set_site_reclaimed(parent, false)
  Structures.set_site_reclaimed(parent, true)
  assert(parent.transform == original)
  assert(parent.get_child_count() == 1)
  var expected := "CentralStationVisual" if kind == "central_station" else "RefugeSubstationVisual"
  var visual := parent.get_node(expected) as Node3D
  assert(visual != null and visual.transform == Transform3D.IDENTITY)
  assert(visual.find_children("*", "CollisionObject3D", true, false).is_empty())
  assert(visual.find_children("*", "NavigationRegion3D", true, false).is_empty())
  assert(visual.find_children("*", "Light3D", true, false).is_empty())
  var meshes := visual.find_children("*", "MeshInstance3D", true, false)
  assert(meshes.size() == 1)
  var model := meshes[0] as MeshInstance3D
  assert(model.mesh.get_surface_count() == 1)
  var mat := model.mesh.surface_get_material(0) as BaseMaterial3D
  assert(mat != null and mat.albedo_texture != null and mat.normal_enabled)
  assert(mat.transparency == BaseMaterial3D.TRANSPARENCY_DISABLED)
  assert(mat.albedo_texture == load("res://assets/models/ammo_workshop_salvage_albedo.png"))
  assert(mat.normal_texture == load("res://assets/models/ammo_workshop_salvage_normal.png"))
  assert(mat.roughness_texture == load("res://assets/models/ammo_workshop_salvage_orm.png"))
  var aabb := model.get_aabb()
  assert(aabb.position.y >= -0.001 and aabb.end.y < 4.0)
  print("POWER_FACILITY_VISUAL_CONTRACT_PASS ",kind," bounds=",aabb)
  parent.free()
 var generator := Node3D.new()
 root.add_child(generator)
 assert(Structures.add_site(generator, "generator"))
 assert(generator.has_node("RailYard_site_generator"))
 assert(not generator.has_node("CentralStationVisual"))
 generator.free()
 print("POWER_FACILITY_EXISTING_GENERATOR_UNCHANGED_PASS")
 await process_frame
 quit()
