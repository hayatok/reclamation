extends SceneTree
## Controlled combat fixture, separate from the ordinary-save replay evidence.
var game
var checks:int=0
var failures:int=0
func _initialize():call_deferred("run")
func check(ok:bool,label:String):
 checks+=1
 if not ok:failures+=1;push_error(label)
func clear_shells():
 for shell in game.shells:shell.node.free()
 game.shells.clear()
func run():
 var campaign=root.get_node("Campaign");campaign.current=0;campaign.launch=true;campaign.resume=false;campaign.muted=true
 game=load("res://main.tscn").instantiate();root.add_child(game);current_scene=game;game.set_process(false)
 for unit in game.units:unit.node.free()
 game.units.clear();game.selected.clear();game.wave_clock=999;game.power_clock=999
 game.spawn_enemy(Vector3(5,0,3));var lone:Dictionary=game.enemies.back();lone.hp=10000
 for i in 6:
  game.spawn_enemy(Vector3(-2+(i%3)*.4,0,2+int(i/3)*.4));game.enemies.back().hp=10000
 game.heavy_targeting.begin_step()
 check(game.auto_fire_target(Vector3(5,0,8),13,"guard")==lone,"infantry keeps nearest threat")
 check(game.auto_fire_target(Vector3(5,0,8),13,"tower")==lone,"ordinary tower keeps nearest threat")
 for kind in ["grenade","siegecart"]:
  var unit:Dictionary=game.make_unit(kind,Vector3(5,0,8));unit.cd=0;game.ammo=400
  game.simulate(.05)
  check(game.shells.size()==1,kind+" automatically fires one unchanged shell")
  if not game.shells.is_empty():
   check(game.shells[0].to.distance_to(Vector3(-1.6,0,2.2))<2,kind+" automatic primary aims into the group")
   check(is_equal_approx(game.shells[0].radius,3 if kind=="grenade" else 4.1),kind+" actual impact radius preserved")
   check(is_equal_approx(game.shells[0].duration,.8 if kind=="grenade" else 1.35),kind+" flight duration preserved")
  check(is_equal_approx(game.ammo,397),kind+" paid shot still costs three ammo")
  clear_shells();unit.cd=0;unit.task="focus_fire";unit.target=lone;unit.goal=lone.node.position
  var aim:Vector3=lone.node.position;game.ammo=400
  game.simulate(.05)
  check(game.shells.size()==1 and game.shells[0].to.distance_to(aim)<.0001,kind+" explicit focus-fire overrides dense group")
  check(is_equal_approx(game.ammo,397),kind+" manual paid shot unchanged")
  clear_shells();unit.hp=0;game.simulate(.05)
 var mortar:Dictionary=game.make_building("mortar",Vector3(5,0,8),true)
 mortar.powered=true;mortar.cd=0;game.power_clock=999;game.ammo=400
 game.simulate(.05)
 check(game.shells.size()==1 and game.shells[0].to.distance_to(Vector3(-1.6,0,2.2))<3,"powered fixed mortar automatically selects the concentration")
 if not game.shells.is_empty():check(is_equal_approx(game.shells[0].damage,85),"fixed mortar base damage preserved")
 clear_shells();mortar.cd=0;mortar.powered=false;game.power_clock=999;game.simulate(.05)
 check(game.shells.is_empty(),"unpowered mortar still cannot fire")
 print("HEAVY_AIM_INTEGRATION checks=",checks," failures=",failures)
 quit(1 if failures else 0)
