extends SceneTree
const CHECKPOINT = "user://settlement_v2/checkpoint.json"
const Validation = preload("res://checkpoint_validation.gd")
const Atomic = preload("res://atomic_save.gd")
const SUFFIXES = ["", ".bak", ".tmp", ".bak.tmp"]
var passed := 0
var failed := 0
var g: Node
var campaign: Node
func _initialize():
 call_deferred("run")
func check(ok: bool, label: String):
 if ok:
  passed += 1
  print("PASS ", label)
 else:
  failed += 1
  push_error("FAIL " + label)
func write_text(path: String, content: String):
 var f = FileAccess.open(path, FileAccess.WRITE)
 if f == null:
  check(false, "fixture file opens " + path)
  return
 f.store_string(content)
 f.close()
func buttons(node: Node) -> Array:
 var found: Array = []
 if not is_instance_valid(node):
  return found
 if node is Button:
  found.append(node)
 for child in node.get_children():
  found.append_array(buttons(child))
 return found
func named_button(text: String) -> Button:
 for b in buttons(g.modal):
  if b.text == text:
   return b
 return null
func reload_and_check(b: Button, expected: int, title: bool, label: String):
 if b == null:
  check(false, label + " button exists")
  return
 var old_id = g.get_instance_id()
 check(not b.disabled and b.is_visible_in_tree() and b.pressed.get_connections().size() > 0, label + " actual button has enabled, visible signal connection")
 b.pressed.emit()
 for frame in range(30):
  await process_frame
  if is_instance_valid(current_scene) and current_scene.get_instance_id() != old_id:
   break
 g = current_scene
 if not is_instance_valid(g) or g.get_instance_id() == old_id:
  check(false, label + " reloads scene")
  return
 g.set_process(false)
 check(campaign.current == expected and g.mission.mode == campaign.MISSIONS[expected].mode, label + " loads intended mission")
 check(g.title_open == title and campaign.launch == not title and not g.ended and not is_instance_valid(g.aftermath_scene), label + " resets end state and selects intended title/gameplay state")
func finish_and_check(index: int):
 var old_ui: Array = g.root_ui.get_children()
 g.finish(true)
 check(g.ended and g.result_won and g.result_progress_error == OK, "mission %d victory records immediately" % index)
 check(is_instance_valid(g.aftermath_scene) and not g.aftermath_scene.complete and g.aftermath_scene.elapsed == 0.0, "mission %d controls exist before any aftermath time passes" % index)
 check(is_instance_valid(g.aftermath_transition) and not g.aftermath_transition.settled and g.aftermath_transition.mouse_filter == Control.MOUSE_FILTER_IGNORE and g.modal.get_child(0) == g.aftermath_transition, "mission %d fade starts behind enabled controls without capturing input" % index)
 check(g.visible and g.units[0].node.is_visible_in_tree(), "mission %d gameplay world remains visible" % index)
 var old_hidden := true
 for child in old_ui:
  if child is CanvasItem and child.visible:
   old_hidden = false
 check(old_hidden and g.modal.visible, "mission %d previous HUD hidden and completion panel visible" % index)
 for text in ["この作戦をもう一度", "作戦選択へ"]:
  var b = named_button(text)
  check(b != null and not b.disabled and b.is_visible_in_tree(), "mission %d immediate %s" % [index, text])
 var next = named_button("次の作戦へ")
 check((next != null and not next.disabled) if index < 2 else next == null, "mission %d Next availability correct" % index)
