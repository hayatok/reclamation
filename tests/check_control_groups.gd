extends SceneTree
const Validation=preload("res://checkpoint_validation.gd")
const PATH="user://settlement_v2/checkpoint.json"
var g:Node
var passed:int=0
var failed:int=0
func _initialize():call_deferred("run")
func check(ok:bool,label:String):
 if ok:passed+=1;print("PASS ",label)
 else:failed+=1;push_error("FAIL "+label)
func press(key:int,ctrl:bool=false,shift:bool=false,echo:bool=false):
 var event=InputEventKey.new();event.keycode=key;event.pressed=true
 event.ctrl_pressed=ctrl;event.shift_pressed=shift;event.echo=echo
 g._input(event);g._unhandled_input(event)
func select_units(value:Array):
 g.selected=value.duplicate();g.inspected={};g.inspected_resource={};g.inspected_site={};g.update_selection()
func select_building(value:Dictionary):
 g.selected=[];g.inspected=value;g.inspected_resource={};g.inspected_site={};g.update_selection()
func remove_save_files():
 for suffix in ["",".bak",".tmp",".bak.tmp"]:
  if FileAccess.file_exists(PATH+suffix):DirAccess.remove_absolute(PATH+suffix)
func write_checkpoint(data:Dictionary):
 remove_save_files()
 var file=FileAccess.open(PATH,FileAccess.WRITE);file.store_string(JSON.stringify(data));file.close()
