class_name BattleEngine
extends RefCounted

const SkillDataRef = preload("res://scripts/skill_data.gd")

const BASE_ACTION_CD: float = 3.0
const CHALLENGE_DURATION: float = 60.0
const MAX_ROUNDS: int = 50
const SHIELD_DURATION: float = 5.0
const HOT_TICK_INTERVAL: float = 1.0
const REPLY_TICK_INTERVAL: float = 5.0


enum Outcome {
	VICTORY,
	DEFEAT,
	DRAW,
	CHALLENGE_DONE,
}


static func run_battle(player_state: Dictionary, encounter: Dictionary) -> Dictionary:
	var state: Dictionary = _build_initial_state(player_state, encounter)
	while true:
		if state["battle_kind"] == "challenge" and state["elapsed"] >= float(encounter.get("duration_limit", CHALLENGE_DURATION)):
			state["outcome"] = Outcome.CHALLENGE_DONE
			break
		if state["rounds"] >= MAX_ROUNDS:
			state["outcome"] = Outcome.DRAW
			break
		var actor_key: String = _pick_next_actor(state)
		if actor_key.is_empty():
			state["outcome"] = Outcome.DRAW
			break
		var delta: float = float(_resolve_actor(state, actor_key).get("time_to_act", 0.0))
		_advance_time(state, delta)
		if state["battle_kind"] == "challenge" and state["elapsed"] >= float(encounter.get("duration_limit", CHALLENGE_DURATION)):
			state["outcome"] = Outcome.CHALLENGE_DONE
			break
		state["rounds"] += 1
		_process_actor_turn(state, actor_key)
		var outcome: int = _check_outcome(state)
		if outcome != -1:
			state["outcome"] = outcome
			break
	return _build_result(state, encounter)


static func _build_initial_state(player_state: Dictionary, encounter: Dictionary) -> Dictionary:
	var player_speed: int = int(player_state.get("speed_points", player_state.get("spd", 0)))
	var player: Dictionary = {
		"side": "player",
		"id": 0,
		"name": player_state.get("name", "勇者"),
		"level": int(player_state.get("level", 1)),
		"max_hp": int(player_state.get("max_hp", 500)),
		"current_hp": int(player_state.get("current_hp", player_state.get("max_hp", 500))),
		"atk": float(player_state.get("atk", 25)),
		"base_atk": float(player_state.get("atk", 25)),
		"def": float(player_state.get("def", 15)),
		"base_def": float(player_state.get("def", 15)),
		"speed_points": player_speed,
		"crit": float(player_state.get("crit", 0.0)),
		"critdmg": float(player_state.get("critdmg", 150.0)),
		"hit": float(player_state.get("hit", 0.0)),
		"dodge": float(player_state.get("dodge", 0.0)),
		"block": float(player_state.get("block", 0.0)),
		"skill_dmg": float(player_state.get("skill_dmg", 0.0)),
		"cd_reduce": float(player_state.get("cd_reduce", 0.0)),
		"lifesteal": float(player_state.get("lifesteal", 0.0)),
		"free_atk_pct": float(player_state.get("free_atk_pct", 0.0)),
		"free_def_pct": float(player_state.get("free_def_pct", 0.0)),
		"gold_bonus": float(player_state.get("gold_bonus", 0.0)),
		"exp_bonus": float(player_state.get("exp_bonus", 0.0)),
		"skill_slots": player_state.get("skill_slots", []).duplicate(true),
		"cooldowns": {},
		"shield": 0.0,
		"shield_time": 0.0,
		"buffs": {},
		"controls": {},
		"dots": [],
		"hots": [],
		"alive": true,
		"action_cd": _calc_action_cd(player_speed),
		"time_to_act": _calc_action_cd(player_speed),
		"undying_used": false,
		"battle_damage_mult": float(player_state.get("battle_damage_mult", 1.0)),
		"passives": player_state.get("passives", []).duplicate(true),
		"regen_timer": REPLY_TICK_INTERVAL,
		"set_counts": player_state.get("set_counts", {}).duplicate(true),
		"battle_gold": int(player_state.get("battle_gold", 0)),
		"set_action_count": 0,
	}
	if _set_count(player, "暗影") >= 3:
		player["buffs"]["shadow_stealth"] = 5.0
	if _set_count(player, "奢侈") >= 3 and int(player.get("battle_gold", 0)) >= 1000:
		player["atk"] = float(player["atk"]) * (1.6 if _set_count(player, "奢侈") >= 4 else 1.3)
		player["base_atk"] = player["atk"]
	player["thunder_timer"] = 8.0
	for slot in player["skill_slots"]:
		if slot == null:
			continue
		var sid: int = int(slot.get("skill_id", 0))
		if sid > 0:
			player["cooldowns"][sid] = 0.0

	var enemies: Array[Dictionary] = []
	for raw_unit in encounter.get("units", []):
		var unit: Dictionary = raw_unit.duplicate(true)
		unit["side"] = "enemy"
		unit["shield"] = 0.0
		unit["shield_time"] = 0.0
		unit["buffs"] = {}
		unit["controls"] = {}
		unit["dots"] = []
		unit["hots"] = []
		unit["cooldowns"] = {}
		unit["alive"] = true
		unit["undying_used"] = false
		unit["battle_damage_mult"] = float(unit.get("battle_damage_mult", 1.0))
		unit["base_atk"] = float(unit.get("atk", 0.0))
		unit["base_def"] = float(unit.get("def", 0.0))
		unit["regen_timer"] = REPLY_TICK_INTERVAL
		var speed_points: int = int(unit.get("speed_points", 0))
		unit["action_cd"] = _calc_action_cd(speed_points)
		unit["time_to_act"] = unit["action_cd"]
		for sid in unit.get("skill_ids", []):
			var skill_id: int = int(sid)
			if skill_id > 0:
				unit["cooldowns"][skill_id] = 0.0
		_apply_passive_start(unit)
		enemies.append(unit)

	return {
		"actors": {"player": player, "enemies": enemies},
		"elapsed": 0.0,
		"rounds": 0,
		"log": [],
		"events": [],
		"damage_total": 0.0,
		"player_start_hp": int(player.get("current_hp", 1)),
		"outcome": -1,
		"battle_kind": encounter.get("battle_kind", "battle"),
		"template_id": encounter.get("template_id", ""),
		"template_name": encounter.get("template_name", ""),
	}


static func _calc_action_cd(speed_points: int) -> float:
	return BASE_ACTION_CD * (1.0 - minf(float(speed_points) * 0.008, 0.50))


static func _pick_next_actor(state: Dictionary) -> String:
	var best_key: String = ""
	var best_time: float = INF
	var player: Dictionary = state["actors"]["player"]
	if player.get("alive", false):
		best_key = "player"
		best_time = float(player.get("time_to_act", INF))
	for idx in range(state["actors"]["enemies"].size()):
		var enemy: Dictionary = state["actors"]["enemies"][idx]
		if not enemy.get("alive", false):
			continue
		var et: float = float(enemy.get("time_to_act", INF))
		if et < best_time:
			best_time = et
			best_key = "enemy:%d" % idx
	return best_key


