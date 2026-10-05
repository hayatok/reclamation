extends Node3D

const HudDepthMask=preload("res://hud_depth_mask.gd")
var hud_depth_mask
const SimulationClock=preload("res://simulation_clock.gd")
var simulation_clock=SimulationClock.new()
const RenderInterpolation=preload("res://render_interpolation.gd")
var render_interpolation=RenderInterpolation.new()
const CheckpointValidation=preload("res://checkpoint_validation.gd")
const AtomicSave=preload("res://atomic_save.gd")
const WorkerOrders=preload("res://worker_orders.gd")
const ControlGroups=preload("res://control_groups.gd")
const CONTROL_GROUP_DOUBLE_TAP_MS:int=350
const CONTROLS_HELP="左クリック・ドラッグ: 選択 / 右クリック: 移動・作業・攻撃\nShift+右クリック: 作業予約 / Shift+配置: 連続建設\nCtrl+1–9: 登録 / 1–9: 呼出 / 同じ番号を2連打: 視点移動\nC 全戦闘員 / V 全作業員 / H 本部 / . 待機作業員\n矢印: 視点移動 / ホイール: 拡大縮小 / Space: 一時停止\n生産施設で右クリック: 集合地点 / 本部から資源指定: 採取\nEsc・右クリック: 配置取消 / Backspace: 最後の生産予約を取消"
var control_groups=ControlGroups.new()
var last_control_group:int=0
var last_control_group_msec:int=0
var result_progress_error:Error=OK
var result_won:bool=false

const CYAN = Color("c5b78e")
const AMBER = Color("d2a148")
const RED = Color("b9523e")
const PALE = Color("ded7c7")
const BG = Color("222520")
const RTSHud=preload("res://rts_hud.gd")
const CommandDeck=preload("res://command_deck.gd")
const EnvironmentOverlay=preload("res://environment_overlay.gd")
const BattleFX=preload("res://battle_fx.gd")
const BattleVisibility=preload("res://battle_visibility.gd")
const ConvoyPlan=preload("res://convoy_plan.gd")
const GameRules=preload("res://settlement_rules.gd")
const StructureVisuals=preload("res://structure_visuals.gd")
const ConstructionVisuals=preload("res://construction_visuals.gd")
const AudioSystem=preload("res://reclamation_audio.gd")
const CompletionPanel=preload("res://completion_panel.gd")
const AftermathScene=preload("res://aftermath_scene.gd")
const AftermathTransition=preload("res://aftermath_transition.gd")
var aftermath_scene:Node3D
var aftermath_transition:Control
var aftermath_settled:bool=false
const BuildingAttackAlerts=preload("res://building_attack_alerts.gd")
var building_attack_alerts=BuildingAttackAlerts.new()
var building_attack_button:Button
const ResourceVisuals=preload("res://resource_visuals.gd")
const EscortOrders=preload("res://escort_orders.gd")
# Newly implemented recovery navigation; not a restored late-version helper.
const FriendlyNavigation=preload("res://friendly_navigation.gd")
var friendly_navigation=FriendlyNavigation.new()
const CombatSpacing=preload("res://combat_spacing.gd")
var combat_spacing=CombatSpacing.new()
const WorkerRoutePreview=preload("res://worker_route_preview.gd")
var worker_route_preview:Node3D
const CrowdSteering=preload("res://crowd_steering.gd")
var crowd_steering=CrowdSteering.new()
const EnemyNavigation=preload("res://enemy_navigation.gd")
var enemy_navigation=EnemyNavigation.new()
var enemy_approach_cells:Dictionary=enemy_navigation.approach_cells
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
var stockpile:Dictionary=GameRules.STARTING_STOCKPILE.duplicate(true)
var resources:float:
 get:return float(stockpile.get("salvage",0))
 set(value):stockpile["salvage"]=value
var settlement_age:int=1
var production:RefCounted
var economy:RefCounted
var resource_nodes:Array=[]
var inspected_resource:Dictionary={}
var inspected_site:Dictionary={}
var context_actions:Array=[]
var context_signature:String=""
var worker_build_page:String="economy"
var command_heading:Label
var queue_caption:Label
var queue_bar:ProgressBar
var last_idle_worker:int=-1
var idle_worker_button:Button
var economy_notice_until:Dictionary={}
var kills:int=0
var xp:float=0
var level:int=1
var upgrades:Dictionary={}
var cards:Array=[]
var active_card:bool=false
var pending_card_delay:float=0.0
var pending_upgrade_levels:Array=[]
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
var modal:Control
var drag_overlay:Control
var drag_start=Vector2.ZERO
var dragging:bool=false
var effects:Array=[]
var impact_mesh:ArrayMesh
var impact_materials:Dictionary={}
var ghost:MeshInstance3D
var run_seed:int=0
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
var minimap_order_point=Vector2.ZERO
var minimap_order_time:float=0.0
var minimap_order_color:Color=Color.WHITE
var hud_counters:Dictionary={}
var queue_icons:HBoxContainer
var queue_signature:String=""
var command_detail:Label
var hovered_command:Dictionary={}
var hud_parts:Array=[]
var portrait_cache:Dictionary={}
var selection_portrait:TextureRect
var selected_hp:ProgressBar
var last_portrait_kind:String=""
var font:Font

func _ready():
 for data in UpgradeCatalog.all():catalog_by_id[data.id]=data
 mission=campaign_state.config()
 stockpile=GameRules.STARTING_STOCKPILE.duplicate(true)
 production=load("res://settlement_production.gd").new()
 production.setup(self)
 economy=load("res://settlement_economy.gd").new()
 economy.setup(self)
 wave_clock=110
 muted=campaign_state.muted
 low_fx=campaign_state.low_fx
 performance_mode=(campaign_state.performance_mode or "--performance" in OS.get_cmdline_user_args()) and not "--quality" in OS.get_cmdline_user_args()
 apply_graphics_quality()
 apply_graphics_quality.call_deferred()
 if campaign_state.run_seed<0:
  campaign_state.choose_run_seed(campaign_state.seed_from_args(OS.get_cmdline_user_args()))
 run_seed=campaign_state.run_seed
 seed_run_streams()
 font=load("res://assets/Japanese.ttc")
 command_font=load("res://assets/Command.ttf")
 command_font.fallbacks=[font]
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
 make_resource("food",Vector3(-8,0,11),1200)
 make_resource("salvage",Vector3(8,0,11),1800)
 make_resource("parts",Vector3(-11,0,2),600)
 make_resource("food",Vector3(18,0,18),1600)
 make_resource("salvage",Vector3(-20,0,15),2200)
 make_resource("parts",Vector3(18,0,-1),1000)
 make_resource("salvage",Vector3(-7,0,-16),2600)
 make_resource("food",Vector3(0,0,-24),2000)
 make_resource("parts",Vector3(-20,0,-15),1200)
 if mission.mode=="finale":make_site("substation",Vector3(17,0,14))
 for i in 2:make_unit("guard",Vector3(-1+i*2,0,3))
 # The HQ padded navigation footprint includes z=12; start workers outside it.
 for i in 6:make_unit("worker",Vector3(-3+(i%3)*1.4,0,13+floori(i/3.0)*1.4))
 make_ui()
 make_audio()
 battle_fx=BattleFX.new()
 add_child(battle_fx)
 horde_renderer=HordeRenderer.new()
 add_child(horde_renderer)
 horde_renderer.setup()
 worker_route_preview=WorkerRoutePreview.new();add_child(worker_route_preview)
 horde_renderer.low_detail=performance_mode
 render_interpolation.reset(units,enemies,corpses)
 battle_visibility=BattleVisibility.new()
 battle_visibility.district=district_art
 add_child(battle_visibility)
 ghost=box(Vector3(2.1,.15,2.1),CYAN,Vector3.ZERO,self)
 ghost.visible=false
 ghost.material_override.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
 ghost.material_override.albedo_color.a=.35
 get_viewport().size_changed.connect(func(): drag_overlay.queue_redraw())
 var resumed_checkpoint=false
 if "--self-test" in OS.get_cmdline_user_args():call_deferred("run_tests")
 elif campaign_state.resume:
  campaign_state.resume=false
  resumed_checkpoint=load_checkpoint()
  if not resumed_checkpoint:show_title()
 elif not campaign_state.launch and not "--showcase" in OS.get_cmdline_user_args():show_title()
 if "--showcase" in OS.get_cmdline_user_args(): debug_run=true
 if not title_open and elapsed<1 and not resumed_checkpoint:
  select_headquarters()
  notify(ConvoyPlan.opening(campaign_state.current),8)

 hud_depth_mask=HudDepthMask.new()
 hud_depth_mask.setup(self)

func seed_run_streams():
 # Domain-separated streams: art, voices and corpses cannot reroll mechanics.
 # Hash all 64 seed bits before seeding PCG (nearby seeds need not be correlated).
 rng.seed=stream_seed("combat")
 card_rng.seed=stream_seed("cards")
 visual_rng.seed=stream_seed("visual")

func stream_seed(domain:String)->int:
 return ("reclamation:%s:%d:%d"%[domain,campaign_state.current,run_seed]).sha256_buffer().decode_s64(0)

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
 var r=ring(Vector3(0,.06,0),.62,c,render_interpolation.visual_root(n))
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
 var b={"node":n,"kind":kind,"hp":float(hp)*(1+bonus("armor","max_hp_add")),"maxhp":float(hp)*(1+bonus("armor","max_hp_add")),"basehp":float(hp),"paid_cost":0,"paid_resources":{},"queue":[],"rally":p+Vector3(0,0,rad+3),"rally_target":null,"powered":false,"enabled":true,"shots":0,"built":1.0 if ready_build else 0.0,"radius":rad,"cd":0.0}
 ConstructionVisuals.setup(n,kind,rad,n.get_node("FinishedVisual")).set_progress(b.built)
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
   var b=box(Vector3(visual_rng.randf_range(.5,1.8),visual_rng.randf_range(.3,.9),visual_rng.randf_range(.5,1.2)),Color("6d7775"),Vector3(visual_rng.randf_range(-1.2,1.2),.5,visual_rng.randf_range(-1,1)),n)
   b.rotation.y=visual_rng.randf()*3
  label=world_label(n,"廃材の山",Vector3(0,2.6,0),AMBER)
 else:
  var art_kind="rail_depot" if kind=="pump" and mission.mode=="convoy" else "substation" if kind=="substation" or (kind=="pump" and mission.mode=="finale") else "generator" if kind=="generator" else "pump"
  StructureVisuals.add_site(n,art_kind)
  label=world_label(n,site_title(kind)+" [未復旧]",Vector3(0,4.3,0),AMBER if kind=="generator" else CYAN)

 var marker=ring(Vector3(0,.1,0),2.4,AMBER if kind=="generator" or kind=="scrap" else CYAN,n)
 sites.append({"marker":marker,"node":n,"kind":kind,"progress":0.0,"reclaimed":false,"stock":650.0,"label":label,"paid":false})

