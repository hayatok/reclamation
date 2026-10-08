extends RefCounted
## Factual losses only. No nodes, actor dictionaries, inferred causes or UI live here.
const Rules=preload("res://settlement_rules.gd")
const MAX_EVENTS:int=16
const RECENT_SECONDS:float=120.0
const WORKER_CLUSTER_SECONDS:float=6.0
const KINDS:Array[String]=["hq","convoy","factory","barracks","vehicle_workshop","garden","truck","worker"]
const TERMINAL_KINDS:Array[String]=["hq","convoy"]
const LOSS_MARKER:String="defeat_recap_recorded"
var _mission:int=-1
var _run_seed:String=""
var _events:Array=[]

func reset(mission:int,run_seed:int)->void:
 _mission=mission
 _run_seed=str(run_seed)
 _events.clear()

func record_loss(subject:Dictionary,at:float)->bool:
 # Called when removal/defeat confirms the loss, never merely at lethal damage:
 # an existing between-tick growth choice can still heal zero-health actors.
 # The actor-local marker prevents cleanup and finish() from counting twice.
 # Dismantling never sets HP to zero and must not call this observer.
 if _mission<0 or not _number(at,0) or subject.get(LOSS_MARKER,false):return false
 if not _number(subject.get("hp")) or float(subject.hp)>0:return false
 var kind:Variant=subject.get("kind")
 if not kind is String or kind not in KINDS:return false
 if not _events.is_empty() and at<float(_events.back().time):return false
 var unfinished:bool=Rules.BUILDINGS.has(kind) and float(subject.get("built",1.0))<1.0
 if kind=="worker":
  for index in range(_events.size()-1,-1,-1):
   var previous:Dictionary=_events[index]
   if previous.kind!="worker":continue
   if at-float(previous.first_time)<=WORKER_CLUSTER_SECONDS and int(previous.count)<10000:
    previous.count=int(previous.count)+1
    previous.time=at
    _events.remove_at(index)
    _events.append(previous)
    subject[LOSS_MARKER]=true
    return true
   break
 _events.append({"kind":kind,"first_time":at,"time":at,"count":1,"unfinished":unfinished})
 while _events.size()>MAX_EVENTS:_events.pop_front()
 subject[LOSS_MARKER]=true
 return true

func capture_losses(units:Array,buildings:Array,at:float)->void:
 # A terminal loss can return before later actors reach the cleanup loop.
 # This one defeat-time pass preserves simultaneous recorded health losses.
 for collection in [units,buildings]:
  for subject in collection:record_loss(subject,at)

func snapshot()->Dictionary:
 return {"version":1,"mission":_mission,"run_seed":_run_seed,"events":_events.duplicate(true)}

func restore(value:Variant,mission:int,run_seed:int,elapsed:float)->bool:
 # Validation is pure and happens before replacing even the recap state.
 if not validate(value,mission,str(run_seed),elapsed):return false
 _mission=mission
 _run_seed=str(run_seed)
 _events.clear()
 for event in value.events:
  # JSON stores all numbers as doubles. Restore the recorder's canonical
  # integer count so save/resume does not change its primitive representation.
  _events.append({"kind":str(event.kind),"first_time":float(event.first_time),"time":float(event.time),"count":int(event.count),"unfinished":bool(event.unfinished)})
 return true

static func validate(value:Variant,mission:int,run_seed:String,elapsed:float)->bool:
 if not value is Dictionary or value.size()!=4 or not _number(elapsed,0):return false
 if not _integer(value.get("version"),1,1) or not _integer(value.get("mission"),0,2):return false
 if int(value.mission)!=mission or not value.get("run_seed") is String or value.run_seed!=run_seed:return false
 if not value.get("events") is Array or value.events.size()>MAX_EVENTS:return false
 var previous_time:float=-1.0
 for event in value.events:
  if not event is Dictionary or event.size()!=5:return false
  if not event.get("kind") is String or event.kind not in KINDS:return false
  if not _number(event.get("first_time"),0,elapsed) or not _number(event.get("time"),float(event.first_time),elapsed):return false
  if float(event.time)<previous_time or not event.get("unfinished") is bool:return false
  previous_time=float(event.time)
  if not _integer(event.get("count"),1,10000):return false
  if event.kind=="worker":
   if event.unfinished or float(event.time)-float(event.first_time)>WORKER_CLUSTER_SECONDS:return false
   if int(event.count)==1 and event.time!=event.first_time:return false
  elif int(event.count)!=1 or event.time!=event.first_time:return false
  if event.unfinished and not Rules.BUILDINGS.has(event.kind):return false
 return true

func recent_events(at:float,limit:int=3)->Array:
 if not _number(at,0):return []
 var candidates:Array=[]
 for event in _events:
  if float(event.time)<=at and float(event.time)>=at-RECENT_SECONDS:candidates.append(event)
 var count:int=mini(clampi(limit,0,3),candidates.size())
 if count==0:return []
 var start:int=candidates.size()-count
 var chosen:Array=candidates.slice(start)
 # Keep the actual terminal loss visible during simultaneous mass losses.
 # Its earlier position in a damage loop does not make it less relevant.
 for index in range(candidates.size()-1,-1,-1):
  if candidates[index].kind not in TERMINAL_KINDS:continue
  if index<start:
   chosen.pop_front()
   chosen.push_front(candidates[index])
  break
 return chosen.duplicate(true)

func recent_lines(at:float,limit:int=3)->Array[String]:
 var lines:Array[String]=[]
 for event in recent_events(at,limit):lines.append(event_text(event))
 return lines

static func event_text(event:Dictionary)->String:
 var stamp:String=_clock(float(event.time))
 if event.kind=="worker" and int(event.count)>1 and int(event.first_time)!=int(event.time):
  stamp=_clock(float(event.first_time))+"〜"+stamp
 var fact:String
 if event.kind=="worker":fact="作業員 %d人を喪失"%int(event.count)
 else:
  var rule:Dictionary=Rules.BUILDINGS.get(event.kind,Rules.UNITS.get(event.kind,{}))
  fact=("建設中の" if event.unfinished else "")+str(rule.title)+"を喪失"
 return stamp+"  "+fact

static func _clock(at:float)->String:
 var seconds:int=int(floor(at))
 return "%02d:%02d"%[int(seconds/60),seconds%60]

static func _number(value:Variant,minimum:float=-INF,maximum:float=INF)->bool:
 return (value is int or value is float) and is_finite(float(value)) and value>=minimum and value<=maximum

static func _integer(value:Variant,minimum:int,maximum:int)->bool:
 return _number(value,minimum,maximum) and float(value)==floor(float(value))
