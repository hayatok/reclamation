extends Control
## Touch presentation only. The main game keeps command availability, costs,
## selected producers, queues, upgrade effects, save state and all callbacks.
## Coordinates are CSS-sized logical viewport units; never multiply by DPR.
const Deck=preload("res://command_deck.gd")
const MobileGroups=preload("res://mobile_groups.gd")
const PALE=Color("eee6d1")
const AMBER=Color("d2b573")
const MUTED=Color("b8bba6")
const GAP=4.0
const TARGET=48.0
var host:Node
var safe_insets=Vector4.ZERO # left, top, right, bottom in logical CSS units
var safe_rect=Rect2()
var touch_mode:int=0
var append_orders:bool=false
var top:Panel
var dock:Panel
var goal:Button
var alert:Button
var selection:Button
var queue_text:Label
var mode_text:Label
var notice:Label
var resource_cells:Dictionary={}
var range_button:Button
var order_button:Button
var append_button:Button
var cancel_button:Button
var pause_button:Button
var growth_button:Button
var idle_button:Button
var menu_button:Button
var popup:PanelContainer
var popup_previous_pause:bool=false
var grid_home:Node
var map_home:Node
var grid_area=Rect2()
var map_area=Rect2()
var fitted_panels:Dictionary={}
var last_size=Vector2.ZERO
var last_grid_count:int=-1
var ui_rects:Array[Rect2]=[]
var portrait:bool=false
var compact_landscape:bool=false

func setup(game:Node)->void:
 host=game
 name="MobileHUD"
 set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 mouse_filter=Control.MOUSE_FILTER_IGNORE
 process_priority=100 # Sync after main._process updates source labels/states.
 grid_home=host.command_grid.get_parent()
 map_home=host.minimap.get_parent()
 top=_panel();dock=_panel()
 for key in ["food","salvage","parts","population","ammo","power"]:
  var cell=Control.new();top.add_child(cell);cell.mouse_filter=Control.MOUSE_FILTER_IGNORE
  var title=_label({"food":"食料","salvage":"廃材","parts":"部品","population":"人口","ammo":"弾薬","power":"電力"}[key],11,MUTED)
  var value=_label("",17,PALE)
  cell.add_child(title);cell.add_child(value)
  resource_cells[key]={"root":cell,"title":title,"value":value}
 idle_button=_button("待機",func():host.select_idle_worker(),top)
 growth_button=_button("成長",func():host.open_growth_choices(),top)
 pause_button=_button("停止",func():host.toggle_pause(),top)
 menu_button=_button("メニュー",func():host.show_options(),top)
 goal=_button("",_show_objectives,self);goal.alignment=HORIZONTAL_ALIGNMENT_LEFT
 alert=_button("",func():host.focus_building_attack(),self)
 alert.add_theme_color_override("font_color",Color("f0b18c"))
 selection=_button("",_show_selection,dock);selection.alignment=HORIZONTAL_ALIGNMENT_LEFT
 selection.add_theme_font_size_override("font_size",13)
 queue_text=_label("",12,AMBER);dock.add_child(queue_text)
 mode_text=_label("",12,AMBER);dock.add_child(mode_text)
 range_button=_button("範囲",func():_set_mode(1),dock)
 order_button=_button("命令",func():_set_mode(2),dock)
 append_button=_button("追加",func():_set_append(not append_orders),dock)
 cancel_button=_button("取消",_cancel,dock)
 for control in [host.command_grid,host.minimap]:control.reparent(dock,false)
 host.command_grid.add_theme_constant_override("h_separation",GAP)
 host.command_grid.add_theme_constant_override("v_separation",GAP)
 host.minimap.custom_minimum_size=Vector2.ZERO
 host.minimap.clip_contents=true
 host.minimap.tooltip_text="タップで視点移動 / 命令モードでは指示"
 notice=_label("",15,AMBER);add_child(notice)
 notice.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
 notice.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
 get_viewport().size_changed.connect(_layout)
 _layout()
 sync()

func set_safe_insets(value:Vector4)->void:
 if safe_insets==value:return
 safe_insets=value
 _layout()

func set_touch_state(mode:int,append:bool)->void:
 touch_mode=mode;append_orders=append
 _update_mode()

func has_open_popup()->bool:
 return is_instance_valid(popup) and not popup.is_queued_for_deletion()

func ui_blocks()->Array[Rect2]:
 # A modal blocks the whole viewport, including its dimmed surround. Main's
 # gesture adapter also checks its own active-card/title/pause panel state.
 if _modal_open():return [Rect2(Vector2.ZERO,size)]
 return ui_rects.duplicate()

