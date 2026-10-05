extends SceneTree
const Orders=preload("res://worker_orders.gd")
func _initialize():call_deferred("run")
func run():
 var campaign=root.get_node("Campaign")
 campaign.launch=true;campaign.current=0;campaign.resume=false;campaign.muted=true
 var g=load("res://main.tscn").instantiate();root.add_child(g);current_scene=g;g.set_process(false)
 g.selected=g.units.filter(func(unit):return unit.kind=="worker")
 g.inspected={}
 g.command_at(Vector3(20,0,24))
 var resource:Dictionary=g.resource_nodes.filter(func(entry):return entry.resource=="salvage")[0]
 g.command_at(resource.node.position,Vector2.INF,true)
 g.update_queue_display()
 var first:Dictionary=Orders.pending(g.selected[0])[0]
 var second:Dictionary=Orders.pending(g.selected[1])[0]
 var ok:bool=first.goal!=second.goal and first.target==second.target and g.selected.all(func(worker):return Orders.pending(worker).size()==1 and Orders.pending(worker)[0].task=="gather") and g.queue_caption.text=="予約1: 次は廃材採取"
 if ok:print("PASS normal group gather queue shows common count and next action despite unused formation goals")
 else:push_error("FAIL shared queue summary: "+g.queue_caption.text)
 print("WORKER_QUEUE_SHARED_SUMMARY checks=1 failures=%d"%[0 if ok else 1])
 g.free();await process_frame;quit(0 if ok else 1)
