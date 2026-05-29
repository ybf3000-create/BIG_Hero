class_name GridExecutor
extends RefCounted
## ============================================================
## GridExecutor - 格子触发执行器 v0.1
## 根据格子类型分发到对应执行逻辑
## 14 种格子类型（拍卖行改为空地2）
## ============================================================

## 格子类型常量
enum GridType {
	START    = 0,   # 起点（经过发放奖励）
	NORMAL   = 1,   # 战斗格
	REST     = 2,   # 休息格（回血）
	TREASURE = 3,   # 宝箱格
	SHOP     = 4,   # 商店格
	CHANCE   = 5,   # 随机事件格
	BOSS_1   = 6,   # Boss 格 Lv.1
	HOLIDAY  = 7,   # 度假格（跳过下回合）
	LOTTERY  = 8,   # 彩票格
	STORM    = 9,   # 风暴格（掉血）
	REVIVE   = 10,  # 复活格（获得复活币）
	EMPTY_1  = 11,  # 空地1
	EMPTY_2  = 12,  # 空地2（原拍卖行，额外金币）
	BOSS_2   = 13,  # Boss 格 Lv.2
}

## 格子类型名称表
static var TYPE_NAME: Dictionary = {
	GridType.START:    "起点",
	GridType.NORMAL:   "战斗",
	GridType.REST:     "休息",
	GridType.TREASURE: "宝箱",
	GridType.SHOP:     "商店",
	GridType.CHANCE:   "随机事件",
	GridType.BOSS_1:   "Boss",
	GridType.HOLIDAY:  "度假",
	GridType.LOTTERY:  "彩票",
	GridType.STORM:    "风暴",
	GridType.REVIVE:   "复活",
	GridType.EMPTY_1:  "空地",
	GridType.EMPTY_2:  "空地",
	GridType.BOSS_2:   "Boss",
}

## 格子类型图标
static var TYPE_ICON: Dictionary = {
	GridType.START:    "★",
	GridType.NORMAL:   "⚔",
	GridType.REST:     "♡",
	GridType.TREASURE: "🎁",
	GridType.SHOP:     "🛒",
	GridType.CHANCE:   "?",
	GridType.BOSS_1:   "☠",
	GridType.HOLIDAY:  "☀",
	GridType.LOTTERY:  "🎰",
	GridType.STORM:    "⛈",
	GridType.REVIVE:   "♻",
	GridType.EMPTY_1:  "·",
	GridType.EMPTY_2:  "·",
	GridType.BOSS_2:   "☠",
}

## 格子类型颜色
static var TYPE_COLOR: Dictionary = {
	GridType.START:    Color(0.2, 0.6, 1.0),
	GridType.NORMAL:   Color(0.9, 0.3, 0.3),
	GridType.REST:     Color(0.3, 0.8, 0.3),
	GridType.TREASURE: Color(1.0, 0.8, 0.2),
	GridType.SHOP:     Color(0.8, 0.5, 1.0),
	GridType.CHANCE:   Color(1.0, 0.7, 0.3),
	GridType.BOSS_1:   Color(0.6, 0.0, 0.1),
	GridType.HOLIDAY:  Color(0.2, 0.9, 0.9),
	GridType.LOTTERY:  Color(1.0, 0.4, 0.6),
	GridType.STORM:    Color(0.3, 0.3, 0.5),
	GridType.REVIVE:   Color(0.5, 0.9, 0.5),
	GridType.EMPTY_1:  Color(0.4, 0.4, 0.5),
	GridType.EMPTY_2:  Color(0.4, 0.4, 0.5),
	GridType.BOSS_2:   Color(0.6, 0.0, 0.1),
}


## 执行格子效果
## 返回 Dictionary: { event: String, data: Dictionary }
func execute(grid_type: int, context: Dictionary) -> Dictionary:
	match grid_type:
		GridType.START:    return _exec_start(context)
		GridType.NORMAL:   return _exec_battle(context)
		GridType.REST:     return _exec_rest(context)
		GridType.TREASURE: return _exec_treasure(context)
		GridType.SHOP:     return _exec_shop(context)
		GridType.CHANCE:   return _exec_chance(context)
		GridType.BOSS_1:   return _exec_boss(context, 1)
		GridType.HOLIDAY:  return _exec_holiday(context)
		GridType.LOTTERY:  return _exec_lottery(context)
		GridType.STORM:    return _exec_storm(context)
		GridType.REVIVE:   return _exec_revive(context)
		GridType.EMPTY_1:  return _exec_empty(context)
		GridType.EMPTY_2:  return _exec_empty_2(context)
		GridType.BOSS_2:   return _exec_boss(context, 2)
		_: return { "event": "unknown", "data": {} }


## ============ 各类型执行逻辑 ============

func _exec_start(_ctx: Dictionary) -> Dictionary:
	return { "event": "start_pass", "data": { "message": "经过起点！获得奖励！" } }


func _exec_battle(_ctx: Dictionary) -> Dictionary:
	return { "event": "battle", "data": { "message": "遭遇敌人！","level": ctx.get("player_level", 1) } }


func _exec_rest(_ctx: Dictionary) -> Dictionary:
	return { "event": "rest", "data": { "message": "休息一下，恢复生命值","heal_percent": 0.2 } }


func _exec_treasure(_ctx: Dictionary) -> Dictionary:
	return { "event": "treasure", "data": { "message": "发现宝箱！" } }


func _exec_shop(_ctx: Dictionary) -> Dictionary:
	return { "event": "shop", "data": { "message": "遇到商店！" } }


func _exec_chance(_ctx: Dictionary) -> Dictionary:
	var outcomes: Array[String] = ["获得金币", "获得经验", "触发战斗", "获得装备"]
	var pick: String = outcomes[randi() % outcomes.size()]
	return { "event": "chance", "data": { "message": "随机事件：" + pick } }


func _exec_boss(ctx: Dictionary, level: int) -> Dictionary:
	return { "event": "boss", "data": { "message": "Boss Lv.%d 出现！" % level, "boss_level": level } }


func _exec_holiday(_ctx: Dictionary) -> Dictionary:
	return { "event": "holiday", "data": { "message": "度假中，跳过下一回合" } }


func _exec_lottery(_ctx: Dictionary) -> Dictionary:
	return { "event": "lottery", "data": { "message": "进入彩票抽取！" } }


func _exec_storm(_ctx: Dictionary) -> Dictionary:
	return { "event": "storm", "data": { "message": "遭遇风暴！失去生命值" } }


func _exec_revive(_ctx: Dictionary) -> Dictionary:
	return { "event": "revive", "data": { "message": "获得一枚复活币" } }


func _exec_empty(_ctx: Dictionary) -> Dictionary:
	return { "event": "empty", "data": { "message": "准备集合" } }


func _exec_empty_2(_ctx: Dictionary) -> Dictionary:
	return { "event": "empty_2", "data": { "message": "获得额外金币！", "bonus_gold": 50 } }
