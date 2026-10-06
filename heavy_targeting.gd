extends RefCounted
## Primary automatic heavy targeting. Reset once at the start of each simulation
## step and query only when a heavy shot is ready. Friendly fire precedes enemy
## movement, so positions/bins are shared inside that step; life is checked live.
## Range and blast tests use the same strict 3D boundaries as the existing game.
## Scores saturate at 64; <=24 aim centers are exact, otherwise nearby cell-center
## representatives plus the nearest enemy form a bounded approximation. No RNG,
## enemy/node writes, armor weighting, or extra-shell coordination.
const MAX_CANDIDATES:int=24
const SCORE_CAP:int=64
var _prepared:bool=false
var _enemies:Array=[]
var _positions:Array[Vector3]=[]
var _grids:Dictionary={}

func begin_step()->void:
 _prepared=false
 _enemies.clear()
 _positions.clear()
 _grids.clear()

func select_target(enemies:Array,origin:Vector3,weapon_range:float,blast_radius:float)->Variant:
 return query(enemies,origin,weapon_range,blast_radius).target

## Transient counters make the budget testable without gameplay/save state.
## At most N snapshot entries and one O(N) grid per distinct radius per step.
## Per query: O(N + B log B + 24N), B <= N; only 24 aim centers are ever scored.
## Typical neighboring-cell scoring ends at 64 hits. Call begin_step() before
## changed positions/new spawns; current dead/HP/node flags never use stale data.
func query(enemies:Array,origin:Vector3,weapon_range:float,blast_radius:float)->Dictionary:
 var result:Dictionary={"target":null,"score":0,"eligible":0,"candidates":0,"neighbor_checks":0,"scanned":0,"snapshot_built":false,"grid_built":false}
 if weapon_range<=0 or not origin.is_finite():return result
 if not _prepared:
  _prepare(enemies)
  result.snapshot_built=true
 var radius:float=maxf(blast_radius,.001)
 if not _grids.has(radius):
  _grids[radius]=_make_grid(radius)
  result.grid_built=true
 var grid:Dictionary=_grids[radius]
 result["relevant"]=_enemies.size()
 result["cells"]=grid.size()
 var range_sq:float=weapon_range*weapon_range
 var radius_sq:float=radius*radius
 var eligible:Array[int]=[]
 var range_cells:Array=[]
 for cell in grid:
  # The square's distance is a lower bound on every 3D enemy distance in it.
  var dx:float=maxf(maxf(cell.x*radius-origin.x,origin.x-(cell.x+1)*radius),0)
  var dz:float=maxf(maxf(cell.y*radius-origin.z,origin.z-(cell.y+1)*radius),0)
  var lower_bound:float=dx*dx+dz*dz
  if lower_bound<range_sq:range_cells.append({"cell":cell,"lower_bound":lower_bound})
 range_cells.sort_custom(func(a:Dictionary,b:Dictionary)->bool:return float(a.lower_bound)<float(b.lower_bound))
 var nearest:int=-1
 var nearest_distance:float=range_sq
 var scanned:int=0
 for entry in range_cells:
  if float(entry.lower_bound)>nearest_distance:break
  for index in grid[entry.cell]:
   scanned+=1
   if not _still_alive(index):continue
   var distance:float=origin.distance_squared_to(_positions[index])
   if distance<nearest_distance or (distance==nearest_distance and nearest>=0 and index<nearest):
    nearest=index
    nearest_distance=distance
 result.scanned=scanned
 result["snapshot_entries"]=_enemies.size()
 if nearest<0:return result
 result.target=_enemies[nearest]
 if blast_radius<=0:return result
 result.score=_score(nearest,grid,radius,radius_sq,result)
 # Search the closest spatial cells first. In dense hordes, a saturated nearest
 # result needs no full in-range scan and no other candidate proposals.
 if int(result.score)==SCORE_CAP:return result
 for entry in range_cells:
  for index in grid[entry.cell]:
   scanned+=1
   if _still_alive(index) and origin.distance_squared_to(_positions[index])<range_sq:eligible.append(index)
 result.scanned=scanned
 result.eligible=eligible.size()
 var candidates:Array=[]
 if eligible.size()<=MAX_CANDIDATES:
  for index in eligible:candidates.append({"index":index,"distance":origin.distance_squared_to(_positions[index])})
 else:
  var proposals:Dictionary={}
  var populations:Dictionary={}
  for index in eligible:
   var position:Vector3=_positions[index]
   var cell:=Vector2i(floori(position.x/radius),floori(position.z/radius))
   populations[cell]=int(populations.get(cell,0))+1
   var center_distance:float=Vector2(position.x-(cell.x+.5)*radius,position.z-(cell.y+.5)*radius).length_squared()
   var distance:float=origin.distance_squared_to(position)
   var previous:Variant=proposals.get(cell)
   if previous==null or center_distance<float(previous.center_distance) or (center_distance==float(previous.center_distance) and (distance<float(previous.distance) or (distance==float(previous.distance) and index<int(previous.index)))):
    proposals[cell]={"index":index,"distance":distance,"center_distance":center_distance,"support":0}
  for cell in proposals:
   var proposal:Dictionary=proposals[cell]
   if int(proposal.index)==nearest:continue
   var support:int=0
   for x in range(-1,2):
    for z in range(-1,2):support+=int(populations.get(cell+Vector2i(x,z),0))
   proposal.support=support
   candidates.append(proposal)
  candidates.sort_custom(_preferred_proposal)
  if candidates.size()>MAX_CANDIDATES-1:candidates.resize(MAX_CANDIDATES-1)
 var best_index:int=nearest
 var best_distance:float=nearest_distance
 for candidate in candidates:
  var index:int=candidate.index
  if index==nearest:continue
  var distance:float=candidate.distance
  var nearer:bool=distance<best_distance or (distance==best_distance and index<best_index)
  if int(result.score)==SCORE_CAP and not nearer:continue
  var score:int=_score(index,grid,radius,radius_sq,result)
  if score>int(result.score) or (score==int(result.score) and nearer):
   best_index=index
   best_distance=distance
   result.target=_enemies[index]
   result.score=score
 return result

