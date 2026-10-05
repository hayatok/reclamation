extends SceneTree
## Focused dispatch fixture: real right-click events, no campaign save mutation.
const Orders=preload("res://worker_orders.gd")
var g:Node
var passed:int=0
var failed:int=0
var failures:Array[String]=[]
var worker:Dictionary
var resource:Dictionary
var enemy:Dictionary

func _initialize():call_deferred("run")

func check(ok:bool,label:String):
 if ok:passed+=1;print("PASS ",label)
 else:failed+=1;failures.append(label);push_error("FAIL "+label)

func prepare_worker():
 Orders.clear(worker)
 g.economy.cancel_assignment(worker)
 worker.cargo=3.25;worker.cargo_kind="parts"
 g.economy.assign_resource(worker,resource)
 Orders.submit(g,worker,{"task":"move","goal":Vector3(-22,0,18)},true)
 g.selected=[worker];g.attack_move=false

func worker_state()->Dictionary:
 return {"task":worker.task,"target":worker.target,"goal":worker.goal,
  "cargo":worker.cargo,"cargo_kind":worker.cargo_kind,
  "resource_target":worker.resource_target,"economy_phase":worker.economy_phase,
  "pending":Orders.snapshot(g,worker)}

func click(point:Vector3,append:bool=false)->Vector3:
 var event=InputEventMouseButton.new()
 event.button_index=MOUSE_BUTTON_RIGHT;event.pressed=true;event.shift_pressed=append
 event.position=g.camera.unproject_position(point)
 var hit_point:Vector3=g.ground_at(event.position)
 var enemy_screen:Vector2=g.camera.unproject_position(enemy.node.position+Vector3(0,.9*enemy.node.scale.y,0))
 check(enemy_screen.distance_to(event.position)<28.0,"fixture click overlaps enemy hit radius")
 g._unhandled_input(event)
 return hit_point

