extends RefCounted
## Local crowd steering in the ground plane; no random draws or new spawn rules.
## Keeps a broad approach from collapsing onto identical A* waypoint centers.
const CELL:float=1.5
const RADIUS:float=.82
var grid:Dictionary={}
var positions:Array[Vector3]=[]
var indices:Dictionary={}
func prepare(enemies:Array)->void:
 grid.clear();positions.clear();indices.clear()
 for e in enemies:
  if e.get("dead",false):continue
  var p:Vector3=e.node.position
  var index:int=positions.size()
  positions.append(p);indices[e.node.get_instance_id()]=index
  var cell:=Vector2i(floori(p.x/CELL),floori(p.z/CELL))
  if not grid.has(cell):grid[cell]=[]
  grid[cell].append(index)
func steer(actor:Node3D,direction:Vector3,dt:float,speed:float,nav:AStarGrid2D)->Vector3:
 var p:Vector3=actor.position
 var index:int=indices.get(actor.get_instance_id(),-1)
 var cell:=Vector2i(floori(p.x/CELL),floori(p.z/CELL))
 var pressure:=Vector3.ZERO
 var used:int=0
 for x in range(-1,2):
  for z in range(-1,2):
   for other in grid.get(cell+Vector2i(x,z),[]):
    if other==index:continue
    var away:Vector3=p-positions[other]
    var distance:float=away.length()
    if distance>=RADIUS:continue
    if distance<.015:
     var a:float=float(mini(index,other)%23)*TAU/23
     away=Vector3(cos(a),0,sin(a))*(1 if index>other else -1);distance=.015
    else:away/=distance
    pressure+=away*(1-distance/RADIUS)
    used+=1
    if used>=16:break
   if used>=16:break
  if used>=16:break
 # Sideways pressure spreads the front, while forward progress remains bounded.
 var lateral:Vector3=pressure-direction*pressure.dot(direction)
 var desired:Vector3=(direction+lateral.limit_length(1.2)*.95).normalized()*speed*dt
 var result:Vector3=p+desired
 if _safe_step(p,result,nav):return desired
 # Do not push through corners, buildings, or blocked tactical cover.
 var base:Vector3=direction*speed*dt
 if _safe_step(p,p+base,nav):return base
 var dx:=Vector3(desired.x,0,0)
 if _safe_step(p,p+dx,nav):return dx
 var dz:=Vector3(0,0,desired.z)
 return dz if _safe_step(p,p+dz,nav) else Vector3.ZERO
static func _open(p:Vector3,nav:AStarGrid2D)->bool:
 var c:=Vector2i(roundi(p.x),roundi(p.z))
 return nav.is_in_boundsv(c) and not nav.is_point_solid(c)

static func _safe_step(start:Vector3,end:Vector3,nav:AStarGrid2D)->bool:
 if not _open(end,nav):return false
 var a:=Vector2i(roundi(start.x),roundi(start.z))
 var b:=Vector2i(roundi(end.x),roundi(end.z))
 if a.x!=b.x and a.y!=b.y:
  var x:=Vector2i(b.x,a.y);var z:=Vector2i(a.x,b.y)
  if not nav.is_in_boundsv(x) or not nav.is_in_boundsv(z):return false
  if nav.is_point_solid(x) or nav.is_point_solid(z):return false
 return true