func spawn_enemy(p:Vector3,fast:bool=false,armored:bool=false,boss:bool=false):
 var n=Node3D.new()
 add_child(n)
 n.position=p
 var boss_label:Label3D
 if boss:
  n.scale=Vector3.ONE*2.2
  boss_label=world_label(render_interpolation.visual_root(n),"破砕体 100%",Vector3(0,2.0,0),RED)
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
 var top=field_panel(Control.PRESET_TOP_WIDE,Vector4(0,0,0,84),Color("1b1e19"))
 var row=HBoxContainer.new();top.add_child(row)
 row.add_theme_constant_override("separation",8)
 for entry in [["food","食料",122],["salvage","廃材",122],["parts","部品",122],["population","人口",122],["age","発展段階",90],["experience","部隊成長",100],["ammo","弾薬",132],["power","電力",150]]:
  var widget=RTSHud.counter(entry[0],entry[1],entry[2],font)
  hud_counters[entry[0]]=widget;row.add_child(widget.root)
  if entry[0]=="experience":
   widget.root.mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND
   widget.root.gui_input.connect(func(event):
    if event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_LEFT:
     open_growth_choices();widget.root.accept_event()
   )
 var stretch=Control.new();stretch.size_flags_horizontal=Control.SIZE_EXPAND_FILL;row.add_child(stretch)
 stats=label("");stats.visible=false;root_ui.add_child(stats)
 idle_worker_button=button("待機 0",select_idle_worker,86)
 idle_worker_button.tooltip_text="待機・採取停止・経路なしの作業員を選択  [ . ]"
 row.add_child(idle_worker_button)
 pause_button=button("一時停止",toggle_pause,86)
 pause_button.tooltip_text="戦術ポーズ / Space"
 row.add_child(pause_button)
 var menu_button=button("メニュー",show_options,92)
 menu_button.tooltip_text="保存・設定・操作方法"
 row.add_child(menu_button)
 var orders=field_panel(Control.PRESET_TOP_LEFT,Vector4(18,100,280,280),Color("242720"))
 var mission_column=VBoxContainer.new()
 orders.add_child(mission_column)
 mission_column.add_child(label("作戦  %02d"%(campaign_state.current+1),14,AMBER))
 mission_column.add_child(label(mission.title.substr(4),22,PALE))
 objective=label("",15,Color("aaa995"))
 mission_column.add_child(objective)
 core_bar=ProgressBar.new()
 core_bar.custom_minimum_size=Vector2(230,6)
 core_bar.max_value=mission.core
 core_bar.show_percentage=false
 core_bar.add_theme_stylebox_override("background",bar_style(Color("10120f"),Color("10120f")))
 core_bar.add_theme_stylebox_override("fill",bar_style(Color("8d9768"),Color("8d9768")))
 mission_column.add_child(core_bar)
 status=label("",16,Color("aca994"))
 status.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
 status.custom_minimum_size.x=228
 mission_column.add_child(status)
 guide=label("",16,PALE)
 guide.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
 guide.custom_minimum_size.x=228
 mission_column.add_child(guide)
 mission_column.move_child(guide,2)
 var site_actions=HBoxContainer.new()
 mission_column.add_child(site_actions)
 var generator_focus=button("発電所へ",func():assign_site("generator"),110)
 generator_focus.tooltip_text="発電所を選択・表示。復旧は作業員で右クリック。\n段階II / "+GameRules.cost_text(site_rule("generator").cost)
 site_actions.add_child(generator_focus)
 var pump_caption={"restore":"揚水場へ","convoy":"貨物庫へ","finale":"送電所へ"}.get(mission.mode,"復旧地点へ")
 var pump_focus=button(pump_caption,func():assign_site("pump"),110)
 pump_focus.tooltip_text=mission.facility+"を選択・表示。復旧は作業員で右クリック。\n段階III / "+GameRules.cost_text(site_rule("pump").cost)
 site_actions.add_child(pump_focus)
 generator_button=button("発電  ON / OFF  [F]",toggle_generator,228)
 generator_button.visible=false
 generator_button.tooltip_text="初回起動: 12秒以内に増援。稼働中は襲撃間隔が短くなる。"
 mission_column.add_child(generator_button)
 mission_action_button=button("",mission_action,228)
 mission_action_button.visible=mission.mode!="restore"
 mission_column.add_child(mission_action_button)
 convoy_pause_button=button("車列を停車",toggle_convoy_stop,228)
 convoy_pause_button.visible=false
 mission_column.add_child(convoy_pause_button)
 var mini_panel=field_panel(Control.PRESET_BOTTOM_LEFT,Vector4(14,-274,230,-14),Color("1b1f1a"))
 var map_col=VBoxContainer.new();mini_panel.add_child(map_col)
 map_col.add_child(label("街区図",14,AMBER))
 minimap=Control.new()
 minimap.custom_minimum_size=Vector2(180,180)
 minimap.size_flags_vertical=Control.SIZE_EXPAND_FILL
 map_col.add_child(minimap)
 minimap.mouse_filter=Control.MOUSE_FILTER_STOP
 minimap.tooltip_text="左クリック: 視点移動 / 右クリック: 命令"
 minimap.gui_input.connect(handle_minimap_input)
 minimap.draw.connect(draw_minimap)
 building_attack_button=button("",focus_building_attack,300)
 root_ui.add_child(building_attack_button)
 building_attack_button.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
 building_attack_button.offset_left=14;building_attack_button.offset_top=-326
 building_attack_button.offset_right=344;building_attack_button.offset_bottom=-284
 building_attack_button.add_theme_color_override("font_color",Color("e7af72"))
 building_attack_button.tooltip_text="クリックで現場へ"
 building_attack_button.mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND
 building_attack_button.visible=false
 var unit_panel=field_panel(Control.PRESET_BOTTOM_LEFT,Vector4(242,-274,562,-14),Color("25281f"))
 var selected_col=VBoxContainer.new()
 unit_panel.add_child(selected_col)
 selected_col.add_child(label("選択対象",14,AMBER))
 var unit_row=HBoxContainer.new()
 selected_col.add_child(unit_row)
 selection_portrait=TextureRect.new()
 CommandDeck.mount_portrait(selection_portrait)
 selection_portrait.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
 selection_portrait.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
 selection_portrait.texture=portrait_for("guard")
 unit_row.add_child(selection_portrait)
 selection_info=label("",18,PALE)
 selection_info.mouse_filter=Control.MOUSE_FILTER_STOP
 selection_info.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
 selection_info.custom_minimum_size=Vector2(196,90)
 unit_row.add_child(selection_info)
 selected_hp=ProgressBar.new()
 selected_hp.custom_minimum_size=Vector2(288,8)
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
 xp_bar.custom_minimum_size=Vector2(288,6)
 xp_bar.show_percentage=false
 xp_bar.add_theme_stylebox_override("background",bar_style(Color("121510"),Color("121510")))
 xp_bar.add_theme_stylebox_override("fill",bar_style(Color("b89955"),Color("b89955")))
 selected_col.add_child(xp_bar);xp_bar.visible=false
 supply_status=label("",15,Color("bcb69d"))
 supply_status.mouse_filter=Control.MOUSE_FILTER_STOP
 supply_status.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
 selected_col.add_child(supply_status)
 var command_panel=field_panel(Control.PRESET_BOTTOM_RIGHT,Vector4(-866,-274,-14,-14),Color("252820"))
 var command_col=VBoxContainer.new()
 command_panel.add_child(command_col)
 command_heading=label("",20,PALE)
 command_heading.mouse_filter=Control.MOUSE_FILTER_STOP
 command_col.add_child(command_heading)
 queue_caption=label("",15,AMBER)
 queue_caption.mouse_filter=Control.MOUSE_FILTER_STOP
 var queue_row=HBoxContainer.new();command_col.add_child(queue_row)
 queue_row.add_child(queue_caption);queue_caption.size_flags_horizontal=Control.SIZE_EXPAND_FILL
 queue_icons=HBoxContainer.new();queue_icons.add_theme_constant_override("separation",4);queue_row.add_child(queue_icons)
 queue_bar=ProgressBar.new();queue_bar.custom_minimum_size=Vector2(760,5);queue_bar.show_percentage=false
 queue_bar.add_theme_stylebox_override("background",bar_style(Color("121510"),Color("121510")))
 queue_bar.add_theme_stylebox_override("fill",bar_style(Color("b89955"),Color("b89955")))
 command_col.add_child(queue_bar)
 command_grid=GridContainer.new()
 command_grid.columns=4
 command_grid.add_theme_constant_override("h_separation",7)
 command_grid.add_theme_constant_override("v_separation",7)
 command_col.add_child(command_grid)
 set_command_tab("people")

 hint=label("Ctrl+1–9: 登録  /  1–9: 呼出・2連打で視点  /  C/V: 全戦闘員/全作業員  /  H: 本部  .: 待機",12,Color("999d86"))
 hint.visible=false;command_col.add_child(hint)
 command_detail=label("",15,Color("d1c8ac"));command_detail.custom_minimum_size=Vector2(790,22)
 command_detail.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
 command_col.add_child(command_detail)
 center_notice=label("",18,AMBER)
 root_ui.add_child(center_notice)
 center_notice.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
 center_notice.offset_left=-380;center_notice.offset_right=380;center_notice.offset_top=102
 center_notice.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
 center_notice.mouse_filter=Control.MOUSE_FILTER_IGNORE
 combo_label=label("",32,AMBER)
 root_ui.add_child(combo_label)
 combo_label.add_theme_font_override("font",command_font)
 combo_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
 combo_label.offset_left=-300;combo_label.offset_right=-26;combo_label.offset_top=122
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
  var protected_units=[]
  for unit in selected:
   if unit.task=="escort" and unit.target!=null and is_instance_valid(unit.target.get("node")) and unit.target.hp>0 and not unit.target.node in protected_units:
    protected_units.append(unit.target.node)
    var aim=camera.unproject_position(unit.target.node.position+Vector3(0,1.0,0))
    drag_overlay.draw_arc(aim,23,0,TAU,24,CYAN,2)
    drag_overlay.draw_line(aim+Vector2(-8,0),aim+Vector2(-1,7),CYAN,2)
    drag_overlay.draw_line(aim+Vector2(-1,7),aim+Vector2(10,-7),CYAN,2)
  if not inspected.is_empty() and not GameRules.unit_kinds_for(inspected.kind).is_empty():
   var flag=camera.unproject_position(inspected.rally+Vector3(0,.1,0))
   drag_overlay.draw_line(flag,flag-Vector2(0,23),AMBER,2)
   drag_overlay.draw_colored_polygon(PackedVector2Array([flag-Vector2(0,23),flag+Vector2(13,-18),flag-Vector2(0,13)]),AMBER)
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
 var skin=CommandDeck.skin("panel",10)
 p.add_theme_stylebox_override("panel",skin)
 hud_parts.append(p)
 return p

func handle_minimap_input(event:InputEvent)->void:
 if not event is InputEventMouseButton or not event.pressed or event.button_index not in [MOUSE_BUTTON_LEFT,MOUSE_BUTTON_RIGHT]:return
 minimap.accept_event()
 if title_open or ended or active_card:return
 for overlay in [options_panel,route_panel,dismantle_panel,choice_panel]:
  if is_instance_valid(overlay):return
 if minimap.size.x<=0 or minimap.size.y<=0 or not Rect2(Vector2.ZERO,minimap.size).has_point(event.position):return
 var map_pos=event.position/minimap.size*64-Vector2(32,32)
 if event.button_index==MOUSE_BUTTON_LEFT:
  camera_focus=Vector3(clampf(map_pos.x,-18,18),0,clampf(map_pos.y,-18,18))
  return
 if not build_mode.is_empty():
  build_mode="";ghost.visible=false
  return
 var destination=Vector3(clampf(map_pos.x,-28,28),0,clampf(map_pos.y,-28,28))
 var attack_order=attack_move
 if command_at(destination,Vector2.INF,event.shift_pressed):
  minimap_order_point=Vector2(destination.x,destination.z)
  minimap_order_time=.65
  minimap_order_color=RED if attack_order or selected.any(func(unit):return unit.task=="focus_fire") else CYAN
  minimap.queue_redraw()

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
 for resource in resource_nodes:
  if resource.renewable or resource.stock>0:
   minimap.draw_circle((Vector2(resource.node.position.x,resource.node.position.z)+Vector2(32,32))/64*size,2.5,resource_color(resource.resource))
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
 if not building_attack_alerts.current.is_empty() and building_attack_button.visible:
  var alert=building_attack_alerts.current
  var point=(Vector2(alert.position.x,alert.position.z)+Vector2(32,32))/64*size
  var radius=6.0+2.0*sin(elapsed*5.0)
  var color=Color("e7af72")
  minimap.draw_arc(point,radius,0,TAU,24,color,2,true)
  if int(alert.severity)==3:
   minimap.draw_line(point-Vector2(3,3),point+Vector2(3,3),color,2,true)
   minimap.draw_line(point-Vector2(3,-3),point+Vector2(3,-3),color,2,true)
 if minimap_order_time>0:
  var order_point=(minimap_order_point+Vector2(32,32))/64*size
  minimap.draw_arc(order_point,3.0+minimap_order_time*6.0,0,TAU,20,minimap_order_color,1.5,true)
 var view=(Vector2(camera_focus.x,camera_focus.z)+Vector2(32,32))/64*size
 minimap.draw_rect(Rect2(view-Vector2(36,26),Vector2(72,52)),Color("c6b991"),false,1)

func update_building_attack_alert():
 var sound=building_attack_alerts.update(elapsed,buildings+units.filter(func(unit):return unit.kind=="worker"))
 var alert=building_attack_alerts.current
 building_attack_button.visible=not alert.is_empty() and not title_open and not ended
 building_attack_button.disabled=active_card or is_instance_valid(options_panel) or is_instance_valid(dismantle_panel) or is_instance_valid(route_panel)
 if not alert.is_empty():
  var title="作業員" if alert.target.kind=="worker" else GameRules.building(alert.target.kind).get("title",alert.target.kind)
  building_attack_button.text=building_attack_alerts.text_for(title)
  if sound and building_attack_button.visible:tone("warning")

func focus_building_attack():
 if building_attack_alerts.current.is_empty() or building_attack_button.disabled:return
 var p=building_attack_alerts.current.position
 camera_focus=Vector3(clampf(p.x,-18,18),0,clampf(p.z,-18,18))

func notify(txt:String,duration:float=4):
 center_notice.text=txt
 notice_timer=duration

func toggle_pause():
 if ended or active_card or title_open: return
 paused=not paused
 notify("戦術ポーズ  /  Spaceで再開" if paused else "作戦再開",2)

func set_build(kind:String):
 if active_card or ended or not selected.any(func(unit):return unit.kind=="worker"):return
 var allowed=GameRules.can_build(kind,settlement_age,buildings)
 if not allowed.ok:notify(allowed.reason,3);return
 build_mode=kind
 ghost.visible=true
 var radius=float(GameRules.building(kind).radius)
 ghost.scale=Vector3(radius/.9,1,radius/.9)
 notify("左クリックで建設 / Escで取消",3)

func select_guards():select_kind("guard")
func select_workers():select_kind("worker")
func select_kind(kind:String):
 inspected={};inspected_resource={};inspected_site={}
 selected.clear()
 for u in units:
  if ControlGroups.alive(u) and (u.kind==kind or kind=="guard" and u.kind in ["grenade","siegecart"]):selected.append(u)
 update_selection()

func reset_control_group_tap():
 last_control_group=0;last_control_group_msec=0

func assign_control_group(slot:int):
 reset_control_group_tap()
 if control_groups.assign(slot,selected,inspected,units,buildings):notify("グループ%d 登録"%slot,2)
 else:notify("部隊か建物を選択して Ctrl+%d で登録"%slot,2)

func recall_control_group(slot:int,now_msec:int=-1):
 var group=control_groups.resolve(slot,units,buildings)
 if group.units.is_empty() and group.building.is_empty():
  reset_control_group_tap();notify("グループ%d は空です"%slot,2);return
 if now_msec<0:now_msec=Time.get_ticks_msec()
 var center=last_control_group==slot and now_msec>=last_control_group_msec and now_msec-last_control_group_msec<=CONTROL_GROUP_DOUBLE_TAP_MS
 selected=group.units;inspected=group.building;inspected_resource={};inspected_site={}
 build_mode="";attack_move=false;ghost.visible=false;dragging=false
 update_selection()
 if center:
  var point=Vector3.ZERO
  if not inspected.is_empty():point=inspected.node.position
  else:
   for unit in selected:point+=unit.node.position
   point/=selected.size()
  camera_focus=Vector3(clampf(point.x,-18,18),0,clampf(point.z,-18,18))
 else:
  last_control_group=slot;last_control_group_msec=now_msec

func update_selection():
 reset_control_group_tap()
 for u in units:u.ring.visible=u in selected
 context_signature=""
 refresh_context_commands(true)
 update_ui()

func recruit(kind:String):
 if ended or active_card or inspected.is_empty():return
 production.queue_unit(inspected,kind)
 refresh_context_commands(true)

func cancel_recruit():
 if inspected.is_empty():return
 production.cancel_last(inspected)
 refresh_context_commands(true)

func assign_site(kind:String):
 var site=get_site(kind)
 if site.is_empty():return
 camera_focus=site.node.position
 inspected={};inspected_resource={};selected.clear();inspected_site=site
 update_selection()

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

func _input(event):
 # Any intervening key/click (including HUD actions) breaks a double tap.
 if event is InputEventMouseButton and event.pressed:reset_control_group_tap()
 if event is InputEventKey and event.pressed and not event.echo and (event.keycode<KEY_1 or event.keycode>KEY_9 or event.ctrl_pressed or event.alt_pressed or event.meta_pressed or event.shift_pressed):reset_control_group_tap()
 if event is InputEventKey and event.pressed and not event.echo and event.keycode==KEY_TAB:
  var focus=get_viewport().gui_get_focus_owner()
  if focus is LineEdit or focus is TextEdit:return
  if active_card or open_growth_choices():get_viewport().set_input_as_handled()

func _unhandled_input(event):
 if is_instance_valid(dismantle_panel):
  if event is InputEventKey and event.pressed and event.keycode==KEY_ESCAPE:close_dismantle()
  return
 if event is InputEventKey and event.pressed and not event.echo:
  var focus=get_viewport().gui_get_focus_owner()
  if focus is LineEdit or focus is TextEdit:return
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
  if active_card:
   if event.keycode==KEY_ESCAPE:postpone_growth_choice();get_viewport().set_input_as_handled();return
   if is_instance_valid(choice_panel) and not (event.ctrl_pressed or event.alt_pressed or event.meta_pressed or event.shift_pressed) and event.keycode in [KEY_1,KEY_2,KEY_3]:choose_upgrade(int(event.keycode-KEY_1))
   return
  if ended:return
  if event.keycode==KEY_ESCAPE:
   build_mode="";attack_move=false;ghost.visible=false
   return
  if event.keycode==KEY_SPACE:toggle_pause();return
  if event.keycode>=KEY_1 and event.keycode<=KEY_9:
   if event.alt_pressed or event.meta_pressed or event.shift_pressed:reset_control_group_tap();return
   var slot=int(event.keycode-KEY_1)+1
   if event.ctrl_pressed:assign_control_group(slot)
   else:recall_control_group(slot)
   get_viewport().set_input_as_handled();return
  reset_control_group_tap()
  if not build_mode.is_empty():
   for action in context_actions:
    if action.key==event.keycode and GameRules.BUILDINGS.has(action.kind):
     activate_context_key(event.keycode);return
   return
  if activate_context_key(event.keycode):return
  match event.keycode:
   KEY_DELETE:
    if event.shift_pressed:request_dismantle()
   KEY_BACKSPACE:cancel_recruit()
   KEY_C:select_guards()
   KEY_V:select_workers()
   KEY_H:select_headquarters()
   KEY_PERIOD:select_idle_worker()
 if active_card or ended or title_open:return
 if event is InputEventMouseButton:
  if event.button_index==MOUSE_BUTTON_WHEEL_UP:camera.size=maxf(26,camera.size-3)
  if event.button_index==MOUSE_BUTTON_WHEEL_DOWN:camera.size=minf(85,camera.size+3)
  if event.button_index==MOUSE_BUTTON_RIGHT and event.pressed:
   if not build_mode.is_empty():
    build_mode=""
    ghost.visible=false
   else: command_at(ground_at(event.position),event.position,event.shift_pressed)
  if event.button_index==MOUSE_BUTTON_LEFT:
   if event.pressed:
    if not build_mode.is_empty():place_building(ground_at(event.position),event.shift_pressed);return
    dragging=true
    drag_start=event.position
   elif dragging:
    dragging=false
    select_rect(drag_start,event.position,event.shift_pressed)
    drag_overlay.queue_redraw()

