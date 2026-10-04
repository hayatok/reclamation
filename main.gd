extends Node3D

const CYAN = Color("c5b78e")
const AMBER = Color("d2a148")
const RED = Color("b9523e")
const PALE = Color("ded7c7")
const BG = Color("222520")
const CommandDeck=preload("res://command_deck.gd")
const EnvironmentOverlay=preload("res://environment_overlay.gd")
const BattleFX=preload("res://battle_fx.gd")
const BattleVisibility=preload("res://battle_visibility.gd")
const ConvoyPlan=preload("res://convoy_plan.gd")
const GameRules=preload("res://game_rules.gd")
const StructureVisuals=preload("res://structure_visuals.gd")
const AudioSystem=preload("res://reclamation_audio.gd")
const CrowdSteering=preload("res://crowd_steering.gd")
var crowd_steering=CrowdSteering.new()
var enemy_approach_cells:Dictionary={}
const HordeRenderer=preload("res://horde_renderer.gd")
const TacticalMap=preload("res://tactical_map.gd")
const ActorVisuals=preload("res://actor_visuals.gd")
const UpgradeCatalog=preload("res://upgrade_catalog.gd")
const BUILD_COSTS={"tower":65,"wall":18,"factory":75,"relay":40,"mortar":120,"yard":80}
const UNIT_COSTS={"guard":45,"worker":30,"truck":80,"grenade":75}

@onready var campaign_state=get_node("/root/Campaign")
var tech_level:int=1
var research_active:bool=false
var research_time:float=0
var shells:Array=[]
var corpses:Array=[]
var convoy_route_choice:int=0
var convoy_halted:bool=false
var convoy_encounter_stage:int=0
var convoy_pending:Dictionary={}
var route_panel:PanelContainer
var route_previous_pause:bool=false
var convoy_pause_button:Button
var convoy_started:bool=false
var convoy_index:int=0
var boss_spawned:bool=false
var boss_defeated:bool=false
var failure_reason:String="拠点を失った。"
var audio_system:Node
var threat_voice_clock:float=7
var mission_action_button:Button
var tech_button:Button
var command_grid:GridContainer
var command_tab:String="people"
const CONVOY_ROUTE=[Vector3(-24,0,18),Vector3(-17,0,17),Vector3(-6,0,17),Vector3(7,0,17),Vector3(18,0,17),Vector3(25,0,18)]
var units:Array=[]
var enemies:Array=[]
var buildings:Array=[]
var sites:Array=[]
var resources:float=150
var kills:int=0
var xp:float=0
var level:int=1
var upgrades:Dictionary={}
var cards:Array=[]
var active_card:bool=false
var pending_card_delay:float=0.0
var paused:bool=false
var ended:bool=false
var build_mode:String=""
var elapsed:float=0
var wave_clock:float=24
var wave:int=0
var hold_time:float=0
var noise:float=10
var generator_on:bool=false
var combo:int=0
var combo_clock:float=0
var selected:Array=[]
var horde_renderer:Node3D
var district_art:Node3D
var battle_visibility:Node
var battle_fx:Node
var camera:Camera3D
var camera_focus=Vector3.ZERO
var root_ui:Control
var stats:Label
var objective:Label
var guide:Label
var generator_button:Button
var status:Label
var hint:Label
var selection_info:Label
var center_notice:Label
var xp_bar:ProgressBar
var core_bar:ProgressBar
var choice_panel:PanelContainer
var modal:PanelContainer
var drag_overlay:Control
var drag_start=Vector2.ZERO
var dragging:bool=false
var effects:Array=[]
var impact_mesh:ArrayMesh
var impact_materials:Dictionary={}
var ghost:MeshInstance3D
var rng=RandomNumberGenerator.new()
var visual_rng=RandomNumberGenerator.new()
var card_rng=RandomNumberGenerator.new()
var notice_timer:float=8
var alert_player:AudioStreamPlayer
var upgrade_player:AudioStreamPlayer
var audio_players:Array=[]
var shot_tick:float=0
var muted:bool=false
var low_fx:bool=false
var performance_mode:bool=false
var showcase_process_ms:Array=[]
var showcase_script_ms:Array=[]
var showcase_sim_ms:Array=[]
var showcase_draws:Array=[]
var showcase_primitives:Array=[]
var debug_run:bool=false
var debug_stage:int=0
var showcase_start_ms:int=0
var showcase_impact_captured:bool=false
var showcase_frame_ms:Array=[]
var attack_move:bool=false
var nav=AStarGrid2D.new()
var first_activation:bool=false
var incoming_surge:bool=false
var mission:Dictionary
var gathered:float=0
var auto_save_clock:float=30
var title_open:bool=false
var pause_button:Button
var ammo:float=240
var power_used:float=0
var power_capacity:float=6
var power_clock:float=0
var build_boost:float=0
var victory_boost:float=0
var recruit_queue:Array=[]
var blast_queue:Array=[]
var preferred_family:String=""
var family_misses:int=0
var rerolls:int=2
var terrain_blocks:Array=[]
var catalog_by_id:Dictionary={}
var inspected:Dictionary={}
var dismantle_button:Button
var dismantle_panel:PanelContainer
var dismantle_target:Dictionary={}
var dismantle_previous_pause:bool=false
var context_button:Button
var supply_status:Label
var combo_label:Label
var title_panel:PanelContainer
var options_panel:PanelContainer
var options_previous_pause:bool=false
var render_frames:int=0
var command_font:Font
var minimap:Control
var hud_parts:Array=[]
var portrait_cache:Dictionary={}
var selection_portrait:TextureRect
var selected_hp:ProgressBar
var last_portrait_kind:String=""
var font:Font

func _ready():
 for data in UpgradeCatalog.all():catalog_by_id[data.id]=data
 mission=campaign_state.config()
 resources=mission.initial
 muted=campaign_state.muted
 low_fx=campaign_state.low_fx
 performance_mode=(campaign_state.performance_mode or "--performance" in OS.get_cmdline_user_args()) and not "--quality" in OS.get_cmdline_user_args()
 apply_graphics_quality()
 apply_graphics_quality.call_deferred()
 rng.seed=48109+campaign_state.current*113
 card_rng.seed=89342
 visual_rng.seed=754301
 font=load("res://assets/Japanese.ttc")
 command_font=load("res://assets/Command.ttf")
 nav.region=Rect2i(-31,-31,63,63)
 nav.cell_size=Vector2.ONE
 nav.diagonal_mode=AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
 nav.update()
 var art=load("res://world_art.gd")
 if art:
  var world=Node3D.new()
  world.set_script(art)
  add_child(world)
  world.rotation.y=0
  district_art=world
 terrain_blocks=TacticalMap.blockers_for(campaign_state.current)
 var terrain=TacticalMap.new()
 add_child(terrain)
 terrain.setup(campaign_state.current)
 var ruin_layer=EnvironmentOverlay.new()
 add_child(ruin_layer)
 ruin_layer.setup(campaign_state.current)
 camera=Camera3D.new()
 add_child(camera)
 camera.projection=Camera3D.PROJECTION_ORTHOGONAL
 camera.size=54
 camera.position=Vector3(37,48,43)
 camera.look_at(Vector3.ZERO)
 camera.current=true
 var core=make_building("hq",Vector3(0,0,8),true)
 core.maxhp=mission.core
 core.hp=mission.core
 make_site("generator",mission.gen)
 make_site("pump",mission.pump)
 make_site("scrap",Vector3(-10,0,9))
 make_site("scrap",Vector3(9,0,10))
 make_site("scrap",Vector3(-6,0,-12))
 if campaign_state.current>0:
  make_site("scrap",Vector3(-17,0,18))
  for site in sites:
   if site.kind=="scrap":site.stock=1000.0
 if mission.mode=="finale":make_site("substation",Vector3(17,0,14))
 for i in 6: make_unit("guard",Vector3(-3+i*1.2,0,3))
 for i in 3: make_unit("worker",Vector3(-3+i*1.6,0,10))
 make_building("tower",Vector3(2,0,-1),true)
 make_ui()
 make_audio()
 battle_fx=BattleFX.new()
 add_child(battle_fx)
 horde_renderer=HordeRenderer.new()
 add_child(horde_renderer)
 horde_renderer.setup()
 horde_renderer.low_detail=performance_mode
 battle_visibility=BattleVisibility.new()
 battle_visibility.district=district_art
 add_child(battle_visibility)
 ghost=box(Vector3(2.1,.15,2.1),CYAN,Vector3.ZERO,self)
 ghost.visible=false
 ghost.transparency=.55
 get_viewport().size_changed.connect(func(): drag_overlay.queue_redraw())
 if "--self-test" in OS.get_cmdline_user_args():call_deferred("run_tests")
 elif campaign_state.resume:
  campaign_state.resume=false
  if not load_checkpoint():show_title()
 elif not campaign_state.launch and not "--showcase" in OS.get_cmdline_user_args():show_title()
 if "--showcase" in OS.get_cmdline_user_args(): debug_run=true
 if not title_open and elapsed<1:notify(ConvoyPlan.opening(campaign_state.current),8)

func material(c:Color,emission:float=0)->StandardMaterial3D:
 var m=StandardMaterial3D.new()
 m.albedo_color=c
 m.roughness=.8
 if emission>0:
  m.emission_enabled=true
  m.emission=c
  m.emission_energy_multiplier=emission
 return m

func box(size:Vector3,c:Color,pos:Vector3,parent:Node)->MeshInstance3D:
 var n=MeshInstance3D.new()
 var mesh=BoxMesh.new()
 mesh.size=size
 n.mesh=mesh
 n.material_override=material(c)
 parent.add_child(n)
 n.position=pos
 return n

func cylinder(radius:float,height:float,c:Color,pos:Vector3,parent:Node)->MeshInstance3D:
 var n=MeshInstance3D.new()
 var mesh=CylinderMesh.new()
 mesh.top_radius=radius
 mesh.bottom_radius=radius
 mesh.height=height
 mesh.radial_segments=10
 n.mesh=mesh
 n.material_override=material(c)
 parent.add_child(n)
 n.position=pos
 return n

func ring(pos:Vector3,r:float,c:Color,parent:Node)->MeshInstance3D:
 var n=MeshInstance3D.new()
 var m=TorusMesh.new()
 m.inner_radius=r-.045
 m.outer_radius=r+.045
 m.rings=24
 m.ring_segments=5
 n.mesh=m
 n.material_override=material(c,1)
 parent.add_child(n)
 n.position=pos
 return n

func world_label(parent:Node,txt:String,pos:Vector3,col:Color=PALE):
 var l=Label3D.new()
 l.set_meta("tactical_label",true)
 l.text=txt
 l.font=font
 l.font_size=40
 l.pixel_size=.023
 l.billboard=BaseMaterial3D.BILLBOARD_ENABLED
 l.no_depth_test=true
 l.modulate=col
 l.outline_size=8
 parent.add_child(l)
 l.position=pos
 return l

func make_unit(kind:String,p:Vector3)->Dictionary:
 var n=Node3D.new()
 add_child(n)
 n.position=p
 decorate_unit(kind,n)
 var c=CYAN if kind=="guard" else AMBER
 var r=ring(Vector3(0,.06,0),.62,c,n)
 r.visible=false
 var base_hp=float(GameRules.unit(kind).hp)
 var max_hp=base_hp*(1+bonus("armor","max_hp_add"))
 var u={"node":n,"kind":kind,"hp":max_hp,"maxhp":max_hp,"basehp":base_hp,"shots":0,"goal":p,"task":"idle","target":null,"cd":rng.randf(),"work":0.0,"ring":r,"route":[],"planned":Vector3.INF}
 units.append(u)
 return u

func make_building(kind:String,p:Vector3,ready_build:bool=false)->Dictionary:
 var n=Node3D.new()
 add_child(n)
 n.position=p
 var hp=float(GameRules.building(kind).hp)
 var rad=float(GameRules.building(kind).radius)
 decorate_building(kind,n,rad)
 var b={"node":n,"kind":kind,"hp":float(hp)*(1+bonus("armor","max_hp_add")),"maxhp":float(hp)*(1+bonus("armor","max_hp_add")),"basehp":float(hp),"paid_cost":0,"powered":false,"enabled":true,"shots":0,"built":1.0 if ready_build else 0.0,"radius":rad,"cd":0.0}
 if not ready_build: n.scale=Vector3(1,.2,1)
 buildings.append(b)
 rebuild_navigation()
 return b

func make_site(kind:String,p:Vector3):
 var n=Node3D.new()
 add_child(n)
 n.position=p
 var label:Label3D
 if kind=="scrap":
  for i in 7:
   var b=box(Vector3(rng.randf_range(.5,1.8),rng.randf_range(.3,.9),rng.randf_range(.5,1.2)),Color("6d7775"),Vector3(rng.randf_range(-1.2,1.2),.5,rng.randf_range(-1,1)),n)
   b.rotation.y=rng.randf()*3
  label=world_label(n,"廃材の山",Vector3(0,2.6,0),AMBER)
 else:
  var art_kind="rail_depot" if kind=="pump" and mission.mode=="convoy" else "substation" if kind=="substation" else "generator" if kind=="generator" else "pump"
  StructureVisuals.add_site(n,art_kind)
  label=world_label(n,site_title(kind)+" [未復旧]",Vector3(0,4.3,0),AMBER if kind=="generator" else CYAN)

 ring(Vector3(0,.1,0),2.4,AMBER if kind=="generator" or kind=="scrap" else CYAN,n)
 sites.append({"node":n,"kind":kind,"progress":0.0,"reclaimed":false,"stock":650.0,"label":label,"paid":false})

func spawn_enemy(p:Vector3,fast:bool=false,armored:bool=false,boss:bool=false):
 var n=Node3D.new()
 add_child(n)
 n.position=p
 var boss_label:Label3D
 if boss:
  n.scale=Vector3.ONE*2.2
  boss_label=world_label(n,"破砕体 100%",Vector3(0,2.0,0),RED)
 enemies.append({"node":n,"boss_label":boss_label,"boss":boss,"windup":0.0,"attack_pos":p,"hp":3600.0 if boss else 150.0 if armored else 30.0 if fast else 45.0,"armored":armored,"charged_until":0.0,"speed":1.45 if boss else 1.2 if armored else 2.7 if fast else 1.65,"cd":rng.randf(),"dead":false,"route":[],"path_cd":0.0})

func style(c:Color,border:Color=Color("29414b"))->StyleBoxFlat:
 var s=StyleBoxFlat.new()
 s.bg_color=c
 s.border_color=border
 s.set_border_width_all(1)
 s.set_corner_radius_all(0)
 s.content_margin_left=12
 s.content_margin_right=12
 s.content_margin_top=12
 s.content_margin_bottom=12
 return s

func label(txt:String,size:int=18,col:Color=PALE)->Label:
 var l=Label.new()
 l.text=txt
 l.add_theme_font_size_override("font_size",size)
 l.add_theme_color_override("font_color",col)
 return l

func button(txt:String,callback:Callable,minwidth:float=140)->Button:
 var b=Button.new()
 b.text=txt
 b.focus_mode=Control.FOCUS_NONE
 b.custom_minimum_size=Vector2(minwidth,42)
 b.add_theme_stylebox_override("normal",style(Color("30332d"),Color("5c5c4d")))
 b.add_theme_stylebox_override("hover",style(Color("464737"),AMBER))
 b.add_theme_stylebox_override("pressed",style(Color("71613b"),AMBER))
 b.pressed.connect(callback)
 CommandDeck.style_button(b)
 return b

