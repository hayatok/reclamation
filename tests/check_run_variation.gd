extends SceneTree
# Actual mission/retry/reload flows; use a fresh isolated XDG_DATA_HOME.
const Validation=preload("res://checkpoint_validation.gd")
const FIXED_SEED:int=9007199254740993 # Deliberately beyond JSON's exact float range.
var passed:int=0
var failed:int=0
var g:Node
var campaign:Node
func _initialize():call_deferred("run")
func check(ok:bool,label:String):
 if ok:passed+=1;print("PASS ",label)
 else:failed+=1;push_error("FAIL "+label)
func fresh(index:int=0,seed_override:int=-1):
 g.start_mission(index,seed_override)
 await scene_changed
 g=current_scene;g.set_process(false)
 await process_frame
func same_value(a:Variant,b:Variant)->bool:
 # JSON parses numbers as floats and its parser can alter the final bits.
 # Seed/RNG strings, card IDs, orders and selection still compare exactly.
 if (a is int or a is float) and (b is int or b is float):return a==b or absf(float(a)-float(b))<=1e-12
 if a is Dictionary and b is Dictionary:
  if a.size()!=b.size():return false
  for key in a:
   if not b.has(key) or not same_value(a[key],b[key]):return false
  return true
 if a is Array and b is Array:
  if a.size()!=b.size():return false
  for i in a.size():
   if not same_value(a[i],b[i]):return false
  return true
 return typeof(a)==typeof(b) and a==b
func opening()->Array:
 g.xp=60;g.bank_earned_upgrades();g.open_growth_choices()
 return g.cards.map(func(card):return card.id)
func world_signature()->Dictionary:
 return {"resources":g.resource_nodes.map(func(r):return [r.resource,r.node.position,r.stock,r.renewable]),"stockpile":g.stockpile.duplicate(),"terrain":g.terrain_blocks.duplicate(true),"units":g.units.map(func(u):return [u.kind,u.node.position,u.maxhp]),"mission":g.mission.duplicate(true)}
func mechanics_signature()->Dictionary:
 var result={"unit_cooldowns":g.units.map(func(u):return u.cd),"cards":opening()}
 g.spawn_wave()
 result["enemies"]=g.enemies.map(func(e):return [e.node.position,e.hp,e.speed,e.cd,e.armored])
 # Fixture exercises actual critical-hit rolls without killing a target.
 g.upgrades={"crit":4}
 for i in 32:g.fire(Vector3(0,1,0),g.enemies[0],1,"grenade")
 result["critical_hits"]=g.shells.map(func(shell):return shell.critical)
 result["rng"]=str(g.rng.state);result["card_rng"]=str(g.card_rng.state)
 return result
func next_draws()->Array:
 var values=[]
 for i in 128:values.append([g.rng.randi(),g.card_rng.randi(),g.visual_rng.randi()])
 return values
