extends SceneTree
## Portable focused regression: Godot --headless --path . --script res://tests/check_crowd_steering.gd
const Steering=preload("res://crowd_steering.gd")
const Game=preload("res://main.gd")

func grid()->AStarGrid2D:
 var nav=AStarGrid2D.new()
 nav.region=Rect2i(-31,-31,63,63)
 nav.cell_size=Vector2.ONE
 nav.diagonal_mode=AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
 nav.update()
 return nav

func spread(nav:AStarGrid2D)->Array:
 var crowd=Steering.new()
 var actors=[]
 for i in 8:
  var actor=Node3D.new()
  actor.position=Vector3((i-3.5)*.025,0,0)
  actors.append({"node":actor,"dead":false})
 for step in 60:
  crowd.prepare(actors)
  for actor in actors:
   actor.node.position+=crowd.steer(actor.node,Vector3(0,0,1),.05,1.65,nav)
 var positions=[]
 for actor in actors:
  positions.append(actor.node.position)
  actor.node.free()
 return positions

func _initialize():
 # The observed corner-crossing segment had open endpoints but a blocked interior.
 var nav=grid()
 nav.set_point_solid(Vector2i.ZERO,true)
 var start=Vector3(-.50577,0,.46600)
 var end=Vector3(-.44904,0,.52590)
 assert(Steering._open(start,nav) and Steering._open(end,nav))
 assert(not Steering._safe_step(start,end,nav),"Diagonal corner crossing must be rejected")
 var actor=Node3D.new();actor.position=start
 var crowd=Steering.new();crowd.prepare([{"node":actor,"dead":false}])
 var step=crowd.steer(actor,(end-start).normalized(),.05,1.65,nav)
 assert(step.length()>.001,"An open axis fallback must preserve progress")
 for i in range(1,21):
  assert(Steering._open(start+step*float(i)/20.0,nav),"Fallback crossed blocked navigation")
 actor.free()

 # Same failure mechanism as the earned finale: nearest free approach is enclosed.
 var game=Game.new()
 game.nav=grid()
 for x in range(-1,2):
  for z in range(-1,2):game.nav.set_point_solid(Vector2i(x,z),true)
 game.nav.set_point_solid(Vector2i(0,-1),false)
 game.nav.set_point_solid(Vector2i(0,-2),true)
 var target_node=Node3D.new()
 var target={"node":target_node,"radius":1.3,"kind":"tower"}
 var source=Vector3(0,0,-6)
 assert(game.open_cell(target_node.position,source)==Vector2i(0,-1))
 assert(game.route_to(source,target_node.position).is_empty())
 var route=game.enemy_route(source,target)
 assert(not route.is_empty(),"Enemy must find a reachable alternative approach")
 for waypoint in route:assert(Steering._open(waypoint,game.nav))
 assert(game.enemy_route(source,target)==route,"Cached route must remain deterministic")
 assert(not game.enemy_approach_cells.is_empty())
 game.rebuild_navigation()
 assert(game.enemy_approach_cells.is_empty(),"Navigation rebuild must invalidate approach cache")

 # Steering broadens a compact group deterministically without consuming RNG draws.
 game.rng.seed=101;game.card_rng.seed=202
 var gameplay_state=game.rng.state;var card_state=game.card_rng.state
 seed(303)
 var expected_global_draw=randf()
 seed(303)
 var first=spread(grid())
 var second=spread(grid())
 assert(first==second,"Crowd separation must be deterministic")
 assert(game.rng.state==gameplay_state and game.card_rng.state==card_state)
 assert(randf()==expected_global_draw,"Crowd steering must not consume global RNG draws")
 var min_x=INF;var max_x=-INF
 for position in first:
  min_x=minf(min_x,position.x);max_x=maxf(max_x,position.x)
  assert(position.z>3.0,"Separation must preserve forward progress")
 assert(max_x-min_x>.65,"Compact crowd must gain meaningful lateral width")
 target_node.free();game.free()
 print("CROWD_STEERING_PASS corner_guard=true reachable_approach=true deterministic=true rng_unchanged=true width=",max_x-min_x)
 quit()
