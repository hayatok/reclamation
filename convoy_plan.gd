extends RefCounted
## Authored road choices and edge-origin threats, not random in-map spawns.
static func route(choice:int)->Array:
 if choice==1:return [Vector3(-24,0,18),Vector3(-20,0,10),Vector3(-8,0,9),Vector3(8,0,9),Vector3(23,0,11),Vector3(25,0,18)]
 return [Vector3(-24,0,18),Vector3(-17,0,24),Vector3(-6,0,24),Vector3(7,0,24),Vector3(18,0,24),Vector3(25,0,18)]
static func encounter(stage:int,choice:int)->Dictionary:
 var entries=[
  {"direction":"西","progress":.08,"pos":Vector3(-28,0,18),"count":24,"armored_every":0,"warning":"西の路地から追走群。車列の後方を守れ。"},
  {"direction":"東","progress":.40,"pos":Vector3(28,0,10 if choice==1 else 19),"count":32,"armored_every":6,"warning":"東の封鎖線が崩れた。前方に感染群！"},
  {"direction":"南","progress":.58,"pos":Vector3(14,0,28),"count":30,"armored_every":0,"warning":"南の線路から疾走体。車列の右側を守れ。"}
 ]
 return entries[clampi(stage,0,2)].duplicate(true)
static func opening(mission:int)->String:
 return ["『水が尽きる前に、あのポンプを動かそう。』","『運河の先へ道を開こう。群れの出どころを探すんだ。』","『向こうの明かりが消える前に、最後の送電をつなぐ。』"][mission]
static func ending(mission:int)->String:
 return ["錆びた蛇口から水が出た。今夜は、ここで眠れる。","感染源が崩れ、港への道が開いた。ここから、街を取り戻していく。","暗い窓に、一つずつ明かりが戻る。この街には、まだ人がいる。"] [mission]