func run():
 var campaign=root.get_node("Campaign")
 campaign.launch=true;campaign.current=0;campaign.resume=false;campaign.muted=true
 root.size=Vector2i(1440,900)
 g=load("res://main.tscn").instantiate();root.add_child(g);current_scene=g;g.set_process(false)
 g.muted=true;g.low_fx=true;g.audio_system.set_muted(true)
 g.wave_clock=100000;g.threat_voice_clock=100000;g.active_card=false;g.ended=false;g.title_open=false;g.paused=false
 for collection in [g.units,g.enemies,g.resource_nodes,g.sites]:
  for item in collection:
   if is_instance_valid(item.node):item.node.queue_free()
  collection.clear()
 g.selected.clear()
 for building in g.buildings.duplicate():
  if building.kind!="hq":g.buildings.erase(building);building.node.queue_free()
 g.buildings[0].node.position=Vector3(-25,0,25)
 g.terrain_blocks.clear();g.rebuild_navigation()
 resource=g.make_resource("parts",Vector3(-18,0,-12),1000)
 worker=g.make_unit("worker",Vector3(-8,0,8))
 g.spawn_enemy(Vector3(8,0,0));enemy=g.enemies.back()
 enemy.speed=0.0;enemy.cd=100000;enemy.hp=100000
 await process_frame

 # Ordinary worker retreat replaces gathering and queued work immediately.
 prepare_worker()
 var point=Vector3(8.4,0,.2)
 var hit_point=click(point)
 check(worker.task=="move" and worker.target==null,"ordinary worker click near enemy issues move")
 check(worker.goal.is_equal_approx(hit_point+Vector3(-1.65,0,0)),"ordinary worker click keeps existing formation destination")
 check(Orders.pending(worker).is_empty(),"ordinary retreat clears old pending orders")
 check(worker.cargo==3.25 and worker.cargo_kind=="parts","ordinary retreat preserves carried cargo")
 check(worker.resource_target==null and worker.economy_phase=="idle","ordinary retreat cancels gather assignment")

 # Shift appends even when its screen-space hit also identifies an enemy.
 prepare_worker()
 var before=worker_state()
 hit_point=click(point,true)
 check(worker.task==before.task and worker.target==before.target and worker.goal==before.goal,"Shift near enemy preserves active work")
 check(Orders.pending(worker).size()==2 and Orders.pending(worker)[0].goal==Vector3(-22,0,18),"Shift near enemy appends without clearing prior queue")
 var latest:Dictionary=Orders.pending(worker).back()
 check(latest.task=="move" and latest.goal.is_equal_approx(hit_point+Vector3(-1.65,0,0)),"Shift near enemy queues clicked move destination")
 check(worker.cargo==3.25 and worker.cargo_kind=="parts","Shift near enemy preserves carried cargo")

 # World-space command callers use the same worker dispatch rule.
 prepare_worker();g.command_at(enemy.node.position)
 check(worker.task=="move" and Orders.pending(worker).is_empty(),"world-space worker enemy proximity also permits move")
 prepare_worker();g.command_at(enemy.node.position,Vector2.INF,true)
 check(Orders.pending(worker).size()==2,"world-space Shift enemy proximity also appends")

 # All supported fighters keep ordinary focus fire. Mixed normal clicks do
 # not replace a worker's active or queued task as a combat side effect.
 var fighters:Array=[]
 for kind in ["guard","grenade","siegecart"]:
  var fighter:Dictionary=g.make_unit(kind,Vector3(-12,0,-3-fighters.size()*2))
  fighters.append(fighter);g.selected=[fighter]
  click(enemy.node.position)
  check(fighter.task=="focus_fire" and fighter.target==enemy,kind+" ordinary click still focuses enemy")
 prepare_worker();before=worker_state();g.selected=[worker,fighters[0]]
 fighters[0].task="idle";fighters[0].target=null
 click(enemy.node.position)
 check(fighters[0].task=="focus_fire" and fighters[0].target==enemy,"mixed ordinary click focuses selected fighter")
 check(worker_state()==before,"mixed ordinary enemy click leaves worker active order queue and cargo unchanged")
 prepare_worker();g.selected=[worker,fighters[0]]
 var fighter_goal:Vector3=fighters[0].goal
 click(point,true)
 check(Orders.pending(worker).size()==2,"mixed Shift enemy click appends worker order")
 check(fighters[0].task=="focus_fire" and fighters[0].target==enemy and fighters[0].goal==fighter_goal,"mixed Shift enemy click leaves fighter focus unchanged")
 g.selected=[fighters[0]];click(point,true)
 check(fighters[0].task=="focus_fire" and fighters[0].target==enemy and fighters[0].goal==fighter_goal,"fighter-only Shift remains a no-op")

 # Civilian priorities stay in the normal resolver despite nearby enemies.
 enemy.node.position=resource.node.position
 prepare_worker();click(resource.node.position)
 check(worker.task=="gather" and worker.resource_target==resource and Orders.pending(worker).is_empty(),"ordinary resource click near enemy assigns gathering and clears queue")
 prepare_worker();click(resource.node.position,true)
 latest=Orders.pending(worker).back()
 check(Orders.pending(worker).size()==2 and latest.task=="gather" and latest.target==resource,"Shift resource click near enemy queues gathering")
 var building:Dictionary=g.make_building("house",resource.node.position)
 prepare_worker();click(building.node.position)
 check(worker.task=="build" and worker.target==building and Orders.pending(worker).is_empty(),"unfinished building retains priority over overlapping resource and enemy")
 check(worker.cargo==3.25 and worker.has("return_assignment"),"build retains cargo and suspended gather fallback")
 prepare_worker();click(building.node.position,true)
 latest=Orders.pending(worker).back()
 check(Orders.pending(worker).size()==2 and latest.task=="build" and latest.target==building,"Shift build retains priority over overlapping resource and enemy")
 building.built=1.0;building.hp-=10
 prepare_worker();click(building.node.position)
 check(worker.task=="repair" and worker.target==building,"damaged building near enemy still resolves as repair")
 prepare_worker();click(building.node.position,true)
 latest=Orders.pending(worker).back()
 check(Orders.pending(worker).size()==2 and latest.task=="repair" and latest.target==building,"Shift damaged building near enemy queues repair")

 # Friendly and site targeting keep their original support and rejections.
 var ally:Dictionary=g.make_unit("guard",Vector3(3,0,-7))
 enemy.node.position=ally.node.position
 prepare_worker();click(ally.node.position)
 check(worker.task=="escort" and worker.target==ally and Orders.pending(worker).is_empty(),"ordinary friendly click near enemy still assigns escort")
 prepare_worker();before=worker_state();click(ally.node.position,true)
 check(worker_state()==before,"unsupported Shift escort preserves worker state near enemy")
 g.EscortOrders.assign(ally,worker,0)
 prepare_worker();before=worker_state();click(ally.node.position)
 check(worker_state()==before,"rejected escort cycle preserves worker state near enemy")
 g.make_site("pump",Vector3(16,0,-12))
 var site:Dictionary=g.sites.back();enemy.node.position=site.node.position
 prepare_worker();click(site.node.position)
 check(worker.task=="site" and worker.target==site and Orders.pending(worker).is_empty(),"ordinary site click near enemy still assigns site")
 prepare_worker();before=worker_state();click(site.node.position,true)
 check(worker_state()==before,"unsupported Shift site preserves worker state near enemy")

 print("WORKER_ENEMY_DISPATCH_SUMMARY passed=%d failed=%d failures=%s"%[passed,failed,failures])
 g.free();await process_frame;quit(1 if failed else 0)
