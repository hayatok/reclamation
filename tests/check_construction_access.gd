extends SceneTree
var g:Node
func _initialize():call_deferred("run")
func run():
 var campaign=root.get_node("Campaign");campaign.current=2;campaign.launch=true;campaign.resume=false;campaign.muted=true
 g=load("res://main.tscn").instantiate();root.add_child(g);current_scene=g;g.set_process(false)
 # Geometry fixture reproduces the three enclosing obstacles from earned play.
 g.settlement_age=2;g.stockpile={"food":1000.0,"salvage":1000.0,"parts":1000.0}
 var tower=g.make_building("tower",Vector3(6,0,-2));tower.built=1
 var factory=g.make_building("factory",Vector3(6,0,4));factory.built=1
 g.rebuild_navigation()
 var point=Vector3(8,0,0)
 assert(g.construction_perimeter("relay",point).is_empty())
 assert(g.placement_issue("relay",point).contains("作業場所"))
 g.selected=g.units.filter(func(u):return u.kind=="worker")
 var before=g.stockpile.duplicate();var count=g.buildings.size();g.build_mode="relay"
 assert(not g.place_building(point))
 assert(g.stockpile==before and g.buildings.size()==count and g.build_mode=="relay")
 print("SEALED_EARNED_LAYOUT_REJECTED_BEFORE_SPENDING_PASS")
 # Free adjacent tiles inside a sealed ring are also unreachable from outside.
 for x in range(-31,32):
  for y in range(-31,32):g.nav.set_point_solid(Vector2i(x,y),false)
 for value in range(-5,6):
  for cell in [Vector2i(value,-5),Vector2i(value,5),Vector2i(-5,value),Vector2i(5,value)]:g.nav.set_point_solid(cell,true)
 var worker=g.selected[0];worker.node.position=Vector3(0,0,8)
 assert(not g.construction_perimeter("relay",Vector3.ZERO).is_empty())
 assert(not g.construction_reachable("relay",Vector3.ZERO,[worker]))
 g.nav.set_point_solid(Vector2i(0,5),false)
 assert(g.construction_reachable("relay",Vector3.ZERO,[worker]))
 assert(not g.nav.is_point_solid(Vector2i.ZERO))
 assert(g.nav.is_point_solid(Vector2i(1,5)))
 print("CONSTRUCTION_REACHABILITY_OPENING_NO_GRID_MUTATION_PASS")
 g.free();await process_frame;quit()
