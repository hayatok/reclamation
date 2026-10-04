extends SceneTree
func _initialize():call_deferred("run")
func run():
 root.get_node("Campaign").launch=true
 var game=load("res://main.tscn").instantiate()
 root.add_child(game)
 game.set_process(false)
 for mission in 3:
  root.get_node("Campaign").current=mission
  for wave in range(1,12):
   var sides=game.wave_sides(wave)
   var observed=[]
   for enemy in 30:
    var primary=game.wave_side(wave)
    var actual=(primary+(1 if enemy%3==0 else 0))%3 if mission==2 and wave>=3 else primary
    if not actual in observed:observed.append(actual)
   sides.sort();observed.sort()
   assert(sides==observed,"Warning directions must match actual spawn directions")
 assert(game.wave_direction_text(8)=="東・西")
 print("WAVE_WARNING_TRUTH_PASS 33 waves plus dual-front labels")
 game.queue_free()
 await process_frame
 quit()