func make_ui():
 var layer=CanvasLayer.new()
 add_child(layer)
 root_ui=Control.new()
 layer.add_child(root_ui)
 root_ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 root_ui.mouse_filter=Control.MOUSE_FILTER_IGNORE
 var theme=Theme.new()
 theme.default_font=font
 theme.default_font_size=16
 root_ui.theme=theme
 var top=field_panel(Control.PRESET_TOP_WIDE,Vector4(0,0,0,58),Color("1b1e19"))
 var row=HBoxContainer.new()
 top.add_child(row)
 row.add_theme_constant_override("separation",22)
 var brand=label("R / 07",23,AMBER)
 brand.add_theme_font_override("font",command_font)
 brand.custom_minimum_size.x=112
 row.add_child(brand)
 stats=label("",20,PALE)
 stats.add_theme_font_override("font",command_font)
 stats.size_flags_horizontal=Control.SIZE_EXPAND_FILL
 stats.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
 row.add_child(stats)
 pause_button=button("II",toggle_pause,54)
 pause_button.tooltip_text="戦術ポーズ / Space"
 row.add_child(pause_button)
 row.add_child(button("保存",save_checkpoint,64))
 row.add_child(button("作戦",return_title,64))
 row.add_child(button("設定",show_options,64))
 var orders=field_panel(Control.PRESET_TOP_LEFT,Vector4(18,78,298,294),Color("242720"))
 var mission_column=VBoxContainer.new()
 orders.add_child(mission_column)
 mission_column.add_child(label("作戦命令  /  %02d"%(campaign_state.current+1),14,AMBER))
 mission_column.add_child(label(mission.title.substr(4),22,PALE))
 objective=label("",16,PALE)
 mission_column.add_child(objective)
 core_bar=ProgressBar.new()
 core_bar.custom_minimum_size=Vector2(256,8)
 core_bar.max_value=mission.core
 core_bar.show_percentage=false
 core_bar.add_theme_stylebox_override("background",bar_style(Color("10120f"),Color("10120f")))
 core_bar.add_theme_stylebox_override("fill",bar_style(Color("8d9768"),Color("8d9768")))
 mission_column.add_child(core_bar)
 status=label("",14,Color("aca994"))
 mission_column.add_child(status)
 guide=label("",14,PALE)
 guide.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
 guide.custom_minimum_size.x=250
 mission_column.add_child(guide)
 var site_actions=HBoxContainer.new()
 mission_column.add_child(site_actions)
 site_actions.add_child(button("発電所へ",func():assign_site("generator"),122))
 site_actions.add_child(button("復旧地点へ",func():assign_site("pump"),122))
 generator_button=button("発電  ON / OFF  [F]",toggle_generator,250)
 generator_button.tooltip_text="初回起動: 12秒以内に増援。稼働中は襲撃間隔が短くなる。"
 mission_column.add_child(generator_button)
 mission_action_button=button("",mission_action,250)
 mission_action_button.visible=mission.mode!="restore"
 mission_column.add_child(mission_action_button)
 convoy_pause_button=button("車列を停車",toggle_convoy_stop,250)
 convoy_pause_button.visible=false
 mission_column.add_child(convoy_pause_button)
 var mini_panel=field_panel(Control.PRESET_BOTTOM_LEFT,Vector4(18,-230,224,-18),Color("1b1f1a"))
 minimap=Control.new()
 minimap.custom_minimum_size=Vector2(180,140)
 mini_panel.add_child(minimap)
 minimap.mouse_filter=Control.MOUSE_FILTER_STOP
 minimap.gui_input.connect(func(event):
  if event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_LEFT:
   var map_pos=event.position/minimap.size*64-Vector2(32,32)
   camera_focus=Vector3(clampf(map_pos.x,-18,18),0,clampf(map_pos.y,-18,18))
 )
 minimap.draw.connect(draw_minimap)
 var unit_panel=field_panel(Control.PRESET_BOTTOM_LEFT,Vector4(236,-230,566,-18),Color("25281f"))
 var selected_col=VBoxContainer.new()
 unit_panel.add_child(selected_col)
 selected_col.add_child(label("生存者",14,AMBER))
 var unit_row=HBoxContainer.new()
 selected_col.add_child(unit_row)
 selection_portrait=TextureRect.new()
 CommandDeck.mount_portrait(selection_portrait)
 selection_portrait.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
 selection_portrait.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
 selection_portrait.texture=portrait_for("guard")
 unit_row.add_child(selection_portrait)
 selection_info=label("",15,PALE)
 selection_info.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
 selection_info.custom_minimum_size=Vector2(205,64)
 unit_row.add_child(selection_info)
 selected_hp=ProgressBar.new()
 selected_hp.custom_minimum_size=Vector2(294,5)
 selected_hp.show_percentage=false
 selected_hp.add_theme_stylebox_override("background",bar_style(Color("121510"),Color("121510")))
 selected_hp.add_theme_stylebox_override("fill",bar_style(Color("879b64"),Color("879b64")))
 selected_col.add_child(selected_hp)
 var building_actions=HBoxContainer.new()
 selected_col.add_child(building_actions)
 context_button=button("工房 ON/OFF",toggle_inspected,140)
 context_button.visible=false
 building_actions.add_child(context_button)
 dismantle_button=button("解体",request_dismantle,140)
 dismantle_button.visible=false
 building_actions.add_child(dismantle_button)
 xp_bar=ProgressBar.new()
 xp_bar.custom_minimum_size=Vector2(294,8)
 xp_bar.show_percentage=false
 xp_bar.add_theme_stylebox_override("background",bar_style(Color("121510"),Color("121510")))
 xp_bar.add_theme_stylebox_override("fill",bar_style(Color("b89955"),Color("b89955")))
 selected_col.add_child(xp_bar)
 supply_status=label("",14,Color("bcb69d"))
 supply_status.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
 selected_col.add_child(supply_status)
 var command_panel=field_panel(Control.PRESET_BOTTOM_RIGHT,Vector4(-852,-230,-18,-18),Color("252820"))
 var command_col=VBoxContainer.new()
 command_panel.add_child(command_col)
 var tabs=HBoxContainer.new()
 command_col.add_child(tabs)
 tabs.add_child(button("仲間・指示",func():set_command_tab("people"),180))
 tabs.add_child(button("拠点・工作",func():set_command_tab("build"),180))
 tech_button=button("再生工学 [J]  180",start_research,210)
 tabs.add_child(tech_button)
 command_grid=GridContainer.new()
 command_grid.columns=5
 command_grid.add_theme_constant_override("h_separation",7)
 command_grid.add_theme_constant_override("v_separation",7)
 command_col.add_child(command_grid)
 set_command_tab("people")

 hint=label("右クリック: 指示   Shift: 追加選択   矢印: 視点移動   Space: 停止   Backspace: 生産取消",12,Color("999d86"))
 command_col.add_child(hint)
 center_notice=label("",18,AMBER)
 root_ui.add_child(center_notice)
 center_notice.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
 center_notice.offset_left=-380;center_notice.offset_right=380;center_notice.offset_top=77
 center_notice.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
 center_notice.mouse_filter=Control.MOUSE_FILTER_IGNORE
 combo_label=label("",32,AMBER)
 root_ui.add_child(combo_label)
 combo_label.add_theme_font_override("font",command_font)
 combo_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
 combo_label.offset_left=-300;combo_label.offset_right=-26;combo_label.offset_top=98
 combo_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
 combo_label.mouse_filter=Control.MOUSE_FILTER_IGNORE
 drag_overlay=Control.new()
 root_ui.add_child(drag_overlay)
 drag_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 drag_overlay.mouse_filter=Control.MOUSE_FILTER_IGNORE
 drag_overlay.draw.connect(func():
  if dragging:
   var rect=Rect2(drag_start,get_viewport().get_mouse_position()-drag_start).abs()
   drag_overlay.draw_rect(rect,Color(.7,.63,.35,.12),true)
   drag_overlay.draw_rect(rect,AMBER,false,1.5)
  var marked=[]
  for unit in selected:
   if unit.task=="focus_fire" and unit.target!=null and not unit.target.get("dead",false) and is_instance_valid(unit.target.get("node")) and not unit.target in marked:
    marked.append(unit.target)
    var aim=camera.unproject_position(unit.target.node.position+Vector3(0,.9*unit.target.node.scale.y,0))
    drag_overlay.draw_arc(aim,19,0,TAU,24,RED,2)
    drag_overlay.draw_line(aim-Vector2(25,0),aim-Vector2(15,0),RED,2)
    drag_overlay.draw_line(aim+Vector2(15,0),aim+Vector2(25,0),RED,2)
  for collection in [units,buildings]:
   for actor in collection:
    if actor.hp<actor.maxhp and actor.hp>0:
     var p=camera.unproject_position(actor.node.position+Vector3(0,2.2,0))
     drag_overlay.draw_rect(Rect2(p-Vector2(15,0),Vector2(30,4)),Color("171c15"))
     drag_overlay.draw_rect(Rect2(p-Vector2(15,0),Vector2(30*actor.hp/actor.maxhp,4)),Color("afbc84") if actor.hp>actor.maxhp*.4 else RED))
 update_ui()

func field_panel(preset:int,offsets:Vector4,color:Color)->PanelContainer:
 var p=PanelContainer.new()
 root_ui.add_child(p)
 p.set_anchors_and_offsets_preset(preset)
 p.offset_left=offsets.x;p.offset_top=offsets.y;p.offset_right=offsets.z;p.offset_bottom=offsets.w
 var skin=CommandDeck.skin("panel",14)
 p.add_theme_stylebox_override("panel",skin)
 hud_parts.append(p)
 return p

func draw_minimap():
 var size=minimap.size
 minimap.draw_rect(Rect2(Vector2.ZERO,size),Color("111811"))
 for i in range(1,4):
  minimap.draw_line(Vector2(size.x*i/4,0),Vector2(size.x*i/4,size.y),Color("303729"))
  minimap.draw_line(Vector2(0,size.y*i/4),Vector2(size.x,size.y*i/4),Color("303729"))
 if mission.mode=="convoy":
  var route=convoy_route()
  for i in range(1,route.size()):minimap.draw_line((Vector2(route[i-1].x,route[i-1].z)+Vector2(32,32))/64*size,(Vector2(route[i].x,route[i].z)+Vector2(32,32))/64*size,Color("bca866"),2)
  if not convoy_pending.is_empty():
   var threat=ConvoyPlan.encounter(convoy_pending.stage,convoy_route_choice).pos
   minimap.draw_circle((Vector2(threat.x,threat.z)+Vector2(32,32))/64*size,5,RED)
 for block in terrain_blocks:
  var origin=Vector2(block.pos.x-block.size.x*.5,block.pos.z-block.size.z*.5)
  minimap.draw_rect(Rect2((origin+Vector2(32,32))/64*size,Vector2(block.size.x,block.size.z)/64*size),Color("65634f"))
 for s in sites:
  var p=(Vector2(s.node.position.x,s.node.position.z)+Vector2(32,32))/64*size
  minimap.draw_circle(p,3,AMBER if not s.reclaimed else Color("b6c897"))
 for b in buildings:
  var p=(Vector2(b.node.position.x,b.node.position.z)+Vector2(32,32))/64*size
  minimap.draw_rect(Rect2(p-Vector2(2,2),Vector2(4,4)),Color("b6c897"))
 for u in units:
  var p=(Vector2(u.node.position.x,u.node.position.z)+Vector2(32,32))/64*size
  minimap.draw_circle(p,2,Color("d4d6bb") if u in selected else Color("8a9c9f"))
 for e in enemies:
  var p=(Vector2(e.node.position.x,e.node.position.z)+Vector2(32,32))/64*size
  minimap.draw_circle(p,1.3,Color("b45a42"))
 var radar=false
 for b in buildings:
  if b.kind=="relay" and b.powered:radar=true
 if radar or wave_clock<=12:
  var danger=Color("c27545") if wave_clock<=12 else Color("91784c")
  for side in wave_sides(wave+1):
   if side==0:
    minimap.draw_line(Vector2(2,size.y*.20),Vector2(2,size.y*.8),danger,3)
    minimap.draw_colored_polygon(PackedVector2Array([Vector2(3,size.y*.5-5),Vector2(13,size.y*.5),Vector2(3,size.y*.5+5)]),danger)
   elif side==1:
    minimap.draw_line(Vector2(size.x*.2,2),Vector2(size.x*.8,2),danger,3)
    minimap.draw_colored_polygon(PackedVector2Array([Vector2(size.x*.5-5,3),Vector2(size.x*.5,13),Vector2(size.x*.5+5,3)]),danger)
   else:
    minimap.draw_line(Vector2(size.x-2,size.y*.2),Vector2(size.x-2,size.y*.8),danger,3)
    minimap.draw_colored_polygon(PackedVector2Array([Vector2(size.x-3,size.y*.5-5),Vector2(size.x-13,size.y*.5),Vector2(size.x-3,size.y*.5+5)]),danger)
 var view=(Vector2(camera_focus.x,camera_focus.z)+Vector2(32,32))/64*size
 minimap.draw_rect(Rect2(view-Vector2(36,26),Vector2(72,52)),Color("c6b991"),false,1)

func notify(txt:String,duration:float=4):
 center_notice.text=txt
 notice_timer=duration

func toggle_pause():
 if ended or active_card or title_open: return
 paused=not paused
 notify("戦術ポーズ  /  Spaceで再開" if paused else "作戦再開",2)

func set_build(kind:String):
 if active_card or ended:return
 if int(GameRules.building(kind).tech)>tech_level:notify("先に再生工学を研究してください。") ;return
 build_mode=kind
 ghost.visible=true
 notify("左クリックで設置 / 右クリック・Escで取消。近くに工兵が必要。",6)

func select_guards():select_kind("guard")
func select_workers():select_kind("worker")
func select_kind(kind:String):
 inspected={}
 selected.clear()
 for u in units:
  if u.kind==kind or kind=="guard" and u.kind=="grenade":selected.append(u)
 update_selection()

func update_selection():
 for u in units:u.ring.visible=u in selected
 update_ui()

func recruit(kind:String):
 if ended or active_card:return
 if int(GameRules.unit(kind).tech)>tech_level:notify("先に再生工学を研究してください。") ;return
 var cost=UNIT_COSTS.get(kind,45)
 if resources<cost:notify("資材が不足しています。") ;return
 if units.size()+recruit_queue.size()>=28:notify("部隊上限28に到達。") ;return
 resources-=cost
 recruit_queue.append({"kind":kind,"time":float(GameRules.unit(kind).time),"cost":cost})
 tone("build")
 notify("生産を予約。Backspaceで最後の予約を取消。",3)

func cancel_recruit():
 if recruit_queue.is_empty():return
 resources+=recruit_queue.pop_back().cost
 notify("生産予約を取消。資材を返却しました。",2)

func assign_site(kind:String):
 if ended or active_card:return
 var site=get_site(kind)
 var workers=[]
 for u in selected:
  if u.kind=="worker":workers.append(u)
 if workers.is_empty():
  for u in units:
   if u.kind=="worker":workers.append(u)
 if workers.is_empty():notify("工兵がいません。Wで工兵を配備。") ;return
 for u in workers:
  u.task="site"
  u.target=site
  u.goal=site.node.position+Vector3(rng.randf_range(-1,1),0,2.5)
 notify("工兵に復旧を指示。未復旧設備は資材50を消費。",4)

func get_site(kind:String)->Dictionary:
 for s in sites:
  if s.kind==kind:return s
 return {}

func toggle_generator():
 if ended or active_card:return
 if not get_site("generator").reclaimed:notify("先に工兵で発電所を復旧してください。") ;return
 generator_on=not generator_on
 if generator_on and not first_activation:
  first_activation=true
  incoming_surge=true
  wave_clock=minf(wave_clock,12)
 notify("発電所 起動：塔が強化 / 騒音で群れを誘引" if generator_on else "発電所 停止：騒音低下 / 揚水停止",5)
 tone("power")

func ground_at(screen:Vector2)->Vector3:
 var from=camera.project_ray_origin(screen)
 var dir=camera.project_ray_normal(screen)
 var t=-from.y/dir.y
 return from+dir*t

