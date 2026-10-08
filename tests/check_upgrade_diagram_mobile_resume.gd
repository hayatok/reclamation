extends SceneTree
func _initialize():call_deferred('run')
func run():
 DirAccess.make_dir_recursive_absolute('user://settlement_v2')
 var f=FileAccess.open('user://settlement_v2/checkpoint.json',FileAccess.WRITE);f.store_string(FileAccess.get_file_as_string('res://tests/fixtures/earned_critical_factory.json'));f.close()
 var c=root.get_node('Campaign');c.current=1;c.launch=true;c.resume=true;c.muted=true
 var g=load('res://main.tscn').instantiate();root.add_child(g);current_scene=g;g.set_process(false)
 assert(g.open_growth_choices());var offers=g.cards.map(func(card):return card.id);var state=g.card_rng.state
 assert(g.save_checkpoint(false)==OK)
 root.remove_child(g);g.free();c.resume=true
 g=load('res://main.tscn').instantiate();root.add_child(g);current_scene=g;g.set_process(false)
 for frame in 3:await process_frame
 g.mobile_hud.sync()
 assert(g.active_card and g.cards.map(func(card):return card.id)==offers and g.card_rng.state==state)
 assert(g.mobile_hud.fitted_panels.has(g.choice_panel.get_instance_id()))
 assert(load('res://upgrade_diagram.gd')._textures.is_empty())
 var count=0
 for button in g.choice_panel.find_children('*','Button',true,false):
  if button.text=='この強化を採用':count+=1
 assert(count==3)
 print('MOBILE_ACTIVE_CHOICE_SCENE_RELOAD_PASS: three choices, RNG, no desktop art allocation')
 quit()
