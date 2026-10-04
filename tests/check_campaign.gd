extends SceneTree
var game
func _initialize():call_deferred("run")
func run():
 var campaign=root.get_node("Campaign")
 campaign.launch=true
 game=load("res://main.tscn").instantiate()
 root.add_child(game)
 await process_frame
 game.title_open=false
 game.resources=233
 game.gathered=77
 game.select_workers()
 game.assign_site("generator")
 game.spawn_enemy(Vector3(-20,0,-20))
 game.offer_upgrade()
 var saved_ids=game.cards.map(func(card):return card.id)
 var saved_rng=game.card_rng.state
 var saved_xp=game.xp
 game.save_checkpoint(false)
 game.choose_upgrade(0)
 game.resources=1
 assert(game.load_checkpoint())
 assert(game.resources==233)
 assert(game.gathered==77)
 assert(game.cards.map(func(card):return card.id)==saved_ids)
 assert(game.card_rng.state==saved_rng)
 assert(game.active_card)
 assert(game.selected.size()==3)
 assert(game.units[6].task=="site")
 assert(game.units[6].target==game.get_site("generator"))
 assert(game.enemies.size()==1)
 assert(game.xp==saved_xp)
 print("SAVE_LOAD_EXACT_CARDS_ORDERS_RNG_XP_PASS")
 game.choose_upgrade(0)
 game.paused=true
 game.offer_upgrade()
 game.choose_upgrade(0)
 assert(game.paused)
 print("SEPARATE_PAUSE_REASONS_PASS")
 assert(campaign.MISSIONS[0].mode=="restore" and campaign.MISSIONS[0].hold==120)
 assert(campaign.MISSIONS[1].mode=="convoy")
 assert(campaign.MISSIONS[2].mode=="finale" and campaign.MISSIONS[2].hold==180)
 print("CAMPAIGN_CONFIG_PASS")
 game.queue_free()
 await process_frame
 quit()
