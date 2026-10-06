extends RefCounted
## Touch presentation for the existing ControlGroups slots. No extra saved state.
const Groups=preload("res://control_groups.gd")
const Rules=preload("res://settlement_rules.gd")

static func add_to_selection(hud,body:VBoxContainer)->void:
 hud._body_text(body,"登録グループ",17)
 var grid:GridContainer
 for slot in range(1,10):
  var group:Dictionary=hud.host.control_groups.resolve(slot,hud.host.units,hud.host.buildings)
  if _empty(group):continue
  if grid==null:
   hud._body_text(body,"タップで選択・視点移動",13,hud.MUTED)
   grid=_grid(body)
  var button:Button=_button(hud,"%d\n%s"%[slot,_short_summary(group)],func():_recall(hud,slot),grid)
  button.tooltip_text=_summary(group)
  button.set_meta("mobile_group_recall",slot)
 if grid!=null:grid.columns=mini(3,grid.get_child_count())
 var register:Button=_button(hud,"今の選択を登録…",func():_show_register(hud),body)
 register.set_meta("mobile_group_register",true)
 register.disabled=_empty(_current_group(hud.host))
 if register.disabled:hud._body_text(body,"部隊か味方施設を選ぶと登録できます。",13,hud.MUTED)

static func _show_register(hud)->void:
 var body:VBoxContainer=hud._open_popup("登録先を選ぶ",true)
 if body==null:return
 var current:Dictionary=_current_group(hud.host)
 hud._body_text(body,"今の選択："+_short_summary(current),16)
 hud._body_text(body,"空きはタップで登録。登録済みは変更を確認。",14,hud.MUTED)
 var grid:GridContainer=_grid(body)
 for slot in range(1,10):
  var group:Dictionary=hud.host.control_groups.resolve(slot,hud.host.units,hud.host.buildings)
  var title:String="%d\n空き"%slot if _empty(group) else "%d\n%s"%[slot,_short_summary(group)]
  var button:Button=_button(hud,title,func():_choose_destination(hud,slot),grid)
  button.tooltip_text="空き番号に登録" if _empty(group) else "変更を確認："+_summary(group)
  button.disabled=_empty(current)
  button.set_meta("mobile_group_destination",slot)
 _button(hud,"キャンセル",func():hud._show_selection(true),body)

static func _choose_destination(hud,slot:int)->void:
 if not hud.has_open_popup():return
 var current:Dictionary=_current_group(hud.host)
 if _empty(current):_show_register(hud);return
 var previous:Dictionary=hud.host.control_groups.resolve(slot,hud.host.units,hud.host.buildings)
 if _empty(previous):
  _store(hud,slot)
  return
 _show_overwrite(hud,slot,previous,current)

static func _show_overwrite(hud,slot:int,previous:Dictionary,current:Dictionary)->void:
 var body:VBoxContainer=hud._open_popup("グループ%dを変更しますか？"%slot,true)
 if body==null:return
 hud._body_text(body,"現在の登録\n"+_summary(previous),16)
 hud._body_text(body,"新しい登録\n"+_summary(current),16,hud.AMBER)
 hud._body_text(body,"この番号の登録内容を入れ替えます。",14,hud.MUTED)
 var old_ids:Array=_identity(previous)
 var new_ids:Array=_identity(current)
 var confirm:Button=_button(hud,"この内容で上書き",func():_confirm_overwrite(hud,slot,old_ids,new_ids),body)
 confirm.set_meta("mobile_group_overwrite",slot)
 _button(hud,"キャンセル",func():_show_register(hud),body)

static func _confirm_overwrite(hud,slot:int,old_ids:Array,new_ids:Array)->void:
 if not hud.has_open_popup():return
 var current:Dictionary=_current_group(hud.host)
 if _empty(current):_show_register(hud);return
 var previous:Dictionary=hud.host.control_groups.resolve(slot,hud.host.units,hud.host.buildings)
 # Recheck the exact members shown in the confirmation, even if an external
 # selection or slot change happened while the popup was open.
 if _identity(previous)!=old_ids or _identity(current)!=new_ids:
  if _empty(previous):_show_register(hud)
  else:_show_overwrite(hud,slot,previous,current)
  return
 _store(hud,slot)

static func _store(hud,slot:int)->void:
 if not hud.has_open_popup() or _empty(_current_group(hud.host)):return
 hud.host.assign_control_group(slot)
 hud._close_popup()

static func _recall(hud,slot:int)->void:
 if not hud.has_open_popup():return
 hud._close_popup()
 hud.host.recall_control_group(slot,-1,true)

static func _current_group(host)->Dictionary:
 var result:Dictionary={"units":[],"building":{}}
 var living:Dictionary=Groups.live_lookup(host.units)
 var seen:Dictionary={}
 for unit in host.selected:
  if not Groups.alive(unit):continue
  var id:int=unit.node.get_instance_id()
  if living.has(id) and not seen.has(id):
   seen[id]=true
   result.units.append(living[id])
 if result.units.is_empty() and host.selected.is_empty() and Groups.alive(host.inspected):
  var building_id:int=host.inspected.node.get_instance_id()
  var buildings:Dictionary=Groups.live_lookup(host.buildings)
  if buildings.has(building_id):result.building=buildings[building_id]
 return result

static func _empty(group:Dictionary)->bool:
 return group.units.is_empty() and group.building.is_empty()

static func _identity(group:Dictionary)->Array:
 var ids:Array=[]
 if not group.units.is_empty():
  ids.append("units")
  for unit in group.units:ids.append(unit.node.get_instance_id())
 elif not group.building.is_empty():
  ids.append("building")
  ids.append(group.building.node.get_instance_id())
 return ids

static func _summary(group:Dictionary)->String:
 if not group.building.is_empty():return str(Rules.building(group.building.kind).get("title","施設"))
 if group.units.is_empty():return "選択なし"
 var counts:Dictionary={}
 for unit in group.units:counts[unit.kind]=int(counts.get(unit.kind,0))+1
 var parts:Array[String]=[]
 for kind in counts:parts.append("%s × %d"%[Rules.unit(kind).get("title","部隊"),counts[kind]])
 return " / ".join(parts)

static func _short_summary(group:Dictionary)->String:
 if not group.building.is_empty():return _summary(group)
 if group.units.is_empty():return "選択なし"
 var first_kind:String=group.units[0].kind
 var same_kind:bool=group.units.all(func(unit):return unit.kind==first_kind)
 var title:String=str(Rules.unit(first_kind).get("title","部隊")) if same_kind else "部隊"
 return "%s × %d"%[title,group.units.size()]

static func _grid(parent:Node)->GridContainer:
 var grid=GridContainer.new();parent.add_child(grid)
 grid.columns=3
 grid.size_flags_horizontal=Control.SIZE_EXPAND_FILL
 grid.mouse_filter=Control.MOUSE_FILTER_PASS
 grid.add_theme_constant_override("h_separation",6)
 grid.add_theme_constant_override("v_separation",6)
 return grid

static func _button(hud,title:String,callback:Callable,parent:Node)->Button:
 var button:Button=hud._button(title,callback,parent)
 button.custom_minimum_size=Vector2(48,48)
 button.size_flags_horizontal=Control.SIZE_EXPAND_FILL
 button.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
 button.text_overrun_behavior=TextServer.OVERRUN_NO_TRIMMING
 button.add_theme_font_size_override("font_size",15)
 # Preserve the v0.37 drag-through controls behavior immediately, including
 # controls created while the existing popup's content is being replaced.
 button.mouse_filter=Control.MOUSE_FILTER_PASS
 return button
