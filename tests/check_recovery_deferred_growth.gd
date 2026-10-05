extends SceneTree
var g:Node
func _initialize():call_deferred("run")
func run():
 var campaign=root.get_node("Campaign");campaign.current=0;campaign.launch=true;campaign.resume=false
 g=load("res://main.tscn").instantiate();root.add_child(g);current_scene=g
 g.set_process(false)
 var goal=g.units[0].goal
 var state=str(g.card_rng.state)
 g.xp=286
 assert(g.bank_earned_upgrades()==3)
 assert(g.pending_upgrade_levels==[2,3,4] and g.level==4 and g.xp==1)
 assert(not g.active_card and not g.paused and g.units[0].goal==goal and str(g.card_rng.state)==state)
 g.paused=true
 assert(g.open_growth_choices())
 assert(g.cards.size()==3 and g.active_card)
 var ids=g.cards.map(func(card):return card.id)
 state=str(g.card_rng.state)
 assert(not g.open_growth_choices())
 g.postpone_growth_choice()
 assert(g.paused and not g.active_card and g.cards.map(func(card):return card.id)==ids and str(g.card_rng.state)==state)
 await process_frame
 assert(g.open_growth_choices())
 assert(g.cards.map(func(card):return card.id)==ids and str(g.card_rng.state)==state)
 g.choose_upgrade(-1)
 assert(g.active_card and g.pending_upgrade_levels.size()==3)
 var id=g.cards[0].id;var rank=g.upgrades.get(id,0)
 g.choose_upgrade(0);g.choose_upgrade(0)
 assert(g.upgrades[id]==rank+1 and g.pending_upgrade_levels==[3,4] and g.paused)
 print("RECOVERY_DEFERRED_GROWTH_PASS")
 g.queue_free();await process_frame;quit()
