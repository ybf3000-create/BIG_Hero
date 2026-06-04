class_name GridExecutor
extends RefCounted
## ============================================================
## GridExecutor v0.3 — 所有地块效果按策划案实现
## ============================================================

const EquipGenCls = preload("res://scripts/equip_gen.gd")

# 格子类型枚举 — 与 main_game.gd GRID_TYPES 索引对齐
enum GridType {
	HOME     = 0,   # 勇者之家
	BATTLE   = 1,   # 战斗格
	ELITE    = 2,   # 精英战斗
	CHALLENG = 3,   # 挑战格
	REST     = 4,   # 休息格
	TREASURE = 5,   # 宝箱格
	FORGE    = 6,   # 锻造格
	FATE     = 7,   # 命运格
	GOD      = 8,   # 神祇格
	SYNTH    = 9,   # 合成格
	LIGHT    = 10,  # 闪电格
	BOSS     = 11,  # Boss格
	EMPTY    = 12,  # 空地
	EMPTY2   = 13,  # 空地2
}


## 执行格子效果
## context 需包含: player_gold, player_level, player_revive(复活币), equip_instances(装备列表), equipment(装备栏对象)
static func execute(grid_type: int, ctx: Dictionary) -> Dictionary:
	match grid_type:
		GridType.HOME:     return _exec_home(ctx)
		GridType.BATTLE:   return _exec_battle(ctx)
		GridType.ELITE:    return _exec_elite(ctx)
		GridType.CHALLENG: return _exec_challenge(ctx)
		GridType.REST:     return _exec_rest(ctx)
		GridType.TREASURE: return _exec_treasure(ctx)
		GridType.FORGE:    return _exec_forge(ctx)
		GridType.FATE:     return _exec_fate(ctx)
		GridType.GOD:      return _exec_god(ctx)
		GridType.SYNTH:    return _exec_synthesize(ctx)
		GridType.LIGHT:    return _exec_lightning(ctx)
		GridType.BOSS:     return _exec_boss(ctx)
		GridType.EMPTY:    return _exec_empty(ctx)
		GridType.EMPTY2:   return _exec_empty(ctx)
	return { "event": "unknown", "data": {} }


## ============ 勇者之家 ============
static func _exec_home(ctx: Dictionary) -> Dictionary:
	return { "event": "home", "data": { "message": "回到勇者之家" } }


## ============ 战斗格 (先空着) ============
static func _exec_battle(ctx: Dictionary) -> Dictionary:
	return { "event": "battle", "data": { "message": "进入战斗！" } }

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
		var gold: int = mini(lv, 100) * 5
		ctx["player_gold"] = ctx.get("player_gold", 0) + gold
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
	var gold: int = mini(lv, 100) * randi_range(6, 12)
	ctx["player_gold"] = ctx.get("player_gold", 0) + gold
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


## ============ 空地 ============
static func _exec_empty(_ctx: Dictionary) -> Dictionary:
	# 空地静默产出少量金币（实际金币增减由 main_game 处理）
	var lv: int = _ctx.get("player_level", 1)
	var gold: int = int(mini(lv, 100) * randf_range(0.3, 0.8))
	_ctx["player_gold"] = _ctx.get("player_gold", 0) + gold
	return { "event": "empty", "data": { "gold": gold, "message": "" } }


## ============ 工具 ============
static func _random_slot() -> String:
	var slots: Array[String] = ["weapon","armor","shoes","ring","necklace","cape","helmet","charm"]
	return slots[randi() % slots.size()]
