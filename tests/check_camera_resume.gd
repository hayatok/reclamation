extends SceneTree
const Validation=preload("res://checkpoint_validation.gd")
const PATH="user://settlement_v2/checkpoint.json"
var g:Node
var passed:int=0
var failed:int=0
func _initialize():call_deferred("run")
func check(ok:bool,label:String):
 if ok:passed+=1;print("PASS ",label)
 else:failed+=1;push_error("FAIL "+label)
func write_checkpoint(data:Dictionary):
 for suffix in ["",".bak",".tmp",".bak.tmp"]:
  if FileAccess.file_exists(PATH+suffix):DirAccess.remove_absolute(PATH+suffix)
 var file=FileAccess.open(PATH,FileAccess.WRITE)
 file.store_string(JSON.stringify(data));file.close()
func gameplay(data:Dictionary)->Dictionary:
 var value=data.duplicate(true);value.erase("camera");return value
func same_saved(a:Variant,b:Variant)->bool:
 if a is Dictionary and b is Dictionary:
  if a.size()!=b.size():return false
  for key in a:
   if not b.has(key) or not same_saved(a[key],b[key]):return false
  return true
 if a is Array and b is Array:
  if a.size()!=b.size():return false
  for i in a.size():
   if not same_saved(a[i],b[i]):return false
  return true
 # JSON parses integers as floats and may round the final double digit.
 if (a is int or a is float) and (b is int or b is float):return absf(float(a)-float(b))<=1e-12
 return a==b
