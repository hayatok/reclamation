extends SceneTree
## Functional UI callbacks and layout assertions; actual pointer/phone QA is separate.
var game
var hud
var checks:int=0
var failures:int=0

func _initialize():call_deferred("run")

func check(ok:bool,label:String)->void:
 checks+=1
 if not ok:failures+=1;push_error(label)

func buttons()->Array:
 return hud.popup.find_children("*","Button",true,false) if hud.has_open_popup() else []

func tagged(key:String,value)->Button:
 for button in buttons():
  if button.has_meta(key) and button.get_meta(key)==value:return button
 return null

func press_tag(key:String,value)->void:
 var button:Button=tagged(key,value)
 check(button!=null and not button.disabled,"Available action: "+key+" "+str(value))
 if button!=null and not button.disabled:button.pressed.emit()

func press_text(value:String)->void:
 for button in buttons():
  if button.text==value:button.pressed.emit();return
 check(false,"Available action: "+value)

func selected_ids()->Array:
 return game.selected.map(func(unit):return unit.node.get_instance_id())

func slot_ids(slot:int)->Array:
 var group:Dictionary=game.control_groups.resolve(slot,game.units,game.buildings)
 if not group.building.is_empty():return [group.building.node.get_instance_id()]
 return group.units.map(func(unit):return unit.node.get_instance_id())

func orders()->Array:
 return game.checkpoint_data().units.duplicate(true)

func select(units:Array)->void:
 game.selected=units;game.inspected={};game.update_selection()

func settle()->void:
 await process_frame;await process_frame;await process_frame

