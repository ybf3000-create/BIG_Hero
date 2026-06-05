class_name GridExecutor
extends RefCounted
## ============================================================
## GridExecutor v0.4 — 所有地块效果按策划案实现
## 基于数值总表 v3.2 — 金币公式: min(Lv,100) × K_gr
## ============================================================

const EquipGenCls = preload("res://scripts/equip_gen.gd")
const GameConfigCls = preload("res://scripts/game_config.gd")

# 格子类型枚举 — 与 main_game.gd GRID_TYPES 索引对齐
# 扩展为15种地块类型，匹配地块收益总表
enum GridType {
	HOME      = 0,   # 勇者之家（村庄）
	GRASS     = 1,   # 草地 — 基础战斗，金币×1.0
	FOREST    = 2,   # 森林 — 金币×1.2，EXP×1.1
	MOUNTAIN  = 3,   # 山地 — 金币×1.0，EXP×1.3
	DESERT    = 4,   # 沙漠 — 金币×1.5，HP耗损+10%
	SNOW      = 5,   # 雪地 — 金币×0.8，速度-20%
	SWAMP     = 6,   # 沼泽 — 中毒地形，受伤+15%
	VOLCANO   = 7,   # 火山 — 金币×2.0，HP自损/秒
	BEACH     = 8,   # 海滩 — 宝石掉率×1.5
	VILLAGE   = 9,   # 村庄 — 免费回血一次/访问
	TEMPLE    = 10,  # 神殿 — 稀有掉落×2.0
	MINE      = 11,  # 矿山 — 铁矿资源掉落
	DEEPFRST  = 12,  # 深林 — 精英怪概率+30%
	RUINS     = 13,  # 废墟 — Boss前置地块
	GLACIER   = 14,  # 冰川 — 冻结负面状态概率
	LAVA      = 15,  # 熔岩 — 持续灼伤+高金币奖励
	# 兼容旧格类型（功能性子格）
	REST      = 16,  # 休息格
	TREASURE  = 17,  # 宝箱格
	FORGE     = 18,  # 锻造格
	FATE      = 19,  # 命运格
	GOD       = 20,  # 神祇格
	SYNTH     = 21,  # 合成格
	LIGHT     = 22,  # 闪电格
	BOSS      = 23,  # Boss格
	ELITE     = 24,  # 精英战斗
	CHALLENG  = 25,  # 挑战格
}


## 执行格子效果
## context 需包含: player_gold, player_level, player_revive(复活币), equip_instances(装备列表), equipment(装备栏对象)
static func execute(grid_type: int, ctx: Dictionary) -> Dictionary:
	match grid_type:
		GridType.HOME:     return _exec_home(ctx)
		GridType.GRASS:    return _exec_grass(ctx)
		GridType.FOREST:   return _exec_forest(ctx)
		GridType.MOUNTAIN: return _exec_mountain(ctx)
		GridType.DESERT:   return _exec_desert(ctx)
		GridType.SNOW:     return _exec_snow(ctx)
		GridType.SWAMP:    return _exec_swamp(ctx)
		GridType.VOLCANO:  return _exec_volcano(ctx)
		GridType.BEACH:    return _exec_beach(ctx)
		GridType.VILLAGE:  return _exec_village(ctx)
		GridType.TEMPLE:   return _exec_temple(ctx)
		GridType.MINE:     return _exec_mine(ctx)
		GridType.DEEPFRST: return _exec_deep_forest(ctx)
		GridType.RUINS:    return _exec_ruins(ctx)
		GridType.GLACIER:  return _exec_glacier(ctx)
		GridType.LAVA:     return _exec_lava(ctx)
		GridType.REST:     return _exec_rest(ctx)
		GridType.TREASURE: return _exec_treasure(ctx)
		GridType.FORGE:    return _exec_forge(ctx)
		GridType.FATE:     return _exec_fate(ctx)
		GridType.GOD:      return _exec_god(ctx)
		GridType.SYNTH:    return _exec_synthesize(ctx)
		GridType.LIGHT:    return _exec_lightning(ctx)
		GridType.BOSS:     return _exec_boss(ctx)
		GridType.ELITE:    return _exec_elite(ctx)
		GridType.CHALLENG: return _exec_challenge(ctx)
	return { "event": "unknown", "data": {} }


## ============ 通用金币计算 ============
## 金币 = min(Lv, 100) × K_gr × 倍率系数
static func _battle_gold(lv: int, multiplier: float = 1.0) -> int:
	return GameConfigCls.calc_battle_gold(lv, multiplier)

