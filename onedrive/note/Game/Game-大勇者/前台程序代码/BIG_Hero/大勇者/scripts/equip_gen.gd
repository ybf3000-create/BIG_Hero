class_name EquipGen
extends RefCounted
## ============================================================
## EquipGen — 装备生成器 v1.5
## 按品质/部位/词条规则生成装备实例
## 新增：词条部位投放限制 + EqTier档位驱动
## ============================================================

const EquipDataCls = preload("res://scripts/equip_data.gd")
const EquipIconsCls = preload("res://scripts/equip_icons.gd")

# 品质掉落权重
const QUALITY_WEIGHTS: Array[float] = [0.60, 0.28, 0.10, 0.017, 0.003]

# 品质 → 词条数
const AFFIX_COUNTS: Array[int] = [1, 2, 3, 4, 5]

# 品质 → 孔数 { min, max }
const GEM_SLOTS: Array[Dictionary] = [
	{ "min": 0, "max": 0 },  # 普通 0
	{ "min": 0, "max": 0 },  # 精良 0
	{ "min": 0, "max": 0 },  # 稀有 0
	{ "min": 1, "max": 2 },  # 史诗 1~2
	{ "min": 1, "max": 3 },  # 传说 1~3
]

# 主属性基础值（按部位）
static var MAIN_BASE: Dictionary = {
	"weapon":    { "name": "攻击力",   "base": 40.0 },
	"armor":     { "name": "防御力",   "base": 30.0 },
	"shoes":     { "name": "闪避率",   "base": 4.0 },
	"ring":      { "name": "暴击率",   "base": 2.0 },
	"necklace":  { "name": "技能伤害", "base": 3.0 },
	"cape":      { "name": "速度",     "base": 5.0 },
	"helmet":    { "name": "格挡率",   "base": 2.0 },
	"charm":     { "name": "生命值",   "base": 100.0 },
}

# 品质系数
static var QUALITY_COEF: Array[float] = [1.0, 1.2, 1.5, 2.0, 3.0]

# 套装池（13套）
static var SET_POOL: Array[Dictionary] = [
	{ "name": "龙鳞", "pos": "坦克" },
	{ "name": "烈焰", "pos": "群伤" },
	{ "name": "冰霜", "pos": "控制" },
	{ "name": "雷霆", "pos": "爆发" },
	{ "name": "疾风", "pos": "攻速" },
	{ "name": "铁壁", "pos": "格挡" },
	{ "name": "暗影", "pos": "暗杀" },
	{ "name": "自然", "pos": "治疗" },
	{ "name": "引力", "pos": "刷宝" },
	{ "name": "星辰", "pos": "技能" },
	{ "name": "幻影", "pos": "闪避" },
	{ "name": "口才", "pos": "跳过" },
	{ "name": "奢侈", "pos": "扣钱" },
]

# 套装品质修正（概率乘数）
static var SET_QUALITY_MOD: Array[float] = [1.5, 1.2, 1.0, 0.7, 0.4]

