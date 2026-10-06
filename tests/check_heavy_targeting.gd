extends SceneTree
## godot --headless --path . --script res://tests/check_heavy_targeting.gd
const Targeting=preload("res://heavy_targeting.gd")
var actors:Array=[]
var failures:Array=[]
var checks:int=0

func _initialize():
 run_cases()
 run_dense(1000)
 run_dense(3000)
 for node in actors:
  if is_instance_valid(node):node.free()
 print("HEAVY_TARGETING checks=",checks," failures=",failures.size())
 quit(0 if failures.is_empty() else 1)

func check(value:bool,label:String):
 checks+=1
 if value:print("PASS ",label)
 else:failures.append(label);push_error("FAIL "+label)

func enemy_at(position:Vector3)->Dictionary:
 var node:=Node3D.new()
 node.position=position
 actors.append(node)
 return {"node":node,"hp":45.0,"dead":false}

func select_target(enemies:Array,origin:Vector3,weapon_range:float,blast_radius:float)->Variant:
 return Targeting.new().select_target(enemies,origin,weapon_range,blast_radius)

func query(enemies:Array,origin:Vector3,weapon_range:float,blast_radius:float)->Dictionary:
 return Targeting.new().query(enemies,origin,weapon_range,blast_radius)

func run_cases():
 var near:Dictionary=enemy_at(Vector3(2,0,0))
 var group:Array=[enemy_at(Vector3(8,0,-.5)),enemy_at(Vector3(8,0,.5)),enemy_at(Vector3(9,0,0)),enemy_at(Vector3(9,0,1))]
 var enemies:Array=[near]+group
 var selected:Variant=select_target(enemies,Vector3.ZERO,13,3)
 check(selected in group,"nearer isolated straggler loses to an in-range crowd")
 check(selected==group[0],"equal crowd counts choose nearest, then stable input order")
 check(select_target(enemies,Vector3.ZERO,6,3)==near,"an out-of-range crowd cannot be the primary aim center")
 check(select_target(group,Vector3.ZERO,6,3)==null,"no in-range aim center returns null")
 check(select_target([near],Vector3.ZERO,6,3)==near,"single isolated enemy remains a target")
 check(select_target([],Vector3.ZERO,6,3)==null,"empty list returns null")
 var dead:Dictionary=enemy_at(Vector3(1,0,0));dead.dead=true
 var zero_hp:Dictionary=enemy_at(Vector3(.5,0,0));zero_hp.hp=0
 var freed:Dictionary=enemy_at(Vector3(.2,0,0));freed.node.free()
 var queued:Dictionary=enemy_at(Vector3(.1,0,0));queued.node.queue_free()
 var invalid:Array=[null,{}, {"node":null,"dead":false},dead,zero_hp,freed,queued]
 check(select_target(invalid+[near],Vector3.ZERO,6,3)==near,"dead, zero HP, null, freed and queued nodes are excluded")
 check(select_target(invalid,Vector3.ZERO,6,3)==null,"all invalid candidates return null")
 var edge:Dictionary=enemy_at(Vector3(6,0,0))
 check(select_target([edge],Vector3.ZERO,6,3)==null,"exact weapon-range edge matches nearest_enemy's strict boundary")
 var neighbor:Dictionary=enemy_at(Vector3(5,0,3))
 var center:Dictionary=enemy_at(Vector3(5,0,0))
 var boundary:Dictionary=query([center,neighbor],Vector3.ZERO,6,3)
 check(boundary.score==1,"exact blast edge is excluded just as detonate_shell excludes it")
 var beyond:Dictionary=enemy_at(Vector3(6.2,0,0))
 var near_edge:Dictionary=enemy_at(Vector3(5.8,0,0))
 var cross_range:Dictionary=query([near,near_edge,beyond],Vector3.ZERO,6,1)
 check(cross_range.target==near_edge and cross_range.score==2,"legal aim center counts splash victims beyond firing range")
 var elevated:Dictionary=enemy_at(Vector3(5,4,0))
 check(query([center,elevated],Vector3.ZERO,10,3).score==1,"ground bins retain actual 3D explosion distance")
 var left:Dictionary=enemy_at(Vector3(-5,0,0))
 var right:Dictionary=enemy_at(Vector3(5,0,0))
 check(select_target([left,right],Vector3.ZERO,10,1)==left,"exact distance tie preserves first source enemy")
 check(select_target([right,left],Vector3.ZERO,10,1)==right,"tie policy follows source order deterministically")
 # A larger real radius changes coverage; callers supply their upgraded radius.
 var wider:Array=[enemy_at(Vector3(8,0,0)),enemy_at(Vector3(8,0,3.4)),enemy_at(Vector3(8,0,-3.4))]
 check(select_target([near]+wider,Vector3.ZERO,13,3)==near,"base radius cannot claim neighbors outside its footprint")
 check(select_target([near]+wider,Vector3.ZERO,13,4.1)==wider[0],"actual larger explosion radius selects the useful group")
 var before:Array=enemies.duplicate(true)
 var transforms:Array=[]
 for enemy in enemies:transforms.append(enemy.node.transform)
 var local_rng:=RandomNumberGenerator.new();local_rng.seed=5566
 var state:int=local_rng.state
 seed(9922)
 var expected:float=randf()
 seed(9922)
 var repeatable:bool=true
 for i in 10:
  if select_target(enemies,Vector3.ZERO,13,3)!=selected:repeatable=false
 check(repeatable,"identical queries repeat the same target")
 check(randf()==expected and local_rng.state==state,"selection consumes no global or gameplay RNG")
 var unchanged:bool=enemies==before
 for i in enemies.size():unchanged=unchanged and enemies[i].node.transform==transforms[i]
 check(unchanged,"input list, enemy dictionaries and node transforms remain unchanged")
 var shared=Targeting.new()
 var initial:Dictionary=shared.query(enemies,Vector3.ZERO,13,3)
 var cached:Dictionary=shared.query(enemies,Vector3.ZERO,13,3)
 check(initial.snapshot_built and initial.grid_built and not cached.snapshot_built and not cached.grid_built,"same-step shots reuse positions and radius bins")
 for enemy in group:enemy.dead=true
 check(shared.select_target(enemies,Vector3.ZERO,13,3)==near,"earlier friendly kills are excluded from cached targets and scores")
 near.node.position=Vector3(30,0,0)
 shared.begin_step()
 check(shared.select_target(enemies,Vector3.ZERO,13,3)==null,"next simulation step rebuilds positions instead of keeping stale targets")
 var added:Dictionary=enemy_at(Vector3(4,0,0));enemies.append(added)
 shared.begin_step()
 check(shared.select_target(enemies,Vector3.ZERO,13,3)==added,"next simulation step includes newly spawned enemies")