func run():
 if DirAccess.dir_exists_absolute("user://settlement_v2"):
  push_error("Fresh isolated XDG_DATA_HOME required")
  quit(2)
  return
 campaign = root.get_node("Campaign")
 campaign.current = 0
 campaign.launch = true
 campaign.muted = true
 campaign.choose_run_seed(20261005)
 g = load("res://main.tscn").instantiate()
 root.add_child(g)
 current_scene = g
 g.set_process(false)
 await process_frame
 # Isolate checkpoint cleanup: all four intended copies go, other files survive.
 check(g.save_checkpoint(false) == OK, "normal completion checkpoint fixture written")
 var checkpoint_bytes = FileAccess.get_file_as_bytes(CHECKPOINT)
 for suffix in SUFFIXES:
  var f = FileAccess.open(CHECKPOINT + suffix, FileAccess.WRITE)
  f.store_buffer(checkpoint_bytes)
  f.close()
 write_text("user://settlement_v2/unrelated.json", "leave unchanged")
 write_text("user://settlement_v2/checkpoint.json.keep", "leave unchanged too")
 finish_and_check(0)
 var removed_all := true
 for suffix in SUFFIXES:
  removed_all = removed_all and not FileAccess.file_exists(CHECKPOINT + suffix)
 check(removed_all, "normal completion clears exactly four intended checkpoint copies")
 check(FileAccess.get_file_as_string("user://settlement_v2/unrelated.json") == "leave unchanged" and FileAccess.get_file_as_string("user://settlement_v2/checkpoint.json.keep") == "leave unchanged too", "normal completion preserves unrelated files")
 var progress = Atomic.read_valid("user://settlement_v2/campaign.json", campaign.validate_progress)
 check(not progress.is_empty() and progress.best.has("0") and progress.unlocked == 2, "normal completion persists earned progress before checkpoint cleanup")
 await reload_and_check(named_button("次の作戦へ"), 1, false, "mission 0 Next")
 finish_and_check(1)
 await reload_and_check(named_button("この作戦をもう一度"), 1, false, "mission 1 Retry")
 finish_and_check(1)
 await reload_and_check(named_button("次の作戦へ"), 2, false, "mission 1 Next")
 finish_and_check(2)
 await reload_and_check(named_button("この作戦をもう一度"), 2, false, "mission 2 Retry")
 finish_and_check(2)
 await reload_and_check(named_button("作戦選択へ"), 2, true, "mission 2 Menu")
 # Launch through the actual title mission button for the save-failure branch.
 var title_button: Button = null
 for b in buttons(g.root_ui):
  if b.text.contains(campaign.MISSIONS[0].title):
   title_button = b
   break
 await reload_and_check(title_button, 0, false, "title mission 0")
 check(g.save_checkpoint(false) == OK and campaign.save_progress() == OK, "save-failure fixtures are persisted")
 var saved = FileAccess.get_file_as_bytes(CHECKPOINT)
 var saved_progress = FileAccess.get_file_as_bytes("user://settlement_v2/campaign.json")
 DirAccess.make_dir_absolute("user://settlement_v2/campaign.json.tmp")
 g.finish(true)
 check(g.result_progress_error != OK and FileAccess.get_file_as_bytes(CHECKPOINT) == saved and FileAccess.get_file_as_bytes("user://settlement_v2/campaign.json") == saved_progress, "failed completion preserves checkpoint and previous progress bytes")
 check(g.modal.save_status.visible and g.modal.save_retry.visible and not g.modal.save_retry.disabled, "failed completion exposes status and live save-retry button")
 check(not g.aftermath_scene.complete and named_button("次の作戦へ") != null and not named_button("次の作戦へ").disabled, "completion failure does not add aftermath wait to navigation")
 g.modal.save_retry.pressed.emit()
 check(g.result_progress_error != OK and FileAccess.get_file_as_bytes(CHECKPOINT) == saved, "failed real save-retry signal preserves checkpoint")
 DirAccess.remove_absolute("user://settlement_v2/campaign.json.tmp")
 g.modal.save_retry.pressed.emit()
 check(g.result_progress_error == OK and not FileAccess.file_exists(CHECKPOINT) and not FileAccess.file_exists(CHECKPOINT + ".bak"), "successful real save-retry records victory then clears checkpoint")
 check(not g.modal.save_status.visible and not g.modal.save_retry.visible, "successful save-retry clears failure controls immediately")
 await reload_and_check(named_button("この作戦をもう一度"), 0, false, "mission 0 Retry")
 # Preserve the existing loss presentation and its live navigation.
 g.finish(false)
 check(g.ended and not g.result_won and not is_instance_valid(g.aftermath_scene) and not is_instance_valid(g.aftermath_transition) and g.modal is PanelContainer, "loss keeps existing panel and does not start aftermath")
 await reload_and_check(named_button("作戦選択へ"), 0, true, "loss Menu")
 print("ENDING_CONTROLS_SUMMARY passed=%d failed=%d" % [passed, failed])
 g.queue_free()
 await process_frame
 await process_frame
 quit(1 if failed else 0)
