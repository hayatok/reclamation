extends SceneTree
func _initialize():call_deferred('run')
func run():
 var output='user://integrated_choice';var auto_exit=false
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with('--out='):output=arg.trim_prefix('--out=')
  if arg=='--auto-exit':auto_exit=true
 DirAccess.make_dir_recursive_absolute('user://settlement_v2')
 var f=FileAccess.open('user://settlement_v2/checkpoint.json',FileAccess.WRITE);f.store_string(FileAccess.get_file_as_string('res://tests/fixtures/earned_critical_factory.json'));f.close()
 var c=root.get_node('Campaign');c.current=1;c.launch=true;c.resume=true;c.muted=true
 var g=load('res://main.tscn').instantiate();root.add_child(g);current_scene=g;g.set_process(false)
 assert(g.open_growth_choices());var offered=g.cards.map(func(d):return d.id);var old=g.upgrades.duplicate(true)
 if g.mobile_enabled:g.mobile_hud.sync()
 for frame in 8:await process_frame
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(output+'.png')
 print('NATIVE_EARNED_CHOICES ',offered,' viewport=',root.get_visible_rect().size)
 if auto_exit:quit();return
 while g.active_card:await process_frame
 var changed=[]
 for key in g.upgrades:
  if g.upgrades[key]!=old.get(key,0):changed.append(key)
 assert(changed.size()==1 and changed[0] in offered)
 print('NATIVE_ARTWORK_CLICK_APPLIED ',changed[0],' rank=',g.upgrades[changed[0]])
 assert(g.save_checkpoint(false)==OK)
 quit()