func baseline_nearest(enemies:Array,origin:Vector3,weapon_range:float)->Variant:
 var best:float=weapon_range*weapon_range
 var found:Variant=null
 for enemy in enemies:
  if enemy.dead:continue
  var distance:float=origin.distance_squared_to(enemy.node.position)
  if distance<best:best=distance;found=enemy
 return found

func benchmark_batch(enemies:Array,count:int):
 var times:Dictionary={"nearest_one":[],"heavy_first":[],"nearest_eight":[],"heavy_eight":[],"heavy_warm":[]}
 var shared=Targeting.new()
 for repeat in 11:
  var started:int=Time.get_ticks_usec()
  baseline_nearest(enemies,Vector3.ZERO,22)
  if repeat>0:times.nearest_one.append(Time.get_ticks_usec()-started)
  shared.begin_step()
  started=Time.get_ticks_usec()
  shared.select_target(enemies,Vector3.ZERO,22,4.1)
  if repeat>0:times.heavy_first.append(Time.get_ticks_usec()-started)
  started=Time.get_ticks_usec()
  shared.select_target(enemies,Vector3.ZERO,22,4.1)
  if repeat>0:times.heavy_warm.append(Time.get_ticks_usec()-started)
  started=Time.get_ticks_usec()
  for i in 8:baseline_nearest(enemies,Vector3(float(i)*.1,0,0),22)
  if repeat>0:times.nearest_eight.append(Time.get_ticks_usec()-started)
  shared.begin_step()
  started=Time.get_ticks_usec()
  for i in 8:shared.select_target(enemies,Vector3(float(i)*.1,0,0),22,4.1)
  if repeat>0:times.heavy_eight.append(Time.get_ticks_usec()-started)
 var medians:Dictionary={}
 for key in times:
  times[key].sort()
  medians[key]=times[key][5]
 print("HEAVY_TARGETING_BATCH count=",count," median_usec=",JSON.stringify(medians))

