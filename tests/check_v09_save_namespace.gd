extends SceneTree
# Run with a fresh isolated XDG_DATA_HOME. Refuses pre-existing saves and removes only its own fixtures.
# XDG_DATA_HOME="$(mktemp -d)" godot --headless --path . --script res://tests/check_v09_save_namespace.gd
const LEGACY_CHECKPOINT="user://checkpoint.json"
const LEGACY_CAMPAIGN="user://campaign.json"
const V2_CHECKPOINT="user://settlement_v2/checkpoint.json"
const V2_CAMPAIGN="user://settlement_v2/campaign.json"
const LEGACY_CHECKPOINT_BYTES='{\r\n  "version": 1, "sentinel": "旧版の作戦を保持", "resources": 9876\r\n}\r\n'
const LEGACY_CAMPAIGN_BYTES='{\r\n "version": 1, "unlocked": 3, "best": {"2":{"time":99,"kills":123}}, "muted":true, "low_fx":true, "performance_mode":true, "sentinel":"旧版の進行と設定を保持"\r\n}\r\n'
var passed:int=0
var failed:int=0
var g:Node
func _initialize():call_deferred("run")
func check(ok:bool,label:String):
 if ok:passed+=1;print("PASS ",label)
 else:failed+=1;print("FAIL ",label)
func write_text(path:String,value:String):
 var file=FileAccess.open(path,FileAccess.WRITE)
 if file==null:check(false,"fixture file opens: "+path);return
 file.store_buffer(value.to_utf8_buffer());file.close()
func legacy_unchanged(stage:String):
 check(FileAccess.file_exists(LEGACY_CHECKPOINT) and FileAccess.get_file_as_bytes(LEGACY_CHECKPOINT)==LEGACY_CHECKPOINT_BYTES.to_utf8_buffer(),stage+": legacy checkpoint remains byte-exact")
 check(FileAccess.file_exists(LEGACY_CAMPAIGN) and FileAccess.get_file_as_bytes(LEGACY_CAMPAIGN)==LEGACY_CAMPAIGN_BYTES.to_utf8_buffer(),stage+": legacy progression/settings remain byte-exact")
func has_button(node:Node,title:String)->bool:
 if node is Button and node.text==title:return true
 for child in node.get_children():
  if has_button(child,title):return true
 return false
func create_scene():
 g=load("res://main.tscn").instantiate();root.add_child(g);current_scene=g;g.set_process(false)