func run():
 if DirAccess.dir_exists_absolute("user://settlement_v2"):
  push_error("Fresh isolated XDG_DATA_HOME required");quit(2);return
 var campaign=root.get_node("Campaign");campaign.current=0;campaign.launch=true;campaign.resume=false;campaign.muted=true
 g=load("res://main.tscn").instantiate();root.add_child(g);current_scene=g;g.set_process(false)
 await process_frame
 var west=[g.units[0],g.make_unit("guard",Vector3(-10,0,3))]
 var east=[g.units[1],g.make_unit("guard",Vector3(10,0,3))]
 var worker:Dictionary=g.units[2]
 var barracks:Dictionary=g.make_building("barracks",Vector3(12,0,20),true)
 var camera_before:Vector3=g.camera_focus
 select_units(west);press(KEY_1,true)
 select_units(east);press(KEY_2,true)
 select_building(barracks);press(KEY_3,true)
 check(g.control_groups.slots.size()==3,"Ctrl+1/2 register independent defense squads and Ctrl+3 registers a producer")
 check(g.camera_focus==camera_before,"assigning groups never moves the camera")
 press(KEY_1)
 check(g.selected==west and g.inspected.is_empty(),"1 recalls only the west squad")
 check(g.camera_focus==camera_before,"single recall leaves camera unchanged")
 press(KEY_Q);g.command_at(Vector3(-15,0,0))
 check(west.all(func(unit):return unit.task=="attack_move") and east.all(func(unit):return unit.task=="idle"),"group 1 contextual Q/right click orders only the west defenders")
 var west_goals=west.map(func(unit):return unit.goal)
 press(KEY_2);g.command_at(Vector3(15,0,0))
 check(g.selected==east and west.map(func(unit):return unit.goal)==west_goals,"group 2 commands preserve west squad orders and replace selection")
 check(not g.attack_move,"recall cancels the prior targeting mode")
 press(KEY_3)
 check(g.selected.is_empty() and g.inspected==barracks,"producer recall clears units and inspects its building")
 var food:float=g.stockpile.food
 press(KEY_Q)
 check(barracks.queue.size()==1 and g.buildings[0].queue.is_empty() and g.stockpile.food==food-60,"recalled producer Q retains local paid production")
 g.command_at(Vector3(16,0,15))
 check(barracks.rally==Vector3(16,0,15),"right click after producer recall changes only that producer rally")
 g.camera_focus=Vector3(0,0,-10);g.reset_control_group_tap()
 g.recall_control_group(1,1000)
 check(g.camera_focus==Vector3(0,0,-10),"first deterministic tap does not center")
 g.recall_control_group(1,1200)
 check(g.camera_focus==(west[0].node.position+west[1].node.position)*.5,"same group within 350ms centers living squad centroid")
 g.camera_focus=Vector3(0,0,-10);g.recall_control_group(2,1500);g.recall_control_group(1,1600)
 check(g.camera_focus==Vector3(0,0,-10),"different group in quick succession does not center")
 g.recall_control_group(1,2000)
 check(g.camera_focus==Vector3(0,0,-10),"same group outside double-tap interval does not center")
 g.reset_control_group_tap();press(KEY_3);press(KEY_3)
 check(g.camera_focus==Vector3(12,0,18),"producer double tap centers building within existing camera bounds")
 g.camera_focus=Vector3(0,0,-10);press(KEY_1);press(KEY_Q);press(KEY_1)
 check(g.camera_focus==Vector3(0,0,-10),"intervening command breaks double-tap sequence")
 var click=InputEventMouseButton.new();click.button_index=MOUSE_BUTTON_LEFT;click.pressed=true
 g._input(click);press(KEY_1)
 check(g.camera_focus==Vector3(0,0,-10),"HUD/world click breaks double-tap sequence")
 press(KEY_1,false,false,true)
 check(g.camera_focus==Vector3(0,0,-10),"held-key echo never counts as a second tap")
 select_units(east);press(KEY_1,false,true);press(KEY_1,true,true)
 check(g.selected==east and g.control_groups.resolve(1,g.units,g.buildings).units==west,"Shift+number neither adds selections nor overwrites groups")
 press(KEY_C)
 check(g.selected.size()==4 and g.selected.all(func(unit):return unit.kind=="guard"),"C selects all combat units")
 press(KEY_V)
 check(g.selected.size()==6 and g.selected.all(func(unit):return unit.kind=="worker"),"V selects all workers")
 press(KEY_Q)
 check(g.build_mode=="house","worker Q retains building placement")
 press(KEY_2)
 check(g.selected==east and g.build_mode.is_empty() and not g.ghost.visible,"group recall exits build placement and selects intended squad")
 g.paused=true;press(KEY_1)
 check(g.selected==west and g.paused,"groups work during tactical pause")
 g.paused=false
 # Invalid, dead and removed members cannot be recalled or serialized.
 west[1].hp=0;press(KEY_2);press(KEY_1)
 check(g.selected==[west[0]],"dead squad member is filtered before commands")
 g.units.erase(west[1]);west[1].node.queue_free()
 var survivor:Dictionary=west[0]
 g.units.erase(survivor);survivor.node.queue_free();press(KEY_2);press(KEY_1)
 check(g.selected==east and not g.control_groups.slots.has(1),"all-dead group leaves current selection unchanged and removes stale group")
 press(KEY_9)
 check(g.selected==east,"unassigned number leaves selection unchanged")
 select_units([]);press(KEY_2,true);press(KEY_2)
 check(g.selected==east,"empty assignment preserves prior registered group")
 select_units([east[0]]);press(KEY_2,true);press(KEY_2)
 check(g.selected==[east[0]],"Ctrl+number replaces membership without appending")
 select_units(east);press(KEY_2,true)
 # Save actual current actors, restore new identities, then recall.
 var data:Dictionary=g.checkpoint_data()
 check(Validation.validate(data) and data.control_groups.size()==2,"actual group checkpoint passes full validator")
 check(g.save_checkpoint(false)==OK,"group checkpoint writes through existing atomic save")
 var old_node_id:int=east[0].node.get_instance_id()
 g.control_groups.slots.clear()
 check(g.load_checkpoint(),"actual group checkpoint reloads")
 press(KEY_2)
 check(g.selected.size()==2 and g.selected[0].node.get_instance_id()!=old_node_id and g.selected[0] in g.units,"restored groups bind new scene actors")
 press(KEY_3)
 check(g.inspected.kind=="barracks" and g.inspected.queue.size()==1,"restored building group retains producer queue context")
 var mutations=[]
 for bad_value in [null,{},"invalid",[{"slot":0,"kind":"units","members":[0]}],[{"slot":10,"kind":"units","members":[0]}],[{"slot":1.5,"kind":"units","members":[0]}],[{"slot":1,"kind":"enemy","members":[0]}],[{"slot":1,"kind":"units","members":[]}],[{"slot":1,"kind":"units","members":[-1]}],[{"slot":1,"kind":"units","members":[999]}],[{"slot":1,"kind":"units","members":[0.5]}],[{"slot":1,"kind":"units","members":[0,0]}],[{"slot":1,"kind":"building","members":[0,1]}],[{"slot":1,"kind":"building","members":[999]}],[{"slot":1,"kind":"units","members":[0]},{"slot":1,"kind":"units","members":[1]}]]:
  var bad=data.duplicate(true);bad.control_groups=bad_value;mutations.append(bad)
 var rejected=0
 for bad in mutations:
  if not Validation.validate(bad):rejected+=1
 check(rejected==mutations.size(),"all 15 malformed group shapes and references are rejected")
 var state=JSON.stringify(g.checkpoint_data());var ids=g.units.map(func(unit):return unit.node.get_instance_id())
 write_checkpoint(mutations.back())
 check(not g.load_checkpoint() and JSON.stringify(g.checkpoint_data())==state and g.units.map(func(unit):return unit.node.get_instance_id())==ids,"invalid group load leaves entire live world and groups unchanged")
 var legacy=data.duplicate(true);legacy.erase("control_groups")
 check(Validation.validate(legacy),"checkpoint without optional groups remains valid")
 write_checkpoint(legacy)
 check(g.load_checkpoint() and g.control_groups.slots.is_empty(),"loading earlier checkpoint clears stale groups")
 # Modal priority: cards keep 1/2/3; modifiers never assign or choose.
 select_units([g.units[0]]);press(KEY_1,true)
 var registered=g.control_groups.slots.duplicate(true)
 g.xp=286;g.bank_earned_upgrades();g.open_growth_choices()
 var level_count:int=g.pending_upgrade_levels.size()
 press(KEY_1,true)
 check(g.active_card and g.pending_upgrade_levels.size()==level_count and g.control_groups.slots==registered,"Ctrl+1 while growth cards are open changes neither cards nor groups")
 var card_id:String=g.cards[0].id;press(KEY_1)
 check(g.upgrades.get(card_id,0)==1 and g.pending_upgrade_levels.size()==level_count-1 and g.control_groups.slots==registered,"bare 1 chooses growth card before group recall")
 if g.active_card:g.postpone_growth_choice()
 g.show_options();select_units([]);press(KEY_1);press(KEY_2,true)
 check(g.selected.is_empty() and g.control_groups.slots==registered,"options modal blocks recall and assignment")
 g.close_options();await process_frame
 var producer:Dictionary=g.buildings.filter(func(building):return building.kind=="barracks")[0]
 select_building(producer);press(KEY_3,true)
 g.buildings.erase(producer);producer.node.queue_free()
 select_units([g.units[0]]);press(KEY_3)
 check(g.selected==[g.units[0]] and g.inspected.is_empty() and not g.control_groups.slots.has(3),"destroyed production building cannot be recalled")
 # Actual visible help reuses the existing command panel and has font coverage.
 check(not g.hint.visible and g.command_detail.visible and g.command_detail.text.contains("Ctrl+1") and g.command_detail.text.contains("C 全戦闘員") and g.command_detail.text.contains("V 全作業員"),"existing detail line explains group and global keys without another help bar")
 select_units([g.units.filter(func(unit):return unit.kind=="worker")[0]])
 g.worker_build_page="military";g.refresh_context_commands(true)
 await process_frame;await process_frame;await process_frame
 var panel:Control=g.command_detail.get_parent().get_parent()
 check(g.root_ui.get_global_rect().encloses(panel.get_global_rect()) and panel.get_global_rect().encloses(g.command_detail.get_global_rect()),"existing command panel and shortcut help fit viewport in largest build context")
 check(g.command_detail.get_theme_font("font").get_string_size(g.command_detail.text,HORIZONTAL_ALIGNMENT_LEFT,-1,g.command_detail.get_theme_font_size("font_size")).x<=g.command_detail.size.x,"complete shortcut help fits its existing row without clipping")
 select_units([])
 var edit=LineEdit.new();g.root_ui.add_child(edit);edit.grab_focus();press(KEY_1)
 check(g.selected.is_empty(),"focused text input blocks game shortcuts")
 edit.queue_free()
 print("CONTROL_GROUPS_SUMMARY passed=%d failed=%d"%[passed,failed])
 g.queue_free();await process_frame;quit(1 if failed else 0)
