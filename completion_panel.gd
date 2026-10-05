extends Control
## Immediate result controls while the reclaimed place stays visible.
var save_status:Label
var save_retry:Button
var panel:PanelContainer
var host:Node
func setup(game:Node):
 host=game
 set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 mouse_filter=Control.MOUSE_FILTER_STOP
 panel=PanelContainer.new();add_child(panel)
 panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
 panel.offset_left=18;panel.offset_right=-18;panel.offset_top=-226;panel.offset_bottom=-16
 panel.add_theme_stylebox_override("panel",host.style(Color("20261ff2"),Color("756f51")))
 var column=VBoxContainer.new();panel.add_child(column);column.add_theme_constant_override("separation",12)
 var heading=HBoxContainer.new();heading.add_theme_constant_override("separation",24);column.add_child(heading)
 var titles=["水が戻った。","物資は届いた。","街に灯が戻った。"]
 var title=host.label(titles[host.campaign_state.current],32,host.PALE);title.size_flags_horizontal=Control.SIZE_EXPAND_FILL;heading.add_child(title)
 var stats=host.label("作戦 %02d 達成  /  %02d:%02d  /  撃破 %d  /  Lv.%d"%[host.campaign_state.current+1,int(host.elapsed)/60,int(host.elapsed)%60,host.kills,host.level],17,host.AMBER)
 stats.vertical_alignment=VERTICAL_ALIGNMENT_CENTER;heading.add_child(stats)
 var story=host.label(host.ConvoyPlan.ending(host.campaign_state.current),18,host.PALE)
 story.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;column.add_child(story)
 if host.campaign_state.current==2:column.add_child(host.label("全3作戦 完了 / オルタ湾に生活圏を再建",17,host.AMBER))
 save_status=host.label("",16,host.RED);column.add_child(save_status)
 save_retry=host.button("達成記録の保存を再試行",host.retry_completion_save,260);column.add_child(save_retry)
 var controls=HBoxContainer.new();controls.add_theme_constant_override("separation",12);column.add_child(controls)
 if host.campaign_state.current<2:controls.add_child(host.button("次の作戦へ",func():host.start_mission(host.campaign_state.current+1),220))
 controls.add_child(host.button("この作戦をもう一度",func():host.start_mission(host.campaign_state.current),220))
 controls.add_child(host.button("作戦選択へ",host.return_title,180))
 set_save_result(host.result_progress_error)
func set_save_result(result:Error):
 var failed=result!=OK
 save_status.visible=failed;save_retry.visible=failed
 save_status.text="達成記録を保存できませんでした。前回の途中保存を保持しています。" if failed else ""
 panel.offset_top=-300 if failed else -242 if host.campaign_state.current==2 else -226
