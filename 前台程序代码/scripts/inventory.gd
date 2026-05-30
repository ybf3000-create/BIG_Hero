class_name Inventory
extends RefCounted
## ============================================================
## Inventory - 背包系统 v0.1
## 物品增删、堆叠、使用
## ============================================================

signal item_changed
signal item_used(item_id: int)

# items: Array[{ item_id: int, count: int }]
var items: Array[Dictionary] = []
var capacity: int = 30


## 添加物品（自动堆叠）
func add_item(item_id: int, count: int = 1) -> int:
	var defn: Dictionary = ItemDB.get_item(item_id)
	if defn.is_empty():
		return 0

	var stack_max: int = defn.get("stack_max", 1)
	var added: int = 0

	# 先尝试堆叠到已有槽位
	for slot in items:
		if slot["item_id"] == item_id and slot["count"] < stack_max:
			var room: int = stack_max - slot["count"]
			var take: int = mini(count, room)
			slot["count"] += take
			count -= take
			added += take
			if count <= 0:
				item_changed.emit()
				return added

	# 剩余创建新槽位
	while count > 0 and items.size() < capacity:
		var take: int = mini(count, stack_max)
		items.append({ "item_id": item_id, "count": take })
		count -= take
		added += take

	item_changed.emit()
	return added


## 移除物品
func remove_item(slot_idx: int, count: int = 1) -> bool:
	if slot_idx < 0 or slot_idx >= items.size():
		return false
	var slot: Dictionary = items[slot_idx]
	slot["count"] -= count
	if slot["count"] <= 0:
		items.remove_at(slot_idx)
	item_changed.emit()
	return true


## 获取槽位信息
func get_slot(slot_idx: int) -> Dictionary:
	if slot_idx < 0 or slot_idx >= items.size():
		return {}
	return items[slot_idx].duplicate()


func get_slot_count() -> int:
	return items.size()


## 序列化
func to_dict() -> Array:
	return items.duplicate(true)


func from_dict(data: Array) -> void:
	items.clear()
	for d in data:
		items.append(d.duplicate())
