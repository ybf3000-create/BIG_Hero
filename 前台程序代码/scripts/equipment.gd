class_name Equipment
extends RefCounted
## ============================================================
## Equipment - 装备栏管理 v0.2
## 8 槽位：武器·防具·鞋子·戒指·项链·披风·头盔·护符
## ============================================================

const ItemDBRef = preload("res://scripts/item_db.gd")

signal equipment_changed

# 装备槽 key → type_id（与 ItemDB enum 对齐）
var _slots: Dictionary = {
	"weapon":    0,  # type=1
	"armor":     0,  # type=2
	"shoes":     0,  # type=3
	"ring":      0,  # type=4
	"necklace":  0,  # type=5
	"cape":      0,  # type=6
	"helmet":    0,  # type=7
	"charm":     0,  # type=8
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


func equip(slot_name: String, item_id: int) -> bool:
	if not _slots.has(slot_name):
		return false
	var defn: Dictionary = ItemDBRef.get_item(item_id)
	if defn.is_empty():
		return false
	if defn["type"] != SLOT_TYPE.get(slot_name, -1):
		return false
	_slots[slot_name] = item_id
	equipment_changed.emit()
	return true


func unequip(slot_name: String) -> int:
	if not _slots.has(slot_name):
		return 0
	var old_id: int = _slots[slot_name]
	_slots[slot_name] = 0
	equipment_changed.emit()
	return old_id


func get_slot_item(slot_name: String) -> int:
	return _slots.get(slot_name, 0)


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


func to_dict() -> Dictionary:
	return _slots.duplicate()


func from_dict(data: Dictionary) -> void:
	for key in _slots:
		_slots[key] = data.get(key, 0)
