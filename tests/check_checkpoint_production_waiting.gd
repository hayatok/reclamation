extends SceneTree
# Fresh isolated profile required. Actual production and game save/load calls;
# this fixture prepares a paid queue, not another campaign completion run.
const Validation=preload("res://checkpoint_validation.gd")
const Rules=preload("res://settlement_rules.gd")
var passed:int=0
var failed:int=0
var g:Node
func _initialize():call_deferred("run")
func check(ok:bool,label:String):
 if ok:passed+=1;print("PASS ",label)
 else:failed+=1;push_error("FAIL "+label)
func run():
 if DirAccess.dir_exists_absolute("user://settlement_v2"):
  push_error("Fresh isolated XDG_DATA_HOME required");quit(2);return
 var campaign=root.get_node("Campaign")
 campaign.launch=true;campaign.current=2;campaign.muted=true
 g=load("res://main.tscn").instantiate();root.add_child(g);g.set_process(false)
 await process_frame
 g.settlement_age=3;g.tech_level=3
 g.stockpile={"food":1000.0,"salvage":1000.0,"parts":1000.0}
 var workshop=g.make_building("vehicle_workshop",Vector3(10,0,16),true)
 var building_index=g.buildings.find(workshop)
 check(g.production.queue_unit(workshop,"siegecart") and g.production.queue_unit(workshop,"siegecart"),"two siegecart orders are paid through real production")
 var after_payment=g.stockpile.duplicate(true)
 check(after_payment=={"food":760.0,"salvage":640.0,"parts":800.0},"both exact paid costs were debited once")
 var original_queue=workshop.queue.duplicate(true)
 for state in ["unpowered","disabled","construction"]:
  workshop.built=.5 if state=="construction" else 1.0
  workshop.enabled=state!="disabled"
  workshop.powered=false
  g.production.update(10.0)
  check(workshop.queue[0].waiting==state and workshop.queue[1].waiting=="","production itself emits "+state+" only on queue head")
  check(workshop.queue[0].remaining==52 and workshop.queue[1].remaining==52,"blocked production preserves both paid timers: "+state)
  var snapshot=g.checkpoint_data()
  check(Validation.validate(snapshot),"actual saved shape accepts "+state)
  var saved=g.save_checkpoint(false)
  check(saved==OK,"actual checkpoint writes "+state)
  if saved==OK:
   workshop.queue[0].remaining=7
   workshop.queue[0].waiting="corrupted_live_fixture"
   g.stockpile.food=1
   check(g.load_checkpoint(),"actual checkpoint restores "+state)
   workshop=g.buildings[building_index]
   check(workshop.queue.size()==2 and workshop.queue[0].remaining==52 and workshop.queue[1].remaining==52 and workshop.queue[0].waiting==state and workshop.queue[1].waiting=="","both queued timers and waiting state survive roundtrip: "+state)
   check(Validation.same_cost(workshop.queue[0].paid_cost,Rules.UNITS.siegecart.cost) and Validation.same_cost(workshop.queue[1].paid_cost,Rules.UNITS.siegecart.cost) and g.stockpile==after_payment,"paid costs and stockpile survive roundtrip without refund/debit: "+state)
  for invalid in ["unknown_state","working","idle","destroyed",17,[],{}]:
   var malformed=snapshot.duplicate(true)
   malformed.buildings[building_index].queue[0].waiting=invalid
   check(not Validation.validate(malformed),"malformed queue waiting rejected: "+str(invalid))
  var malformed=snapshot.duplicate(true)
  malformed.buildings[building_index].queue[0].paid_cost.food="120"
  check(not Validation.validate(malformed),"corrupt paid cost remains rejected with "+state)
 # Re-enabling a complete powered producer resumes, never backfills blocked time.
 workshop.built=1.0;workshop.enabled=true;workshop.powered=true
 g.production.update(2.0)
 check(workshop.queue[0].waiting=="" and workshop.queue[0].remaining==50 and workshop.queue[1].remaining==52,"restored queue resumes only elapsed production time")
 check(g.stockpile==after_payment and original_queue[0].paid_cost==Rules.UNITS.siegecart.cost,"resuming does not debit or refund the paid order")
 print("CHECKPOINT_PRODUCTION_WAITING_SUMMARY passed=%d failed=%d"%[passed,failed])
 g.queue_free();await process_frame;await process_frame;quit(1 if failed else 0)
