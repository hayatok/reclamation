extends SceneTree
var g:Node
func _initialize():call_deferred("run")
func run():
 if FileAccess.file_exists("user://settlement_v2/checkpoint.json"):
  push_error("Fresh isolated XDG_DATA_HOME required for earned fixture review");quit(2);return
 DirAccess.make_dir_recursive_absolute("user://settlement_v2")
 var raw=FileAccess.get_file_as_string("res://tests/fixtures/earned_m2_blocked_economy.json")
 var file=FileAccess.open("user://settlement_v2/checkpoint.json",FileAccess.WRITE);file.store_string(raw);file.close()
 var c=root.get_node("Campaign");c.current=1;c.launch=true;c.resume=true;c.muted=true
 g=load("res://main.tscn").instantiate();root.add_child(g);current_scene=g;g.set_process(false)
 assert(g.elapsed>1020 and g.elapsed<1021)
 for tick in 100:g.advance_simulation_time(.05)
 var blocked=g.units.filter(func(u):return u.kind=="worker" and g.friendly_navigation.current_status(u)==g.FriendlyNavigation.BLOCKED)
 assert(blocked.size()>=4,"Earned cramped layout must reproduce blocked gatherers")
 g.update_ui()
 var waiting=g.units.filter(func(u):return g.worker_needs_attention(u))
 assert(g.idle_worker_button.text=="待機 %d"%waiting.size() and not g.idle_worker_button.disabled)
 var original=blocked.map(func(u):return [u.task,u.target,u.goal])
 var seen=[]
 for i in waiting.size():
  g.select_idle_worker();assert(g.selected.size()==1);seen.append(g.selected[0])
 assert(blocked.all(func(u):return u in seen),"Cycle must reach every blocked worker")
 for i in blocked.size():assert([blocked[i].task,blocked[i].target,blocked[i].goal]==original[i],"Selection must preserve orders")
 g.selected=[blocked[0]];g.update_selection();assert("経路なし" in g.selected_order_text())
 print("EARNED_BLOCKED_WORKERS_DISCOVERABLE count=",blocked.size()," waiting=",waiting.size())
 # Ordinary paid-building removal opens the corridor, without moving actors.
 var parts=g.units.filter(func(u):return u.kind=="worker" and u.get("resource_kind","")=="parts")
 var before=g.stockpile.parts
 for b in g.buildings.duplicate():
  if b.kind=="garden":assert(g.dismantle_building(b))
 for tick in 1600:
  g.advance_simulation_time(.05)
  if g.stockpile.parts>before+1:break
 assert(g.stockpile.parts>before+1,"Existing parts orders must deliver after corridor opens")
 assert(parts.any(func(u):return g.friendly_navigation.current_status(u)!=g.FriendlyNavigation.BLOCKED))
 print("EARNED_CORRIDOR_REOPEN_RESUMES_DELIVERY parts=",g.stockpile.parts)
 g.free();await process_frame;quit(0)
