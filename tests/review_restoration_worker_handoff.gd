extends SceneTree
## Controlled partial restoration setup; native right-click starts the real order.
var g:Node
var worker:Dictionary
var site:Dictionary
var out:String
var done=false
func _initialize():call_deferred("run")
func run():
 out=OS.get_environment("RESTORATION_REVIEW_OUTPUT")
 DirAccess.make_dir_recursive_absolute(out)
 var c=root.get_node("Campaign");c.current=0;c.launch=true;c.resume=false;c.run_seed=71221;c.muted=true
 g=load("res://main.tscn").instantiate();root.add_child(g);g.paused=true
 g.settlement_age=2
 site=g.get_site("generator");site.paid=true;site.progress=.98
 worker=g.units.filter(func(u):return u.kind=="worker")[0]
 g.economy.assign_resource(worker,g.resource_nodes[0])
 g.friendly_navigation.invalidate_order(worker)
 g.selected=[worker];g.inspected={};g.update_selection()
 g.camera_focus=site.node.position;g.camera.position=g.camera_focus+Vector3(37,48,43);g.camera.look_at(g.camera_focus);g.camera.size=38
 for frame in 12:await process_frame
 await capture("initial")
 process_frame.connect(observe)
func observe():
 if done or worker.task!="site":return
 done=true;call_deferred("complete")
func complete():
 await capture("ordered")
 # Keep world paused: advance only this already-paid near-complete work fixture.
 for tick in 500:
  g.friendly_navigation.begin_frame(.05,g.units)
  g.friendly_navigation.advance(worker,g.nav,.05,5.0)
  if g.friendly_navigation.is_arrived(worker):g.work_site(worker,.05)
  if site.reclaimed:break
 g.update_ui();g.update_selection()
 for frame in 12:await process_frame
 await capture("completed")
func capture(stage:String):
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(out.path_join(stage+".png"))
 var report={"stage":stage,"task":worker.task,"economy_phase":worker.get("economy_phase",""),"resource_kind":worker.get("resource_kind",""),"return_assignment":str(worker.get("return_assignment",{})),"cargo":worker.get("cargo",0),"reclaimed":site.reclaimed,"point":str(g.camera.unproject_position(site.node.position)),"selected":g.selected.size()}
 var f=FileAccess.open(out.path_join(stage+".json"),FileAccess.WRITE);f.store_string(JSON.stringify(report,"  "));f.close()
 print(JSON.stringify(report))
