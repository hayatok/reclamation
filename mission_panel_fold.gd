extends RefCounted
## Desktop-only disclosure. Keep the actionable goal and urgent status in view.
static func attach(panel:PanelContainer,column:VBoxContainer,details:Array,number:int)->Button:
 var header:Label=column.get_child(0)
 var toggle=Button.new();toggle.name="MissionDetailsToggle"
 toggle.flat=true;toggle.alignment=HORIZONTAL_ALIGNMENT_LEFT
 toggle.focus_mode=Control.FOCUS_NONE;toggle.custom_minimum_size.y=28
 toggle.add_theme_font_size_override("font_size",14)
 toggle.add_theme_color_override("font_color",Color("d2b573"))
 toggle.text="作戦 %02d  −"%number
 toggle.tooltip_text="作戦の詳細を開閉"
 column.add_child(toggle);column.move_child(toggle,0);header.queue_free()
 var body=VBoxContainer.new();body.name="MissionDetails"
 body.add_theme_constant_override("separation",4)
 column.add_child(body)
 for child in details:child.reparent(body,false)
 toggle.pressed.connect(func():
  body.visible=not body.visible
  toggle.text="作戦 %02d  %s"%[number,"−" if body.visible else "+"]
  panel.set_deferred("size",Vector2(panel.size.x,0))
 )
 return toggle