func select_rect(a:Vector2,b:Vector2,append:bool=false):
 inspected={};inspected_site={};inspected_resource={}
 var rect=Rect2(a,b-a).abs()
 if not append:selected.clear()
 if rect.size.length()<10:
  var nearest:Variant=null;var best:float=24
  for unit in units:
   var screen=camera.unproject_position(unit.node.position+Vector3(0,.8,0))
   var distance=screen.distance_to(b)
   if distance<best:nearest=unit;best=distance
  if nearest!=null:
   if append and nearest in selected:selected.erase(nearest)
   elif not nearest in selected:selected.append(nearest)
  elif selected.is_empty():
   var ground=ground_at(b)
   var best_building:float=INF
   for building in buildings:
    var distance=ground.distance_to(building.node.position)
    if distance<building.radius+1 and distance<best_building:inspected=building;best_building=distance
   if inspected.is_empty():
    inspected_resource=resource_at(ground)
    if inspected_resource.is_empty():
     for site in sites:
      if site.node.position.distance_to(ground)<3:inspected_site=site;break
 else:
  for unit in units:
   if unit.kind=="convoy":continue
   if rect.has_point(camera.unproject_position(unit.node.position+Vector3(0,.8,0))) and not unit in selected:selected.append(unit)
 update_selection()

func command_at(p:Vector3,screen:Vector2=Vector2.INF,append_orders:bool=false)->bool:
 if selected.is_empty():
  if not inspected.is_empty() and not GameRules.unit_kinds_for(inspected.kind).is_empty():
   set_rally(inspected,p)
   return true
  return false
 p.x=clampf(p.x,-28,28)
 p.z=clampf(p.z,-28,28)
 var enemy_target:Variant=null
 var nearest=28.0 if screen!=Vector2.INF else 2.6
 for enemy in enemies:
  if enemy.dead:continue
  var separation=camera.unproject_position(enemy.node.position+Vector3(0,.9*enemy.node.scale.y,0)).distance_to(screen) if screen!=Vector2.INF else enemy.node.position.distance_to(p)
  if separation<nearest:nearest=separation;enemy_target=enemy
 # Enemy hits consume only ordinary combat orders; workers still resolve their
 # destination or work target, and Shift remains a worker queue command.
 if enemy_target!=null and not append_orders and not attack_move:
  var fighters=0
  for u in selected:
   if u.kind not in ["guard","grenade","siegecart"]:continue
   friendly_navigation.invalidate_order(u)
   u.task="focus_fire";u.target=enemy_target;u.goal=enemy_target.node.position;u.planned=Vector3.INF;u["focus_repath"]=0.0
   fighters+=1
  if fighters>0:
   attack_move=false
   pulse(enemy_target.node.position,RED,2.2,.5)
   notify("集中攻撃："+("破砕体" if enemy_target.get("boss",false) else "重装感染者" if enemy_target.get("armored",false) else "感染者"),3)
   tone("order")
   return true
 var friendly_target:Variant=null
 var friendly_distance:float=25.0 if screen!=Vector2.INF else 1.65
 if not attack_move:
  for ally in units:
   if ally.hp<=0 or selected.any(func(unit):return unit.node==ally.node):continue
   var separation:float=camera.unproject_position(ally.node.position+Vector3(0,1.0,0)).distance_to(screen) if screen!=Vector2.INF else ally.node.position.distance_to(p)
   if separation<friendly_distance:friendly_distance=separation;friendly_target=ally
 var s_target:Variant=null
 var b_target:Variant=null
 for b in buildings:
  if (b.built<1 or b.hp<b.maxhp) and b.node.position.distance_to(p)<b.radius+1:b_target=b
 for s in sites:
  if s.node.position.distance_to(p)<3:s_target=s
 var resource_target=resource_at(p)
 if append_orders:
  var workers=selected.filter(func(unit):return unit.kind=="worker" and unit.hp>0)
  if workers.is_empty():return false
  var task="move"
  var target:Variant=null
  if not resource_target.is_empty() and b_target==null:task="gather";target=resource_target
  elif b_target!=null:task="build" if b_target.built<1 else "repair";target=b_target
  elif s_target!=null or friendly_target!=null:
   notify("予約は移動・建設・修理・採取に対応しています。",3);return false
  for worker in workers:
   var issue=WorkerOrders.append_issue(worker)
   if not issue.is_empty():notify(issue,3);return false
  for i in workers.size():
   WorkerOrders.submit(self,workers[i],{"task":task,"target":target,"goal":p+Vector3((i%4-1.5)*1.1,0,floori(i/4.0)*1.1)},true)
  context_signature="";pulse(p,CYAN,1.5,.55);tone("order")
  return true
 var escort_count:int=0
 var issued_orders:int=0
 for i in selected.size():
  var u=selected[i]
  if u.kind=="convoy":continue
  # A rejected escort cycle is not an accepted replacement order.
  if u.kind=="worker" and friendly_target!=null and resource_target.is_empty() and s_target==null and b_target==null and not EscortOrders.can_follow(u,friendly_target):continue
  friendly_navigation.invalidate_order(u)
  if u.kind=="worker":WorkerOrders.clear(u)
  if u.kind=="worker" and not resource_target.is_empty() and b_target==null:
   economy.assign_resource(u,resource_target)
   issued_orders+=1
   continue
  if u.kind=="worker":
   if b_target!=null:economy.suspend_for_construction(u)
   else:economy.cancel_assignment(u)
  if friendly_target!=null and not (u.kind=="worker" and (s_target!=null or b_target!=null)):
   if EscortOrders.assign(u,friendly_target,escort_count):
    escort_count+=1;issued_orders+=1
   continue
  issued_orders+=1
  u.goal=p+Vector3((i%4-1.5)*1.1,0,floori(i/4.0)*1.1)
  u.task="attack_move" if attack_move and u.kind in ["guard","grenade","siegecart"] else "move"
  u.target=null
  if u.kind=="worker" and s_target!=null:
   u.task="site"
   u.target=s_target
   u.goal=s_target.node.position+Vector3((i%3-1)*.9,0,2.2)
  elif u.kind=="worker" and b_target!=null:
   economy.suspend_for_construction(u)
   u.task="build" if b_target.built<1 else "repair"
   u.target=b_target
   u.goal=b_target.node.position+Vector3(0,0,2)
 attack_move=false
 if escort_count>0:
  pulse(friendly_target.node.position,CYAN,2.2,.55)
  notify("護衛："+{"convoy":"物資輸送隊","truck":"補給車","worker":"作業員","guard":"生存者","grenade":"爆薬手"}.get(friendly_target.kind,"仲間"),3)
 else:pulse(p,CYAN,1.5,.55)
 tone("order")
 return issued_orders>0

func building_nav_rect(kind:String,p:Vector3)->Rect2i:
 var radius=float(GameRules.building(kind).radius)+.3
 var low=Vector2i(floori(p.x-radius),floori(p.z-radius))
 var high=Vector2i(ceili(p.x+radius),ceili(p.z+radius))
 return Rect2i(low,high-low+Vector2i.ONE)

func placement_issue(kind:String,p:Vector3)->String:
 var allowed=build_availability(kind)
 if not allowed.ok:return allowed.reason
 var radius:float=GameRules.building(kind).radius
 if absf(p.x)+radius>29 or absf(p.z)+radius>29:return "作戦区域の外です"
 for block in terrain_blocks:
  if absf(p.x-block.pos.x)<block.size.x*.5+radius+.25 and absf(p.z-block.pos.z)<block.size.z*.5+radius+.25:return "遮蔽物に重なっています"
 for building in buildings:
  if building.node.position.distance_to(p)<building.radius+radius+.5:return "建物に近すぎます"
 for site in sites:
  if site.node.position.distance_to(p)<radius+2.7:return "復旧設備に近すぎます"
 for resource in resource_nodes:
  if not resource.renewable and resource.stock<=0:continue
  if resource.node.position.distance_to(p)<radius+float(resource.radius)+.35:return "資源の作業場所に重なっています"
 var footprint=building_nav_rect(kind,p)
 for unit in units:
  if unit.hp>0 and footprint.has_point(FriendlyNavigation.cell_of(unit.node.position)):
   return "部隊がいます。移動させてから建設してください。"
 if construction_perimeter(kind,p).is_empty():return "建設の作業場所がありません。周囲を空けてください。"
 return ""

func construction_perimeter(kind:String,p:Vector3)->Array[Vector2i]:
 var footprint=building_nav_rect(kind,p)
 var cells:Array[Vector2i]=[]
 for x in range(footprint.position.x,footprint.end.x):
  for z in [footprint.position.y-1,footprint.end.y]:
   var cell=Vector2i(x,z)
   if FriendlyNavigation.cell_open(nav,cell):cells.append(cell)
 for z in range(footprint.position.y,footprint.end.y):
  for x in [footprint.position.x-1,footprint.end.x]:
   var cell=Vector2i(x,z)
   if FriendlyNavigation.cell_open(nav,cell):cells.append(cell)
 return cells

func construction_reachable(kind:String,p:Vector3,workers:Array)->bool:
 # One bounded flood at placement time. Preview only checks free perimeter.
 # Treat the prospective foundation as solid without mutating live navigation.
 var footprint=building_nav_rect(kind,p)
 var destinations={}
 for cell in construction_perimeter(kind,p):destinations[cell]=true
 if destinations.is_empty():return false
 var queue:Array[Vector2i]=[]
 var visited={}
 for worker in workers:
  var cell=FriendlyNavigation.cell_of(worker.node.position)
  if not footprint.has_point(cell) and FriendlyNavigation.cell_open(nav,cell) and not visited.has(cell):
   visited[cell]=true;queue.append(cell)
 var cursor=0
 while cursor<queue.size():
  var cell=queue[cursor];cursor+=1
  if destinations.has(cell):return true
  for direction in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
   var next=cell+direction
   if not visited.has(next) and not footprint.has_point(next) and FriendlyNavigation.cell_open(nav,next):
    visited[next]=true;queue.append(next)
 return false

func place_building(p:Vector3,append_orders:bool=false)->bool:
 if build_mode.is_empty():return false
 var workers=selected.filter(func(unit):return unit.kind=="worker" and unit.hp>0)
 if workers.is_empty():return false
 if append_orders:
  for worker in workers:
   var queue_issue=WorkerOrders.append_issue(worker)
   if not queue_issue.is_empty():notify(queue_issue,3);return false
 var issue=placement_issue(build_mode,p)
 if not issue.is_empty():notify(issue,2);return false
 if not construction_reachable(build_mode,p,workers):notify("作業員が建設場所に到達できません。通路を確保してください。",3);return false
 var rule=GameRules.building(build_mode)
 if not spend_cost(rule.cost):return false
 var building=make_building(build_mode,p)
 building.paid_resources=rule.cost.duplicate(true);building.paid_cost=rule.cost.get("salvage",0)
 for worker in workers:
  WorkerOrders.submit(self,worker,{"task":"build","target":building,"goal":p},append_orders)
 tone("build")
 if not append_orders:build_mode="";ghost.visible=false
 context_signature=""
 return true

func _process(delta):
 var script_start=Time.get_ticks_usec()
 var simulation_usec=0
 render_frames+=1
 var dt=clampf(delta,0,.4)
 shot_tick-=delta
 notice_timer-=delta
 minimap_order_time=maxf(0.0,minimap_order_time-delta)
 if notice_timer<=0:center_notice.text=""
 drag_overlay.queue_redraw()
 if ghost.visible:
  var build_point=ground_at(get_viewport().get_mouse_position())
  var footprint=building_nav_rect(build_mode,build_point)
  ghost.position=Vector3(footprint.position.x+(footprint.size.x-1)*.5,.08,footprint.position.y+(footprint.size.y-1)*.5)
  ghost.scale=Vector3(footprint.size.x/2.1,1,footprint.size.y/2.1)
  ghost.material_override.albedo_color=Color(.55,.7,.55,.35) if placement_issue(build_mode,build_point).is_empty() else Color(.8,.23,.15,.4)
 var pan=Vector3.ZERO
 if Input.is_physical_key_pressed(KEY_LEFT):pan+=Vector3(-1,0,1)
 if Input.is_physical_key_pressed(KEY_RIGHT):pan+=Vector3(1,0,-1)
 if Input.is_physical_key_pressed(KEY_UP):pan+=Vector3(-1,0,-1)
 if Input.is_physical_key_pressed(KEY_DOWN):pan+=Vector3(1,0,1)
 if not ended:
  camera_focus+=pan*dt*16
  camera_focus.x=clampf(camera_focus.x,-18,18)
  camera_focus.z=clampf(camera_focus.z,-18,18)
 camera.position=camera_focus+Vector3(37,48,43)
 camera.look_at(camera_focus)
 update_effects(dt)
 var sim_start=Time.get_ticks_usec()
 advance_simulation_time(delta)
 simulation_usec=Time.get_ticks_usec()-sim_start
 update_building_attack_alert()
 render_actors()
 update_worker_route_preview()
 battle_visibility.update_visibility(camera,units,[] if aftermath_settled else enemies,[] if aftermath_settled else shells,delta)
 battle_fx.update(dt,camera,buildings)
 if pending_card_delay>0:
  pending_card_delay-=dt
  if pending_card_delay<=0 and active_card and not ended:display_cards()
 refresh_context_commands()
 update_ui()
 if debug_run:
  if render_frames>20:
   showcase_frame_ms.append(delta*1000)
   showcase_script_ms.append((Time.get_ticks_usec()-script_start)/1000.0)
   showcase_sim_ms.append(simulation_usec/1000.0)
  showcase_step()

func simulation_running()->bool:
 return not paused and not active_card and not ended and not title_open