func is_over_ui(point:Vector2)->bool:
 for rect in ui_blocks():
  if rect.has_point(point):return true
 return false

func _process(_delta:float)->void:
 if not is_instance_valid(host):return
 sync()

func sync()->void:
 if not is_instance_valid(host):return
 if size!=last_size:_layout()
 for part in host.hud_parts:part.hide()
 host.center_notice.hide();host.combo_label.hide();host.building_attack_button.hide()
 var playing:bool=not host.title_open and not host.ended
 top.visible=playing;dock.visible=playing;goal.visible=playing
 alert.visible=playing and not host.building_attack_alerts.current.is_empty()
 notice.visible=playing and not _modal_open()
 notice.text=_touch_words(host.center_notice.text)
 for key in resource_cells:
  var cell:Dictionary=resource_cells[key]
  cell.value.text=host.hud_counters[key].value.text.replace(" ","")
  if key=="power":cell.value.text=cell.value.text.replace(".0","")
  cell.value.modulate=host.hud_counters[key].value.get_theme_color("font_color")
  if key=="ammo":
   cell.title.text={"消費超過":"弾薬減少","予備弾使用":"予備弾使用"}.get(host.hud_counters.ammo.caption.text,"弾薬")
   cell.title.modulate=host.hud_counters.ammo.caption.get_theme_color("font_color")
  if key in ["food","salvage","parts"]:
   cell.title.text={"food":"食","salvage":"廃","parts":"部"}[key]+" · "+host.hud_counters[key].assigned.text
 pause_button.text="再開" if host.paused else "停止"
 idle_button.text=host.idle_worker_button.text.replace("待機 ","待機\n")
 idle_button.disabled=host.idle_worker_button.disabled
 var count:int=host.pending_upgrade_levels.size()
 growth_button.text="強化 %d"%count if count>0 else "Lv.%d"%host.level
 growth_button.disabled=count==0
 selection.text="選択・詳細"
 queue_text.text=_touch_words(host.queue_caption.text)
 if queue_text.text.is_empty():queue_text.text=host.command_heading.text
 queue_text.tooltip_text=host.queue_caption.tooltip_text
 var instruction:String=_touch_words(host.guide.text)
 if instruction.is_empty():instruction="発展段階 "+["I","II","III"][clampi(host.settlement_age-1,0,2)]
 goal.text="目標  "+instruction+"  ›"
 alert.text=host.building_attack_button.text
 alert.disabled=host.building_attack_button.disabled
 _update_mode()
 if host.command_grid.get_child_count()!=last_grid_count:_layout()
 else:
  for child in host.command_grid.get_children():
   if not child.has_meta("mobile_tile"):_fit_commands();break
 for child in host.command_grid.get_children():
  if child.has_meta("command_detail"):
   var detail:Label=child.get_meta("command_detail")
   detail.text=_touch_words(detail.text)
 for child in host.command_grid.get_children():
  var detail=child.get_node_or_null("CommandContent/CommandDetail")
  if detail!=null:
   detail.text=_touch_words(detail.text)
   if compact_landscape:detail.text=detail.text.replace("が必要","")
 _adapt_modals()
 # Main clears and recreates contextual buttons; the grid remains the same
 # live object and every press retains the original source callback.

