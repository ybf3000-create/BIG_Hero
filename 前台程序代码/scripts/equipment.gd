class_name Equipment
extends RefCounted
## ============================================================
## Equipment - 装备栏管理 v0.3
## 8 槽位：武器·防具·鞋子·戒指·项链·披风·头盔·护符
## 存储完整装备实例（非 item_id）
## ============================================================

signal equipment_changed

# 装备槽数据: key=slot_name, value=装备实例字典 (空={})
var _equipped: Dictionary = {
	"weapon":    {},
	"armor":     {},
	"shoes":     {},
	"ring":      {},
	"necklace":  {},
	"cape":      {},
	"helmet":    {},
	"charm":     {},
}

const SLOT_TYPE: Dictionary = {
	"weapon":    1,
	"armor":     2,
	"shoes":     3,
	"ring":      4,
	"necklace":  5,
	"cape":      6,
	"helmet":    7,
	"charm":     8,
}


## 穿戴装备实例
func equip_instance(slot_name: String, eqp: Dictionary) -> bool:
	if not _equipped.has(slot_name):
		return false
	if eqp.is_empty():
		return false
	_equipped[slot_name] = eqp.duplicate(true)
	equipment_changed.emit()
	return true


## 卸下装备
func unequip(slot_name: String) -> Dictionary:
	if not _equipped.has(slot_name):
		return {}
	var old: Dictionary = _equipped[slot_name].duplicate(true)
	_equipped[slot_name] = {}
	equipment_changed.emit()
	return old


## 获取槽位装备
func get_slot_item(slot_name: String) -> Dictionary:
	return _equipped.get(slot_name, {})


## 已装备实例的显示文本（用于装备面板）
func get_slot_display(slot_name: String) -> String:
	var eqp: Dictionary = _equipped.get(slot_name, {})
	if eqp.is_empty():
		return "[ 空 ]"
	var s: String = eqp.get("icon", "?") + " " + eqp.get("base_name", "???")
	if eqp.get("enhance", 0) > 0:
		s += " +" + str(eqp["enhance"])
	return s


func to_dict() -> Dictionary:
	return _equipped.duplicate(true)


func from_dict(data: Dictionary) -> void:
	for key in _equipped:
		_equipped[key] = data.get(key, {}).duplicate(true) if data.has(key) else {}
