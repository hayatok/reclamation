extends SceneTree
## Ordinary order dispatch and real simulation in an isolated profile.
## Controlled open-ground/navigation fixtures; not a campaign balance run.
const Navigation = preload("res://friendly_navigation.gd")
const Rules = preload("res://game_rules.gd")
var g: Node
var failures: Array[String] = []
var checks: int = 0
var candidate := false
var safe := true
var speed_safe := true
var max_queries := 0
var closest_while_moving := INF

func _initialize(): call_deferred("run")
func check(ok: bool, label: String):
 checks += 1
 if ok: print("PASS ", label)
 else: failures.append(label);push_error("FAIL "+label)

func clean():
 for collection in [g.units,g.enemies,g.shells,g.corpses]:
  for actor in collection:
   if is_instance_valid(actor.node): actor.node.queue_free()
  collection.clear()
 g.friendly_navigation.clear_reservations()
 g.selected.clear();g.upgrades.clear();g.active_card=false;g.ended=false;g.paused=false
 g.xp=0;g.kills=0;g.level=1;g.wave_clock=100000;g.threat_voice_clock=100000;g.ammo=100000;g.attack_move=false
 g.terrain_blocks.clear()
 for building in g.buildings.duplicate():
  if building.kind != "hq":g.buildings.erase(building);building.node.queue_free()
 g.buildings[0].node.position=Vector3(-25,0,25)
 g.buildings[0].cd=100000
 g.rebuild_navigation()
 safe=true;speed_safe=true;max_queries=0;closest_while_moving=INF

func squad() -> Array:
 var result: Array=[]
 for index in 7:
  result.append(g.make_unit("guard",Vector3(-18-float(index/4)*2,0,-3+(index%4)*2)))
 g.selected=result.duplicate()
 return result

func enemy_at(point: Vector3) -> Dictionary:
 g.spawn_enemy(point)
 var enemy:Dictionary=g.enemies.back()
 enemy.hp=100000;enemy.speed=0.0;enemy.cd=100000
 return enemy

func minimum_distance(actors: Array) -> float:
 var smallest:=INF
 for i in actors.size():
  for j in range(i+1,actors.size()):smallest=minf(smallest,actors[i].node.position.distance_to(actors[j].node.position))
 return smallest

func step(count: int, dt: float=.05):
 for frame in count:
  var prior: Dictionary={}
  for actor in g.units:prior[actor.node]=actor.node.position
  g.simulate(dt)
  max_queries=maxi(max_queries,g.friendly_navigation.queries_this_frame)
  for actor in g.units:
   if not prior.has(actor.node):continue
   safe = safe and Navigation.segment_open(g.nav,prior[actor.node],actor.node.position)
   var speed:float=float(Rules.unit(actor.kind).speed)*(1+g.bonus("move","move_speed_add"))
   speed_safe=speed_safe and prior[actor.node].distance_to(actor.node.position)<=dt*speed+.00001
  closest_while_moving=minf(closest_while_moving,minimum_distance(g.units.filter(func(actor):return actor.kind=="guard")))

func evidence(label: String, actors: Array):
 print("SPACING_EVIDENCE ",label," minimum=",minimum_distance(actors)," minimum_during_travel=",closest_while_moving," positions=",actors.map(func(actor):return actor.node.position)," safe=",safe," speed_safe=",speed_safe," max_queries=",max_queries)
 check(safe and speed_safe and max_queries<=8,label+" preserves grid/speed/query bounds")

