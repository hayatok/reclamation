extends SceneTree
const Catalog=preload("res://upgrade_catalog.gd")
func _initialize():call_deferred("run")
func run():
 root.get_node("Campaign").launch=true
 root.get_node("Campaign").current=0
 var game=load("res://main.tscn").instantiate()
 root.add_child(game)
 game.set_process(false)
 game.muted=true
 assert(game.tutorial_instruction().contains("残骸"))
 game.gathered=20
 assert(game.tutorial_instruction().contains("発電所"))
 game.get_site("generator").reclaimed=true
 assert(game.tutorial_instruction().contains("増援"))
 game.upgrades={"damage":1,"chain":1}
 assert(game.upgrade_preview(Catalog.by_id("damage")).contains("+20% → +40%"))
 assert(game.upgrade_preview(Catalog.by_id("chain")).contains("2 → 4体"))
 for data in Catalog.all():assert(not game.upgrade_preview(data).is_empty())
 game.select_workers()
 game.command_at(Vector3(-10,0,9))
 assert(game.selected_order_text()=="回収中")
 game.attack_move=true
 assert(game.selected_order_text().contains("指示待ち"))
 game.attack_move=false
 var factory=game.make_building("factory",Vector3(10,0,-5),true)
 game.generator_on=true;game.power_clock=0;game.resources=0;game.ammo=100
 game.update_economy(.05)
 assert(game.factory_status(factory)=="資材不足")
 factory.enabled=false
 assert(game.factory_status(factory)=="手動停止")
 factory.enabled=true;factory.powered=false
 assert(game.factory_status(factory)=="未給電")
 game.spawn_enemy(Vector3(20,0,20))
 var enemy=game.enemies.back();enemy.hp=100
 var pos=enemy.node.position
 game.hit(enemy,10,true,0,false,true)
 assert(enemy.hp==90 and enemy.node.position==pos)
 assert(enemy.hit_kind=="critical" and enemy.hit_until>game.elapsed)
 game.low_fx=true;game.hit(enemy,1,false)
 assert(enemy.hit_reduced)
 game.muted=false
 for player in game.audio_players:
  player.stream=load("res://assets/power.wav");player.play()
 game.tone("warning")
 assert(game.alert_player.playing,"Danger warning must have a reserved voice")
 game.tone("level")
 assert(game.upgrade_player.playing,"Upgrade voice must not consume the danger voice")
 print("PLAYER_FEEDBACK_PASS guide,24 previews,orders,factory reasons,local hit cue,priority voices")
 game.queue_free()
 await process_frame
 quit()