func _layout()->void:
 if not is_instance_valid(top):return
 last_size=size
 var left=maxf(0,safe_insets.x)+6
 var upper=maxf(0,safe_insets.y)+4
 var right=maxf(0,safe_insets.z)+6
 var lower=maxf(0,safe_insets.w)+4
 safe_rect=Rect2(Vector2(left,upper),Vector2(maxf(280,size.x-left-right),maxf(260,size.y-upper-lower)))
 portrait=safe_rect.size.x<safe_rect.size.y
 compact_landscape=not portrait and safe_rect.size.y<360 and safe_rect.size.x>=640
 var w:float=safe_rect.size.x
 var top_h:float=96 if portrait else 48
 _rect(top,Rect2(safe_rect.position,Vector2(w,top_h)))
 var action_width:float=54
 var resources_width:float=w if portrait else w-action_width*4-8
 var resource_width:float=resources_width/6.0
 var index:int=0
 for key in ["food","salvage","parts","population","ammo","power"]:
  var cell:Dictionary=resource_cells[key]
  _rect(cell.root,Rect2(Vector2(index*resource_width+4,0),Vector2(resource_width-4,48)))
  _rect(cell.title,Rect2(Vector2(0,1),Vector2(resource_width-5,19)))
  _rect(cell.value,Rect2(Vector2(0,19),Vector2(resource_width-5,26)))
  cell.value.add_theme_font_size_override("font_size",12 if key=="power" and resource_width<68 else 17)
  index+=1
 var buttons=[idle_button,growth_button,pause_button,menu_button]
 for i in buttons.size():
  _rect(buttons[i],Rect2(Vector2(i*(w/4.0) if portrait else resources_width+8+i*action_width,48 if portrait else 0),Vector2(w/4.0-4 if portrait else action_width-4,48)))
 var columns:int=2 if portrait else 8 if compact_landscape else 4
 var row_count:int=4 if portrait else clampi(ceili(host.command_grid.get_child_count()/float(columns)),1,2)
 var dock_h:float=48+4+row_count*52+(row_count-1)*GAP+(52 if portrait else 0)
 if not portrait and not compact_landscape:dock_h=maxf(116,dock_h)
 var dock_y:float=safe_rect.end.y-dock_h
 _rect(dock,Rect2(Vector2(safe_rect.position.x,dock_y),Vector2(w,dock_h)))
 var tools_width:float=4*52
 var selection_width:float=w-tools_width-8
 _rect(selection,Rect2(Vector2(4,0),Vector2(selection_width,48)))
 for i in 4:
  _rect([range_button,order_button,append_button,cancel_button][i],Rect2(Vector2(w-tools_width+i*52,0),Vector2(48,48)))
 if portrait:
  map_area=Rect2(Vector2(4,52),Vector2(48,48))
  _rect(queue_text,Rect2(Vector2(60,52),Vector2(w-64,22)))
  _rect(mode_text,Rect2(Vector2(60,76),Vector2(w-64,22)))
  grid_area=Rect2(Vector2(4,104),Vector2(w-8,dock_h-104))
 else:
  var map_size:float=64 if row_count==1 else 104
  map_area=Rect2(Vector2(4,52),Vector2(map_size,map_size))
  # Queue/status sits inside the selection header, never underneath tiles.
  selection.add_theme_font_size_override("font_size",13)
  selection.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
  _rect(queue_text,Rect2(Vector2(116,29),Vector2(maxf(40,selection_width-118),18)))
  _rect(mode_text,Rect2(Vector2(116,4),Vector2(maxf(40,selection_width-118),20)))
  selection.alignment=HORIZONTAL_ALIGNMENT_LEFT
  # Leave the right half of the selection header for queue/mode text.
  selection.add_theme_constant_override("outline_size",0)
  grid_area=Rect2(Vector2(map_size+12,52),Vector2(w-map_size-16,row_count*52))
  _rect(selection,Rect2(Vector2(4,0),Vector2(108,48)))
 if compact_landscape:
  map_area=Rect2(Vector2(4,0),Vector2(48,48))
  _rect(selection,Rect2(Vector2(56,0),Vector2(90,48)))
  _rect(queue_text,Rect2(Vector2(154,29),Vector2(maxf(40,w-tools_width-166),18)))
  _rect(mode_text,Rect2(Vector2(154,4),Vector2(maxf(40,w-tools_width-166),20)))
  grid_area=Rect2(Vector2(4,52),Vector2(w-8,52))
 host.command_grid.columns=columns
 _rect(host.command_grid,grid_area)
 _rect(host.minimap,map_area)
 var goal_w:float=minf(w,420)
 _rect(goal,Rect2(Vector2(safe_rect.position.x,safe_rect.position.y+top_h+4),Vector2(goal_w,44)))
 _rect(alert,Rect2(Vector2(safe_rect.end.x-minf(w,310),safe_rect.position.y+top_h+52),Vector2(minf(w,310),44)))
 _rect(notice,Rect2(Vector2(safe_rect.position.x,safe_rect.position.y+top_h+52),Vector2(w,46)))
 ui_rects=[top.get_global_rect(),dock.get_global_rect(),goal.get_global_rect()]
 if alert.visible:ui_rects.append(alert.get_global_rect())
 _fit_commands()
 for id in fitted_panels:
  var item:Dictionary=fitted_panels[id]
  if is_instance_valid(item.get("scroll")):_fit_scroll(item.scroll)
 if is_instance_valid(popup):_fit_scroll(popup.get_meta("scroll"))

func _fit_commands()->void:
 var width:float=(grid_area.size.x-(host.command_grid.columns-1)*GAP)/host.command_grid.columns
 for child in host.command_grid.get_children():
  if child is Button:_compact_command(child,width,compact_landscape)
 last_grid_count=host.command_grid.get_child_count()
 host.command_grid.queue_sort()
 _settle_grid.call_deferred()

