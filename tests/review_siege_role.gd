extends SceneTree
var g:Node
func _initialize():call_deferred("run")
func write_json(path:String,value):
 var f=FileAccess.open(path,FileAccess.WRITE);f.store_string(JSON.stringify(value,"  "));f.close()
func run():
 var output=OS.get_environment("SIEGE_REVIEW_OUTPUT")
 if output.is_empty():output="user://siege_role_review"
 DirAccess.make_dir_recursive_absolute(output)
 var fixture=FileAccess.get_file_as_string("res://tests/fixtures/earned_frontier_departure.json")
 var rows=[]
 for mode in ["existing_departure","escort_siege"]:
  DirAccess.make_dir_recursive_absolute("user://settlement_v2")
  var f=FileAccess.open("user://settlement_v2/checkpoint.json",FileAccess.WRITE);f.store_string(fixture);f.close()
  var c=root.get_node("Campaign");c.current=1;c.launch=true;c.resume=true;c.muted=true
  g=load("res://main.tscn").instantiate();root.add_child(g);g.set_process(false)
  assert(not g.title_open and absf(g.elapsed-720.35)<.001)
  g.paused=false
  var siege:Dictionary=g.units.filter(func(u):return u.kind=="siegecart")[0]
  var expedition=g.units.filter(func(u):return u.kind in ["guard","grenade"] and u.task=="attack_move")
  assert(expedition.size()==9)
  var initial=g.checkpoint_data()
  if mode=="escort_siege":
   g.selected=expedition;g.attack_move=false
   assert(g.command_at(siege.node.position))
   assert(expedition.all(func(u):return u.task=="escort" and u.target==siege))
  var start=g.elapsed;var first_damage=-1.0;var first_siege_nest=-1.0;var seen_shells={};var nest_shells=0;var minimum_ammo=g.ammo
  var trace=[]
  for step in 2400:
   if g.active_card:g.postpone_growth_choice()
   g.advance_simulation_time(.05)
   minimum_ammo=minf(minimum_ammo,g.ammo)
   if g.frontier.nest.hp<6000 and first_damage<0:first_damage=g.elapsed-start
   for shell in g.shells:
    var id=shell.node.get_instance_id()
    if seen_shells.has(id):continue
    seen_shells[id]=true
    if shell.kind=="mortar" and shell.to.distance_to(g.frontier.nest.node.position)<4.5:
     nest_shells+=1
     if first_siege_nest<0:first_siege_nest=g.elapsed-start
   if step%100==0:
    trace.append({"seconds":g.elapsed-start,"nest_hp":g.frontier.nest.hp,"siege_position":g.vec_data(siege.node.position),"siege_hp":siege.hp,"shots":siege.shots,"ammo":g.ammo,"kills":g.kills,"expedition_living":expedition.filter(func(u):return u.hp>0).size()})
    await process_frame
   if g.ended:break
  var result={"mode":mode,"seconds":g.elapsed-start,"ended":g.ended,"won":g.result_won,"nest_hp":g.frontier.nest.hp,"first_nest_damage_seconds":first_damage,"first_siege_nest_shell_seconds":first_siege_nest,"siege_nest_shells":nest_shells,"siege_volleys":siege.shots,"siege_position":g.vec_data(siege.node.position),"expedition_living":expedition.filter(func(u):return u.hp>0).size(),"expedition_hp":expedition.reduce(func(total,u):return total+maxf(u.hp,0),0.0),"minimum_ammo":minimum_ammo,"hq_hp":g.buildings.filter(func(b):return b.kind=="hq")[0].hp,"kills":g.kills,"initial_rng":initial.rng,"initial_upgrades":initial.upgrades,"trace":trace}
  rows.append(result);write_json(output.path_join(mode+".json"),result)
  if not g.ended:write_json(output.path_join(mode+"_state.json"),g.checkpoint_data())
  print("SIEGE_ROLE_RESULT ",JSON.stringify(result));g.free();await process_frame
 write_json(output.path_join("comparison.json"),rows);quit()
