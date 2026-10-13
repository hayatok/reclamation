extends RefCounted
## Only M3's central station is a defended restoration site. Shutdown keeps its
## reclaimed/paid state, footprint and repair reference; it is never destroyed.
const MISSION:int=2
const POSITION:Vector3=Vector3(-16,0,-14)
const BASE_HP:float=600.0
const RESTART_FRACTION:float=0.25
const RADIUS:float=2.1

static func initialize(site:Dictionary,mission_index:int,armor_bonus:float=0.0):
 if mission_index!=MISSION or site.get("kind","")!="pump" or site.node.position!=POSITION:return
 var maximum:float=BASE_HP*(1.0+armor_bonus)
 site.merge({"central_station":true,"hp":maximum,"maxhp":maximum,"basehp":BASE_HP,"disabled":false,"radius":RADIUS})

static func is_station(site:Variant)->bool:
 return site is Dictionary and site.get("central_station",false) and site.get("kind","")=="pump" and is_instance_valid(site.get("node")) and not site.node.is_queued_for_deletion() and site.node.position==POSITION

static func repair_target(site:Variant)->bool:
 return is_station(site) and site.get("reclaimed",false) and not site.get("being_removed",false)

static func repairable(site:Variant)->bool:
 return repair_target(site) and float(site.hp)<float(site.maxhp)

static func operational(site:Variant)->bool:
 return repair_target(site) and not site.get("disabled",false) and float(site.hp)>0.0

static func damage(site:Dictionary,amount:float)->bool:
 if not operational(site) or amount<=0.0:return false
 site.hp=maxf(0.0,float(site.hp)-amount)
 if site.hp<=0.0:site.disabled=true
 return true

static func repair(site:Dictionary,amount:float):
 if not repair_target(site) or amount<=0.0:return
 site.hp=minf(float(site.maxhp),float(site.hp)+amount)
 if site.disabled and site.hp>=float(site.maxhp)*RESTART_FRACTION:site.disabled=false

static func status(site:Dictionary)->String:
 return "停止 / 耐久25%で再開" if site.get("disabled",false) else "復旧済"
