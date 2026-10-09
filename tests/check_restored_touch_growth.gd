extends SceneTree
var failures=0
var g
func check(value:bool,message:String):
 print("PASS " if value else "FAIL ",message)
 if not value:failures+=1
func _initialize():call_deferred("run")
func settle():
 for i in 3:await process_frame
 g.mobile_hud.sync()
 await process_frame
func mouse(at:Vector2,pressed:bool):
 var move=InputEventMouseMotion.new();move.position=at;move.global_position=at
 Input.parse_input_event(move);Input.flush_buffered_events()
 var e=InputEventMouseButton.new();e.device=InputEvent.DEVICE_ID_EMULATION;e.position=at;e.global_position=at;e.button_index=MOUSE_BUTTON_LEFT;e.button_mask=MOUSE_BUTTON_MASK_LEFT if pressed else 0;e.pressed=pressed
 Input.parse_input_event(e);Input.flush_buffered_events()
func reload_game():
 if g!=null:g.free();await process_frame
 var c=root.get_node("Campaign");c.current=1;c.launch=true;c.resume=true;c.muted=true
 g=load("res://main.tscn").instantiate();root.add_child(g);g.set_process(false)
 await settle()
func ordered()->bool:return g.choice_panel.get_parent()==g.mobile_hud.get_parent() and g.choice_panel.get_index()>g.mobile_hud.get_index()
func run():
 DirAccess.make_dir_recursive_absolute("user://settlement_v2")
 var f=FileAccess.open("user://settlement_v2/checkpoint.json",FileAccess.WRITE);f.store_string(FileAccess.get_file_as_string("res://tests/fixtures/earned_frontier_growth_resume.json"));f.close()
 await reload_game()
 check(g.active_card and ordered(),"resumed card modal is above HUD")
 var before=g.checkpoint_data()
 for at in [Vector2(12,12),Vector2(12,root.size.y-20)]:
  var motion=InputEventMouseMotion.new();motion.position=at;motion.global_position=at
  Input.parse_input_event(motion);Input.flush_buffered_events();await process_frame
  var hovered=root.gui_get_hovered_control()
  check(hovered!=null and (hovered==g.choice_panel or g.choice_panel.is_ancestor_of(hovered)),"former HUD region targets the growth modal")
 check(g.checkpoint_data().cards==before.cards and g.card_rng.state==int(before.card_rng),"presentation does not reroll offers")
 g.reroll_cards();await settle();check(ordered(),"replacement after reroll stays modal")
 var offers=g.cards.map(func(c):return c.id);var rng=g.card_rng.state
 g.postpone_growth_choice();await settle();check(not g.active_card,"postpone returns to normal HUD")
 check(g.open_growth_choices(),"reopen existing choices");await settle()
 check(ordered() and g.cards.map(func(c):return c.id)==offers and g.card_rng.state==rng,"reopen preserves cards and RNG")
 check(g.save_checkpoint(false)==OK,"save while choices are open")
 await reload_game();check(ordered() and g.cards.map(func(c):return c.id)==offers and g.card_rng.state==rng,"second scene reload keeps offers and topmost panel")
 var buttons=g.choice_panel.find_children("*","Button",true,false).filter(func(b):return b.text=="この強化を採用")
 check(buttons.size()==3,"all three adoption controls exist")
 var point=buttons[0].get_global_rect().get_center()
 var ranks=g.upgrades.duplicate(true)
 mouse(point,true);await process_frame;g._mobile_reset("resize");mouse(point,false);await settle()
 check(g.active_card and g.upgrades==ranks,"interrupted press cannot apply upgrade")
 mouse(point,true);await process_frame;mouse(point,false);await settle()
 check(not g.active_card and g.upgrades[offers[0]]==ranks[offers[0]]+1,"fresh tap applies chosen upgrade once")
 mouse(point,false);await process_frame
 check(g.upgrades[offers[0]]==ranks[offers[0]]+1,"duplicate release cannot reapply upgrade")
 print("RESTORED_TOUCH_GROWTH_RESULT failures=",failures," viewport=",root.size)
 g.free();g=null;await process_frame;quit(1 if failures else 0)
