extends SceneTree
func _initialize():call_deferred("run")
func run():
 DirAccess.make_dir_recursive_absolute("user://settlement_v2")
 var f=FileAccess.open("user://settlement_v2/checkpoint.json",FileAccess.WRITE);f.store_string(FileAccess.get_file_as_string("res://tests/fixtures/earned_frontier_departure.json"));f.close()
 var c=root.get_node("Campaign");c.current=1;c.launch=true;c.resume=true;c.muted=true
 var g=load("res://main.tscn").instantiate();root.add_child(g);g.set_process(false);g.paused=true
 assert(not g.title_open)
 for kind in ["guard","grenade","siegecart"]:
  var unit=g.units.filter(func(u):return u.kind==kind)[0];g.selected=[unit]
  var before=g.checkpoint_data();g.update_weapon_range_preview()
  assert(g.weapon_range_preview.visible and is_equal_approx(g.weapon_range_preview.get_debug_state().radius,g.selected_weapon_range(unit)))
  assert(g.checkpoint_data()==before)
  var actual=unit.node.global_position;var shifted=unit.node.global_transform;shifted.origin+=Vector3(.1,0,.1)
  g.update_weapon_range_preview({unit.node.get_instance_id():{"world":shifted}})
  assert(g.weapon_range_preview.get_debug_state().world_position.is_equal_approx(shifted.origin) and unit.node.global_position==actual)
  g.active_card=true;g.update_weapon_range_preview();assert(not g.weapon_range_preview.visible);g.active_card=false
  var hp=unit.hp;unit.hp=0;g.update_weapon_range_preview();assert(not g.weapon_range_preview.visible);unit.hp=hp
 g.selected=g.units.filter(func(u):return u.kind=="guard");g.update_weapon_range_preview();assert(not g.weapon_range_preview.visible)
 g.selected=[g.units.filter(func(u):return u.kind=="worker")[0]];g.update_weapon_range_preview();assert(not g.weapon_range_preview.visible)
 g.selected=[g.units.filter(func(u):return u.kind=="siegecart")[0]]
 var had_rank=g.upgrades.has("range");var old_rank=g.upgrades.get("range",0);g.upgrades.range=3;g.update_weapon_range_preview();assert(is_equal_approx(g.weapon_range_preview.get_debug_state().radius,28.6))
 if had_rank:g.upgrades.range=old_rank
 else:g.upgrades.erase("range")
 g.update_weapon_range_preview();var state=g.checkpoint_data();assert(g.save_checkpoint(false)==OK and g.load_checkpoint());g.update_weapon_range_preview();assert(g.checkpoint_data()==state and g.weapon_range_preview.visible)
 print("RANGE_INTEGRATION_PASS: exact live ranges, render interpolation, no saved-state mutation, death/multi/worker/card clear, upgrade, save/reload")
 g.free();quit()
