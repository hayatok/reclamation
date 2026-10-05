extends RefCounted
## RECLAMATION bespoke field-command hardware skin.
## All artwork is local; no runtime services or dependencies.
const ROOT="res://assets/ui/"

static func skin(kind:String="panel",padding:float=14)->StyleBoxTexture:
 var s=StyleBoxTexture.new()
 s.texture=load(ROOT+kind+".svg")
 for side in [SIDE_LEFT,SIDE_TOP,SIDE_RIGHT,SIDE_BOTTOM]:
  s.set_texture_margin(side,19)
  s.set_content_margin(side,padding)
 s.axis_stretch_horizontal=StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
 s.axis_stretch_vertical=StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
 return s

static func style_button(b:Button,card:bool=false):
 for state in ["normal","hover","pressed","disabled"]:
  var texture=state
  if card:texture="card_hover" if state in ["hover","pressed"] else "card"
  b.add_theme_stylebox_override(state,skin(texture,10))
 b.add_theme_stylebox_override("focus",skin("hover",10))
 b.add_theme_color_override("font_color",Color("e5ddc6"))
 b.add_theme_color_override("font_hover_color",Color("fff0c8"))
 b.add_theme_color_override("font_disabled_color",Color("747d6d"))
 b.mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND
 var t={"value":null}
 b.mouse_entered.connect(func():
  if b.disabled:return
  if t.value:t.value.kill()
  t.value=b.create_tween()
  t.value.tween_property(b,"self_modulate",Color(1.12,1.10,1.02),.13)
 )
 b.mouse_exited.connect(func():
  if t.value:t.value.kill()
  t.value=b.create_tween()
  t.value.tween_property(b,"self_modulate",Color.WHITE,.2)
 )

static func portrait(kind:String)->Texture2D:
 var model_image=ROOT+"portrait_"+kind+".png"
 if ResourceLoader.exists(model_image):return load(model_image)
 var index={"guard":0,"grenade":0,"worker":1,"truck":2,"convoy":2,"siegecart":4,"hq":5,"food":5,"salvage":5,"parts":5,"electric":3,"lightning":3,"tower":4,"mortar":4,"support":5,"research":3,"factory":5,"yard":5,"relay":5,"wall":5}.get(kind,0)
 var a=AtlasTexture.new()
 a.atlas=load(ROOT+"crew_equipment_atlas.png")
 a.region=Rect2((index%3)*512,int(index/3)*512,512,512)
 a.filter_clip=true
 return a

static func equipment(family:String)->Control:
 var frame=PanelContainer.new()
 frame.custom_minimum_size=Vector2(300,210)
 frame.mouse_filter=Control.MOUSE_FILTER_IGNORE
 frame.add_theme_stylebox_override("panel",skin("normal",5))
 var art=TextureRect.new()
 var category="electric" if family in ["electric","lightning","chain","tesla"] else "tower" if family in ["ballistic","projectile","explosive","explosion","critical","pierce","multishot","damage"] else "support"
 art.texture=portrait(category)
 art.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
 art.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
 art.custom_minimum_size=Vector2(280,200)
 art.mouse_filter=Control.MOUSE_FILTER_IGNORE
 frame.add_child(art)
 return frame

