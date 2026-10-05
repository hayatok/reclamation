extends RefCounted
## Exact schema for the reconstructed settlement + deferred-growth build.
## Validation is pure: the loader must call this before touching live objects.
const Rules=preload("res://settlement_rules.gd")
const Catalog=preload("res://upgrade_catalog.gd")
const Atomic=preload("res://atomic_save.gd")
const MAX_ITEMS:=10000
const TASKS:=["idle","move","attack_move","site","build","repair","focus_fire","escort","gather","convoy"]
const PHASES:=["","idle","suspended","to_resource","gathering","waiting_resource","to_dropoff","waiting_dropoff"]
static var last_read_used_backup:bool=false

static func read(path:String)->Dictionary:
 last_read_used_backup=false
 var recovered=Atomic.read_recoverable(path,validate)
 if recovered.is_empty():return {}
 last_read_used_backup=recovered.suffix!=""
 return recovered.data

static func number(v:Variant,minimum:float=-INF,maximum:float=INF)->bool:
 return (v is float or v is int) and is_finite(float(v)) and v>=minimum and v<=maximum

static func integer(v:Variant,minimum:int=0,maximum:int=2147483647)->bool:
 return number(v,minimum,maximum) and float(v)==floor(float(v))

static func vector(v:Variant)->bool:
 return v is Array and v.size()==3 and number(v[0]) and number(v[1]) and number(v[2])

static func array(v:Variant,limit:int=MAX_ITEMS)->bool:
 return v is Array and v.size()<=limit

static func index(v:Variant,size:int,optional:bool=true)->bool:
 return integer(v,-1 if optional else 0,size-1)

static func costs(v:Variant,complete:bool=false)->bool:
 if not v is Dictionary:return false
 if complete and v.size()!=3:return false
 for key in v:
  if not key is String or not key in Rules.RESOURCE_KINDS or not number(v[key],0):return false
 return true

static func same_cost(a:Dictionary,b:Dictionary)->bool:
 if a.size()!=b.size():return false
 for key in b:
  if not a.has(key) or not number(a[key]) or float(a[key])!=float(b[key]):return false
 return true

static func rng_state(v:Variant)->bool:
 if not v is String or v.is_empty() or not v.is_valid_int():return false
 # Reject overflow, whitespace, exponent notation and truncating conversion.
 return str(int(v))==v

static func fields(value:Dictionary,numbers:Array=[],booleans:Array=[])->bool:
 for key in numbers:
  if not number(value.get(key)):return false
 for key in booleans:
  if not value.get(key) is bool:return false
 return true

