extends RefCounted
## Worker-only FIFO. References stay live until a snapshot resolves current indices.
## Navigation and economic accounting remain owned by their existing helpers.
const Rules=preload("res://settlement_rules.gd")
const MAX_PENDING:int=16
const TASKS:Array[String]=["move","build","repair","gather"]

static func pending(worker:Dictionary)->Array:
 return worker.get("pending_orders",[])

static func clear(worker:Dictionary):
 worker["pending_orders"]=[]

static func append_issue(worker:Dictionary)->String:
 if worker.get("task","")=="escort":return "護衛中は予約できません。右クリックで作業を変更してください。"
 if pending(worker).size()>=MAX_PENDING:return "作業予約は16件までです。"
 return ""

static func submit(host:Node,worker:Dictionary,order:Dictionary,append:bool=false)->bool:
 if worker.get("kind","")!="worker" or not valid_target(host,order):return false
 if append:
  if not append_issue(worker).is_empty():return false
  if not worker.has("pending_orders"):clear(worker)
  worker.pending_orders.append(order.duplicate())
  if worker.task=="idle" or empty_resource_wait(worker):advance(host,worker)
 else:
  clear(worker)
  activate(host,worker,order)
 return true

static func empty_resource_wait(worker:Dictionary)->bool:
 return worker.get("task","")=="gather" and worker.get("economy_phase","")=="waiting_resource" and float(worker.get("cargo",0))<=0

static func tick(host:Node,worker:Dictionary):
 if not pending(worker).is_empty() and (worker.task=="idle" or empty_resource_wait(worker)):advance(host,worker)

static func alive(target:Variant)->bool:
 return target is Dictionary and not target.is_empty() and is_instance_valid(target.get("node")) and not target.node.is_queued_for_deletion() and not target.get("being_removed",false) and float(target.get("hp",1))>0

static func valid_target(host:Node,order:Dictionary)->bool:
 if not order.get("task","") in TASKS:return false
 if order.task=="move":return order.get("goal") is Vector3 and order.goal.is_finite()
 var target:Variant=order.get("target")
 if not alive(target):return false
 return target in (host.resource_nodes if order.task=="gather" else host.buildings)

static func satisfied(order:Dictionary)->bool:
 var target:Variant=order.get("target")
 return order.task=="build" and float(target.built)>=1 or order.task=="repair" and float(target.hp)>=float(target.maxhp)

static func advance(host:Node,worker:Dictionary)->bool:
 # Bounded by MAX_PENDING; inaccessible targets are valid and remain active.
 while not pending(worker).is_empty():
  var order:Dictionary=worker.pending_orders.pop_front()
  if not valid_target(host,order):
   host.economy_notice("予約先が失われたため、次の作業へ進みます。")
   continue
  if order.task in ["build","repair"] and satisfied(order):continue
  activate(host,worker,order,true)
  return true
 return false

static func activate(host:Node,worker:Dictionary,order:Dictionary,from_queue:bool=false):
 host.friendly_navigation.invalidate_order(worker)
 match order.task:
  "gather":
   host.economy.assign_resource(worker,order.target)
   worker["gather_requires_work"]=from_queue
  "build","repair":
   host.economy.suspend_for_construction(worker)
   worker.task=order.task;worker.target=order.target
   worker.goal=order.target.node.position+Vector3(0,0,float(order.target.radius)+1)
  "move":
   host.economy.cancel_assignment(worker)
   worker.task="move";worker.target=null;worker.goal=order.goal
 worker.route=[];worker.planned=Vector3.INF
 host.context_signature=""

static func finish(host:Node,worker:Dictionary,resume_gather:bool=false):
 host.friendly_navigation.invalidate_order(worker)
 worker.task="idle";worker.target=null;worker.goal=worker.node.position
 if not advance(host,worker) and resume_gather:host.economy.resume_after_construction(worker)

static func after_deposit(host:Node,worker:Dictionary):
 # Leave the current gather assignment intact until a valid next order starts.
 # Old cargo may be delivered before this assignment ever reaches its resource.
 if worker.task=="gather" and not worker.get("gather_requires_work",false):advance(host,worker)

static func snapshot(host:Node,worker:Dictionary)->Array:
 var result:Array=[]
 for order in pending(worker):
  if not valid_target(host,order):continue
  var task:String=order.task
  var target_type:String="" if task=="move" else "resource" if task=="gather" else "build"
  var target_index:int=-1 if task=="move" else (host.resource_nodes if task=="gather" else host.buildings).find(order.target)
  var goal:Vector3=order.goal if task=="move" else order.target.node.position
  result.append({"task":task,"target_type":target_type,"target_index":target_index,"goal":[goal.x,goal.y,goal.z]})
 return result

static func restore(host:Node,worker:Dictionary,entries:Array):
 clear(worker)
 for entry in entries:
  var target:Variant=null
  if entry.target_type=="build":target=host.buildings[int(entry.target_index)]
  elif entry.target_type=="resource":target=host.resource_nodes[int(entry.target_index)]
  worker.pending_orders.append({"task":entry.task,"target":target,"goal":Vector3(entry.goal[0],entry.goal[1],entry.goal[2])})

static func next_label(worker:Dictionary)->String:
 if pending(worker).is_empty():return ""
 var order:Dictionary=pending(worker)[0]
 if order.task=="gather":return {"food":"食料採取","salvage":"廃材採取","parts":"部品採取"}.get(order.target.get("resource",""),"採取")
 if order.task=="build":return str(Rules.building(order.target.kind).title)+"建設"
 return "修理" if order.task=="repair" else "移動"

static func summary(workers:Array)->String:
 var entries:Array=[]
 var first_queue:Variant=null
 for worker in workers:
  if worker.kind!="worker":continue
  if first_queue==null:first_queue=pending(worker)
  elif pending(worker)!=first_queue:return "予約は作業員ごと"
  var count:int=pending(worker).size()
  var text:String="予約%d: 次は%s"%[count,next_label(worker)] if count>0 else ""
  if count>0 and worker.task=="gather":text+=" / 搬入後に次の命令"
  if not text in entries:entries.append(text)
 if entries.size()>1:return "予約は作業員ごと"
 return entries[0] if entries.size()==1 else ""