static func _advance_time(state: Dictionary, delta: float) -> void:
	state["elapsed"] += delta
	var player: Dictionary = state["actors"]["player"]
	if player.get("alive", false):
		player["time_to_act"] = maxf(0.0, float(player.get("time_to_act", 0.0)) - delta)
		_tick_actor_timers(state, player, delta)
	for idx in range(state["actors"]["enemies"].size()):
		var enemy: Dictionary = state["actors"]["enemies"][idx]
		if not enemy.get("alive", false):
			continue
		enemy["time_to_act"] = maxf(0.0, float(enemy.get("time_to_act", 0.0)) - delta)
		_tick_actor_timers(state, enemy, delta)


static func _tick_actor_timers(state: Dictionary, actor: Dictionary, delta: float) -> void:
	if _set_count(actor, "雷霆") >= 4:
		actor["thunder_timer"] = float(actor.get("thunder_timer", 8.0)) - delta
		if float(actor["thunder_timer"]) <= 0.0:
			actor["buffs"]["thunder_frenzy"] = 2.0
			actor["thunder_timer"] = 8.0
	if float(actor.get("shield_time", 0.0)) > 0.0:
		actor["shield_time"] = maxf(0.0, float(actor.get("shield_time", 0.0)) - delta)
		if float(actor.get("shield_time", 0.0)) <= 0.0:
			actor["shield"] = 0.0

	var buffs: Dictionary = actor.get("buffs", {})
	for key in buffs.keys():
		buffs[key] = maxf(0.0, float(buffs[key]) - delta)
		if float(buffs[key]) <= 0.0:
			buffs.erase(key)

	var controls: Dictionary = actor.get("controls", {})
	for key in controls.keys():
		controls[key] = maxf(0.0, float(controls[key]) - delta)
		if float(controls[key]) <= 0.0:
			controls.erase(key)

	var dots: Array = actor.get("dots", [])
	for i in range(dots.size() - 1, -1, -1):
		var dot: Dictionary = dots[i]
		dot["tick_timer"] = float(dot.get("tick_timer", 0.0)) - delta
		while float(dot.get("tick_timer", 0.0)) <= 0.0 and int(dot.get("ticks_remaining", 0)) > 0 and actor.get("alive", false):
			dot["tick_timer"] = float(dot.get("tick_timer", 0.0)) + float(dot.get("tick_interval", 1.0))
			_tick_dot(state, actor, dot)
			dot["ticks_remaining"] = int(dot.get("ticks_remaining", 0)) - 1
		if int(dot.get("ticks_remaining", 0)) <= 0 or not actor.get("alive", false):
			dots.remove_at(i)

	var hots: Array = actor.get("hots", [])
	for i in range(hots.size() - 1, -1, -1):
		var hot: Dictionary = hots[i]
		hot["tick_timer"] = float(hot.get("tick_timer", 0.0)) - delta
		while float(hot.get("tick_timer", 0.0)) <= 0.0 and int(hot.get("ticks_remaining", 0)) > 0 and actor.get("alive", false):
			hot["tick_timer"] = float(hot.get("tick_timer", 0.0)) + float(hot.get("tick_interval", HOT_TICK_INTERVAL))
			_apply_heal(state, actor, float(actor.get("max_hp", 0.0)) * float(hot.get("heal_pct", 0.0)) / 100.0, "持续治疗")
			hot["ticks_remaining"] = int(hot.get("ticks_remaining", 0)) - 1
		if int(hot.get("ticks_remaining", 0)) <= 0:
			hots.remove_at(i)

	if _has_passive(actor, "回复") and actor.get("alive", false):
		actor["regen_timer"] = float(actor.get("regen_timer", REPLY_TICK_INTERVAL)) - delta
		while float(actor.get("regen_timer", 0.0)) <= 0.0 and actor.get("alive", false):
			actor["regen_timer"] = float(actor.get("regen_timer", 0.0)) + REPLY_TICK_INTERVAL
			_apply_heal(state, actor, float(actor.get("max_hp", 0.0)) * 0.05, "回复")
	if _set_count(actor, "自然") >= 4 and float(actor.get("shield", 0.0)) > 0.0 and actor.get("alive", false):
		actor["nature_regen_timer"] = float(actor.get("nature_regen_timer", 1.0)) - delta
		while float(actor.get("nature_regen_timer", 0.0)) <= 0.0:
			actor["nature_regen_timer"] = float(actor.get("nature_regen_timer", 0.0)) + 1.0
			_apply_heal(state, actor, float(actor.get("max_hp", 0.0)) * 0.02, "自然护盾")


static func _process_actor_turn(state: Dictionary, actor_key: String) -> void:
	var actor: Dictionary = _resolve_actor(state, actor_key)
	if actor.is_empty() or not actor.get("alive", false):
		return
	if _has_hard_control(actor):
		state["log"].append("%s 受硬控，跳过行动" % actor.get("name", "单位"))
		_reset_after_turn(actor)
		return
	_tick_action_cooldowns(actor)
	var action: Dictionary = _choose_action(actor)
	if action.get("type", "") == "skill":
		_execute_skill(state, actor, int(action.get("skill_id", 0)))
	else:
		_execute_basic_attack(state, actor)
	_reset_after_turn(actor)


static func _tick_action_cooldowns(actor: Dictionary) -> void:
	var cooldowns: Dictionary = actor.get("cooldowns", {})
	for sid in cooldowns.keys():
		cooldowns[sid] = maxf(0.0, float(cooldowns[sid]) - 1.0)


static func _resolve_actor(state: Dictionary, actor_key: String) -> Dictionary:
	if actor_key == "player":
		return state["actors"]["player"]
	if actor_key.begins_with("enemy:"):
		var idx: int = int(actor_key.split(":")[1])
		if idx >= 0 and idx < state["actors"]["enemies"].size():
			return state["actors"]["enemies"][idx]
	return {}


static func _has_hard_control(actor: Dictionary) -> bool:
	var controls: Dictionary = actor.get("controls", {})
	return controls.has("freeze") or controls.has("stun")


