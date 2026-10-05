extends SceneTree
## Worker-only observer boundaries; existing building test covers main focus.
const Alerts=preload("res://building_attack_alerts.gd")
var checks:=0
var failures:Array[String]=[]
func _initialize():call_deferred("run")
func check(ok:bool,label:String):
 checks+=1
 if ok:print("PASS ",label)
 else:failures.append(label);push_error("FAIL "+label)
func target(kind:String,position:Vector3)->Dictionary:
 var node=Node3D.new();root.add_child(node);node.position=position
 var result={"kind":kind,"node":node,"hp":100.0,"maxhp":100.0}
 if kind in ["hq","depot"]:result.built=1.0
 return result
func run():
 var worker=target("worker",Vector3(-14,0,9))
 var depot=target("depot",Vector3(10,0,8))
 var hq=target("hq",Vector3.ZERO)
 var a=Alerts.new()
 a.record_hit(worker,0)
 check(a.update(0,[worker]) and a.current.target==worker,"worker without built field requests first warning")
 check(a.text_for("作業員")=="作業員：攻撃を受けた","worker attack uses truthful named text")
 worker.node.position=Vector3(-10,0,7);a.update(.1,[worker])
 check(a.current.position==worker.node.position,"active worker cue follows living position without another hit")
 worker.hp=25;a.record_hit(worker,.2)
 check(not a.update(.2,[worker]) and a.current.severity==2,"worker critical escalation bypasses display gap while respecting sound gap")
 worker.node.position=Vector3(-7,0,4);worker.hp=0;a.record_hit(worker,.3)
 var death_position:Vector3=worker.node.position
 worker.node.free();a.update(.3,[])
 check(a.current.severity==3 and a.text_for("作業員")=="作業員：喪失","freed worker remains a truthful loss")
 check(a.current.position==death_position,"worker loss preserves final recorded hit position after node free")
 worker=target("worker",Vector3(-14,0,9));a.reset()
 a.record_hit(depot,0);a.update(0,[worker,depot])
 a.record_hit(worker,.1);a.update(.1,[worker,depot])
 check(a.current.target==depot,"worker warning respects existing building global display gap")
 worker.node.position=Vector3(-4,0,3)
 check(not a.update(3,[worker,depot]) and a.current.target==worker,"queued worker appears after global gap without replaying sound")
 check(a.current.position==worker.node.position,"newly displayed queued worker uses its current living location")
 worker.hp=20;a.record_hit(worker,8)
 check(a.update(8,[worker,depot]) and a.current.severity==2,"critical worker warning can sound once eight-second gap passes")
 a.update(8.1,[])
 check(a.current.is_empty(),"living worker removed voluntarily does not create false loss")
 worker.hp=100;a.reset();depot.hp=25
 a.record_hit(worker,0);a.record_hit(depot,0);a.update(0,[worker,depot,hq])
 check(a.current.target==depot,"critical economic building retains priority over normal worker damage")
 a.reset();worker.hp=0;a.record_hit(worker,0);a.record_hit(hq,0);a.update(0,[worker,depot,hq])
 check(a.current.target==hq,"HQ retains priority even over simultaneous worker loss")
 a.reset()
 for kind in ["guard","grenade","siegecart"]:
  var fighter=target(kind,Vector3.ZERO);a.record_hit(fighter,0);fighter.node.free()
 check(a.recent.is_empty(),"ordinary combat unit hits do not enter strategic alerts")
 for item in [worker,depot,hq]:item.node.free()
 print("WORKER_ATTACK_ALERTS_SUMMARY checks=%d failures=%d"%[checks,failures.size()])
 quit(0 if failures.is_empty() else 1)
