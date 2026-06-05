class_name GameConfig
extends RefCounted
## ==================================================================
## GameConfig — 游戏全局配置表 v2.0
## 集中管理：主角数值 / 货币 / 装备槽 / 技能 / 经济常数
##
## 使用方式:
##   const Config = preload("res://scripts/game_config.gd")
##   var hp: float = Config.player_hp(1)  # Lv.1 HP
##   var gold_drop: int = Config.calc_battle_gold(monster_level)
##
## 修数值只需改这一个文件，不需要翻其他代码。
## 基于数值设计总表 v3.2 — 所有公式以此为准。
## ==================================================================

# ===================================================================
# 一、主角基础数值（Lv.1 初始值）
# ===================================================================
static var PLAYER_BASE: Dictionary = {
	"name":           "勇者",    # 默认名字
	"level":          1,         # 初始等级
	"hp":             500.0,     # 基础生命值 (500 + (Lv-1)*80)
	"atk":            25.0,      # 基础攻击力 (25 + (Lv-1)*2)
	"def":            15.0,      # 基础防御力 (15 + (Lv-1)*1)
	"spd":            0.0,       # 基础速度 (装备提供)
	"luk":            0.0,       # 基础幸运 (装备提供)
	"exp":            0,         # 初始经验
	"exp_max":        100,       # 初始升级所需经验
	"gold":           0,         # 初始金币
	"revive_coins":   3,         # 初始复活币
	"revive_max":     3,         # 最大复活币
	"grid_index":     0,         # 初始位置（0=起点）
	"map_total_grids": 28,       # 地图总格数
}

# ===================================================================
# 二、等级成长曲线
#    等级上限: Lv.100
#    EXP: 100 × 1.12^(Lv-1)
#    自由属性点: 2点/级 (Lv.100累计198点)
# ===================================================================
static var LEVEL_UP: Dictionary = {
	"max_level":         100,      # 等级上限
	"exp_base":          100,      # EXP底数
	"exp_growth":        1.12,     # 每级指数增长
	"free_points":       2,        # 每级自由属性点数
	"attack_per_point":  0.018,    # +1.8%攻击/点（无上限）
	"defense_per_point": 0.012,    # -1.2%受伤/点（上限50%，42点封顶）
	"defense_cap":       0.50,     # 防御减伤上限
	"defense_max_points": 42,      # 防御点数上限
	"speed_per_point":   0.008,    # -0.8% CD/点（上限50%，63点封顶）
	"speed_cap":         0.50,     # 速度CD缩减上限
	"speed_max_points":  63,       # 速度点数上限
	"luck_per_point":    0.015,    # +1.5%稀有概率/点（无上限）
	"gold_reward":       50,       # 升级奖励金币基数
}

## 计算玩家基础HP
static func player_hp(level: int) -> float:
	return 500.0 + (level - 1) * 80.0

## 计算玩家基础ATK
static func player_atk(level: int) -> float:
	return 25.0 + (level - 1) * 2.0

## 计算玩家基础DEF
static func player_def(level: int) -> float:
	return 15.0 + (level - 1) * 1.0

## 计算升级所需EXP
static func exp_for_level(level: int) -> int:
	return int(100.0 * pow(1.12, level - 1))

# ===================================================================
# 三、货币系统
# ===================================================================
static var CURRENCY: Dictionary = {
	"gold":             { "name": "金币", "icon": "🪙", "desc": "通用货币，用于购买和强化" },
	"revive_coin":      { "name": "复活币", "icon": "♻️", "desc": "战斗中复活一次" },
	"lottery_ticket":   { "name": "彩票", "icon": "🎟️", "desc": "用于彩票格抽奖" },
	"diamond":          { "name": "钻石", "icon": "💎", "desc": "稀有货币（暂未开放）" },
}