func _unhandled_input(event):
 if is_instance_valid(dismantle_panel):
  if event is InputEventKey and event.pressed and event.keycode==KEY_ESCAPE:close_dismantle()
  return
 if event is InputEventKey and event.pressed and not event.echo:
  if event.keycode==KEY_F6:
   save_checkpoint()
  if event.keycode==KEY_F12:
   capture_frame()
  if title_open:return
  if is_instance_valid(dismantle_panel):
   if event.keycode==KEY_ESCAPE:close_dismantle()
   return
  if is_instance_valid(route_panel):
   if event.keycode==KEY_ESCAPE:close_route_choice()
   return
  if is_instance_valid(options_panel):
   if event.keycode==KEY_ESCAPE:close_options()
   return
  if event.keycode==KEY_G:
   attack_move=true
   notify("攻撃移動：右クリックで目的地を指定。敵を射程に捉えると停止して迎撃。")
  if event.keycode==KEY_ESCAPE:
   if is_instance_valid(options_panel):close_options()
   build_mode=""
   ghost.visible=false
  if event.keycode==KEY_SPACE:toggle_pause()
  if active_card:
   if is_instance_valid(choice_panel) and event.keycode in [KEY_1,KEY_2,KEY_3]: choose_upgrade(int(event.keycode-KEY_1))
   return
  if ended:return
  match event.keycode:
   KEY_DELETE:
    if event.shift_pressed:request_dismantle()
   KEY_Q:recruit("guard")
   KEY_W:
    if not event.ctrl_pressed:recruit("worker")
   KEY_E:set_build("tower")
   KEY_R:set_build("wall")
   KEY_U:set_build("factory")
   KEY_Y:set_build("relay")
   KEY_T:recruit("truck")
   KEY_V:recruit("grenade")
   KEY_B:set_build("mortar")
   KEY_N:set_build("yard")
   KEY_J:start_research()
   KEY_BACKSPACE:cancel_recruit()
   KEY_F:toggle_generator()
   KEY_1:select_guards()
   KEY_2:select_workers()
   KEY_H:camera_focus=Vector3.ZERO
 if active_card or ended or title_open:return
 if event is InputEventMouseButton:
  if event.button_index==MOUSE_BUTTON_WHEEL_UP:camera.size=maxf(26,camera.size-3)
  if event.button_index==MOUSE_BUTTON_WHEEL_DOWN:camera.size=minf(85,camera.size+3)
  if event.button_index==MOUSE_BUTTON_RIGHT and event.pressed:
   if not build_mode.is_empty():
    build_mode=""
    ghost.visible=false
   else: command_at(ground_at(event.position),event.position)
  if event.button_index==MOUSE_BUTTON_LEFT:
   if event.pressed:
    if not build_mode.is_empty():place_building(ground_at(event.position));return
    dragging=true
    drag_start=event.position
   elif dragging:
    dragging=false
    select_rect(drag_start,event.position,event.shift_pressed)
    drag_overlay.queue_redraw()

func select_rect(a:Vector2,b:Vector2,append:bool=false):
 inspected={}
 if not append:selected.clear()
 var rect=Rect2(a,b-a).abs()
 for u in units:
  if u.kind=="convoy":continue
  var p=camera.unproject_position(u.node.position+Vector3(0,.8,0))
  if (rect.size.length()<10 and p.distance_to(b)<24) or (rect.size.length()>=10 and rect.has_point(p)):
   if not u in selected:selected.append(u)
 if selected.is_empty() and rect.size.length()<10:
  var ground=ground_at(b)
  for building in buildings:
   if ground.distance_to(building.node.position)<building.radius+1:inspected=building;break
 update_selection()

func command_at(p:Vector3,screen:Vector2=Vector2.INF):
 if selected.is_empty():notify("先に部隊を選択してください。1で全警備兵、2で全工兵。") ;return
 p.x=clampf(p.x,-28,28)
 p.z=clampf(p.z,-28,28)
 var enemy_target:Variant=null
 var nearest=28.0 if screen!=Vector2.INF else 2.6
 for enemy in enemies:
  if enemy.dead:continue
  var separation=camera.unproject_position(enemy.node.position+Vector3(0,.9*enemy.node.scale.y,0)).distance_to(screen) if screen!=Vector2.INF else enemy.node.position.distance_to(p)
  if separation<nearest:nearest=separation;enemy_target=enemy
 if enemy_target!=null:
  var fighters=0
  for u in selected:
   if u.kind not in ["guard","grenade"]:continue
   u.task="focus_fire";u.target=enemy_target;u.goal=enemy_target.node.position;u.planned=Vector3.INF;u["focus_repath"]=0.0
   fighters+=1
  if fighters>0:
   attack_move=false
   pulse(enemy_target.node.position,RED,2.2,.5)
   notify("集中攻撃："+("破砕体" if enemy_target.get("boss",false) else "重装感染者" if enemy_target.get("armored",false) else "感染者"),3)
   tone("order")
  return
 var s_target:Variant=null
 var b_target:Variant=null
 for b in buildings:
  if b.built<1 and b.node.position.distance_to(p)<3:b_target=b
 for s in sites:
  if s.node.position.distance_to(p)<3:s_target=s
 for i in selected.size():
  var u=selected[i]
  u.goal=p+Vector3((i%4-1.5)*1.1,0,floori(i/4.0)*1.1)
  u.task="attack_move" if attack_move and u.kind in ["guard","grenade"] else "move"
  u.target=null
  if u.kind=="worker" and s_target!=null:
   u.task="site"
   u.target=s_target
   u.goal=s_target.node.position+Vector3((i%3-1)*.9,0,2.2)
  elif u.kind=="worker" and b_target!=null:
   u.task="build"
   u.target=b_target
   u.goal=b_target.node.position+Vector3(0,0,2)
 attack_move=false
 pulse(p,CYAN,1.5,.55)
 tone("order")

func place_building(p:Vector3)->bool:
 if int(GameRules.building(build_mode).tech)>tech_level:notify("再生工学の研究が必要です。") ;return false
 var cost=BUILD_COSTS.get(build_mode,65)
 if resources<cost:notify("資材不足。設置は取消されず、資材は消費しません。") ;return false
 if absf(p.x)>25 or absf(p.z)>25:notify("作戦区域の外には建設できません。") ;return false
 for block in terrain_blocks:
  if absf(p.x-block.pos.x)<block.size.x*.5+1.8 and absf(p.z-block.pos.z)<block.size.z*.5+1.8:
   notify("瓦礫や設備を避けて設置してください。")
   return false
 for b in buildings:
  if b.node.position.distance_to(p)<b.radius+2:notify("他の建物に近すぎます。") ;return false
 for s in sites:
  if s.node.position.distance_to(p)<4.3:notify("復旧・回収の作業空間を確保してください。") ;return false
 var worker:Variant=null
 var best=18.0
 for u in units:
  if u.kind=="worker" and u.node.position.distance_to(p)<best:
   worker=u
   best=u.node.position.distance_to(p)
 if worker==null:notify("18m以内に工兵が必要。工兵を前線へ移動させてください。") ;return false
 resources-=cost
 var b=make_building(build_mode,p)
 b.paid_cost=cost
 worker.task="build"
 worker.target=b
 worker.goal=p+Vector3(0,0,2)
 tone("build")
 build_mode=""
 ghost.visible=false
 notify("建設開始。工兵が到着すると組み立てます。",3)
 return true

func _process(delta):
 var script_start=Time.get_ticks_usec()
 var simulation_usec=0
 render_frames+=1
 var dt=minf(delta,.05)
 shot_tick-=delta
 notice_timer-=delta
 if notice_timer<=0:center_notice.text=""
 drag_overlay.queue_redraw()
 if ghost.visible:ghost.position=ground_at(get_viewport().get_mouse_position())+Vector3(0,.08,0)
 var pan=Vector3.ZERO
 if Input.is_physical_key_pressed(KEY_LEFT) or Input.is_physical_key_pressed(KEY_A):pan+=Vector3(-1,0,1)
 if Input.is_physical_key_pressed(KEY_RIGHT) or Input.is_physical_key_pressed(KEY_D):pan+=Vector3(1,0,-1)
 if Input.is_physical_key_pressed(KEY_UP):pan+=Vector3(-1,0,-1)
 if Input.is_physical_key_pressed(KEY_DOWN) or Input.is_physical_key_pressed(KEY_S):pan+=Vector3(1,0,1)
 camera_focus+=pan*dt*16
 camera_focus.x=clampf(camera_focus.x,-18,18)
 camera_focus.z=clampf(camera_focus.z,-18,18)
 camera.position=camera_focus+Vector3(37,48,43)
 camera.look_at(camera_focus)
 update_effects(dt)
 if not paused and not active_card and not ended and not title_open:
  var sim_start=Time.get_ticks_usec()
  simulate(dt)
  simulation_usec=Time.get_ticks_usec()-sim_start
  auto_save_clock-=dt
  if auto_save_clock<=0:
   auto_save_clock=30
   save_checkpoint(false)
 horde_renderer.update_horde(enemies+corpses,elapsed)
 horde_renderer.update_friends(units)
 battle_visibility.update_visibility(camera,units,enemies,shells,delta)
 battle_fx.update(dt,camera)
 if pending_card_delay>0:
  pending_card_delay-=dt
  if pending_card_delay<=0 and active_card and not ended:display_cards()
 update_ui()
 if debug_run:
  if render_frames>20:
   showcase_frame_ms.append(delta*1000)
   showcase_script_ms.append((Time.get_ticks_usec()-script_start)/1000.0)
   showcase_sim_ms.append(simulation_usec/1000.0)
  showcase_step()

func simulate(dt:float):
 elapsed+=dt
 update_economy(dt)
 threat_voice_clock-=dt
 audio_system.set_power(generator_on)
 audio_system.set_threat(clampf(float(enemies.size())/160,0,1))
 if threat_voice_clock<=0 and not enemies.is_empty():
  audio_system.play_event("infected_growl" if enemies.size()>60 else "infected_moan",enemies[0].node.position)
  threat_voice_clock=visual_rng.randf_range(5,10)
 noise=move_toward(noise,75 if generator_on else 12,dt*5)
 wave_clock-=dt
 combo_clock-=dt
 if combo_clock<=0:combo=0
 if wave_clock<=0:
  wave+=1
  spawn_wave()
  wave_clock=maxf(14,30-wave*.8)-4 if generator_on else maxf(26,34-wave*.4)
 update_shells(dt)
 update_corpses(dt)
 for u in units.duplicate():
  if u.hp<=0:
   if u.kind=="convoy":
    failure_reason="輸送隊が感染群に飲まれた。"
    finish(false)
    return
   if u in selected:selected.erase(u)
   units.erase(u)
   pulse(u.node.position,RED,1,.3)
   u.node.queue_free()
   continue
  u.cd-=dt
  if u.task=="focus_fire":
   if u.target==null or u.target.get("dead",false) or not is_instance_valid(u.target.get("node")):
    u.task="idle";u.target=null;u.goal=u.node.position;u.route.clear();u.planned=Vector3.INF
   else:
    u["focus_repath"]=float(u.get("focus_repath",0))-dt
    if u.focus_repath<=0:
     u.goal=u.target.node.position;u.focus_repath=.3
  var previous_position=u.node.position
  var distance=u.node.position.distance_to(u.goal)
  var stop_to_fire=u.task=="attack_move" and nearest_enemy(u.node.position,float(GameRules.unit(u.kind).range)*(1+bonus("range","range_add")))!=null
  if u.task=="focus_fire" and u.target!=null:stop_to_fire=u.node.position.distance_to(u.target.node.position)<=float(GameRules.unit(u.kind).range)*(1+bonus("range","range_add"))*.97
  if distance>.35 and not stop_to_fire:
   if u.planned!=u.goal:
    u.route=route_to(u.node.position,u.goal)
    var safe_end=open_cell(u.goal,u.node.position)
    u.goal=Vector3(safe_end.x,0,safe_end.y)
    u.planned=u.goal
   var waypoint=u.goal
   if not u.route.is_empty():
    waypoint=u.route[0]
    if u.node.position.distance_to(waypoint)<.3:
     u.route.pop_front()
     if not u.route.is_empty():waypoint=u.route[0]
   var direction=(waypoint-u.node.position).normalized()
   u.node.position+=direction*dt*float(GameRules.unit(u.kind).speed)*(1+bonus("move","move_speed_add"))
   u.node.rotation.y=atan2(-direction.x,-direction.z)
  elif u.task=="site" and u.target!=null:
   work_site(u,dt)
  elif u.task=="build" and u.target!=null:
   var b=u.target
   if is_instance_valid(b.node):
    b.built=minf(1,b.built+dt*.13*construction_multiplier())
    b.node.scale.y=.2+.8*b.built
    if b.built>=1:u.task="idle";tone("build")
   else:u.task="idle"
  if u.kind in ["guard","grenade"] and u.cd<=0:
   var weapon=GameRules.unit(u.kind)
   var range_value=float(weapon.range)*(1+bonus("range","range_add"))
   var target:Variant=null
   if u.task=="focus_fire":
    if u.target!=null and u.node.position.distance_to(u.target.node.position)<=range_value:target=u.target
   else:target=nearest_enemy(u.node.position,range_value)
   if target!=null:
    fire(u.node.position+Vector3(0,1,0),target,float(weapon.damage),u.kind,u)
    u.cd=float(weapon.cooldown)/(1+bonus("rate","attack_speed_add"))
    u["shot_cycle"]=u.cd
  if u.kind not in ["truck","convoy"]:
   var attack_age=elapsed-float(u.get("attack_at",-100))
   var cycle=float(u.get("shot_cycle",.72))
   var reload_phase=clampf((attack_age-.2)/maxf(.2,cycle-.2),0,1) if attack_age>.2 and attack_age<cycle else -1.0
   ActorVisuals.pose(u.node,elapsed*8+u.node.get_instance_id()%17,u.node.position.distance_to(previous_position)>.001,attack_age,reload_phase,u.kind=="worker" and u.task in ["site","build"] and u.node.position.distance_to(u.goal)<.5)
 for b in buildings.duplicate():
  if b.hp<=0:
   if b.kind=="hq":finish(false);return
   buildings.erase(b)
   rebuild_navigation()
   pulse(b.node.position,RED,3,.5)
   b.node.queue_free()
   continue
  if b.kind in ["tower","mortar"] and b.built>=1:
   b.cd-=dt
   if b.kind=="mortar" and not b.powered:continue
   if b.cd<=0:
    var weapon_range=22.0 if b.kind=="mortar" else 15.5 if b.powered else 12.5
    var e=nearest_enemy(b.node.position,weapon_range*(1+bonus("range","range_add")))
    if e!=null:
     fire(b.node.position+Vector3(0,2.4 if b.kind=="mortar" else 3.3,0),e,85 if b.kind=="mortar" else 28 if b.powered else 19,b.kind,b)
     b.cd=(3.2 if b.kind=="mortar" else .48)/(1+bonus("rate","attack_speed_add"))
 crowd_steering.prepare(enemies)
 for e in enemies.duplicate():
  if e.dead:continue
  var target:Variant=buildings[0] if not buildings.is_empty() else null
  var best=INF
  for b in buildings:
   var dis=e.node.position.distance_to(b.node.position)-b.radius
   if dis<best:best=dis;target=b
  for u in units:
   var dis=e.node.position.distance_to(u.node.position)-(1.8 if u.kind=="convoy" else .6 if u.kind=="truck" else 0)
   if dis<best and dis<(10 if u.kind=="convoy" else 6):best=dis;target=u
  if e.get("convoy_hunter",false):
   var cargo=convoy_unit()
   if not cargo.is_empty():target=cargo;best=e.node.position.distance_to(cargo.node.position)-1.8
  if target==null:continue
  if e.get("boss",false) and e.windup>0:
   e.windup-=dt
   if e.windup<=0:boss_impact(e)
   continue
  if upgrades.get("storm",0)>0:
   for wall in buildings:
    if wall.kind=="wall" and wall.built>=1 and e.node.position.distance_to(wall.node.position)<2.7:e.charged_until=elapsed+4
  var can_attack=best<=(3.8 if e.get("boss",false) else 1.3)
  if not can_attack:
   e.path_cd-=dt
   if e.path_cd<=0 or e.route.is_empty():
    e.route=enemy_route(e.node.position,target)
    e.path_cd=1.2
   if not e.route.is_empty():
    var waypoint=e.route[0]
    if e.node.position.distance_to(waypoint)<.6:
     e.route.pop_front()
     if not e.route.is_empty():waypoint=e.route[0]
    var direction=(waypoint-e.node.position).normalized()
    var movement:Vector3=crowd_steering.steer(e.node,direction,dt,e.speed,nav)
    e.node.position+=movement
    if movement.length_squared()>.000001:e.node.rotation.y=atan2(-movement.x,-movement.z)
   elif best<2.5:can_attack=true
  if can_attack:
   e.cd-=dt
   if e.cd<=0:
    if e.get("boss",false):
     e.windup=1.4;e.attack_pos=target.node.position
     pulse(e.attack_pos,RED,4.5,1.4)
     continue
    e["attack_at"]=elapsed
    target.hp-=18 if e.get("armored",false) else 9
    e.cd=.9 if e.get("armored",false) else .75
    if not low_fx:pulse(target.node.position,RED,.6,.15)

 drain_blast_queue()
 if buildings.is_empty() or buildings[0].hp<=0:
  failure_reason="拠点を失った。"
  finish(false)
  return
 var convoy=convoy_unit()
 if convoy_started and (convoy.is_empty() or convoy.hp<=0):
  failure_reason="輸送隊が感染群に飲まれた。"
  finish(false)
  return
 update_mission(dt)
 if ended:return
 if xp>=xp_needed() and not active_card:offer_upgrade()

