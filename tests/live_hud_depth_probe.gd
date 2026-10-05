extends "res://main.gd"
## Test-only fixed logical delta; the production scene and simulation are intact.
var benchmark_frames:int=0
var benchmark_script_ms:float=0.0
func _process(_real_delta):
 var started=Time.get_ticks_usec()
 super._process(1.0/60.0)
 benchmark_script_ms=float(Time.get_ticks_usec()-started)/1000.0
 benchmark_frames+=1
func save_checkpoint(_announce:bool=true)->Error:return OK