# 附加词条池
static var AFFIX_POOL: Array[Dictionary] = [
	{ "name": "攻击%",     "type": "attack",  "min": 3.0,  "max": 15.0, "fmt": "+%.0f%%" },
	{ "name": "暴击率",    "type": "attack",  "min": 1.0,  "max": 8.0,  "fmt": "+%.0f%%" },
	{ "name": "暴击伤害",  "type": "attack",  "min": 5.0,  "max": 25.0, "fmt": "+%.0f%%" },
	{ "name": "技能伤害",  "type": "attack",  "min": 3.0,  "max": 15.0, "fmt": "+%.0f%%" },
	{ "name": "命中",      "type": "attack",  "min": 1.0,  "max": 8.0,  "fmt": "+%.0f%%" },
	{ "name": "防御%",     "type": "defense", "min": 3.0,  "max": 12.0, "fmt": "+%.0f%%" },
	{ "name": "生命%",     "type": "defense", "min": 3.0,  "max": 15.0, "fmt": "+%.0f%%" },
	{ "name": "格挡率",    "type": "defense", "min": 1.0,  "max": 25.0, "fmt": "+%.0f%%" },
	{ "name": "闪避率",    "type": "defense", "min": 1.0,  "max": 25.0, "fmt": "+%.0f%%" },
	{ "name": "回血",      "type": "defense", "min": 1.0,  "max": 8.0,  "fmt": "+%.0f/步" },
	{ "name": "吸血",      "type": "defense", "min": 1.0,  "max": 5.0,  "fmt": "+%.0f%%" },
	{ "name": "速度",      "type": "universal","min": 2.0, "max": 15.0, "fmt": "+%.0f" },
	{ "name": "冷却缩减",  "type": "universal","min": 2.0, "max": 10.0, "fmt": "+%.0f%%" },
	{ "name": "幸运",      "type": "universal","min": 2.0, "max": 15.0, "fmt": "+%.0f" },
	{ "name": "金币加成",  "type": "universal","min": 5.0, "max": 25.0, "fmt": "+%.0f%%" },
	{ "name": "经验加成",  "type": "universal","min": 3.0, "max": 10.0, "fmt": "+%.0f%%" },
	{ "name": "攻击(数值)","type": "attack",  "min": 5.0,  "max": 50.0, "fmt": "+%.0f" },
	{ "name": "防御(数值)","type": "defense", "min": 5.0,  "max": 40.0, "fmt": "+%.0f" },
]

# 互斥组
static var MUTEX: Dictionary = {
	"攻击%": "攻击(数值)",
	"攻击(数值)": "攻击%",
	"防御%": "防御(数值)",
	"防御(数值)": "防御%",
}

# 词条部位投放限制（v1.5 新增）
# 5种百分比词条各只在4种装备部位投放，避免无脑叠加
static var SLOT_RESTRICTIONS: Dictionary = {
	"攻击%":  ["weapon", "helmet", "shoes", "ring"],       # 武器/头盔/护腿/戒指
	"暴击率": ["weapon", "cape", "necklace", "ring"],       # 武器/肩甲/腰带/戒指
	"防御%":  ["armor", "cape", "shoes", "helmet"],         # 护甲/肩甲/护腿/靴子
	"格挡率": ["weapon", "armor", "necklace", "ring"],      # 武器/护甲/手套/戒指
	"闪避率": ["helmet", "cape", "necklace", "shoes"],      # 头盔/腰带/手套/靴子
}

static var _next_uid: int = 1


## 计算装备档位 EqTier
## EqTier = player_level + Σ floor(BossTier_i / X_i)
## X值递减规则: Boss#1-50:X=20, 51-100:X=10, 101-150:X=6, 151-180:X=4, 181-200:X=3
static func calc_eq_tier(player_level: int, boss_tiers: Array[int] = []) -> int:
	var tier: int = player_level
	for i in range(boss_tiers.size()):
		var bt: int = boss_tiers[i]
		var x: int = 20
		if i >= 50:  x = 10
		if i >= 100: x = 6
		if i >= 150: x = 4
		if i >= 180: x = 3
		tier += int(floor(float(bt) / float(x)))
	return tier