static func _choose_action(actor: Dictionary) -> Dictionary:
	if actor.get("controls", {}).has("silence"):
		return {"type": "basic"}

	var available: Array = []
	var cooldowns: Dictionary = actor.get("cooldowns", {})
	var skill_slots: Array = actor.get("skill_slots", [])
	if actor.get("side", "") == "player":
		if actor.get("current_hp", 0) <= int(actor.get("max_hp", 0)) * 0.2 and not actor.get("undying_used", false):
			for slot in skill_slots:
				if slot == null:
					continue
				if int(slot.get("skill_id", 0)) == 26 and float(cooldowns.get(26, 0.0)) <= 0.0:
					available.append({"priority": 99, "slot": -1, "skill_id": 26})
		for i in range(skill_slots.size()):
			var slot = skill_slots[i]
			if slot == null:
				continue
			var sid: int = int(slot.get("skill_id", 0))
			if sid > 0 and float(cooldowns.get(sid, 0.0)) <= 0.0:
				available.append({"priority": int(slot.get("priority", 1)), "slot": i, "skill_id": sid})
	else:
		for sid in actor.get("skill_ids", []):
			var skill_id: int = int(sid)
			if skill_id > 0 and float(cooldowns.get(skill_id, 0.0)) <= 0.0:
				available.append({"priority": 1, "slot": 0, "skill_id": skill_id})

	if available.is_empty():
		return {"type": "basic"}
	available.sort_custom(func(a, b):
		if int(a["priority"]) != int(b["priority"]):
			return int(a["priority"]) > int(b["priority"])
		return int(a["slot"]) < int(b["slot"])
	)
	return {"type": "skill", "skill_id": int(available[0]["skill_id"])}


static func _execute_basic_attack(state: Dictionary, actor: Dictionary) -> void:
	var targets: Array = _select_basic_targets(state, actor)
	if targets.is_empty():
		return
	state["events"].append(_cast_event(actor, targets, 0, "普攻", "basic"))
	_apply_attack_instance(state, actor, targets[0], 100.0, {"label": "普攻", "is_basic": true})


static func _execute_skill(state: Dictionary, actor: Dictionary, skill_id: int) -> void:
	var skill: Dictionary = SkillDataRef.get_skill(skill_id).duplicate(true)
	if skill.is_empty():
		_execute_basic_attack(state, actor)
		return
	if skill_id == 12:
		var max_stacks: int = int(skill.get("bonus", {}).get("max_stacks", 10))
		var chain_count: int = mini(int(actor.get("endless_strike_count", 0)) + 1, max_stacks)
		skill["dmg_pct"] = float(skill.get("dmg_pct", 0.0)) + float(chain_count - 1) * float(skill.get("bonus", {}).get("stack_step_pct", 10.0))
		actor["endless_strike_count"] = chain_count

	var targets: Array = _select_skill_targets(state, actor, skill)
	state["events"].append(_cast_event(actor, targets, skill_id, str(skill.get("name", "技能")), _skill_visual_type(skill)))
	if skill.has("shield_pct"):
		_apply_shield(state, actor, skill)
	if skill.has("heal_pct") and (int(skill.get("target", -1)) == SkillDataRef.TargetTag.SELF or int(skill.get("target", -1)) == SkillDataRef.TargetTag.SELF_HEAL):
		_apply_heal_skill(state, actor, skill)
	if int(skill_id) == 25:
		_add_hot(actor, skill)
	if skill.get("buff_effect", "") != "":
		_apply_buff(actor, skill)
	if int(skill_id) == 26:
		actor["undying_used"] = true

	var handled_pierce: bool = false
	if skill.get("bonus", {}).has("pierce_back_dmg") and targets.size() >= 1:
		handled_pierce = true
		_apply_attack_instance(state, actor, targets[0], float(skill.get("dmg_pct", 0.0)), {"label": skill.get("name", "技能"), "skill": skill})
		if targets.size() >= 2 and targets[1].get("alive", false):
			var back_skill: Dictionary = skill.duplicate(true)
			back_skill["dmg_pct"] = float(skill.get("bonus", {}).get("pierce_back_dmg", 0.0))
			if skill.get("bonus", {}).has("pierce_back_slow"):
				back_skill["control"] = SkillDataRef.ControlType.SLOW
				back_skill["control_dur"] = float(skill.get("bonus", {}).get("pierce_back_slow", 0.0))
			_apply_attack_instance(state, actor, targets[1], float(back_skill.get("dmg_pct", 0.0)), {"label": skill.get("name", "技能") + "(贯穿)", "skill": back_skill})
			if skill.get("bonus", {}).has("pierce_back_execute"):
				var exec_info: Dictionary = skill.get("bonus", {}).get("pierce_back_execute", {})
				var hp_pct: float = float(targets[1].get("current_hp", 0.0)) / maxf(float(targets[1].get("max_hp", 1.0)), 1.0)
				if hp_pct < float(exec_info.get("threshold", 0.0)):
					_apply_final_damage(state, targets[1], float(actor.get("atk", 0.0)) * float(exec_info.get("mult", 1.0)), {"source": actor.get("name", "单位"), "owner": actor})
		if skill.has("control") and targets.size() >= 1:
			_apply_control_to_target(state, targets[0], skill)
	elif not targets.is_empty():
		for target in targets:
			if not target.get("alive", false):
				continue
			if skill.has("dmg_pct"):
				_apply_attack_instance(state, actor, target, float(skill.get("dmg_pct", 0.0)), {"label": skill.get("name", "技能"), "skill": skill})
			if skill.has("control"):
				_apply_control_to_target(state, target, skill)

	if not handled_pierce:
		for target in targets:
			if not target.get("alive", false):
				continue
			if skill.has("dot_pct"):
				_apply_dot(state, target, actor, skill)
			if int(skill_id) == 31:
				_detonate_dots(state, actor, target, float(skill.get("bonus", {}).get("detonate_dot", 1.5)))
			if int(skill_id) == 32:
				_spread_dot(state, target)
	else:
		for target in targets:
			if not target.get("alive", false):
				continue
			if skill.has("dot_pct"):
				_apply_dot(state, target, actor, skill)
			if int(skill_id) == 31:
				_detonate_dots(state, actor, target, float(skill.get("bonus", {}).get("detonate_dot", 1.5)))
			if int(skill_id) == 32:
				_spread_dot(state, target)

	_set_skill_cooldown(actor, skill_id, float(skill.get("action_cd", 1.0)))
	if _set_count(actor, "星辰") >= 3 and randf() < 0.25:
		actor["cooldowns"][skill_id] = 0.0
		actor["star_energy"] = int(actor.get("star_energy", 0)) + 1
		if _set_count(actor, "星辰") >= 4 and int(actor["star_energy"]) >= 5:
			actor["star_energy"] = 0
			for enemy in _opponents(state, actor):
				if enemy.get("alive", false):
					var star_dealt := _apply_final_damage(state, enemy, float(actor.get("atk", 0.0)) * 4.0, {"source": "星辰坠落", "owner": actor})
					state["events"].append({"type": "damage", "source": _actor_ref(actor), "target": _actor_ref(enemy), "amount": int(round(star_dealt)), "hp": int(round(float(enemy.get("current_hp", 0)))), "max_hp": int(enemy.get("max_hp", 1)), "shield": int(round(float(enemy.get("shield", 0.0)))), "crit": false, "block": false, "dot": false, "label": "星辰坠落"})
			for sid in actor.get("cooldowns", {}).keys():
				actor["cooldowns"][sid] = 0.0
	if actor.get("buffs", {}).has("shadow_strike"):
		actor["buffs"].erase("shadow_strike")