## The command tile owns presentation only. The caller owns availability and costs.
## `title` accepts the existing "Q 作業員" form; the key is drawn separately.
static func command_button(kind:String,title:String,cost:String,callback:Callable,font:Font)->Button:
 var b=Button.new()
 b.custom_minimum_size=Vector2(188,72)
 b.size=Vector2(188,72)
 b.focus_mode=Control.FOCUS_NONE
 b.mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND
 b.pressed.connect(callback)
 for state in ["normal","hover","pressed","disabled","focus"]:
  b.add_theme_stylebox_override(state,_command_surface(state))
 var content=Control.new()
 content.name="CommandContent"
 b.add_child(content)
 content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 content.mouse_filter=Control.MOUSE_FILTER_IGNORE
 # Distinct, unframed silhouettes stay legible at an actual 32 px.
 var visual=TextureRect.new()
 visual.name="ActionIcon"
 content.add_child(visual)
 visual.position=Vector2(10,8)
 visual.size=Vector2(32,32)
 visual.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
 visual.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
 var glyph:String={"convoy":"truck","siegecart":"mortar","hq":"house"}.get(kind,kind)
 var file:String=ROOT+"icon_"+glyph+".svg"
 visual.texture=load(file) if ResourceLoader.exists(file) else load(ROOT+"icon_factory.svg")
 visual.mouse_filter=Control.MOUSE_FILTER_IGNORE
 var caption:Dictionary=_command_caption(title)
 var name_label:Label=_command_label(caption.title,font,16,Color("f1ead8"))
 name_label.name="ActionTitle"
 content.add_child(name_label)
 name_label.position=Vector2(50,9)
 name_label.size=Vector2(128,25)
 name_label.anchor_right=1.0
 name_label.offset_right=-10
 name_label.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
 name_label.clip_text=true
 var key_chip=Panel.new()
 key_chip.name="HotkeyChip"
 key_chip.mouse_filter=Control.MOUSE_FILTER_IGNORE
 key_chip.position=Vector2(10,46)
 key_chip.size=Vector2(22,18)
 key_chip.add_theme_stylebox_override("panel",_command_key_surface())
 key_chip.visible=not str(caption.key).is_empty()
 content.add_child(key_chip)
 var key_label:Label=_command_label(caption.key,font,12,Color("ddd0a8"))
 key_label.name="Hotkey"
 key_chip.add_child(key_label)
 key_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 key_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
 key_label.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
 var bottom_x:float=39.0 if key_chip.visible else 10.0
 var cost_row=HBoxContainer.new()
 cost_row.name="ResourceCosts"
 content.add_child(cost_row)
 cost_row.position=Vector2(bottom_x,44)
 cost_row.size=Vector2(178-bottom_x,22)
 cost_row.anchor_right=1.0
 cost_row.offset_right=-10
 cost_row.add_theme_constant_override("separation",5)
 cost_row.mouse_filter=Control.MOUSE_FILTER_IGNORE
 var costs:Dictionary=_command_costs(cost)
 var amount_labels:Dictionary={}
 for resource in ["food","salvage","parts"]:
  if not costs.has(resource):continue
  var token=HBoxContainer.new()
  token.name=resource.capitalize()+"Cost"
  token.add_theme_constant_override("separation",3)
  token.mouse_filter=Control.MOUSE_FILTER_IGNORE
  cost_row.add_child(token)
  var resource_name:Label=_command_label({"food":"食","salvage":"廃","parts":"部"}[resource],font,14,Color("c9c4af"))
  token.add_child(resource_name)
  var amount:Label=_command_label(str(costs[resource]),font,14,Color("e3c78e"))
  amount.name="Amount"
  token.add_child(amount)
  amount_labels[resource]=amount
 var detail:Label=_command_label(cost,font,14,Color("c5c9b8"))
 detail.name="CommandDetail"
 content.add_child(detail)
 detail.position=Vector2(bottom_x,43)
 detail.size=Vector2(178-bottom_x,24)
 detail.anchor_right=1.0
 detail.offset_right=-10
 detail.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
 detail.clip_text=true
 detail.visible=costs.is_empty()
 cost_row.visible=not costs.is_empty()
 b.tooltip_text=title+("\n"+cost if not cost.is_empty() else "")
 b.set_meta("command_title",str(caption.title))
 b.set_meta("command_hotkey",str(caption.key))
 b.set_meta("command_description",cost)
 b.set_meta("command_costs",costs)
 b.set_meta("command_amount_labels",amount_labels)
 b.set_meta("command_detail",detail)
 b.set_meta("command_cost_row",cost_row)
 b.set_meta("command_icon",visual)
 b.set_meta("command_title_label",name_label)
 b.set_meta("command_blocked_reason","")
 b.set_meta("command_highlighted",false)
 b.set_meta("command_shortages",[])
 b.set_meta("command_ready_tooltip",b.tooltip_text)
 b.button_down.connect(func():content.position=Vector2(1,1))
 b.button_up.connect(func():content.position=Vector2.ZERO)
 return b

