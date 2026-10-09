extends SceneTree
func _initialize():call_deferred("run")
func click_event(point:Vector2,pressed:bool=true,shift:bool=false)->InputEventMouseButton:
 var e=InputEventMouseButton.new();e.button_index=MOUSE_BUTTON_LEFT;e.position=point;e.pressed=pressed;e.double_click=true;e.shift_pressed=shift;return e
func world_state(g:Node)->Dictionary:
 var state=g.checkpoint_data();state.erase("selected");return state
func run():
 DirAccess.make_dir_recursive_absolute("user://settlement_v2")
 var f=FileAccess.open("user://settlement_v2/checkpoint.json",FileAccess.WRITE);f.store_string(FileAccess.get_file_as_string("res://tests/fixtures/earned_siege_escort.json"));f.close()
 var c=root.get_node("Campaign");c.current=1;c.launch=true;c.resume=true;c.muted=true
 var g=load("res://main.tscn").instantiate();root.add_child(g);g.set_process(false);g.paused=true
 assert(not g.title_open)
 var grenades=g.units.filter(func(u):return u.kind=="grenade")
 var guard=g.units.filter(func(u):return u.kind=="guard" and u.task=="escort")[0]
 var siege=g.units.filter(func(u):return u.kind=="siegecart")[0]
 g.camera_focus=siege.node.position+Vector3(9,0,-5);g.camera.position=g.camera_focus+Vector3(37,48,43);g.camera.look_at(g.camera_focus);g.camera.size=50
 var point=g.camera.unproject_position(grenades[0].node.position+Vector3(0,.8,0));var before=world_state(g)
 g._unhandled_input(click_event(point));g._unhandled_input(click_event(point,false))
 assert(g.selected.size()==2 and g.selected.all(func(u):return u.kind=="grenade") and not g.dragging)
 assert(world_state(g)==before)
 g.selected=[guard];g._unhandled_input(click_event(point,true,true));g._unhandled_input(click_event(point,false,true));assert(g.selected.size()==3 and guard in g.selected)
 g.active_card=true;var held=g.selected.duplicate();g._unhandled_input(click_event(point));assert(g.selected==held);g.active_card=false
 g.selected=[guard,grenades[0],siege];var groups=g.selection_kind_counts();assert(groups.size()==3 and groups[1].kind=="grenade" and groups[1].count==1)
 assert(g.filter_selected_kind("grenade") and g.selected.size()==1 and g.selected[0]==grenades[0],"mobile-style filter must not recruit the other grenade from outside current selection")
 assert(world_state(g)==before)
 assert(not g.filter_selected_kind("worker") and g.selected.size()==1)
 assert(g.save_checkpoint(false)==OK and g.load_checkpoint());assert(g.selected.size()==1 and g.selected[0].kind=="grenade")
 print("UNIT_TYPE_INTEGRATION_PASS: double-click exact type, release retains group, shift adds, card blocks, selected-only filter, orders/world unchanged, save/reload")
 g.free();quit()
