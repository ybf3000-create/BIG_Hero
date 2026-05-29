extends Node
## ============================================================
## SaveManager - 存档管理器 (Autoload 单例)
## 负责 slot_0~2.json 的读写，角色状态的持久化
## 访问方式: get_node("/root/SaveManager")
## ============================================================

const SAVE_VERSION := 1
const MAX_SLOTS := 3
const SAVE_DIR := "user://saves/"

signal slot_changed(slot: int)


func _ready() -> void:
	# 确保存档目录存在
	DirAccess.make_dir_absolute(SAVE_DIR)


## ============ 槽位信息 ============

func get_slot_info(slot: int) -> Dictionary:
	var path := _slot_path(slot)
	if not FileAccess.file_exists(path):
		return { "empty": true, "slot": slot }

	var data := _read_json(path)
	if data.is_empty():
		return { "empty": true, "slot": slot }

	return {
		"empty": false,
		"slot": slot,
		"name": data.get("character_name", "???"),
		"level": data.get("level", 1),
		"last_saved": data.get("last_saved", 0),
		"gold": data.get("gold", 0),
	}


func get_all_slots() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for i in range(MAX_SLOTS):
		result.append(get_slot_info(i))
	return result


## ============ 创建角色 ============

func create_character(slot: int, char_name: String) -> Dictionary:
	var now := int(Time.get_unix_time_from_system())
	var data: Dictionary = {
		"version": SAVE_VERSION,
		"character_name": char_name,
		"created_at": now,
		"last_saved": now,
		"last_online": now,
		"level": 1,
		"exp": 0,
		"exp_max": 100,
		"gold": 0,
		"revive_coins": 3,
		"grid_index": 0,
		"map_total_grids": 28,
		"map_grids": _default_map_grids(),
		"dice_history": [],
		"poker_records": [],
	}
	_write_json(_slot_path(slot), data)
	slot_changed.emit(slot)
	return data


## ============ 保存/加载 ============

func save_game(slot: int, data: Dictionary) -> void:
	# 合并已有数据，保留 created_at / last_online 等仅创建时写入的字段
	var existing := _read_json(_slot_path(slot))
	if not existing.is_empty():
		for key in existing:
			if not data.has(key):
				data[key] = existing[key]
	data["last_saved"] = int(Time.get_unix_time_from_system())
	data["version"] = SAVE_VERSION
	_write_json(_slot_path(slot), data)
	slot_changed.emit(slot)


func load_game(slot: int) -> Dictionary:
	var path := _slot_path(slot)
	if not FileAccess.file_exists(path):
		return {}
	return _read_json(path)


## ============ 删除 ============

func delete_slot(slot: int) -> void:
	var path := _slot_path(slot)
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
	slot_changed.emit(slot)


## ============ 名称校验 ============

func validate_name(input_name: String) -> Dictionary:
	# 去除首尾空格
	var trimmed := input_name.strip_edges()
	if trimmed.is_empty():
		return { "valid": false, "error": "名称不能为空", "byte_count": 0 }

	# UTF-8 字节数
	var byte_count := trimmed.to_utf8_buffer().size()
	if byte_count > 14:
		return { "valid": false, "error": "名称超过14字节限制", "byte_count": byte_count }

	return { "valid": true, "error": "", "byte_count": byte_count, "trimmed": trimmed }


## ============ 内部 ============

func _slot_path(slot: int) -> String:
	return SAVE_DIR + "slot_" + str(slot) + ".json"


func _read_json(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		return {}
	var text := file.get_as_text()
	file.close()
	if text.is_empty():
		return {}
	var json := JSON.new()
	var err := json.parse(text)
	if err != OK:
		push_warning("[SaveManager] JSON 解析失败: " + path + " error=" + str(json.get_error_message()))
		return {}
	return json.get_data()


func _write_json(path: String, data: Dictionary) -> void:
	var json_text := JSON.stringify(data, "\t")
	var file := FileAccess.open(path, FileAccess.WRITE)
	if not file:
		push_error("[SaveManager] 无法写入存档: " + path)
		return
	file.store_string(json_text)
	file.close()


func _default_map_grids() -> Array:
	var grids: Array[int] = [0]  # 勇者之家
	for i in range(1, 28):
		grids.append(1 + (i % 13))
	return grids
