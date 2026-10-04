extends Node

const MISSIONS = [
 {"title":"01  都市に灯を","subtitle":"FIRST LIGHT","description":"水のない避難所。発電所と揚水場を取り戻し、押し寄せる感染者から守る。","mode":"restore","hold":120.0,"salvage":0.0,"pressure":1.0,"initial":180.0,"core":900.0,"gen":Vector3(14,0,-5),"pump":Vector3(-14,0,-7),"facility":"揚水場","objective":"揚水を維持","tint":Color("c5b78e")},
 {"title":"02  命を運ぶ道","subtitle":"LAST CONVOY","description":"廃材から輸送車を動かし、避難所へ物資を届ける。車列を護衛して感染街区を抜けろ。","mode":"convoy","hold":0.0,"salvage":0.0,"pressure":1.15,"initial":220.0,"core":1000.0,"gen":Vector3(16,0,-10),"pump":Vector3(-17,0,0),"facility":"貨物中継所","objective":"輸送隊を護衛","tint":Color("d2a148")},
 {"title":"03  最後の送電","subtitle":"THE DEAD TIDE","description":"三つの設備をつなぎ、避難所への送電を守り切る。街の奥から破砕体が迫る。","mode":"finale","hold":180.0,"salvage":0.0,"pressure":1.35,"initial":240.0,"core":1200.0,"gen":Vector3(12,0,-14),"pump":Vector3(-16,0,-14),"facility":"中央送電所","objective":"最終送電","tint":Color("b29a72")}
]

var current:int=0
var unlocked:int=1
var launch:bool=false
var resume:bool=false
var best:Dictionary={}
var muted:bool=false
var low_fx:bool=false
var performance_mode:bool=false

func _ready():
 if FileAccess.file_exists("user://settlement_v2/campaign.json"):
  var data=JSON.parse_string(FileAccess.get_file_as_string("user://settlement_v2/campaign.json"))
  if data is Dictionary:
   unlocked=clampi(int(data.get("unlocked",1)),1,3)
   best=data.get("best",{})
   muted=data.get("muted",false)
   low_fx=data.get("low_fx",false)
   performance_mode=data.get("performance_mode",false)

func save_progress():
 if DirAccess.make_dir_recursive_absolute("user://settlement_v2")!=OK:return
 var file=FileAccess.open("user://settlement_v2/campaign.json",FileAccess.WRITE)
 if file:file.store_string(JSON.stringify({"version":1,"unlocked":unlocked,"best":best,"muted":muted,"low_fx":low_fx,"performance_mode":performance_mode}))

func complete(seconds:float,kills:int):
 unlocked=mini(3,maxi(unlocked,current+2))
 var key=str(current)
 if not best.has(key) or seconds<float(best[key].time):best[key]={"time":seconds,"kills":kills}
 save_progress()

func config()->Dictionary:return MISSIONS[current]
