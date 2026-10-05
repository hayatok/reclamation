extends RefCounted
## Soft local separation for idle combatants and combatants holding to fire.
## Travel, work slots, convoy motion, targeting and path queries stay with their
## existing owners. A blocked candidate simply stays still; no reposition jump.
const Navigation = preload("res://friendly_navigation.gd")
const INFANTRY_RADIUS := 0.55
const CART_RADIUS := 0.85
const SETTLE_SPEED := 1.5
const MAX_STEP := 0.12
const MAX_NEIGHBORS := 16
const HASH_SIZE := 2.0
const EPSILON := 0.000001
const TURN_OPTIONS := [0.0, PI / 4.0, -PI / 4.0, PI / 2.0, -PI / 2.0, PI * 0.75, -PI * 0.75, PI]
var actors: Array = []
var positions: Array[Vector3] = []
var indices: Dictionary = {}
var buckets: Dictionary = {}
var protected_cells: Dictionary = {}
var other_actors: Array = []
var reservations: Dictionary = {}

func prepare(live_actors: Array, work_reservations: Dictionary) -> void:
 actors.clear();positions.clear();indices.clear();buckets.clear();protected_cells.clear();other_actors.clear()
 reservations=work_reservations
 for actor in live_actors:
  if not _live(actor):continue
  if actor.get("kind", "") not in ["guard", "grenade", "siegecart"]:
   # Never displace workers/convoys, or settle onto their current/assigned cell.
   other_actors.append(actor)
   continue
  var index:=actors.size()
  actors.append(actor);positions.append(actor.node.position)
  indices[actor.node.get_instance_id()]=index
  var cell:=_bucket(actor.node.position)
  if not buckets.has(cell):buckets[cell]=[]
  buckets[cell].append(index)

## Caller must only use this for idle/fire-holding combatants, BEFORE ordinary
## navigation. If this returns true, hold navigation for the entire tick. Never
## infer unused movement budget from a multi-waypoint route's final position.
func settle(unit: Dictionary, grid: AStarGrid2D, dt: float, speed: float, firing_center: Vector3 = Vector3.INF, firing_radius: float = INF) -> bool:
 if not _live(unit) or unit.get("kind", "") not in ["guard", "grenade", "siegecart"] or not is_finite(dt) or not is_finite(speed) or dt<=0.0 or speed<=0.0:return false
 var index:int=indices.get(unit.node.get_instance_id(),-1)
 if index<0:return false
 var start:Vector3=unit.node.position
 var cell:=_bucket(start)
 var neighbors:Array[int]=[]
 for x in range(-1,2):
  for z in range(-1,2):
   for other in buckets.get(cell+Vector2i(x,z),[]):
    if other==index:continue
    if start.distance_to(positions[other])<_radius(unit)+_radius(actors[other])+MAX_STEP:neighbors.append(other)
 # Stable actor order supplies exact-overlap tie-breaking without RNG or node
 # instance IDs (which change on save/load). Bound work in a dense crowd.
 neighbors.sort()
 if neighbors.size()>MAX_NEIGHBORS:neighbors.resize(MAX_NEIGHBORS)
 if neighbors.is_empty():return false
 var pressure:=Vector3.ZERO
 for other in neighbors:
  var away:=start-positions[other]
  var distance:=away.length()
  var separation:=_radius(unit)+_radius(actors[other])
  if distance<EPSILON:
   var angle:=float((mini(index,other)*7+maxi(index,other)*11)%32)*TAU/32.0
   away=Vector3(cos(angle),0,sin(angle))*(1.0 if index>other else -1.0)
  else:away/=distance
  pressure+=away*maxf(0.0,separation-distance)
 if pressure.length_squared()<EPSILON:return false
 var budget:=minf(minf(speed,SETTLE_SPEED)*dt,MAX_STEP)
 var displacement:=pressure.limit_length(budget)
 # Workers earlier in the simulation may have changed jobs or reserved a
 # work cell since prepare(). Read their current orders and reservation map.
 protected_cells.clear()
 for reserved_cell in reservations:_protect(Vector3(reserved_cell.x,0,reserved_cell.y))
 for other_actor in other_actors:
  if not _live(other_actor):continue
  _protect(other_actor.node.position)
  if other_actor.get("task", "idle") != "idle" and other_actor.get("goal", Vector3.INF).is_finite():
   _protect(other_actor.goal)
 var best:=start
 var best_energy:=_overlap_energy(start,unit,neighbors)
 for turn in TURN_OPTIONS:
  var candidate:=start+displacement.rotated(Vector3.UP,turn)
  if firing_center.is_finite() and candidate.distance_to(firing_center)>firing_radius:continue
  if not Navigation.segment_open(grid,start,candidate) or not _unreserved_segment(start,candidate):continue
  var energy:=_overlap_energy(candidate,unit,neighbors)
  if energy+EPSILON<best_energy:best=candidate;best_energy=energy
 if best==start:return false
 unit.node.position=best
 # Subsequent units see committed positions, avoiding mutual overshoots. Each
 # actor moves <= .12, smaller than the neighboring-bucket search margin.
 positions[index]=best
 return true

func _overlap_energy(point: Vector3, unit: Dictionary, neighbors: Array[int]) -> float:
 var energy:=0.0
 for other in neighbors:
  var overlap:=maxf(0.0,_radius(unit)+_radius(actors[other])-point.distance_to(positions[other]))
  energy+=overlap*overlap
 return energy

func _unreserved_segment(start: Vector3, end: Vector3) -> bool:
 var a:=Navigation.cell_of(start)
 var b:=Navigation.cell_of(end)
 # Conservative supercover. These are tiny local steps; testing every cell
 # in the bounding rectangle also rejects diagonal entry across a work slot.
 for x in range(mini(a.x,b.x),maxi(a.x,b.x)+1):
  for z in range(mini(a.y,b.y),maxi(a.y,b.y)+1):
   var cell:=Vector2i(x,z)
   if not protected_cells.has(cell):continue
   if cell!=a:return false
   # Old saves/orders can already share a worker's cell. Permit a gradual
   # exit only along a segment that never approaches its occupied/assigned
   # points; never move that worker, acquire its slot, or enter another slot.
   for point in protected_cells[cell]:
    var away:Vector3=start-point
    if (end-start).dot(away)<0.0 or end.distance_squared_to(point)<=start.distance_squared_to(point):return false
 return true

func _protect(point: Vector3) -> void:
 var cell:=Navigation.cell_of(point)
 if not protected_cells.has(cell):protected_cells[cell]=[]
 protected_cells[cell].append(point)

func _radius(unit: Dictionary) -> float:
 return CART_RADIUS if unit.get("kind", "")=="siegecart" else INFANTRY_RADIUS

func _bucket(point: Vector3) -> Vector2i:
 return Vector2i(floori(point.x/HASH_SIZE),floori(point.z/HASH_SIZE))

func _live(actor: Dictionary) -> bool:
 var node:Variant=actor.get("node")
 return is_instance_valid(node) and not node.is_queued_for_deletion() and float(actor.get("hp",1.0))>0.0