## Empty reason enables the button. Prerequisites replace the cost row; resource
## shortages preserve costs so the player can see exactly what is missing.
## Callers may keep assigning tooltip_text for richer hover details. The most
## recent enabled tooltip is restored when a block clears.
static func set_command_state(button:Button,blocked_reason:String,highlighted:bool=false)->void:
 if not is_instance_valid(button):return
 var previous:String=str(button.get_meta("command_blocked_reason",""))
 if previous.is_empty():button.set_meta("command_ready_tooltip",button.tooltip_text)
 button.disabled=not blocked_reason.is_empty()
 button.set_meta("command_blocked_reason",blocked_reason)
 button.tooltip_text=blocked_reason if button.disabled else str(button.get_meta("command_ready_tooltip",button.tooltip_text))
 button.mouse_default_cursor_shape=Control.CURSOR_ARROW if button.disabled else Control.CURSOR_POINTING_HAND
 if bool(button.get_meta("command_highlighted",false))!=highlighted:
  button.set_meta("command_highlighted",highlighted)
  button.add_theme_stylebox_override("normal",_command_surface("selected" if highlighted else "normal"))
  button.add_theme_stylebox_override("disabled",_command_surface("selected_disabled" if highlighted else "disabled"))
 if not button.has_meta("command_detail"):return
 var detail:Label=button.get_meta("command_detail")
 var cost_row:HBoxContainer=button.get_meta("command_cost_row")
 var has_costs:bool=not (button.get_meta("command_costs",{}) as Dictionary).is_empty()
 # Structural blockers must be visible without hover; resource shortages keep
 # their red itemized costs. The full cost/reason remains in the detail bar.
 var show_costs:bool=has_costs and (blocked_reason.is_empty() or _command_resource_block(blocked_reason))
 cost_row.visible=show_costs
 detail.visible=not show_costs
 detail.text=_command_short_reason(blocked_reason) if not blocked_reason.is_empty() else str(button.get_meta("command_description",""))
 detail.add_theme_color_override("font_color",Color("edb296") if button.disabled else Color("c5c9b8"))
 var icon:TextureRect=button.get_meta("command_icon")
 icon.modulate=Color("b6b8a7") if button.disabled else Color.WHITE
 var name_label:Label=button.get_meta("command_title_label")
 name_label.add_theme_color_override("font_color",Color("c7c8b8") if button.disabled else Color("f1ead8"))
 # Do not modulate the entire tile: missing numbers must remain clearly red.
 if button.disabled:
  var content:Control=button.get_node_or_null("CommandContent")
  if content:content.position=Vector2.ZERO

## Optional; does not change availability or the exact reason owned by the game.
## Resource dictionary keys are food, salvage, parts. Unknown keys are ignored.
static func set_command_affordability(button:Button,stockpile:Dictionary,cost_dictionary:Dictionary)->void:
 if not is_instance_valid(button) or not button.has_meta("command_amount_labels"):return
 var labels:Dictionary=button.get_meta("command_amount_labels")
 var shortages:Array[String]=[]
 for resource in labels:
  var amount:Label=labels[resource]
  var needed:float=float(cost_dictionary.get(resource,0))
  var missing:bool=float(stockpile.get(resource,0))+0.00001<needed
  amount.add_theme_color_override("font_color",Color("ff9e87") if missing else Color("e3c78e"))
  if missing:shortages.append(resource)
 button.set_meta("command_shortages",shortages)

static func _command_label(text:String,font:Font,font_size:int,color:Color)->Label:
 var label=Label.new()
 label.text=text
 if font:label.add_theme_font_override("font",font)
 label.add_theme_font_size_override("font_size",font_size)
 label.add_theme_color_override("font_color",color)
 label.mouse_filter=Control.MOUSE_FILTER_IGNORE
 label.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
 return label

static func _command_caption(title:String)->Dictionary:
 var split:int=title.find(" ")
 if split>0:
  var key:String=title.substr(0,split)
  var key_test=RegEx.new()
  key_test.compile("^(?:[A-Z0-9.]|F[0-9]{1,2}|Period|Space|Escape|Enter|Tab)$")
  if key_test.search(key):
   key={"Period":".","Space":"SP","Escape":"Esc","Enter":"↵"}.get(key,key)
   return {"key":key,"title":title.substr(split+1).strip_edges()}
 return {"key":"","title":title}