static func _set_skill_cooldown(actor: Dictionary, skill_id: int, base_cd: float) -> void:
	var cd_reduce: float = minf(float(actor.get("cd_reduce", 0.0)) / 100.0, 0.50)
	var extra_mult: float = 1.0
	if actor.get("controls", {}).has("paralysis"):
		extra_mult = 1.3
	actor["cooldowns"][skill_id] = base_cd * (1.0 - cd_reduce) * extra_mult


static func _reset_after_turn(actor: Dictionary) -> void:
	var next_cd: float = float(actor.get("action_cd", BASE_ACTION_CD))
	if actor.get("controls", {}).has("slow"):
		next_cd *= 1.5
	actor["set_action_count"] = int(actor.get("set_action_count", 0)) + 1
	if _set_count(actor, "疾风") >= 3:
		var threshold := 3
		if int(actor["set_action_count"]) % threshold == 0:
			next_cd = 0.01
			if _set_count(actor, "疾风") >= 4:
				_reset_random_cooldown(actor)
	actor["time_to_act"] = next_cd


static func _reset_random_cooldown(actor: Dictionary) -> void:
	var active: Array = []
	for sid in actor.get("cooldowns", {}).keys():
		if float(actor["cooldowns"][sid]) > 0.0:
			active.append(sid)
	if not active.is_empty():
		actor["cooldowns"][active[randi() % active.size()]] = 0.0


static func _set_count(actor: Dictionary, set_name: String) -> int:
	return int(actor.get("set_counts", {}).get(set_name, 0))


static func _apply_set_burn(state: Dictionary, target: Dictionary, actor: Dictionary) -> void:
	var burns := 0
	for dot in target.get("dots", []):
		if str(dot.get("dot_type", "")) == "set_burn":
			burns += 1
	if burns >= 3:
		return
	var entry: Dictionary = {
		"source_name": "烈焰套·灼烧", "damage": float(actor.get("atk", 0.0)) * 0.20,
		"ticks_remaining": 3, "tick_interval": 1.0, "tick_timer": 1.0,
		"dot_type": "set_burn", "source_id": -100, "source_side": actor.get("side", "enemy"),
	}
	target["dots"].append(entry)
	_tick_dot(state, target, entry)
	entry["ticks_remaining"] = int(entry["ticks_remaining"]) - 1


static func _trigger_chain_lightning(state: Dictionary, actor: Dictionary, primary: Dictionary, max_targets: int) -> void:
	var chained := 0
	for enemy in _opponents(state, actor):
		if enemy == primary or not enemy.get("alive", false):
			continue
		var dealt := _apply_final_damage(state, enemy, float(actor.get("atk", 0.0)) * 1.5, {"source": "雷霆套·连锁闪电", "owner": actor})
		state["events"].append({"type": "damage", "source": _actor_ref(actor), "target": _actor_ref(enemy), "amount": int(round(dealt)), "hp": int(round(float(enemy.get("current_hp", 0)))), "max_hp": int(enemy.get("max_hp", 1)), "shield": int(round(float(enemy.get("shield", 0.0)))), "crit": false, "block": false, "dot": false, "label": "连锁闪电"})
		chained += 1
		if chained >= max_targets:
			break


static func _opponents(state: Dictionary, actor: Dictionary) -> Array:
	if actor.get("side", "") == "player":
		return state["actors"]["enemies"]
	return [state["actors"]["player"]]


static func _handle_set_kill(state: Dictionary, actor: Dictionary) -> void:
	if _set_count(actor, "暗影") >= 4:
		actor["buffs"]["shadow_strike"] = 4.0
		actor["time_to_act"] = 0.0
	if _set_count(actor, "自然") >= 3:
		_apply_heal(state, actor, float(actor.get("max_hp", 1)) * 0.08, "自然套·生机")


static func _select_basic_targets(state: Dictionary, actor: Dictionary) -> Array:
	if actor.get("side", "") == "player":
		return _select_enemy_targets_by_tag(state, SkillDataRef.TargetTag.FRONT_LINE)
	return [state["actors"]["player"]] if state["actors"]["player"].get("alive", false) else []


static func _select_skill_targets(state: Dictionary, actor: Dictionary, skill: Dictionary) -> Array:
	if actor.get("side", "") == "enemy":
		var target_tag: int = int(skill.get("target", SkillDataRef.TargetTag.FRONT_LINE))
		if target_tag == SkillDataRef.TargetTag.SELF or target_tag == SkillDataRef.TargetTag.SELF_HEAL:
			return [actor]
		return [state["actors"]["player"]] if state["actors"]["player"].get("alive", false) else []
	return _select_enemy_targets_by_tag(state, int(skill.get("target", SkillDataRef.TargetTag.FRONT_LINE)), skill)


static func _select_enemy_targets_by_tag(state: Dictionary, target_tag: int, skill: Dictionary = {}) -> Array:
	var enemies: Array = []
	for enemy in state["actors"]["enemies"]:
		if enemy.get("alive", false):
			enemies.append(enemy)
	if enemies.is_empty():
		return []

	var front: Array = []
	var back: Array = []
	for enemy in enemies:
		if enemy.get("row", "front") == "front":
			front.append(enemy)
		else:
			back.append(enemy)

	match target_tag:
		SkillDataRef.TargetTag.FRONT_LINE:
			return [front[0]] if not front.is_empty() else [back[0]]
		SkillDataRef.TargetTag.BACK_LINE:
			return [back[0]] if not back.is_empty() else [front[0]]
		SkillDataRef.TargetTag.LOWEST_HP:
			return [_pick_best(enemies, func(a, b): return float(a["current_hp"]) < float(b["current_hp"]))]
		SkillDataRef.TargetTag.LOWEST_HP_PCT:
			return [_pick_best(enemies, func(a, b): return float(a["current_hp"]) / maxf(float(a["max_hp"]), 1.0) < float(b["current_hp"]) / maxf(float(b["max_hp"]), 1.0))]
		SkillDataRef.TargetTag.HIGHEST_ATK:
			return [_pick_best(enemies, func(a, b): return float(a["atk"]) > float(b["atk"]))]
		SkillDataRef.TargetTag.HIGHEST_DEF:
			return [_pick_best(enemies, func(a, b): return float(a["def"]) > float(b["def"]))]
		SkillDataRef.TargetTag.AOE_FRONT:
			return front if not front.is_empty() else back
		SkillDataRef.TargetTag.AOE_ALL:
			var max_targets: int = int(skill.get("bonus", {}).get("max_targets", 0))
			if max_targets > 0:
				return enemies.slice(0, min(max_targets, enemies.size()))
			return enemies
		SkillDataRef.TargetTag.AOE_BACK:
			return back if not back.is_empty() else front
		SkillDataRef.TargetTag.PIERCE:
			if not front.is_empty():
				var first_front: Dictionary = front[0]
				var result: Array = [first_front]
				var partner: Dictionary = _find_same_column_target(front, back, first_front)
				if not partner.is_empty():
					result.append(partner)
				return result
			return [back[0]]
		SkillDataRef.TargetTag.SELF, SkillDataRef.TargetTag.SELF_HEAL:
			return []
	return [front[0]] if not front.is_empty() else [back[0]]