func run()->void:
 var campaign=root.get_node("Campaign")
 campaign.launch=true;campaign.resume=false;campaign.current=0;campaign.muted=true;campaign.run_seed=38
 root.size=Vector2i(390,844);root.content_scale_size=Vector2i(390,844)
 game=load("res://main.tscn").instantiate();root.add_child(game);current_scene=game
 game.set_process(false)
 await settle()
 check(game.mobile_enabled,"Use --touch-ui for this fixture")
 if not game.mobile_enabled:quit(2);return
 hud=game.mobile_hud
 hud.set_safe_insets(Vector4(0,44,0,34))
 var workers:Array=game.units.filter(func(unit):return unit.kind=="worker")
 var guards:Array=game.units.filter(func(unit):return unit.kind=="guard")
 var squad:Array=workers.slice(0,4)
 select(squad)
 var intended:Array=selected_ids()
 var before_orders:Array=orders()
 var bank:Dictionary=game.stockpile.duplicate(true)
 game.paused=false
 hud._show_selection()
 var owned= hud.popup
 check(game.paused,"Selection details pauses a running game")
 check(tagged("mobile_group_recall",1)==null,"Empty slots do not clutter default panel")
 press_tag("mobile_group_register",true)
 check(hud.popup==owned and game.paused and not hud.popup_previous_pause,"Registration retains original popup and prior running state")
 var destinations:Array=buttons().filter(func(button):return button.has_meta("mobile_group_destination"))
 check(destinations.size()==9,"Registration exposes all existing nine slots")
 press_tag("mobile_group_destination",1)
 check(slot_ids(1)==intended and not hud.has_open_popup() and not game.paused,"Empty-slot tap registers exact four and restores running state")
 check(orders()==before_orders and game.stockpile==bank,"Registration changes no orders or resources")

 select(guards)
 game.camera_focus=Vector3(18,0,18)
 hud._show_selection();press_tag("mobile_group_recall",1)
 var expected_focus=Vector3.ZERO
 for unit in squad:expected_focus+=unit.node.position
 expected_focus/=squad.size()
 expected_focus=Vector3(clampf(expected_focus.x,-18,18),0,clampf(expected_focus.z,-18,18))
 check(selected_ids()==intended and game.camera_focus==expected_focus,"Saved subgroup recalls and centers in one tap after another selection")
 check(not hud.has_open_popup() and not game.paused,"Recall closes panel and restores running state")
 check(orders()==before_orders and game.stockpile==bank,"Recall changes no orders or resources")

 select(guards);game.paused=true
 hud._show_selection();owned=hud.popup
 press_tag("mobile_group_register",true);press_tag("mobile_group_destination",1)
 check(slot_ids(1)==intended and tagged("mobile_group_overwrite",1)!=null,"Occupied slot waits for explicit overwrite confirmation")
 check(hud.popup==owned and game.paused and hud.popup_previous_pause,"Overwrite view shares one popup and prior paused state")
 press_text("キャンセル")
 check(tagged("mobile_group_destination",9)!=null and slot_ids(1)==intended,"Overwrite Cancel returns to destinations without replacing group")
 press_text("キャンセル")
 check(tagged("mobile_group_recall",1)!=null,"Registration Cancel returns to selection details")
 hud._close_popup();hud._close_popup()
 check(game.paused,"Nested cancel and repeated close retain prior paused state")
 hud._show_selection();press_tag("mobile_group_register",true);press_tag("mobile_group_destination",1)
 press_tag("mobile_group_overwrite",1)
 check(slot_ids(1)==selected_ids() and game.paused and not hud.has_open_popup(),"Explicit overwrite replaces group and retains prior paused state")

 game.select_headquarters()
 var headquarters:Dictionary=game.inspected
 hud._show_selection();press_tag("mobile_group_register",true);press_tag("mobile_group_destination",2)
 select(squad);hud._show_selection();press_tag("mobile_group_recall",2)
 check(game.selected.is_empty() and game.inspected==headquarters,"Building registration and recall use the existing inspected building")
 check(orders()==before_orders and game.stockpile==bank,"Unit/building switches do not mutate orders or resources")

 select(workers.slice(0,2));game.assign_control_group(3)
 var old_hp:float=workers[0].hp
 workers[0].hp=0
 select(guards);hud._show_selection()
 check(slot_ids(3)==[workers[1].node.get_instance_id()],"Opening list resolves and filters dead members")
 press_tag("mobile_group_recall",3)
 check(selected_ids()==[workers[1].node.get_instance_id()],"Recall includes only surviving members")
 workers[1].hp=0
 hud._show_selection()
 check(tagged("mobile_group_recall",3)==null and not game.control_groups.slots.has(3),"Fully dead group disappears without an empty default button")
 hud._close_popup()
 workers[0].hp=old_hp;workers[1].hp=old_hp

 select([]);hud._show_selection()
 check(tagged("mobile_group_register",true).disabled,"Nothing selected disables registration")
 hud._close_popup()
 select(squad)
 for slot in range(1,10):game.assign_control_group(slot)
 hud._show_selection()
 await settle()
 var scroll:ScrollContainer=hud.popup.get_meta("scroll")
 var group_buttons:Array=buttons().filter(func(button):return button.has_meta("mobile_group_recall"))
 check(group_buttons.size()==9,"All nine saved slots remain reachable")
 for button in group_buttons:
  check(button.size.x>=48 and button.size.y>=48 and button.mouse_filter==Control.MOUSE_FILTER_PASS,"Group touch target is at least 48 CSS units and permits scroll drag")
 check(scroll.vertical_scroll_mode==ScrollContainer.SCROLL_MODE_AUTO,"Portrait group panel retains vertical scroll support")
 check(hud.safe_rect.encloses(scroll.get_global_rect()),"Portrait popup remains inside safe area")
 press_tag("mobile_group_register",true)
 check(hud.popup.get_meta("scroll")==scroll,"Registration reuses safe-area scroll container")
 await settle()
 check(scroll.scroll_vertical==0,"Popup navigation resets scroll position")
 root.size=Vector2i(844,390);root.content_scale_size=Vector2i(844,390)
 hud.set_safe_insets(Vector4(40,0,40,20))
 await settle()
 check(hud.safe_rect.encloses(scroll.get_global_rect()),"Landscape rotation keeps same popup inside safe area")
 check(scroll.get_global_rect().encloses(tagged("mobile_group_destination",9).get_global_rect()),"All nine destinations fit phone landscape without scrolling")
 for button in buttons():
  if button.text=="キャンセル":check(scroll.get_global_rect().encloses(button.get_global_rect()),"Registration Cancel fits phone landscape without scrolling")
 hud._close_popup()
 check(game.paused and game.stockpile==bank,"Final close retains prior pause and resources")
 game.queue_free();await process_frame
 print("MOBILE_GROUPS checks=",checks," failures=",failures)
 quit(1 if failures else 0)