static func _command_costs(cost:String)->Dictionary:
 var result:Dictionary={}
 var expression=RegEx.new()
 expression.compile("^(?:[食廃部][0-9]+)(?:\\s+[食廃部][0-9]+)*$")
 var text:String=cost.strip_edges()
 if not expression.search(text):return result
 var tokens=RegEx.new()
 tokens.compile("([食廃部])([0-9]+)")
 for token in tokens.search_all(text):
  var resource:String={"食":"food","廃":"salvage","部":"parts"}[token.get_string(1)]
  if result.has(resource):return {}
  result[resource]=int(token.get_string(2))
 return result

static func _command_resource_block(reason:String)->bool:
 return reason.begins_with("必要:") or reason.begins_with("必要：") or reason.begins_with("資材が不足") or reason.begins_with("資源が不足") or reason in ["資材不足","資源不足"]

static func _command_short_reason(reason:String)->String:
 if reason.is_empty():return ""
 if _command_resource_block(reason):return "資材不足"
 if reason.begins_with("必要施設:") or reason.begins_with("必要施設："):
  var requirement:String=reason.substr(5).strip_edges()
  # One short prerequisite can retain its useful name; compound requirements
  # stay concise and the full list remains available in the tooltip/detail bar.
  if not "、" in requirement:
   var first:String=requirement.get_slice(" ",0).trim_prefix("給電中の")
   if first.length()<=6:return first+("に給電" if requirement.begins_with("給電中の") else "が必要")
  return "前提施設が必要"
 if reason.begins_with("時代 ") and "が必要" in reason:return reason.replace("時代 ","段階 ")
 if "人口" in reason:return "人口上限"
 if "給電" in reason or "電力" in reason:return "未給電"
 if "建設中" in reason or "建築中" in reason or "工事" in reason or "未完成" in reason or "完成した生産施設" in reason:return "建築中"
 if "停止" in reason or "無効" in reason:return "稼働停止中"
 if "予約されています" in reason:return "発展を予約済み"
 if "予約" in reason and ("上限" in reason or "いっぱい" in reason):return "予約上限"
 if "最高段階" in reason:return "最高段階に到達"
 if "出口" in reason:return "出口が塞がれた"
 if "準備されていません" in reason:return "準備中"
 if "施設を選択" in reason:return "施設を選択"
 if "訓練できません" in reason:return "訓練できない施設"
 if "訓練できないユニット" in reason:return "訓練できない対象"
 if "建設できない施設" in reason:return "建設できない施設"
 # Fit unknown messages without tiny type; exact text is always in tooltip.
 return reason

static func _command_surface(state:String)->StyleBoxFlat:
 var box=StyleBoxFlat.new()
 box.bg_color={"normal":Color("28322d"),"hover":Color("3c4739"),"pressed":Color("19281f"),"disabled":Color("202923"),"focus":Color(0,0,0,0),"selected":Color("394733"),"selected_disabled":Color("30382a")}.get(state,Color("28322d"))
 box.border_color={"normal":Color("66705b"),"hover":Color("c4b075"),"pressed":Color("b09e61"),"disabled":Color("4e5849"),"focus":Color("c4b075"),"selected":Color("dbc383"),"selected_disabled":Color("a49362")}.get(state,Color("66705b"))
 box.set_border_width_all(1)
 box.border_width_left=3 if state in ["selected","selected_disabled"] else 1
 box.set_corner_radius_all(2)
 box.set_content_margin_all(0)
 return box

static func _command_key_surface()->StyleBoxFlat:
 var box=StyleBoxFlat.new()
 box.bg_color=Color("17221d")
 box.border_color=Color("777957")
 box.set_border_width_all(1)
 box.set_corner_radius_all(2)
 return box

static func mount_portrait(image:TextureRect):
 image.custom_minimum_size=Vector2(80,76)
 image.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
 var hardware=Control.new()
 image.add_child(hardware)
 hardware.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 hardware.mouse_filter=Control.MOUSE_FILTER_IGNORE
 hardware.draw.connect(func():
  var s=hardware.size
  hardware.draw_style_box(skin("panel",0),Rect2(Vector2(-4,-4),s+Vector2(8,8)))
 )
 # Put hardware behind the illustrated portrait.
 hardware.show_behind_parent=true

static func section_rule(parent:Control,text:String,font:Font):
 var l=Label.new()
 l.text="▰  "+text
 l.add_theme_font_override("font",font)
 l.add_theme_font_size_override("font_size",14)
 l.add_theme_color_override("font_color",Color("d6b674"))
 parent.add_child(l)
 return l
