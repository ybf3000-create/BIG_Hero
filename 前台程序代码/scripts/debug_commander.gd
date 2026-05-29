extends Node
## ============================================================
## DebugCommander - 调试命令接收器 (Autoload)
## 读取 user://debug_cmd.txt → 解析 JSON → 执行 UI 操作
## ============================================================

var _timer: Timer
var _last_size: int = 0


func _ready() -> void:
	_timer = Timer.new()
	_timer.wait_time = 0.3
	_timer.autostart = true
	_timer.timeout.connect(_check_command)
	add_child(_timer)
	_clear_cmd_file()


func _check_command() -> void:
	var path := "user://debug_cmd.txt"
	if not FileAccess.file_exists(path):
		return
	var f := FileAccess.open(path, FileAccess.READ)
	if not f:
		return
	var txt := f.get_as_text()
	f.close()
	if txt.is_empty() or txt.length() == _last_size:
		return
	_last_size = txt.length()

	var json := JSON.new()
	var err := json.parse(txt)
	if err != OK:
		push_warning("[DebugCmd] JSON parse error: ", txt)
		return
	var cmd: Dictionary = json.get_data()
	if cmd.is_empty():
		return

	var action: String = cmd.get("action", "")
	print("[DebugCmd] Executing: ", action)

	match action:
		"click_slot":
			_exec_on("select_slot", "_on_slot_clicked", [cmd.get("slot", 0)])
		"create_char":
			_exec_on("select_slot", "_show_create_dialog", [cmd.get("slot", 0)])
		"input_name":
			_set_line_edit("CreateDialog/NameInput", cmd.get("text", ""))
		"confirm_create":
			_press_button("CreateDialog/CreateBtn")
		"cancel_create":
			_press_button("CreateDialog/CreateBtn")  # actually cancel
			_close_window("CreateDialog")
		"close_create":
			_close_window("CreateDialog")
		"click_delete":
			_exec_on("select_slot", "_show_delete_dialog", [cmd.get("slot", 0), {}])
		"hold_confirm":
			_simulate_hold("DeletePanel/ConfirmBtn", cmd.get("seconds", 3.0))
		"click_cancel":
			_press_button_by_text("DeletePanel", "取 消")
		"click_overlay":
			_exec_on_node("DeleteOverlay", "queue_free", [])
		"click_dice":
			_press_button_by_path("MainGame/BottomBar/DiceRollBtn")
		"click_bag":
			_press_button_by_path("MainGame/BottomBar/BagBtn")
		"click_skill":
			_press_button_by_path("MainGame/BottomBar/SkillBtn")
		"click_log":
			_press_button_by_path("MainGame/BottomBar/LogBtn")
		"click_home":
			_press_button_by_path("MainGame/BottomBar/SettingsBtn")
		"toggle_auto":
			_toggle_checkbox("MainGame/MapArea/AutoPlayCheck")
		_:
			push_warning("[DebugCmd] Unknown action: ", action)
	
	_clear_cmd_file()


func _clear_cmd_file() -> void:
	var f := FileAccess.open("user://debug_cmd.txt", FileAccess.WRITE)
	if f:
		f.store_string("")
		f.close()


## ============ Helpers ============

func _get_root_control() -> Control:
	for child in get_tree().root.get_children():
		if child is Control:
			return child
	return null


func _exec_on(scene_name: String, method: String, args: Array) -> void:
	var ctrl := _get_root_control()
	if ctrl and ctrl.name.to_lower().begins_with(scene_name):
		ctrl.callv(method, args)


func _find_node_by_path(root: Node, path: String) -> Node:
	var parts := path.split("/")
	var current := root
	for p in parts:
		current = current.get_node_or_null(p)
		if not current:
			break
	return current


func _press_button_by_path(path: String) -> void:
	var root := get_tree().root
	var btn := _find_node_by_path(root, path)
	if btn is Button:
		_press(btn)


func _press_button(parent_name: String, btn_name: String) -> void:
	var ctrl := _get_root_control()
	if not ctrl:
		return
	var parent := ctrl.get_node_or_null(parent_name)
	if not parent:
		parent = ctrl.get_node_or_null(btn_name)  # try direct
	if parent is Button:
		_press(parent)


func _press_button_by_text(parent_name: String, text: String) -> void:
	var ctrl := _get_root_control()
	if not ctrl:
		return
	var parent := ctrl.get_node_or_null(parent_name)
	if not parent:
		return
	for child in parent.get_children():
		if child is Button and child.text == text:
			_press(child)
			return


func _set_line_edit(rel_path: String, text: String) -> void:
	var ctrl := _get_root_control()
	if not ctrl:
		return
	var le := ctrl.get_node_or_null(rel_path)
	if le is LineEdit:
		le.text = text
		if le.has_signal("text_changed"):
			le.text_changed.emit(text)


func _close_window(name: String) -> void:
	var ctrl := _get_root_control()
	if not ctrl:
		return
	var w := ctrl.get_node_or_null(name)
	if w:
		w.queue_free()


func _toggle_checkbox(path: String) -> void:
	var root := get_tree().root
	var cb := _find_node_by_path(root, path)
	if cb is CheckBox:
		cb.button_pressed = not cb.button_pressed


func _exec_on_node(node_name: String, method: String, args: Array) -> void:
	var ctrl := _get_root_control()
	if not ctrl:
		return
	var node := ctrl.get_node_or_null(node_name)
	if node:
		node.callv(method, args)


func _press(btn: Button) -> void:
	btn.emit_signal("pressed")


func _simulate_hold(btn_path: String, seconds: float) -> void:
	var ctrl := _get_root_control()
	if not ctrl:
		return
	var btn := _find_node_by_path(ctrl, btn_path)
	if not (btn is Button):
		return
	btn.emit_signal("button_down")
	var t := Timer.new()
	t.one_shot = true
	t.wait_time = seconds
	t.timeout.connect(func():
		btn.emit_signal("button_up")
		t.queue_free()
	)
	add_child(t)
	t.start()