static func _find_same_column_target(front: Array, back: Array, front_target: Dictionary) -> Dictionary:
	var front_index: int = front.find(front_target)
	if front_index >= 0 and front_index < back.size():
		return back[front_index]
	return {}


static func _pick_best(arr: Array, cmp: Callable) -> Dictionary:
	var best: Dictionary = arr[0]
	for i in range(1, arr.size()):
		var cand: Dictionary = arr[i]
		if cmp.call(cand, best):
			best = cand
	return best


static func _apply_attack_instance(state: Dictionary, actor: Dictionary, target: Dictionary, dmg_pct: float, meta: Dictionary) -> void:
	var skill: Dictionary = meta.get("skill", {})
	var label: String = str(meta.get("label", "攻击"))
	var raw_damage: float = float(actor.get("atk", 0.0)) * dmg_pct / 100.0
	if actor.get("buffs", {}).has("phantom_step"):
		raw_damage *= 1.30
	if actor.get("side", "") == "player":
		raw_damage *= 1.0 + float(actor.get("free_atk_pct", 0.0))
	raw_damage *= float(actor.get("battle_damage_mult", 1.0))
	if _has_passive(actor, "狂暴") and float(actor.get("current_hp", 0.0)) / maxf(float(actor.get("max_hp", 1.0)), 1.0) < 0.5:
		raw_damage *= 1.5
	if not skill.is_empty():
		raw_damage *= 1.0 + float(actor.get("skill_dmg", 0.0)) / 100.0

	var hits: int = int(skill.get("hits", 1)) if not skill.is_empty() else 1
	for _i in range(hits):
		var result: Dictionary = _resolve_hit_crit_block(actor, target)
		if not result.get("hit", false):
			state["log"].append("%s 对 %s 的%s MISS" % [actor.get("name", "单位"), target.get("name", "目标"), label])
			state["events"].append({"type": "miss", "source": _actor_ref(actor), "target": _actor_ref(target), "label": label})
			if _set_count(target, "幻影") >= 3:
				target["buffs"]["phantom_next"] = 999.0
				target["phantom_dodges"] = int(target.get("phantom_dodges", 0)) + 1
				if _set_count(target, "幻影") >= 4 and int(target["phantom_dodges"]) % 3 == 0:
					target["buffs"]["phantom_step"] = 3.0
			continue
		var damage: float = raw_damage
		if actor.get("buffs", {}).has("phantom_next"):
			damage *= 1.5
			actor["buffs"].erase("phantom_next")
		if actor.get("buffs", {}).has("shadow_strike"):
			damage *= 2.5
		var ignore_def_pct: float = float(skill.get("bonus", {}).get("ignore_def_pct", 0.0))
		damage = _apply_defense_damage(actor, target, damage, ignore_def_pct)
		if result.get("crit", false):
			damage *= float(actor.get("critdmg", 150.0)) / 100.0
		if result.get("block", false):
			damage *= 0.35 if _set_count(target, "铁壁") >= 3 else 0.5
		if target.get("controls", {}).has("freeze"):
			damage *= 1.5
			target["controls"].erase("freeze")
		var burn_count := 0
		for dot in target.get("dots", []):
			if str(dot.get("dot_type", "")) == "set_burn":
				burn_count += 1
		if _set_count(actor, "烈焰") >= 4 and burn_count > 0:
			damage *= 1.0 + minf(float(burn_count), 4.0) * 0.12
		if skill.get("bonus", {}).has("execute_threshold"):
			var th: float = float(skill.get("bonus", {}).get("execute_threshold", 0.0))
			var mult: float = float(skill.get("bonus", {}).get("execute_mult", 1.0))
			if float(target.get("current_hp", 0.0)) / maxf(float(target.get("max_hp", 1.0)), 1.0) < th:
				damage *= mult
		if skill.get("bonus", {}).has("missing_hp_scale"):
			var miss_ratio: float = 1.0 - float(target.get("current_hp", 0.0)) / maxf(float(target.get("max_hp", 1.0)), 1.0)
			damage *= 1.0 + miss_ratio * float(skill.get("bonus", {}).get("missing_hp_scale", 0.0))
		var dealt: float = _apply_final_damage(state, target, damage, {
			"source": actor.get("name", "单位"),
			"owner": actor,
			"crit": result.get("crit", false),
			"block": result.get("block", false),
			"ignore_def": false,
			"ignore_free_def": false,
		})
		state["log"].append("%s 对 %s 使用%s 造成 %.0f 伤害" % [actor.get("name", "单位"), target.get("name", "目标"), label, dealt])
		state["events"].append({
			"type": "damage", "source": _actor_ref(actor), "target": _actor_ref(target),
			"amount": int(round(dealt)), "hp": int(round(float(target.get("current_hp", 0.0)))),
			"max_hp": int(target.get("max_hp", 1)), "shield": int(round(float(target.get("shield", 0.0)))), "crit": bool(result.get("crit", false)),
			"block": bool(result.get("block", false)), "dot": false, "label": label,
		})
		if actor.get("side", "") == "player":
			state["damage_total"] += maxf(dealt, 0.0)
		if dealt > 0.0 and _set_count(actor, "烈焰") >= 3 and target.get("alive", false):
			_apply_set_burn(state, target, actor)
		if dealt > 0.0 and _set_count(actor, "冰霜") >= 3 and target.get("alive", false):
			var freeze_chance := 0.075 if target.get("is_boss", false) else 0.15
			if randf() < freeze_chance:
				target["controls"]["freeze"] = 1.5
				state["events"].append({"type": "status", "target": _actor_ref(target), "status": "冻结", "duration": 1.5})
				if _set_count(actor, "冰霜") >= 4:
					actor["shield"] = float(actor.get("shield", 0.0)) + float(actor.get("max_hp", 1)) * 0.08
		if result.get("crit", false) and _set_count(actor, "雷霆") >= 3:
			_trigger_chain_lightning(state, actor, target, 2)
		if result.get("block", false) and _set_count(target, "铁壁") >= 4:
			target["set_block_count"] = int(target.get("set_block_count", 0)) + 1
			if int(target["set_block_count"]) % 3 == 0:
				_apply_final_damage(state, actor, float(target.get("current_hp", 1)) * 0.5, {"source": "铁壁反弹", "owner": target})
				target["shield"] = float(target.get("shield", 0.0)) + float(target.get("max_hp", 1)) * 0.15
		if dealt > 0.0 and _set_count(target, "龙鳞") >= 3 and randf() < 0.20:
			_apply_final_damage(state, actor, dealt * 0.30, {"source": "龙鳞反伤", "owner": target})
		if dealt > 0.0 and _set_count(target, "龙鳞") >= 4:
			target["dragon_hits"] = int(target.get("dragon_hits", 0)) + 1
			if int(target["dragon_hits"]) % 5 == 0:
				target["buffs"]["dragon_guard"] = 4.0
				for foe in _opponents(state, target):
					if foe.get("alive", false):
						_apply_final_damage(state, foe, float(target.get("atk", 0.0)) * 2.0, {"source": "龙威", "owner": target})
		if not target.get("alive", true):
			_handle_set_kill(state, actor)
		if dealt > 0.0 and _has_passive(target, "荆棘") and actor.get("alive", false):
			_apply_final_damage(state, actor, dealt * 0.15, {"source": target.get("name", "单位") + "(荆棘)"})
		if dealt > 0.0 and bool(meta.get("is_basic", false)) and _has_passive(actor, "毒素") and target.get("alive", false):
			_apply_passive_poison(state, target, actor)