func _settle_grid()->void:
 if not is_instance_valid(host):return
 _rect(host.command_grid,grid_area)
 host.command_grid.queue_sort()

static func _compact_command(button:Button,width:float,compact:bool=false)->void:
 button.set_meta("mobile_tile",true)
 button.custom_minimum_size=Vector2(width,50)
 button.size=Vector2(width,50)
 var content:Control=button.get_node_or_null("CommandContent")
 if not content:return
 var icon:TextureRect=content.get_node("ActionIcon")
 icon.position=Vector2(6,4);icon.size=Vector2(22,22);icon.visible=not compact
 var title:Label=content.get_node("ActionTitle")
 title.add_theme_font_size_override("font_size",13 if compact else 14)
 title.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
 title.position=Vector2(6 if compact else 33,1);title.size=Vector2(width-(12 if compact else 39),25)
 content.get_node("HotkeyChip").hide()
 var costs:HBoxContainer=content.get_node("ResourceCosts")
 costs.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
 costs.position=Vector2(7,27);costs.size=Vector2(width-14,20)
 costs.add_theme_constant_override("separation",4)
 for token in costs.get_children():
  token.add_theme_constant_override("separation",1)
  for label in token.get_children():label.add_theme_font_size_override("font_size",12)
 var detail:Label=content.get_node("CommandDetail")
 detail.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
 detail.position=Vector2(7,26);detail.size=Vector2(width-14,22)
 detail.add_theme_font_size_override("font_size",12)
 detail.text=_touch_words(detail.text)

func _update_mode()->void:
 if not is_instance_valid(range_button):return
 range_button.button_pressed=touch_mode==1
 order_button.button_pressed=touch_mode==2
 append_button.button_pressed=append_orders
 range_button.text="範囲✓" if touch_mode==1 else "範囲"
 order_button.text="命令✓" if touch_mode==2 else "命令"
 append_button.text="追加✓" if append_orders else "追加"
 var building:bool=not host.build_mode.is_empty()
 cancel_button.disabled=touch_mode==0 and not append_orders and not building and not host.attack_move and not host.escort_targeting
 mode_text.text="護衛先の味方をタップ" if host.escort_targeting else "範囲をドラッグ" if touch_mode==1 else "指示先をタップ" if touch_mode==2 or host.attack_move else "配置先をタップ" if building else host.selection_info.text.replace("\n"," · ")
 if append_orders:mode_text.text+=(" · " if not mode_text.text.is_empty() else "")+("連続建設" if building else "追加予約")
 # Rebuild the small rect list because attack alerts can appear after layout.
 ui_rects=[top.get_global_rect(),dock.get_global_rect(),goal.get_global_rect()]
 if alert.visible:ui_rects.append(alert.get_global_rect())

func _set_mode(value:int)->void:
 if host.has_method("touch_set_mode"):host.touch_set_mode(0 if touch_mode==value else value)
func _set_append(value:bool)->void:
 if host.has_method("touch_set_append"):host.touch_set_append(value)
func _cancel()->void:
 if host.has_method("touch_cancel"):host.touch_cancel()

func _modal_open()->bool:
 if is_instance_valid(popup):return true
 for panel in [host.title_panel,host.options_panel,host.choice_panel,host.route_panel,host.dismantle_panel,host.modal]:
  if is_instance_valid(panel) and panel.is_visible_in_tree() and not panel.is_queued_for_deletion():return true
 return false

func _show_objectives()->void:
 var body=_open_popup("作戦 %02d · %s"%[host.campaign_state.current+1,host.mission.title.substr(4)])
 if body==null:return
 _body_text(body,_touch_words(host.guide.text),17)
 _body_text(body,host.objective.text+"\n"+host.status.text+"\n"+host.core_bar.tooltip_text,14)
 _button("発電所へ",func():_close_popup();host.assign_site("generator"),body)
 if host.mission.mode!="assault":_button(host.mission.facility+"へ",func():_close_popup();host.assign_site("pump"),body)
 if not host.generator_button.disabled:_button(host.generator_button.text,func():host.toggle_generator();_close_popup(),body)
 if host.mission_action_button.visible:_button(host.mission_action_button.text,func():_close_popup();host.mission_action(),body)
 if host.convoy_pause_button.visible:_button(host.convoy_pause_button.text,func():host.toggle_convoy_stop();_close_popup(),body)
 _button("閉じる",_close_popup,body)

