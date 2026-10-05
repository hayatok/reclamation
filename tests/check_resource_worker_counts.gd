extends SceneTree
## Current orders, real economy/queue transitions, and a read-only observer.
## Run in the project's isolated test copy; no saved game or main scene needed.
const Orders=preload("res://worker_orders.gd")

class EconomyHost extends Node:
 var resource_nodes:Array=[]
 var buildings:Array=[]
 var stockpile:Dictionary={"food":0.0,"salvage":0.0,"parts":0.0}
 var economy=preload("res://settlement_economy.gd").new()
 var friendly_navigation=preload("res://friendly_navigation.gd").new()
 var context_signature:String="unchanged"
 func economy_notice(_message:String):pass
 func worker_deposited(worker:Dictionary):
  preload("res://worker_orders.gd").after_deposit(self,worker)

var host:EconomyHost
var workers:Array=[]
var passed:int=0
var failed:int=0
var unchanged:bool=true

func _initialize():call_deferred("run")
func check(ok:bool,label:String):
 if ok:passed+=1;print("PASS ",label)
 else:failed+=1;push_error("FAIL "+label)
func actor(kind:String="worker")->Dictionary:
 var node=Node3D.new();host.add_child(node)
 var worker={"node":node,"kind":kind,"hp":50.0,"task":"idle","target":null,"goal":Vector3.ZERO,"route":[],"planned":Vector3.INF,"pending_orders":[]}
 workers.append(worker)
 return worker
func resource(kind:String,point:Vector3)->Dictionary:
 var node=Node3D.new();host.add_child(node);node.position=point
 var entry={"node":node,"resource":kind,"stock":50.0,"renewable":false}
 host.resource_nodes.append(entry)
 return entry
func observe(food:int,salvage:int,parts:int,label:String):
 var before:Array=[workers.duplicate(true),host.resource_nodes.duplicate(true),host.buildings.duplicate(true),host.stockpile.duplicate(true),host.context_signature,host.friendly_navigation.total_queries]
 var expected:Dictionary={"food":food,"salvage":salvage,"parts":parts}
 var first:Dictionary=host.economy.resource_worker_counts(workers)
 var second:Dictionary=host.economy.resource_worker_counts(workers)
 check(first==expected and second==expected,label)
 unchanged=unchanged and before==[workers,host.resource_nodes,host.buildings,host.stockpile,host.context_signature,host.friendly_navigation.total_queries]

