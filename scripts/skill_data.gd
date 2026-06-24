class_name SkillData
extends RefCounted
## ============================================================
## SkillData v0.1 — 全部36技能定义 + 控制效果 + 被动技能
## 来源：技能系统细化案【定案】v0.4
## ============================================================

# 目标标签（对应策划案 §3.1）
enum TargetTag {
	FRONT_LINE,        # 前排位序
	BACK_LINE,         # 后排位序
	LOWEST_HP,         # 全场最低HP
	LOWEST_HP_PCT,     # 全场最低HP%
	HIGHEST_ATK,       # 全场最高攻击
	HIGHEST_DEF,       # 全场最高防御
	AOE_FRONT,         # 前排全体
	AOE_ALL,           # 敌方全体
	AOE_BACK,          # 后排全体
	PIERCE,            # 贯穿
	SELF,              # 玩家自身
	SELF_HEAL,         # 治疗自身
}

# 技能类型/流派
enum School {
	BURST,     # ⚡ 爆发流
	SUSTAIN,   # 🔥 持续流
	CONTROL,   # 🧊 控制流
	SURVIVAL,  # 🛡 生存流
	DOT,       # ☠ Dot流
	PIERCE,    # 🎯 贯穿流
}

# 控制类型
enum ControlType {
	NONE,
	FREEZE,    # 冻结
	STUN,      # 眩晕
	SILENCE,   # 沉默
	PARALYSIS, # 麻痹
	SLOW,      # 减速
	ANTI_HEAL, # 禁疗
}

# Dot叠加模式
enum DotMode {
	REFRESH,   # 刷新持续时间
	STACK,     # 叠加层数
}

# 技能结构模板
# { id, name, icon, school, target, cd, desc,
#   dmg_pct, hits, dot_pct, dot_dur, dot_type, dot_mode,
#   control, control_dur, control_pct,
#   shield_pct, shield_stat, heal_pct, heal_stat,
#   buff_effect, buff_dur, bonus }