func _show_selection(replace_current:bool=false)->void:
 var body=_open_popup(host.selection_info.text.replace("\n"," · "),replace_current)
 if body==null:return
 var selectors=HBoxContainer.new();body.add_child(selectors)
 selectors.add_theme_constant_override("separation",6)
 for entry in [["本部",func():_close_popup();host.select_headquarters()],["全戦闘員",func():_close_popup();host.select_guards()],["全作業員",func():_close_popup();host.select_workers()]]:
  var shortcut=_button(entry[0],entry[1],selectors)
  shortcut.size_flags_horizontal=Control.SIZE_EXPAND_FILL
 MobileGroups.add_to_selection(self,body)
 _body_text(body,_touch_words(host.selection_info.tooltip_text+"\n"+host.supply_status.text+"\n"+host.supply_status.tooltip_text),15)
 if host.current_supply_feedback.get("active",false) and host.inspected.get("kind","")!="factory" and not host.supply_status.text.contains(host.current_supply_feedback.context):
  _body_text(body,host.current_supply_feedback.context,15,AMBER)
 _body_text(body,_touch_words(host.queue_caption.text+"\n"+host.command_detail.text),14)
 if host.can_dismantle(host.inspected):_button("この施設を解体…",func():_close_popup();host.request_dismantle(),body)
 if host.context_button.visible:_button(host.context_button.text,func():host.toggle_inspected();_close_popup(),body)
 var zoom=HBoxContainer.new();body.add_child(zoom)
 zoom.add_theme_constant_override("separation",6)
 for entry in [["拡大 +",-6.0],["縮小 −",6.0]]:
  var step:float=entry[1]
  var zoom_button=_button(entry[0],func():host.camera.size=clampf(host.camera.size+step,26,85);_close_popup(),zoom)
  zoom_button.size_flags_horizontal=Control.SIZE_EXPAND_FILL
 var priced=host.context_actions.filter(func(action):return not action.cost.is_empty())
 if not priced.is_empty():
  var costs_body=VBoxContainer.new()
  var cost_toggle=_button("建設・生産の費用を見る",func():costs_body.visible=not costs_body.visible,body)
  body.add_child(costs_body);costs_body.hide()
  for action in priced:
   var title_label=action.button.get_node_or_null("CommandContent/ActionTitle")
   var title_text:String=title_label.text if title_label!=null else str(action.kind)
   _body_text(costs_body,title_text+"\n"+_touch_words(action.button.tooltip_text),14)
 _button("閉じる",_close_popup,body)

func _open_popup(title:String,replace_current:bool=false)->VBoxContainer:
 var scroll:ScrollContainer
 if replace_current and has_open_popup():
  # Navigate inside one owned modal: retain the first pause snapshot and the
  # v0.37 safe-area/scroll setup instead of stacking a second popup.
  scroll=popup.get_meta("scroll")
  scroll.scroll_vertical=0
  for child in scroll.get_children():
   scroll.remove_child(child)
   child.queue_free()
 else:
  if _modal_open():return null
  popup_previous_pause=host.paused;host.paused=true
  _cancel()
  popup=PanelContainer.new();host.root_ui.add_child(popup)
  popup.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
  popup.add_theme_stylebox_override("panel",_surface(Color("141a17f5")))
  scroll=_new_scroll(popup)
  popup.set_meta("scroll",scroll)
 var body=VBoxContainer.new();scroll.add_child(body)
 body.mouse_filter=Control.MOUSE_FILTER_PASS
 body.size_flags_horizontal=Control.SIZE_EXPAND_FILL
 body.add_theme_constant_override("separation",8)
 _body_text(body,title,22)
 return body

func _close_popup()->void:
 if not has_open_popup():return
 popup.hide();popup.queue_free()
 popup=null;host.paused=popup_previous_pause

func _adapt_modals()->void:
 for entry in [[host.title_panel,"title"],[host.options_panel,"options"],[host.choice_panel,"cards"],[host.route_panel,"generic"],[host.dismantle_panel,"generic"],[host.modal,"result"]]:
  if not is_instance_valid(entry[0]):continue
  var panel:Control=entry[0]
  if panel.is_queued_for_deletion() or fitted_panels.has(panel.get_instance_id()):continue
  var kind:String=entry[1]
  if kind=="cards":_adapt_cards(panel)
  elif kind=="title":_adapt_title(panel)
  else:_adapt_panel(panel,kind)