static func validate(value:Variant)->bool:
 if not value is Dictionary:return false
 var d:Dictionary=value
 if not integer(d.get("version"),3,3) or not integer(d.get("mission"),0,2):return false
 if d.has("camera") and not _camera(d.camera):return false
 if not integer(d.get("settlement_age"),1,3) or not integer(d.get("tech_level"),1,3):return false
 if not costs(d.get("stockpile"),true):return false
 if not fields(d,["resources","gathered","xp","elapsed","wave_clock","hold","noise","ammo","build_boost","victory_boost","research_time"],["generator","first_activation","surge","paused","active_card","research_active","convoy_started","boss_spawned","boss_defeated","convoy_halted"]):return false
 for key in ["resources","gathered","xp","elapsed","hold","ammo"]:
  if d[key]<0:return false
 for key in ["kills","wave","rerolls","family_misses"]:
  if not integer(d.get(key)):return false
 if not integer(d.get("level"),1) or not number(d.noise,0,100):return false
 if not rng_state(d.get("run_seed")) or int(d.run_seed)<0:return false
 for key in ["rng","card_rng","visual_rng"]:
  if not rng_state(d.get(key)):return false
 if not d.get("preferred_family") is String or (d.preferred_family!="" and not Catalog.FAMILIES.has(d.preferred_family)):return false
 for key in ["units","enemies","buildings","sites","resource_nodes","shells","blast_queue","selected","pending_upgrade_levels","cards","recruit_queue"]:
  if not array(d.get(key)):return false
 # recruit_queue is unused in the current source. No speculative legacy shape.
 if not d.recruit_queue.is_empty():return false
 if not _growth(d):return false
 if d.buildings.is_empty():return false
 var hqs=0
 var age_orders=0
 for b in d.buildings:
  if not _building(b,d):return false
  if b.kind=="hq":hqs+=1
  for order in b.queue:
   if order.type=="age":age_orders+=1
 if hqs!=1 or d.buildings[0].kind!="hq" or age_orders>1:return false
 var sites_seen={}
 for s in d.sites:
  if not s is Dictionary or not s.get("kind") in ["generator","pump","substation","scrap"] or not vector(s.get("pos")):return false
  if not fields(s,["progress","stock"],["reclaimed","paid"]):return false
  if not number(s.progress,0,1) or s.stock<0:return false
  if s.reclaimed and s.progress!=1:return false
  if s.kind!="scrap":
   if sites_seen.has(s.kind):return false
   sites_seen[s.kind]=true
 if not sites_seen.has("generator") or not sites_seen.has("pump"):return false
 if int(d.mission)==2 and not sites_seen.has("substation"):return false
 var owners={}
 for r in d.resource_nodes:
  if not r is Dictionary or not r.get("resource") is String or not r.get("resource") in Rules.RESOURCE_KINDS or not vector(r.get("pos")):return false
  if not fields(r,["stock","radius"],["renewable"]) or r.stock<0 or r.radius<=0:return false
  if not index(r.get("source_building_index"),d.buildings.size()):return false
  var owner=int(r.source_building_index)
  if owner>=0:
   var b=d.buildings[owner]
   if b.kind!="garden" or b.built<1 or r.resource!="food" or not r.renewable or owners.has(owner):return false
   owners[owner]=true
 for e in d.enemies:
  if not e is Dictionary or not vector(e.get("pos")) or not vector(e.get("attack_pos")):return false
  if not fields(e,["hp","speed","cd","charged_until","windup"],["armored","convoy_hunter","boss"]):return false
  if e.hp<=0 or e.speed<=0:return false
 for i in d.units.size():
  if not _unit(d.units[i],d,i):return false
 # A chain may merge with another chain, but must never revisit its own node.
 for origin in d.units.size():
  var visited={}
  var cursor=origin
  while d.units[cursor].task=="escort":
   if visited.has(cursor):return false
   visited[cursor]=true
   cursor=int(d.units[cursor].target_index)
 for i in d.selected:
  if not index(i,d.units.size(),false):return false
 if not _unique(d.selected):return false
 if not _control_groups(d):return false
 for s in d.shells:
  if not s is Dictionary or not vector(s.get("from")) or not vector(s.get("to")):return false
  if not fields(s,["time","duration","damage","radius"],["critical"]):return false
  if not s.get("kind") in ["grenade","mortar","siegecart"] or s.time<0 or s.duration<=0 or s.time>s.duration or s.damage<0 or s.radius<=0:return false
 for event in d.blast_queue:
  if not event is Dictionary or not vector(event.get("pos")):return false
  if not number(event.get("radius"),0) or not number(event.get("damage"),0) or not integer(event.get("generation"),0,2):return false
 if not integer(d.get("convoy_route_choice"),0,1) or not integer(d.get("convoy_index"),0,5) or not integer(d.get("convoy_encounter_stage"),0,3):return false
 if not d.get("convoy_pending") is Dictionary:return false
 if not d.convoy_pending.is_empty():
  if not integer(d.convoy_pending.get("stage"),0,2) or not number(d.convoy_pending.get("clock")):return false
 return true

static func _camera(value:Variant)->bool:
 if not value is Dictionary or not vector(value.get("focus")):return false
 var focus:Array=value.focus
 return number(focus[0],-18,18) and number(focus[1],0,0) and number(focus[2],-18,18) and number(value.get("size"),26,85)

