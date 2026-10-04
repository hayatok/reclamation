extends SceneTree
# Focused readable-UI regression. Run in an isolated copy with isolated XDG_DATA_HOME.
const Deck=preload("res://command_deck.gd")
var passed:int=0
var failed:int=0
var g:Node
var checked_glyphs:int=0
var font_failures:Array[String]=[]
func _initialize():call_deferred("run")
func check(ok:bool,what:String):
 if ok:passed+=1;print("PASS ",what)
 else:failed+=1;print("FAIL ",what)
func font_supports(f:Font,c:int)->bool:
 if f.has_char(c):return true
 for fallback in f.fallbacks:
  if font_supports(fallback,c):return true
 return false
func check_text(node:Node,scope:String):
 if node is Control and not node.is_visible_in_tree():return
 var text:String=""
 if node is Label or node is BaseButton:text=node.text
 if not text.is_empty():
  var f:Font=node.get_theme_font("font")
  for i in text.length():
   var c:int=text.unicode_at(i)
   if c in [9,10,13,32]:continue
   checked_glyphs+=1
   if not font_supports(f,c):font_failures.append(scope+"/"+str(node.name)+": "+text[i]+" U+%04X"%c)
 for child in node.get_children():check_text(child,scope)
func choose_units(value:Array):
 g.selected=value;g.inspected={};g.inspected_resource={};g.inspected_site={};g.update_selection()
func choose_building(value:Dictionary):
 g.selected.clear();g.inspected=value;g.inspected_resource={};g.inspected_site={};g.update_selection()
func find_action(kind:String)->Dictionary:
 for action in g.context_actions:
  if action.kind==kind:return action
 return {}
func frames():
 await process_frame
 await process_frame
 await process_frame
func validate_commands(scope:String):
 check(g.command_grid.columns==4,scope+" has 4 columns")
 var grid_rect:Rect2=g.command_grid.get_global_rect()
 var icon_ok:bool=true
 var tile_ok:bool=true
 var content_ok:bool=true
 var labels_ok:bool=true
 for action in g.context_actions:
  var b:Button=action.button
  var rect:Rect2=b.get_global_rect()
  if b.size.y<72 or not grid_rect.grow(.1).encloses(rect):tile_ok=false
  var icon:TextureRect=b.get_meta("command_icon")
  if icon.texture==null or icon.texture.get_width()<=0:icon_ok=false
  var content:Control=b.get_node("CommandContent")
  for child in content.get_children():
   if child is Control and child.visible and not rect.grow(1).encloses(child.get_global_rect()):
    content_ok=false;print("DETAIL bounds ",scope," ",action.kind,"/",child.name," tile=",rect," child=",child.get_global_rect())
  var caption:Label=b.get_meta("command_title_label")
  if caption.text.contains("□") or caption.text.contains("�"):labels_ok=false
  if not b.text.is_empty():labels_ok=false
  check_text(b,scope)
 check(icon_ok,scope+" action icons are loaded textures")
 check(tile_ok,scope+" command tiles respect 72px minimum and grid bounds")
 check(content_ok,scope+" titles, icons, hotkeys and costs stay within tile")
 check(labels_ok,scope+" uses no text icon/replacement glyphs")
func queue_textures()->bool:
 for box in g.queue_icons.get_children():
  if box.get_child_count()==0 or not box.get_child(0) is TextureRect or box.get_child(0).texture==null:return false
 return true