func _adapt_title(panel:Control)->void:
 var columns=panel.find_children("*","VBoxContainer",true,false)
 if columns.is_empty():return
 var body:VBoxContainer=columns[0]
 var scroll=_new_scroll(panel)
 body.reparent(scroll,false)
 body.custom_minimum_size=Vector2.ZERO
 body.size_flags_horizontal=Control.SIZE_EXPAND_FILL
 body.add_theme_constant_override("separation",6)
 _relax_content(body)
 for child in body.get_children():
  if child is Label:
   if child.text=="RECLAMATION":child.add_theme_font_size_override("font_size",36)
   elif "左ドラッグ" in child.text:child.text="タップで選択・指示 / ドラッグで視点移動 / 2本指でズーム"
 fitted_panels[panel.get_instance_id()]={"scroll":scroll}

func _adapt_panel(panel:Control,kind:String)->void:
 var columns=panel.find_children("*","VBoxContainer",true,false)
 if columns.is_empty():return
 var body:VBoxContainer=columns[0]
 # The ending panel stays translucent over its source aftermath scene.
 # Retain the source save-status and retry controls and their callbacks.
 var scroll=_new_scroll(panel)
 body.reparent(scroll,false)
 body.custom_minimum_size=Vector2.ZERO
 body.size_flags_horizontal=Control.SIZE_EXPAND_FILL
 body.add_theme_constant_override("separation",8)
 _relax_content(body)
 if kind=="result":_reflow_result_rows(body)
 if kind=="options":
  var help=body.get_node_or_null("ControlsHelp")
  if help:
   help.text="タップ：選択・移動・作業・攻撃\nドラッグ：視点移動 / 2本指：ズーム\n範囲：囲んで選択 / 命令：味方への護衛・修理\n追加：作業予約・連続建設 / 取消：指示モード解除"
   help.hide()
   var help_button=_button("タッチ操作を見る",func():help.visible=not help.visible,body)
   body.move_child(help_button,body.get_child_count()-2)
  var restart=_button("この作戦をやり直す…",_confirm_restart,body)
  body.move_child(restart,2)
 # Original wrappers may enforce a desktop minimum even after content moved.
 for child in panel.get_children():
  if child!=scroll and child!=scroll.get_parent() and child is Container:child.hide()
 panel.custom_minimum_size=Vector2.ZERO
 panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 if kind=="result":
  if host.result_won:scroll.set_meta("mobile_result",true)
  scroll.add_theme_stylebox_override("panel",_surface(Color("20261ff2")))
  _fit_scroll(scroll)
 fitted_panels[panel.get_instance_id()]={"scroll":scroll}

func _reflow_result_rows(body:VBoxContainer)->void:
 # Auto-wrapping labels/buttons have tiny minimum widths. The desktop HBoxes
 # let the expanding title take all space and collapse stats/actions to 1/20px.
 # Replace only those rows, preserving the original nodes and callbacks.
 for old_row in body.get_children():
  if not old_row is HBoxContainer:continue
  var children=old_row.get_children()
  if children.is_empty():continue
  var heading:bool=children.all(func(child):return child is Label)
  var actions:bool=children.all(func(child):return child is Button)
  if not heading and not actions:continue
  var row:Container=VBoxContainer.new() if heading else GridContainer.new()
  body.add_child(row);body.move_child(row,old_row.get_index())
  row.size_flags_horizontal=Control.SIZE_EXPAND_FILL
  if heading:row.add_theme_constant_override("separation",4)
  else:
   row.set_meta("mobile_result_actions",true)
   row.columns=1 if portrait else children.size()
   row.add_theme_constant_override("h_separation",8)
   row.add_theme_constant_override("v_separation",8)
  for child in children:
   child.reparent(row,false)
   child.size_flags_horizontal=Control.SIZE_EXPAND_FILL
   if actions:child.custom_minimum_size=Vector2(44,48)
  old_row.hide();old_row.queue_free()

 # Defeat has no aftermath scene to preserve. Keep retry actions together
 # so the added factual recap does not push them below a short landscape sheet.
 if not host.result_won:
  var actions=body.get_children().filter(func(child):return child is Button)
  if actions.size()>1:
   var row=GridContainer.new();body.add_child(row);body.move_child(row,actions[0].get_index())
   row.size_flags_horizontal=Control.SIZE_EXPAND_FILL
   row.set_meta("mobile_result_actions",true);row.columns=1 if portrait else actions.size()
   row.add_theme_constant_override("h_separation",8);row.add_theme_constant_override("v_separation",8)
   for action in actions:
    action.reparent(row,false);action.size_flags_horizontal=Control.SIZE_EXPAND_FILL
    action.custom_minimum_size=Vector2(44,48)