func _prepare(enemies:Array)->void:
 for enemy in enemies:
  if not _alive(enemy):continue
  var position:Vector3=enemy.node.position
  if not position.is_finite():continue
  _enemies.append(enemy)
  _positions.append(position)
 _prepared=true

func _still_alive(index:int)->bool:
 # Entry shape was checked when the snapshot was built. Only life can change
 # during friendly fire; source dictionaries are shared, positions are copied.
 var enemy:Dictionary=_enemies[index]
 if enemy.get("dead",false) or float(enemy.get("hp",1))<=0:return false
 var node:Variant=enemy.node
 return is_instance_valid(node) and not node.is_queued_for_deletion()

func _make_grid(radius:float)->Dictionary:
 var grid:Dictionary={}
 for index in _positions.size():
  var position:Vector3=_positions[index]
  var cell:=Vector2i(floori(position.x/radius),floori(position.z/radius))
  if not grid.has(cell):grid[cell]=[]
  grid[cell].append(index)
 return grid

static func _alive(enemy:Variant)->bool:
 if not enemy is Dictionary or enemy.get("dead",false) or float(enemy.get("hp",1))<=0:return false
 var node:Variant=enemy.get("node")
 return is_instance_valid(node) and node is Node3D and not node.is_queued_for_deletion()

static func _preferred_proposal(a:Dictionary,b:Dictionary)->bool:
 if int(a.support)!=int(b.support):return int(a.support)>int(b.support)
 return float(a.distance)<float(b.distance) or (float(a.distance)==float(b.distance) and int(a.index)<int(b.index))

func _score(index:int,grid:Dictionary,radius:float,radius_sq:float,result:Dictionary)->int:
 result.candidates+=1
 var position:Vector3=_positions[index]
 var cell:=Vector2i(floori(position.x/radius),floori(position.z/radius))
 var score:int=0
 var checks:int=0
 for x in range(-1,2):
  for z in range(-1,2):
   for other in grid.get(cell+Vector2i(x,z),[]):
    checks+=1
    if position.distance_squared_to(_positions[other])<radius_sq and _still_alive(other):
     score+=1
     if score>=SCORE_CAP:
      result.neighbor_checks+=checks
      return score
 result.neighbor_checks+=checks
 return score
