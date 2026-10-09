## Developer review: use isolated XDG/user-data directories; writes a fixture checkpoint.
extends SceneTree
func _initialize():call_deferred("run")
func run():
 var out=OS.get_environment("SQUAD_ROUTE_REVIEW_OUTPUT")
 DirAccess.make_dir_recursive_absolute(out)
 var fixture=OS.get_environment("SQUAD_ROUTE_FIXTURE")
 DirAccess.make_dir_recursive_absolute("user://settlement_v2")
 var f=FileAccess.open("user://settlement_v2/checkpoint.json",FileAccess.WRITE);f.store_string(FileAccess.get_file_as_string(fixture));f.close()
 var c=root.get_node("Campaign");c.current=1;c.launch=true;c.resume=true;c.muted=true
 var g=load("res://main.tscn").instantiate();root.add_child(g);g.paused=true
 assert(not g.title_open and g.mobile_enabled and g.selected.size()==4)
 g.friendly_navigation.begin_frame(0.0,g.units)
 for u in g.selected:g.friendly_navigation.advance(u,g.nav,0.0,1.0)
 for frame in 8:await process_frame
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(out.path_join("mobile_844x390.png"))
 print("SQUAD_MOBILE_LAYOUT ",JSON.stringify({"viewport":root.size,"minimap_size":g.minimap.size,"selected":g.selected.size(),"elapsed":g.elapsed}))
 quit()
