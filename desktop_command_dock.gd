extends Node
## Desktop presentation only. Main retains selection, production, availability,
## button callbacks and modal ownership. Mobile never instantiates this helper.
const TILE_WIDTH=188.0
const TILE_HEIGHT=72.0
const GAP=7.0
const PADDING=10.0
const LEFT_EDGE=242.0
const EDGE=14.0
const DETAIL_HEIGHT=22.0
const IDENTITY_HEIGHT=56.0
const PRODUCER_HEIGHT=64.0
const HEADER_GAP=6.0
var host:Node
var panel:PanelContainer
var old_selection_panel:PanelContainer
var body:Control
var header_region:Control
var grid_scroll:ScrollContainer
var last_layout:Dictionary={}
var top_panel:PanelContainer
var top_body:Control
var top_counters:Array=[]
var top_buttons:Array=[]
var top_compact:bool=false
var top_width:float=-1.0

func setup(game:Node,selection_panel:PanelContainer,command_panel:PanelContainer,resource_panel:PanelContainer,menu_button:Button)->void:
 host=game
 if host.mobile_enabled:return
 name="DesktopCommandDock"
 process_priority=110 # Read labels after main refreshes the live game state.
 panel=command_panel
 old_selection_panel=selection_panel
 panel.name="ContextCommandDock"
 old_selection_panel.hide()
 # An ordinary Control keeps text minimum sizes from forcing the panel wide.
 # The existing panel stays in hud_parts for end-state hiding and depth masks.
 for child in panel.get_children():child.hide()
 body=Control.new()
 body.name="DockContent"
 body.mouse_filter=Control.MOUSE_FILTER_PASS
 body.clip_contents=true
 panel.add_child(body)
 header_region=Control.new()
 header_region.name="DockSelection"
 header_region.mouse_filter=Control.MOUSE_FILTER_PASS
 header_region.clip_contents=true
 body.add_child(header_region)
 for control in [host.selection_portrait,host.selection_info,host.selected_hp,
   host.supply_status,host.context_button,host.dismantle_button,
   host.command_heading,host.queue_caption,host.queue_icons,host.queue_bar,
   host.command_detail]:
  control.reparent(body if control==host.command_detail else header_region,false)
  control.custom_minimum_size=Vector2.ZERO
  control.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
 for text in [host.selection_info,host.supply_status,host.command_heading,
   host.queue_caption,host.command_detail]:
  text.autowrap_mode=TextServer.AUTOWRAP_OFF
  text.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
  text.clip_text=true
  text.max_lines_visible=1
 host.selection_info.add_theme_font_size_override("font_size",17)
 host.supply_status.add_theme_font_size_override("font_size",14)
 host.command_heading.add_theme_font_size_override("font_size",16)
 host.selection_portrait.mouse_filter=Control.MOUSE_FILTER_IGNORE
 host.selected_hp.mouse_filter=Control.MOUSE_FILTER_IGNORE
 host.queue_bar.mouse_filter=Control.MOUSE_FILTER_IGNORE
 grid_scroll=ScrollContainer.new()
 grid_scroll.name="DockCommands"
 grid_scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_AUTO
 grid_scroll.vertical_scroll_mode=ScrollContainer.SCROLL_MODE_AUTO
 grid_scroll.mouse_filter=Control.MOUSE_FILTER_STOP
 body.add_child(grid_scroll)
 host.command_grid.reparent(grid_scroll,false)
 host.command_grid.size_flags_horizontal=Control.SIZE_EXPAND_FILL
 host.command_grid.size_flags_vertical=Control.SIZE_SHRINK_BEGIN
 # Main recreates tiles after queue/cancel even when the layout is unchanged.
 # Apply sizing on entry so replacement hit areas never collapse to minimums.
 host.command_grid.child_entered_tree.connect(_fit_command_tile)
 for tile in host.command_grid.get_children():_fit_command_tile(tile)
 _setup_top(resource_panel,menu_button)
 # No replacement buttons, reduced fonts or changes to their live callbacks.
 sync()

func _process(_delta:float)->void:
 sync()

func sync()->void:
 if not is_instance_valid(host) or host.mobile_enabled:return
 old_selection_panel.hide()
 host.command_detail.tooltip_text=host.command_detail.text
 var empty:bool=host.selected.is_empty() and host.inspected.is_empty() and host.inspected_resource.is_empty() and host.inspected_site.is_empty()
 var producer:bool=not host.inspected.is_empty()
 var requested:Dictionary=layout_metrics(host.get_viewport().get_visible_rect().size,host.command_grid.get_child_count(),empty,producer)
 requested["dismantle"]=host.dismantle_button.visible
 requested["context"]=host.context_button.visible
 requested["context_key"]=host.context_signature
 requested["tile_count"]=host.command_grid.get_child_count()
 # Hover detail and countdown text deliberately do not enter the signature.
 # Defer movement through a press/release, including a context change or resize.
 if requested!=last_layout:
  if not last_layout.is_empty() and (Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) or Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)):return
  if requested.get("context_key","")!=last_layout.get("context_key",""):
   grid_scroll.scroll_vertical=0
   grid_scroll.scroll_horizontal=0
  _layout(requested)
  last_layout=requested
 # The game owns HP/queue visibility. It updates them even without a reflow.
 host.command_heading.visible=not empty and (not producer or host.queue_caption.text.is_empty())
 if not host.queue_caption.text.is_empty() and host.queue_caption.tooltip_text.is_empty():
  host.queue_caption.tooltip_text=host.queue_caption.text

