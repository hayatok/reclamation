extends SceneTree
const Scene=preload("res://frontier_reclamation_scene.gd")
func _initialize():call_deferred("run")
func run():
 var origin=Vector3(62,0,-48)
 var clear={"frontier_clear":func(_p):return true}
 assert(Scene.choose_space(clear,origin).is_finite())
 assert(not Scene.choose_space({},origin).is_finite())
 assert(not Scene.choose_space({"frontier_clear":func(_p):return false},origin).is_finite())
 var occupied=clear.duplicate();occupied["frontier_unit_footprints"]=[{"position":origin,"radius":100}]
 assert(not Scene.choose_space(occupied,origin).is_finite())
 var blocked=clear.duplicate();blocked["frontier_building_footprints"]=[{"position":origin,"radius":100}]
 assert(not Scene.choose_space(blocked,origin).is_finite())
 var scene=Scene.new();root.add_child(scene);assert(scene.setup(clear,origin))
 for t in [0.,1.,2.5,3.5,4.2,5.6]:
  scene.sample_at(t)
  for a in scene.actors:
   for part in a.get_meta("actor_visuals").get_meta("part_nodes"):
    assert(part.transform.is_finite())
 scene.free()
 var empty=Scene.new();root.add_child(empty);assert(not empty.setup(blocked,origin));assert(empty.get_child_count()==0);empty.free()
 print("FRONTIER_RECLAMATION_BOUNDARIES_PASS safe/unknown/occupied/building/fallback/finite/free")
 quit()