func run():
 candidate="--candidate" in OS.get_cmdline_user_args()
 var campaign=root.get_node("Campaign")
 campaign.launch=true;campaign.current=0;campaign.muted=true;campaign.choose_run_seed(715247)
 root.size=Vector2i(1440,900)
 g=load("res://main.tscn").instantiate();root.add_child(g);g.set_process(false)
 g.muted=true;g.low_fx=true;g.audio_system.set_muted(true)
 await process_frame
 clean()
 var actors=squad()
 g.command_at(Vector3(12,0,0))
 check(actors.all(func(actor):return actor.task=="move"),"ordinary ground command selects move")
 step(260)
 evidence("move",actors)
 check(actors.all(func(actor):return actor.task=="idle"),"ordinary move completes")
 check(minimum_distance(actors)>1.0,"ordinary move retains distinct formation endpoints")

 clean();actors=squad()
 var target=enemy_at(Vector3(10,0,0))
 g.attack_move=true;g.command_at(Vector3(20,0,0))
 check(actors.all(func(actor):return actor.task=="attack_move" and actor.target==null),"ordinary attack-move remains player-directed")
 step(250)
 evidence("attack_move_hold",actors)
 if candidate:check(minimum_distance(actors)>.9,"attack-move firing hold spreads combatants")

 clean();actors=squad();target=enemy_at(Vector3(10,0,0))
 g.command_at(target.node.position)
 check(actors.all(func(actor):return actor.task=="focus_fire" and actor.target==target),"ordinary enemy command keeps explicit focus target")
 step(250)
 evidence("focus_fire_hold",actors)
 if candidate:
  check(minimum_distance(actors)>.9,"focus-fire firing hold spreads combatants")
  check(actors.all(func(actor):return actor.target==target and actor.node.position.distance_to(target.node.position)<=10.5*.97),"spacing retains focus and firing hold range")
  target.speed=1.0
  var saved_positions=actors.map(func(actor):return actor.node.position)
  var saved_rng=g.rng.state
  check(g.save_checkpoint(false)==OK,"spaced focus-fire state saves through actual checkpoint writer")
  check(g.load_checkpoint(),"spaced focus-fire state loads through actual checkpoint reader")
  actors=g.units.duplicate();target=g.enemies[0]
  check(actors.map(func(actor):return actor.node.position)==saved_positions and g.rng.state==saved_rng,"save/load preserves coordinates and gameplay RNG")
  check(actors.all(func(actor):return actor.task=="focus_fire" and actor.target==target),"save/load retains all explicit focus orders")
  target.speed=0.0;g.selected=actors.duplicate()
  step(40)
  check(actors.map(func(actor):return actor.node.position)==saved_positions,"reload adds no snap or stationary drift")
 g.stop_selected();step(120)
 evidence("focus_fire_stop",actors)
 check(actors.all(func(actor):return actor.task=="idle" and actor.target==null),"ordinary Stop clears focus without replacing it with another order")
 if candidate:
  check(minimum_distance(actors)>.9,"focus-fire Stop leaves selectable spacing")
  var unique:=true
  for actor in actors:
   var screen:Vector2=g.camera.unproject_position(actor.node.position+Vector3(0,.8,0))
   g.select_rect(screen,screen)
   unique=unique and g.selected.size()==1 and g.selected[0]==actor
  check(unique,"each separated guard is individually selected through real projected-center selection")
 if candidate:
  var stopped_positions=actors.map(func(actor):return actor.node.position)
  step(100)
  check(actors.map(func(actor):return actor.node.position)==stopped_positions,"settled Stop remains still")
  var left_front:Array=[]
  for actor in actors.slice(0,3):
   var screen:Vector2=g.camera.unproject_position(actor.node.position+Vector3(0,.8,0))
   g.select_rect(screen,screen,not left_front.is_empty());left_front.append(actor)
  check(g.selected.size()==3 and left_front.all(func(actor):return actor in g.selected),"ordinary shift selection isolates three guards from the settled squad")
  g.command_at(Vector3(-12,0,-12))
  g.selected=actors.slice(3);g.command_at(Vector3(15,0,-12));step(220)
  check(left_front.all(func(actor):return actor.node.position.x< -10 and actor.task=="idle") and actors.slice(3).all(func(actor):return actor.node.position.x>12 and actor.task=="idle"),"two ordinary ground orders split the former pileup into independent fronts")
  evidence("split_two_fronts",actors)

  clean();actors=[g.make_unit("guard",Vector3.ZERO),g.make_unit("guard",Vector3(.1,0,0))]
  target=enemy_at(Vector3(10.49,0,0));g.selected=actors.duplicate();g.stop_selected()
  step(100)
  check(actors.all(func(actor):return actor.task=="idle" and actor.target==null and actor.node.position.distance_to(target.node.position)<=10.5),"idle autofiring defenders keep existing target in range while settling")
  check(minimum_distance(actors)>.9,"range-constrained idle defenders still separate")

  clean()
  var hq:Dictionary=g.buildings[0]
  var spawn_point:Vector3=hq.node.position+Vector3(0,0,float(hq.radius)+1.8)
  var spawn_cell:Vector2i=g.open_cell(spawn_point,hq.node.position)
  spawn_point=Vector3(spawn_cell.x,0,spawn_cell.y)
  hq.rally=spawn_point
  actors=[g.make_unit("guard",spawn_point+Vector3(-.52,0,0)),g.make_unit("guard",spawn_point+Vector3(-.62,0,0))]
  g.stockpile={"food":1000.0,"salvage":1000.0,"parts":1000.0}
  check(g.production.queue_unit(hq,"worker"),"production fixture pays for a real worker order")
  hq.queue[0].remaining=.01
  step(1)
  var produced=g.units.filter(func(actor):return actor.kind=="worker")
  check(produced.size()==1 and g.combat_spacing.other_actors.has(produced[0]),"spacing snapshot includes worker produced during the same simulation tick")
  check(actors.all(func(actor):return Navigation.cell_of(actor.node.position)!=spawn_cell),"settling guards do not enter freshly produced worker cell")

  clean();actors=squad()
  for z in range(-31,32):g.nav.set_point_solid(Vector2i(0,z))
  g.friendly_navigation.navigation_changed()
  var blocked_starts=actors.map(func(actor):return actor.node.position)
  g.command_at(Vector3(12,0,0));step(100)
  evidence("no_path_wall",actors)
  check(actors.map(func(actor):return actor.node.position)==blocked_starts and actors.all(func(actor):return g.friendly_navigation.current_status(actor)==Navigation.BLOCKED),"unreachable ordinary move stays blocked and unmoved")

  clean();actors=[]
  g.nav.fill_solid_region(g.nav.region,true)
  for x in range(-29,30):g.nav.set_point_solid(Vector2i(x,0),false)
  g.friendly_navigation.navigation_changed()
  for index in 7:actors.append(g.make_unit("guard",Vector3(-23+index*1.2,0,0)))
  g.selected=actors.duplicate();target=enemy_at(Vector3(12,0,0))
  g.command_at(target.node.position);step(450)
  evidence("narrow_corridor_focus",actors)
  check(actors.all(func(actor):return actor.task=="focus_fire" and actor.target==target and actor.node.position.distance_to(target.node.position)<=10.5*.97),"narrow corridor retains selected target and reaches firing range")
  check(minimum_distance(actors)>.75,"one-cell corridor makes useful spacing without passing its walls")
  g.stop_selected();step(150)
  evidence("narrow_corridor_stop",actors)
  check(minimum_distance(actors)>.9,"stopped corridor crowd settles within available corridor")

 print("COMBAT_SPACING_SUMMARY candidate=%s checks=%d failures=%d"%[candidate,checks,failures.size()])
 g.queue_free();await process_frame;await process_frame
 quit(0 if failures.is_empty() else 1)