func run():
 if DirAccess.dir_exists_absolute("user://settlement_v2"):
  push_error("Fresh isolated XDG_DATA_HOME required");quit(2);return
 campaign=root.get_node("Campaign")
 campaign.launch=true;campaign.current=0;campaign.muted=true;campaign.choose_run_seed(FIXED_SEED)
 g=load("res://main.tscn").instantiate();root.add_child(g);current_scene=g;g.set_process(false)
 await process_frame
 check(g.run_seed==FIXED_SEED,"64-bit seed injection reaches actual scene")
 check(campaign.seed_from_args(PackedStringArray(["--run-seed=0"]))==0,"explicit seed zero is supported")
 check(campaign.seed_from_args(PackedStringArray(["--run-seed=9223372036854775807"]))==9223372036854775807,"maximum signed seed parses without truncation")
 check(campaign.seed_from_args(PackedStringArray(["--other-flag"]))==-1,"no override requests fresh randomness")
 check(g.rng.seed!=g.card_rng.seed and g.rng.seed!=g.visual_rng.seed and g.card_rng.seed!=g.visual_rng.seed,"all three streams have separate seeds")
 var baseline_world=world_signature()
 var first=mechanics_signature()
 check(first.critical_hits.has(true) and first.critical_hits.has(false),"deterministic fixture exercises critical and ordinary hits")
 await fresh(0,FIXED_SEED)
 check(world_signature()==baseline_world,"same seed preserves map/resources/building and unit balance")
 check(mechanics_signature()==first,"same seed reproduces opening cards, cooldowns, wave positions and critical rolls")
 await fresh(0,FIXED_SEED)
 var combat_before=str(g.rng.state);var cards_before=str(g.card_rng.state)
 for i in 2500:g.visual_rng.randf()
 g.make_site("scrap",Vector3(23,0,20))
 var cosmetic_site=g.sites.pop_back();cosmetic_site.node.queue_free()
 check(str(g.rng.state)==combat_before and str(g.card_rng.state)==cards_before,"cosmetic draws and scrap geometry do not advance mechanical streams")
 check(mechanics_signature()==first,"cosmetic perturbation cannot change cards, wave spawns, cooldowns or critical hits")
 var seeds={};var deals={};var previous=g.run_seed
 for i in 8:
  await fresh()
  check(g.run_seed!=previous and g.run_seed>=0,"actual retry gets fresh seed %d"%i)
  previous=g.run_seed;seeds[str(g.run_seed)]=true
  check(world_signature()==baseline_world,"retry keeps fixed map/resources and balance %d"%i)
  deals[str(opening())]=true
 check(seeds.size()==8 and deals.size()>1,"fresh retries vary seeds and opening card offers")
 await fresh(1)
 check(g.run_seed!=previous and campaign.current==1,"starting next mission also chooses a fresh seed")
 await fresh(0,FIXED_SEED)
 g.xp=300;g.bank_earned_upgrades();g.open_growth_choices();g.choose_upgrade(0);g.open_growth_choices()
 var earned=g.upgrades.duplicate(true)
 var queued=g.pending_upgrade_levels.duplicate()
 var saved_cards=g.cards.map(func(card):return card.id)
 check(not earned.is_empty() and queued.size()==2 and g.active_card,"checkpoint fixture has an earned build and pending displayed choices")
 g.spawn_wave()
 g.economy.assign_resource(g.units[2],g.resource_nodes[0])
 g.units[0].task="focus_fire";g.units[0].target=g.enemies[0]
 g.units[1].task="escort";g.units[1].target=g.units[0]
 g.selected=[g.units[0],g.units[2]]
 g.control_groups.assign(1,g.selected,{},g.units,g.buildings)
 var before=g.checkpoint_data()
 check(Validation.validate(before) and before.version==3,"new seed-bearing checkpoint validates")
 check(before.run_seed==str(FIXED_SEED),"checkpoint serializes the full run seed as decimal text")
 check(g.save_checkpoint(false)==OK,"actual checkpoint writes all three RNG states")
 var expected_draws=next_draws()
 campaign.choose_run_seed(77)
 g.resume_checkpoint()
 await scene_changed
 g=current_scene;g.set_process(false)
 await process_frame
 check(g.run_seed==FIXED_SEED and campaign.run_seed==FIXED_SEED,"resume overrides current/command-line attempt seed with saved identity")
 check(same_value(g.upgrades,earned) and g.pending_upgrade_levels==queued and g.cards.map(func(card):return card.id)==saved_cards and g.active_card,"resume preserves earned build, pending levels and exact visible cards")
 check(g.selected==[g.units[0],g.units[2]] and g.units[0].target==g.enemies[0] and g.units[1].target==g.units[0] and g.units[2].resource_target==g.resource_nodes[0],"early resume retains selected actors, focus/escort and resource orders")
 check(same_value(g.checkpoint_data(),before),"saved world fields restore (only JSON float parser tolerance allowed)")
 check(next_draws()==expected_draws,"128 next draws from every stream exactly match uninterrupted continuation")
 check(g.load_checkpoint(),"same-scene load also succeeds")
 g.postpone_growth_choice()
 var delayed=g.checkpoint_data()
 check(g.save_checkpoint(false)==OK and g.load_checkpoint() and same_value(g.checkpoint_data(),delayed),"postponed choices and all RNG states also roundtrip exactly")
 var card_state=str(g.card_rng.state)
 check(g.open_growth_choices() and str(g.card_rng.state)==card_state and g.cards.map(func(card):return card.id)==saved_cards,"reopening resumed choices does not reroll")
 for field in ["run_seed","rng","card_rng","visual_rng"]:
  for invalid in ["9223372036854775808","01"," 1","1e3",0,null]:
   var bad=before.duplicate(true);bad[field]=invalid
   check(not Validation.validate(bad),"invalid %s rejected: %s"%[field,str(invalid)])
 var negative=before.duplicate(true);negative.run_seed="-1"
 check(not Validation.validate(negative),"negative run seed sentinel cannot enter a checkpoint")
 var old=before.duplicate(true);old.version=2
 check(not Validation.validate(old),"previous schema is explicitly unsupported rather than silently guessed")
 print("RUN_VARIATION_SUMMARY passed=%d failed=%d unique_seeds=%d unique_opening_deals=%d"%[passed,failed,seeds.size(),deals.size()])
 g.queue_free();await process_frame;await process_frame;quit(1 if failed else 0)