# ===================================================================
# 四、装备槽定义
#    与 equipment.gd 的 SLOT_TYPE 保持一致
#    type_id 对应 item_db.gd 的物品类型编号
# ===================================================================
static var EQUIP_SLOTS: Array[Dictionary] = [
	{ "key": "weapon",   "name": "武器",  "type_id": 1, "icon": "⚔️" },
	{ "key": "armor",    "name": "防具",  "type_id": 2, "icon": "🛡️" },
	{ "key": "shoes",    "name": "鞋子",  "type_id": 3, "icon": "👟" },
	{ "key": "ring",     "name": "戒指",  "type_id": 4, "icon": "💍" },
	{ "key": "necklace", "name": "项链",  "type_id": 5, "icon": "📿" },
	{ "key": "cape",     "name": "披风",  "type_id": 6, "icon": "🧣" },
	{ "key": "helmet",   "name": "头盔",  "type_id": 7, "icon": "⛑️" },
	{ "key": "charm",    "name": "护符",  "type_id": 8, "icon": "🍀" },
]

# ===================================================================
# 五、技能系统（预留框架）
#    每个技能：id, name, icon, type(主动/被动), cooldown, cost, effect
#    type: 0=伤害 1=治疗 2=Buff 3=Debuff 4=被动
# ===================================================================
static var SKILLS: Dictionary = {
	# 示例技能结构（后续 Phase 2 填充）
	# 1: { "id": 1, "name": "斩击", "icon": "⚔", "type": 0, "cd": 2, "cost": 10, "power": 1.5, "desc": "对单体造成150%物理伤害" },
	# 2: { "id": 2, "name": "治疗术", "icon": "♡", "type": 1, "cd": 3, "cost": 15, "power": 0.3, "desc": "恢复最大HP的30%" },
}

static var SKILL_TYPE_NAMES: Dictionary = {
	0: "伤害",
	1: "治疗",
	2: "Buff",
	3: "Debuff",
	4: "被动",
}

# ===================================================================
# 六、经济与掉落常数（基于数值总表 v3.2）
#    金币/战斗 = min(怪物Lv, 100) × K_gr
#    K_gr = 2.50
#    离线收益 = 在线 × 0.8
# ===================================================================
static var ECONOMY: Dictionary = {
	"K_gr":                  2.50,   # 金币系数
	"gold_level_cap":        100,    # 金币计算等级上限
	"offline_ratio":         0.8,    # 离线收益系数
	"start_pass_gold":       50,     # 经过起点奖励金币
	"battle_exp_base":       20,     # 战斗基础经验
	"battle_exp_per_level":  5,      # 每怪等级额外经验
}

## 计算单次战斗金币
static func calc_battle_gold(monster_level: int, multiplier: float = 1.0) -> int:
	return int(mini(monster_level, ECONOMY["gold_level_cap"]) * ECONOMY["K_gr"] * multiplier)

## 计算离线金币
static func calc_offline_gold(online_gold: int) -> int:
	return int(online_gold * ECONOMY["offline_ratio"])

# ===================================================================
# 七、战斗常数（基于数值总表 v3.2）
#    防御减伤率 = DEF / (DEF + 400)
#    400防 = 50%减伤
# ===================================================================
static var COMBAT: Dictionary = {
	"crit_rate_base":   0.05,   # 基础暴击率 5%
	"crit_dmg_mult":    1.5,    # 暴击伤害倍率
	"dodge_rate_base":  0.03,   # 基础闪避率
	"min_damage":       1,      # 保底伤害
	"def_constant":     400.0,  # 防御公式常数
	"frontline_slots":  3,      # 前排槽位数
	"backline_slots":   3,      # 后排槽位数
}

## 计算防御减伤率
static func calc_def_reduction(def_value: float) -> float:
	return def_value / (def_value + COMBAT["def_constant"])

# ===================================================================
# 八、UI 常量
# ===================================================================
static var UI: Dictionary = {
	"base_width":   1280,
	"base_height":  720,
	"top_bar_h":    110,
	"bottom_bar_h": 86,
	"tile_w":       160,        # 地块宽度
	"tile_h":       90,         # 地块高度
	"tile_shear":   45,         # 斜边偏移
	"tile_count":   7,          # 可见地块数
	"dice_min":     1,
	"dice_max":     6,
}