func work_site(u:Dictionary,dt:float):
 var s=u.target
 if s.kind=="scrap":
  if s.stock<=0:u.task="idle";return
  u.work+=dt
  if u.work>=1.2/(1+bonus("salvage","salvage_speed_add")):
   u.work=0
   var amount=minf(s.stock,4*(1.4 if near_yard(u.node.position) else 1.0))
   s.stock-=amount
   resources+=amount
   gathered+=amount
   pulse(u.node.position,AMBER,.45,.3)
 elif not s.reclaimed:
  if not s.paid:
   if resources<50:
    if u.work<=0:notify("復旧には資材50が必要。残骸を回収してください。")
    u.work=3
    u.work-=dt
    return
   resources-=50
   s.paid=true
  s.progress=minf(1,s.progress+dt*.035)
  if s.progress>=1:
   s.reclaimed=true
   if s.kind=="pump":rerolls+=1
   s.label.text=site_title(s.kind)+" [復旧済]"
   s.label.modulate=CYAN
   pulse(s.node.position,CYAN,5,1)
   tone("power")
   notify("発電所を復旧。Fで起動し、揚水場にも工兵を。" if s.kind=="generator" else mission.facility+"を復旧。発電所を起動して防衛。",7)
 else:
  u.task="idle"

func nearest_enemy(p:Vector3,radius:float,excluded:Array=[])->Variant:
 var best=radius*radius
 var found:Variant=null
 for e in enemies:
  if e.dead or e in excluded:continue
  var d=p.distance_squared_to(e.node.position)
  if d<best:best=d;found=e
 return found

func fire(origin:Vector3,target:Dictionary,base:float,kind:String,source:Dictionary={}):
 if not source.is_empty():
  source["attack_at"]=elapsed
  if kind in ["guard","grenade"]:
   var aim=target.node.position-source.node.position
   if aim.length_squared()>.01:source.node.rotation.y=atan2(-aim.x,-aim.z)
 var ammo_cost=(3.0 if kind in ["grenade","mortar"] else 1.0)*maxf(.4,1-bonus("supply","ammo_reduction_add")-(.1 if kind in ["guard","grenade"] and mobile_aura(origin) else 0.0))
 var supplied=ammo>=ammo_cost
 if supplied:ammo-=ammo_cost
 var damage=base*(1+bonus("damage","damage_add"))*(1 if supplied else .4)
 var conditional=bonus("overload","conditional_damage_add") if noise>=60 else 0.0
 if kind in ["guard","grenade"] and mobile_aura(origin):conditional+=.2
 damage*=1+minf(.5,conditional)
 var critical=rng.randf()<bonus("crit","crit_chance_add")
 if critical:damage*=1.5+bonus("critpower","crit_multiplier_add")
 var pos=target.node.position
 if kind in ["grenade","mortar"]:
  var radius=3.0 if kind=="grenade" else 4.1
  launch_shell(origin,pos,damage,radius,kind,critical)
  var shell_targets=[target]
  for i in int(upgrades.get("multi",0)):
   var extra=nearest_enemy(pos,7,shell_targets)
   if extra==null:break
   shell_targets.append(extra)
   launch_shell(origin,extra.node.position,damage*.65,radius,kind,false)
  if kind=="mortar" and not source.is_empty():
   source.shots+=1
   var interval=4 if upgrades.get("salvo",0)>1 else 6
   if upgrades.get("salvo",0)>0 and int(source.shots)%interval==0:
    var forward=Vector3(pos.x-origin.x,0,pos.z-origin.z).normalized()
    var across=Vector3(-forward.z,0,forward.x)
    for side in [-1,1]:launch_shell(origin,pos+across*side*3.6,damage*.6,radius,kind,false)
    if upgrades.get("sweep",0)>0:
     for distance in [4.0,8.0]:launch_shell(origin,pos+forward*distance,damage*.6,radius,kind,false)
  return
 battle_fx.muzzle(origin,false)
 beam(origin,pos+Vector3(0,.7,0),Color("fff1bd") if critical else AMBER,.10)
 var hit_targets=[target]
 hit(target,damage,true,0,false,critical)
 var direction=Vector3(pos.x-origin.x,0,pos.z-origin.z).normalized()
 if upgrades.get("pierce",0)>0:
  for other in enemies.duplicate():
   if other.dead or other in hit_targets:continue
   var offset=other.node.position-pos
   if offset.dot(direction)>0 and offset.dot(direction)<7 and offset.cross(direction).length()<.9:
    hit_targets.append(other)
    beam(pos+Vector3(0,.7,0),other.node.position+Vector3(0,.7,0),AMBER,.10)
    hit(other,damage,false)
    if hit_targets.size()>upgrades.pierce:break
 if shot_tick<=0:
  audio_system.play_event("rifle",origin)
  shot_tick=.07
 for i in int(upgrades.get("multi",0)):
  var other=nearest_enemy(pos,6,hit_targets)
  if other==null:break
  hit_targets.append(other)
  beam(origin,other.node.position+Vector3(0,.7,0),AMBER,.12)
  hit(other,damage*.65,false)
 if upgrades.get("chain",0)>0:
  audio_system.play_event("chain",origin)
  var used=[target]
  var last=pos
  var hops=mini(5,2*int(upgrades.chain)+int(upgrades.get("storm",0)))
  for i in hops:
   var other=nearest_enemy(last,4.5,used)
   if other==null:break
   beam(last+Vector3(0,.8,0),other.node.position+Vector3(0,.8,0),Color("91c3df"),.22)
   last=other.node.position
   used.append(other)
   hit(other,damage*pow(.65,i+1),false,0,true)
 if kind=="tower" and not source.is_empty():
  source.shots+=1
  var interval=4 if upgrades.get("salvo",0)>1 else 6
  if upgrades.get("salvo",0)>0 and int(source.shots)%interval==0:
   salvo(origin,pos,damage)

func salvo(origin:Vector3,target_pos:Vector3,damage:float):
 var direction=Vector3(target_pos.x-origin.x,0,target_pos.z-origin.z).normalized()
 var flat_origin=Vector3(origin.x,0,origin.z)
 var sweep=upgrades.get("sweep",0)>0
 var width=2.5 if sweep else 1.4
 var targets=[]
 for e in enemies:
  var off=e.node.position-flat_origin
  if off.dot(direction)>0 and off.dot(direction)<22 and off.cross(direction).length()<width:targets.append(e)
 targets.sort_custom(func(a,b):return origin.distance_squared_to(a.node.position)<origin.distance_squared_to(b.node.position))
 var limit=6 if sweep else 3
 for i in mini(limit,targets.size()):hit(targets[i],damage,false)
 beam(flat_origin+Vector3(0,.7,0),flat_origin+Vector3(0,.7,0)+direction*22,Color("f4d9a0"),.25,.35 if sweep else .16)
 if sweep:
  var side=direction.cross(Vector3.UP).normalized()*2
  beam(flat_origin+Vector3(0,.7,0)+side,flat_origin+Vector3(0,.7,0)+side+direction*22,AMBER,.25,.25)
  var second=0
  for e in enemies.duplicate():
   if e in targets:continue
   var off=e.node.position-flat_origin-side
   if off.dot(direction)>0 and off.dot(direction)<22 and off.cross(direction).length()<1.4:
    hit(e,damage,false)
    second+=1
    if second>=6:break
 tone("blast")

func hit(e:Dictionary,damage:float,direct:bool,generation:int=0,electric:bool=false,critical:bool=false):
 if e.dead:return
 var dealt=damage
 if e.get("armored",false):dealt*=minf(1,.65+.12*upgrades.get("pierce",0))
 if electric and e.get("charged_until",0)>elapsed:dealt*=1.25
 e.hp-=dealt
 audio_system.play_event("impact_armor" if e.get("armored",false) else "impact_flesh",e.node.position,.6 if not direct else 1.0)
 e.hit_until=elapsed+.12
 if e.get("boss",false) and is_instance_valid(e.get("boss_label")):e.boss_label.text="破砕体 %d%%"%maxi(0,ceili(e.hp/3600*100))
 e.hit_kind="critical" if critical else "armored" if e.get("armored",false) else "normal"
 e.hit_reduced=low_fx
 if e.hp>0:
  if not low_fx:impact_spark(e.node.position+Vector3(0,.8,0),e.hit_kind)
  return
 e.dead=true
 var p=e.node.position
 kills+=1
 xp+=90 if e.get("boss",false) else 12 if e.get("armored",false) else 6
 if e.get("boss",false):boss_defeated=true;audio_system.play_event("ruin_collapse",p,1.4)
 combo+=1
 combo_clock=3
 if kills%25==0 and upgrades.get("economy",0)>0:victory_boost=8
 if combo in [25,50,100,250]:audio_system.play_event("combo_%d"%combo,p)
 if combo>=50 and combo%25==0:audio_system.play_event("kill_sweep",p)
 enemies.erase(e)
 if not low_fx and corpses.size()<(32 if performance_mode else 96):
  e.node.position.y=.12
  corpses.append({"node":e.node,"dead":false,"armored":e.get("armored",false),"speed":e.speed,"moving":false,"life":3.5,"lean":visual_rng.randf_range(-1.5,1.5),"scale":e.node.scale,"start":e.node.transform})
 else:e.node.queue_free()
 if upgrades.get("blast",0)>0 and (direct or (generation>0 and generation<2 and upgrades.get("cascade",0)>0)):
  var radius=2*(1+bonus("blast_radius","blast_radius_add"))
  var blast_damage=damage*(.2+.2*upgrades.blast) if direct else damage*.5
  blast_queue.append({"pos":p,"radius":radius,"damage":blast_damage,"generation":generation+1})

func drain_blast_queue():
 var processed=0
 while not blast_queue.is_empty() and processed<64:
  var event=blast_queue.pop_front()
  battle_fx.blast(event.pos,event.radius,false,low_fx)
  if processed==0:tone("blast")
  for other in enemies.duplicate():
   if not other.dead and other.node.position.distance_to(event.pos)<event.radius:hit(other,event.damage,false,event.generation)
  processed+=1

func wave_side(number:int)->int:
 if campaign_state.current==1:return 0 if number%2==0 else 2
 return number%3

func wave_sides(number:int)->Array:
 var sides=[wave_side(number)]
 if campaign_state.current==2 and number>=3:sides.append((sides[0]+1)%3)
 return sides

func wave_direction_text(number:int)->String:
 var words=PackedStringArray()
 for side in wave_sides(number):words.append(["西","北","東"][side])
 return "・".join(words)

func spawn_wave():
 var count=18+wave*9+(35 if generator_on else 0)
 if incoming_surge:
  count+=45
  incoming_surge=false
 count=mini(int(count*(mission.pressure if generator_on else 1.0)),250)
 var side=wave_side(wave)
 for i in count:
  var spawn_side=(side+(1 if i%3==0 else 0))%3 if campaign_state.current==2 and wave>=3 else side
  var p=Vector3(-28+rng.randf_range(-1,1),0,rng.randf_range(-20,15)) if spawn_side==0 else (Vector3(rng.randf_range(-24,24),0,-28+rng.randf_range(-1,1)) if spawn_side==1 else Vector3(28+rng.randf_range(-1,1),0,rng.randf_range(-20,15)))
  var armored=generator_on and campaign_state.current>=1 and wave>=4 and i%(10 if campaign_state.current==2 else 16)==0
  var fast=wave>=2 and i%(3 if campaign_state.current==1 else 5)==0 and not armored
  spawn_enemy(p,fast,armored)
 notify("襲撃 %02d  /  %sから %d体接近"%[wave,wave_direction_text(wave),count],6)
 tone("warning")

func xp_needed()->float:return 60+float(level-1)*35

func offer_upgrade():
 xp-=xp_needed()
 level+=1
 cards=UpgradeCatalog.draw_for_level(upgrades,card_rng,level,preferred_family,family_misses)
 if not preferred_family.is_empty():
  var found=false
  for card in cards:
   if card.get("family","")==preferred_family:found=true
  family_misses=0 if found else family_misses+1
 active_card=true
 dragging=false;build_mode="";ghost.visible=false
 pending_card_delay=.28

func reroll_cards():
 if not active_card or rerolls<=0:return
 rerolls-=1
 cards=UpgradeCatalog.draw_for_level(upgrades,card_rng,level,preferred_family,family_misses)
 if is_instance_valid(choice_panel):choice_panel.queue_free()
 display_cards()

func display_cards():
 pending_card_delay=0
 active_card=true
 dragging=false
 build_mode=""
 ghost.visible=false
 tone("level")
 choice_panel=PanelContainer.new()
 root_ui.add_child(choice_panel)
 choice_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 choice_panel.add_theme_stylebox_override("panel",style(Color("10130fee"),Color("10130f")))
 var center=CenterContainer.new()
 choice_panel.add_child(center)
 var content=VBoxContainer.new()
 content.add_theme_constant_override("separation",16)
 center.add_child(content)
 var heading=label("生存者の成長",36,PALE)
 content.add_child(heading)
 var sub=label("SURVIVORS %02d  /  生き延びる力を選ぶ"%level,17,AMBER)
 sub.add_theme_font_override("font",command_font)
 content.add_child(sub)
 var row=HBoxContainer.new()
 row.add_theme_constant_override("separation",18)
 content.add_child(row)
 for i in 3:
  var data=cards[i]
  var b=button("",func():choose_upgrade(i),350)
  b.custom_minimum_size=Vector2(350,550)
  b.add_theme_stylebox_override("normal",style(Color("c9c0a5"),Color("625c48")))
  b.add_theme_stylebox_override("hover",style(Color("dfd2ad"),AMBER))
  b.add_theme_stylebox_override("pressed",style(Color("aa9e7e"),AMBER))
  CommandDeck.style_button(b,true)
  row.add_child(b)
  var v=VBoxContainer.new()
  b.add_child(v)
  v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
  v.offset_left=22;v.offset_right=-22;v.offset_top=18;v.offset_bottom=-18
  v.mouse_filter=Control.MOUSE_FILTER_IGNORE
  v.add_theme_constant_override("separation",10)
  var ink=Color("303329")
  var tier={"basic":"基礎装備","advanced":"戦術改装","ultimate":"決戦仕様","fallback":"補給指令"}.get(data.get("tier","basic"),"装備")
  var serial=label("0%d    /    %s"%[i+1,tier],15,Color("71603d"))
  serial.add_theme_font_override("font",command_font)
  v.add_child(serial)
  var name_label=label(data.name,29,ink)
  v.add_child(name_label)
  v.add_child(equipment_diagram(data.id))
  var desc=label(data.desc,17,ink)
  desc.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
  desc.custom_minimum_size=Vector2(300,62)
  v.add_child(desc)
  var change=label(upgrade_preview(data),16,Color("654b20"))
  change.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
  change.custom_minimum_size.x=300
  v.add_child(change)
  var route=upgrade_route_text(data.id)
  if not route.is_empty():
   var next=label(route,14,Color("595c48"))
   next.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
   next.custom_minimum_size.x=300
   v.add_child(next)
  var rank=int(upgrades.get(data.id,0))+1
  var footer="採用  [%d]"%[i+1]
  if data.get("max_rank",-1)>0:footer+="    RANK %d / %d"%[rank,data.max_rank]
  v.add_child(label(footer,14,Color("71603d")))
  for child in v.get_children():child.mouse_filter=Control.MOUSE_FILTER_IGNORE
 var reroll_button=button("候補更新  /  残り%d回"%rerolls,reroll_cards,260)
 reroll_button.disabled=rerolls<=0
 content.add_child(reroll_button)