static func _add_gold(ctx: Dictionary, amount: int) -> void:
	ctx["player_gold"] = ctx.get("player_gold", 0) + amount


## ============ 勇者之家 ============
static func _exec_home(ctx: Dictionary) -> Dictionary:
	return { "event": "home", "data": { "message": "回到勇者之家" } }


## ============ 15种地块类型 — 基于地块收益总表 ============

## 草地 — 基础战斗，金币×1.0
static func _exec_grass(ctx: Dictionary) -> Dictionary:
	var lv: int = ctx.get("player_level", 1)
	var gold: int = _battle_gold(lv, 1.0)
	_add_gold(ctx, gold)
	return { "event": "battle", "data": { "type": "grass", "message": "草地战斗", "gold": gold } }

## 森林 — 金币×1.2，EXP×1.1
static func _exec_forest(ctx: Dictionary) -> Dictionary:
	var lv: int = ctx.get("player_level", 1)
	var gold: int = _battle_gold(lv, 1.2)
	_add_gold(ctx, gold)
	return { "event": "battle", "data": { "type": "forest", "message": "森林战斗", "gold": gold, "exp_mult": 1.1 } }

## 山地 — 金币×1.0，EXP×1.3
static func _exec_mountain(ctx: Dictionary) -> Dictionary:
	var lv: int = ctx.get("player_level", 1)
	var gold: int = _battle_gold(lv, 1.0)
	_add_gold(ctx, gold)
	return { "event": "battle", "data": { "type": "mountain", "message": "山地战斗", "gold": gold, "exp_mult": 1.3 } }

## 沙漠 — 金币×1.5，HP耗损+10%
static func _exec_desert(ctx: Dictionary) -> Dictionary:
	var lv: int = ctx.get("player_level", 1)
	var gold: int = _battle_gold(lv, 1.5)
	_add_gold(ctx, gold)
	return { "event": "battle", "data": { "type": "desert", "message": "沙漠战斗（HP耗损+10%）", "gold": gold } }

## 雪地 — 金币×0.8，速度-20%
static func _exec_snow(ctx: Dictionary) -> Dictionary:
	var lv: int = ctx.get("player_level", 1)
	var gold: int = _battle_gold(lv, 0.8)
	_add_gold(ctx, gold)
	return { "event": "battle", "data": { "type": "snow", "message": "雪地战斗（速度-20%）", "gold": gold } }

## 沼泽 — 中毒地形，受伤+15%
static func _exec_swamp(ctx: Dictionary) -> Dictionary:
	var lv: int = ctx.get("player_level", 1)
	var gold: int = _battle_gold(lv, 1.0)
	_add_gold(ctx, gold)
	return { "event": "battle", "data": { "type": "swamp", "message": "沼泽中毒！（受伤+15%）", "gold": gold } }

## 火山 — 金币×2.0，HP自损/秒
static func _exec_volcano(ctx: Dictionary) -> Dictionary:
	var lv: int = ctx.get("player_level", 1)
	var gold: int = _battle_gold(lv, 2.0)
	_add_gold(ctx, gold)
	return { "event": "battle", "data": { "type": "volcano", "message": "火山战斗（HP持续自损）", "gold": gold } }

## 海滩 — 宝石掉率×1.5
static func _exec_beach(ctx: Dictionary) -> Dictionary:
	var lv: int = ctx.get("player_level", 1)
	var gold: int = _battle_gold(lv, 1.0)
	_add_gold(ctx, gold)
	return { "event": "battle", "data": { "type": "beach", "message": "海滩战斗（宝石掉率×1.5）", "gold": gold } }

## 村庄 — 免费回血一次/访问
static func _exec_village(ctx: Dictionary) -> Dictionary:
	return { "event": "village", "data": { "type": "heal", "message": "村庄休憩，免费回血！" } }

## 神殿 — 稀有掉落×2.0
static func _exec_temple(ctx: Dictionary) -> Dictionary:
	var lv: int = ctx.get("player_level", 1)
	var gold: int = _battle_gold(lv, 1.0)
	_add_gold(ctx, gold)
	return { "event": "battle", "data": { "type": "temple", "message": "神殿战斗（稀有掉落×2.0）", "gold": gold } }

## 矿山 — 铁矿资源掉落
static func _exec_mine(ctx: Dictionary) -> Dictionary:
	var lv: int = ctx.get("player_level", 1)
	var gold: int = _battle_gold(lv, 1.0)
	_add_gold(ctx, gold)
	return { "event": "battle", "data": { "type": "mine", "message": "矿山开采，获得铁矿！", "gold": gold } }