func run():
 for path in [LEGACY_CHECKPOINT,LEGACY_CAMPAIGN,V2_CHECKPOINT,V2_CAMPAIGN,V2_CHECKPOINT+".tmp"]:
  if FileAccess.file_exists(path):
   push_error("Use a fresh isolated XDG_DATA_HOME; refusing to replace existing save: "+path)
   quit(2);return
 write_text(LEGACY_CHECKPOINT,LEGACY_CHECKPOINT_BYTES)
 write_text(LEGACY_CAMPAIGN,LEGACY_CAMPAIGN_BYTES)
 var campaign=root.get_node("Campaign")
 var probe=load("res://campaign.gd").new();root.add_child(probe)
 check(probe.unlocked==1 and probe.best.is_empty() and not probe.muted and not probe.low_fx and not probe.performance_mode,"legacy-only campaign is ignored without migration")
 probe.queue_free()
 campaign.current=0;campaign.launch=false;campaign.resume=false
 create_scene()
 await process_frame
 check(g.title_open and not has_button(g.title_panel,"作戦を再開"),"legacy-only checkpoint does not offer Continue")
 var before=g.stockpile.duplicate(true);var count=g.units.size()
 check(not g.load_checkpoint() and g.stockpile==before and g.units.size()==count,"legacy-only checkpoint is ignored without mutating the new game")
 check(not FileAccess.file_exists(V2_CHECKPOINT) and not FileAccess.file_exists(V2_CAMPAIGN),"legacy files are not copied into the new namespace")
 legacy_unchanged("legacy-only startup")
 g.queue_free();await process_frame
 campaign.launch=true;campaign.muted=true
 create_scene()
 await process_frame
 g.stockpile={"food":400.0,"salvage":150.0,"parts":70.0}
 var hq=g.buildings[0]
 check(g.production.queue_unit(hq,"worker"),"new game queues paid worker")
 g.production.update(6)
 var worker=g.units.filter(func(unit):return unit.kind=="worker")[0]
 var worker_index=g.units.find(worker)
 worker.cargo=5.0;worker.cargo_kind="food";g.economy.assign_resource(worker,g.resource_nodes[0])
 g.save_checkpoint(false)
 check(FileAccess.file_exists(V2_CHECKPOINT),"new game creates namespaced checkpoint")
 check(not FileAccess.file_exists(V2_CHECKPOINT+".tmp"),"checkpoint temporary file is renamed within namespace")
 var saved=JSON.parse_string(FileAccess.get_file_as_string(V2_CHECKPOINT))
 check(saved is Dictionary and saved.version==2 and g.valid_checkpoint(saved),"namespaced checkpoint uses valid schema 2")
 legacy_unchanged("new game save")
 g.stockpile.food=1;worker.cargo=0;hq.queue[0].remaining=999
 check(g.load_checkpoint(),"schema 2 namespaced checkpoint loads")
 worker=g.units[worker_index];hq=g.buildings[0]
 check(g.stockpile.food==350 and g.stockpile.salvage==150 and g.stockpile.parts==70,"stockpile roundtrip preserves all three resources")
 check(worker.cargo==5 and worker.cargo_kind=="food" and worker.task=="gather" and worker.resource_target==g.resource_nodes[0],"cargo and gathering assignment roundtrip")
 check(hq.queue.size()==1 and hq.queue[0].kind=="worker" and hq.queue[0].remaining==12 and hq.queue[0].paid_cost.food==50,"queue progress and paid cost roundtrip")
 legacy_unchanged("new game load")
 campaign.muted=true;campaign.low_fx=true;campaign.performance_mode=true;campaign.save_progress()
 check(FileAccess.file_exists(V2_CAMPAIGN),"settings save uses namespaced campaign file")
 campaign.complete(61,17)
 var progress=JSON.parse_string(FileAccess.get_file_as_string(V2_CAMPAIGN))
 check(progress.unlocked==2 and progress.best["0"].time==61 and progress.best["0"].kills==17,"progression save uses namespaced campaign file")
 check(progress.muted and progress.low_fx and progress.performance_mode,"all settings persist in the new namespace")
 probe=load("res://campaign.gd").new();root.add_child(probe)
 check(probe.unlocked==2 and probe.best.has("0") and not probe.best.has("2") and probe.muted and probe.low_fx and probe.performance_mode,"campaign loads its own progression/settings, not the legacy sentinel")
 probe.queue_free()
 legacy_unchanged("progression and settings save")
 g.show_title()
 check(has_button(g.title_panel,"作戦を再開"),"schema 2 namespaced checkpoint offers Continue")
 var previous=g
 g.resume_checkpoint()
 for frame in 6:
  await process_frame
  if is_instance_valid(current_scene) and current_scene!=previous:
   g=current_scene;g.set_process(false);break
 check(is_instance_valid(g) and g!=previous and not g.title_open and not campaign.resume,"Continue actually reloads and consumes the namespaced checkpoint")
 if not is_instance_valid(g) or g==previous:
  print("V09_SAVE_NAMESPACE_SUMMARY passed=%d failed=%d"%[passed,failed]);quit(1);return
 worker=g.units[worker_index];hq=g.buildings[0]
 check(g.stockpile.food==350 and worker.cargo==5 and hq.queue.size()==1 and hq.queue[0].remaining>11 and hq.queue[0].remaining<=12,"Continue restores the schema 2 economy fixture")
 legacy_unchanged("Continue")
 g.finish(false)
 check(not FileAccess.file_exists(V2_CHECKPOINT) and FileAccess.file_exists(V2_CAMPAIGN),"defeat deletes only namespaced checkpoint and keeps namespaced progression")
 legacy_unchanged("defeat")
 g.queue_free();await process_frame
 campaign.current=0;campaign.launch=true;campaign.resume=false
 create_scene();await process_frame;g.save_checkpoint(false)
 check(FileAccess.file_exists(V2_CHECKPOINT),"second new game saves a fresh namespaced checkpoint")
 g.finish(true)
 check(not FileAccess.file_exists(V2_CHECKPOINT) and FileAccess.file_exists(V2_CAMPAIGN),"victory deletes only namespaced checkpoint and keeps namespaced progression")
 legacy_unchanged("victory")
 # Verify schema 1 also stays invalid if explicitly placed in the new namespace.
 saved.version=1;write_text(V2_CHECKPOINT,JSON.stringify(saved))
 before=g.stockpile.duplicate(true)
 check(not g.load_checkpoint() and g.stockpile==before,"schema 1 is rejected even inside the v2 namespace")
 legacy_unchanged("schema 1 rejection")
 for path in [LEGACY_CHECKPOINT,LEGACY_CAMPAIGN,V2_CHECKPOINT,V2_CAMPAIGN,V2_CHECKPOINT+".tmp"]:
  if FileAccess.file_exists(path):DirAccess.remove_absolute(path)
 print("V09_SAVE_NAMESPACE_SUMMARY passed=%d failed=%d"%[passed,failed])
 g.queue_free();await process_frame;quit(1 if failed else 0)
