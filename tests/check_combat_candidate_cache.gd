extends SceneTree
var g:Node
var checked:=0
func _initialize():call_deferred("run")
func check(ok:bool,label:String):
 checked+=1
 if not ok:push_error(label);quit(1)
func run():
 create_timer(30).timeout.connect(func():quit(2))
 var c=root.get_node("Campaign");c.current=1;c.launch=true;c.resume=false;c.muted=true;c.run_seed=731054
 g=load("res://main.tscn").instantiate();root.add_child(g);current_scene=g;g.set_process(false)
 var p:Vector3=g.buildings[0].node.position+Vector3(2,0,0)
 g.spawn_enemy(p);var first:Dictionary=g.enemies.back()
 g.refresh_frontier_visibility(0,true)
 g._friendly_target_phase=true
 var initial=g.combat_targets()
 check(first in initial,"visible spawned enemy eligible")
 check(is_same(initial,g.combat_targets()),"within friendly phase reuses candidate array")
 first.dead=true
 check(g.nearest_enemy(p,.1)==null,"death checked live inside shared array")
 first.dead=false
 g.spawn_enemy(p+Vector3(.2,0,0));var spawned:Dictionary=g.enemies.back()
 check(spawned in g.combat_targets(),"new spawn invalidates list")
 g.frontier.nest.known=true;g.frontier.nest.dead=false
 g.refresh_frontier_visibility(0,true)
 check(g.frontier.nest in g.combat_targets(),"new known nest included after visibility refresh")
 g.frontier.nest.dead=true
 check(g.nearest_enemy(g.frontier.nest.node.position,.1)==null,"destroyed nest excluded live")
 g.frontier.nest.dead=false;g.frontier.nest.known=false;g.refresh_frontier_visibility(0,true)
 check(g.frontier.nest not in g.combat_targets(),"unknown nest remains excluded")
 g._friendly_target_phase=false
 first.node.position=Vector3(10000,0,10000)
 check(first not in g.combat_targets(),"outside-phase moved enemy visibility is fresh")
 first.node.position=p
 check(first in g.combat_targets(),"outside-phase return to sight is fresh")
 g._friendly_target_phase=true;g.combat_targets();g.refresh_frontier_visibility(0,true)
 check(not g._combat_candidates_ready,"visibility refresh invalidates")
 g._friendly_target_phase=false
 g.simulate(.05)
 check(not g._friendly_target_phase and not g._combat_candidates_ready and g._combat_candidates.is_empty(),"normal simulation leaves no retained cache")
 g.buildings[0].hp=0
 g.simulate(.05)
 check(g.ended and not g._friendly_target_phase and g._combat_candidates.is_empty(),"early end clears phase cache")
 print("TARGET_CACHE_BOUNDARIES_PASS ",checked)
 g.free();quit()