## Pure geometry, also usable by layout regression tests without a game scene.
static func layout_metrics(viewport:Vector2,tile_count:int,empty:bool,producer:bool)->Dictionary:
 var available:float=maxf(1.0,viewport.x-LEFT_EDGE-EDGE)
 var width:float=minf(available,2.0*TILE_WIDTH+GAP+PADDING*2.0) if empty else available
 var inner:float=maxf(1.0,width-PADDING*2.0)
 var columns:int=clampi(floori((inner+GAP)/(TILE_WIDTH+GAP)),1,2 if empty else 4)
 var rows:int=ceili(tile_count/float(columns))
 var stacked:bool=not empty and inner<720.0
 var state_height:float=PRODUCER_HEIGHT if producer else 44.0
 var header:float=0.0
 if not empty:header=IDENTITY_HEIGHT+8.0+state_height if stacked else maxf(IDENTITY_HEIGHT,state_height)
 var grid_top:float=header+(HEADER_GAP if header>0.0 and rows>0 else 0.0)
 var content_height:float=rows*TILE_HEIGHT+maxi(0,rows-1)*GAP
 # Keep at most two rows on screen on narrow desktops; scroll complete tiles.
 var space:float=maxf(TILE_HEIGHT,viewport.y-100.0-EDGE-PADDING*2.0-grid_top-DETAIL_HEIGHT-4.0)
 var grid_height:float=minf(content_height,minf(TILE_HEIGHT*2.0+GAP,space))
 # A visible vertical scrollbar takes width. Recompute columns with that space
 # reserved so a third/fourth column cannot become clipped by the scrollbar.
 if content_height>grid_height:
  columns=clampi(floori((inner-16.0+GAP)/(TILE_WIDTH+GAP)),1,columns)
  rows=ceili(tile_count/float(columns))
  content_height=rows*TILE_HEIGHT+maxi(0,rows-1)*GAP
 var detail_top:float=grid_top+grid_height+(4.0 if rows>0 else 0.0)
 var height:float=PADDING*2.0+detail_top+DETAIL_HEIGHT
 return {"rect":Rect2(Vector2(viewport.x-EDGE-width,viewport.y-EDGE-height),Vector2(width,height)),
  "inner":inner,"columns":columns,"rows":rows,"empty":empty,"producer":producer,
  "stacked":stacked,"header":header,"grid_top":grid_top,"grid_height":grid_height,
  "content_height":content_height,"detail_top":detail_top}

func _layout(metrics:Dictionary)->void:
 _layout_top(host.get_viewport().get_visible_rect().size.x)
 var rectangle:Rect2=metrics.rect
 panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
 panel.position=rectangle.position
 panel.size=rectangle.size
 var width:float=metrics.inner
 _rect(header_region,Rect2(0,0,width,metrics.header))
 header_region.visible=not metrics.empty
 var identity_width:float=width if metrics.stacked else clampf(width*.46,340.0,500.0)
 identity_width=minf(width,identity_width)
 _rect(host.selection_portrait,Rect2(0,0,48,48))
 _rect(host.selection_info,Rect2(60,0,maxf(1,identity_width-60),24))
 _rect(host.supply_status,Rect2(60,26,maxf(1,identity_width-60),22))
 _rect(host.selected_hp,Rect2(0,52,identity_width,4))
 var state_x:float=0.0 if metrics.stacked else identity_width+16.0
 var state_y:float=IDENTITY_HEIGHT+8.0 if metrics.stacked else 0.0
 var state_width:float=maxf(1.0,width-state_x)
 var action_width:float=0.0
 for action in [host.dismantle_button,host.context_button]:
  if not action.visible:continue
  var button_width:float=78.0 if action==host.dismantle_button else 140.0
  action_width+=button_width+8.0
  _rect(action,Rect2(width-action_width+8.0,state_y+8.0,button_width,40.0))
 var text_width:float=maxf(1.0,state_width-action_width)
 _rect(host.command_heading,Rect2(state_x,state_y,text_width,24))
 _rect(host.queue_caption,Rect2(state_x,state_y if metrics.producer else state_y+24.0,text_width,22))
 _rect(host.queue_icons,Rect2(state_x,state_y+22.0,text_width,36))
 _rect(host.queue_bar,Rect2(state_x,state_y+60.0,text_width,4))
 host.command_grid.columns=metrics.columns
 grid_scroll.visible=metrics.rows>0
 _rect(grid_scroll,Rect2(0,metrics.grid_top,width,metrics.grid_height))
 host.command_grid.custom_minimum_size=Vector2.ZERO
 _rect(host.command_detail,Rect2(0,metrics.detail_top,width,DETAIL_HEIGHT))