func run():
 host=EconomyHost.new();root.add_child(host);host.economy.setup(host)
 var food:Dictionary=resource("food",Vector3(8,0,0))
 var salvage:Dictionary=resource("salvage",Vector3(0,0,8))
 var parts:Dictionary=resource("parts",Vector3(-8,0,0))
 var hq_node=Node3D.new();host.add_child(hq_node)
 var hq:Dictionary={"node":hq_node,"kind":"hq","hp":100.0,"maxhp":200.0,"built":1.0,"radius":2.0}
 host.buildings.append(hq)
 var foundation_node=Node3D.new();host.add_child(foundation_node);foundation_node.position=Vector3(12,0,12)
 var foundation:Dictionary={"node":foundation_node,"kind":"house","hp":100.0,"maxhp":100.0,"built":0.0,"radius":1.5}
 host.buildings.append(foundation)
 var a:Dictionary=actor();var b:Dictionary=actor();var c:Dictionary=actor()
 host.economy.assign_resource(a,food);host.economy.assign_resource(b,salvage);host.economy.assign_resource(c,parts)
 observe(1,1,1,"outward travel counts all three assigned resources")
 Orders.submit(host,a,{"task":"move","goal":Vector3(20,0,0)})
 observe(0,1,1,"an explicit move order removes the old resource assignment")
 host.economy.assign_resource(a,food);a.node.position=a.goal;host.economy.update_worker(a,.5)
 check(a.economy_phase=="gathering" and a.cargo>0,"fixture reaches actual gathering")
 Orders.submit(host,a,{"task":"gather","target":parts},true)
 observe(1,1,1,"future queued gathering does not count before its turn")
 host.economy.update_worker(a,20)
 check(a.economy_phase=="to_dropoff","fixture enters delivery with a full load")
 observe(1,1,1,"delivery preserves the current assignment until the queue advances")
 a.node.position=a.goal;host.economy.update_worker(a,0)
 check(a.resource_kind=="parts" and a.pending_orders.is_empty() and a.gather_requires_work,"deposit activates the next real gather order")
 observe(0,1,2,"queue counts switch exactly when the next gather order activates")

 # A fresh order must belong to parts even while delivering food already held.
 a.cargo=3.0;a.cargo_kind="food";host.economy.assign_resource(a,parts)
 check(a.economy_phase=="to_dropoff" and a.cargo_kind=="food","reassignment preserves old cargo")
 observe(0,1,2,"old cargo never moves the worker into the cargo resource count")
 Orders.submit(host,a,{"task":"build","target":foundation})
 Orders.submit(host,a,{"task":"gather","target":food},true)
 Orders.submit(host,b,{"task":"repair","target":hq})
 check(a.has("return_assignment") and b.has("return_assignment"),"construction and repair retain gather fallbacks")
 observe(0,0,1,"build and repair exclude both retained fallback and future gather queue")

 # Last partial load still counts; exhausted waiting after its deposit does not.
 c.node.position=c.goal;parts.stock=.1;host.economy.update_worker(c,1)
 check(c.economy_phase=="to_dropoff" and is_equal_approx(c.cargo,.1),"exhaustion starts a real final partial delivery")
 observe(0,0,1,"last delivery counts even when its deposit is exhausted")
 c.node.position=c.goal;host.economy.update_worker(c,0)
 check(c.economy_phase=="waiting_resource" and c.resource_target==null,"last deposit becomes a depleted wait with no target")
 observe(0,0,0,"depleted waiting resource_kind is not ongoing workforce")
 c.resource_target=parts;c.target=parts
 observe(0,0,0,"a retained but exhausted waiting target also does not count")
 parts.stock=10;host.resource_nodes.erase(parts)
 observe(0,0,0,"an unregistered waiting target does not count even with stock")
 host.resource_nodes.append(parts);c.resource_target=null;c.target=null;host.economy.update_worker(c,0)
 observe(0,0,1,"ordinary economy retargeting restores a real resource assignment")

 var d:Dictionary=actor();host.economy.assign_resource(d,food)
 d.nav_status="blocked"
 observe(1,0,1,"blocked assigned travel stays in its resource count")
 d.nav_status="work_waiting"
 observe(1,0,1,"waiting for a work position stays in its resource count")
 host.buildings.clear();d.cargo=10.0;d.cargo_kind="food";d.node.position=d.goal;host.economy.update_worker(d,0)
 check(d.economy_phase=="waiting_dropoff","missing HQ produces an actual delivery wait")
 observe(1,0,1,"blocked delivery remains assigned rather than pretending income")
 d.hp=0
 observe(0,0,1,"dead workers stop counting before scene cleanup")
 c.node.queue_free()
 observe(0,0,0,"workers queued for deletion do not count")
 var nonworker:Dictionary=actor("guard");nonworker.task="gather";nonworker.resource_kind="food"
 var invalid:Dictionary={"node":null,"kind":"worker","hp":50,"task":"gather","resource_kind":"food"};workers.append(invalid)
 observe(0,0,0,"nonworkers and invalid worker nodes are excluded")
 check(unchanged,"repeated observations never mutate workers, queues, cargo, routes, resources, buildings, stockpiles or navigation")
 print("RESOURCE_WORKER_COUNTS_SUMMARY passed=%d failed=%d"%[passed,failed])
 host.free();await process_frame;quit(1 if failed else 0)