# ======== ⚡ 爆发流 1~6 ========
static var SKILLS: Array[Dictionary] = [
	# 1 - 重击
	{ "id": 1, "name": "重击", "icon": "⚔", "school": 0, "target": 0,
	  "cd": 4, "desc": "攻击力×150% 单体伤害",
	  "dmg_pct": 150.0, "hits": 1 },
	# 2 - 猛力一击
	{ "id": 2, "name": "猛力一击", "icon": "💥", "school": 0, "target": 0,
	  "cd": 8, "desc": "攻击力×250% 单体重击",
	  "dmg_pct": 250.0, "hits": 1 },
	# 3 - 蓄力斩
	{ "id": 3, "name": "蓄力斩", "icon": "⚡", "school": 0, "target": 0,
	  "cd": 12, "desc": "攻击力×400% 蓄力一击",
	  "dmg_pct": 400.0, "hits": 1 },
	# 4 - 碎裂打击
	{ "id": 4, "name": "碎裂打击", "icon": "🪨", "school": 0, "target": 5,
	  "cd": 6, "desc": "攻击力×180% 无视20%防御",
	  "dmg_pct": 180.0, "hits": 1, "bonus": { "ignore_def_pct": 20 } },
	# 5 - 致命一击
	{ "id": 5, "name": "致命一击", "icon": "🗡", "school": 0, "target": 2,
	  "cd": 15, "desc": "攻击力×500% HP<30%翻倍",
	  "dmg_pct": 500.0, "hits": 1, "bonus": { "execute_threshold": 0.3, "execute_mult": 2.0 } },
	# 6 - 终结技
	{ "id": 6, "name": "终结技", "icon": "🎯", "school": 0, "target": 3,
	  "cd": 20, "desc": "攻击力×300% 每损失1%HP+1%伤害",
	  "dmg_pct": 300.0, "hits": 1, "bonus": { "missing_hp_scale": 1.0 } },

	# ======== 🔥 持续流 7~12 ========
	{ "id": 7, "name": "快速打击", "icon": "⚡", "school": 1, "target": 0,
	  "cd": 2, "desc": "攻击力×80% 快速攻击",
	  "dmg_pct": 80.0, "hits": 1 },
	{ "id": 8, "name": "连击", "icon": "💥", "school": 1, "target": 0,
	  "cd": 3, "desc": "攻击力×60% ×2次",
	  "dmg_pct": 60.0, "hits": 2 },
	{ "id": 9, "name": "旋风斩", "icon": "🌀", "school": 1, "target": 7,
	  "cd": 4, "desc": "攻击力×100% 全体AOE",
	  "dmg_pct": 100.0, "hits": 1 },
	{ "id": 10, "name": "连射", "icon": "🏹", "school": 1, "target": 0,
	  "cd": 3, "desc": "攻击力×45% ×3次",
	  "dmg_pct": 45.0, "hits": 3 },
	{ "id": 11, "name": "回旋镖", "icon": "🪃", "school": 1, "target": 7,
	  "cd": 5, "desc": "攻击力×120% 最多2目标",
	  "dmg_pct": 120.0, "hits": 1, "bonus": { "max_targets": 2 } },
	{ "id": 12, "name": "无尽打击", "icon": "♾", "school": 1, "target": 0,
	  "cd": 1, "desc": "攻击力×40% 每5次重置CD",
	  "dmg_pct": 40.0, "hits": 1, "bonus": { "reset_after": 5 } },

	# ======== 🧊 控制流 13~20 ========
	{ "id": 13, "name": "冰冻射击", "icon": "❄", "school": 2, "target": 0,
	  "cd": 5, "desc": "攻击力×100% 冻结8秒",
	  "dmg_pct": 100.0, "hits": 1,
	  "control": 0, "control_dur": 8.0 },
	{ "id": 14, "name": "冰霜新星", "icon": "🧊", "school": 2, "target": 7,
	  "cd": 8, "desc": "攻击力×80% 全体减速8秒",
	  "dmg_pct": 80.0, "hits": 1,
	  "control": 4, "control_dur": 8.0 },
	{ "id": 15, "name": "眩晕锤", "icon": "🔨", "school": 2, "target": 0,
	  "cd": 7, "desc": "攻击力×120% 眩晕8秒",
	  "dmg_pct": 120.0, "hits": 1,
	  "control": 1, "control_dur": 8.0 },
	{ "id": 16, "name": "雷霆一击", "icon": "⚡", "school": 2, "target": 0,
	  "cd": 6, "desc": "攻击力×130% 麻痹8秒",
	  "dmg_pct": 130.0, "hits": 1,
	  "control": 3, "control_dur": 8.0 },
	{ "id": 17, "name": "静默领域", "icon": "🔇", "school": 2, "target": 7,
	  "cd": 10, "desc": "攻击力×60% 全体沉默8秒",
	  "dmg_pct": 60.0, "hits": 1,
	  "control": 2, "control_dur": 8.0 },
	{ "id": 18, "name": "深度冻结", "icon": "❄️", "school": 2, "target": 0,
	  "cd": 15, "desc": "攻击力×200% 冻结8秒",
	  "dmg_pct": 200.0, "hits": 1,
	  "control": 0, "control_dur": 8.0 },
	{ "id": 19, "name": "腐蚀之触", "icon": "💀", "school": 2, "target": 4,
	  "cd": 8, "desc": "攻击力×100% 禁疗8秒",
	  "dmg_pct": 100.0, "hits": 1,
	  "control": 5, "control_dur": 8.0 },
	{ "id": 20, "name": "时间凝滞", "icon": "⏳", "school": 2, "target": 7,
	  "cd": 12, "desc": "攻击力×50% 全体麻痹8秒",
	  "dmg_pct": 50.0, "hits": 1,
	  "control": 3, "control_dur": 8.0 },

	# ======== 🛡 生存流 21~26 ========
	{ "id": 21, "name": "护盾", "icon": "🛡", "school": 3, "target": 9,
	  "cd": 6, "desc": "护盾=防御力×300% 持续5秒",
	  "shield_pct": 300.0, "shield_stat": "def" },
	{ "id": 22, "name": "治疗波", "icon": "💚", "school": 3, "target": 10,
	  "cd": 8, "desc": "恢复攻击力×150% HP",
	  "heal_pct": 150.0, "heal_stat": "atk" },
	{ "id": 23, "name": "铁壁姿态", "icon": "🏰", "school": 3, "target": 9,
	  "cd": 10, "desc": "防御翻倍4秒",
	  "buff_effect": "def_x2", "buff_dur": 4.0 },
	{ "id": 24, "name": "坚毅", "icon": "💪", "school": 3, "target": 9,
	  "cd": 8, "desc": "受伤-40%+免疫控制4秒",
	  "buff_effect": "tenacity", "buff_dur": 4.0 },
	{ "id": 25, "name": "生命绽放", "icon": "🌿", "school": 3, "target": 10,
	  "cd": 12, "desc": "5秒内每秒恢复5%最大HP",
	  "heal_pct": 5.0, "heal_stat": "max_hp_pct", "bonus": { "tick_dur": 5.0, "tick_interval": 1.0 } },
	{ "id": 26, "name": "不屈意志", "icon": "❤️‍🔥", "school": 3, "target": 9,
	  "cd": 20, "desc": "HP<20%自动触发 锁血4秒",
	  "buff_effect": "undying", "buff_dur": 4.0, "bonus": { "trigger_hp_pct": 0.2 } },

	# ======== ☠ Dot流 27~32 ========
	{ "id": 27, "name": "毒刃", "icon": "🗡", "school": 4, "target": 0,
	  "cd": 4, "desc": "直伤80%+Dot30%/次×8秒",
	  "dmg_pct": 80.0, "hits": 1,
	  "dot_pct": 30.0, "dot_dur": 8.0, "dot_type": "poison", "dot_mode": 0 },
	{ "id": 28, "name": "烈焰灼烧", "icon": "🔥", "school": 4, "target": 7,
	  "cd": 6, "desc": "直伤60%+Dot40%/次×8秒全体",
	  "dmg_pct": 60.0, "hits": 1,
	  "dot_pct": 40.0, "dot_dur": 8.0, "dot_type": "burn", "dot_mode": 0 },
	{ "id": 29, "name": "撕裂", "icon": "🩸", "school": 4, "target": 0,
	  "cd": 5, "desc": "直伤120%+Dot20%/次×8秒",
	  "dmg_pct": 120.0, "hits": 1,
	  "dot_pct": 20.0, "dot_dur": 8.0, "dot_type": "bleed", "dot_mode": 0 },
	{ "id": 30, "name": "毒雾", "icon": "☁️", "school": 4, "target": 7,
	  "cd": 8, "desc": "直伤40%+Dot50%/次×8秒全体",
	  "dmg_pct": 40.0, "hits": 1,
	  "dot_pct": 50.0, "dot_dur": 8.0, "dot_type": "poison", "dot_mode": 0 },
	{ "id": 31, "name": "剧毒爆发", "icon": "💚", "school": 4, "target": 0,
	  "cd": 10, "desc": "结算目标所有Dot剩余伤害×1.5",
	  "bonus": { "detonate_dot": 1.5 } },
	{ "id": 32, "name": "瘟疫传播", "icon": "🦠", "school": 4, "target": 7,
	  "cd": 15, "desc": "将目标Dot复制到所有敌人",
	  "bonus": { "spread_dot": true } },

	# ======== 🎯 贯穿流 33~36 ========
	{ "id": 33, "name": "穿刺射击", "icon": "🏹", "school": 5, "target": 9,
	  "cd": 5, "desc": "前120%+后80%贯穿",
	  "dmg_pct": 120.0, "hits": 1, "bonus": { "pierce_back_dmg": 80.0 } },
	{ "id": 34, "name": "裂地斩", "icon": "🌍", "school": 5, "target": 9,
	  "cd": 8, "desc": "前180%+后120% 后排减速8秒",
	  "dmg_pct": 180.0, "hits": 1,
	  "bonus": { "pierce_back_dmg": 120.0, "pierce_back_slow": 8.0 } },
	{ "id": 35, "name": "穿透箭雨", "icon": "🌧", "school": 5, "target": 9,
	  "cd": 6, "desc": "前90%+后90%贯穿",
	  "dmg_pct": 90.0, "hits": 1, "bonus": { "pierce_back_dmg": 90.0 } },
	{ "id": 36, "name": "暗影突袭", "icon": "🌑", "school": 5, "target": 9,
	  "cd": 10, "desc": "前150%+后100% 后排HP<30%×1.5",
	  "dmg_pct": 150.0, "hits": 1,
	  "bonus": { "pierce_back_dmg": 100.0, "pierce_back_execute": { "threshold": 0.3, "mult": 1.5 } } },
]

# 按ID快速查找
static func get_skill(id: int) -> Dictionary:
	for s in SKILLS:
		if s["id"] == id:
			return s
	return {}

# 按流派筛选
static func get_skills_by_school(school: int) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for s in SKILLS:
		if s["school"] == school:
			result.append(s)
	return result

# 获取技能显示名称
static func skill_name(id: int) -> String:
	var s := get_skill(id)
	return s.get("name", "???")

# 获取技能图标
static func skill_icon(id: int) -> String:
	var s := get_skill(id)
	return s.get("icon", "❓")

# 流派名称
static func school_name(school: int) -> String:
	match school:
		0: return "爆发流"
		1: return "持续流"
		2: return "控制流"
		3: return "生存流"
		4: return "Dot流"
		5: return "贯穿流"
	return "未知"

# 控制类型名称
static func control_name(ct: int) -> String:
	match ct:
		0: return "冻结"
		1: return "眩晕"
		2: return "沉默"
		3: return "麻痹"
		4: return "减速"
		5: return "禁疗"
	return ""
