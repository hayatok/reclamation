## Developer review: use isolated XDG/user-data directories; writes a fixture checkpoint.
extends SceneTree
var g:Node
var old_map:RefCounted
var swapped=false
var out:String
func _initialize():call_deferred("run")
func run():
 root.window_input.connect(_input)
 out=OS.get_environment("SQUAD_ROUTE_REVIEW_OUTPUT")
 if out.is_empty():out="user://squad_route_review"
 DirAccess.make_dir_recursive_absolute(out)
 DirAccess.make_dir_recursive_absolute("user://settlement_v2")
 var f=FileAccess.open("user://settlement_v2/checkpoint.json",FileAccess.WRITE)
 var fixture=OS.get_environment("SQUAD_ROUTE_FIXTURE")
 f.store_string(FileAccess.get_file_as_string("res://tests/fixtures/freight_scout_3.json" if fixture.is_empty() else fixture));f.close()
 var c=root.get_node("Campaign");c.current=1;c.launch=true;c.resume=true;c.muted=true
 g=load("res://main.tscn").instantiate();root.add_child(g)
 assert(not g.title_open)
 g.paused=true
 if fixture.is_empty():
  g.camera_focus=Vector3(63,0,33);g.camera.size=50
  g.selected=g.units.filter(func(u):return u.kind=="guard" and u.node.position.distance_to(Vector3(63,0,33))<8)
 assert(g.selected.size()==4);g.update_selection();old_map=g.frontier_minimap
 var baseline=OS.get_environment("SQUAD_ROUTE_BASELINE")
 if not baseline.is_empty():
  old_map=ResourceLoader.load(baseline,"Script",ResourceLoader.CACHE_MODE_IGNORE).new();g.frontier_minimap=old_map
 var saved=g.checkpoint_data()
 g.friendly_navigation.begin_frame(0.0,g.units)
 for u in g.selected:g.friendly_navigation.advance(u,g.nav,0.0,1.0)
 assert(saved==g.checkpoint_data(),"Zero-time route reconstruction must preserve checkpoint state")
 await process_frame
 print("SQUAD_NATIVE_READY ",JSON.stringify({"elapsed":g.elapsed,"selected":g.selected.size(),"minimap_position":g.minimap.global_position,"minimap_size":g.minimap.size}))
func _input(event):
 if event is InputEventKey and event.pressed and not event.echo and is_instance_valid(g):
  if event.keycode==KEY_F9:call_deferred("capture")
  if event.keycode==KEY_F10:call_deferred("swap_map")
func capture():
 await RenderingServer.frame_post_draw
 var label="after" if swapped else "before"
 root.get_texture().get_image().save_png(out.path_join(label+".png"))
 var f=FileAccess.open(out.path_join(label+".json"),FileAccess.WRITE);f.store_string(JSON.stringify(g.checkpoint_data()));f.close()
 print("SQUAD_CAPTURE ",label," elapsed=",g.elapsed," selected=",g.selected.size())
func swap_map():
 if not g.paused:push_warning("Pause before changing only the draw helper");return
 var before=g.checkpoint_data();var queries=g.friendly_navigation.total_queries
 if swapped:g.frontier_minimap=old_map;swapped=false
 else:g.frontier_minimap=ResourceLoader.load("res://frontier_minimap.gd","Script",ResourceLoader.CACHE_MODE_IGNORE).new();swapped=true
 g.minimap.queue_redraw()
 await process_frame
 assert(before==g.checkpoint_data(),"Drawing helper must not change game state")
 assert(queries==g.friendly_navigation.total_queries,"Drawing helper must not query paths")
 print("SQUAD_MAP_SWAP_EXACT ",swapped)
