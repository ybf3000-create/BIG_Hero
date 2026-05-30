class_name Equipment
extends RefCounted
## ============================================================
## Equipment - 装备栏管理 v0.1
## 武器/防具/饰品 三槽 + 属性加成计算
## ============================================================

const ItemDBRef = preload("res://scripts/item_db.gd")

signal equipment_changed

# 装备槽：key = slot_name, value = item_id (0 = 空)
var _slots: Dictionary = {
	"weapon":    0,
	"armor":     0,
	"accessory": 0,
}


## 穿戴装备
func equip(slot_name: String, item_id: int) -> bool:
	if not _slots.has(slot_name):
		return false
	var defn: Dictionary = ItemDBRef.get_item(item_id)
	if defn.is_empty():
		return false
	var expected_type: int = -1
	match slot_name:
		"weapon":    expected_type = 1
		"armor":     expected_type = 2
		"accessory": expected_type = 3
	if defn["type"] != expected_type:
		return false
	_slots[slot_name] = item_id
	equipment_changed.emit()
	return true


## 卸下装备
func unequip(slot_name: String) -> int:
	if not _slots.has(slot_name):
		return 0
	var old_id: int = _slots[slot_name]
	_slots[slot_name] = 0
	equipment_changed.emit()
	return old_id


## 获取槽位物品ID
func get_slot_item(slot_name: String) -> int:
	return _slots.get(slot_name, 0)


## 计算总属性加成
func get_stat_bonuses() -> Dictionary:
	var bonuses: Dictionary = {}
	for slot_name in _slots:
		var item_id: int = _slots[slot_name]
		if item_id <= 0:
			continue
		var defn: Dictionary = ItemDBRef.get_item(item_id)
		var stats: Dictionary = defn.get("stats", {})
		for key in stats:
			bonuses[key] = bonuses.get(key, 0) + stats[key]
	return bonuses


## 序列化
func to_dict() -> Dictionary:
	return _slots.duplicate()


func from_dict(data: Dictionary) -> void:
	for key in _slots:
		_slots[key] = data.get(key, 0)