static func _control_groups(d:Dictionary)->bool:
 # Optional for checkpoints made before numbered groups were introduced.
 if not d.has("control_groups"):return true
 if not array(d.control_groups,9):return false
 var slots={}
 for group in d.control_groups:
  if not group is Dictionary or group.size()!=3:return false
  if not integer(group.get("slot"),1,9) or slots.has(int(group.slot)):return false
  slots[int(group.slot)]=true
  if not group.get("kind") in ["units","building"]:return false
  if not array(group.get("members")) or group.members.is_empty() or not _unique(group.members):return false
  if group.kind=="building" and group.members.size()!=1:return false
  var count=d.units.size() if group.kind=="units" else d.buildings.size()
  for member in group.members:
   if not index(member,count,false):return false
 return true

static func _growth(d:Dictionary)->bool:
 if not d.get("upgrades") is Dictionary or d.upgrades.size()>Catalog.DEFINITIONS.size()+Catalog.FALLBACKS.size():return false
 var consumed=0
 for id in d.upgrades:
  if not id is String:return false
  var card=Catalog.by_id(id)
  if card.is_empty() or not integer(d.upgrades[id],1):return false
  if card.max_rank>0 and d.upgrades[id]>card.max_rank:return false
  for prerequisite in card.requires:
   if not integer(d.upgrades.get(prerequisite),1):return false
  consumed+=int(d.upgrades[id])
 if consumed+d.pending_upgrade_levels.size()!=int(d.level)-1:return false
 for i in d.pending_upgrade_levels.size():
  if not integer(d.pending_upgrade_levels[i],consumed+i+2,consumed+i+2):return false
 if d.pending_upgrade_levels.is_empty():return d.cards.is_empty() and not d.active_card
 if not d.cards.size() in [0,3] or (d.active_card and d.cards.size()!=3):return false
 if not _unique(d.cards):return false
 for id in d.cards:
  if not id is String:return false
  var card=Catalog.by_id(id)
  if card.is_empty():return false
  if card.max_rank>0 and int(d.upgrades.get(id,0))>=int(card.max_rank):return false
  for prerequisite in card.requires:
   if not d.upgrades.has(prerequisite):return false
 return true

static func _unique(values:Array)->bool:
 var seen={}
 for v in values:
  if not (v is String or v is int or v is float):return false
  if seen.has(v):return false
  seen[v]=true
 return true

static func _building(b:Variant,d:Dictionary)->bool:
 if not b is Dictionary or not b.get("kind") is String or not Rules.BUILDINGS.has(b.kind):return false
 if not vector(b.get("pos")) or not vector(b.get("rally")):return false
 if not fields(b,["hp","maxhp","built","cd","paid_cost"],["enabled"]):return false
 if b.hp<=0 or b.maxhp<b.hp or not number(b.built,0,1) or b.paid_cost<0 or not integer(b.get("shots")):return false
 if not costs(b.get("paid_resources")) or not index(b.get("rally_target_index"),d.resource_nodes.size()):return false
 if not array(b.get("queue"),Rules.MAX_QUEUE_SIZE):return false
 for order in b.queue:
  if not order is Dictionary or not order.get("id") is String or not order.get("type") in ["unit","age"]:return false
  if not fields(order,["remaining","duration"],["refunded"]) or order.refunded or order.duration<=0 or not number(order.remaining,0,order.duration):return false
  if not costs(order.get("paid_cost")) or not integer(order.get("population")):return false
  # Exactly the persisted states emitted by settlement_production._set_state.
  if not order.get("waiting") in ["","unpowered","construction","disabled","age","population","spawn_blocked"]:return false
  if order.type=="unit":
   if not order.get("kind") is String or not Rules.UNITS.has(order.kind):return false
   var rule=Rules.UNITS[order.kind]
   if rule.producer!=b.kind or order.get("id")!=order.kind or order.population!=rule.population:return false
   if not same_cost(order.paid_cost,rule.cost) or order.duration!=rule.time:return false
  else:
   if b.kind!="hq" or not integer(order.get("target_age"),2,3):return false
   var rule=Rules.AGES[int(order.target_age)]
   if order.target_age!=d.settlement_age+1 or order.get("id")!="age_%d"%int(order.target_age) or order.population!=0:return false
   if not same_cost(order.paid_cost,rule.cost) or order.duration!=rule.time:return false
 return true

