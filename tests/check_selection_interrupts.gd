extends SceneTree
## Real viewport dispatch; isolated user data, no simulation or saves.
const Orders=preload("res://worker_orders.gd")
const SELECT_KEYS=[KEY_C,KEY_V,KEY_H,KEY_PERIOD]
var g:Node
var checks:int=0
var failures:Array[String]=[]
func _initialize():call_deferred("run")
func check(ok:bool,label:String):
 checks+=1
 if ok:print("PASS ",label)
 else:failures.append(label);push_error("FAIL "+label)
func press(key:int):
 for down in [true,false]:
  var event=InputEventKey.new();event.keycode=key;event.physical_keycode=key;event.pressed=down
  if down:event.unicode=46 if key==KEY_PERIOD else OS.get_keycode_string(key).to_lower().unicode_at(0)
  root.push_input(event,true)
func choose(values:Array):
 g.selected=values.duplicate();g.inspected={};g.inspected_resource={};g.inspected_site={};g.update_selection()
func world_state()->String:
 var data:Dictionary=g.checkpoint_data()
 return JSON.stringify([data.units,data.buildings,data.stockpile,data.resource_nodes,g.units.map(func(u):return [u.route,u.planned])])
func selection_state()->Array:
 return [g.selected.duplicate(),g.inspected.duplicate(),g.camera_focus,g.build_mode,g.attack_move,g.ghost.visible,g.dragging]
func cleared()->bool:
 return g.build_mode.is_empty() and not g.attack_move and not g.ghost.visible and not g.dragging
func intended_selection(key:int)->bool:
 match key:
  KEY_C:return not g.selected.is_empty() and g.selected==g.units.filter(func(u):return u.kind in ["guard","grenade","siegecart"])
  KEY_V:return g.selected==g.units.filter(func(u):return u.kind=="worker")
  KEY_H:return g.selected.is_empty() and g.inspected.get("kind","")=="hq" and g.camera_focus==g.inspected.node.position
  KEY_PERIOD:return g.selected.size()==1 and g.worker_needs_attention(g.selected[0]) and g.camera_focus==g.selected[0].node.position
 return false
func run():
 if DirAccess.dir_exists_absolute("user://settlement_v2"):
  push_error("Fresh isolated XDG_DATA_HOME required");quit(2);return
 var campaign=root.get_node("Campaign")
 campaign.current=0;campaign.launch=true;campaign.resume=false;campaign.muted=true;campaign.run_seed=20261006
 root.size=Vector2i(1440,900)
 g=load("res://main.tscn").instantiate();root.add_child(g);current_scene=g;g.set_process(false)
 g.stockpile={"food":1000.0,"salvage":1000.0,"parts":1000.0}
 await process_frame;await process_frame
 var worker:Dictionary=g.units.filter(func(u):return u.kind=="worker")[0]
 var guard:Dictionary=g.units.filter(func(u):return u.kind=="guard")[0]
 choose([worker]);g.economy.assign_resource(worker,g.resource_nodes[0]);press(KEY_Q)
 var stock:Dictionary=g.stockpile.duplicate()
 check(g.place_building(Vector3(8,0,19),true) and g.place_building(Vector3(14,0,20),true),"fixture creates two paid foundations through normal placement")
 check(worker.task=="gather" and Orders.pending(worker).size()==2 and g.stockpile.salvage<stock.salvage,"fixture has active gathering, a real pending build FIFO and charged resources")
 if Orders.pending(worker).size()!=2:g.free();await process_frame;quit(1);return
 var stable:String=world_state()

 for mode in ["placement","attack aim"]:
  for key in SELECT_KEYS:
   choose([worker] if mode=="placement" else [guard]);press(KEY_Q)
   check(g.build_mode=="house" and g.ghost.visible if mode=="placement" else g.attack_move,"%s starts through contextual Q before %s"%[mode,OS.get_keycode_string(key)])
   g.dragging=true
   press(key)
   check(cleared() and intended_selection(key),"%s during %s selects intended target and clears placement/aim/drag/ghost"%[OS.get_keycode_string(key),mode])
   check(world_state()==stable,"%s during %s preserves all orders, paid queues, foundations and stock"%[OS.get_keycode_string(key),mode])

 choose([worker]);press(KEY_Q);press(KEY_W)
 check(g.build_mode=="depot" and g.ghost.visible,"W substitutes depot during house placement")
 press(KEY_Q)
 check(g.build_mode=="house" and g.ghost.visible and world_state()==stable,"Q substitutes house again without placing or spending")
 press(KEY_ESCAPE)
 check(g.build_mode.is_empty() and not g.attack_move and not g.ghost.visible and world_state()==stable,"Escape cancels preview without changing paid work or stock")
 press(KEY_Q)
 for down in [true,false]:
  var event=InputEventMouseButton.new();event.button_index=MOUSE_BUTTON_RIGHT;event.pressed=down
  event.position=Vector2(700,350);event.global_position=event.position;root.push_input(event,true)
 check(g.build_mode.is_empty() and not g.ghost.visible and world_state()==stable,"viewport right click cancels preview without issuing an order or refund")
 choose([guard]);press(KEY_Q);press(KEY_ESCAPE)
 check(not g.attack_move and world_state()==stable,"Escape cancels attack aim without changing unit orders")
 choose([worker]);press(KEY_Q);g.dragging=true;g.idle_worker_button.pressed.emit()
 check(cleared() and intended_selection(KEY_PERIOD) and world_state()==stable,"existing idle-worker button callback interrupts placement and preserves paid work")

 # Modal and typing guards keep selection shortcuts out of active UI flows.
 for flag in ["title_open","ended","active_card"]:
  choose([worker]);press(KEY_Q);g.set(flag,true)
  var before:Array=selection_state()
  for key in SELECT_KEYS:press(key)
  check(selection_state()==before and world_state()==stable,flag+" blocks all four selection shortcuts")
  g.set(flag,false);press(KEY_ESCAPE)
 for property in ["options_panel","route_panel","dismantle_panel"]:
  choose([worker]);press(KEY_Q)
  if property=="options_panel":g.show_options()
  else:
   var panel=PanelContainer.new();g.root_ui.add_child(panel);g.set(property,panel)
  var before:Array=selection_state()
  for key in SELECT_KEYS:press(key)
  check(selection_state()==before and world_state()==stable,property+" blocks all four selection shortcuts")
  var panel:Control=g.get(property);g.set(property,null);panel.free();g.paused=false;press(KEY_ESCAPE)
 for edit in [LineEdit.new(),TextEdit.new()]:
  choose([worker]);press(KEY_Q);g.root_ui.add_child(edit);edit.grab_focus()
  var before:Array=selection_state()
  for key in SELECT_KEYS:press(key)
  check(selection_state()==before and edit.text=="cvh." and world_state()==stable,edit.get_class()+" receives text while gameplay selection and modes stay unchanged")
  edit.release_focus();edit.free();press(KEY_ESCAPE)
 print("SELECTION_INTERRUPTS_SUMMARY checks=%d failures=%d labels=%s"%[checks,failures.size(),failures])
 g.free();await process_frame;quit(0 if failures.is_empty() else 1)
