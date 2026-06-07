class_name SkillSystem
extends RefCounted

const SkillDataRef = preload("res://scripts/skill_data.gd")

signal skills_changed

var slots: Array = []
var cooldowns: Dictionary = {}
var max_slots: int = 2


func _init():
	slots.clear()
	for i in range(6):
		slots.append(null)


func update_max_slots(level: int) -> void:
	var new_max: int = 2
	if level >= 5:   new_max = 3
	if level >= 15:  new_max = 4
	if level >= 35:  new_max = 5
	if level >= 45:  new_max = 6
	if new_max != max_slots:
		max_slots = new_max
		skills_changed.emit()


func get_slot_count() -> int:
	return slots.size()


func get_unlocked_slots() -> int:
	return max_slots


func get_slot_skill_id(slot_idx: int):
	if slot_idx < 0 or slot_idx >= slots.size():
		return null
	var entry = slots[slot_idx]
	return entry["skill_id"] if entry else null


func get_slot_priority(slot_idx: int) -> int:
	if slot_idx < 0 or slot_idx >= slots.size():
		return 1
	var entry = slots[slot_idx]
	return entry["priority"] if entry else 1


func equip_skill(skill_id: int) -> bool:
	for i in range(max_slots):
		var entry = slots[i]
		if entry and entry["skill_id"] == skill_id:
			return false
	for i in range(max_slots):
		if slots[i] == null:
			slots[i] = { "skill_id": skill_id, "priority": 2 }
			cooldowns[skill_id] = 0.0
			skills_changed.emit()
			return true
	return false


func unequip_skill(slot_idx: int) -> bool:
	if slot_idx < 0 or slot_idx >= max_slots:
		return false
	if slots[slot_idx] == null:
		return false
	var sid: int = slots[slot_idx]["skill_id"]
	slots[slot_idx] = null
	cooldowns.erase(sid)
	skills_changed.emit()
	return true


func toggle_priority(slot_idx: int) -> void:
	if slot_idx < 0 or slot_idx >= max_slots:
		return
	var entry = slots[slot_idx]
	if entry == null:
		return
	entry["priority"] = (entry["priority"] % 3) + 1
	skills_changed.emit()


func to_dict() -> Dictionary:
	var slot_data: Array = []
	for i in range(slots.size()):
		slot_data.append(slots[i].duplicate() if slots[i] else null)
	return {
		"slots": slot_data,
		"max_slots": max_slots,
		"cooldowns": cooldowns.duplicate(),
	}


func from_dict(data: Dictionary) -> void:
	slots.clear()
	for d in data.get("slots", []):
		slots.append(d.duplicate() if d else null)
	while slots.size() < 6:
		slots.append(null)
	max_slots = data.get("max_slots", 2)
	cooldowns.clear()
	for k, v in data.get("cooldowns", {}):
		cooldowns[int(k)] = v


func select_next_skill() -> int:
	var candidates: Array = []
	for i in range(max_slots):
		var entry = slots[i]
		if entry == null:
			continue
		var sid: int = entry["skill_id"]
		if cooldowns.get(sid, 0.0) <= 0.0:
			candidates.append([entry["priority"], i, sid])
	if candidates.is_empty():
		return -1
	candidates.sort_custom(func(a, b):
		if a[0] != b[0]: return a[0] > b[0]
		return a[1] < b[1]
	)
	return candidates[0][2]
