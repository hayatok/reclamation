# Existing combat controls plus queue-change save regression. The original
# stationary enemy fixture used speed=0, which the current save schema rejects.
# Give surviving enemies valid speeds only at the checkpoint boundary.
extends SceneTree
var failures:Array=[]
var checks:int=0
var g
func _initialize():call_deferred("run")
func check(value:bool,label:String):
 checks+=1
 if value:print("PASS ",label)
 else:failures.append(label);push_error("FAIL "+label)
func enemy_at(pos:Vector3,hp:float=10000)->Dictionary:
 g.spawn_enemy(pos)
 var e=g.enemies.back()
 e.hp=hp;e.speed=0.0;e.cd=10000
 return e
func clean():
 for collection in [g.units,g.enemies,g.shells,g.corpses]:
  for item in collection:
   if is_instance_valid(item.node):item.node.queue_free()
  collection.clear()
 g.selected.clear();g.upgrades.clear();g.active_card=false;g.ended=false;g.paused=false
 g.xp=0;g.kills=0;g.level=1;g.wave_clock=10000;g.threat_voice_clock=10000;g.ammo=100000;g.attack_move=false
 for b in g.buildings:b.cd=10000
func right_click(target:Dictionary):
 var evt=InputEventMouseButton.new()
 evt.button_index=MOUSE_BUTTON_RIGHT;evt.pressed=true
 evt.position=g.camera.unproject_position(target.node.position+Vector3(0,.9*target.node.scale.y,0))
 g._unhandled_input(evt)
func step(count:int,dt:float=.05):
 for i in count:g.simulate(dt)
func run():
 root.get_node("Campaign").launch=true
 root.get_node("Campaign").current=0
 root.size=Vector2i(1440,900)
 g=load("res://main.tscn").instantiate();root.add_child(g);g.set_process(false)
 g.muted=true;g.low_fx=true;g.audio_system.set_muted(true)
 # Controlled fixture: remove scenery navigation, move HQ aside, remove tower.
 # This isolates RTS order behavior; it is not a campaign playthrough.
 for b in g.buildings.duplicate():
  if b.kind!="hq":g.buildings.erase(b);b.node.queue_free()
 g.buildings[0].node.position=Vector3(-25,0,25)
 g.terrain_blocks.clear();g.rebuild_navigation()
 await process_frame
 clean()
 var u=g.make_unit("guard",Vector3(-12,0,0));g.selected=[u]
 var near=enemy_at(Vector3(-9,0,0))
 var chosen=enemy_at(Vector3(-4,0,0))
 right_click(chosen)
 check(u.task=="focus_fire" and u.target==chosen,"real right-click dispatch selects clicked farther enemy")
 check(g.nearest_enemy(u.node.position,10.5)==near,"priority fixture has different nearest enemy")
 u.cd=0;step(1)
 check(chosen.hp<10000 and near.hp==10000,"guard primary shot damages designated target over nearest")
 check(u.node.position.distance_to(Vector3(-12,0,0))<.001,"already in range does not approach point-blank")
 clean()
 u=g.make_unit("guard",Vector3(-14,0,0));g.selected=[u]
 chosen=enemy_at(Vector3(10,0,0));right_click(chosen)
 step(200)
 var distance=u.node.position.distance_to(chosen.node.position)
 check(distance>9.8 and distance<=10.5,"guard chase stops near weapon range: %.3f"%distance)
 var stopped=u.node.position;step(20)
 check(u.node.position.distance_to(stopped)<.001,"guard holds firing position")
 chosen.node.position=Vector3(20,0,0);step(100)
 var following=u.node.position.distance_to(chosen.node.position)
 check(following>9.8 and following<=10.5,"moving designated target repaths and stops in range: %.3f"%following)
 clean()
 u=g.make_unit("grenade",Vector3(-14,0,-5));g.selected=[u]
 near=enemy_at(Vector3(-10,0,-5));chosen=enemy_at(Vector3(8,0,-5));right_click(chosen)
 u.cd=0;step(150)
 var grenade_distance=u.node.position.distance_to(chosen.node.position)
 check(grenade_distance>12.2 and grenade_distance<=13,"grenadier chase stops near weapon range: %.3f"%grenade_distance)
 check(chosen.hp<10000 and near.hp==10000,"grenadier shells prioritize designated target beyond nearer enemy")
 clean()
 u=g.make_unit("guard",Vector3(-12,0,0));g.selected=[u]
 chosen=enemy_at(Vector3(-4,0,0));right_click(chosen);u.cd=10000
 g.hit(chosen,10001,true);step(1)
 check(u.task=="idle" and u.target==null and u.route.is_empty(),"real target death clears focus, target, and route")
 var death_stop=u.node.position;step(20)
 check(u.node.position.distance_to(death_stop)<.001,"target death leaves unit stopped")
 clean()
 u=g.make_unit("guard",Vector3(-12,0,0));g.selected=[u]
 chosen=enemy_at(Vector3(-4,0,0));near=enemy_at(Vector3(-7,0,-6));right_click(chosen)
 right_click(near)
 check(u.task=="focus_fire" and u.target==near,"new enemy click replaces designated target")
 g.command_at(Vector3(-20,0,-20))
 check(u.task=="move" and u.target==null,"new ground move clears focus target")
 right_click(chosen);g.attack_move=true;g.command_at(Vector3(-20,0,-20))
 check(u.task=="attack_move" and u.target==null,"new attack-move clears focus target")
 clean()
 u=g.make_unit("guard",Vector3(-12,0,0));g.selected=[u]
 var removed=enemy_at(Vector3(20,0,20),10)
 near=enemy_at(Vector3(-9,0,0))
 chosen=enemy_at(Vector3(-4,0,0))
 var trailing=enemy_at(Vector3(15,0,-15))
 right_click(chosen)
 g.hit(removed,100,true)
 var saved_pos=chosen.node.position
 for enemy in g.enemies:
  if not enemy.dead:enemy.speed=1.0
 var save_result=g.save_checkpoint(false)
 check(save_result==OK,"combat fixture writes through current atomic schema")
 if save_result!=OK:g.free();quit(1);return
 var serialized=JSON.parse_string(FileAccess.get_file_as_string("user://settlement_v2/checkpoint.json"))
 check(serialized.units[0].target_type=="enemy" and serialized.units[0].target_index==1,"save records designated live enemy index after earlier enemy death")
 check(g.load_checkpoint(),"checkpoint loads")
 u=g.units[0]
 check(u.task=="focus_fire" and u.target==g.enemies[1] and u.target.node.position==saved_pos,"load restores correct nonzero enemy index and focus order")
 var before_other=g.enemies[0].hp;var before_focus=g.enemies[1].hp
 u.cd=0;step(1)
 check(g.enemies[1].hp<before_focus and g.enemies[0].hp==before_other,"restored focus shoots correct enemy")
 print("FOCUS_QA_RESULT checks=",checks," failures=",failures.size()," failure_labels=",failures)
 print("USER_DATA_DIR ",OS.get_user_data_dir())
 g.queue_free();await process_frame
 quit(0 if failures.is_empty() else 1)
