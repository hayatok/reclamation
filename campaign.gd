extends Node

const MISSIONS = [
 {"title":"01  都市に灯を","subtitle":"FIRST LIGHT","description":"第七揚水場を復旧し、水と電気を取り戻す。","hold":120.0,"salvage":0.0,"pressure":1.0,"initial":150.0,"core":900.0,"gen":Vector3(14,0,-5),"pump":Vector3(-14,0,-7),"facility":"揚水場","objective":"揚水を維持","tint":Color("64e6d2")},
 {"title":"02  鉄路の再接続","subtitle":"IRON CORRIDOR","description":"資材を600回収し、貨物中継所を稼働させる。","hold":150.0,"salvage":600.0,"pressure":1.2,"initial":120.0,"core":900.0,"gen":Vector3(16,0,-10),"pump":Vector3(-17,0,0),"facility":"貨物中継所","objective":"物流を維持","tint":Color("ffb85e")},
 {"title":"03  明日への送電","subtitle":"THE LONG NIGHT","description":"中央送電所を再接続。最後の大群から都市を守る。","hold":210.0,"salvage":300.0,"pressure":1.45,"initial":200.0,"core":1100.0,"gen":Vector3(12,0,-14),"pump":Vector3(-16,0,-14),"facility":"中央送電所","objective":"送電を維持","tint":Color("bcacff")}
]
var current:int=0
var unlocked:int=1
var launch:bool=false
var resume:bool=false
var best:Dictionary={}
var muted:bool=false
var low_fx:bool=false

func _ready():
 if FileAccess.file_exists("user://campaign.json"):
  var data=JSON.parse_string(FileAccess.get_file_as_string("user://campaign.json"))
  if data is Dictionary:
   unlocked=clampi(int(data.get("unlocked",1)),1,3)
   best=data.get("best",{})
   muted=data.get("muted",false)
   low_fx=data.get("low_fx",false)

func save_progress():
 var file=FileAccess.open("user://campaign.json",FileAccess.WRITE)
 if file:file.store_string(JSON.stringify({"version":1,"unlocked":unlocked,"best":best,"muted":muted,"low_fx":low_fx}))

func complete(seconds:float,kills:int):
 unlocked=mini(3,maxi(unlocked,current+2))
 var key=str(current)
 if not best.has(key) or seconds<float(best[key].time):best[key]={"time":seconds,"kills":kills}
 save_progress()

func config()->Dictionary:return MISSIONS[current]
