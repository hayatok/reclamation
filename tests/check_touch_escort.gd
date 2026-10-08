extends SceneTree
var failures=0
func _initialize():call_deferred("run")
func check(ok:bool,title:String):
 if not ok:failures+=1;push_error(title)
func run():
 var c=root.get_node("Campaign");c.current=1;c.launch=true;c.resume=false;c.muted=true
 root.size=Vector2i(844,390);root.content_scale_size=Vector2i(844,390)
 var g=load("res://main.tscn").instantiate();root.add_child(g);g.set_process(false)
 var leader=g.make_unit("siegecart",g.map_config.home+Vector3(7,0,4))
 var followers=[g.units[0],g.units[1]]
 g.selected=followers+[leader];g.inspected={};g.update_selection()
 g.camera_focus=leader.node.position;g.camera.position=g.camera_focus+Vector3(37,48,43);g.camera.look_at(g.camera_focus)
 await process_frame;await process_frame
 g.mobile_hud.sync();g.mobile_input.sync()
 g.touch_set_mode(1);g.touch_set_append(true);g.begin_escort();g.mobile_hud.sync()
 check(g.mobile_input.controller.mode==0 and not g.mobile_input.controller.append,"escort clears stale range/add state")
 check(not g.mobile_hud.cancel_button.disabled,"touch cancel is enabled")
 var at=g.camera.unproject_position(leader.node.position+Vector3(0,.8,0))
 check(not g.mobile_hud.is_over_ui(at),"target is in usable battlefield")
 for pressed in [true,false]:
  var event=InputEventScreenTouch.new();event.index=0;event.position=at;event.pressed=pressed;g._input(event)
 check(followers.all(func(u):return u.task=="escort" and u.target==leader),"touch selects already-selected leader as target")
 check(g.selected.size()==3 and not g.escort_targeting,"touch preserves selection and clears mode")
 g.begin_escort();g.touch_cancel();check(not g.escort_targeting and followers[0].task=="escort","touch cancel keeps issued orders")
 g.begin_escort();g.touch_set_mode(1);check(not g.escort_targeting,"range choice replaces escort targeting")
 g.begin_escort();g.show_options();check(not g.escort_targeting,"options cancels transient targeting")
 g.close_options()
 g.begin_escort();g._mobile_reset("resize");check(not g.escort_targeting,"resize cancels targeting")
 var saved=g.checkpoint_data()
 DirAccess.make_dir_recursive_absolute("user://settlement_v2")
 var f=FileAccess.open("user://settlement_v2/checkpoint.json",FileAccess.WRITE);f.store_string(JSON.stringify(saved));f.close()
 check(g.load_checkpoint(),"actual escort save/reload")
 check(g.selected_escort_summary().contains("移動迫撃車"),"restored leader feedback")
 print("TOUCH_ESCORT_RESULT failures=",failures)
 g.free();await process_frame;quit(1 if failures else 0)