func advance_simulation_time(real_delta:float)->int:
 var steps=simulation_clock.take_steps(real_delta,simulation_running())
 var completed=0
 for step in steps:
  if not simulation_running():
   simulation_clock.reset();break
  render_interpolation.before_step(units,enemies,corpses)
  # Navigation resets its eight-query allowance inside simulate(), per logical tick.
  simulate(SimulationClock.STEP)
  render_interpolation.after_step(units,enemies,corpses)
  auto_save_clock-=SimulationClock.STEP
  completed+=1
  if not simulation_running():
   simulation_clock.reset();break
 if completed>0 and auto_save_clock<=0 and not ended:
  auto_save_clock=30
  save_checkpoint(false)
 return completed

func render_actors()->void:
 var running=simulation_running()
 if not running:render_interpolation.reset(units,enemies,corpses)
 var alpha=clampf(simulation_clock.remainder/SimulationClock.STEP,0,1) if running else 1.0
 var rendered=render_interpolation.frame(alpha)
 var rendered_time=maxf(0.0,elapsed-SimulationClock.STEP*(1.0-alpha)) if running else elapsed
 horde_renderer.update_horde([] if aftermath_settled else enemies+corpses,rendered_time,rendered)
 horde_renderer.update_friends(units,rendered)

func simulate(dt:float):
 friendly_navigation.begin_frame(dt,units)
 enemy_navigation.begin_step(nav)
 elapsed+=dt
 update_economy(dt)
 threat_voice_clock-=dt
 audio_system.set_power(generator_on)
 audio_system.set_threat(clampf(float(enemies.size())/160,0,1))
 if threat_voice_clock<=0 and not enemies.is_empty():
  audio_system.play_event("infected_growl" if enemies.size()>60 else "infected_moan",enemies[0].node.position)
  threat_voice_clock=visual_rng.randf_range(5,10)
 noise=move_toward(noise,clampf(8+units.size()*.55+settlement_age*3+(40 if generator_on else 0)+active_producers()*2.5,0,100),dt*3)
 wave_clock-=dt
 combo_clock-=dt
 if combo_clock<=0:combo=0
 if wave_clock<=0:
  wave+=1
  spawn_wave()
  wave_clock=(95.0 if settlement_age==1 else maxf(40,64-noise*.23) if settlement_age==2 else maxf(25,43-noise*.16))
 update_shells(dt)
 update_corpses(dt)
 # Production/economy may have spawned a worker this tick. Include it before
 # protecting current and assigned cells during combat settling.
 combat_spacing.prepare(units,friendly_navigation.work_reservations)
 for u in units.duplicate():
  if u.hp<=0:
   friendly_navigation.release_unit(u)
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
  if u.kind=="worker":
   WorkerOrders.tick(self,u)
   if u.task in ["build","repair"]:
    var work_target:Variant=u.target
    if work_target==null or not is_instance_valid(work_target.get("node")) or work_target.node.is_queued_for_deletion() or work_target.get("hp",0)<=0 or (u.task=="build" and work_target.built>=1) or (u.task=="repair" and work_target.hp>=work_target.maxhp):
     finish_construction_order(u)
   economy.update_worker(u,dt)
  if u.task=="escort":EscortOrders.update(u,units,dt)
  if u.task=="focus_fire":
   if u.target==null or u.target.get("dead",false) or not is_instance_valid(u.target.get("node")):
    u.task="idle";u.target=null;u.goal=u.node.position;u.route.clear();u.planned=Vector3.INF
   else:
    u["focus_repath"]=float(u.get("focus_repath",0))-dt
    if u.focus_repath<=0:
     u.goal=u.target.node.position;u.focus_repath=.3
  var previous_position=u.node.position
  var stop_to_fire=u.task=="attack_move" and nearest_enemy(u.node.position,float(GameRules.unit(u.kind).range)*(1+bonus("range","range_add")))!=null
  if u.task=="focus_fire" and u.target!=null:stop_to_fire=u.node.position.distance_to(u.target.node.position)<=float(GameRules.unit(u.kind).range)*(1+bonus("range","range_add"))*.97
  var unit_speed=float(GameRules.unit(u.kind).speed)*(1+bonus("move","move_speed_add"))
  var settled=false
  # Choose settling OR path travel for this tick, never both. A source-center
  # detour can travel and return to the old coordinate, so comparing positions
  # after navigation alone would not prove that its movement budget is unused.
  if u.kind in ["guard","grenade","siegecart"] and (u.task=="idle" or stop_to_fire):
   var firing_center=Vector3.INF
   var firing_radius=float(GameRules.unit(u.kind).range)*(1+bonus("range","range_add"))
   # Idle defenders also auto-fire. Do not cost them an existing shot merely
   # to separate their feet; this constraint does not assign/change a target.
   var held_target=u.target if u.task=="focus_fire" else nearest_enemy(u.node.position,firing_radius)
   if held_target!=null:firing_center=held_target.node.position
   if u.task=="focus_fire":firing_radius*=.97
   settled=combat_spacing.settle(u,nav,dt,unit_speed,firing_center,firing_radius)
   if settled and u.task=="idle":u.goal=u.node.position
  friendly_navigation.advance(u,nav,dt,unit_speed,stop_to_fire or settled)
  if not friendly_navigation.is_arrived(u):pass
  elif u.task in ["move","attack_move"]:
   if u.kind=="worker":WorkerOrders.finish(self,u)
   else:u.task="idle";u.target=null
  elif u.task=="site" and u.target!=null:
   work_site(u,dt)
  elif u.task=="build" and u.target!=null:
   var b=u.target
   if is_instance_valid(b.node):
    b.built=minf(1,b.built+dt/maxf(1,float(GameRules.building(b.kind).build_time))*construction_multiplier())
    b.node.get_meta(ConstructionVisuals.META).set_progress(b.built)
    if b.built>=1:
     building_completed(b)
     finish_construction_order(u);tone("build")
   else:finish_construction_order(u)
  elif u.task=="repair" and u.target!=null:
   var building=u.target
   if is_instance_valid(building.get("node")) and building.hp>0:
    var healed=minf(building.maxhp-building.hp,dt*8*construction_multiplier())
    var paid=minf(resources,healed*.1)
    building.hp=minf(building.maxhp,building.hp+paid*10);resources-=paid
    if building.hp>=building.maxhp:
     finish_construction_order(u)
   else:finish_construction_order(u)
  if u.kind in ["guard","grenade","siegecart"] and u.cd<=0:
   var weapon=GameRules.unit(u.kind)
   var range_value=float(weapon.range)*(1+bonus("range","range_add"))
   var target:Variant=null
   if u.task=="focus_fire":
    if u.target!=null and u.node.position.distance_to(u.target.node.position)<=range_value:target=u.target
   else:target=nearest_enemy(u.node.position,range_value)
   if target!=null:
    fire(u.node.position+Vector3(0,1.6 if u.kind=="siegecart" else 1,0),target,float(weapon.damage),"mortar" if u.kind=="siegecart" else u.kind,u)
    u.cd=float(weapon.cooldown)/(1+bonus("rate","attack_speed_add"))
    u["shot_cycle"]=u.cd
  if u.kind not in ["truck","convoy","siegecart"]:
   var attack_age=elapsed-float(u.get("attack_at",-100))
   var cycle=float(u.get("shot_cycle",.72))
   var reload_phase=clampf((attack_age-.2)/maxf(.2,cycle-.2),0,1) if attack_age>.2 and attack_age<cycle else -1.0
   ActorVisuals.pose(u.node,elapsed*8+u.node.get_instance_id()%17,u.node.position.distance_to(previous_position)>.001,attack_age,reload_phase,u.kind=="worker" and u.task in ["site","build","repair","gather"] and friendly_navigation.is_arrived(u))
 for b in buildings.duplicate():
  if b.hp<=0:
   if b.kind=="hq":finish(false);return
   production.on_building_destroyed(b)
   remove_garden_resource(b)
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
   enemy_navigation.update_route(e,target,nav,dt)
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
    building_attack_alerts.record_hit(target,elapsed)
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
 bank_earned_upgrades()


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
  if kind in ["guard","grenade"] or source.get("kind","")=="siegecart":
   var aim=target.node.position-source.node.position
   if aim.length_squared()>.01:source.node.rotation.y=atan2(-aim.x,-aim.z)
 if source.get("kind","")=="siegecart":origin=source.node.to_global(Vector3(0,2.116018,-1.205950))
 var ammo_cost=(3.0 if kind in ["grenade","mortar"] else 1.0)*maxf(.4,1-bonus("supply","ammo_reduction_add")-(.1 if (kind in ["guard","grenade"] or source.get("kind","")=="siegecart") and mobile_aura(origin) else 0.0))
 var supplied=ammo>=ammo_cost
 if supplied:ammo-=ammo_cost
 var damage=base*(1+bonus("damage","damage_add"))*(1 if supplied else .4)
 var conditional=bonus("overload","conditional_damage_add") if noise>=60 else 0.0
 if (kind in ["guard","grenade"] or source.get("kind","")=="siegecart") and mobile_aura(origin):conditional+=.2
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
 var count=mini(20,6+wave*2) if settlement_age==1 else mini(110,22+wave*4+int(noise*.25)) if settlement_age==2 else mini(240,55+wave*7+int(noise*.35))
 if incoming_surge:count+=30;incoming_surge=false
 count=mini(int(count*mission.pressure),280)
 var side=wave_side(wave)
 for i in count:
  var spawn_side=(side+(1 if i%3==0 else 0))%3 if campaign_state.current==2 and wave>=3 else side
  var p=Vector3(-28+rng.randf_range(-1,1),0,rng.randf_range(-20,15)) if spawn_side==0 else (Vector3(rng.randf_range(-24,24),0,-28+rng.randf_range(-1,1)) if spawn_side==1 else Vector3(28+rng.randf_range(-1,1),0,rng.randf_range(-20,15)))
  var armored=settlement_age>=3 and generator_on and wave>=4 and i%(10 if campaign_state.current==2 else 16)==0
  var fast=settlement_age>=2 and wave>=2 and i%(3 if campaign_state.current==1 else 5)==0 and not armored
  spawn_enemy(p,fast,armored)
 notify("襲撃 %02d  /  %sから %d体接近"%[wave,wave_direction_text(wave),count],6)
 tone("warning")

func xp_needed()->float:return 60+float(level-1)*35

func bank_earned_upgrades()->int:
 var was_empty=pending_upgrade_levels.is_empty()
 var earned=0
 while xp>=xp_needed():
  xp-=xp_needed()
  level+=1
  pending_upgrade_levels.append(level)
  earned+=1
 if earned>0 and was_empty and is_instance_valid(audio_system):tone("level")
 return earned

# Developer fixture compatibility; ordinary simulation calls bank_earned_upgrades.
func offer_upgrade():
 bank_earned_upgrades()
 open_growth_choices()

func open_growth_choices()->bool:
 if active_card or ended or title_open or pending_upgrade_levels.is_empty():return false
 if is_instance_valid(options_panel) or is_instance_valid(route_panel) or is_instance_valid(dismantle_panel):return false
 if cards.is_empty():
  cards=UpgradeCatalog.draw_for_level(upgrades,card_rng,int(pending_upgrade_levels[0]),preferred_family,family_misses)
  if not preferred_family.is_empty():
   var found=false
   for card in cards:
    if card.get("family","")==preferred_family:found=true
   family_misses=0 if found else family_misses+1
 active_card=true
 dragging=false;build_mode="";ghost.visible=false
 pending_card_delay=0
 display_cards()
 return true

func postpone_growth_choice():
 if not active_card:return
 active_card=false
 pending_card_delay=0
 if is_instance_valid(choice_panel):choice_panel.queue_free()
 choice_panel=null
 update_ui()

func reroll_cards():
 if not active_card or pending_upgrade_levels.is_empty() or rerolls<=0:return
 rerolls-=1
 cards=UpgradeCatalog.draw_for_level(upgrades,card_rng,int(pending_upgrade_levels[0]),preferred_family,family_misses)
 if is_instance_valid(choice_panel):choice_panel.queue_free()
 choice_panel=null
 display_cards()

func display_cards():
 if not active_card or pending_upgrade_levels.is_empty() or cards.size()!=3:return
 if is_instance_valid(choice_panel):return
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
 var sub=label("LV %02d の強化  /  未選択 %d件"%[int(pending_upgrade_levels[0]),pending_upgrade_levels.size()],17,AMBER)
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
 content.add_child(button("あとで選ぶ  [Esc]",postpone_growth_choice,260))

func equipment_diagram(id:String)->Control:
 return CommandDeck.equipment(UpgradeCatalog.family_for(id))

func choose_upgrade(index:int):
 if not active_card or pending_upgrade_levels.is_empty() or index<0 or index>=cards.size():return
 # Consume before effects or UI callbacks so repeated input cannot apply twice.
 active_card=false
 pending_card_delay=0
 var data=cards[index]
 pending_upgrade_levels.pop_front()
 cards=[]
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
 choice_panel=null
 tone("power")
 notify("成長："+data.name,4)
 update_ui()

func finish(won:bool):
 if ended:return
 ended=true
 result_won=won
 result_progress_error=campaign_state.complete(elapsed,kills) if won else OK
 if result_progress_error==OK:clear_finished_checkpoint()
 active_card=false
 if is_instance_valid(choice_panel):choice_panel.queue_free()
 if won:
  selected.clear();inspected={};inspected_site={};inspected_resource={}
  attack_move=false;build_mode="";ghost.visible=false;update_selection()
  for site in sites:site.marker.hide()
  for caption in find_children("*","Label3D",true,false):
   if caption.has_meta("tactical_label"):caption.hide()
  for child in root_ui.get_children():
   if child is CanvasItem:child.hide()
  aftermath_scene=AftermathScene.new();add_child(aftermath_scene)
  var anchors={"pump":get_site("pump").node.global_position,"hq":buildings[0].node.global_position,"occupied_positions":units.map(func(u):return u.node.global_position),"building_positions":buildings.map(func(b):return b.node.global_position)}
  var delivered=convoy_unit()
  if not delivered.is_empty():anchors["convoy_node"]=delivered.node;anchors["convoy"]=delivered.node.global_position
  aftermath_scene.setup(campaign_state.current,anchors)
  aftermath_scene.hide();aftermath_scene.set_process(false)
  modal=CompletionPanel.new();root_ui.add_child(modal);modal.setup(self)
  aftermath_transition=AftermathTransition.new();modal.add_child(aftermath_transition);modal.move_child(aftermath_transition,0)
  aftermath_transition.midpoint.connect(settle_aftermath_presentation)
  aftermath_transition.setup()
  audio_system.set_threat(0)
  audio_system.play_event("victory")
  return
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
 if result_progress_error!=OK:
  v.add_child(label("達成記録を保存できませんでした。前回の途中保存を保持しています。",16,RED))
  v.add_child(button("達成記録の保存を再試行",retry_completion_save,440))
 if won and campaign_state.current<2:
  v.add_child(button("次の作戦へ",func():start_mission(campaign_state.current+1),440))
 elif won:
  v.add_child(label("全3作戦 完了 / オルタ湾に生活圏を再建",20,CYAN))
 v.add_child(button("この作戦をもう一度",func():start_mission(campaign_state.current),440))
 v.add_child(button("作戦選択へ",return_title,440))
 audio_system.play_event("victory" if won else "defeat")

