extends SceneTree
var checks=0
func _initialize():call_deferred("run")
func check(value:bool,description:String):
 checks+=1
 assert(value,description)
 print("PASS ",description)
func run():
 var campaign=root.get_node("Campaign")
 campaign.launch=true;campaign.current=0;campaign.muted=true
 var game=load("res://main.tscn").instantiate();root.add_child(game);game.set_process(false)
 await process_frame
 game.settlement_age=2
 game.stockpile={"food":1000.0,"salvage":1000.0,"parts":1000.0}
 game.select_workers();game.worker_build_page="economy";game.refresh_context_commands(true)
 var action=game.context_actions.filter(func(a):return a.kind=="factory")[0]
 var b:Button=action.button
 check(b.disabled,"missing depot blocks factory")
 check(b.get_meta("command_detail").visible and "集積所" in b.get_meta("command_detail").text,"prerequisite facility appears directly on command tile")
 check(not b.get_meta("command_cost_row").visible,"structural reason is not covered by the cost row")
 var before=game.stockpile.duplicate()
 game.activate_context_key(KEY_R)
 check("集積所" in game.center_notice.text,"blocked hotkey explains exact prerequisite")
 check(game.stockpile==before and game.build_mode.is_empty(),"blocked hotkey neither spends nor enters placement")
 game.make_building("depot",Vector3(15,0,15),true)
 game.stockpile.salvage=0
 game.refresh_context_commands(true)
 b=game.context_actions.filter(func(a):return a.kind=="factory")[0].button
 check(b.disabled and b.get_meta("command_cost_row").visible,"resource shortage retains itemized costs")
 game.stockpile.salvage=1000
 game.refresh_context_commands(true)
 b=game.context_actions.filter(func(a):return a.kind=="factory")[0].button
 check(not b.disabled and b.get_meta("command_cost_row").visible,"available command restores normal cost presentation")
 game.make_building("vehicle_workshop",Vector3(-14,0,10),true)
 game.select_headquarters();game.refresh_context_commands(true)
 b=game.context_actions.filter(func(a):return a.kind=="research")[0].button
 check(b.disabled and b.get_meta("command_detail").text=="弾薬工房を建設","absent workshop asks for construction, not electricity")
 var cash=game.stockpile.duplicate(true)
 game.activate_context_key(KEY_W)
 check(game.stockpile==cash and game.inspected.queue.is_empty(),"missing facility never charges or starts age research")
 var factory=game.make_building("factory",Vector3(8,0,-4),false)
 factory.built=.5;factory.powered=false
 game.refresh_context_commands()
 b=game.context_actions.filter(func(a):return a.kind=="research")[0].button
 check(b.disabled and b.get_meta("command_detail").text=="弾薬工房を完成","paid foundation asks to finish the existing workshop")
 factory.built=1;game.refresh_context_commands()
 check(b.disabled and b.get_meta("command_detail").text=="弾薬工房に給電","completed unpowered workshop asks for electricity")
 factory.powered=true;game.refresh_context_commands()
 check(not b.disabled and b.get_meta("command_cost_row").visible,"powered completed workshop restores exact age cost row")
 factory.hp=0;game.refresh_context_commands()
 check(b.disabled and b.get_meta("command_detail").text=="弾薬工房を建設","destroyed workshop again asks for rebuilding")
 print("COMMAND_REASON_PASS checks=",checks)
 game.queue_free();await process_frame;quit()
