extends Node
const AtomicSave=preload("res://atomic_save.gd")

const MISSIONS = [
 {"title":"01  都市に灯を","subtitle":"FIRST LIGHT","description":"水のない避難所。発電所と揚水場を取り戻し、押し寄せる感染者から守る。","mode":"restore","hold":120.0,"salvage":0.0,"pressure":1.0,"initial":180.0,"core":900.0,"gen":Vector3(14,0,-5),"pump":Vector3(-14,0,-7),"facility":"揚水場","objective":"揚水を維持","tint":Color("c5b78e")},
 {"title":"02  感染港を拓く","subtitle":"BEYOND THE CANAL","description":"運河の先は未踏の感染街区。資源地へ進出し、群れを生む感染源を探して破壊する。","mode":"assault","hold":0.0,"salvage":0.0,"pressure":1.15,"initial":220.0,"core":1000.0,"gen":Vector3(-42,0,32),"pump":Vector3(62,0,-48),"facility":"感染源","objective":"感染源を探して破壊","tint":Color("d2a148")},
 {"title":"03  最後の送電","subtitle":"THE DEAD TIDE","description":"三つの設備をつなぎ、初期送電を60秒維持する。迫る破砕体を撃破して送電を確立しよう。","mode":"finale","hold":60.0,"salvage":0.0,"pressure":1.35,"initial":240.0,"core":1200.0,"gen":Vector3(12,0,-14),"pump":Vector3(-16,0,-14),"facility":"中央送電所","objective":"最終送電","tint":Color("b29a72")}
]

# One attempt identity, independent of progress/settings. The source is randomized
# once, so rapid retries draw fresh seeds without relying on clock resolution.
var run_seed:int=-1
var _run_seed_source=RandomNumberGenerator.new()
var current:int=0
var unlocked:int=1
var launch:bool=false
var resume:bool=false
var best:Dictionary={}
var muted:bool=false
var low_fx:bool=false
var performance_mode:bool=false

func _ready():
 _run_seed_source.randomize()
 var recovered=AtomicSave.read_recoverable("user://settlement_v2/campaign.json",validate_progress)
 if recovered.is_empty():return
 var data=recovered.data
 unlocked=int(data.unlocked);best=data.best
 muted=data.muted;low_fx=data.low_fx;performance_mode=data.performance_mode

static func validate_progress(data:Variant)->bool:
 if not data is Dictionary:return false
 if not _integer(data.get("version"),1,1) or not _integer(data.get("unlocked"),1,3) or not data.get("best") is Dictionary:return false
 for field in ["muted","low_fx","performance_mode"]:
  if not data.get(field) is bool:return false
 for key in data.best:
  if key not in ["0","1","2"]:return false
  var record=data.best[key]
  if not record is Dictionary or not _number(record.get("time")) or record.time<0 or not _integer(record.get("kills"),0,2147483647):return false
 return true

static func _number(value:Variant)->bool:
 return (value is int or value is float) and is_finite(float(value))

static func _integer(value:Variant,minimum:int,maximum:int)->bool:
 return _number(value) and value>=minimum and value<=maximum and floor(float(value))==float(value)

func save_progress()->Error:
 var result=DirAccess.make_dir_recursive_absolute("user://settlement_v2")
 if result!=OK:return result
 return AtomicSave.write_json("user://settlement_v2/campaign.json",{"version":1,"unlocked":unlocked,"best":best,"muted":muted,"low_fx":low_fx,"performance_mode":performance_mode},validate_progress)

func complete(seconds:float,kills:int)->Error:
 if not is_finite(seconds) or seconds<0 or kills<0 or current<0 or current>=MISSIONS.size():return ERR_INVALID_DATA
 # Retain the earned result in memory for retry. Only the caller may clear the
 # resumable checkpoint, and only after this write returns OK.
 unlocked=mini(3,maxi(unlocked,current+2))
 var key=str(current)
 if not best.has(key) or seconds<float(best[key].time):best[key]={"time":seconds,"kills":kills}
 return save_progress()

func config()->Dictionary:return MISSIONS[current]

# Optional reproduction hook: -- --run-seed=12345, or start_mission(index, seed).
# Keep 64-bit values as canonical decimal strings in checkpoint JSON.
static func seed_from_args(args:PackedStringArray)->int:
 for arg in args:
  if not arg.begins_with("--run-seed="):continue
  var value=arg.trim_prefix("--run-seed=")
  if value.is_valid_int() and str(int(value))==value and int(value)>=0:return int(value)
  push_warning("Ignored invalid --run-seed; use an integer from 0 to 9223372036854775807.")
 return -1

func choose_run_seed(seed_override:int=-1)->int:
 if seed_override>=0:
  run_seed=seed_override
 else:
  var previous=run_seed
  run_seed=(int(_run_seed_source.randi() & 0x7fffffff)<<32)|int(_run_seed_source.randi())
  while run_seed==previous:
   run_seed=(int(_run_seed_source.randi() & 0x7fffffff)<<32)|int(_run_seed_source.randi())
 return run_seed