func settle_aftermath_presentation()->void:
 if not ended or not result_won or aftermath_settled:return
 aftermath_settled=true
 AftermathTransition.hide_combat_visuals([enemies,corpses,shells,effects],battle_fx)
 # The renderer also owns survivor batches. Empty only its infected submission,
 # immediately and on subsequent frames; never hide the shared renderer root.
 horde_renderer.update_horde([],elapsed)
 for child in get_children():
  if child.has_method("restore_district_lights"):child.restore_district_lights()
 camera_focus=aftermath_scene.camera_focus;camera.size=aftermath_scene.camera_size
 camera.position=camera_focus+Vector3(37,48,43);camera.look_at(camera_focus)
 aftermath_scene.show();aftermath_scene.set_process(true)


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
    s.reclaimed=true;s.progress=1;StructureVisuals.set_site_reclaimed(s.node,true)
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
 print("TEST_START foundation_v09")
 set_process(false)
 muted=true
 audio_system.set_muted(true)
 # Bounded scene integration fixtures, not a full campaign or timing replay.
 campaign_state.current=0
 mission=campaign_state.config()
 assert(not title_open and not ended and not active_card,"Self-test starts in the live first mission")
 assert(settlement_age==1 and units.size()==8,"Opening fixture has six workers and two defenders")
 assert(production.population_used()==8 and production.population_cap()==10,"Opening population is 8/10")
 var hq=buildings[0]
 var initial_stock=stockpile.duplicate(true)
 var initial_count=units.size()
 select_headquarters()
 assert(activate_context_key(KEY_Q),"HQ exposes contextual worker hotkey")
 assert(units.size()==initial_count and hq.queue.size()==1,"Worker recruitment queues without an instant spawn")
 assert(stockpile.food==initial_stock.food-50 and stockpile.salvage==initial_stock.salvage and stockpile.parts==initial_stock.parts,"Worker costs exactly 50 food")
 assert(hq.queue[0].paid_cost=={"food":50},"Queue retains its paid resource vector")
 production.update(17)
 assert(units.size()==initial_count and is_equal_approx(hq.queue[0].remaining,1),"Worker waits for the full training time")
 production.update(1)
 assert(units.size()==initial_count+1 and hq.queue.is_empty() and units.back().kind=="worker","HQ completes its worker locally")
 assert(units.back().node.position.distance_to(hq.node.position)<7,"Worker emerges at its producer")
 assert(production.queue_unit(hq,"worker") and production.queue_unit(hq,"worker"),"Population fixture queues two more paid workers")
 production.update(36)
 assert(production.population_used()==10 and hq.queue.size()==1 and hq.queue[0].waiting=="population","Completed training waits at the population cap")
 assert(stockpile.food==initial_stock.food-150,"Training completion never charges twice")
 # Explicit completed-house fixture checks the population gate without replaying construction.
 make_building("house",Vector3(-4,0,19),true)
 production.update(.01)
 assert(production.population_cap()==15 and production.population_used()==11 and hq.queue.is_empty(),"A completed house releases the population wait")
 print("TEST_LOCAL_PRODUCTION_AND_POPULATION_OK")
 var worker=units.filter(func(unit):return unit.kind=="worker")[0]
 selected=[worker];inspected={};inspected_resource={};inspected_site={};update_selection()
 var before=stockpile.duplicate(true)
 set_build("tower")
 assert(not place_building(hq.node.position),"Overlapping placement must reject")
 assert(stockpile==before,"Rejected placement cannot spend resources")
 set_build("wall")
 assert(place_building(Vector3(5,0,5)),"Selected worker can place a legal wall")
 assert(stockpile.salvage==before.salvage-18 and stockpile.food==before.food and stockpile.parts==before.parts,"Wall spends exactly 18 salvage once")
 assert(buildings.back().built==0 and buildings.back().paid_resources=={"salvage":18} and worker.task=="build" and worker.target==buildings.back(),"Paid wall remains a worker-owned construction job")
 assert(units.filter(func(unit):return unit.kind=="worker" and unit.task=="build").size()==1,"Construction never recruits unselected workers")
 print("TEST_SELECTED_CONSTRUCTION_OK")
 spawn_enemy(Vector3(0,0,0))
 var enemy=enemies.back()
 var old_kills=kills
 var old_xp=xp
 hit(enemy,1000,false)
 hit(enemy,1000,false)
 assert(kills==old_kills+1 and xp==old_xp+6,"An enemy death and its XP are counted once")
 xp=xp_needed()
 offer_upgrade()
 assert(cards.size()==3 and cards[0].id!=cards[1].id and cards[0].id!=cards[2].id and cards[1].id!=cards[2].id,"Growth offers three distinct cards")
 var pick=cards[0].id
 choose_upgrade(0)
 var rank=upgrades[pick]
 choose_upgrade(0)
 assert(upgrades[pick]==rank and not active_card,"Repeated growth choice is accepted once and closes")
 print("TEST_XP_CARDS_DEATH_OK")
 # Isolate the mobile-artillery weapon contract from whichever growth card was drawn.
 var saved_upgrades=upgrades.duplicate(true)
 upgrades={"fortress":1}
 var truck=make_unit("truck",Vector3(-7,0,0))
 var siege=make_unit("siegecart",Vector3(-8,0,0))
 spawn_enemy(Vector3(-2,0,3))
 var artillery_target=enemies.back()
 ammo=100
 fire(Vector3.ZERO,artillery_target,96,"mortar",siege)
 var shell=shells.back()
 var aim=(artillery_target.node.position-siege.node.position).normalized()
 assert((-siege.node.basis.z).dot(aim)>.999,"Siege cart aims its forward axis at the target")
 assert(shell.from.distance_to(siege.node.to_global(Vector3(0,2.116018,-1.205950)))<.001,"Siege shell launches from its transformed muzzle")
 assert(is_equal_approx(shell.damage,115.2) and is_equal_approx(ammo,97.3),"Fortress aura grants siege cart +20% damage and 10-point ammo reduction")
 truck.node.position=Vector3(24,0,24)
 fire(Vector3.ZERO,artillery_target,96,"mortar",siege)
 assert(is_equal_approx(shells.back().damage,96) and is_equal_approx(ammo,94.3),"Siege cart loses the fortress bonus outside its supply truck aura")
 upgrades=saved_upgrades
 print("TEST_SIEGECART_AURA_AIM_MUZZLE_OK")
 # Explicit restored M1 fixture verifies the Age III terminal gate.
 get_site("generator").reclaimed=true
 get_site("pump").reclaimed=true
 generator_on=true
 settlement_age=2;tech_level=2
 hold_time=mission.hold-.01
 update_mission(.02)
 assert(not ended and hold_time<mission.hold,"Restored facilities cannot win before Age III")
 settlement_age=3;tech_level=3
 update_mission(.02)
 assert(ended and hold_time==mission.hold,"Age III restored first mission reaches victory")
 print("TEST_AGE_III_VICTORY_OK")
 print("ALL_TESTS_PASSED")
 await get_tree().process_frame
 get_tree().quit(0)

func capture_frame():
 await RenderingServer.frame_post_draw
 var directory="res://builds" if OS.has_feature("editor") else "user://screenshots"
 if DirAccess.make_dir_recursive_absolute(directory)!=OK:return
 var path=directory+"/gameplay_%d.png"%Time.get_unix_time_from_system()
 var result=get_viewport().get_texture().get_image().save_png(path)
 if result==OK:print("SCREENSHOT: ",path)
 else:push_warning("Screenshot could not be saved: "+str(result))

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
 friendly_navigation.navigation_changed()
 enemy_navigation.navigation_changed()
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
 return enemy_navigation.route_now(nav,start,target)

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
 if not CheckpointValidation.read("user://settlement_v2/checkpoint.json").is_empty():
  var saved=CheckpointValidation.read("user://settlement_v2/checkpoint.json")
  if valid_checkpoint(saved):v.add_child(button("作戦を再開",resume_checkpoint,555))
  else:v.add_child(label("旧版の保存は元のリリースで再開できます。この版は新規作戦から開始。",14,RED))
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

func start_mission(index:int,seed_override:int=-1):
 campaign_state.current=index
 campaign_state.choose_run_seed(seed_override if seed_override>=0 else campaign_state.seed_from_args(OS.get_cmdline_user_args()))
 campaign_state.launch=true
 campaign_state.resume=false
 get_tree().reload_current_scene()

func return_title():
 if not ended and not title_open and save_checkpoint(false)!=OK:return
 campaign_state.launch=false
 get_tree().reload_current_scene()

func resume_checkpoint():
 var data=CheckpointValidation.read("user://settlement_v2/checkpoint.json")
 if not valid_checkpoint(data):
  notify("保存データを読み込めません。新しい作戦を開始してください。",5)
  return
 campaign_state.current=clampi(int(data.mission),0,2)
 campaign_state.launch=true
 campaign_state.resume=true
 get_tree().reload_current_scene()

func vec_data(v:Vector3)->Array:return [v.x,v.y,v.z]
func from_data(a:Array)->Vector3:return Vector3(float(a[0]),float(a[1]),float(a[2]))

func save_checkpoint(announce:bool=true)->Error:
 if ended or title_open:return ERR_UNAVAILABLE
 var result=DirAccess.make_dir_recursive_absolute("user://settlement_v2")
 if result==OK:result=AtomicSave.write_json("user://settlement_v2/checkpoint.json",checkpoint_data(),CheckpointValidation.validate)
 if announce or result!=OK:notify("作戦を保存しました。" if result==OK else "保存ファイルを更新できませんでした。",3)
 return result

func checkpoint_data()->Dictionary:
 var living_enemies=enemies.filter(func(enemy):return not enemy.dead)
 var data={"version":3,"run_seed":str(run_seed),"visual_rng":str(visual_rng.state),"stockpile":stockpile.duplicate(),"settlement_age":settlement_age,"resource_nodes":[],"preferred_family":preferred_family,"family_misses":family_misses,"blast_queue":[],"ammo":ammo,"rerolls":rerolls,"build_boost":build_boost,"victory_boost":victory_boost,"recruit_queue":recruit_queue.duplicate(true),"mission":campaign_state.current,"resources":resources,"gathered":gathered,"kills":kills,"xp":xp,"level":level,"pending_upgrade_levels":pending_upgrade_levels.duplicate(),"upgrades":upgrades.duplicate(),"elapsed":elapsed,"wave_clock":wave_clock,"wave":wave,"hold":hold_time,"noise":noise,"generator":generator_on,"first_activation":first_activation,"surge":incoming_surge,"paused":paused,"active_card":active_card,"rng":str(rng.state),"card_rng":str(card_rng.state),"cards":[],"units":[],"enemies":[],"buildings":[],"sites":[],"selected":[]}
 data.merge({"tech_level":tech_level,"research_active":research_active,"research_time":research_time,"convoy_started":convoy_started,"convoy_index":convoy_index,"boss_spawned":boss_spawned,"boss_defeated":boss_defeated,"convoy_route_choice":convoy_route_choice,"convoy_halted":convoy_halted,"convoy_encounter_stage":convoy_encounter_stage,"convoy_pending":{},"shells":[]})
 if not convoy_pending.is_empty():data.convoy_pending={"stage":convoy_pending.stage,"clock":convoy_pending.clock}
 for shell in shells:
  data.shells.append({"from":vec_data(shell.from),"to":vec_data(shell.to),"time":shell.time,"duration":shell.duration,"damage":shell.damage,"radius":shell.radius,"kind":shell.kind,"critical":shell.critical})
 for event in blast_queue:data.blast_queue.append({"pos":vec_data(event.pos),"radius":event.radius,"damage":event.damage,"generation":event.generation})
 for card in cards:data.cards.append(card.id)
 for b in buildings:data.buildings.append({"kind":b.kind,"pos":vec_data(b.node.position),"hp":b.hp,"maxhp":b.maxhp,"built":b.built,"cd":b.cd,"shots":b.shots,"enabled":b.enabled,"paid_cost":b.get("paid_cost",0),"paid_resources":b.get("paid_resources",{}).duplicate(),"queue":b.get("queue",[]).duplicate(true),"rally":vec_data(b.get("rally",b.node.position)),"rally_target_index":resource_nodes.find(b.get("rally_target"))})
 for s in sites:data.sites.append({"kind":s.kind,"pos":vec_data(s.node.position),"progress":s.progress,"reclaimed":s.reclaimed,"stock":s.stock,"paid":s.paid})
 for resource in resource_nodes:
  data.resource_nodes.append({"resource":resource.resource,"pos":vec_data(resource.node.position),"stock":resource.stock,"renewable":resource.renewable,"radius":resource.radius,"source_building_index":buildings.find(resource.source_building)})
 for u in units:
  var target_type=""
  var target_index=-1
  if u.target!=null:
   if u.task=="site":target_type="site";target_index=sites.find(u.target)
   if u.task in ["build","repair"]:target_type="build";target_index=buildings.find(u.target)
   if u.task=="focus_fire":target_type="enemy";target_index=living_enemies.find(u.target)
   if u.task=="escort":target_type="unit";target_index=units.find(u.target)
   if u.task=="gather":target_type="resource";target_index=resource_nodes.find(u.target)
  if target_index<0:target_type=""
  data.units.append({"kind":u.kind,"pos":vec_data(u.node.position),"hp":u.hp,"maxhp":u.maxhp,"goal":vec_data(u.goal),"task":u.task,"target_type":target_type,"target_index":target_index,"escort_slot":u.get("escort_slot",0),"escort_repath":u.get("escort_repath",0),"yaw":u.node.rotation.y,"cd":u.cd,"work":u.work,"shots":u.shots})
  var saved=data.units.back()
  if target_type=="" and u.task in ["site","build","repair","focus_fire","escort"]:saved.task="idle"
  for field in ["cargo_kind","cargo","resource_kind","economy_phase","gather_requires_work"]:
   if u.has(field):saved[field]=u[field]
  saved["resource_target_index"]=resource_nodes.find(u.get("resource_target"))
  saved["dropoff_index"]=buildings.find(u.get("dropoff_target"))
  # Paused removal may precede the next economy tick. Persist its recoverable
  # phase without mutating the live worker or abandoning paid pending work.
  if saved.task=="gather":
   if saved.resource_target_index<0 and saved.get("economy_phase","") in ["to_resource","gathering"]:saved.economy_phase=""
   if saved.dropoff_index<0 and saved.get("economy_phase","")=="to_dropoff":saved.economy_phase="waiting_dropoff"
  var assignment=u.get("return_assignment",{})
  saved["return_assignment"]={"resource":assignment.get("resource",""),"target_index":resource_nodes.find(assignment.get("target"))}
  saved["pending_orders"]=WorkerOrders.snapshot(self,u)
  if u in selected:data.selected.append(units.find(u))
 for e in living_enemies:
  if not e.dead:data.enemies.append({"pos":vec_data(e.node.position),"hp":e.hp,"speed":e.speed,"cd":e.cd,"armored":e.get("armored",false),"charged_until":e.get("charged_until",0),"convoy_hunter":e.get("convoy_hunter",false),"boss":e.get("boss",false),"windup":e.get("windup",0),"attack_pos":vec_data(e.get("attack_pos",e.node.position))})
 data["control_groups"]=control_groups.snapshot(units,buildings)
 # Selection shortcuts can set focus before the next frame clamps the view.
 data["camera"]={"focus":vec_data(Vector3(clampf(camera_focus.x,-18,18),0,clampf(camera_focus.z,-18,18))),"size":clampf(camera.size,26,85)}
 return data

