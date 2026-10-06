extends SceneTree
var game
var holder:Node3D
var count:int=0
var failed:int=0
func _initialize():call_deferred("run")
func check(ok:bool,label:String):
 count+=1
 if not ok:failed+=1;push_error(label)
func body(life:float)->Dictionary:
 var node=Node3D.new();holder.add_child(node)
 return {"node":node,"life":life}
func run():
 holder=Node3D.new();root.add_child(holder)
 game=load("res://main.gd").new()
 for i in 96:game.corpses.append(body(3.5))
 check(not game.make_corpse_room() and game.corpses.size()==96,"fresh reactions are protected at the normal cap")
 var old:Dictionary=game.corpses[11];old.life=2.6
 var younger:Dictionary=game.corpses[12];younger.life=3.0
 check(game.make_corpse_room() and game.corpses.size()==95,"an older reaction yields one display slot")
 check(old.node.is_queued_for_deletion() and not younger.node.is_queued_for_deletion(),"recycling removes the old body only")
 game.corpses.append(body(3.5))
 check(not game.make_corpse_room(),"no repeated eviction of newly admitted bodies")
 game.performance_mode=true
 check(not game.make_corpse_room() and game.corpses.size()==32,"switching quality cannot perpetuate the previous 96-body pool")
 var low_old:Dictionary=game.corpses[0];low_old.life=2.0
 check(game.make_corpse_room() and game.corpses.size()==31,"performance mode reuses a slot inside its 32-body budget")
 game.corpses.append(body(3.5))
 check(game.corpses.size()==32,"admission never increases the performance budget")
 game.free();holder.queue_free();await process_frame
 print("CORPSE_BUDGET checks=",count," failures=",failed);quit(1 if failed else 0)
