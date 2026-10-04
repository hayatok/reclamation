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
 var index={"guard":0,"grenade":0,"worker":1,"truck":2,"convoy":2,"electric":3,"lightning":3,"tower":4,"mortar":4,"support":5,"research":3,"factory":5,"yard":5,"relay":5,"wall":5}.get(kind,0)
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

static func command_button(kind:String,title:String,cost:String,callback:Callable,font:Font)->Button:
 var b=Button.new()
 b.custom_minimum_size=Vector2(153,57)
 b.focus_mode=Control.FOCUS_NONE
 b.pressed.connect(callback)
 style_button(b)
 var content=Control.new()
 b.add_child(content)
 content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 content.mouse_filter=Control.MOUSE_FILTER_IGNORE
 var visual=TextureRect.new()
 content.add_child(visual)
 visual.position=Vector2(8,9)
 visual.size=Vector2(36,36)
 visual.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
 visual.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
 var glyph=kind
 if title.begins_with("1") or title.begins_with("2"):glyph="select"
 if title.begins_with("G"):glyph="attack"
 glyph={"grenade":"grenade","mortar":"mortar","yard":"yard","research":"research","convoy":"truck"}.get(glyph,glyph)
 var file=ROOT+"icon_"+glyph+".svg"
 visual.texture=load(file) if ResourceLoader.exists(file) else load(ROOT+"icon_factory.svg")
 visual.mouse_filter=Control.MOUSE_FILTER_IGNORE
 var words=VBoxContainer.new()
 content.add_child(words)
 words.position=Vector2(51,10)
 words.add_theme_constant_override("separation",0)
 words.mouse_filter=Control.MOUSE_FILTER_IGNORE
 for pair in [[title,14,Color("e8e1ce")],[cost,12,Color("cfad6a")]]:
  var l=Label.new()
  l.text=pair[0]
  l.add_theme_font_override("font",font)
  l.add_theme_font_size_override("font_size",pair[1])
  l.add_theme_color_override("font_color",pair[2])
  l.mouse_filter=Control.MOUSE_FILTER_IGNORE
  words.add_child(l)
 b.button_down.connect(func():content.position=Vector2(1,2))
 b.button_up.connect(func():content.position=Vector2.ZERO)
 return b

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
