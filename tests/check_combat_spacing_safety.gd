extends SceneTree
const Spacing=preload("res://combat_spacing.gd")
const Navigation=preload("res://friendly_navigation.gd")
var allocated:Array[Node]=[]
var failures:Array[String]=[]
var checks:=0
func _initialize():call_deferred("run")
func check(ok:bool,label:String):
 checks+=1
 if ok:print("PASS ",label)
 else:failures.append(label);push_error("FAIL "+label)
func actor(kind:String,point:Vector3,task:String="idle",goal:Vector3=Vector3.INF)->Dictionary:
 var node:=Node3D.new();allocated.append(node);node.position=point
 return {"node":node,"kind":kind,"hp":100.0,"task":task,"goal":point if not goal.is_finite() else goal}
func grid()->AStarGrid2D:
 var result:=AStarGrid2D.new();result.region=Rect2i(-8,-8,17,17)
 result.diagonal_mode=AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES;result.update()
 return result
func minimum(actors:Array)->float:
 var distance:=INF
 for i in actors.size():
  for j in range(i+1,actors.size()):distance=minf(distance,actors[i].node.position.distance_to(actors[j].node.position))
 return distance
func run():
 var nav:=grid();var helper:=Spacing.new()
 var fighters:Array=[]
 for i in 7:fighters.append(actor("guard",Vector3.ZERO))
 var worker:=actor("worker",Vector3(0,0,2),"gather",Vector3(1,0,0))
 var convoy:=actor("convoy",Vector3(-2,0,0),"move",Vector3(-2,0,3))
 var live:=fighters+[worker,convoy]
 var reservations:Dictionary={Vector2i(1,1):worker}
 var protected:Dictionary={Vector2i(0,2):true,Vector2i(1,0):true,Vector2i(-2,0):true,Vector2i(-2,3):true,Vector2i(1,1):true}
 var safe:=true;var speed_safe:=true;var work_safe:=true
 seed(917341)
 var expected_random:=randf()
 seed(917341)
 for frame in 200:
  helper.prepare(live,reservations)
  for fighter in fighters:
   var previous:Vector3=fighter.node.position
   helper.settle(fighter,nav,.05,4.4)
   safe=safe and Navigation.segment_open(nav,previous,fighter.node.position)
   speed_safe=speed_safe and previous.distance_to(fighter.node.position)<=.220001
   work_safe=work_safe and not protected.has(Navigation.cell_of(fighter.node.position))
 check(minimum(fighters)>.9,"seven exactly overlapping combatants spread deterministically")
 check(safe and speed_safe and work_safe,"exact-duplicate settling respects grid, speed, current worker/convoy cells and work/gather goals")
 check(randf()==expected_random,"settling consumes no global gameplay random draw")
 check(worker.node.position==Vector3(0,0,2) and worker.goal==Vector3(1,0,0) and worker.task=="gather","worker position, gathering goal and task are untouched")
 check(convoy.node.position==Vector3(-2,0,0) and convoy.goal==Vector3(-2,0,3) and convoy.task=="move","convoy position, path goal and stop/task state are untouched")
 check(reservations=={Vector2i(1,1):worker},"construction reservations remain unchanged")

 # Check freshly assigned slots after prepare, not just the frame-start map.
 var a:=actor("guard",Vector3(-.49,0,0));var b:=actor("guard",Vector3(-.39,0,0))
 var worker2:=actor("worker",Vector3(5,0,5),"build",Vector3(5,0,5))
 var fresh:Dictionary={}
 helper.prepare([a,b,worker2],fresh)
 fresh[Vector2i(-1,0)]=worker2
 helper.settle(a,nav,.05,4.4)
 check(Navigation.cell_of(a.node.position)!=Vector2i(-1,0),"new same-tick construction reservation prevents intrusion")
 fresh.clear();worker2.task="gather";worker2.goal=Vector3(-1,0,0)
 a.node.position=Vector3(-.49,0,0);helper.prepare([a,b,worker2],fresh)
 helper.settle(a,nav,.05,4.4)
 check(Navigation.cell_of(a.node.position)!=Vector2i(-1,0),"new same-tick gather destination prevents intrusion")
 # A loaded overlap may safely move OUT of a worker cell, without approaching
 # its actual worker or goal point anywhere along the short segment.
 a.node.position=Vector3.ZERO;b.node.position=Vector3(.1,0,0)
 worker2.node.position=Vector3(.3,0,0);worker2.goal=Vector3(.3,0,0)
 helper.prepare([a,b,worker2],{})
 var escape_start:Vector3=a.node.position
 helper.settle(a,nav,.05,4.4)
 check(a.node.position.distance_to(worker2.node.position)>escape_start.distance_to(worker2.node.position) and (a.node.position-escape_start).dot(escape_start-worker2.node.position)>=0,"existing shared worker cell allows only a non-approaching escape")
 check(worker2.node.position==Vector3(.3,0,0) and worker2.goal==Vector3(.3,0,0),"escaping combatant never moves worker or assignment")

 nav=grid();nav.set_point_solid(Vector2i(-1,0),true)
 a=actor("guard",Vector3(-.49,0,0));b=actor("guard",Vector3(-.48,0,0))
 helper.prepare([a,b],{})
 var start:Vector3=a.node.position
 helper.settle(a,nav,10,100)
 check(Navigation.segment_open(nav,start,a.node.position) and a.node.position.distance_to(start)<=Spacing.MAX_STEP+.000001,"large dt separation does not tunnel through adjacent wall")
 a.node.position=Vector3(-1,0,0);b.node.position=a.node.position
 helper.prepare([a,b],{})
 check(not helper.settle(a,nav,.05,4.4) and a.node.position==Vector3(-1,0,0),"solid start never teleports to a free nearby cell")

 nav=grid();a.node.position=Vector3.ZERO;b.node.position=Vector3(.01,0,0)
 helper.prepare([a,b],{})
 start=a.node.position;helper.settle(a,nav,.01,.01)
 check(a.node.position.distance_to(start)<=.000101,"low unit speed remains the movement limit")
 check(not helper.settle(worker,nav,1,4.4) and not helper.settle(convoy,nav,1,4.4),"helper explicitly excludes worker and convoy kinds")
 print("COMBAT_SPACING_SAFETY_SUMMARY checks=%d failures=%d"%[checks,failures.size()])
 for node in allocated:node.free()
 quit(0 if failures.is_empty() else 1)