func run():
 root.get_node("Campaign").launch=true;root.get_node("Campaign").current=0;root.get_node("Campaign").muted=true
 g=load("res://main.tscn").instantiate();root.add_child(g);g.set_process(false);g.wave_clock=10000
 await frames()
 print("VIEWPORT ",g.get_viewport().get_visible_rect()," ROOT_UI ",g.root_ui.get_global_rect())
 check(g.command_font.fallbacks.has(g.font),"Command.ttf explicitly falls back to Japanese font")
 check(font_supports(g.command_font,"食".unicode_at(0)),"decorative-font fallback covers Japanese")
 var counters_ok:bool=g.hud_counters.size()==8
 var header_bounds:bool=true
 for kind in g.hud_counters:
  var entry:Dictionary=g.hud_counters[kind]
  var icon:TextureRect=entry.root.get_child(0)
  counters_ok=counters_ok and icon.texture!=null and icon.texture.get_width()>0 and not entry.caption.text.is_empty() and entry.value.get_theme_font_size("font_size")>=23
  if not g.root_ui.get_global_rect().grow(.1).encloses(entry.root.get_global_rect()):header_bounds=false
 check(counters_ok,"all 8 resource SVGs load with Japanese captions and large values")
 check(header_bounds,"all header resources fit logical viewport")
 check(not g.supply_status.text.contains("弾薬") and not g.supply_status.text.contains("電力"),"selection pane does not repeat global ammo/power")
 check_text(g.root_ui,"initial")
 choose_units([]);await frames();validate_commands("empty")
 var workers:Array=g.units.filter(func(u):return u.kind=="worker")
 var guards:Array=g.units.filter(func(u):return u.kind=="guard")
 choose_units([workers[0]]);await frames();validate_commands("worker economy")
 g.worker_build_page="military";g.refresh_context_commands(true);await frames();validate_commands("worker defense")
 choose_units([guards[0]]);await frames();validate_commands("combat")
 choose_units([workers[0],guards[0]]);await frames();validate_commands("mixed")
 g.select_headquarters();await frames();validate_commands("HQ")
 var hq:Dictionary=g.inspected
 g.stockpile={"food":0.0,"salvage":0.0,"parts":0.0};g.refresh_context_commands(true);await frames()
 var worker_action:Dictionary=find_action("worker")
 var wb:Button=worker_action.button
 check(wb.disabled and wb.get_meta("command_cost_row").visible and not wb.get_meta("command_detail").visible,"resource shortage disables training while retaining visible cost")
 check(wb.get_meta("command_shortages")==["food"] and wb.get_meta("command_amount_labels").food.get_theme_color("font_color")==Color("ff9e87"),"missing food amount is highlighted red")
 var before:int=hq.queue.size();g.activate_context_key(KEY_Q)
 check(hq.queue.size()==before,"disabled hotkey cannot queue missing-resource training")
 g.stockpile={"food":2000.0,"salvage":2000.0,"parts":2000.0};g.refresh_context_commands();await frames()
 check(not wb.disabled and wb.get_meta("command_shortages").is_empty(),"refilling stockpile restores training and cost color")
 g.production.queue_unit(hq,"worker");g.refresh_context_commands(true);await frames()
 check(g.queue_icons.get_child_count()==1 and queue_textures() and g.queue_caption.text.contains("作業員") and g.queue_bar.visible,"HQ local production has icon, title and progress")
 g.production.update(3);g.update_queue_display();await frames()
 check(g.queue_bar.value>0 and g.queue_caption.text.contains("残り15秒"),"production progress displays elapsed queue time")
 choose_units([workers[0]]);await frames();check(g.queue_icons.get_child_count()==0,"leaving producer hides its local queue")
 choose_building(hq);await frames();check(g.queue_icons.get_child_count()==1 and queue_textures(),"returning to producer restores its local queue")
 g.production.cancel_last(hq);g.refresh_context_commands(true);await frames();check(g.queue_icons.get_child_count()==0 and not g.queue_bar.visible,"cancelling final job clears queue icon and progress")
 # Queue tests inject known display records, avoiding unrelated tech-tree prerequisites.
 for kind in ["worker","guard","grenade","truck","siegecart"]:
  hq.queue=[{"type":"unit","kind":kind,"remaining":10.0,"duration":20.0}]
  g.update_queue_display();await frames();check(g.queue_icons.get_child_count()==1 and queue_textures(),kind+" queue icon texture loads")
 hq.queue=[]
 for i in 7:hq.queue.append({"type":"unit","kind":"worker","remaining":10.0,"duration":20.0})
 g.update_queue_display();await frames()
 check(g.queue_icons.get_child_count()==5 and g.queue_icons.get_child(4).get_child_count()==2 and g.queue_icons.get_child(4).get_child(1).text=="3","queue overflow condenses remaining 3 jobs")
 hq.queue=[];g.update_queue_display()
 # Prerequisite and runtime production states are visible in local controls.
 g.settlement_age=1;choose_building(hq);await frames()
 var research_button:Button=find_action("research").button
 check(research_button.disabled and not research_button.get_meta("command_cost_row").visible and research_button.get_meta("command_detail").visible and research_button.get_meta("command_detail").text=="前提施設が必要","compound age prerequisites replace cost row with short readable condition")
 var barracks:Dictionary=g.make_building("barracks",Vector3(12,0,20),true)
 choose_building(barracks);await frames();validate_commands("barracks stage I")
 var grenade_button:Button=find_action("grenade").button
 check(grenade_button.disabled and grenade_button.get_meta("command_detail").text=="段階 2 が必要","locked grenade training displays stage requirement")
 g.settlement_age=3;g.refresh_context_commands(true);await frames();validate_commands("barracks stage III")
 var vehicle:Dictionary=g.make_building("vehicle_workshop",Vector3(19,0,18),true)
 vehicle.powered=false;choose_building(vehicle);await frames();validate_commands("vehicle unpowered")
 check(not find_action("truck").button.disabled and find_action("truck").button.get_meta("command_cost_row").visible,"unpowered vehicle still permits prepaid local queue reservations")
 vehicle.powered=true;g.refresh_context_commands(true);await frames();validate_commands("vehicle powered")
 check(g.production.queue_unit(vehicle,"siegecart"),"actual vehicle producer accepts siegecart job")
 g.refresh_context_commands(true);await frames()
 check(g.queue_icons.get_child_count()==1 and queue_textures(),"actual vehicle siegecart queue has a loaded icon")
 vehicle.enabled=false;g.production.update(.1);g.update_queue_display();await frames()
 check(g.queue_caption.text.contains("停止中"),"disabled producer queue shows stopped condition")
 vehicle.enabled=true;vehicle.powered=false;g.production.update(.1);g.update_queue_display();await frames()
 check(g.queue_caption.text.contains("未給電"),"unpowered queue shows missing-power condition")
 vehicle.powered=true;g.production.cancel_last(vehicle)
 hq.queue=[{"type":"unit","kind":"worker","remaining":0.0,"duration":18.0,"population":1,"waiting":"population"}];hq.queue_state="population"
 choose_building(hq);await frames()
 check(g.queue_caption.text.contains("人口上限") and g.queue_bar.value==100,"completed population-blocked queue shows cap and full progress")
 check_text(g.root_ui,"producer states")
 hq.queue=[];g.update_queue_display()
 for was_paused in [false,true]:
  for i in 3:
   g.paused=was_paused;g.show_options();await frames()
   check(g.paused and is_instance_valid(g.options_panel),"menu opens paused (prior=%s cycle=%s)"%[was_paused,i])
   check_text(g.options_panel,"options")
   var e=InputEventKey.new();e.keycode=KEY_ESCAPE;e.pressed=true;g._unhandled_input(e);await frames()
   check(g.paused==was_paused and not is_instance_valid(g.options_panel),"Esc closes menu and preserves pause (prior=%s cycle=%s)"%[was_paused,i])
 # Rapid duplicate open must not orphan a modal or replace the original pause state.
 g.paused=false;var children_before:int=g.root_ui.get_child_count()
 g.show_options();g.show_options();await frames()
 g.close_options();await frames()
 check(g.root_ui.get_child_count()==children_before and not g.paused,"repeated menu open is idempotent and preserves running state")
 check(font_failures.is_empty(),"all visible header, command, cost and menu characters have assigned-font coverage (%d checks)"%checked_glyphs)
 for issue in font_failures:print("DETAIL font ",issue)
 print("V10_UI_SUMMARY passed=%d failed=%d"%[passed,failed])
 g.queue_free();await process_frame;quit(1 if failed else 0)
