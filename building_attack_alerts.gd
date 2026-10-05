extends RefCounted
## Presentation-only event memory. Never serialized or used by combat/orders.
const QUIET_GAP := 8.0
const TARGET_GAP := 18.0
const GLOBAL_GAP := 3.0
const SOUND_GAP := 8.0
const LIFETIME := 6.0
const CRITICAL := 0.30
var recent: Dictionary = {}
var current: Dictionary = {}
var last_shown := -1000.0
var last_sound := -1000.0

func reset() -> void:
 recent.clear();current.clear();last_shown=-1000.0;last_sound=-1000.0

func record_hit(target: Dictionary, now: float) -> void:
 if not target.has("built") or target.get("kind", "") in ["wall", "tower", "mortar"]:return
 if not is_instance_valid(target.get("node")):return
 var id: int=target.node.get_instance_id()
 if not recent.has(id):
  recent[id]={"id":id,"target":target,"position":target.node.position,"last_hit":-1000.0,"last_alert":-1000.0,"critical_sent":false,"pending":0,"ready_at":now}
 var entry: Dictionary=recent[id]
 var fresh: bool=now-float(entry.last_hit)>=QUIET_GAP
 if fresh:entry.critical_sent=false
 entry.last_hit=now
 var severity: int=3 if float(target.hp)<=0 else 2 if float(target.hp)<=float(target.maxhp)*CRITICAL else 1
 # One start, one critical deterioration, and one truthful loss per engagement.
 if severity==3 or (severity==2 and not entry.critical_sent) or fresh:
  entry.pending=maxi(int(entry.pending),severity)
  entry.ready_at=now if severity>1 else maxf(now,float(entry.last_alert)+TARGET_GAP)
  if severity==2:entry.critical_sent=true

func update(now: float, buildings: Array) -> bool:
 var changed := false
 if not current.is_empty():
  var target: Dictionary=current.target
  # Keep the last location after destruction, never dereference its freed node.
  if current.severity<3 and float(target.hp)<=0:
   current.severity=3;current.until=now+LIFETIME
   var entry: Dictionary=recent.get(current.id,{})
   if not entry.is_empty():entry.pending=0;entry.last_alert=now
   last_shown=now;changed=true
  elif current.severity<3 and target not in buildings:
   current.clear() # Voluntary removal is not an enemy destruction alert.
  if not current.is_empty() and now>=float(current.until):current.clear()
 var best: Dictionary={}
 var best_priority := -1
 for id in recent.keys():
  var entry: Dictionary=recent[id]
  var target: Dictionary=entry.target
  if now-float(entry.last_hit)>60.0:
   recent.erase(id);continue
  if int(entry.pending)==0:continue
  if float(target.hp)>0 and target not in buildings:
   recent.erase(id);continue
  if now-float(entry.last_hit)>QUIET_GAP:
   entry.pending=0;continue # No delayed warning for an engagement already over.
  var same: bool=not current.is_empty() and current.id==id
  var escalation: bool=same and int(entry.pending)>int(current.severity)
  if now<float(entry.ready_at) or (now-last_shown<GLOBAL_GAP and not escalation):continue
  # An endangered HQ wins ties and simultaneous lower-priority structure hits.
  var priority: int=int(entry.pending)*3+(10 if target.kind=="hq" else 0)
  if priority>best_priority:best=entry;best_priority=priority
 if not best.is_empty():
  current={"id":best.id,"target":best.target,"position":best.position,"severity":best.pending,"until":now+LIFETIME}
  best.pending=0;best.last_alert=now;last_shown=now;changed=true
 if changed and now-last_sound>=SOUND_GAP:
  last_sound=now;return true
 return false

func text_for(title: String) -> String:
 if current.is_empty():return ""
 if int(current.severity)==3:return title+"：喪失"
 var target: Dictionary=current.target
 if float(target.hp)<=float(target.maxhp)*CRITICAL:
  return title+"：耐久危険 %d%%"%maxi(1,ceili(float(target.hp)/float(target.maxhp)*100.0))
 return title+"：攻撃を受けた"