## 深林 — 精英怪概率+30%
static func _exec_deep_forest(ctx: Dictionary) -> Dictionary:
	var lv: int = ctx.get("player_level", 1)
	var gold: int = _battle_gold(lv, 1.2)
	_add_gold(ctx, gold)
	return { "event": "battle", "data": { "type": "deep_forest", "message": "深林战斗（精英概率+30%）", "gold": gold, "exp_mult": 1.1 } }

## 废墟 — Boss前置地块
static func _exec_ruins(ctx: Dictionary) -> Dictionary:
	var lv: int = ctx.get("player_level", 1)
	var gold: int = _battle_gold(lv, 1.0)
	_add_gold(ctx, gold)
	return { "event": "battle", "data": { "type": "ruins", "message": "废墟深处…前方Boss！", "gold": gold } }

## 冰川 — 冻结负面状态概率
static func _exec_glacier(ctx: Dictionary) -> Dictionary:
	var lv: int = ctx.get("player_level", 1)
	var gold: int = _battle_gold(lv, 0.9)
	_add_gold(ctx, gold)
	return { "event": "battle", "data": { "type": "glacier", "message": "冰川战斗（概率冻结）", "gold": gold } }

## 熔岩 — 持续灼伤+高金币奖励
static func _exec_lava(ctx: Dictionary) -> Dictionary:
	var lv: int = ctx.get("player_level", 1)
	var gold: int = _battle_gold(lv, 1.8)
	_add_gold(ctx, gold)
	return { "event": "battle", "data": { "type": "lava", "message": "熔岩地狱！（持续灼伤+高金币）", "gold": gold } }


## ============ 旧战斗格 (兼容) ============
static func _exec_battle(ctx: Dictionary) -> Dictionary:
	return _exec_grass(ctx)

static func _exec_elite(ctx: Dictionary) -> Dictionary:
	return { "event": "elite_battle", "data": { "message": "精英战斗！" } }

static func _exec_boss(ctx: Dictionary) -> Dictionary:
	return { "event": "boss", "data": { "message": "Boss 挑战！" } }

static func _exec_challenge(ctx: Dictionary) -> Dictionary:
	return { "event": "challenge", "data": { "message": "挑战格" } }


## ============ 休息格 ============
static func _exec_rest(ctx: Dictionary) -> Dictionary:
	var rev: int = ctx.get("player_revive", 3)
	if rev < 3:
		ctx["player_revive"] = rev + 1
		return { "event": "rest", "data": { "type": "revive", "message": "+1 复活币", "revive": rev + 1 } }
	else:
		var lv: int = ctx.get("player_level", 1)
		var gold: int = _battle_gold(lv, 0.5)  # 复活币满时给一半战斗金币
		_add_gold(ctx, gold)
		return { "event": "rest", "data": { "type": "gold", "message": "+" + str(gold) + " 金币（复活币已满）", "gold": gold } }


## ============ 宝箱格 ============
static func _exec_treasure(ctx: Dictionary) -> Dictionary:
	var roll: float = randf()
	var lv: int = ctx.get("player_level", 1)

	if roll < 0.55:
		return _treasure_gold(ctx)
	elif roll < 0.80:
		return _treasure_equip(ctx)
	elif roll < 0.92:
		return _treasure_card(ctx)
	else:
		return _treasure_gem(ctx)


static func _treasure_gold(ctx: Dictionary) -> Dictionary:
	var lv: int = ctx.get("player_level", 1)
	var gold: int = _battle_gold(lv, randi_range(3, 7))  # 宝箱3~7倍战斗金币
	_add_gold(ctx, gold)
	return { "event": "treasure", "data": { "type": "gold", "amount": gold, "message": "宝箱开出 +" + str(gold) + " 金币" } }


static func _treasure_equip(ctx: Dictionary) -> Dictionary:
	var eqp: Dictionary = EquipGenCls.generate(_random_slot(), ctx.get("player_level", 1))
	if ctx.has("equip_instances"):
		ctx["equip_instances"].append(eqp)
	return { "event": "treasure", "data": { "type": "equip", "equip": eqp, "message": "宝箱获得: " + EquipGenCls.full_name(eqp) } }


static func _treasure_card(ctx: Dictionary) -> Dictionary:
	return { "event": "treasure", "data": { "type": "card", "message": "宝箱开出命运卡" } }