static func _resolve_hit_crit_block(actor: Dictionary, target: Dictionary) -> Dictionary:
	var dodge_rate: float = maxf(0.0, float(target.get("dodge", 0.0)) - float(actor.get("hit", 0.0)))
	if target.get("buffs", {}).has("phantom_step"):
		dodge_rate *= 2.0
	var hit_success: bool = randf() * 100.0 >= dodge_rate
	var crit_rate := float(actor.get("crit", 0.0))
	if actor.get("buffs", {}).has("shadow_stealth"):
		crit_rate += 30.0
	if actor.get("buffs", {}).has("thunder_frenzy") or actor.get("buffs", {}).has("shadow_strike"):
		crit_rate = 100.0
	var crit_success: bool = randf() * 100.0 < crit_rate
	var block_success: bool = randf() * 100.0 < float(target.get("block", 0.0))
	return {"hit": hit_success, "crit": crit_success, "block": block_success}


static func _apply_defense_damage(_actor: Dictionary, target: Dictionary, damage: float, ignore_def_pct: float) -> float:
	var effective_def: float = float(target.get("def", 0.0))
	if target.get("buffs", {}).has("def_x2"):
		effective_def *= 2.0
	effective_def *= (1.0 - ignore_def_pct / 100.0)
	var dr: float = effective_def / (effective_def + 400.0)
	var result: float = damage * (1.0 - dr)
	if target.get("side", "") == "player":
		result *= (1.0 - minf(float(target.get("free_def_pct", 0.0)), 0.50))
	if target.get("buffs", {}).has("tenacity"):
		result *= 0.6
	if target.get("buffs", {}).has("dragon_guard"):
		result *= 0.7
	return maxf(result, 1.0)


static func _apply_final_damage(state: Dictionary, target: Dictionary, damage: float, meta: Dictionary) -> float:
	var remaining: float = damage
	var absorbed: float = 0.0
	if float(target.get("shield", 0.0)) > 0.0:
		absorbed = minf(float(target.get("shield", 0.0)), remaining)
		target["shield"] = float(target.get("shield", 0.0)) - absorbed
		remaining -= absorbed

	var hp_before: float = float(target.get("current_hp", 0.0))
	if remaining > 0.0:
		target["current_hp"] = maxf(0.0, hp_before - remaining)
	var dealt_hp: float = maxf(0.0, hp_before - float(target.get("current_hp", 0.0)))
	var total_dealt: float = dealt_hp + absorbed

	if float(target.get("current_hp", 0.0)) <= 0.0:
		if target.get("buffs", {}).has("undying"):
			target["current_hp"] = 1.0
			target["buffs"].erase("undying")
		elif bool(target.get("infinite_hp", false)):
			target["current_hp"] = maxf(1.0, float(target.get("current_hp", 0.0)))
		else:
			target["alive"] = false
			target["dots"] = []
			if _has_passive(target, "诅咒") and meta.has("owner"):
				var owner: Dictionary = meta["owner"]
				owner.get("controls", {})["anti_heal"] = 5.0
				state["log"].append("%s 的诅咒触发，%s 被禁疗 5 秒" % [target.get("name", "单位"), owner.get("name", "目标")])

	if meta.has("owner"):
		var owner2: Dictionary = meta["owner"]
		var ls: float = float(owner2.get("lifesteal", 0.0)) / 100.0
		if ls > 0.0 and dealt_hp > 0.0:
			_apply_heal(state, owner2, dealt_hp * ls, "吸血")
	return total_dealt


static func _apply_heal(state: Dictionary, actor: Dictionary, heal_amount: float, label: String) -> void:
	var actual: float = heal_amount
	if actor.get("controls", {}).has("anti_heal"):
		actual *= 0.5
	var before: float = float(actor.get("current_hp", 0.0))
	actor["current_hp"] = minf(float(actor.get("max_hp", 0.0)), before + actual)
	var healed := float(actor.get("current_hp", 0.0)) - before
	var overflow := maxf(0.0, actual - healed)
	if overflow > 0.0 and _set_count(actor, "自然") >= 4:
		var shield_cap := float(actor.get("max_hp", 1)) * 0.30
		actor["shield"] = minf(shield_cap, float(actor.get("shield", 0.0)) + overflow)
		actor["shield_time"] = maxf(float(actor.get("shield_time", 0.0)), SHIELD_DURATION)
	state["log"].append("%s %s %.0f" % [actor.get("name", "单位"), label, healed])
	state["events"].append({"type": "heal", "target": _actor_ref(actor), "amount": int(round(healed)), "hp": int(round(float(actor.get("current_hp", 0.0)))), "max_hp": int(actor.get("max_hp", 1)), "label": label})


static func _apply_heal_skill(state: Dictionary, actor: Dictionary, skill: Dictionary) -> void:
	var heal_value: float = 0.0
	var stat_key: String = str(skill.get("heal_stat", "atk"))
	match stat_key:
		"atk":
			heal_value = float(actor.get("atk", 0.0)) * float(skill.get("heal_pct", 0.0)) / 100.0
		"max_hp_pct":
			heal_value = float(actor.get("max_hp", 0.0)) * float(skill.get("heal_pct", 0.0)) / 100.0
	_apply_heal(state, actor, heal_value, str(skill.get("name", "治疗")))


static func _apply_shield(state: Dictionary, actor: Dictionary, skill: Dictionary) -> void:
	var shield_value: float = 0.0
	var stat_key: String = str(skill.get("shield_stat", "def"))
	match stat_key:
		"def":
			shield_value = float(actor.get("def", 0.0)) * float(skill.get("shield_pct", 0.0)) / 100.0
		"atk":
			shield_value = float(actor.get("atk", 0.0)) * float(skill.get("shield_pct", 0.0)) / 100.0
		"max_hp_pct":
			shield_value = float(actor.get("max_hp", 0.0)) * float(skill.get("shield_pct", 0.0)) / 100.0
	actor["shield"] = float(actor.get("shield", 0.0)) + shield_value
	actor["shield_time"] = SHIELD_DURATION
	state["log"].append("%s 获得护盾 %.0f" % [actor.get("name", "单位"), shield_value])
	state["events"].append({"type": "shield", "target": _actor_ref(actor), "amount": int(round(shield_value)), "shield": int(round(float(actor.get("shield", 0.0)))), "max_hp": int(actor.get("max_hp", 1)), "label": str(skill.get("name", "护盾"))})


