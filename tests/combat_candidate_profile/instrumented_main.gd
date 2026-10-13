extends "res://main.gd"
var measured_target_calls:int=0
var measured_target_usec:int=0
var measured_enemy_entries:int=0
var measured_results:int=0
func combat_targets()->Array:
 var started:int=Time.get_ticks_usec()
 var result:Array=super.combat_targets()
 measured_target_usec+=Time.get_ticks_usec()-started
 measured_target_calls+=1
 measured_enemy_entries+=enemies.size()
 measured_results+=result.size()
 return result