## 生成一件装备
## level: 玩家等级 (影响主属性系数)
## eq_tier: 装备档位 (可选，用于更高精度的等级系数)
static func generate(slot_name: String, level: int = 1, eq_tier: int = -1) -> Dictionary:
	# 1. 品质
	var quality: int = _roll_quality()

	# 2. 图标
	var icon_info: Dictionary = EquipIconsCls.random_icon(slot_name)

	# 3. 主属性
	var main: Dictionary = MAIN_BASE.get(slot_name, { "name": "???", "base": 1.0 })
	var main_value: float = main["base"] * QUALITY_COEF[quality]
	if slot_name in ["shoes", "ring", "necklace", "helmet"]:
		# 百分比类主属性不受等级系数影响
		pass
	else:
		# 数值类主属性受等级系数影响
		var effective_level: int = eq_tier if eq_tier > 0 else level
		var level_coef: float = 1.0 + (effective_level - 1) * 0.015
		main_value *= level_coef
	main_value = snapped(main_value, 0.1)

	# 4. 附加词条
	var affixes: Array[Dictionary] = []
	var affix_count: int = AFFIX_COUNTS[quality]
	var attack_count: int = 0
	var defense_count: int = 0
	var used_names: Array[String] = []

	for _i in range(affix_count):
		var max_retry: int = 10
		while max_retry > 0:
			max_retry -= 1
			var aff: Dictionary = AFFIX_POOL[randi() % AFFIX_POOL.size()]
			# 检查重复
			if aff["name"] in used_names:
				continue
			# 检查互斥
			var blocked: bool = false
			for un in used_names:
				if MUTEX.get(un, "") == aff["name"] or MUTEX.get(aff["name"], "") == un:
					blocked = true
					break
			if blocked:
				continue
			# 检查类别上限
			if aff["type"] == "attack" and attack_count >= 2:
				continue
			if aff["type"] == "defense" and defense_count >= 2:
				continue
			# 检查词条部位投放限制（v1.5）
			var restricted_slots: Array = SLOT_RESTRICTIONS.get(aff["name"], [])
			if not restricted_slots.is_empty() and not restricted_slots.has(slot_name):
				continue
			# 通过
			if aff["type"] == "attack":
				attack_count += 1
			elif aff["type"] == "defense":
				defense_count += 1
			used_names.append(aff["name"])
			var v: float = randf_range(aff["min"], aff["max"])
			v = snapped(v, 0.1)
			var disp: String = aff["fmt"] % v
			affixes.append({ "name": aff["name"], "value": v, "display": disp })
			break

	# 5. 宝石槽位
	var gem_slots: int = 0
	var gs: Dictionary = GEM_SLOTS[quality]
	if gs["max"] > 0:
		gem_slots = randi_range(gs["min"], gs["max"])

	# 5.5 套装判定（3% + 幸运×0.3%）× 品质修正
	var suit_name: String = ""
	var set_rate: float = (3.0 + 0.0 * 0.3) * SET_QUALITY_MOD[quality] / 100.0  # 幸运=0 默认
	if randf() < set_rate:
		suit_name = SET_POOL[randi() % SET_POOL.size()]["name"]

	# 6. 组装
	var uid: int = _next_uid
	_next_uid += 1

	return {
		"uid": uid,
		"slot": slot_name,
		"slot_type_id": EquipDataCls.SLOT_TYPE_ID.get(slot_name, 0),
		"quality": quality,
		"quality_name": EquipDataCls.QUALITY_NAMES.get(quality, "???"),
		"base_name": icon_info.get("name", "???"),
		"icon": icon_info.get("icon", "❓"),
		"main_stat": main["name"],
		"main_value": main_value,
		"affixes": affixes,
		"gems": [] as Array[int],
		"gem_slots": gem_slots,
		"enhance": 0,
		"suit_name": suit_name,
		"suit_count": 0,
	}


static func _roll_quality() -> int:
	var r: float = randf()
	var cumulative: float = 0.0
	for i in range(QUALITY_WEIGHTS.size()):
		cumulative += QUALITY_WEIGHTS[i]
		if r <= cumulative:
			return i
	return 0


## 获取品质前缀词
static func quality_prefix(q: int) -> String:
	match q:
		0: return ""
		1: return "精良的"
		2: return "稀有的"
		3: return "史诗的"
		4: return "传说的"
	return ""


## 品质颜色字符串（CSS hex）
static func quality_hex(q: int) -> String:
	match q:
		0: return "#999999"
		1: return "#33cc33"
		2: return "#3366ff"
		3: return "#b333ff"
		4: return "#ff9911"
	return "#ffffff"


## 获取装备完整名
static func full_name(eqp: Dictionary) -> String:
	var s: String = ""
	if eqp.get("quality", 0) >= 1:
		s += quality_prefix(eqp["quality"]) + " "
	s += eqp.get("base_name", "???")
	return s


## 序列化（存档用）
static func serialize(eqp: Dictionary) -> Dictionary:
	return eqp.duplicate(true)


static func deserialize(data: Dictionary) -> Dictionary:
	var d: Dictionary = data.duplicate(true)
	return d