func _confirm_restart()->void:
 # Deliberate in-game confirmation protects the current unsaved operation.
 var panel:Control=host.options_panel
 if not is_instance_valid(panel):return
 var data:Dictionary=fitted_panels.get(panel.get_instance_id(),{})
 var scroll:ScrollContainer=data.get("scroll")
 if not is_instance_valid(scroll):return
 for child in scroll.get_children():child.hide()
 var body=VBoxContainer.new();scroll.add_child(body)
 body.size_flags_horizontal=Control.SIZE_EXPAND_FILL;body.add_theme_constant_override("separation",10)
 _body_text(body,"この作戦を最初からやり直す？",22)
 _body_text(body,"現在の作戦の進行をリセットします。",15)
 _button("最初から開始",func():host.start_mission(host.campaign_state.current),body)
 _button("やめる",func():
  body.queue_free()
  for child in scroll.get_children():
   if child!=body:child.show()
 ,body)

func _adapt_cards(panel:Control)->void:
 for child in panel.get_children():child.hide()
 var scroll=_new_scroll(panel)
 var body=VBoxContainer.new();scroll.add_child(body)
 body.size_flags_horizontal=Control.SIZE_EXPAND_FILL
 body.add_theme_constant_override("separation",6)
 _body_text(body,"生存者の成長 · LV %02d / 未選択 %d"%[int(host.pending_upgrade_levels[0]),host.pending_upgrade_levels.size()],20)
 var card_row=GridContainer.new();body.add_child(card_row)
 card_row.columns=1 if portrait else 3
 card_row.add_theme_constant_override("h_separation",8)
 card_row.add_theme_constant_override("v_separation",8)
 card_row.size_flags_horizontal=Control.SIZE_EXPAND_FILL
 for i in host.cards.size():
  var data:Dictionary=host.cards[i]
  var card=PanelContainer.new();card_row.add_child(card)
  card.size_flags_horizontal=Control.SIZE_EXPAND_FILL
  card.add_theme_stylebox_override("panel",_surface(Color("30372cfb")))
  var content=VBoxContainer.new();card.add_child(content)
  content.add_theme_constant_override("separation",4)
  _body_text(content,data.name,19)
  _body_text(content,data.desc,14)
  _body_text(content,host.upgrade_preview(data),13,AMBER)
  var route:String=host.upgrade_route_text(data.id)
  if not route.is_empty():_body_text(content,route,12,MUTED)
  var spacer=Control.new();spacer.size_flags_vertical=Control.SIZE_EXPAND_FILL;content.add_child(spacer)
  var choose=_button("この強化を採用",func():host.choose_upgrade(i),content)
  choose.custom_minimum_size.y=48
 var actions=HBoxContainer.new();body.add_child(actions)
 actions.add_theme_constant_override("separation",8)
 var reroll=_button("候補更新 · 残り%d"%host.rerolls,func():host.reroll_cards(),actions)
 reroll.disabled=host.rerolls<=0;reroll.size_flags_horizontal=Control.SIZE_EXPAND_FILL
 var later=_button("あとで選ぶ",func():host.postpone_growth_choice(),actions)
 later.size_flags_horizontal=Control.SIZE_EXPAND_FILL
 fitted_panels[panel.get_instance_id()]={"scroll":scroll,"cards":card_row}
 _fit_card_columns(card_row)

func _fit_card_columns(row:GridContainer)->void:
 row.columns=1 if portrait else 3
 var width:float=(safe_rect.size.x-24-(row.columns-1)*8)/row.columns
 for child in row.get_children():child.custom_minimum_size=Vector2(width,214 if not portrait else 190)

func _relax_content(node:Control)->void:
 node.custom_minimum_size.x=0
 if node is Label:
  node.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
  node.add_theme_font_size_override("font_size",mini(22,node.get_theme_font_size("font_size")))
  node.text=_touch_words(node.text)
 if node is BaseButton:
  node.custom_minimum_size=Vector2(0,48)
  node.add_theme_font_size_override("font_size",15)
  if node is Button:node.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
 if node is BoxContainer:node.add_theme_constant_override("separation",8)
 for child in node.get_children():
  if child is Control:_relax_content(child)