static func _apply_buff(actor: Dictionary, skill: Dictionary) -> void:
	var effect: String = str(skill.get("buff_effect", ""))
	var dur: float = float(skill.get("buff_dur", 0.0))
	if effect.is_empty() or dur <= 0.0:
		return
	actor["buffs"][effect] = dur


static func _apply_control_to_target(state: Dictionary, target: Dictionary, skill: Dictionary) -> void:
	if target.get("buffs", {}).has("tenacity"):
		return
	var control_type: int = int(skill.get("control", -1))
	var dur: float = float(skill.get("control_dur", 0.0))
	if target.get("is_boss", false):
		dur *= 0.5
	match control_type:
		SkillDataRef.ControlType.FREEZE:
			target["controls"]["freeze"] = dur
		SkillDataRef.ControlType.STUN:
			target["controls"]["stun"] = dur
		SkillDataRef.ControlType.SILENCE:
			target["controls"]["silence"] = dur
		SkillDataRef.ControlType.PARALYSIS:
			target["controls"]["paralysis"] = dur
		SkillDataRef.ControlType.SLOW:
			target["controls"]["slow"] = dur
		SkillDataRef.ControlType.ANTI_HEAL:
			target["controls"]["anti_heal"] = dur
	if control_type != SkillDataRef.ControlType.NONE and dur > 0.0:
		state["events"].append({"type": "status", "target": _actor_ref(target), "status": SkillDataRef.control_name(control_type), "duration": dur})


static func _actor_ref(actor: Dictionary) -> Dictionary:
	return {"side": str(actor.get("side", "enemy")), "id": int(actor.get("id", 0)), "name": str(actor.get("name", "单位"))}


static func _cast_event(actor: Dictionary, targets: Array, skill_id: int, label: String, visual: String) -> Dictionary:
	var refs: Array[Dictionary] = []
	for target in targets:
		refs.append(_actor_ref(target as Dictionary))
	return {"type": "cast", "source": _actor_ref(actor), "targets": refs, "skill_id": skill_id, "label": label, "visual": visual}


static func _skill_visual_type(skill: Dictionary) -> String:
	if skill.has("heal_pct"):
		return "heal"
	if skill.has("shield_pct") or not str(skill.get("buff_effect", "")).is_empty():
		return "buff"
	if skill.has("dot_pct"):
		return "dot"
	if skill.has("control"):
		return "control"
	if int(skill.get("target", -1)) in [SkillDataRef.TargetTag.AOE_FRONT, SkillDataRef.TargetTag.AOE_ALL, SkillDataRef.TargetTag.AOE_BACK]:
		return "aoe"
	return "projectile"


static func _apply_dot(state: Dictionary, target: Dictionary, actor: Dictionary, skill: Dictionary) -> void:
	var dot_damage: float = float(actor.get("atk", 0.0)) * float(skill.get("dot_pct", 0.0)) / 100.0
	dot_damage *= float(actor.get("battle_damage_mult", 1.0))
	var tick_count: int = maxi(1, int(skill.get("dot_tick_count", 1)))
	var tick_interval: float = maxf(0.01, float(skill.get("dot_tick_interval", 1.0)))
	var entry: Dictionary = {
		"source_name": skill.get("name", "Dot"),
		"damage": dot_damage,
		"ticks_remaining": tick_count,
		"tick_interval": tick_interval,
		"tick_timer": tick_interval,
		"dot_type": skill.get("dot_type", "dot"),
		"source_side": actor.get("side", "enemy"),
	}
	var dots: Array = target.get("dots", [])
	if int(skill.get("dot_mode", 0)) == SkillDataRef.DotMode.REFRESH:
		for dot in dots:
			if dot.get("source_name", "") == entry["source_name"]:
				dot["damage"] = dot_damage
				dot["ticks_remaining"] = tick_count
				dot["tick_interval"] = tick_interval
				dot["tick_timer"] = tick_interval
				dot["source_side"] = actor.get("side", "enemy")
				_tick_dot(state, target, dot)
				dot["ticks_remaining"] = int(dot["ticks_remaining"]) - 1
				return
	if dots.size() >= 10:
		dots.pop_front()
	dots.append(entry)
	_tick_dot(state, target, entry)
	entry["ticks_remaining"] = int(entry["ticks_remaining"]) - 1


static func _tick_dot(state: Dictionary, target: Dictionary, dot: Dictionary) -> void:
	var dealt: float = _apply_final_damage(state, target, float(dot.get("damage", 0.0)), {
		"source": dot.get("source_name", "Dot"), "dot": true,
		"ignore_free_def": false, "ignore_def": false,
	})
	state["events"].append({"type": "damage", "target": _actor_ref(target), "amount": int(round(dealt)), "hp": int(round(float(target.get("current_hp", 0.0)))), "max_hp": int(target.get("max_hp", 1)), "shield": int(round(float(target.get("shield", 0.0)))), "crit": false, "block": false, "dot": true, "label": str(dot.get("source_name", "Dot"))})
	if str(dot.get("source_side", "enemy")) == "player":
		state["damage_total"] += maxf(dealt, 0.0)


static func _detonate_dots(state: Dictionary, actor: Dictionary, target: Dictionary, mult: float) -> void:
	var dots: Array = target.get("dots", [])
	if dots.is_empty():
		return
	var total: float = 0.0
	for dot in dots:
		total += float(dot.get("damage", 0.0)) * float(dot.get("ticks_remaining", 0))
	var dealt: float = _apply_final_damage(state, target, total * mult, {"source": actor.get("name", "单位"), "owner": actor})
	if actor.get("side", "") == "player":
		state["damage_total"] += dealt


static func _spread_dot(state: Dictionary, source_target: Dictionary) -> void:
	var dots: Array = source_target.get("dots", [])
	if dots.is_empty():
		return
	for enemy in state["actors"]["enemies"]:
		if enemy == source_target or not enemy.get("alive", false):
			continue
		for dot in dots:
			if enemy["dots"].size() >= 10:
				enemy["dots"].pop_front()
			enemy["dots"].append(dot.duplicate(true))


static func _add_hot(actor: Dictionary, skill: Dictionary) -> void:
	var bonus: Dictionary = skill.get("bonus", {})
	var tick_count: int = maxi(1, int(bonus.get("tick_count", 5)))
	var tick_interval: float = maxf(0.01, float(bonus.get("tick_interval", HOT_TICK_INTERVAL)))
	# 释放流程已经立即治疗一次，此处只登记余下次数。
	if tick_count > 1:
		actor["hots"].append({"heal_pct": float(skill.get("heal_pct", 0.0)), "ticks_remaining": tick_count - 1, "tick_interval": tick_interval, "tick_timer": tick_interval})


