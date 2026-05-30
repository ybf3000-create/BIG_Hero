class_name ItemDB
extends RefCounted
## ============================================================
## ItemDB - 物品数据库 v0.1
## 所有物品的模板定义（消耗品/装备/材料）
## ============================================================

enum ItemType {
	CONSUMABLE = 0,  # 消耗品
	WEAPON     = 1,  # 武器
	ARMOR      = 2,  # 防具
	ACCESSORY  = 3,  # 饰品
	MATERIAL   = 4,  # 材料
}

# 物品模板结构：{ id, name, type, icon, desc, price, stack_max, stats }
# stats: { atk, def, hp, spd, luk, heal, exp_bonus, gold_bonus }
static var ITEMS: Dictionary = {}

static func _init_all() -> void:
	if not ITEMS.is_empty():
		return
	ITEMS = {
		# ======== 消耗品 ========
		1: { "id": 1, "name": "回复药水", "type": 0, "icon": "🧪", "desc": "恢复 50 HP", "price": 30, "stack_max": 99, "stats": { "heal": 50 } },
		2: { "id": 2, "name": "大回复药", "type": 0, "icon": "🧴", "desc": "恢复 200 HP", "price": 100, "stack_max": 50, "stats": { "heal": 200 } },
		3: { "id": 3, "name": "经验卷轴", "type": 0, "icon": "📜", "desc": "获得 100 经验", "price": 80, "stack_max": 20, "stats": { "exp_bonus": 100 } },
		4: { "id": 4, "name": "金币袋",   "type": 0, "icon": "💰", "desc": "获得 200 金币", "price": 0, "stack_max": 30, "stats": { "gold_bonus": 200 } },

		# ======== 武器 ========
		10: { "id": 10, "name": "铁剑",   "type": 1, "icon": "🗡️", "desc": "基础武器",     "price": 100, "stack_max": 1, "stats": { "atk": 8 } },
		11: { "id": 11, "name": "钢剑",   "type": 1, "icon": "⚔️", "desc": "精良武器",     "price": 300, "stack_max": 1, "stats": { "atk": 18 } },
		12: { "id": 12, "name": "火焰剑", "type": 1, "icon": "🔥", "desc": "附带火焰伤害", "price": 600, "stack_max": 1, "stats": { "atk": 28, "luk": 5 } },

		# ======== 防具 ========
		20: { "id": 20, "name": "布甲",   "type": 2, "icon": "👘", "desc": "基础防具",   "price": 80,  "stack_max": 1, "stats": { "def": 5 } },
		21: { "id": 21, "name": "锁子甲", "type": 2, "icon": "🛡️", "desc": "精良防具",   "price": 250, "stack_max": 1, "stats": { "def": 12 } },
		22: { "id": 22, "name": "龙鳞甲", "type": 2, "icon": "🐉", "desc": "龙鳞打造",   "price": 500, "stack_max": 1, "stats": { "def": 22, "hp": 30 } },

		# ======== 饰品 ========
		30: { "id": 30, "name": "速度戒指", "type": 3, "icon": "💍", "desc": "速度+8",  "price": 200, "stack_max": 1, "stats": { "spd": 8 } },
		31: { "id": 31, "name": "幸运护符", "type": 3, "icon": "🍀", "desc": "幸运+12", "price": 300, "stack_max": 1, "stats": { "luk": 12 } },

		# ======== 材料 ========
		50: { "id": 50, "name": "铁矿石", "type": 4, "icon": "⛰", "desc": "锻造材料", "price": 15, "stack_max": 99, "stats": {} },
		51: { "id": 51, "name": "龙鳞片", "type": 4, "icon": "🪶", "desc": "稀有材料", "price": 50, "stack_max": 50, "stats": {} },
	}


static func get_item(id: int) -> Dictionary:
	_init_all()
	return ITEMS.get(id, {})


static func get_name(id: int) -> String:
	return get_item(id).get("name", "???")


static func get_icon(id: int) -> String:
	return get_item(id).get("icon", "❓")
