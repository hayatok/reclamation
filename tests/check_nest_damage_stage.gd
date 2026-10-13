extends SceneTree
const Art=preload("res://frontier_nest_visual.gd")
var failures:=0
var checks:=0
func check(ok:bool,label:String):
 checks+=1
 if not ok:failures+=1;push_error(label)
func _initialize():call_deferred("run")
func run():
 var art=Art.create();root.add_child(art)
 Art.set_observed(art,true,true);Art.set_state(art,false,false,.50001)
 check(art.get_node("Intact").visible,"above half stays intact")
 Art.set_state(art,false,true,.5)
 check(art.get_node("Damaged").visible and not art.get_node("Intact").visible and not art.get_node("Rubble").visible,"half switches only the live damage mesh")
 check(art.get_meta("frontier_core_material").get_shader_parameter("alarm")==1.0,"damaged infection retains observed alarm")
 Art.set_observed(art,true,false);Art.set_state(art,true,false,0)
 check(art.get_node("Damaged").visible and not art.get_node("Rubble").visible,"hidden destruction preserves last observed half-damage")
 check(art.get_meta("frontier_core_material").get_shader_parameter("alarm")==0.0,"hidden damaged core never glows an alarm")
 Art.set_observed(art,true,true)
 check(art.get_node("Rubble").visible and not art.get_node("Damaged").visible,"observed destruction switches to final rubble")
 Art.set_observed(art,false,false)
 check(not art.visible,"unknown structure remains hidden")
 art.free()
 DirAccess.make_dir_recursive_absolute("user://settlement_v2")
 var f=FileAccess.open("user://settlement_v2/checkpoint.json",FileAccess.WRITE);f.store_string(FileAccess.get_file_as_string("res://tests/fixtures/native_rebuild_after_scout_loss.json"));f.close()
 var c=root.get_node("Campaign");c.current=1;c.launch=true;c.resume=true;c.muted=true
 var g=load("res://main.tscn").instantiate();root.add_child(g);g.set_process(false);g.paused=true
 var rng_before=[g.rng.state,g.card_rng.state,g.visual_rng.state]
 var needed:float=g.frontier.nest.hp-g.frontier.NEST_HP*.5
 var result=g.frontier.apply_damage(g.frontier.nest,needed)
 check(is_equal_approx(result.applied,needed) and g.frontier.nest.hp==3000,"existing damage handler crosses exact half threshold")
 check(g.frontier.nest.node.get_node("Intact").visible,"unobserved damage is not disclosed")
 check(g.save_checkpoint(false)==OK and g.load_checkpoint(),"hidden-damage save roundtrip")
 check(g.frontier.nest.node.get_node("Intact").visible,"reload does not derive remembered damage from current HP")
 g.frontier.discover_if_visible(func(_p):return true)
 check(g.frontier.nest.node.get_node("Damaged").visible,"scouting reveals actual half-damage")
 check(g.save_checkpoint(false)==OK and g.load_checkpoint(),"observed-damage save roundtrip")
 check(g.frontier.nest.node.get_node("Damaged").visible and not g.frontier_visibility.is_visible(g.frontier.nest.node.position),"observed damage persists as memory outside sight after reload")
 check([g.rng.state,g.card_rng.state,g.visual_rng.state]==rng_before,"presentation and save reload preserve all RNG")
 var data=g.frontier.snapshot(g.enemies)
 check(g.frontier.validate_snapshot(data,g.enemies.size()),"observed stage snapshot validates")
 data.nest.observed_stage=3
 check(not g.frontier.validate_snapshot(data,g.enemies.size()),"invalid observed stage rejected")
 data.nest.observed_stage=2
 check(not g.frontier.validate_snapshot(data,g.enemies.size()),"false remembered death of living nest rejected")
 print("NEST_DAMAGE_STAGE checks=",checks," failures=",failures)
 g.free();quit(1 if failures else 0)