func load_checkpoint()->bool:
 var d=CheckpointValidation.read("user://settlement_v2/checkpoint.json")
 if ended or not valid_checkpoint(d) or int(d.mission)!=campaign_state.current:return false
 var recovered=CheckpointValidation.last_read_used_backup
 building_attack_alerts.reset()
 building_attack_button.visible=false
 active_card=false;cards.clear();pending_upgrade_levels.clear();pending_card_delay=0
 if is_instance_valid(choice_panel):choice_panel.queue_free()
 choice_panel=null
 for shell in shells:shell.node.queue_free()
 shells.clear()
 for corpse in corpses:corpse.node.queue_free()
 corpses.clear()
 for resource in resource_nodes:
  if resource.source_building.is_empty():resource.node.queue_free()
 resource_nodes.clear()
 friendly_navigation.clear_reservations()
 for collection in [units,enemies,buildings,sites]:
  for item in collection:item.node.queue_free()
  collection.clear()
 selected.clear();inspected={};inspected_resource={};inspected_site={}
 stockpile=d.stockpile.duplicate();settlement_age=int(d.settlement_age);tech_level=settlement_age
 for raw in d.buildings:
  var b=make_building(raw.kind,from_data(raw.pos),true)
  for key in ["hp","maxhp","built","cd"]:b[key]=raw[key]
  b.node.get_meta(ConstructionVisuals.META).set_progress(b.built)
  b.shots=raw.get("shots",0)
  b.enabled=raw.get("enabled",true)
  b.paid_cost=raw.get("paid_cost",0)
  b.paid_resources=raw.get("paid_resources",{}).duplicate()
  b.queue=raw.get("queue",[]).duplicate(true)
  b.rally=from_data(raw.get("rally",raw.pos))
 for raw in d.sites:
  make_site(raw.kind,from_data(raw.pos))
  var s=sites.back()
  for key in ["progress","reclaimed","stock","paid"]:s[key]=raw[key]
  if s.reclaimed:
   StructureVisuals.set_site_reclaimed(s.node,true)
   s.label.text=site_title(s.kind)+" [復旧済]"
   s.label.modulate=CYAN
 for raw in d.resource_nodes:
  var owner:Dictionary={}
  var owner_index=int(raw.get("source_building_index",-1))
  if owner_index>=0 and owner_index<buildings.size():owner=buildings[owner_index];owner["garden_registered"]=true
  var resource=make_resource(raw.resource,from_data(raw.pos),raw.stock,raw.renewable,owner)
  resource.radius=raw.get("radius",1.4)
 for i in d.buildings.size():
  var index=int(d.buildings[i].get("rally_target_index",-1))
  if index>=0 and index<resource_nodes.size():buildings[i].rally_target=resource_nodes[index]
 for raw in d.units:
  var u=make_unit(raw.kind,from_data(raw.pos))
  for key in ["hp","maxhp","task","cd","work"]:u[key]=raw[key]
  u.goal=from_data(raw.goal)
  u.shots=raw.get("shots",0)
  u["escort_slot"]=int(raw.get("escort_slot",0))
  u["escort_repath"]=float(raw.get("escort_repath",0))
  u.node.rotation.y=float(raw.get("yaw",0))
  for field in ["cargo_kind","cargo","resource_kind","economy_phase","gather_requires_work"]:
   if raw.has(field):u[field]=raw[field]
  var resource_index=int(raw.get("resource_target_index",-1))
  var dropoff_index=int(raw.get("dropoff_index",-1))
  u["resource_target"]=resource_nodes[resource_index] if resource_index>=0 and resource_index<resource_nodes.size() else null
  u["dropoff_target"]=buildings[dropoff_index] if dropoff_index>=0 and dropoff_index<buildings.size() else null
  var assignment=raw.get("return_assignment",{})
  var return_index=int(assignment.get("target_index",-1))
  if not assignment.get("resource","").is_empty():u["return_assignment"]={"resource":assignment.resource,"target":resource_nodes[return_index] if return_index>=0 and return_index<resource_nodes.size() else null}
  WorkerOrders.restore(self,u,raw.get("pending_orders",[]))
  if raw.target_index>=0:
   if raw.target_type=="site" and raw.target_index<sites.size():u.target=sites[raw.target_index]
   if raw.target_type=="build" and raw.target_index<buildings.size():u.target=buildings[raw.target_index]
   if raw.target_type=="resource" and raw.target_index<resource_nodes.size():u.target=resource_nodes[raw.target_index]
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
  if raw.target_type=="unit" and raw.target_index>=0 and raw.target_index<units.size():units[i].target=units[int(raw.target_index)]
 for unit in units:
  if unit.task=="escort" and (unit.target==null or not EscortOrders.can_follow(unit,unit.target)):
   unit.task="idle";unit.target=null;unit.goal=unit.node.position
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
 run_seed=int(d.run_seed);campaign_state.run_seed=run_seed
 # Restore after constructors have consumed random draws. Re-seed first so
 # both the seed metadata and exact continuation state describe the saved run.
 seed_run_streams()
 rng.state=int(d.rng);card_rng.state=int(d.card_rng);visual_rng.state=int(d.visual_rng)
 for earned_level in d.pending_upgrade_levels:pending_upgrade_levels.append(int(earned_level))
 for id in d.cards:cards.append(UpgradeCatalog.by_id(id))
 for index in d.selected:
  if index<units.size():selected.append(units[index])
 control_groups.restore(d.get("control_groups",[]),units,buildings)
 update_selection()
 # Checkpoints without a saved view use the original camera defaults. Restore
 # synchronously so Continue opens here before the first process frame.
 var view:Dictionary=d.get("camera",{"focus":[0,0,0],"size":54})
 camera_focus=from_data(view.focus)
 camera.size=float(view.size)
 camera.position=camera_focus+Vector3(37,48,43)
 camera.look_at(camera_focus)
 if d.active_card:
  active_card=true
  display_cards()
 recompute_power()
 simulation_clock.reset()
 render_interpolation.reset(units,enemies,corpses)
 notify("直前の保存から再開しました。" if recovered else "前回の作戦を再開しました。",3)
 rebuild_navigation()
 return true

func show_options():
 if title_open or active_card or ended or is_instance_valid(options_panel):return
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
 v.add_child(label("作戦メニュー",32,CYAN))
 v.add_child(button("作戦を保存",func():save_checkpoint();close_options(),350))
 v.add_child(button("保存して作戦選択へ",return_title,350))
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
 var controls=label(CONTROLS_HELP,16,Color("bcb69d"))
 controls.name="ControlsHelp"
 v.add_child(controls)
 v.add_child(button("作戦に戻る",close_options,350))

func close_options():
 if is_instance_valid(options_panel):options_panel.queue_free()
 paused=options_previous_pause

func valid_checkpoint(d:Variant)->bool:
 return CheckpointValidation.validate(d)

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
 production.update(dt*production_multiplier())
 build_boost=maxf(0,build_boost-dt)
 victory_boost=maxf(0,victory_boost-dt)
 ammo=minf(400,ammo+dt*2)
 power_clock-=dt
 if power_clock<=0:
  power_clock=1
  recompute_power()
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
 var industry=active_producers()
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
 for kind in ["factory","vehicle_workshop","mortar","tower","yard"]:
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
 if kind in ["truck","convoy"]:StructureVisuals.add_vehicle(render_interpolation.visual_root(n),kind)
 elif kind=="siegecart":
  render_interpolation.visual_root(n).add_child((load("res://assets/models/siege_cart.glb") as PackedScene).instantiate())
 else:
  ActorVisuals.add_human(n,kind)
  for mesh in n.find_children("*","MeshInstance3D",true,false):mesh.visible=false

func decorate_building(kind:String,n:Node3D,_rad:float,preview:bool=false):
 var finished=Node3D.new();finished.name="FinishedVisual";n.add_child(finished)
 StructureVisuals.add_building(finished,kind)
 if not preview and kind in ["hq","factory","relay","yard","mortar"]:
  world_label(n,{"hq":"生存者の拠点","factory":"弾薬工房","relay":"電力中継","yard":"廃材回収所","mortar":"廃材臼砲"}[kind],Vector3(0,4.1 if kind=="hq" else 3.5,0),CYAN)

func portrait_for(kind:String)->Texture2D:
 return CommandDeck.portrait(kind)

func command_icon_button(kind:String,title:String,cost:String,callback:Callable)->Button:
 return CommandDeck.command_button(kind,title,cost,callback,font)


func selected_order_text()->String:
 if attack_move:return "攻撃移動: 指示待ち"
 if not build_mode.is_empty():return "建設: 配置待ち"
 if selected.is_empty():return "未選択"
 var kinds=[]
 for u in selected:
  var navigation_status=friendly_navigation.current_status(u)
  if navigation_status in [FriendlyNavigation.BLOCKED,FriendlyNavigation.WORK_WAITING]:return friendly_navigation.status_text(u)
  var task=u.task
  if task=="move" and navigation_status==FriendlyNavigation.PENDING:task="move_pending"
  if task=="gather":
   task={"to_resource":"採取へ移動","gathering":"採取中","to_dropoff":"搬入中","waiting_resource":"近くの資源が枯渇","waiting_dropoff":"搬入先なし"}.get(u.get("economy_phase",""),"採取・搬入")
   if selected.size()==1:
    var resource_title=str(GameRules.RESOURCE_TITLES.get(u.get("resource_kind",""),"資源"))
    if u.get("economy_phase","") in ["to_resource","gathering"]:task=resource_title+" "+task
    elif u.get("economy_phase","")=="waiting_resource":task=resource_title+"が枯渇"
  if task=="site" and u.target!=null:task="salvage" if u.target.kind=="scrap" else "restore"
  if not task in kinds:kinds.append(task)
 if kinds.size()>1:return "複数命令"
 return {"idle":"待機","move":"移動中","move_pending":"経路を確認中","attack_move":"攻撃移動","focus_fire":"集中攻撃","escort":"護衛・追尾","gather":"採取・搬入","repair":"修理中","salvage":"回収中","restore":"復旧中","build":"建設中"}.get(kinds[0],kinds[0])

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

func base_power()->float:return 12.0 if settlement_age>=3 else 7.0

func near_yard(p:Vector3)->bool:
 for b in buildings:
  if b.kind=="yard" and b.built>=1 and p.distance_to(b.node.position)<12:return true
 return false

func start_research():
 if inspected.is_empty():return
 production.queue_age(inspected)
 refresh_context_commands(true)

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
 if settlement_age<3 or not generator_on or not get_site("pump").reclaimed:
  notify("発電所と貨物中継所を復旧し、発電を開始してください。")
  return
 if resources<80:notify("輸送物資の積込みに廃材80が必要。") ;return
 resources-=80
 convoy_started=true
 convoy_index=1
 var vehicle=make_unit("convoy",convoy_route()[0])
 vehicle.goal=convoy_route()[1]
 vehicle.task="convoy"
 world_label(render_interpolation.visual_root(vehicle.node),"物資輸送隊",Vector3(0,3.2,0),AMBER)
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
   if friendly_navigation.is_arrived(convoy):
    convoy_index+=1
    if convoy_index>=convoy_route().size():finish(true);return
    convoy.goal=convoy_route()[convoy_index]
   hold_time=convoy_progress()*100
  return
 var restored=settlement_age>=3 and generator_on and get_site("pump").reclaimed
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
  if u.node.position.distance_to(p)<4.5:
   u.hp-=45
   building_attack_alerts.record_hit(u,elapsed)
 for b in buildings:
  if b.node.position.distance_to(p)<4.5+b.radius:
   b.hp-=175 if b.kind=="wall" else 120
   building_attack_alerts.record_hit(b,elapsed)
 enemy.cd=3.2
 audio_system.play_event("heavy_hit",p,1.4)


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
 if settlement_age<3 or not generator_on or not get_site("pump").reclaimed:
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

func dismantle_refund_cost(building:Dictionary)->Dictionary:
 if not can_dismantle(building):return {}
 var result:Dictionary={}
 var fraction=(1-.5*clampf(building.built,0,1))*clampf(building.hp/maxf(1,building.maxhp),0,1)
 for kind in building.get("paid_resources",{}):result[kind]=floori(float(building.paid_resources[kind])*fraction)
 return result

func dismantle_refund(building:Dictionary)->int:return int(dismantle_refund_cost(building).get("salvage",0))

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
 var name=GameRules.building(dismantle_target.kind).title
 col.add_child(label(name+"を解体する？",26,AMBER))
 col.add_child(label("回収: "+GameRules.cost_text(dismantle_refund_cost(dismantle_target))+"。予約は返金されます。",17))
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
 var recovered=dismantle_refund_cost(building)
 production.on_building_destroyed(building)
 remove_garden_resource(building)
 buildings.erase(building)
 if inspected==building:inspected={}
 building.node.queue_free();refund_cost(recovered)
 rebuild_navigation();recompute_power();context_signature=""
 notify("解体: "+GameRules.cost_text(recovered)+"を回収",3)
 tone("build")
 return true

func make_resource(kind:String,p:Vector3,stock:float,renewable:bool=false,source_building:Dictionary={})->Dictionary:
 var node:Node3D
 if source_building.is_empty():
  node=Node3D.new();add_child(node);node.position=p
  ResourceVisuals.add_resource(node,kind)
 else:node=source_building.node
 var title=GameRules.RESOURCE_TITLES.get(kind,kind)
 var caption=world_label(node,title,Vector3(0,2,0),resource_color(kind))
 var data={"node":node,"resource":kind,"stock":stock,"renewable":renewable,"radius":float(source_building.get("radius",1.4)),"label":caption,"source_building":source_building}
 resource_nodes.append(data)
 return data

func resource_color(kind:String)->Color:return {"food":Color("afbd76"),"salvage":AMBER,"parts":Color("8fb0ba")}.get(kind,PALE)

func resource_at(p:Vector3)->Dictionary:
 var nearest:Dictionary={};var distance:float=INF
 for resource in resource_nodes:
  if not is_instance_valid(resource.node):continue
  var d:float=resource.node.position.distance_to(p)
  if d<float(resource.radius)+1.1 and d<distance:nearest=resource;distance=d
 return nearest

func building_completed(building:Dictionary):
 if building.kind=="garden" and not building.get("garden_registered",false):
  building["garden_registered"]=true
  make_resource("food",building.node.position,0,true,building)
 context_signature=""

func finish_construction_order(worker:Dictionary):
 WorkerOrders.finish(self,worker,true)

func remove_garden_resource(building:Dictionary):
 building["being_removed"]=true
 for resource in resource_nodes.duplicate():
  if resource.get("source_building",{})==building:
   resource_nodes.erase(resource)
   if is_instance_valid(resource.get("label")):resource.label.queue_free()
 for worker in units:
  if worker.kind=="worker" and worker.task in ["build","repair"] and worker.target==building:
   finish_construction_order(worker)