func same_gameplay(a:Dictionary,b:Dictionary)->bool:return same_saved(gameplay(a),gameplay(b))
func run():
 if DirAccess.dir_exists_absolute("user://settlement_v2"):
  push_error("Fresh isolated XDG_DATA_HOME required");quit(2);return
 var campaign=root.get_node("Campaign")
 campaign.current=0;campaign.launch=true;campaign.resume=false;campaign.muted=true;campaign.run_seed=20261005
 g=load("res://main.tscn").instantiate();root.add_child(g);current_scene=g;g.set_process(false)
 await process_frame
 g.paused=true
 g.economy.assign_resource(g.units[2],g.resource_nodes[8])
 g.selected=[g.units[3]];g.inspected={};g.command_at(Vector3(12,0,-10))
 g.selected=[g.units[2],g.units[3]];g.update_selection()
 g.camera_focus=Vector3(-12.25,0,15.5);g.camera.size=32.75
 g._process(0)
 var original_view:Transform3D=g.camera.transform
 var data:Dictionary=g.checkpoint_data()
 check(Validation.validate(data) and same_saved(data.camera,{"focus":[-12.25,0,15.5],"size":32.75}),"real scene serializes bounded nondefault focus and fractional zoom")
 check(data.units[2].task=="gather" and data.units[3].task=="move" and data.selected==[2,3],"fixture has independent gathering and movement orders with selected workers")
 check(g.save_checkpoint(false)==OK,"camera checkpoint writes through the real atomic save")
 var saved_rng=[str(g.rng.state),str(g.card_rng.state),str(g.visual_rng.state)]
 g.camera_focus=Vector3(18,0,-18);g.camera.size=85;g.selected=[]
 # Exercise the actual title Continue path, including _ready's opening logic.
 g.resume_checkpoint()
 await scene_changed
 g=current_scene;g.set_process(false)
 check(g.camera_focus==Vector3(-12.25,0,15.5) and is_equal_approx(g.camera.size,32.75) and g.camera.transform.is_equal_approx(original_view),"Continue restores focus, zoom and camera transform before its first process frame")
 check(g.render_frames==0 and not g.title_open and g.selected==[g.units[2],g.units[3]] and g.inspected.is_empty(),"zero-elapsed Continue preserves worker selection instead of opening HQ")
 check(same_gameplay(g.checkpoint_data(),data),"Continue leaves every serialized gameplay field and both worker orders unchanged")
 check(saved_rng==[str(g.rng.state),str(g.card_rng.state),str(g.visual_rng.state)],"camera restoration consumes no combat, card or visual random state")
 g._process(0)
 check(g.camera.transform.is_equal_approx(original_view),"first process frame keeps the restored view without a jump")
 # The view is independent of the current selection or unit order target.
 var empty=data.duplicate(true);empty.selected=[];empty.camera={"focus":[18,0,-18],"size":85}
 write_checkpoint(empty)
 check(g.load_checkpoint() and g.selected.is_empty() and g.camera_focus==Vector3(18,0,-18) and g.camera.size==85 and same_gameplay(g.checkpoint_data(),empty),"empty selection restores its own camera and preserves all gameplay state")
 var near=data.duplicate(true);near.selected=[0];near.camera={"focus":[-18,0,18],"size":26}
 write_checkpoint(near)
 check(g.load_checkpoint() and g.selected==[g.units[0]] and g.camera_focus==Vector3(-18,0,18) and g.camera.size==26 and same_gameplay(g.checkpoint_data(),near),"different selection restores opposite view and accepts exact pan and zoom limits")
 var before=gameplay(g.checkpoint_data())
 g.camera_focus=Vector3(-24,0,29);g.camera.size=100
 var bounded:Dictionary=g.checkpoint_data()
 check(Validation.validate(bounded) and same_saved(bounded.camera,{"focus":[-18,0,18],"size":85}) and same_gameplay(bounded,before) and g.camera_focus==Vector3(-24,0,29),"saving an unprocessed focus shortcut bounds only serialized camera values")
 g.camera_focus=Vector3(2,0,3);g.camera.size=40;g._process(0)
 var mutations=[null,[],{},"bad",{"focus":[0,0,0]},{"size":54},{"focus":[0,0],"size":54},{"focus":[0,0,0,0],"size":54},{"focus":"bad","size":54}]
 for focus in [[-18.01,0,0],[18.01,0,0],[0,0,-18.01],[0,0,18.01],[0,0.01,0],[0,-0.01,0],[NAN,0,0],[0,INF,0],[0,0,-INF],["0",0,0],[0,true,0],[0,0,null]]:
  mutations.append({"focus":focus,"size":54})
 for size in [25.99,85.01,NAN,INF,-INF,"54",true,null]:mutations.append({"focus":[0,0,0],"size":size})
 var live=JSON.stringify(g.checkpoint_data())
 var live_view:Transform3D=g.camera.transform
 var live_ids=g.units.map(func(unit):return unit.node.get_instance_id())
 var rejected=0
 var unchanged=0
 for camera_value in mutations:
  var bad=data.duplicate(true);bad.camera=camera_value
  if not Validation.validate(bad):rejected+=1
  write_checkpoint(bad)
  if not g.load_checkpoint() and live==JSON.stringify(g.checkpoint_data()) and g.camera.transform==live_view and live_ids==g.units.map(func(unit):return unit.node.get_instance_id()):unchanged+=1
 check(rejected==mutations.size(),"all %d malformed, nonfinite and out-of-range camera values fail validation"%mutations.size())
 check(unchanged==mutations.size(),"all %d invalid camera loads preserve the entire live world, view and actor identities"%mutations.size())
 var absent=data.duplicate(true);absent.erase("camera")
 check(Validation.validate(absent),"schema-3 checkpoint without optional camera remains valid")
 write_checkpoint(absent)
 check(g.load_checkpoint() and g.camera_focus==Vector3.ZERO and g.camera.size==54 and g.camera.position==Vector3(37,48,43) and same_gameplay(g.checkpoint_data(),absent),"absent camera uses explicit original defaults and leaves selection and orders independent")
 print("CAMERA_RESUME_SUMMARY passed=%d failed=%d"%[passed,failed])
 g.queue_free();await process_frame;await process_frame;quit(1 if failed else 0)