func _new_scroll(parent:Control)->ScrollContainer:
 var scroll=ScrollContainer.new()
 if parent is Container:
  # A Container would overwrite scroll.position/size. A plain Control makes
  # the CSS safe rectangle authoritative without double-applying margins.
  if parent is PanelContainer:
   var skin=parent.get_theme_stylebox("panel").duplicate()
   skin.set_content_margin_all(0)
   parent.add_theme_stylebox_override("panel",skin)
  var stage=Control.new();parent.add_child(stage)
  stage.mouse_filter=Control.MOUSE_FILTER_IGNORE
  stage.add_child(scroll)
 else:parent.add_child(scroll)
 scroll.name="MobileScroll"
 scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
 scroll.vertical_scroll_mode=ScrollContainer.SCROLL_MODE_AUTO
 scroll.follow_focus=true
 scroll.scroll_deadzone=12
 scroll.child_entered_tree.connect(func(child):_allow_scroll_drag.call_deferred(child))
 scroll.mouse_filter=Control.MOUSE_FILTER_STOP
 _fit_scroll(scroll)
 return scroll

func _fit_scroll(scroll:ScrollContainer)->void:
 if not is_instance_valid(scroll):return
 for row in scroll.find_children("*","GridContainer",true,false):
  if row.has_meta("mobile_result_actions"):row.columns=1 if portrait else row.get_child_count()
 # Full-screen modal parents use root coordinates. Safe area applied once.
 scroll.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
 scroll.position=safe_rect.position+Vector2(6,6)
 scroll.size=safe_rect.size-Vector2(12,12)
 if scroll.has_meta("mobile_result"):
  scroll.size.y=minf(scroll.size.y,320 if portrait else 220)
  scroll.position.y=safe_rect.end.y-scroll.size.y-6
 scroll.custom_minimum_size=Vector2.ZERO
 for data in fitted_panels.values():
  if data.get("scroll")==scroll and is_instance_valid(data.get("cards")):_fit_card_columns(data.cards)

func _panel()->Panel:
 var panel=Panel.new();add_child(panel)
 panel.add_theme_stylebox_override("panel",_surface(Color("1c251ffa")))
 panel.mouse_filter=Control.MOUSE_FILTER_STOP
 return panel

func _button(text:String,callback:Callable,parent:Node)->Button:
 var button=Button.new();parent.add_child(button)
 button.text=text;button.focus_mode=Control.FOCUS_NONE
 button.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
 button.custom_minimum_size=Vector2(44,48)
 button.add_theme_font_size_override("font_size",13)
 button.add_theme_color_override("font_color",PALE)
 for state in ["normal","hover","pressed","disabled","focus"]:
  button.add_theme_stylebox_override(state,Deck._command_surface(state))
 button.pressed.connect(callback)
 return button

func _label(text:String,font_size:int,color:Color)->Label:
 var label=Label.new();label.text=text
 label.add_theme_font_size_override("font_size",font_size)
 label.add_theme_color_override("font_color",color)
 label.mouse_filter=Control.MOUSE_FILTER_IGNORE
 label.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
 label.clip_text=true;label.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
 return label

func _body_text(parent:Node,text:String,font_size:int=15,color:Color=PALE)->Label:
 var label=_label(text.strip_edges(),font_size,color);parent.add_child(label)
 label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
 label.size_flags_horizontal=Control.SIZE_EXPAND_FILL
 label.clip_text=false;label.text_overrun_behavior=TextServer.OVERRUN_NO_TRIMMING
 return label

static func _rect(control:Control,value:Rect2)->void:
 control.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
 control.position=value.position;control.size=value.size

static func _surface(color:Color)->StyleBoxFlat:
 var box=StyleBoxFlat.new();box.bg_color=color;box.border_color=Color("6b7256")
 box.set_border_width_all(1);box.set_content_margin_all(8)
 return box

static func _touch_words(text:String)->String:
 return text.replace("Shift+右クリック","追加を有効にしてタップ").replace("Shift+左クリック","追加を有効にして配置").replace("Shift+配置","追加で配置").replace("右クリック","タップ").replace("左クリック","タップ").replace("Spaceで再開","再開で続行").replace("Escで取消","取消で解除").replace("  [Esc]","").replace(" [Tab]","")

func _allow_scroll_drag(node)->void:
 if not is_instance_valid(node):return
 if node is Control and not node is ScrollContainer and node.mouse_filter!=Control.MOUSE_FILTER_IGNORE:
  node.mouse_filter=Control.MOUSE_FILTER_PASS
 for child in node.get_children():_allow_scroll_drag(child)

func cancel_scroll_drag()->void:
 for scroll in host.root_ui.find_children("MobileScroll","ScrollContainer",true,false):
  if is_instance_valid(scroll) and scroll.is_visible_in_tree():
   # Godot's setter cancels its internal touch drag/momentum without moving it.
   scroll.scroll_vertical=scroll.scroll_vertical
