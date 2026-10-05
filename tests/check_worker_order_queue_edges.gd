extends SceneTree
const Orders=preload("res://worker_orders.gd")
const Nav=preload("res://friendly_navigation.gd")
const Atomic=preload("res://atomic_save.gd")
const Validation=preload("res://checkpoint_validation.gd")
var g:Node
var passed:int=0
var failed:int=0
func _initialize():call_deferred("run")
func check(ok:bool,label:String):
 if ok:passed+=1;print("PASS ",label)
 else:failed+=1;push_error("FAIL "+label)
func tick(count:int=1):
 for step in count:g.advance_simulation_time(.05)
func run():
 var campaign=root.get_node("Campaign")
 campaign.launch=true;campaign.current=0;campaign.resume=false;campaign.muted=true
 g=load("res://main.tscn").instantiate();root.add_child(g);current_scene=g;g.set_process(false)
 g.wave_clock=100000;g.stockpile={"food":1000.0,"salvage":1000.0,"parts":1000.0}
 var workers:Array=g.units.filter(func(u):return u.kind=="worker")
 var w:Dictionary=workers[0]
 var food:Dictionary=g.resource_nodes[0]
 var salvage:Dictionary=g.resource_nodes[1]
 g.economy.assign_resource(w,food)
 var a:Dictionary=g.make_building("house",Vector3(-4,0,19))
 var b:Dictionary=g.make_building("house",Vector3(2,0,19))
 Orders.submit(g,w,{"task":"build","target":a,"goal":a.node.position})
 Orders.submit(g,w,{"task":"gather","target":salvage,"goal":salvage.node.position},true)
 g.selected=[w];g.command_at(b.node.position)
 b.built=1;g.finish_construction_order(w)
 check(w.task=="gather" and w.resource_target==food and Orders.pending(w).is_empty(),"normal build replacement cancels future gather but preserves original fallback")
 Orders.submit(g,w,{"task":"build","target":a,"goal":a.node.position})
 Orders.submit(g,w,{"task":"gather","target":salvage,"goal":salvage.node.position},true)
 a.built=1;g.finish_construction_order(w)
 check(w.task=="gather" and w.resource_target==salvage and not w.has("return_assignment"),"activated explicit gather supersedes original fallback")

 # The existing target priority still rejects a cyclic escort without cancellation.
 a.built=0
 Orders.submit(g,w,{"task":"build","target":a,"goal":a.node.position})
 Orders.submit(g,w,{"task":"build","target":b,"goal":b.node.position},true)
 var guard:Dictionary=g.units.filter(func(u):return u.kind=="guard")[0]
 g.EscortOrders.assign(guard,w,0)
 g.command_at(guard.node.position)
 check(w.task=="build" and w.target==a and Orders.pending(w).size()==1 and w.has("return_assignment"),"rejected escort cycle preserves active, pending, and fallback")
 var saved_route:Array=w.route.duplicate()
 var saved_goal:Vector3=w.goal
 g.command_at(g.sites[0].node.position,Vector2.INF,true)
 check(w.target==a and Orders.pending(w).size()==1 and w.goal==saved_goal and w.route==saved_route,"unsupported Shift site leaves worker work untouched")

 # Actual event modifier forwarding and repeated Shift foundation placement.
 g.inspected={};g.selected=[workers[1]];g.update_selection();g.stop_selected();g.set_build("house")
 var click=InputEventMouseButton.new();click.button_index=MOUSE_BUTTON_LEFT;click.pressed=true;click.shift_pressed=true
 click.position=g.camera.unproject_position(Vector3(8,0,19));g._unhandled_input(click)
 var first:Dictionary=g.buildings.back()
 click.position=g.camera.unproject_position(Vector3(14,0,20));g._unhandled_input(click)
 var second:Dictionary=g.buildings.back()
 check(first!=second and workers[1].target==first and Orders.pending(workers[1]).size()==1 and Orders.pending(workers[1])[0].target==second and g.build_mode=="house","two Shift mouse events keep preview and queue two distinct paid foundations")
 var switch_key=InputEventKey.new();switch_key.keycode=KEY_W;switch_key.pressed=true
 g.refresh_context_commands(true);g._unhandled_input(switch_key)
 check(g.build_mode=="depot","building hotkey switches retained preview through normal availability")
 click.button_index=MOUSE_BUTTON_RIGHT;g._unhandled_input(click)
 check(g.build_mode.is_empty() and Orders.pending(workers[1]).size()==1,"right-click preview cancel preserves existing paid orders")
 click.position=g.camera.unproject_position(Vector3(20,0,25));g._unhandled_input(click)
 check(Orders.pending(workers[1]).size()==2 and Orders.pending(workers[1])[1].task=="move","Shift right mouse event forwards append mode")
 g.update_queue_display()
 check(g.queue_caption.text.contains("予約2") and g.queue_caption.text.contains("建設"),"existing queue caption exposes count and next work type")

 # Mid-delivery checkpoint preserves cargo, pending foundation, and one credit.
 g.selected=[w];g.stop_selected();g.economy.assign_resource(w,food)
 Orders.submit(g,w,{"task":"build","target":a,"goal":a.node.position},true)
 for step in 1600:
  tick()
  if w.economy_phase=="to_dropoff" and w.cargo>0:break
 check(w.task=="gather" and w.economy_phase=="to_dropoff" and w.cargo>0,"fixture reaches actual mid-delivery queue boundary")
 var amount:float=w.cargo;var cargo_kind:String=w.cargo_kind;var before:float=g.stockpile[cargo_kind]
 var worker_index:int=g.units.find(w)
 check(g.save_checkpoint(false)==OK and g.load_checkpoint(),"mid-delivery FIFO saves and reloads atomically")
 w=g.units[worker_index];a=Orders.pending(w)[0].target
 check(not w.gather_requires_work and w.cargo==amount and w.cargo_kind==cargo_kind and w.economy_phase=="to_dropoff" and Orders.pending(w).size()==1,"reload preserves partial journey cargo and pending work")
 for step in 1500:
  tick()
  if w.task=="build":break
 check(w.task=="build" and w.target==a and w.cargo==0 and g.stockpile[cargo_kind]==before+amount,"loaded delivery credits cargo once before starting queued foundation")
 var valid_data:Dictionary=g.checkpoint_data()
 var corrupt:Dictionary=valid_data.duplicate(true)
 corrupt.units[worker_index].pending_orders=[{"task":"build","target_type":"resource","target_index":0,"goal":[0,0,0]}]
 var path="user://settlement_v2/checkpoint.json"
 var bytes_before:PackedByteArray=FileAccess.get_file_as_bytes(path)
 check(Atomic.write_json(path,corrupt,Validation.validate)!=OK and FileAccess.get_file_as_bytes(path)==bytes_before and w.target==a,"malformed FIFO is rejected before replacing disk checkpoint or live world")

 # Old cargo must never substitute for a newly requested harvest.
 var parts:Dictionary=g.resource_nodes.filter(func(r):return r.resource=="parts")[0]
 var cargo_build:Dictionary=g.make_building("house",Vector3(20,0,22))
 g.selected=[w];g.stop_selected();w.cargo=5.0;w.cargo_kind="food"
 Orders.submit(g,w,{"task":"gather","target":parts,"goal":parts.node.position},true)
 Orders.submit(g,w,{"task":"build","target":cargo_build,"goal":cargo_build.node.position},true)
 var old_food:float=g.stockpile.food
 check(w.gather_requires_work and g.save_checkpoint(false)==OK and g.load_checkpoint(),"unworked gather and its old cargo save and reload")
 w=g.units[worker_index];cargo_build=Orders.pending(w)[0].target
 for step in 1500:
  tick()
  if g.stockpile.food>old_food:break
 check(w.task=="gather" and w.gather_requires_work and w.resource_kind=="parts" and Orders.pending(w).size()==1 and g.stockpile.food==old_food+5,"old food deposit credits once without skipping queued parts harvest")
 var old_parts:float=g.stockpile.parts
 for step in 2200:
  tick()
  if w.task=="build":break
 check(w.task=="build" and w.target==cargo_build and g.stockpile.parts>old_parts,"new parts assignment gathers and deposits before queued build activates")
 g.selected=[w];g.stop_selected();w.cargo=g.worker_carry_capacity(w,"parts");w.cargo_kind="parts"
 var carried_parts:float=w.cargo
 parts=g.resource_nodes.filter(func(r):return r.resource=="parts")[0]
 Orders.submit(g,w,{"task":"gather","target":parts,"goal":parts.node.position},true)
 Orders.submit(g,w,{"task":"build","target":cargo_build,"goal":cargo_build.node.position},true)
 old_parts=g.stockpile.parts
 for step in 1000:
  tick()
  if g.stockpile.parts>old_parts:break
 check(w.task=="gather" and w.gather_requires_work and Orders.pending(w).size()==1 and g.stockpile.parts==old_parts+carried_parts,"full old same-kind cargo cannot instantly complete a newly queued gather")

 # An already-active normal gather retains the stated next-deposit boundary.
 g.selected=[w];g.stop_selected();w.cargo=5.0;w.cargo_kind="food"
 g.economy.assign_resource(w,parts)
 Orders.submit(g,w,{"task":"build","target":cargo_build,"goal":cargo_build.node.position},true)
 old_food=g.stockpile.food
 for step in 1000:
  tick()
  if g.stockpile.food>old_food:break
 check(w.task=="build" and w.target==cargo_build and g.stockpile.food==old_food+5,"append to an existing ordinary gather still yields at its next successful deposit")

 # Narrow construction perimeter: WAITING and BLOCKED never consume a queue.
 g.selected=g.units.filter(func(u):return u.kind=="worker");g.stop_selected()
 var target:Dictionary=g.make_building("relay",Vector3(-20,0,-5))
 var available:Array=g.friendly_navigation._work_perimeter(g.nav,target,Vector3(-26,0,-5))
 var slot:Vector3=available[0]
 for point in available:
  if point!=slot:g.nav.set_point_solid(Nav.cell_of(point),true)
 g.friendly_navigation.navigation_changed()
 var builder:Dictionary=g.make_unit("worker",slot+Vector3(-3,0,0))
 var waiting:Dictionary=g.make_unit("worker",slot+Vector3(-3,0,-1))
 var next:Dictionary=g.make_building("house",Vector3(-20,0,7))
 # make_building rebuilds the map, so restore the deliberately narrowed fixture.
 for point in available:
  if point!=slot:g.nav.set_point_solid(Nav.cell_of(point),true)
 g.friendly_navigation.navigation_changed()
 g.selected=[builder,waiting];g.command_at(target.node.position)
 Orders.submit(g,waiting,{"task":"build","target":next,"goal":next.node.position},true)
 for step in 250:
  tick()
  if g.friendly_navigation.is_arrived(builder) and g.friendly_navigation.current_status(waiting)==Nav.WORK_WAITING:break
 check(g.friendly_navigation.current_status(waiting)==Nav.WORK_WAITING and waiting.target==target and Orders.pending(waiting).size()==1,"occupied work perimeter waits with paid future order intact")
 g.selected=[waiting];g.update_queue_display()
 check(g.selected_order_text()=="作業場所の空き待ち" and g.queue_caption.text.contains("予約1"),"work-space waiting reason stays visible alongside queue count")
 target.built=.999999;tick()
 check(waiting.task=="build" and waiting.target==next and Orders.pending(waiting).is_empty(),"another builder's completion advances waiting worker to next foundation")
 g.selected=[waiting];g.stop_selected()
 Orders.submit(g,waiting,{"task":"build","target":next,"goal":next.node.position})
 Orders.submit(g,waiting,{"task":"move","goal":Vector3(-10,0,5)},true)
 var blocked_perimeter:Array=g.friendly_navigation._work_perimeter(g.nav,next,waiting.node.position)
 for point in blocked_perimeter:g.nav.set_point_solid(Nav.cell_of(point),true)
 g.friendly_navigation.navigation_changed()
 tick(50)
 check(g.friendly_navigation.current_status(waiting)==Nav.BLOCKED and waiting.target==next and Orders.pending(waiting).size()==1 and next.built==0,"closed perimeter remains BLOCKED without skipping or remotely building paid target")
 for point in blocked_perimeter:g.nav.set_point_solid(Nav.cell_of(point),false)
 g.friendly_navigation.navigation_changed()
 for step in 1200:
  tick()
  if next.built>=1:break
 check(next.built==1 and waiting.task=="move" and Orders.pending(waiting).is_empty(),"reopening route recovers existing work and then advances FIFO")
 print("WORKER_ORDER_QUEUE_EDGES_SUMMARY passed=%d failed=%d"%[passed,failed])
 g.free();await process_frame;quit(1 if failed else 0)
