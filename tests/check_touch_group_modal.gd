extends SceneTree
var game
var failures=0
var checks=0
func _initialize():call_deferred("run")
func check(ok:bool,message:String):
 checks+=1
 if not ok:failures+=1;push_error(message)
func key(code:int,ctrl:bool=false):
 var event=InputEventKey.new();event.keycode=code;event.pressed=true;event.ctrl_pressed=ctrl
 game._input(event);game._unhandled_input(event)
func run():
 if DirAccess.dir_exists_absolute("user://settlement_v2"):push_error("Fresh data required");quit(2);return
 var campaign=root.get_node("Campaign");campaign.current=0;campaign.launch=true;campaign.resume=false;campaign.muted=true
 root.size=Vector2i(844,390)
 game=load("res://main.tscn").instantiate();root.add_child(game);current_scene=game;game.set_process(false);game.paused=false
 await process_frame
 game.select_guards();var guards=game.selected.duplicate();game.assign_control_group(1)
 game.level=2;game.pending_upgrade_levels=[2] # A real pending choice makes the Tab modal gate observable.
 game.mobile_hud._show_selection()
 var groups=game.control_groups.snapshot(game.units,game.buildings)
 for code in [KEY_C,KEY_V,KEY_H,KEY_SPACE,KEY_TAB]:
  key(code)
  check(game.selected==guards and game.paused and not game.active_card and game.mobile_hud.has_open_popup(),"Touch popup blocks gameplay key %d"%code)
 key(KEY_2,true)
 check(game.control_groups.snapshot(game.units,game.buildings)==groups,"Ctrl registration cannot overwrite behind mobile popup")
 key(KEY_ESCAPE)
 check(not game.mobile_hud.has_open_popup() and not game.paused,"Escape closes owned popup and restores running state")
 game.select_workers();game.assign_control_group(2);game.paused=true
 check(game.save_checkpoint(false)==OK,"Existing checkpoint saves touch/PC shared groups")
 var expected=game.control_groups.snapshot(game.units,game.buildings)
 check(game.load_checkpoint(),"Checkpoint restores successfully")
 check(game.control_groups.snapshot(game.units,game.buildings)==expected,"Group membership survives save/reload exactly")
 game.mobile_hud._show_selection()
 var button:Button
 for candidate in game.mobile_hud.popup.find_children("*","Button",true,false):
  if candidate.get_meta("mobile_group_recall",0)==1:button=candidate;break
 check(is_instance_valid(button),"Saved group is reachable through touch UI after reload")
 if is_instance_valid(button):button.pressed.emit()
 check(game.selected.size()==2 and game.selected.all(func(u):return u.kind=="guard") and game.paused and not game.mobile_hud.has_open_popup(),"Touch recall restores saved fighters and prior pause")
 game.queue_free();await process_frame
 print("TOUCH_GROUP_MODAL checks=",checks," failures=",failures);quit(1 if failures else 0)
