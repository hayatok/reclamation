extends SceneTree
var failures=[]
func _initialize():call_deferred("run")
func connected(grid:AStarGrid2D,start:Vector2i)->Dictionary:
 var seen={start:true};var queue=[start];var cursor=0
 while cursor<queue.size():
  var p=queue[cursor];cursor+=1
  for offset in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
   var n=p+offset
   if not seen.has(n) and grid.is_in_boundsv(n) and not grid.is_point_solid(n):seen[n]=true;queue.append(n)
 return seen
func run():
 var reports=[]
 for mission in [0,2]:
  var c=root.get_node("Campaign");c.current=mission;c.launch=true;c.resume=false;c.muted=true;c.choose_run_seed(731054)
  var g=load("res://main.tscn").instantiate();root.add_child(g);current_scene=g;g.set_process(false);g.paused=true
  var origin=g.units[0].node.position;var reachable=connected(g.nav,Vector2i(roundi(origin.x),roundi(origin.z)))
  var unreachable=[]
  for target in g.resource_nodes+g.sites:
   var endpoints=g.friendly_navigation._work_perimeter(g.nav,target,origin);var found=false
   for point in endpoints:
    if reachable.has(Vector2i(roundi(point.x),roundi(point.z))):found=true;break
   if not found:unreachable.append(str(target.get("resource",target.get("kind","")))+"@"+str(target.node.position))
  if not unreachable.is_empty():failures.append({"mission":mission,"unreachable":unreachable})
  reports.append({"mission":mission,"targets":g.resource_nodes.size()+g.sites.size(),"unreachable":unreachable,"wall_solid":g.nav.is_point_solid(Vector2i(-25,-7)),"reachable_cells":reachable.size()})
  for side in [0,1,2]:
   var raw=Vector3(-28,0,-7) if side==0 else Vector3(0,0,-28) if side==1 else Vector3(28,0,-7)
   var fixed=g.city_ruin_layout.correct_spawn(g.nav,raw,side)
   if not fixed.is_finite() or g.nav.is_point_solid(Vector2i(roundi(fixed.x),roundi(fixed.z))):failures.append("blocked entry mission%d side%d"%[mission,side])
  g.wave=3;g.spawn_wave()
  var spawn_count=g.enemies.size();var state_before=str(g.rng.state)
  if g.save_checkpoint(false)!=OK or not g.load_checkpoint():failures.append("save/load failure")
  if g.enemies.size()!=spawn_count or str(g.rng.state)!=state_before:failures.append("save/load enemy count or rng mismatch")
  if not g.city_ruin_layout.entries_available([0,1,2]):failures.append("entry cache missing afterload")
  g.free();await process_frame
 print("CITY_ROUTE_REPORT ",JSON.stringify(reports));print("CITY_ROUTE_FAILURES ",JSON.stringify(failures));quit(0 if failures.is_empty() else 1)
