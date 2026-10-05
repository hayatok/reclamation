extends SceneTree
const Alerts=preload("res://building_attack_alerts.gd")
var failures:=0
var checks:=0
func _initialize():call_deferred("run")
func check(ok:bool,label:String):
 checks+=1
 if ok:print("PASS ",label)
 else:failures+=1;push_error("FAIL "+label)
func run():
 var node=Node3D.new();root.add_child(node)
 var b={"node":node,"kind":"depot","built":1.0,"hp":240.0,"maxhp":260.0}
 var a=Alerts.new()
 a.record_hit(b,0);check(a.update(0,[b]),"first engagement requests one protected warning")
 a.record_hit(b,1);a.update(1,[b])
 a.update(6.1,[b]);check(a.current.is_empty(),"quiet temporary attack alert expires")
 a.record_hit(b,10);a.update(10,[b])
 check(a.current.is_empty(),"new normal engagement respects eighteen-second per-target gap")
 for now in [11.0,12.0,13.0,14.0,15.0,16.0,17.0]:a.record_hit(b,now);a.update(now,[b])
 a.record_hit(b,18)
 check(a.update(18,[b]) and a.current.target==b,"still-active delayed engagement becomes eligible without requiring another quiet interval")
 b.hp=70.0;a.record_hit(b,18.1)
 check(not a.update(18.1,[b]) and a.current.severity==2,"same-target critical transition bypasses text gap but obeys sound gap")
 b.hp=200.0
 check(a.text_for("資材集積所")=="資材集積所：攻撃を受けた","repaired building no longer falsely reads critical")
 a.update(19,[])
 check(a.current.is_empty(),"voluntary removal clears attack feedback without a false loss")
 a.reset();a.record_hit(b,0);a.update(0,[b]);a.update(61,[b])
 check(a.recent.is_empty() and a.current.is_empty(),"old transient target records are bounded and removed")
 a.reset();a.record_hit(b,0);a.last_shown=0
 a.update(9,[b])
 check(a.current.is_empty(),"queued alerts for resolved engagements are discarded")
 node.free()
 print("BUILDING_ATTACK_ALERT_EDGES_SUMMARY checks=%d failures=%d"%[checks,failures])
 quit(0 if failures==0 else 1)