func spend_cost(cost:Dictionary)->bool:
 if not GameRules.can_afford(stockpile,cost):return false
 for kind in cost:stockpile[kind]=float(stockpile.get(kind,0))-float(cost[kind])
 return true

func refund_cost(cost:Dictionary):
 for kind in cost:stockpile[kind]=float(stockpile.get(kind,0))+maxf(0,float(cost[kind]))

func production_notice(text:String):
 if is_instance_valid(center_notice):notify(text,3)
 context_signature=""

func economy_notice(text:String):
 if float(economy_notice_until.get(text,-1))>elapsed:return
 economy_notice_until[text]=elapsed+8
 if is_instance_valid(center_notice):notify(text,3)

func resource_deposited(_kind:String,amount:float):gathered+=amount

func worker_deposited(worker:Dictionary):WorkerOrders.after_deposit(self,worker)

func worker_work_rate(worker:Dictionary,kind:String)->float:
 return float(GameRules.RESOURCE_RULES[kind].rate)*(1+bonus("salvage","salvage_speed_add"))*(1.2 if near_yard(worker.node.position) else 1.0)

func worker_carry_capacity(_worker:Dictionary,kind:String)->float:
 return float(GameRules.RESOURCE_RULES[kind].capacity)*(1+.15*maxi(0,settlement_age-1))

func complete_age(age:int):
 settlement_age=age;tech_level=age
 recompute_power();context_signature=""
 notify(GameRules.age(age).title+"へ発展",6)
 if is_instance_valid(audio_system):audio_system.play_event("power")

func spawn_produced_unit(kind:String,building:Dictionary)->Dictionary:
 var point:Vector3=building.node.position+Vector3(0,0,float(building.radius)+1.8)
 var cell=open_cell(point,building.node.position)
 var unit=make_unit(kind,Vector3(cell.x,0,cell.y))
 var resource:Variant=building.get("rally_target")
 if kind=="worker" and resource!=null and resource in resource_nodes:
  economy.assign_resource(unit,resource)
 else:
  var rally:Vector3=building.get("rally",point)
  unit.goal=friendly_navigation.rally_destination(nav,rally,unit,units) if kind in ["guard","grenade","siegecart"] else rally
  unit.task="move";unit.planned=Vector3.INF
 if is_instance_valid(audio_system):audio_system.play_event("build_complete",unit.node.position)
 return unit

func active_producers()->int:
 var count:int=0
 for building in buildings:
  if not building.get("queue",[]).is_empty() or building.get("production_state","")=="生産中":count+=1
 return count

func compact_cost(cost:Dictionary)->String:
 var parts=[]
 for kind in ["food","salvage","parts"]:
  if cost.get(kind,0)>0:parts.append({"food":"食","salvage":"廃","parts":"部"}[kind]+str(int(cost[kind])))
 return " ".join(parts)

func set_rally(building:Dictionary,p:Vector3):
 if GameRules.unit_kinds_for(building.kind).is_empty():return
 building.rally=p;building.rally_target=resource_at(p) if building.kind=="hq" else null
 if building.rally_target is Dictionary and building.rally_target.is_empty():building.rally_target=null
 pulse(p,AMBER,1.3,.6);tone("order")
 context_signature=""

func select_headquarters():
 for building in buildings:
  if building.kind=="hq":
   selected.clear();inspected=building;inspected_site={};inspected_resource={}
   camera_focus=building.node.position;update_selection();return

func worker_needs_attention(unit:Dictionary)->bool:
 if unit.kind!="worker":return false
 return unit.task=="idle" or unit.get("economy_phase","") in ["waiting_resource","waiting_dropoff"] or friendly_navigation.current_status(unit)==FriendlyNavigation.BLOCKED

func select_idle_worker():
 var idle=[]
 for unit in units:
  if worker_needs_attention(unit):idle.append(unit)
 if idle.is_empty():return
 last_idle_worker=(last_idle_worker+1)%idle.size()
 selected=[idle[last_idle_worker]];inspected={};inspected_site={};inspected_resource={}
 camera_focus=selected[0].node.position;update_selection()

func stop_selected():
 for unit in selected:
  if unit.kind=="convoy":continue
  friendly_navigation.invalidate_order(unit)
  if unit.kind=="worker":WorkerOrders.clear(unit);economy.cancel_assignment(unit)
  unit.task="idle";unit.target=null;unit.goal=unit.node.position;unit.route.clear();unit.planned=Vector3.INF
 context_signature=""

func filter_selection(kind:String):
 selected=selected.filter(func(unit):return unit.kind=="worker" if kind=="worker" else unit.kind in ["guard","grenade","siegecart"])
 update_selection()

func begin_attack_move():
 if not selected.any(func(unit):return unit.kind in ["guard","grenade","siegecart"]):return
 attack_move=true
 notify("右クリックで攻撃移動の目的地を指定",3)

func refresh_context_commands(force:bool=false):
 if not is_instance_valid(command_grid):return
 if not inspected.is_empty() and (not is_instance_valid(inspected.get("node")) or not inspected in buildings):inspected={}
 var identity="%s/%s/%s/%s/%s"%[str(selected.map(func(unit):return unit.node.get_instance_id())),inspected.get("node",null),settlement_age,worker_build_page,inspected_resource.get("node",null)]
 if force or identity!=context_signature:
  context_signature=identity
  hovered_command={}
  for child in command_grid.get_children():command_grid.remove_child(child);child.queue_free()
  context_actions.clear()
  if not selected.is_empty():
   var worker_count=selected.filter(func(unit):return unit.kind=="worker").size()
   if worker_count==selected.size():
    command_heading.text="建設  /  "+("住居・経済" if worker_build_page=="economy" else "生産・防衛")
    var types=["house","depot","garden","factory","yard"] if worker_build_page=="economy" else ["barracks","tower","wall","relay","vehicle_workshop","mortar"]
    for kind in types:
     var rule=GameRules.building(kind)
     add_context_action(kind,rule.title,compact_cost(rule.cost),func():set_build(kind),func():return build_availability(kind))
    add_context_action("worker","防衛施設 →" if worker_build_page=="economy" else "← 生活施設","建築ページ",func():worker_build_page="military" if worker_build_page=="economy" else "economy";refresh_context_commands(true))
    add_context_action("select","停止","命令を解除",stop_selected)
   elif worker_count>0:
    command_heading.text="混成部隊"
    add_context_action("select","停止","命令を解除",stop_selected)
    add_context_action("worker","作業員だけ","選択を絞る",func():filter_selection("worker"))
    add_context_action("guard","戦闘員だけ","選択を絞る",func():filter_selection("combat"))
   elif selected.size()==1 and selected[0].kind=="convoy":
    command_heading.text="物資輸送隊"
    add_context_action("truck","停車・再発進","輸送隊を待機",toggle_convoy_stop)
   else:
    command_heading.text="部隊命令"
    if selected.any(func(unit):return unit.kind in ["guard","grenade","siegecart"]):add_context_action("attack","攻撃移動","右クリックで指示",begin_attack_move)
    add_context_action("select","停止","命令を解除",stop_selected)
  elif not inspected.is_empty():
   var building=inspected
   command_heading.text="生産・発展" if building.kind=="hq" else "部隊生産" if not GameRules.unit_kinds_for(building.kind).is_empty() else "施設操作"
   if building.built>=1:
    for kind in GameRules.unit_kinds_for(building.kind):
     var rule=GameRules.unit(kind)
     add_context_action(kind,rule.title,compact_cost(rule.cost),func():production.queue_unit(building,kind),func():return production.can_queue_unit(building,kind))
    if building.kind=="hq" and settlement_age<3:
     add_context_action("research","段階%sへ"%["II","III"][settlement_age-1],compact_cost(GameRules.age(settlement_age+1).cost),func():production.queue_age(building),func():return production.can_queue_age(building))
    if not GameRules.unit_kinds_for(building.kind).is_empty():add_context_action("select","予約を取消","最後の注文を返金",func():production.cancel_last(building),func():return {"ok":not building.queue.is_empty(),"reason":"予約なし"})
    if building.kind=="factory":add_context_action("factory","稼働切替","弾薬を生産",toggle_inspected)
    if building.kind=="garden":add_context_action("worker","作業員を選択","右クリックで耕作",select_idle_worker)
  elif not inspected_resource.is_empty():
   command_heading.text=GameRules.RESOURCE_TITLES[inspected_resource.resource]
  elif not inspected_site.is_empty():
   command_heading.text=site_title(inspected_site.kind)
   if inspected_site.kind=="generator" and inspected_site.reclaimed:add_context_action("relay","発電切替","騒音と送電",toggle_generator)
  else:
   command_heading.text="対象を選択"
   add_context_action("house","本部へ","増員・発展",select_headquarters,Callable(),KEY_H)
   add_context_action("worker","待機作業員","次の1人を選択",select_idle_worker,Callable(),KEY_PERIOD)
  command_heading.tooltip_text="Shift+右クリックで作業を予約。通常の右クリックで現在の命令を変更。\n建設中はShift+左クリックで連続配置。詳しい操作はメニュー。" if selected.any(func(unit):return unit.kind=="worker") else "地面を右クリックで移動、敵で集中攻撃、仲間で護衛。詳しい操作はメニュー。"
  if not inspected.is_empty() and not GameRules.unit_kinds_for(inspected.kind).is_empty():command_heading.tooltip_text="右クリックで集合地点を設定。"+("資源を指定すると作業員が採取へ向かいます。" if inspected.kind=="hq" else "")
 for action in context_actions:
  var blocked=""
  var short_blocked=""
  if action.check.is_valid():
   var check=action.check.call()
   if not check.ok:
    blocked=check.get("reason","")
    short_blocked=check.get("short_reason","")
  action.button.tooltip_text=action.get("detail","")
  CommandDeck.set_command_state(action.button,blocked,build_mode==action.kind or (attack_move and action.kind=="attack"),short_blocked)
  CommandDeck.set_command_affordability(action.button,stockpile,action.cost)
  if not blocked.is_empty():action.button.tooltip_text=blocked+"  /  "+action.get("detail","")
 update_queue_display()
 if is_instance_valid(command_detail):
  var detail_text=hovered_command.get("button").tooltip_text if not hovered_command.is_empty() and is_instance_valid(hovered_command.get("button")) else ""
  if hovered_command.is_empty() and inspected.get("kind","")=="hq" and settlement_age<3:
   var next_age=production.can_queue_age(inspected)
   if not next_age.ok:
    detail_text=next_age.get("reason","")
    if detail_text.begins_with("必要施設:"):detail_text="発展 "+compact_cost(GameRules.age(settlement_age+1).cost)+" / "+detail_text
  command_detail.text=detail_text

func build_availability(kind:String)->Dictionary:
 var check=GameRules.can_build(kind,settlement_age,buildings)
 if not check.ok:return check
 if not GameRules.can_afford(stockpile,GameRules.building(kind).cost):return {"ok":false,"reason":"必要: "+GameRules.cost_text(GameRules.building(kind).cost)}
 return {"ok":true,"reason":""}

func add_context_action(kind:String,title:String,cost:String,callback:Callable,check:Callable=Callable(),key:int=0):
 var keys=[KEY_Q,KEY_W,KEY_E,KEY_R,KEY_A,KEY_S,KEY_D,KEY_F,KEY_Z,KEY_X]
 if key==0:key=keys[mini(context_actions.size(),keys.size()-1)]
 var caption=OS.get_keycode_string(key)+" "+title
 var b=command_icon_button(kind,caption,cost,func():callback.call();context_signature="")
 var detail=cost
 if GameRules.BUILDINGS.has(kind):detail=GameRules.cost_text(GameRules.building(kind).cost)+" / 建築%d秒"%int(GameRules.building(kind).build_time)
 elif GameRules.UNITS.has(kind):detail=GameRules.cost_text(GameRules.unit(kind).cost)+" / %d秒 / 人口%d"%[int(GameRules.unit(kind).time),int(GameRules.unit(kind).population)]
 if GameRules.BUILDINGS.has(kind) and not selected.is_empty():detail+=" / Shift+配置で連続建設"
 b.tooltip_text=detail
 command_grid.add_child(b)
 var price:Dictionary={}
 if GameRules.BUILDINGS.has(kind):price=GameRules.building(kind).cost
 elif GameRules.UNITS.has(kind):price=GameRules.unit(kind).cost
 elif kind=="research" and settlement_age<3:price=GameRules.age(settlement_age+1).cost
 var action={"key":key,"call":callback,"check":check,"button":b,"detail":detail,"kind":kind,"cost":price}
 context_actions.append(action)
 b.mouse_entered.connect(func():hovered_command=action)
 b.mouse_exited.connect(func():if hovered_command==action:hovered_command={})

func activate_context_key(key:int)->bool:
 for action in context_actions:
  if action.key==key:
   if not action.button.disabled:action.call.call();context_signature=""
   else:
    var reason=str(action.button.get_meta("command_blocked_reason",""))
    if not reason.is_empty():notify(reason,4)
   return true
 return false


func update_queue_icons():
 if not is_instance_valid(queue_icons):return
 var queue:Array=inspected.get("queue",[]) if not inspected.is_empty() else []
 var signature=str(queue.map(func(item):return item.get("kind",item.get("target_age",""))))
 if signature==queue_signature:return
 queue_signature=signature
 for child in queue_icons.get_children():queue_icons.remove_child(child);child.queue_free()
 for i in mini(5,queue.size()):
  var item=queue[i]
  var kind=str(item.get("kind","research")) if item.get("type")=="unit" else "research"
  var title=GameRules.unit(kind).title if item.get("type")=="unit" else "段階の発展"
  queue_icons.add_child(RTSHud.queue_slot(kind,title,i==0,queue.size()-4 if i==4 else 1,font))

func update_queue_display():
 if not is_instance_valid(queue_caption):return
 queue_bar.visible=false
 queue_caption.tooltip_text=""
 update_queue_icons()
 if not inspected.is_empty():
  var building=inspected
  if building.built<1:
   queue_caption.text="建築 %d%%"%int(building.built*100)
   queue_caption.tooltip_text="作業員を選択して右クリックで工事に追加"
   queue_bar.visible=true;queue_bar.value=building.built*100
  elif not building.get("queue",[]).is_empty():
   var item=building.queue[0]
   var title=GameRules.unit(item.kind).title if item.type=="unit" else GameRules.age(item.target_age).title
   var state={"population":"人口上限","unpowered":"未給電","disabled":"停止中","spawn_blocked":"出口が塞がれている"}.get(building.get("queue_state",""),"")
   queue_caption.text="%s  %s  /  予約%d"%[title,state if not state.is_empty() else "残り%d秒"%int(ceil(item.remaining)),building.queue.size()]
   queue_bar.visible=true;queue_bar.value=100*(1-float(item.remaining)/maxf(1,float(item.duration)))
  else:queue_caption.text=""
 elif not selected.is_empty():
  var queue_summary=WorkerOrders.summary(selected)
  if not queue_summary.is_empty():queue_caption.text=queue_summary
  else:queue_caption.text=""
 else:queue_caption.text=""
 queue_caption.visible=not queue_caption.text.is_empty()
 queue_icons.visible=queue_icons.get_child_count()>0

func set_command_tab(_tab:String):refresh_context_commands(true)