static func _check_outcome(state: Dictionary) -> int:
	if state["battle_kind"] != "challenge" and not state["actors"]["player"].get("alive", false):
		return Outcome.DEFEAT
	var any_enemy_alive: bool = false
	for enemy in state["actors"]["enemies"]:
		if enemy.get("alive", false) or enemy.get("infinite_hp", false):
			any_enemy_alive = true
			break
	if not any_enemy_alive:
		return Outcome.VICTORY
	return -1


static func _build_result(state: Dictionary, encounter: Dictionary) -> Dictionary:
	var outcome: int = int(state.get("outcome", Outcome.DRAW))
	var player: Dictionary = state["actors"]["player"]
	var result: Dictionary = {
		"outcome": outcome,
		"player_hp": int(round(float(player.get("current_hp", 0.0)))),
		"player_start_hp": int(state.get("player_start_hp", player.get("max_hp", 1))),
		"player_max_hp": int(round(float(player.get("max_hp", 0.0)))),
		"player_alive": bool(player.get("alive", false)),
		"damage_total": int(round(float(state.get("damage_total", 0.0)))),
		"elapsed": float(state.get("elapsed", 0.0)),
		"rounds": int(state.get("rounds", 0)),
		"log": state.get("log", []).duplicate(true),
		"events": state.get("events", []).duplicate(true),
		"battle_kind": encounter.get("battle_kind", "battle"),
		"monster_level": encounter.get("monster_level", 1),
		"template_id": encounter.get("template_id", ""),
		"template_name": encounter.get("template_name", ""),
		"gold_gain": 0,
		"exp_gain": 0,
		"drops": [],
		"revive_used": false,
		"force_home": false,
		"gold_penalty": 0,
		"boss_cleared": false,
		"luxury_gold_spent": 0,
	}
	if _set_count(player, "奢侈") >= 3:
		var cost_per_tick := int(player.get("level", 1)) * (100 if _set_count(player, "奢侈") >= 4 else 50)
		result["luxury_gold_spent"] = mini(int(player.get("battle_gold", 0)), int(floor(float(result["elapsed"]) / 10.0)) * cost_per_tick)

	if encounter.get("battle_kind", "") == "challenge" and outcome == Outcome.CHALLENGE_DONE:
		var challenge_rewards: Dictionary = _calc_challenge_rewards(int(result["damage_total"]), int(player.get("level", 1)))
		result["gold_gain"] = challenge_rewards.get("gold_gain", 0)
		result["drops"] = challenge_rewards.get("drops", []).duplicate(true)
		return result

	if outcome == Outcome.VICTORY:
		var rewards: Dictionary = _calc_victory_rewards(encounter, player)
		result["gold_gain"] = rewards.get("gold_gain", 0)
		result["exp_gain"] = rewards.get("exp_gain", 0)
		result["drops"] = rewards.get("drops", []).duplicate(true)
		result["boss_cleared"] = encounter.get("battle_kind", "") == "boss"
	return result


static func _calc_victory_rewards(encounter: Dictionary, player: Dictionary) -> Dictionary:
	var monster_level: int = int(encounter.get("monster_level", 1))
	var gold_bonus_mult: float = 1.0 + float(player.get("gold_bonus", 0.0)) / 100.0
	var exp_bonus_mult: float = 1.0 + float(player.get("exp_bonus", 0.0)) / 100.0
	match encounter.get("battle_kind", "battle"):
		"battle":
			return {
				"gold_gain": int(round(monster_level * randf_range(8.0, 15.0) * gold_bonus_mult)),
				"exp_gain": int(round(monster_level * randf_range(10.0, 18.0) * exp_bonus_mult)),
				"drops": [{"kind": "equip"}],
			}
		"elite":
			return {
				"gold_gain": int(round(monster_level * randf_range(20.0, 35.0) * gold_bonus_mult)),
				"exp_gain": int(round(monster_level * randf_range(25.0, 40.0) * exp_bonus_mult)),
				"drops": [{"kind": "equip", "quality_floor": 1}],
			}
		"boss":
			return {
				"gold_gain": int(round(monster_level * 40.0 * gold_bonus_mult)),
				"exp_gain": int(round(monster_level * 50.0 * exp_bonus_mult)),
				"drops": [{"kind": "boss"}],
			}
	return {"gold_gain": 0, "exp_gain": 0, "drops": []}


static func _calc_challenge_rewards(total_damage: int, player_level: int) -> Dictionary:
	var gold_gain: int = 0
	var drops: Array[Dictionary] = []
	if total_damage >= 5000:
		gold_gain += player_level * 50
	if total_damage >= 15000:
		gold_gain += player_level * 100
	if total_damage >= 30000:
		gold_gain += player_level * 200
		drops.append({"kind": "equip", "quality_floor": 1})
	if total_damage >= 60000:
		gold_gain += player_level * 400
		drops.append({"kind": "equip", "quality_floor": 2})
	if total_damage >= 100000:
		gold_gain += player_level * 800
		drops.append({"kind": "equip", "quality_floor": 3})
	return {"gold_gain": gold_gain, "drops": drops}


static func _apply_passive_start(unit: Dictionary) -> void:
	for passive in unit.get("passives", []):
		match String(passive):
			"铁壁":
				unit["def"] = float(unit.get("def", 0.0)) * 1.3
				unit["base_def"] = float(unit.get("def", 0.0))
			"迅捷":
				unit["action_cd"] = maxf(0.5, float(unit.get("action_cd", BASE_ACTION_CD)) - 0.3)
				unit["time_to_act"] = unit["action_cd"]
			"护盾":
				unit["shield"] = float(unit.get("max_hp", 0.0)) * 0.2
				unit["shield_time"] = SHIELD_DURATION


static func _has_passive(actor: Dictionary, passive_name: String) -> bool:
	for passive in actor.get("passives", []):
		if String(passive) == passive_name:
			return true
	return false


static func _apply_passive_poison(state: Dictionary, target: Dictionary, actor: Dictionary) -> void:
	var entry: Dictionary = {
		"source_name": actor.get("name", "单位") + "·毒素",
		"damage": float(actor.get("atk", 0.0)) * 0.15,
		"ticks_remaining": 5,
		"tick_interval": 1.0,
		"tick_timer": 1.0,
		"dot_type": "poison",
		"source_side": actor.get("side", "enemy"),
	}
	var dots: Array = target.get("dots", [])
	for dot in dots:
		if dot.get("source_name", "") == entry["source_name"]:
			dot["damage"] = entry["damage"]
			dot["ticks_remaining"] = entry["ticks_remaining"]
			dot["tick_interval"] = entry["tick_interval"]
			dot["tick_timer"] = entry["tick_timer"]
			_tick_dot(state, target, dot)
			dot["ticks_remaining"] = int(dot["ticks_remaining"]) - 1
			return
	if dots.size() >= 10:
		dots.pop_front()
	dots.append(entry)
	_tick_dot(state, target, entry)
	entry["ticks_remaining"] = int(entry["ticks_remaining"]) - 1