static func _unit(u:Variant,d:Dictionary,own_index:int)->bool:
 if not u is Dictionary or not u.get("kind") is String or not Rules.UNITS.has(u.kind) or not u.get("task") in TASKS:return false
 if not vector(u.get("pos")) or not vector(u.get("goal")):return false
 if not fields(u,["hp","maxhp","cd","work","yaw","escort_repath"]):return false
 if u.hp<=0 or u.maxhp<u.hp or not integer(u.get("shots")) or not integer(u.get("escort_slot")):return false
 if not u.get("target_type") in ["","site","build","enemy","unit","resource"]:return false
 var expected={"site":"site","build":"build","repair":"build","focus_fire":"enemy","escort":"unit","gather":"resource"}.get(u.task,"")
 if u.target_type!="" and u.target_type!=expected:return false
 var sizes={"":0,"site":d.sites.size(),"build":d.buildings.size(),"enemy":d.enemies.size(),"unit":d.units.size(),"resource":d.resource_nodes.size()}
 if not index(u.get("target_index"),sizes[u.target_type],u.target_type==""):return false
 if u.task in ["site","build","repair","focus_fire","escort"] and u.target_type!=expected:return false
 if u.task in ["site","build","repair","gather"] and u.kind!="worker":return false
 if u.task=="convoy" and u.kind!="convoy":return false
 if u.task=="escort" and (int(u.target_index)==own_index or u.kind=="convoy"):return false
 for key in ["resource_target_index","dropoff_index"]:
  if not index(u.get(key),d.resource_nodes.size() if key=="resource_target_index" else d.buildings.size()):return false
 if not u.get("return_assignment") is Dictionary:return false
 var assignment=u.return_assignment
 if not assignment.get("resource") in ["","food","salvage","parts"] or not index(assignment.get("target_index"),d.resource_nodes.size()):return false
 if assignment.resource=="" and assignment.target_index!=-1:return false
 if assignment.target_index>=0 and d.resource_nodes[int(assignment.target_index)].resource!=assignment.resource:return false
 var cargo=u.get("cargo",0)
 var cargo_kind=u.get("cargo_kind","")
 var resource_kind=u.get("resource_kind","")
 var phase=u.get("economy_phase","")
 if not number(cargo,0) or not cargo_kind in ["","food","salvage","parts"] or not resource_kind in ["","food","salvage","parts"] or not phase in PHASES:return false
 if cargo>0 and cargo_kind=="":return false
 if u.kind!="worker" and (cargo!=0 or resource_kind!="" or phase not in ["","idle"] or u.resource_target_index!=-1 or u.dropoff_index!=-1 or assignment.resource!=""):return false
 if u.resource_target_index>=0 and (resource_kind=="" or d.resource_nodes[int(u.resource_target_index)].resource!=resource_kind):return false
 if u.dropoff_index>=0:
  var depot=d.buildings[int(u.dropoff_index)]
  if depot.kind not in ["hq","depot"] or depot.built<1:return false
 if u.task=="gather":
  if resource_kind=="":return false
  if u.target_type=="resource" and (u.target_index!=u.resource_target_index or d.resource_nodes[int(u.target_index)].resource!=resource_kind):return false
  if phase in ["to_resource","gathering"] and u.resource_target_index<0:return false
  if phase=="to_dropoff" and u.dropoff_index<0:return false
 return true