static func _treasure_gem(ctx: Dictionary) -> Dictionary:
	var gid: int = randi_range(1, 7)
	var lv: int = 1
	var lv_roll: float = randf()
	if lv_roll < 0.60:     lv = 1
	elif lv_roll < 0.85:   lv = 2
	elif lv_roll < 0.97:   lv = 3
	else:                  lv = 4
	var gdef: Dictionary = EquipGenCls.EquipDataCls.GEM_DEFS.get(gid, {})
	return { "event": "treasure", "data": { "type": "gem", "gem_id": gid, "level": lv, "message": "宝箱开出" + gdef.get("icon","?") + " Lv." + str(lv) } }


## ============ 锻造格 ============
static func _exec_forge(ctx: Dictionary) -> Dictionary:
	var eqp_list: Array = ctx.get("equip_instances", [])
	var equipped_slots: Array[String] = []
	for ep in eqp_list:
		if ep.get("equipped", false):
			var sn: String = ep.get("slot", "")
			if not equipped_slots.has(sn):
				equipped_slots.append(sn)
	if equipped_slots.is_empty():
		return { "event": "forge", "data": { "type": "fail", "message": "装备架空空如也" } }

	# 随机选一个已装备槽位强化
	var slot: String = equipped_slots[randi() % equipped_slots.size()]
	var target: Dictionary = {}
	for ep in eqp_list:
		if ep.get("equipped", false) and ep.get("slot", "") == slot:
			target = ep
			break

	var enhance: int = target.get("enhance", 0)
	if enhance >= 200:
		return { "event": "forge", "data": { "type": "cap", "message": slot + " 强化已达上限 +200" } }

	var cost: int = enhance * 500
	var gold: int = ctx.get("player_gold", 0)
	if gold < cost:
		return { "event": "forge", "data": { "type": "nofund", "message": "金币不足（需要 " + str(cost) + "）" } }

	ctx["player_gold"] = gold - cost
	target["enhance"] = enhance + 1
	return { "event": "forge", "data": { "type": "success", "slot": slot, "enhance": enhance + 1, "cost": cost, "message": slot + " +" + str(enhance) + " → +" + str(enhance + 1) + "  (-" + str(cost) + "金)" } }


## ============ 命运格 ============
static var FATE_EVENTS: Array[Dictionary] = [
	{ "name": "股市大涨", "type": "reward",    "weight": 6 },
	{ "name": "宝石行情好","type": "reward",    "weight": 6 },
	{ "name": "技能大赛",  "type": "reward",    "weight": 7 },
	{ "name": "天命降临",  "type": "reward",    "weight": 6 },
	{ "name": "装备促销",  "type": "reward",    "weight": 6 },
	{ "name": "小憩",      "type": "reward",    "weight": 7 },
	{ "name": "获得宝石",  "type": "reward",    "weight": 6 },
	{ "name": "获得打孔器","type": "reward",    "weight": 6 },
	{ "name": "股市崩盘",  "type": "punish",    "weight": 8 },
	{ "name": "暴风雨",    "type": "punish",    "weight": 7 },
	{ "name": "拆迁通知",  "type": "punish",    "weight": 7 },
	{ "name": "诅咒降临",  "type": "punish",    "weight": 8 },
	{ "name": "攻击削弱",  "type": "punish",    "weight": 5 },
	{ "name": "传送门",    "type": "special",   "weight": 8 },
	{ "name": "命运逆转",  "type": "special",   "weight": 7 },
]

static func _exec_fate(ctx: Dictionary) -> Dictionary:
	var pool: Array[Dictionary] = []
	for ev in FATE_EVENTS:
		for _w in range(ev["weight"]):
			pool.append(ev)
	var chosen: Dictionary = pool[randi() % pool.size()]

	match chosen["name"]:
		"股市大涨":
			var lv: int = ctx.get("player_level", 1)
			var g: int = ctx.get("player_gold", 0)
			var add: int = clampi(int(g * 0.05), 100, 50000)
			ctx["player_gold"] = g + add
			return { "event": "fate", "data": { "type": "reward", "name": "股市大涨", "message": "股市大涨！+" + str(add) + " 金币" } }
		"股市崩盘":
			var g2: int = ctx.get("player_gold", 0)
			var sub: int = clampi(int(g2 * 0.05), 100, 10000)
			ctx["player_gold"] = g2 - sub
			return { "event": "fate", "data": { "type": "punish", "name": "股市崩盘", "message": "股市崩盘！-" + str(sub) + " 金币" } }
		"小憩":
			return { "event": "fate", "data": { "type": "reward", "name": "小憩", "message": "小憩恢复50%HP，下次步数+1" } }
		"获得宝石":
			var gid: int = randi_range(1, 7)
			return { "event": "fate", "data": { "type": "reward", "name": "获得宝石", "gem_id": gid, "level": 1, "message": "获得宝石" } }
		"获得打孔器":
			return { "event": "fate", "data": { "type": "reward", "name": "获得打孔器", "message": "获得打孔器×1" } }
		"传送门":
			return { "event": "fate", "data": { "type": "special", "name": "传送门", "message": "传送门！传送到闪电格", "teleport": true } }
		_:
			return { "event": "fate", "data": { "type": chosen["type"], "name": chosen["name"], "message": chosen["name"] } }