func _fit_command_tile(tile:Node)->void:
 if tile is Control:tile.size_flags_horizontal=Control.SIZE_EXPAND_FILL

func _rect(control:Control,rectangle:Rect2)->void:
 control.position=rectangle.position
 control.size=rectangle.size

func _setup_top(resource_panel:PanelContainer,menu_button:Button)->void:
 top_panel=resource_panel
 for child in top_panel.get_children():child.hide()
 top_body=Control.new()
 top_body.name="AdaptiveResources"
 top_body.mouse_filter=Control.MOUSE_FILTER_PASS
 top_panel.add_child(top_body)
 for key in ["food","salvage","parts","population","age","experience","ammo","power"]:
  var widget:Dictionary=host.hud_counters[key]
  var root:HBoxContainer=widget.root
  var icon:TextureRect=root.get_child(0)
  var words:VBoxContainer=root.get_child(1)
  top_counters.append({"widget":widget,"root":root,"icon":icon,"words":words,
   "heading":words.get_child(0),"minimum":root.custom_minimum_size})
  root.reparent(top_body,false)
 top_buttons=[host.idle_worker_button,host.pause_button,menu_button]
 for action in top_buttons:action.reparent(top_body,false)

## Two 32 px counter rows preserve every value, caption and assigned-worker
## count while retaining the three original menu/pause/idle button objects.
static func top_layout_metrics(viewport_width:float)->Dictionary:
 var compact:bool=viewport_width<1360.0
 var widths:Array=[122.0,122.0,122.0,122.0,90.0,100.0,132.0,150.0]
 var button_widths:Array=[86.0,86.0,92.0]
 var inner:float=maxf(1.0,viewport_width-PADDING*2.0)
 var button_width:float=280.0
 var counter_width:float=maxf(1.0,inner-button_width-12.0)
 var counters:Array[Rect2]=[]
 var x:float=0.0
 for i in 8:
  if compact:
   var cell_width:float=(counter_width-24.0)/4.0
   counters.append(Rect2((i%4)*(cell_width+8.0),floori(i/4.0)*36.0,cell_width,32.0))
  else:
   counters.append(Rect2(x,0,widths[i],64.0))
   x+=widths[i]+8.0
 var buttons:Array[Rect2]=[]
 x=inner-button_width
 for width in button_widths:
  buttons.append(Rect2(x,13.0 if compact else 11.0,width,42.0))
  x+=width+8.0
 return {"compact":compact,"height":88.0 if compact else 84.0,"counters":counters,"buttons":buttons}

func _layout_top(viewport_width:float)->void:
 if is_equal_approx(top_width,viewport_width):return
 var metrics:Dictionary=top_layout_metrics(viewport_width)
 if metrics.compact!=top_compact:
  for entry in top_counters:
   var widget:Dictionary=entry.widget
   if metrics.compact:
    entry.heading.reparent(entry.root,false)
    widget.value.reparent(entry.root,false)
    entry.words.hide()
   else:
    entry.heading.reparent(entry.words,false)
    widget.value.reparent(entry.words,false)
    entry.words.show()
   entry.root.custom_minimum_size=Vector2.ZERO if metrics.compact else entry.minimum
   entry.root.add_theme_constant_override("separation",5 if metrics.compact else 7)
   entry.icon.custom_minimum_size=Vector2(20,20) if metrics.compact else Vector2(28,28)
   entry.heading.size_flags_vertical=Control.SIZE_SHRINK_CENTER if metrics.compact else Control.SIZE_FILL
   widget.value.size_flags_vertical=Control.SIZE_SHRINK_CENTER if metrics.compact else Control.SIZE_FILL
   widget.value.size_flags_horizontal=Control.SIZE_EXPAND_FILL if metrics.compact else Control.SIZE_FILL
   widget.caption.add_theme_font_size_override("font_size",13 if metrics.compact else 14)
   if is_instance_valid(widget.assigned):widget.assigned.add_theme_font_size_override("font_size",12 if metrics.compact else 13)
 top_compact=metrics.compact
 top_width=viewport_width
 top_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
 top_panel.position=Vector2.ZERO
 top_panel.size=Vector2(viewport_width,metrics.height)
 for i in top_counters.size():_rect(top_counters[i].root,metrics.counters[i])
 for i in top_buttons.size():_rect(top_buttons[i],metrics.buttons[i])
