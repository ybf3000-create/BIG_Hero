class_name EquipIcons
extends RefCounted
## ============================================================
## EquipIcons — 装备图标配置 v1.0
## 每个部位多张候选图，生成时随机选1张
## 路径格式: res://assets/equip/{slot}/{filename}
## 注：当前用 emoji 占位，后续替换为实际美术资源
## ============================================================

# 每个部位 3 个图标候选项 { name, icon }
static var ICONS: Dictionary = {
	"weapon": [
		{ "name": "铁剑",      "icon": "🗡️" },
		{ "name": "长剑",      "icon": "⚔️" },
		{ "name": "战斧",      "icon": "🪓" },
	],
	"armor": [
		{ "name": "皮甲",      "icon": "👘" },
		{ "name": "锁子甲",    "icon": "🛡️" },
		{ "name": "板甲",      "icon": "🦺" },
	],
	"shoes": [
		{ "name": "布鞋",      "icon": "👟" },
		{ "name": "皮靴",      "icon": "👢" },
		{ "name": "铁靴",      "icon": "🥾" },
	],
	"ring": [
		{ "name": "铜戒",      "icon": "💍" },
		{ "name": "银戒",      "icon": "💎" },
		{ "name": "金戒",      "icon": "👑" },
	],
	"necklace": [
		{ "name": "石坠",      "icon": "📿" },
		{ "name": "银链",      "icon": "🔮" },
		{ "name": "宝珠",      "icon": "💠" },
	],
	"cape": [
		{ "name": "麻布披风",  "icon": "🧣" },
		{ "name": "丝质披风",  "icon": "🦸" },
		{ "name": "暗影斗篷",  "icon": "🦇" },
	],
	"helmet": [
		{ "name": "皮帽",      "icon": "🎩" },
		{ "name": "铁盔",      "icon": "⛑️" },
		{ "name": "王冠",      "icon": "🤴" },
	],
	"charm": [
		{ "name": "木符",      "icon": "🪬" },
		{ "name": "玉符",      "icon": "🌿" },
		{ "name": "圣符",      "icon": "✨" },
	],
}


## 从部位随机选1个图标
static func random_icon(slot_name: String) -> Dictionary:
	var pool: Array = ICONS.get(slot_name, [])
	if pool.is_empty():
		return { "name": "???", "icon": "❓" }
	return pool[randi() % pool.size()]