## ============ 神祇格 ============
static var GOD_POOL: Array[Dictionary] = [
	{ "name": "财神",     "type": "bless", "weight": 15 },
	{ "name": "战神",     "type": "bless", "weight": 15 },
	{ "name": "速神",     "type": "bless", "weight": 15 },
	{ "name": "福神",     "type": "bless", "weight": 15 },
	{ "name": "衰神",     "type": "curse", "weight": 15 },
	{ "name": "穷神",     "type": "curse", "weight": 8 },
	{ "name": "懒神",     "type": "curse", "weight": 7 },
	{ "name": "命运之神", "type": "special","weight": 10 },
]

static func _exec_god(ctx: Dictionary) -> Dictionary:
	var pool: Array[Dictionary] = []
	for gd in GOD_POOL:
		for _w in range(gd["weight"]):
			pool.append(gd)
	var chosen: Dictionary = pool[randi() % pool.size()]
	return { "event": "god", "data": { "type": chosen["type"], "name": chosen["name"], "message": "遇到" + chosen["name"] + "！" } }


## ============ 合成格 ============
static func _exec_synthesize(ctx: Dictionary) -> Dictionary:
	var eqp_list: Array = ctx.get("equip_instances", [])
	var unequipped: Array[Dictionary] = []
	for ep in eqp_list:
		if not ep.get("equipped", false):
			unequipped.append(ep)
	if unequipped.size() < 2:
		return { "event": "synthesize", "data": { "type": "fail", "message": "背包装备不足2件，无法合成" } }
	# 自动随机选2件不同装备合成
	var a: Dictionary = unequipped[randi() % unequipped.size()]
	var b: Dictionary = a
	while b["uid"] == a["uid"]:
		b = unequipped[randi() % unequipped.size()]

	var qa: int = a.get("quality", 0)
	var qb: int = b.get("quality", 0)
	var result_quality: int
	if qa == qb:
		result_quality = mini(qa + 1, 4)
	else:
		var low: int = mini(qa, qb)
		var high: int = maxi(qa, qb)
		var span: int = mini(high + 1, 4) - low + 1
		result_quality = low + randi() % span

	var slot: String = a["slot"] if randi() % 2 == 0 else b["slot"]
	var new_eqp: Dictionary = EquipGenCls.generate(slot, ctx.get("player_level", 1))
	# 强制品质
	var old_quality: int = new_eqp["quality"]
	new_eqp["quality"] = result_quality
	new_eqp["quality_name"] = EquipGenCls.EquipDataCls.QUALITY_NAMES.get(result_quality, "???")

	# 移除原2件
	for ei in range(eqp_list.size() - 1, -1, -1):
		if eqp_list[ei]["uid"] == a["uid"] or eqp_list[ei]["uid"] == b["uid"]:
			eqp_list.remove_at(ei)
	eqp_list.append(new_eqp)

	return { "event": "synthesize", "data": { "type": "success", "quality": result_quality, "message": "合成获得 [" + EquipGenCls.EquipDataCls.QUALITY_NAMES.get(result_quality,"?") + "] " + new_eqp["base_name"] } }


## ============ 闪电格 ============
static func _exec_lightning(ctx: Dictionary) -> Dictionary:
	var jump: int = randi_range(2, 5)
	return { "event": "lightning", "data": { "jump": jump, "message": "闪电跳跃 " + str(jump) + " 格！" } }


## ============ 工具 ============
static func _random_slot() -> String:
	var slots: Array[String] = ["weapon","armor","shoes","ring","necklace","cape","helmet","charm"]
	return slots[randi() % slots.size()]
