extends RefCounted
## Font-independent resource silhouettes and explicit Japanese/numeric hierarchy.
const ROOT="res://assets/ui/"
static func counter(kind:String,title:String,width:float,font:Font)->Dictionary:
 var box=HBoxContainer.new()
 box.custom_minimum_size=Vector2(width,52)
 box.add_theme_constant_override("separation",7)
 box.mouse_filter=Control.MOUSE_FILTER_STOP
 var icon=TextureRect.new()
 icon.custom_minimum_size=Vector2(28,28)
 icon.size_flags_vertical=Control.SIZE_SHRINK_CENTER
 icon.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
 icon.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
 var path=ROOT+"resource_"+kind+".svg"
 if ResourceLoader.exists(path):icon.texture=load(path)
 icon.mouse_filter=Control.MOUSE_FILTER_IGNORE
 box.add_child(icon)
 var words=VBoxContainer.new();words.mouse_filter=Control.MOUSE_FILTER_IGNORE;words.add_theme_constant_override("separation",0);box.add_child(words)
 var caption=Label.new();caption.mouse_filter=Control.MOUSE_FILTER_IGNORE;caption.text=title
 caption.add_theme_font_override("font",font);caption.add_theme_font_size_override("font_size",14)
 caption.add_theme_color_override("font_color",Color("b6b5a7"));words.add_child(caption)
 var value=Label.new();value.mouse_filter=Control.MOUSE_FILTER_IGNORE;value.text="0"
 value.add_theme_font_override("font",font);value.add_theme_font_size_override("font_size",23)
 value.add_theme_color_override("font_color",Color("f2ead7"));words.add_child(value)
 return {"root":box,"value":value,"caption":caption}

static func queue_slot(kind:String,title:String,active:bool,number:int,font:Font)->Control:
 var box=PanelContainer.new();box.custom_minimum_size=Vector2(42,36)
 var skin=StyleBoxFlat.new();skin.bg_color=Color("34382c") if active else Color("20261f")
 skin.border_color=Color("c6ae72") if active else Color("53584a");skin.set_border_width_all(2 if active else 1)
 box.add_theme_stylebox_override("panel",skin);box.tooltip_text=title
 var icon=TextureRect.new();icon.custom_minimum_size=Vector2(30,28)
 icon.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;icon.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
 var glyph={"siegecart":"mortar","convoy":"truck"}.get(kind,kind)
 var path=ROOT+"icon_"+glyph+".svg"
 if ResourceLoader.exists(path):icon.texture=load(path)
 box.add_child(icon)
 if number>1:
  var count=Label.new();count.text=str(number);count.add_theme_font_override("font",font);count.add_theme_font_size_override("font_size",13)
  count.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT);count.position=Vector2(27,18);box.add_child(count)
 return box

static func set_growth_pending(widget:Dictionary,count:int)->void:
 widget.caption.text="強化 %d [Tab]"%count if count>0 else "部隊成長"
 widget.caption.add_theme_color_override("font_color",Color("d2a148") if count>0 else Color("b6b5a7"))
