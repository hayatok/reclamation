extends SceneTree
var g:Node
var states:Dictionary={}
func _initialize():call_deferred('run')
func capture(label:String):states[label]=g.checkpoint_data()
func run():
 var output='user://choice_comparison.json'
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with('--out='):output=arg.trim_prefix('--out=')
 DirAccess.make_dir_recursive_absolute('user://settlement_v2')
 var f=FileAccess.open('user://settlement_v2/checkpoint.json',FileAccess.WRITE);f.store_string(FileAccess.get_file_as_string('res://tests/fixtures/earned_critical_factory.json'));f.close()
 var c=root.get_node('Campaign');c.current=1;c.launch=true;c.resume=true;c.muted=true
 g=load('res://main.tscn').instantiate();root.add_child(g);current_scene=g;g.set_process(false)
 assert(g.elapsed>500 and not g.pending_upgrade_levels.is_empty());assert(g.open_growth_choices());capture('opened')
 for frame in 2:await process_frame
 if g.mobile_enabled:
  g.mobile_hud.sync();assert(g.choice_panel.find_children('UpgradeDiagram_*','',true,false).is_empty())
  if ResourceLoader.exists('res://upgrade_diagram.gd'):assert(load('res://upgrade_diagram.gd')._textures.is_empty())
 else:
  var diagrams=g.choice_panel.find_children('UpgradeDiagram_*','',true,false)
  if ResourceLoader.exists('res://upgrade_diagram.gd'):
   assert(diagrams.size()==3)
   for i in 3:assert(diagrams[i].get_meta('upgrade_id')==g.cards[i].id)
 if g.rerolls>0:g.reroll_cards()
 capture('rerolled')
 var ids=g.cards.map(func(card):return card.id);var rng_state=g.card_rng.state
 g.postpone_growth_choice();capture('postponed');assert(g.open_growth_choices());capture('reopened')
 assert(g.cards.map(func(card):return card.id)==ids and g.card_rng.state==rng_state)
 var picked=g.cards[0].id;var old_rank=g.upgrades.get(picked,0);g.choose_upgrade(0);assert(g.upgrades[picked]==old_rank+1)
 var once=g.upgrades.duplicate(true);g.choose_upgrade(0);assert(once==g.upgrades);capture('chosen')
 assert(g.save_checkpoint(false)==OK);assert(g.load_checkpoint());capture('resumed')
 f=FileAccess.open(output,FileAccess.WRITE);f.store_string(JSON.stringify(states,'  '));f.close()
 print('INTEGRATED_GROWTH_FLOW_PASS mobile=',g.mobile_enabled,' picked=',picked,' earned_time=',g.elapsed)
 quit()
