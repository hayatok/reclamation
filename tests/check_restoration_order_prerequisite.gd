extends SceneTree
var failures=0
var g
func check(ok:bool,title:String):
 print("PASS " if ok else "FAIL ",title)
 if not ok:failures+=1
func _initialize():call_deferred("run")
func run():
 DirAccess.make_dir_recursive_absolute("user://settlement_v2")
 var f=FileAccess.open("user://settlement_v2/checkpoint.json",FileAccess.WRITE)
 f.store_string(FileAccess.get_file_as_string("res://tests/fixtures/native_age_research_in_progress.json"));f.close()
 var c=root.get_node("Campaign");c.current=1;c.launch=true;c.resume=true;c.muted=true
 g=load("res://main.tscn").instantiate();root.add_child(g);g.set_process(false);g.paused=true
 var workers=g.units.filter(func(u):return u.kind=="worker").slice(0,3)
 var site=g.sites.filter(func(s):return s.kind=="generator")[0]
 g.selected.assign(workers);g.inspected={};g.update_selection()
 check(g.settlement_age==1 and workers[0].task=="gather","native fixture is gathering during Age II research")
 var before=g.checkpoint_data()
 check(not g.command_at(site.node.position),"unavailable restoration is rejected at issuance")
 check(g.checkpoint_data()==before,"rejection preserves full saved state including work, cargo, queues and RNG")
 check(not g.command_at(site.node.position),"repeated unavailable order remains rejected")
 check(g.checkpoint_data()==before,"repeat does not erase existing assignment")
 var fighter=g.units.filter(func(u):return u.kind=="guard")[0]
 g.selected.append(fighter)
 check(g.command_at(site.node.position),"mixed selection can still send its fighter")
 check(fighter.task=="move" and workers[0].task=="gather","worker retains gathering while fighter moves")
 g.selected.assign(workers);g.settlement_age=2
 check(g.command_at(site.node.position),"restoration becomes available after development completes")
 check(workers.all(func(u):return u.task=="site" and u.target==site),"eligible workers receive actual restoration order")
 print("RESTORATION_PREREQUISITE_RESULT failures=",failures)
 g.free();await process_frame;quit(1 if failures else 0)