func update_ui():
 if not is_instance_valid(stats):return
 var resource_workers:Dictionary=economy.resource_worker_counts(units)
 for kind in ["food","salvage","parts"]:
  hud_counters[kind].value.text=str(int(stockpile[kind]))
  hud_counters[kind].assigned.text="%d人"%resource_workers[kind]
 hud_counters.population.value.text="%d / %d"%[production.population_used(),production.population_cap()]
 RTSHud.set_label_color(hud_counters.population.value,RED if production.population_used()>=production.population_cap() else PALE)
 hud_counters.population.root.tooltip_text="居住枠。住居1棟で上限+5。予約中の部隊は完成時に人口を使用。"
 hud_counters.age.value.text=["I","II","III"][clampi(settlement_age-1,0,2)]
 hud_counters.age.root.tooltip_text="復興本部を選択して次の段階へ発展"
 hud_counters.experience.value.text="Lv %d"%level
 RTSHud.set_growth_pending(hud_counters.experience,pending_upgrade_levels.size())
 hud_counters.experience.root.tooltip_text="共有XP %d / %d。強化 %d件。クリック / Tabで選択、Escで保留。"%[int(xp),int(xp_needed()),pending_upgrade_levels.size()]
 hud_counters.ammo.value.text="%d"%int(ammo)
 RTSHud.set_label_color(hud_counters.ammo.value,RED if ammo<40 else PALE)
 hud_counters.ammo.root.tooltip_text="弾薬 %d / 400。弾薬工房で補給。枯渇時は予備弾で威力40%%。"%int(ammo)
 hud_counters.power.value.text=str(snappedf(power_used,.1))+" / "+str(snappedf(power_capacity,.1))
 hud_counters.power.root.tooltip_text="使用電力 / 発電容量。施設は送電範囲と空き電力が必要。"
 var idle_count=units.filter(func(unit):return worker_needs_attention(unit)).size()
 idle_worker_button.text="待機 %d"%idle_count;idle_worker_button.disabled=idle_count==0
 var gen=get_site("generator");var pump=get_site("pump")
 var progress_lines:Array[String]=[]
 if gen.reclaimed:progress_lines.append("発電中" if generator_on else "発電停止")
 elif gen.progress>0:progress_lines.append("発電所 復旧 %d%%"%int(gen.progress*100))
 if not pump.reclaimed and pump.progress>0:progress_lines.append(mission.facility+" 復旧 %d%%"%int(pump.progress*100))
 if mission.mode=="convoy":
  if convoy_started:progress_lines.append("輸送 %d%%"%int(convoy_progress()*100))
  mission_action_button.text="輸送隊へ" if convoy_started else "輸送路を選ぶ"
  convoy_pause_button.visible=convoy_started and not ended
  convoy_pause_button.text="車列を再発進" if convoy_halted else "車列を停車"
  if not convoy_pending.is_empty():progress_lines.append("追走群 %s / %.1f秒"%[ConvoyPlan.encounter(convoy_pending.stage,convoy_route_choice).direction,maxf(0,convoy_pending.clock)])
 elif mission.mode=="finale":
  var sub=get_site("substation")
  if not sub.reclaimed and sub.progress>0:progress_lines.append("変電所 復旧 %d%%"%int(sub.progress*100))
  if hold_time>0 or (settlement_age>=3 and pump.reclaimed and sub.reclaimed):progress_lines.append("初期送電 %d/%d秒"%[int(hold_time),int(mission.hold)])
  if boss_spawned:progress_lines.append("破砕体 "+("撃破" if boss_defeated else "接近"))
  mission_action_button.text="変電所へ"
 elif hold_time>0 or (settlement_age>=3 and pump.reclaimed):progress_lines.append("揚水 %d/%d秒"%[int(hold_time),int(mission.hold)])
 objective.text="\n".join(progress_lines);objective.visible=not progress_lines.is_empty()
 pause_button.text="再開" if paused else "一時停止"
 core_bar.value=buildings[0].hp if not buildings.is_empty() else 0
 core_bar.tooltip_text="復興本部 耐久 %d/%d"%[int(core_bar.value),int(core_bar.max_value)]
 guide.text=tutorial_instruction();guide.visible=not guide.text.is_empty()
 generator_button.text="発電停止" if generator_on else "発電起動"
 generator_button.disabled=not gen.reclaimed
 var warning_text="次の襲撃 %d秒  /  騒音 %d"%[int(maxf(0,wave_clock)),int(noise)]
 if buildings.any(func(building):return building.kind=="relay" and building.powered):warning_text+=" / 次は"+wave_direction_text(wave+1)
 status.text=warning_text
 RTSHud.set_label_color(status,AMBER if wave_clock<=20 else Color("aca994"))
 context_button.visible=false
 dismantle_button.visible=can_dismantle(inspected)
 if dismantle_button.visible:dismantle_button.text="解体"
 xp_bar.visible=false;supply_status.visible=true
 var supply_text=""
 var supply_tooltip=""
 var selection_tooltip=""
 var portrait_kind="hq";var hp_sum:float=0;var max_sum:float=0
 var selection_text="未選択"
 if not selected.is_empty():
  portrait_kind=selected[0].kind
  var names=[]
  for unit in selected:
   hp_sum+=unit.hp;max_sum+=unit.maxhp
   var title=GameRules.unit(unit.kind).get("title",unit.kind)
   if not title in names:names.append(title)
  var selection_title=names[0] if names.size()==1 else "混成部隊"
  selection_text=selection_title+(" ×%d"%selected.size() if selected.size()>1 else "")+"\n"+selected_order_text()
  selection_tooltip="・".join(names)
  supply_text="耐久 %d / %d"%[int(hp_sum),int(max_sum)]
  if selected.size()==1 and selected[0].kind=="worker":
   var destination=worker_destination_text(selected[0])
   if not destination.is_empty():supply_tooltip=destination
  if selected.size()==1 and selected[0].kind=="worker" and selected[0].get("cargo",0)>0:
   var cargo_amount=str(int(selected[0].cargo)) if selected[0].cargo>=1 else "1未満"
   supply_text+="\n運搬: %s %s"%[GameRules.RESOURCE_TITLES.get(selected[0].cargo_kind,""),cargo_amount]
 elif not inspected.is_empty() and is_instance_valid(inspected.get("node")):
  var rule=GameRules.building(inspected.kind)
  portrait_kind=inspected.kind;hp_sum=inspected.hp;max_sum=inspected.maxhp
  selection_text=rule.title
  if inspected.kind=="factory":selection_text+="\n"+factory_status(inspected)
  elif rule.power>0:selection_text+="\n"+("給電中" if inspected.powered else "未給電")
  supply_text="耐久 %d / %d"%[int(hp_sum),int(max_sum)]
  selection_tooltip={"hq":"作業員の生産・段階の発展","barracks":"生存者・爆薬手を訓練","vehicle_workshop":"補給車・移動迫撃車を生産","house":"人口上限 +5","depot":"3資源の搬入先","garden":"作業員が食料を耕作","factory":"電力で弾薬を補給","relay":"送電範囲を延長","yard":"近くの採取・修理を支援","tower":"自動迎撃","mortar":"範囲砲撃","wall":"感染者の進行を遮る"}.get(inspected.kind,"")
  if inspected.kind in ["house","depot","garden","relay","yard","tower","mortar","wall"]:supply_text+="\n"+selection_tooltip
 elif not inspected_resource.is_empty():
  portrait_kind=inspected_resource.resource
  supply_text="作業員を選択して右クリックで採取"
  selection_text=GameRules.RESOURCE_TITLES[inspected_resource.resource]+"\n"+("菜園 / 継続生産" if inspected_resource.renewable else "残量 %d"%int(inspected_resource.stock))
 elif not inspected_site.is_empty():
  portrait_kind="pump" if inspected_site.kind=="pump" and mission.mode=="restore" else "depot" if inspected_site.kind=="pump" and mission.mode=="convoy" else "electric"
  supply_text="作業員を選択して右クリックで復旧"
  if not inspected_site.reclaimed:
   var restoration=site_rule(inspected_site.kind)
   supply_text="段階%d / %s\n%s"%[int(restoration.age),"支払済み" if inspected_site.paid else GameRules.cost_text(restoration.cost),"作業員を選択して右クリックで復旧"]
  selection_text=site_title(inspected_site.kind)+"\n"+("復旧済" if inspected_site.reclaimed else "復旧 %d%%"%int(inspected_site.progress*100))
 selection_info.text=selection_text
 selection_info.tooltip_text=selection_tooltip
 supply_status.text=supply_text
 supply_status.tooltip_text=supply_tooltip
 if portrait_kind!=last_portrait_kind:selection_portrait.texture=portrait_for(portrait_kind);last_portrait_kind=portrait_kind
 selected_hp.max_value=maxf(1,max_sum);selected_hp.value=hp_sum;selected_hp.visible=max_sum>0
 minimap.queue_redraw()
 combo_label.text="%d KILLS"%combo if combo>=10 and combo_clock>0 else "";combo_label.modulate.a=minf(1,combo_clock)
 xp_bar.max_value=xp_needed();xp_bar.value=xp
 var cursor=get_viewport().get_mouse_position()
 for site in sites:
  var hover=camera.unproject_position(site.node.position+Vector3(0,1,0)).distance_to(cursor)<34
  site.label.visible=not ended and (hover or inspected_site==site or selected.any(func(unit):return unit.target==site and unit.task=="site"))
 for resource in resource_nodes:
  if not is_instance_valid(resource.node):continue
  resource.label.text=GameRules.RESOURCE_TITLES[resource.resource]+(" / 菜園" if resource.renewable else " %d"%int(resource.stock))
  resource.label.visible=not ended and (inspected_resource==resource or camera.unproject_position(resource.node.position+Vector3(0,1,0)).distance_to(cursor)<30)
  if resource.source_building.is_empty():resource.node.visible=resource.stock>0
 for building in buildings:
  var hover=camera.unproject_position(building.node.position+Vector3(0,1.2,0)).distance_to(cursor)<30
  for child in building.node.get_children():
   if child is Label3D and child.has_meta("tactical_label"):child.visible=not ended and (hover or inspected==building)

func tutorial_instruction()->String:
 if mission.mode=="convoy" and convoy_started:return "輸送隊を護衛"
 if settlement_age==1:
  if gathered<20:return "作業員で資源を採取"
  if production.population_cap()-production.population_used()<2:return "住居を建て、人口枠を増やす"
  return "住居2・集積所・訓練所を整え\n本部で段階IIへ"
 if settlement_age==2:
  if not get_site("generator").reclaimed:return "作業員で発電所を復旧"
  if not generator_on:return "防衛を整え、発電所を起動"
  return "車両工房・弾薬工房を整え\n本部で段階IIIへ"
 if not get_site("generator").reclaimed:return "作業員で発電所を復旧"
 if not get_site("pump").reclaimed:return "作業員で"+mission.facility+"を復旧"
 if mission.mode=="finale" and not get_site("substation").reclaimed:return "作業員で変電所を復旧"
 if not generator_on:return "発電所を起動"
 if mission.mode=="convoy":return "輸送隊を護衛" if convoy_started else "輸送路を選んで出発"
 if mission.mode=="finale":return "破砕体を撃破し、送電を守る" if boss_spawned and not boss_defeated else "送電設備を守る"
 return "揚水場を守る"

func site_rule(kind:String)->Dictionary:
 if kind=="generator":return {"age":2,"cost":{"salvage":120,"parts":30},"time":60.0}
 return {"age":3,"cost":{"salvage":250 if kind=="substation" else 300,"parts":100},"time":90.0}

func work_site(unit:Dictionary,dt:float):
 var site=unit.target
 if site==null or not is_instance_valid(site.get("node")):WorkerOrders.finish(self,unit);return
 if site.reclaimed:WorkerOrders.finish(self,unit);return
 var rule=site_rule(site.kind)
 if settlement_age<int(rule.age):
  WorkerOrders.finish(self,unit);notify("この設備の復旧は段階%dから"%rule.age,3);return
 if not site.paid:
  if not spend_cost(rule.cost):
   unit.work-=dt
   if unit.work<=0:notify("復旧費用: "+GameRules.cost_text(rule.cost),3);unit.work=8
   return
  site.paid=true
 site.progress=minf(1,site.progress+dt/float(rule.time))
 if site.progress>=1:
  site.reclaimed=true;site.label.text=site_title(site.kind)+" [復旧済]"
  StructureVisuals.set_site_reclaimed(site.node,true)
  if site.kind=="pump":rerolls+=1
  pulse(site.node.position,CYAN,5,1);tone("power")
  notify(site_title(site.kind)+"を復旧",5)
  WorkerOrders.finish(self,unit);context_signature=""

func worker_retarget_radius(_worker:Dictionary,_kind:String)->float:return 14.0

func worker_resource_approach(worker:Dictionary,resource:Dictionary)->Vector3:
 var slot:int=maxi(0,units.find(worker))
 var angle:float=float(slot%10)*TAU/10.0
 var radius:float=float(resource.radius)+.85+float(slot/10)*.10
 return resource.node.position+Vector3(cos(angle)*radius,0,sin(angle)*radius)

# Economy travel retains depletion/reassignment updates while using safe arrival.
func worker_navigation_arrived(worker:Dictionary)->bool:
 return friendly_navigation.is_arrived(worker)

func clear_finished_checkpoint():
 for suffix in ["",".bak",".tmp",".bak.tmp"]:
  var path="user://settlement_v2/checkpoint.json"+suffix
  if FileAccess.file_exists(path):DirAccess.remove_absolute(path)

func retry_completion_save():
 if not ended or not result_won:return
 result_progress_error=campaign_state.complete(elapsed,kills)
 if is_instance_valid(modal) and modal.has_method("set_save_result"):modal.set_save_result(result_progress_error)
 if result_progress_error==OK:
  clear_finished_checkpoint()
  notify("達成記録を保存しました。",4)
 else:notify("達成記録を保存できませんでした。途中保存を保持しています。",4)

func update_worker_route_preview():
 if not is_instance_valid(worker_route_preview):return
 if title_open or ended or active_card or is_instance_valid(options_panel) or is_instance_valid(route_panel) or is_instance_valid(dismantle_panel) or selected.size()!=1:
  worker_route_preview.clear_preview();return
 var worker=selected[0]
 if worker.kind!="worker" or worker.hp<=0 or not is_instance_valid(worker.node) or worker.node.is_queued_for_deletion() or friendly_navigation.current_status(worker)!=FriendlyNavigation.MOVING:
  worker_route_preview.clear_preview();return
 worker_route_preview.set_selected_worker_route(worker.node.get_instance_id(),worker.node.global_position,worker.route,{"world_position":worker.get("nav_endpoint",Vector3.INF)},true)

func worker_destination_text(worker:Dictionary)->String:
 if worker.task!="gather":return ""
 if worker.get("economy_phase","")=="to_dropoff":
  var depot=worker.get("dropoff_target",{})
  if depot is Dictionary and not depot.is_empty() and is_instance_valid(depot.get("node")):
   return "搬入先: "+str(GameRules.building(depot.kind).title)
 elif worker.get("economy_phase","") in ["to_resource","gathering"]:
  return "採取先: "+str(GameRules.RESOURCE_TITLES.get(worker.get("resource_kind",""),""))
 return ""