func equipment_diagram(id:String)->Control:
 return CommandDeck.equipment(UpgradeCatalog.family_for(id))

func choose_upgrade(index:int):
 if not active_card or index>=cards.size():return
 var data=cards[index]
 upgrades[data.id]=upgrades.get(data.id,0)+1
 if data.id in ["chain","blast","multi","salvo","storm","cascade","sweep","fortress"]:
  var family=UpgradeCatalog.family_for(data.id)
  if family!=preferred_family:family_misses=0
  preferred_family=family
 if data.id=="armor":
  for u in units:
   var increase=u.basehp*.2
   u.maxhp+=increase;u.hp=minf(u.maxhp,u.hp+increase)
  for b in buildings:
   if b.kind!="hq":b.maxhp+=b.basehp*.2;b.hp=minf(b.maxhp,b.hp+b.basehp*.2)
 if data.id=="reserve":resources+=80
 if data.id=="reserve2":build_boost=12
 if data.id=="field_repair":
  for u in units:u.hp=u.maxhp
  for b in buildings:b.hp=b.maxhp
 active_card=false
 if is_instance_valid(choice_panel):choice_panel.queue_free()
 tone("power")
 notify("成長："+data.name,4)

func finish(won:bool):
 if ended:return
 ended=true
 if won:
  campaign_state.complete(elapsed,kills)
  for child in get_children():
   if child.has_method("restore_district_lights"):child.restore_district_lights()
  if mission.mode=="convoy":camera_focus=Vector3(18,0,18)
 if FileAccess.file_exists("user://checkpoint.json"):DirAccess.remove_absolute("user://checkpoint.json")
 active_card=false
 if is_instance_valid(choice_panel):choice_panel.queue_free()
 modal=PanelContainer.new()
 root_ui.add_child(modal)
 modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 modal.add_theme_stylebox_override("panel",style(Color("171b16c4")))
 var center=CenterContainer.new()
 modal.add_child(center)
 var v=VBoxContainer.new()
 v.add_theme_constant_override("separation",22)
 center.add_child(v)
 v.add_child(label("都市に、灯が戻った。" if won else "防衛線、崩壊。",42,CYAN if won else RED))
 v.add_child(label("OPERATION COMPLETE" if won else "COMMAND LOST",20,AMBER))
 v.add_child(label("経過 %02d:%02d  /  撃破 %d  /  生存者 Lv.%d"%[int(elapsed)/60,int(elapsed)%60,kills,level],21))
 v.add_child(label(ConvoyPlan.ending(campaign_state.current) if won else failure_reason,18))
 if won and campaign_state.current<2:
  v.add_child(button("次の作戦へ",func():start_mission(campaign_state.current+1),440))
 elif won:
  v.add_child(label("全3作戦 完了 / オルタ湾に生活圏を再建",20,CYAN))
 v.add_child(button("この作戦をもう一度",func():start_mission(campaign_state.current),440))
 v.add_child(button("作戦選択へ",return_title,440))
 audio_system.play_event("victory" if won else "defeat")

func update_ui():
 if stats==null:return
 stats.text="廃材  %03d     弾薬  %03d     仲間  %02d     成長  %02d"%[int(resources),int(ammo),units.size(),level]
 var gen=get_site("generator")
 var pump=get_site("pump")
 objective.text="01  発電所  %s\n02  %s  %s"%[("稼働中" if generator_on else "復旧済" if gen.reclaimed else "%d%%"%int(gen.progress*100)),mission.facility,("復旧済" if pump.reclaimed else "%d%%"%int(pump.progress*100))]
 if mission.mode=="convoy":
  var convoy=convoy_unit()
  objective.text+="\n輸送  %d%%"%int(convoy_progress()*100) if convoy_started else "\n物資を積んで輸送隊を出発"
  if not convoy.is_empty():objective.text+="  耐久 %d"%int(convoy.hp)
  if not convoy_pending.is_empty():objective.text+="\n%s  接近 %d秒"%[["西：追走群","東：封鎖線崩壊","南：疾走体"][int(convoy_pending.stage)],ceili(maxf(0,convoy_pending.clock))]
  mission_action_button.text="輸送路を選ぶ / 廃材80" if not convoy_started else "輸送隊へ視点移動"
  convoy_pause_button.visible=convoy_started
  convoy_pause_button.text="車列を再発進" if convoy_halted else "車列を停車"
 elif mission.mode=="finale":
  var sub=get_site("substation")
  objective.text+="\n03  避難所変電所  %s"%["復旧済" if sub.get("reclaimed",false) else "%d%%"%int(sub.get("progress",0)*100)]
  objective.text+="\n送電 %03d/%d秒  破砕体:%s"%[int(hold_time),int(mission.hold),"撃破" if boss_defeated else "接近" if boss_spawned else "未到達"]
  mission_action_button.text="工兵を避難所変電所へ"
 else:objective.text+="\n03  揚水 %03d / %d秒"%[int(hold_time),int(mission.hold)]
 if is_instance_valid(tech_button):
  tech_button.text="再生工学 完成" if tech_level>=2 else "再生工学 %d%%"%int(research_time/30*100) if research_active else "再生工学 [J]  180"
  tech_button.disabled=tech_level>=2 or research_active

 pause_button.text="再開" if paused else "II"
 core_bar.value=buildings[0].hp if not buildings.is_empty() else 0
 guide.text=tutorial_instruction()
 guide.visible=not guide.text.is_empty()
 generator_button.text="発電停止 [F]" if generator_on else "発電起動 [F]"
 if not first_activation and gen.reclaimed:generator_button.text="起動 [F]  /  増援まで12秒以内"
 status.text="拠点耐久 %d   騒音 %d\n次の群れまで %02d秒  /  襲撃 %02d"%[int(core_bar.value),int(noise),int(maxf(0,wave_clock)),wave]
 var radar=false
 for b in buildings:
  if b.kind=="relay" and b.powered:radar=true
 if radar:status.text+="\nレーダー：次は"+wave_direction_text(wave+1)+" / "+("重装混成" if campaign_state.current>0 and wave>=3 else "感染群")
 selection_info.text="%02d部隊  %s\n撃破 %04d   XP %d / %d"%[selected.size(),selected_order_text(),kills,int(xp),int(xp_needed())]
 supply_status.text="電力 %.1f / %.1f   生産 %d\n%s"%[power_used,power_capacity,recruit_queue.size(),"予備弾: 威力40% / 補給不足" if ammo<1 else "補給 %03d / 400"%int(ammo)]
 context_button.visible=not inspected.is_empty() and is_instance_valid(inspected.get("node")) and inspected.get("kind")=="factory"
 dismantle_button.visible=can_dismantle(inspected)
 if dismantle_button.visible:dismantle_button.text="解体 +%d"%dismantle_refund(inspected)
 xp_bar.visible=not context_button.visible and not dismantle_button.visible
 supply_status.visible=xp_bar.visible
 if not inspected.is_empty() and is_instance_valid(inspected.get("node")):
  var names={"hq":"司令拠点","tower":"防衛塔","wall":"防壁","factory":"工廠","relay":"電力中継","mortar":"廃材臼砲","yard":"廃材回収所"}
  selection_info.text="%s  耐久%d / %d\n%s"%[names.get(inspected.kind,inspected.kind),int(inspected.hp),int(inspected.maxhp),"建設 %d%%"%int(inspected.built*100) if inspected.built<1 else "給電中" if inspected.powered else "手動 / 未給電"]
 if context_button.visible:
  selection_info.text="工廠  %s\n資材1.5/秒 → 補給8/秒"%[factory_status(inspected)]
 var portrait_kind="guard"
 var hp_sum=0.0
 var max_sum=0.0
 if not selected.is_empty():
  portrait_kind=selected[0].kind
  for u in selected:hp_sum+=u.hp;max_sum+=u.maxhp
 elif not inspected.is_empty() and is_instance_valid(inspected.get("node")):
  portrait_kind=inspected.kind;hp_sum=inspected.hp;max_sum=inspected.maxhp
 if portrait_kind!=last_portrait_kind:
  selection_portrait.texture=portrait_for(portrait_kind)
  last_portrait_kind=portrait_kind
 selected_hp.max_value=maxf(1,max_sum)
 selected_hp.value=hp_sum
 minimap.queue_redraw()
 combo_label.text="%d  KILLS"%combo if combo>=10 and combo_clock>0 else ""
 combo_label.modulate.a=minf(1,combo_clock)
 xp_bar.max_value=xp_needed()
 xp_bar.value=xp
 var cursor=get_viewport().get_mouse_position()
 for s in sites:
  if s.kind=="scrap":s.label.text="資材の残骸  %d"%int(s.stock)
  var hovered=camera.unproject_position(s.node.position+Vector3(0,1,0)).distance_to(cursor)<34
  var assigned=selected.any(func(unit):return unit.target==s and unit.task=="site")
  s.label.visible=hovered or assigned or (s.kind!="scrap" and not s.reclaimed)
 for building in buildings:
  var hovered=camera.unproject_position(building.node.position+Vector3(0,1.2,0)).distance_to(cursor)<30
  for child in building.node.get_children():
   if child is Label3D and child.has_meta("tactical_label"):child.visible=hovered or inspected==building

func beam(a:Vector3,b:Vector3,c:Color,duration:float,width:float=.055):
 if is_instance_valid(battle_fx):battle_fx.beam(a,b,c,duration,width)

func pulse(p:Vector3,c:Color,r:float,duration:float):
 if effects.size()>180:return
 var n=ring(p+Vector3(0,.2,0),1,c,self)
 n.material_override.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
 n.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 effects.append({"node":n,"life":duration,"total":duration,"kind":"pulse","radius":r})

func update_effects(dt:float):
 for fx in effects.duplicate():
  fx.life-=dt
  if fx.life<=0:
   fx.node.queue_free()
   effects.erase(fx)
  elif fx.kind=="fireball":
   var growth=1-fx.life/fx.total
   fx.node.scale=Vector3.ONE*(.3+growth*fx.radius)
   fx.node.transparency=growth
  elif fx.kind=="debris":
   fx.velocity.y-=dt*12
   fx.node.position+=fx.velocity*dt
   fx.node.rotation+=Vector3(3,5,2)*dt
  elif fx.kind=="spark":
   var size=maxf(.05,fx.life/fx.total)
   fx.node.scale=Vector3.ONE*size
  elif fx.kind=="pulse":
   var scale_value=maxf(.05,fx.radius*(1-fx.life/fx.total))
   fx.node.scale=Vector3(scale_value,1,scale_value)
   fx.node.material_override.albedo_color.a=fx.life/fx.total

func make_audio():
 audio_system=AudioSystem.new()
 add_child(audio_system)
 audio_system.set_muted(muted)

func tone(name:String):
 if is_instance_valid(audio_system):audio_system.play_event(name)

func apply_graphics_quality():
 if is_instance_valid(horde_renderer):horde_renderer.low_detail=performance_mode
 get_viewport().scaling_3d_scale=.75 if performance_mode else 1.0
 for light in find_children("*","DirectionalLight3D",true,false):
  if light.shadow_enabled:light.directional_shadow_mode=DirectionalLight3D.SHADOW_ORTHOGONAL if performance_mode else DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS

func showcase_step():
 if render_frames>20:
  showcase_process_ms.append(Performance.get_monitor(Performance.TIME_PROCESS)*1000)
  showcase_draws.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
  showcase_primitives.append(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
 if render_frames==20:
  if "--close-camera" in OS.get_cmdline_user_args():camera.size=40;camera_focus=Vector3(0,0,-4)
  resources=450
  ammo=400
  level=18
  tech_level=2
  set_command_tab("build")
  wave=8
  wave_clock=30
  gathered=650
  first_activation=true
  showcase_start_ms=Time.get_ticks_msec()
  select_guards()
  for s in sites:
   if s.kind!="scrap":
    s.reclaimed=true;s.progress=1
    s.label.text=site_title(s.kind)+" [復旧済]"
  generator_on=true
  upgrades={"chain":2,"storm":1,"power":2,"multi":1,"damage":3,"rate":3,"range":1,"crit":2,"salvo":1}
  make_building("factory",Vector3(5,0,12),true)
  make_building("relay",Vector3(-4,0,4),true)
  make_building("mortar",Vector3(11,0,6),true)
  make_unit("grenade",Vector3(3,0,4))
  make_unit("grenade",Vector3(-3,0,4))
  make_building("yard",Vector3(-9,0,9),true)
  recompute_power()
  notify("戦闘シーン確認 / 感染群 250",20)
  make_building("tower",Vector3(-6,0,3),true)
  make_building("tower",Vector3(10,0,4),true)
  for x in [-8,-5,5,8]:make_building("wall",Vector3(x,0,-7),true)
  for i in (500 if "--horde-500" in OS.get_cmdline_user_args() else 250):spawn_enemy(Vector3(rng.randf_range(-18,20),0,rng.randf_range(-20,-11)),i%5==0)
 if active_card:choose_upgrade(0)
 if render_frames in [80,140,260] and DisplayServer.get_name()!="headless":
  get_viewport().get_texture().get_image().save_png("res://builds/v04_combat_showcase_%d.png"%render_frames)
  if render_frames==140 and "--capture-only" in OS.get_cmdline_user_args():get_tree().quit()
  print("SHOWCASE_SCREENSHOT_SAVED frame=",render_frames," alive=",enemies.size()," corpses=",corpses.size()," process_ms=",Performance.get_monitor(Performance.TIME_PROCESS)*1000," draw_calls=",Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)," primitives=",Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
 if render_frames==400:
  showcase_frame_ms.sort()
  var total=0.0
  for value in showcase_frame_ms:total+=value
  var result={"scenario":"lightning_%d_spawn"%(500 if "--horde-500" in OS.get_cmdline_user_args() else 250),"frames":showcase_frame_ms.size(),"mean_frame_ms":total/maxi(1,showcase_frame_ms.size()),"p95_frame_ms":showcase_frame_ms[int(showcase_frame_ms.size()*.95)] if not showcase_frame_ms.is_empty() else 0,"kills":kills,"remaining":enemies.size(),"wall_ms":Time.get_ticks_msec()-showcase_start_ms,"renderer":RenderingServer.get_video_adapter_name()}
  result["quality"]="performance" if performance_mode else "quality"
  result["process_mean_ms"]=array_mean(showcase_process_ms)
  result["script_mean_ms"]=array_mean(showcase_script_ms)
  result["simulation_mean_ms"]=array_mean(showcase_sim_ms)
  result["draw_calls_mean"]=array_mean(showcase_draws)
  result["primitives_mean"]=array_mean(showcase_primitives)
  var file=FileAccess.open("res://builds/v04_showcase_metrics.json",FileAccess.WRITE)
  file.store_string(JSON.stringify(result,"  "))
  print("STRESS_METRICS ",JSON.stringify(result))
  get_tree().quit()

func run_tests():
 print("TEST_START")
 var before=resources
 build_mode="tower"
 assert(not place_building(Vector3(0,0,8)),"Overlap must reject")
 assert(resources==before,"Rejected placement cannot spend")
 build_mode="wall"
 assert(place_building(Vector3(5,0,5)),"Legal placement must succeed")
 assert(resources==before-18,"Spend exactly once")
 for i in 1200:simulate(.05)
 assert(wave>=1,"Wave advances")
 print("TEST_WAVE_AND_ECONOMY_OK wave=",wave," kills=",kills)
 if active_card:choose_upgrade(0)
 var e_count=enemies.size()
 spawn_enemy(Vector3(0,0,0))
 var e=enemies.back()
 var old_kills=kills
 var old_xp=xp
 hit(e,1000,false)
 hit(e,1000,false)
 assert(kills==old_kills+1,"Death counted once")
 assert(xp==old_xp+6,"XP counted once")
 offer_upgrade()
 assert(cards.size()==3 and cards[0].id!=cards[1].id and cards[0].id!=cards[2].id and cards[1].id!=cards[2].id,"Unique cards")
 var pick=cards[0].id
 choose_upgrade(0)
 var rank=upgrades[pick]
 choose_upgrade(0)
 assert(upgrades[pick]==rank,"Choice accepted once")
 assert(not active_card,"Choice closes")
 print("TEST_XP_CARDS_DEATH_OK")
 get_site("generator").reclaimed=true
 get_site("pump").reclaimed=true
 generator_on=true
 hold_time=mission.hold-.01
 simulate(.02)
 assert(ended,"Victory terminal")
 print("TEST_VICTORY_OK")
 print("ALL_TESTS_PASSED")
 await get_tree().process_frame
 get_tree().quit()

func capture_frame():
 await RenderingServer.frame_post_draw
 var path="res://builds/gameplay_%d.png"%Time.get_unix_time_from_system()
 get_viewport().get_texture().get_image().save_png(path)
 print("SCREENSHOT: ",path)

func rebuild_navigation():
 enemy_approach_cells.clear()
 if not nav.is_in_boundsv(Vector2i.ZERO):return
 nav.fill_solid_region(nav.region,false)
 for block in terrain_blocks:
  var p=block.pos
  var half=block.size*.5+Vector3(.4,0,.4)
  for x in range(floori(p.x-half.x),ceili(p.x+half.x)+1):
   for z in range(floori(p.z-half.z),ceili(p.z+half.z)+1):
    var cell=Vector2i(x,z)
    if nav.is_in_boundsv(cell):nav.set_point_solid(cell,true)
 for b in buildings:
  var p=b.node.position
  var radius=b.radius+.3
  for x in range(floori(p.x-radius),ceili(p.x+radius)+1):
   for z in range(floori(p.z-radius),ceili(p.z+radius)+1):
    var cell=Vector2i(x,z)
    if nav.is_in_boundsv(cell):nav.set_point_solid(cell,true)
 for u in units:u.planned=Vector3.INF
 for e in enemies:e.path_cd=0;e.route.clear()

func open_cell(p:Vector3,approach:Vector3=Vector3.INF)->Vector2i:
 var cell=Vector2i(clampi(roundi(p.x),-30,30),clampi(roundi(p.z),-30,30))
 if not nav.is_point_solid(cell):return cell
 for r in range(1,12):
  var candidates=[]
  for x in range(-r,r+1):
   for y in range(-r,r+1):
    var candidate=cell+Vector2i(x,y)
    if nav.is_in_boundsv(candidate) and not nav.is_point_solid(candidate):candidates.append(candidate)
  if not candidates.is_empty():
   if approach!=Vector3.INF:
    candidates.sort_custom(func(a,b):return Vector3(a.x,0,a.y).distance_squared_to(approach)<Vector3(b.x,0,b.y).distance_squared_to(approach))
   return candidates[0]
 return cell

func enemy_route(start:Vector3,target:Dictionary)->Array:
 var direct=route_to(start,target.node.position)
 if not direct.is_empty():return direct
 var source=open_cell(start)
 var key:int=target.node.get_instance_id()
 if enemy_approach_cells.has(key):
  var cached:Vector2i=enemy_approach_cells[key]
  if nav.is_in_boundsv(cached) and not nav.is_point_solid(cached):
   var points=nav.get_id_path(source,cached)
   if not points.is_empty():return path_vectors(points)
 # A nearest empty tile can be an enclosed pocket between adjacent buildings.
 # Try a reachable perimeter tile instead of leaving an entire approach idle.
 var center:Vector2i=Vector2i(roundi(target.node.position.x),roundi(target.node.position.z))
 var radius:int=ceili(float(target.get("radius",.7))+2.0)
 var candidates:Array[Vector2i]=[]
 for x in range(-radius,radius+1):
  for z in range(-radius,radius+1):
   var cell:Vector2i=center+Vector2i(x,z)
   if nav.is_in_boundsv(cell) and not nav.is_point_solid(cell):candidates.append(cell)
 candidates.sort_custom(func(a,b):return a.distance_to(center)*5+a.distance_to(source)<b.distance_to(center)*5+b.distance_to(source))
 for cell in candidates:
  var points=nav.get_id_path(source,cell)
  if not points.is_empty():
   enemy_approach_cells[key]=cell
   return path_vectors(points)
 return []

func path_vectors(points)->Array:
 var result=[]
 for point in points:result.append(Vector3(point.x,0,point.y))
 if not result.is_empty():result.pop_front()
 return result

func route_to(start:Vector3,end:Vector3)->Array:
 var result=[]
 var points=nav.get_id_path(open_cell(start),open_cell(end,start))
 for point in points:result.append(Vector3(point.x,0,point.y))
 if not result.is_empty():result.pop_front()
 return result

func toggle_audio():
 muted=not muted
 campaign_state.muted=muted
 if is_instance_valid(audio_system):audio_system.set_muted(muted)
 campaign_state.save_progress()

func toggle_fx():
 low_fx=not low_fx
 campaign_state.low_fx=low_fx
 campaign_state.save_progress()

func show_title():
 title_open=true
 for part in hud_parts:part.visible=false
 center_notice.visible=false
 combo_label.visible=false
 title_panel=PanelContainer.new()
 root_ui.add_child(title_panel)
 title_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 title_panel.add_theme_stylebox_override("panel",style(Color(0,0,0,0),Color(0,0,0,0)))
 var surface=Control.new()
 title_panel.add_child(surface)
 var artwork=TextureRect.new()
 surface.add_child(artwork)
 artwork.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 artwork.texture=load("res://assets/ui/title_keyart.png")
 artwork.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
 artwork.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_COVERED
 artwork.mouse_filter=Control.MOUSE_FILTER_IGNORE
 var fade=TextureRect.new()
 surface.add_child(fade)
 fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 fade.mouse_filter=Control.MOUSE_FILTER_IGNORE
 var gradient=Gradient.new()
 gradient.offsets=PackedFloat32Array([0,.48,.86,1])
 gradient.colors=PackedColorArray([Color("171b16fa"),Color("171b16f4"),Color("171b1600"),Color("171b1600")])
 var gradient_texture=GradientTexture2D.new()
 gradient_texture.gradient=gradient
 gradient_texture.width=1024
 gradient_texture.height=4
 gradient_texture.fill_from=Vector2(0,0)
 gradient_texture.fill_to=Vector2(1,0)
 fade.texture=gradient_texture
 var backdrop=Control.new()
 surface.add_child(backdrop)
 backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 backdrop.mouse_filter=Control.MOUSE_FILTER_IGNORE
 backdrop.draw.connect(func():
  var viewport=get_viewport().get_visible_rect().size
  backdrop.draw_line(Vector2(54,57),Vector2(626,57),AMBER,3)
  for i in 11:backdrop.draw_line(Vector2(54+i*18,viewport.y-47),Vector2(66+i*18,viewport.y-61),Color("74613b"),5)
 )
 var v=VBoxContainer.new()
 surface.add_child(v)
 v.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
 v.position=Vector2(55,90)
 v.custom_minimum_size=Vector2(565,0)
 v.add_theme_constant_override("separation",13)
 var small=label("AFTER THE FALL  /  2091",15,AMBER)
 small.add_theme_font_override("font",command_font)
 v.add_child(small)
 var logo=label("RECLAMATION",55,PALE)
 logo.add_theme_font_override("font",command_font)
 v.add_child(logo)
 v.add_child(label("オルタ湾復旧作戦",25,Color("b9b29b")))
 v.add_child(label("2091.  廃墟に電力を、水を、生活を。",16,Color("939985")))
 v.add_child(label(" ",10))
 if FileAccess.file_exists("user://checkpoint.json"):
  var saved=JSON.parse_string(FileAccess.get_file_as_string("user://checkpoint.json"))
  if valid_checkpoint(saved):v.add_child(button("作戦を再開",resume_checkpoint,555))
  else:v.add_child(label("保存データを読み込めません。作戦を新規開始してください。",14,RED))
 for i in 3:
  var m=campaign_state.MISSIONS[i]
  var unlocked=i<campaign_state.unlocked
  var prefix="達成済" if campaign_state.best.has(str(i)) else "出撃可能" if unlocked else "未開放"
  var b=button(m.title+"    /    "+prefix,func():start_mission(i),555)
  b.custom_minimum_size.y=65
  b.alignment=HORIZONTAL_ALIGNMENT_LEFT
  b.disabled=not unlocked
  v.add_child(b)
  var detail=label(m.description,14,Color("a6aa94") if unlocked else Color("5f6759"))
  detail.custom_minimum_size.x=545
  detail.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
  v.add_child(detail)
 v.add_child(label(" ",8))
 v.add_child(label("選択して指揮。回収して建設。群れを迎え撃つ。",16,PALE))
 v.add_child(label("左ドラッグ 選択  /  右クリック 指示  /  Space 戦術停止",14,Color("a29c85")))

func start_mission(index:int):
 campaign_state.current=index
 campaign_state.launch=true
 campaign_state.resume=false
 get_tree().reload_current_scene()

func return_title():
 if not ended and not title_open:save_checkpoint(false)
 campaign_state.launch=false
 get_tree().reload_current_scene()

func resume_checkpoint():
 var data=JSON.parse_string(FileAccess.get_file_as_string("user://checkpoint.json"))
 if not valid_checkpoint(data):
  notify("保存データを読み込めません。新しい作戦を開始してください。",5)
  return
 campaign_state.current=clampi(int(data.mission),0,2)
 campaign_state.launch=true
 campaign_state.resume=true
 get_tree().reload_current_scene()

func vec_data(v:Vector3)->Array:return [v.x,v.y,v.z]
func from_data(a:Array)->Vector3:return Vector3(float(a[0]),float(a[1]),float(a[2]))

func save_checkpoint(announce:bool=true):
 if ended or title_open:return
 var data={"version":1,"preferred_family":preferred_family,"family_misses":family_misses,"blast_queue":[],"ammo":ammo,"rerolls":rerolls,"build_boost":build_boost,"victory_boost":victory_boost,"recruit_queue":recruit_queue.duplicate(true),"mission":campaign_state.current,"resources":resources,"gathered":gathered,"kills":kills,"xp":xp,"level":level,"upgrades":upgrades.duplicate(),"elapsed":elapsed,"wave_clock":wave_clock,"wave":wave,"hold":hold_time,"noise":noise,"generator":generator_on,"first_activation":first_activation,"surge":incoming_surge,"paused":paused,"active_card":active_card,"rng":str(rng.state),"card_rng":str(card_rng.state),"cards":[],"units":[],"enemies":[],"buildings":[],"sites":[],"selected":[]}
 data.merge({"tech_level":tech_level,"research_active":research_active,"research_time":research_time,"convoy_started":convoy_started,"convoy_index":convoy_index,"boss_spawned":boss_spawned,"boss_defeated":boss_defeated,"convoy_route_choice":convoy_route_choice,"convoy_halted":convoy_halted,"convoy_encounter_stage":convoy_encounter_stage,"convoy_pending":{},"shells":[]})
 if not convoy_pending.is_empty():data.convoy_pending={"stage":convoy_pending.stage,"clock":convoy_pending.clock}
 for shell in shells:
  data.shells.append({"from":vec_data(shell.from),"to":vec_data(shell.to),"time":shell.time,"duration":shell.duration,"damage":shell.damage,"radius":shell.radius,"kind":shell.kind,"critical":shell.critical})
 for event in blast_queue:data.blast_queue.append({"pos":vec_data(event.pos),"radius":event.radius,"damage":event.damage,"generation":event.generation})
 for card in cards:data.cards.append(card.id)
 for b in buildings:data.buildings.append({"kind":b.kind,"pos":vec_data(b.node.position),"hp":b.hp,"maxhp":b.maxhp,"built":b.built,"cd":b.cd,"shots":b.shots,"enabled":b.enabled,"paid_cost":b.get("paid_cost",0)})
 for s in sites:data.sites.append({"kind":s.kind,"pos":vec_data(s.node.position),"progress":s.progress,"reclaimed":s.reclaimed,"stock":s.stock,"paid":s.paid})
 for u in units:
  var target_type=""
  var target_index=-1
  if u.target!=null:
   if u.task=="site":target_type="site";target_index=sites.find(u.target)
   if u.task=="build":target_type="build";target_index=buildings.find(u.target)
   if u.task=="focus_fire":target_type="enemy";target_index=enemies.find(u.target)
  data.units.append({"kind":u.kind,"pos":vec_data(u.node.position),"hp":u.hp,"maxhp":u.maxhp,"goal":vec_data(u.goal),"task":u.task,"target_type":target_type,"target_index":target_index,"cd":u.cd,"work":u.work,"shots":u.shots})
  if u in selected:data.selected.append(units.find(u))
 for e in enemies:
  if not e.dead:data.enemies.append({"pos":vec_data(e.node.position),"hp":e.hp,"speed":e.speed,"cd":e.cd,"armored":e.get("armored",false),"charged_until":e.get("charged_until",0),"convoy_hunter":e.get("convoy_hunter",false),"boss":e.get("boss",false),"windup":e.get("windup",0),"attack_pos":vec_data(e.get("attack_pos",e.node.position))})
 var file=FileAccess.open("user://checkpoint.json.tmp",FileAccess.WRITE)
 if file==null:
  if announce:notify("保存に失敗しました。空き容量とフォルダを確認してください。")
  return
 file.store_string(JSON.stringify(data))
 file.close()
 var result=DirAccess.rename_absolute("user://checkpoint.json.tmp","user://checkpoint.json")
 if announce:notify("作戦を保存しました。" if result==OK else "保存ファイルを更新できませんでした。",3)

func load_checkpoint()->bool:
 if not FileAccess.file_exists("user://checkpoint.json"):return false
 var d=JSON.parse_string(FileAccess.get_file_as_string("user://checkpoint.json"))
 if not valid_checkpoint(d):return false
 for shell in shells:shell.node.queue_free()
 shells.clear()
 for corpse in corpses:corpse.node.queue_free()
 corpses.clear()
 for collection in [units,enemies,buildings,sites]:
  for item in collection:item.node.queue_free()
  collection.clear()
 selected.clear()
 for raw in d.buildings:
  var b=make_building(raw.kind,from_data(raw.pos),true)
  for key in ["hp","maxhp","built","cd"]:b[key]=raw[key]
  b.node.scale.y=.2+.8*b.built
  b.shots=raw.get("shots",0)
  b.enabled=raw.get("enabled",true)
  b.paid_cost=raw.get("paid_cost",0 if b.kind=="hq" or (b.kind=="tower" and b.node.position.distance_to(Vector3(2,0,-1))<.1) else BUILD_COSTS.get(b.kind,0))
 for raw in d.sites:
  make_site(raw.kind,from_data(raw.pos))
  var s=sites.back()
  for key in ["progress","reclaimed","stock","paid"]:s[key]=raw[key]
  if s.reclaimed:
   s.label.text=site_title(s.kind)+" [復旧済]"
   s.label.modulate=CYAN
 for raw in d.units:
  var u=make_unit(raw.kind,from_data(raw.pos))
  for key in ["hp","maxhp","task","cd","work"]:u[key]=raw[key]
  u.goal=from_data(raw.goal)
  u.shots=raw.get("shots",0)
  if raw.target_index>=0:
   if raw.target_type=="site" and raw.target_index<sites.size():u.target=sites[raw.target_index]
   if raw.target_type=="build" and raw.target_index<buildings.size():u.target=buildings[raw.target_index]
 for raw in d.enemies:
  spawn_enemy(from_data(raw.pos),raw.speed>2,raw.get("armored",false),raw.get("boss",false))
  var e=enemies.back()
  for key in ["hp","speed","cd"]:e[key]=raw[key]
  e.charged_until=raw.get("charged_until",0)
  e.convoy_hunter=raw.get("convoy_hunter",false)
  e.windup=raw.get("windup",0)
  e.attack_pos=from_data(raw.get("attack_pos",raw.pos))
 for i in d.units.size():
  var raw=d.units[i]
  if raw.target_type=="enemy" and raw.target_index>=0 and raw.target_index<enemies.size():units[i].target=enemies[int(raw.target_index)]
 convoy_route_choice=int(d.get("convoy_route_choice",0));convoy_halted=d.get("convoy_halted",false);convoy_encounter_stage=int(d.get("convoy_encounter_stage",0));convoy_pending=d.get("convoy_pending",{})
 tech_level=int(d.get("tech_level",1));research_active=d.get("research_active",false);research_time=d.get("research_time",0)
 convoy_started=d.get("convoy_started",false);convoy_index=int(d.get("convoy_index",0));boss_spawned=d.get("boss_spawned",false);boss_defeated=d.get("boss_defeated",false)
 for raw in d.get("shells",[]):
  launch_shell(from_data(raw.from),from_data(raw.to),raw.damage,raw.radius,raw.kind,raw.critical)
  var shell=shells.back()
  shell.radius=raw.radius;shell.time=raw.time;shell.duration=raw.duration
 if campaign_state.current==2 and not sites.any(func(site):return site.kind=="substation"):make_site("substation",Vector3(17,0,14))
 set_command_tab(command_tab)
 preferred_family=d.get("preferred_family","");family_misses=int(d.get("family_misses",0))
 blast_queue.clear()
 for event in d.get("blast_queue",[]):blast_queue.append({"pos":from_data(event.pos),"radius":event.radius,"damage":event.damage,"generation":int(event.generation)})
 ammo=d.get("ammo",240);rerolls=int(d.get("rerolls",2));build_boost=d.get("build_boost",0);victory_boost=d.get("victory_boost",0);recruit_queue=d.get("recruit_queue",[])
 resources=d.resources;gathered=d.gathered;kills=int(d.kills);xp=d.xp;level=int(d.level)
 upgrades=d.upgrades
 elapsed=d.elapsed;wave_clock=d.wave_clock;wave=int(d.wave);hold_time=d.hold;noise=d.noise
 generator_on=d.generator;first_activation=d.first_activation;incoming_surge=d.surge;paused=d.paused
 rng.state=int(d.rng);card_rng.state=int(d.card_rng)
 for index in d.selected:
  if index<units.size():selected.append(units[index])
 update_selection()
 if d.active_card:
  cards.clear()
  for id in d.cards:
   var card=UpgradeCatalog.by_id(id)
   if not card.is_empty():cards.append(card)
  display_cards()
 recompute_power()
 notify("前回の作戦を再開しました。",3)
 return true

func show_options():
 if title_open or active_card or ended:return
 options_previous_pause=paused
 paused=true
 options_panel=PanelContainer.new()
 root_ui.add_child(options_panel)
 options_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 options_panel.add_theme_stylebox_override("panel",style(Color("081922e8")))
 var center=CenterContainer.new()
 options_panel.add_child(center)
 var v=VBoxContainer.new()
 center.add_child(v)
 v.add_theme_constant_override("separation",18)
 v.add_child(label("設定",32,CYAN))
 var audio_toggle=CheckButton.new()
 audio_toggle.text="効果音"
 audio_toggle.button_pressed=not muted
 audio_toggle.toggled.connect(func(on):muted=not on;campaign_state.muted=muted;audio_system.set_muted(muted);campaign_state.save_progress())
 v.add_child(audio_toggle)
 var fx_toggle=CheckButton.new()
 fx_toggle.text="撃破エフェクトを控えめに"
 fx_toggle.button_pressed=low_fx
 fx_toggle.toggled.connect(func(on):low_fx=on;campaign_state.low_fx=low_fx;campaign_state.save_progress())
 v.add_child(fx_toggle)
 var quality=OptionButton.new()
 quality.add_item("画質優先")
 quality.add_item("動作優先（3D解像度75%）")
 quality.selected=1 if performance_mode else 0
 quality.item_selected.connect(func(index):performance_mode=index==1;campaign_state.performance_mode=performance_mode;apply_graphics_quality();campaign_state.save_progress())
 v.add_child(quality)
 v.add_child(button("作戦に戻る",close_options,350))

func close_options():
 if is_instance_valid(options_panel):options_panel.queue_free()
 paused=options_previous_pause

func valid_checkpoint(d:Variant)->bool:
 if not d is Dictionary or d.get("version",0)!=1:return false
 for key in ["mission","resources","gathered","kills","xp","level","elapsed","wave_clock","wave","hold","noise"]:
  if not d.has(key) or not (d[key] is float or d[key] is int):return false
 if int(d.mission)<0 or int(d.mission)>2:return false
 for key in ["generator","first_activation","surge","paused","active_card"]:
  if not d.has(key) or not d[key] is bool:return false
 for key in ["rng","card_rng"]:
  if not d.has(key) or not d[key] is String or not d[key].is_valid_int():return false
 if not d.get("upgrades") is Dictionary:return false
 for key in ["cards","units","enemies","buildings","sites","selected"]:
  if not d.get(key) is Array:return false
 if d.buildings.is_empty() or not d.buildings[0] is Dictionary or d.buildings[0].get("kind")!="hq":return false
 if d.active_card and d.cards.size()!=3:return false
 for kind in ["units","enemies","buildings","sites"]:
  for item in d[kind]:
   if not item is Dictionary or not item.get("pos") is Array or item.pos.size()!=3:return false
   for value in item.pos:
    if not (value is float or value is int):return false
   var fields={"units":["kind","hp","maxhp","goal","task","target_type","target_index","cd","work"],"enemies":["hp","speed","cd"],"buildings":["kind","hp","maxhp","built","cd"],"sites":["kind","progress","reclaimed","stock","paid"]}[kind]
   for field in fields:
    if not item.has(field):return false
   if kind=="units" and (not item.goal is Array or item.goal.size()!=3):return false
 return true

func construction_multiplier()->float:
 return 1+bonus("build","build_speed_add")+(.5 if build_boost>0 else 0)

func production_multiplier()->float:
 return construction_multiplier()+(.25*upgrades.get("economy",0) if victory_boost>0 else 0)

func in_supply(p:Vector3)->bool:
 if p.distance_to(Vector3(0,0,8))<12:return true
 for b in buildings:
  if b.kind=="relay" and b.powered and p.distance_to(b.node.position)<14:return true
 for u in units:
  if u.kind=="truck" and p.distance_to(u.node.position)<11:return true
 return false

func mobile_aura(p:Vector3)->bool:
 if upgrades.get("fortress",0)<=0:return false
 for u in units:
  if u.kind=="truck" and p.distance_to(u.node.position)<11:return true
 return false

func update_economy(dt:float):
 if research_active:
  research_time+=dt
  if research_time>=30:
   research_active=false;tech_level=2
   set_command_tab(command_tab)
   recompute_power()
   notify("再生工学 完成：爆薬手・廃材臼砲を解放。発電容量 +3。",7)
   audio_system.play_event("power")
 build_boost=maxf(0,build_boost-dt)
 victory_boost=maxf(0,victory_boost-dt)
 ammo=minf(400,ammo+dt*2)
 power_clock-=dt
 if power_clock<=0:
  power_clock=1
  recompute_power()
 if not recruit_queue.is_empty():
  recruit_queue[0].time-=dt*production_multiplier()
  if recruit_queue[0].time<=0:
   var kind=recruit_queue.pop_front().kind
   make_unit(kind,Vector3(rng.randf_range(-3,3),0,12))
   tone("build")
 for b in buildings:
  if b.kind!="factory":continue
  b.production_state="生産中"
  if b.built<1:b.production_state="建設中"
  elif not b.enabled:b.production_state="手動停止"
  elif not b.powered:b.production_state="未給電"
  elif ammo>=399:b.production_state="補給満杯"
  elif resources<dt*1.5:b.production_state="資材不足"
  else:
   resources-=dt*1.5
   ammo=minf(400,ammo+dt*8*production_multiplier())
 var industry=0
 for yard in buildings:
  if yard.kind=="yard" and yard.built>=1 and yard.powered:
   industry+=1
   for stock in sites:
    if stock.kind=="scrap" and stock.stock>0 and stock.node.position.distance_to(yard.node.position)<14:
     var amount=minf(stock.stock,1.5*dt*production_multiplier())
     stock.stock-=amount;resources+=amount;gathered+=amount
     break
  if yard.kind=="factory" and yard.get("production_state","")=="生産中":industry+=1
 if is_instance_valid(audio_system):audio_system.set_industry(industry)
 if upgrades.get("repair",0)>0:
  for u in units:
   if u.hp>0 and in_supply(u.node.position):u.hp=minf(u.maxhp,u.hp+u.maxhp*.005*upgrades.repair*dt)
  for b in buildings:
   if b.kind in ["tower","mortar"] and b.hp>0 and in_supply(b.node.position):b.hp=minf(b.maxhp,b.hp+b.maxhp*.005*upgrades.repair*dt)

func recompute_power():
 power_capacity=base_power()*(1+bonus("power","power_capacity_add")) if generator_on else 0
 power_used=0
 for b in buildings:b.powered=false
 if not generator_on:return
 var sources=[get_site("generator").node.position]
 var changed=true
 while changed:
  changed=false
  for b in buildings:
   if b.kind!="relay" or b.built<1 or b.powered:continue
   for origin in sources.duplicate():
    if origin.distance_to(b.node.position)<=22 and power_used+.5<=power_capacity:
     b.powered=true;power_used+=.5;sources.append(b.node.position);changed=true
     break
 for kind in ["factory","mortar","tower","yard"]:
  for b in buildings:
   if b.kind!=kind or b.built<1 or not b.enabled:continue
   var demand=float(GameRules.building(kind).power)
   for origin in sources:
    if origin.distance_to(b.node.position)<=22 and power_used+demand<=power_capacity:
     b.powered=true;power_used+=demand
     break

func bonus(id:String,key:String)->float:
 return float(catalog_by_id.get(id,{}).get("effects",{}).get(key,0))*float(upgrades.get(id,0))

func toggle_inspected():
 if inspected.is_empty() or not is_instance_valid(inspected.get("node")) or inspected.kind!="factory":return
 inspected.enabled=not inspected.enabled
 recompute_power()

func bar_style(color:Color,border:Color)->StyleBoxFlat:
 var skin=style(color,border)
 skin.content_margin_left=0;skin.content_margin_right=0;skin.content_margin_top=0;skin.content_margin_bottom=0
 return skin

func decorate_unit(kind:String,n:Node3D):
 if kind in ["truck","convoy"]:StructureVisuals.add_vehicle(n,kind)
 else:
  ActorVisuals.add_human(n,kind)
  for mesh in n.find_children("*","MeshInstance3D",true,false):mesh.visible=false

func decorate_building(kind:String,n:Node3D,_rad:float,preview:bool=false):
 StructureVisuals.add_building(n,kind)
 if not preview and kind in ["hq","factory","relay","yard","mortar"]:
  world_label(n,{"hq":"生存者の拠点","factory":"弾薬工房","relay":"電力中継","yard":"廃材回収所","mortar":"廃材臼砲"}[kind],Vector3(0,4.1 if kind=="hq" else 3.5,0),CYAN)

func portrait_for(kind:String)->Texture2D:
 return CommandDeck.portrait(kind)

func command_icon_button(kind:String,title:String,cost:String,callback:Callable)->Button:
 return CommandDeck.command_button(kind,title,cost,callback,font)

func tutorial_instruction()->String:
 if campaign_state.current!=0 or hold_time>=15:return ""
 if gathered<20:return "工兵を選び、残骸を右クリックして回収。"
 if not get_site("generator").reclaimed:return "警備兵で護衛し、工兵で発電所を復旧。費用50。"
 if not first_activation:return "起動で増援。防衛と補給を整えてから発電ON。"
 if not get_site("pump").reclaimed:return "工兵を揚水場へ。警備兵を護衛と拠点守備に分ける。"
 return "工廠と回収班で補給を維持し、稼働を守る。"

func selected_order_text()->String:
 if attack_move:return "攻撃移動: 指示待ち"
 if not build_mode.is_empty():return "建設: 配置待ち"
 if selected.is_empty():return "未選択"
 var kinds=[]
 for u in selected:
  var task=u.task
  if task=="site" and u.target!=null:task="salvage" if u.target.kind=="scrap" else "restore"
  if not task in kinds:kinds.append(task)
 if kinds.size()>1:return "複数命令"
 return {"idle":"待機","move":"移動中","attack_move":"攻撃移動","focus_fire":"集中攻撃","salvage":"回収中","restore":"復旧中","build":"建設中"}.get(kinds[0],kinds[0])

func factory_status(b:Dictionary)->String:
 if b.built<1:return "建設中"
 if not b.enabled:return "手動停止"
 if not b.powered:return "未給電"
 if ammo>=399:return "補給満杯"
 if resources<=0:return "資材不足"
 return b.get("production_state","生産中")

func upgrade_preview(data:Dictionary)->String:
 var id=String(data.id)
 var r=int(upgrades.get(id,0))
 var percentage_keys={"damage":"damage_add","rate":"attack_speed_add","range":"range_add","armor":"max_hp_add","move":"move_speed_add","supply":"ammo_reduction_add","salvage":"salvage_speed_add","build":"build_speed_add","overload":"conditional_damage_add","economy":"production_burst_add"}
 if percentage_keys.has(id):
  var step=float(data.effects.get(percentage_keys[id],0))
  var sign="−" if id=="supply" else "+"
  return "改装補正  %s%d%% → %s%d%%"%[sign,roundi(step*r*100),sign,roundi(step*(r+1)*100)]
 match id:
  "pierce":return "追加貫通  %d → %d体"%[r,r+1]
  "blast_radius":return "爆発半径  %.1f → %.1fm"%[2*(1+.15*r),2*(1+.15*(r+1))]
  "crit":return "会心率  %d%% → %d%%"%[r*10,(r+1)*10]
  "power":return "発電容量  %.1f → %.1f"%[base_power()*(1+.15*r),base_power()*(1+.15*(r+1))]
  "multi":return "追加弾  %d → %d発"%[r,r+1]
  "chain":return "連鎖先  %d → %d体"%[mini(5,2*r+int(upgrades.get("storm",0))),mini(5,2*(r+1)+int(upgrades.get("storm",0)))]
  "blast":return "誘爆威力  %d%% → %d%%"%[0 if r==0 else 20+20*r,40+20*r]
  "critpower":return "会心倍率  %.2f → %.2f"%[1.5+.25*r,1.5+.25*(r+1)]
  "salvo":return "斉射なし → 6射ごと" if r==0 else "斉射間隔  6射 → 4射"
  "repair":return "毎秒回復  %.1f%% → %.1f%%"%[.5*r,.5*(r+1)]
  "storm":return "連鎖先  %d → %d体"%[2*int(upgrades.get("chain",0)),mini(5,2*int(upgrades.get("chain",0))+1)]
  "cascade":return "誘爆  第1世代 → 第2世代まで"
  "sweep":return "斉射  3体 → 6体貫通 / 追加1列"
  "fortress":return "補給車の周囲: 威力+20% / 消費−10pt"
  "reserve":return "資材  %d → %d"%[int(resources),int(resources)+80]
  "field_repair":return "部隊と建造物を全回復"
  "reserve2":return "12秒間: 建設・生産速度 +50%"
 return ""

func upgrade_route_text(id:String)->String:
 var routes={"chain":["storm","chain","power"],"power":["storm","chain","power"],"blast":["cascade","blast","blast_radius"],"blast_radius":["cascade","blast","blast_radius"],"salvo":["sweep","salvo","pierce"],"pierce":["sweep","salvo","pierce"],"supply":["fortress","supply","repair"],"repair":["fortress","supply","repair"]}
 if not routes.has(id):return ""
 var route=routes[id]
 var pieces=PackedStringArray()
 for prerequisite in route.slice(1):
  pieces.append(("✓ " if upgrades.get(prerequisite,0)>0 else "○ ")+UpgradeCatalog.by_id(prerequisite).name)
 return UpgradeCatalog.by_id(route[0]).name+"へ: "+" / ".join(pieces)

func impact_spark(p:Vector3,kind:String):
 if is_instance_valid(battle_fx):battle_fx.impact(p,kind)

func site_title(kind:String)->String:
 if kind=="generator":return "01 発電所"
 if kind=="substation":return "03 避難所変電所"
 if kind=="scrap":return "廃材の山"
 return "02 "+mission.facility

func base_power()->float:return 9.0 if tech_level>=2 else 6.0

func near_yard(p:Vector3)->bool:
 for b in buildings:
  if b.kind=="yard" and b.built>=1 and p.distance_to(b.node.position)<12:return true
 return false

func start_research():
 if ended or active_card or tech_level>=2 or research_active:return
 var workshop=false
 var yard=false
 for b in buildings:
  if b.kind=="factory" and b.built>=1 and b.powered:workshop=true
  if b.kind=="yard" and b.built>=1:yard=true
 if not workshop or not yard:
  notify("再生工学には稼働中の弾薬工房と完成した回収所が必要。",5)
  return
 if resources<180:notify("研究費用は廃材180。") ;return
 resources-=180
 research_active=true
 research_time=0
 tone("build")
 notify("廃材と古い設計図から、重火器を再生する。研究30秒。",5)

func launch_shell(origin:Vector3,target:Vector3,damage:float,radius:float,kind:String,critical:bool=false):
 if is_instance_valid(battle_fx):battle_fx.muzzle(origin,kind=="mortar")
 pulse(target,Color("bd975c"),radius,.8 if kind=="grenade" else 1.35)
 var node=Node3D.new()
 add_child(node)
 node.position=origin
 var ball=cylinder(.13 if kind=="grenade" else .2,.28,Color("b0a275"),Vector3.ZERO,node)
 ball.rotation.x=PI*.5
 var tail=box(Vector3(.08,.08,.38),AMBER,Vector3(0,0,.25),node)
 tail.material_override=material(AMBER,1.4)
 shells.append({"node":node,"from":origin,"to":target,"time":0.0,"duration":.8 if kind=="grenade" else 1.35,"damage":damage,"radius":radius*(1+bonus("blast_radius","blast_radius_add")),"kind":kind,"critical":critical})
 audio_system.play_event("grenade_launch" if kind=="grenade" else "mortar_launch",origin)

func update_shells(dt:float):
 for shell in shells.duplicate():
  var previous=shell.node.position
  shell.time+=dt
  var t=minf(1,shell.time/shell.duration)
  shell.node.position=shell.from.lerp(shell.to,t)+Vector3(0,sin(t*PI)*(3 if shell.kind=="grenade" else 7),0)
  if dt>0 and not low_fx:battle_fx.trail(previous,shell.node.position,shell.kind=="mortar")
  if t>=1:
   detonate_shell(shell)
   shell.node.queue_free()
   shells.erase(shell)

func detonate_shell(shell:Dictionary):
 var p=shell.to
 explosion_visual(p,shell.radius,shell.kind=="mortar")
 if debug_run and shell.kind=="mortar" and not showcase_impact_captured and DisplayServer.get_name()!="headless":
  showcase_impact_captured=true
  capture_impact.call_deferred()
 audio_system.play_event("blast_heavy" if shell.kind=="mortar" else "blast_light",p)
 var primary=nearest_enemy(p,shell.radius)
 for e in enemies.duplicate():
  if e.dead:continue
  var distance=e.node.position.distance_to(p)
  if distance<shell.radius:
   var multiplier=1.0 if e==primary else .65
   hit(e,shell.damage*multiplier,e==primary,0,false,shell.critical)
 if upgrades.get("chain",0)>0 and primary!=null:
  var last=p
  var used=[primary]
  for i in mini(5,2*int(upgrades.chain)+int(upgrades.get("storm",0))):
   var e=nearest_enemy(last,4.5,used)
   if e==null:break
   beam(last+Vector3(0,.6,0),e.node.position+Vector3(0,.6,0),Color("91c3df"),.20)
   last=e.node.position;used.append(e)
   hit(e,shell.damage*pow(.65,i+1),false,0,true)

func explosion_visual(p:Vector3,radius:float,heavy:bool):
 if is_instance_valid(battle_fx):battle_fx.blast(p,radius,heavy,low_fx)

func update_corpses(dt:float):
 for corpse in corpses.duplicate():
  corpse.life-=dt
  corpse.node.transform=corpse.start*ActorVisuals.sample_death(3.5-corpse.life,1 if corpse.lean>=0 else -1,1)
  if corpse.life<1:corpse.node.scale=corpse.scale*maxf(.03,corpse.life)
  if corpse.life<=0:
   corpse.node.queue_free()
   corpses.erase(corpse)

func convoy_unit()->Dictionary:
 for u in units:
  if u.kind=="convoy":return u
 return {}

func launch_convoy():
 if ended or active_card or mission.mode!="convoy" or convoy_started:return
 if not generator_on or not get_site("pump").reclaimed:
  notify("発電所と貨物中継所を復旧し、発電を開始してください。")
  return
 if resources<80:notify("輸送物資の積込みに廃材80が必要。") ;return
 resources-=80
 convoy_started=true
 convoy_index=1
 var vehicle=make_unit("convoy",convoy_route()[0])
 vehicle.goal=convoy_route()[1]
 vehicle.task="convoy"
 world_label(vehicle.node,"物資輸送隊",Vector3(0,3.2,0),AMBER)
 wave_clock=minf(wave_clock,6)
 notify("輸送隊が出発。護衛を付けて東の避難所へ。",7)
 audio_system.play_event("power",vehicle.node.position)

func convoy_progress()->float:
 var convoy=convoy_unit()
 if not convoy_started or convoy.is_empty():return 0
 var previous=convoy_route()[maxi(0,convoy_index-1)]
 var destination=convoy_route()[mini(convoy_index,convoy_route().size()-1)]
 var leg=maxf(.1,previous.distance_to(destination))
 var fraction=clampf(1-convoy.node.position.distance_to(destination)/leg,0,1)
 return clampf((convoy_index-1+fraction)/(convoy_route().size()-1),0,1)

func update_mission(dt:float):
 if ended:return
 if mission.mode=="convoy":
  update_convoy_encounters(dt)
  if convoy_started:
   var convoy=convoy_unit()
   if convoy.is_empty():failure_reason="輸送隊を失った。";finish(false);return
   if convoy_halted:return
   if convoy.node.position.distance_to(convoy_route()[convoy_index])<1.2 or (convoy.planned!=Vector3.INF and convoy.node.position.distance_to(convoy.goal)<.55):
    convoy_index+=1
    if convoy_index>=convoy_route().size():finish(true);return
    convoy.goal=convoy_route()[convoy_index]
   hold_time=convoy_progress()*100
  return
 var restored=generator_on and get_site("pump").reclaimed
 if mission.mode=="finale":restored=restored and get_site("substation").get("reclaimed",false)
 if restored:
  hold_time=minf(mission.hold,hold_time+dt)
  if mission.mode=="finale" and hold_time>=55 and not boss_spawned:
   boss_spawned=true
   spawn_enemy(Vector3(-25,0,-18),false,true,true)
   wave_clock=minf(wave_clock,4)
   notify("破砕体 接近。防壁を砕く一撃に注意！",8)
   audio_system.play_event("infected_growl",Vector3(-25,0,-18),1.4)
  if hold_time>=mission.hold and (mission.mode!="finale" or boss_defeated):finish(true)

func boss_impact(enemy:Dictionary):
 enemy["attack_at"]=elapsed
 var p=enemy.attack_pos
 explosion_visual(p,4.5,true)
 for u in units:
  if u.node.position.distance_to(p)<4.5:u.hp-=45
 for b in buildings:
  if b.node.position.distance_to(p)<4.5+b.radius:b.hp-=175 if b.kind=="wall" else 120
 enemy.cd=3.2
 audio_system.play_event("heavy_hit",p,1.4)

func set_command_tab(tab:String):
 command_tab=tab
 if not is_instance_valid(command_grid):return
 for child in command_grid.get_children():command_grid.remove_child(child);child.queue_free()
 var actions=[]
 if tab=="people":
  actions=[
   ["guard","Q 生存者","廃材45",func():recruit("guard")],
   ["worker","W 作業員","廃材30",func():recruit("worker")],
   ["grenade","V 爆薬手","廃材75 / 要研究",func():recruit("grenade")],
   ["truck","T 補給車","廃材80",func():recruit("truck")],
   ["guard","G 攻撃移動","右クリック指示",func():attack_move=true],
   ["guard","1 戦闘部隊","まとめて選択",select_guards],
   ["worker","2 作業員","まとめて選択",select_workers]
  ]
 else:
  actions=[
   ["tower","E 廃材銃座","廃材65",func():set_build("tower")],
   ["wall","R バリケード","廃材18",func():set_build("wall")],
   ["factory","U 弾薬工房","廃材75 / 電力2",func():set_build("factory")],
   ["relay","Y 電力中継","廃材40 / 電力0.5",func():set_build("relay")],
   ["yard","N 回収所","廃材80 / 回収増加",func():set_build("yard")],
   ["mortar","B 廃材臼砲","廃材120 / 要研究",func():set_build("mortar")]
  ]
 for action in actions:
  var b=command_icon_button(action[0],action[1],action[2],action[3])
  if action[0] in ["grenade","mortar"] and tech_level<2:b.modulate=Color(.70,.70,.70)
  command_grid.add_child(b)

func mission_action():
 if mission.mode=="convoy":
  if not convoy_started:show_route_choice()
  else:
   var convoy=convoy_unit()
   if not convoy.is_empty():camera_focus=convoy.node.position
 elif mission.mode=="finale":assign_site("substation")

func capture_impact():
 await RenderingServer.frame_post_draw
 get_viewport().get_texture().get_image().save_png("res://builds/v04_mortar_impact.png")

func array_mean(values:Array)->float:
 var total=0.0
 for value in values:total+=value
 return total/maxi(1,values.size())

func convoy_route()->Array:return ConvoyPlan.route(convoy_route_choice)

func show_route_choice():
 if ended or active_card or convoy_started or is_instance_valid(route_panel):return
 if not generator_on or not get_site("pump").reclaimed:
  notify("発電所と貨物中継所を復旧し、車列を整備しよう。",4)
  return
 route_previous_pause=paused;paused=true
 route_panel=PanelContainer.new();root_ui.add_child(route_panel)
 route_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
 route_panel.position-=Vector2(340,165)
 route_panel.custom_minimum_size=Vector2(680,330)
 route_panel.add_theme_stylebox_override("panel",CommandDeck.skin("panel",24))
 var col=VBoxContainer.new();route_panel.add_child(col);col.add_theme_constant_override("separation",16)
 col.add_child(label("水と薬を、東の避難所へ",26,AMBER))
 col.add_child(label("護衛の配置と輸送路を決めて出発。廃材80を積み込む。",16))
 col.add_child(button("南側道路  /  短い道。拠点の防衛線から離れる。",func():choose_convoy_route(0),620))
 col.add_child(button("拠点側迂回  /  長い道。銃座と補給圏を利用できる。",func():choose_convoy_route(1),620))
 col.add_child(button("準備に戻る",close_route_choice,620))

func close_route_choice():
 if is_instance_valid(route_panel):route_panel.queue_free()
 paused=route_previous_pause

func choose_convoy_route(choice:int):
 convoy_route_choice=choice
 close_route_choice()
 launch_convoy()

func toggle_convoy_stop():
 var convoy=convoy_unit()
 if convoy.is_empty() or ended:return
 convoy_halted=not convoy_halted
 convoy.goal=convoy.node.position if convoy_halted else convoy_route()[convoy_index]
 convoy.planned=Vector3.INF
 notify("車列を停車。護衛を集め直せ。" if convoy_halted else "車列、再発進。",3)

func update_convoy_encounters(dt:float):
 if not convoy_started:return
 if not convoy_pending.is_empty():
  convoy_pending.clock-=dt
  if convoy_pending.clock<=0:
   var data=ConvoyPlan.encounter(convoy_pending.stage,convoy_route_choice)
   for i in data.count:
    var armored=data.armored_every>0 and i%data.armored_every==0
    spawn_enemy(data.pos+Vector3(rng.randf_range(-.6,.6),0,rng.randf_range(-2,2)),not armored,armored)
    var pursuer=enemies.back();pursuer.convoy_hunter=true
    pursuer.speed=1.8 if armored else 3.15
   audio_system.play_event("infected_growl",data.pos,1.2)
   convoy_pending.clear()
 elif convoy_encounter_stage<3:
  var data=ConvoyPlan.encounter(convoy_encounter_stage,convoy_route_choice)
  if convoy_progress()>=data.progress:
   convoy_pending={"stage":convoy_encounter_stage,"clock":4.0}
   convoy_encounter_stage+=1
   notify(data.warning,6)
   pulse(data.pos,RED,4,4)
   audio_system.play_event("warning",data.pos)

func can_dismantle(building:Dictionary)->bool:
 return not building.is_empty() and building in buildings and building.get("kind","")!="hq" and building.get("hp",0)>0 and is_instance_valid(building.get("node"))

func dismantle_refund(building:Dictionary)->int:
 if not can_dismantle(building):return 0
 var invested=maxf(0,float(building.get("paid_cost",0)))
 var fraction=1-.5*clampf(building.built,0,1)
 return floori(invested*fraction*clampf(building.hp/maxf(1,building.maxhp),0,1))

func request_dismantle():
 if ended or active_card or title_open or is_instance_valid(dismantle_panel) or is_instance_valid(route_panel):return
 if not can_dismantle(inspected):return
 dismantle_target=inspected
 dismantle_previous_pause=paused;paused=true
 dismantle_panel=PanelContainer.new();root_ui.add_child(dismantle_panel)
 dismantle_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 dismantle_panel.add_theme_stylebox_override("panel",style(Color("151912bb")))
 var center=CenterContainer.new();dismantle_panel.add_child(center)
 var card=PanelContainer.new();center.add_child(card);card.custom_minimum_size=Vector2(520,240)
 card.add_theme_stylebox_override("panel",CommandDeck.skin("panel",24))
 var col=VBoxContainer.new();card.add_child(col);col.add_theme_constant_override("separation",18)
 var name={"tower":"廃材銃座","wall":"バリケード","factory":"弾薬工房","relay":"電力中継","mortar":"廃材臼砲","yard":"廃材回収所"}.get(dismantle_target.kind,"建物")
 col.add_child(label(name+"を解体する？",26,AMBER))
 col.add_child(label("廃材 %d を回収。建物は撤去されます。"%dismantle_refund(dismantle_target),17))
 var row=HBoxContainer.new();col.add_child(row)
 row.add_child(button("解体する",confirm_dismantle,220))
 row.add_child(button("残す",close_dismantle,220))

func close_dismantle():
 if is_instance_valid(dismantle_panel):dismantle_panel.queue_free()
 dismantle_target={};paused=dismantle_previous_pause

func confirm_dismantle():
 var target=dismantle_target
 if can_dismantle(target):dismantle_building(target)
 close_dismantle()

func dismantle_building(building:Dictionary)->bool:
 if ended or not can_dismantle(building):return false
 var refund=dismantle_refund(building)
 buildings.erase(building)
 for unit in units:
  if unit.task=="build" and unit.target==building:
   unit.target=null;unit.task="idle";unit.goal=unit.node.position;unit.route.clear();unit.planned=Vector3.INF
 if inspected==building:inspected={}
 building.node.queue_free()
 resources+=refund
 rebuild_navigation();recompute_power()
 notify("建物を解体。廃材%dを回収。"%refund,3)
 tone("build")
 return true