func run_dense(count:int):
 var dense:Array=[]
 # Deterministic 50-wide field; no random fixture generation or gameplay assets.
 for i in count:
  dense.append(enemy_at(Vector3(2+float(i%50)*.14,0,-4+float(i/50)*.14)))
 var first:Dictionary=query(dense,Vector3.ZERO,22,4.1)
 check(first.target!=null and first.score==Targeting.SCORE_CAP,"dense %d finds a saturated useful crowd"%count)
 check(first.snapshot_entries==count and first.scanned<=2*count and first.candidates<=Targeting.MAX_CANDIDATES,"dense %d enforces snapshot and bounded query scans"%count)
 check(first.neighbor_checks<=Targeting.MAX_CANDIDATES*first.relevant,"dense %d has a linear bounded neighbor-check budget"%count)
 var samples:Array=[]
 for repeat in 21:
  var started:int=Time.get_ticks_usec()
  var current:Dictionary=query(dense,Vector3.ZERO,22,4.1)
  var duration:int=Time.get_ticks_usec()-started
  if repeat>0:samples.append(duration)
  if current.target!=first.target:failures.append("dense query became nondeterministic")
 samples.sort()
 print("HEAVY_TARGETING_BENCH count=",count," median_us=",samples[samples.size()/2]," p95_us=",samples[18]," candidates=",first.candidates," neighbor_checks=",first.neighbor_checks," cells=",first.cells)
 benchmark_batch(dense,count)
 var straggler:Dictionary=enemy_at(Vector3(-2,0,0))
 for enemy in dense:enemy.node.position.x+=6
 var mixed:Array=[straggler]+dense
 var mixed_started:int=Time.get_ticks_usec()
 var mixed_result:Dictionary=query(mixed,Vector3.ZERO,22,4.1)
 var mixed_us:int=Time.get_ticks_usec()-mixed_started
 check(mixed_result.target!=straggler and mixed_result.score==Targeting.SCORE_CAP,"dense %d crowd is found beyond a nearer isolated straggler"%count)
 check(mixed_result.candidates>1 and mixed_result.candidates<=Targeting.MAX_CANDIDATES,"dense %d representative search respects its budget"%count)
 print("HEAVY_TARGETING_MIXED count=",mixed.size()," usec=",mixed_us," candidates=",mixed_result.candidates," neighbor_checks=",mixed_result.neighbor_checks)
 # Dispersed input cannot hide an N-by-N fallback behind score saturation.
 var dispersed:Array=[]
 for i in count:dispersed.append(enemy_at(Vector3(float(i%60)*5+1,0,float(i/60)*5+1)))
 var dispersed_started:int=Time.get_ticks_usec()
 var result:Dictionary=query(dispersed,Vector3.ZERO,1000,1)
 var dispersed_us:int=Time.get_ticks_usec()-dispersed_started
 check(result.candidates<=Targeting.MAX_CANDIDATES and result.neighbor_checks<=Targeting.MAX_CANDIDATES*result.relevant,"dispersed %d also enforces the fixed scoring budget"%count)
 check(result.target==dispersed[0],"dispersed %d keeps nearest tie behavior"%count)
 print("HEAVY_TARGETING_DISPERSED count=",count," usec=",dispersed_us," candidates=",result.candidates," neighbor_checks=",result.neighbor_checks)
