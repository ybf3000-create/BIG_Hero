class_name TopBar
extends RefCounted

var main_game


func _init(mg):
	main_game = mg


func build() -> void:
	var bar := Panel.new()
	bar.name = "TopBar"
	bar.position = Vector2(0, 0)
	bar.size = Vector2(1280, 128)
	UIUtils.panel_style(bar, Color(0.10, 0.10, 0.14))

	# -- 角色头像 --
	var avatar_bg := ColorRect.new()
	avatar_bg.name = "AvatarBg"
	avatar_bg.position = Vector2(8, 8)
	avatar_bg.size = Vector2(94, 94)
	avatar_bg.color = Color(0.18, 0.18, 0.28)
	bar.add_child(avatar_bg)

	var avatar_tex := load("res://assets/主角.png")
	if avatar_tex:
		var avatar := TextureRect.new()
		avatar.name = "AvatarImg"
		avatar.position = Vector2(10, 10)
		avatar.size = Vector2(90, 90)
		avatar.texture = avatar_tex
		avatar.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		avatar.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		bar.add_child(avatar)
	else:
		var fallback := Label.new()
		fallback.name = "AvatarFallback"
		fallback.text = "👤"
		fallback.add_theme_font_size_override("font_size", 48)
		fallback.position = Vector2(28, 20)
		bar.add_child(fallback)

	# 头像点击区域（打开属性面板）
	var avatar_btn := Button.new()
	avatar_btn.name = "AvatarBtn"
	avatar_btn.flat = true
	avatar_btn.position = Vector2(8, 8)
	avatar_btn.size = Vector2(94, 94)
	UIUtils.btn_transparent2(avatar_btn)
	avatar_btn.pressed.connect(main_game._show_stats_panel)
	bar.add_child(avatar_btn)

	# -- 名字 + 等级 --
	var name_lbl := Label.new()
	name_lbl.name = "NameLabel"
	name_lbl.text = main_game.player_name
	name_lbl.add_theme_font_size_override("font_size", 24)
	name_lbl.add_theme_color_override("font_color", Color.WHITE)
	name_lbl.position = Vector2(112, 8)
	bar.add_child(name_lbl)

	var lv_lbl := Label.new()
	lv_lbl.name = "LevelLabel"
	lv_lbl.text = "Lv." + str(main_game.player_level)
	lv_lbl.add_theme_font_size_override("font_size", 16)
	lv_lbl.add_theme_color_override("font_color", Color(0.6, 0.8, 1.0))
	lv_lbl.position = Vector2(112, 34)
	bar.add_child(lv_lbl)

	# -- 经验条 --
	var exp_bar := ProgressBar.new()
	exp_bar.name = "ExpBar"
	exp_bar.position = Vector2(112, 58)
	exp_bar.size = Vector2(240, 16)
	exp_bar.value = main_game.player_exp
	exp_bar.max_value = main_game.player_exp_max
	UIUtils.bar_style(exp_bar, Color(0.15, 0.35, 0.6))
	bar.add_child(exp_bar)

	var exp_lbl := Label.new()
	exp_lbl.name = "ExpLabel"
	exp_lbl.text = str(main_game.player_exp) + "/" + str(main_game.player_exp_max)
	exp_lbl.add_theme_font_size_override("font_size", 10)
	exp_lbl.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))
	exp_lbl.position = Vector2(117, 59)
	exp_lbl.size = Vector2(230, 14)
	exp_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bar.add_child(exp_lbl)

	# -- 复活币 --
	var rv_icon := Label.new()
	rv_icon.text = "💀"
	rv_icon.add_theme_font_size_override("font_size", 22)
	rv_icon.position = Vector2(370, 8)
	bar.add_child(rv_icon)

	var rv_lbl := Label.new()
	rv_lbl.name = "ReviveLabel"
	rv_lbl.text = str(main_game.player_revive) + "/" + str(main_game.player_max_revive)
	rv_lbl.add_theme_font_size_override("font_size", 16)
	rv_lbl.add_theme_color_override("font_color", Color(0.3, 0.9, 0.9))
	rv_lbl.position = Vector2(400, 10)
	bar.add_child(rv_lbl)

	# -- 金币 --
	var gold_icon := Label.new()
	gold_icon.text = "🪙"
	gold_icon.add_theme_font_size_override("font_size", 22)
	gold_icon.position = Vector2(370, 40)
	bar.add_child(gold_icon)

	var gold_lbl := Label.new()
	gold_lbl.name = "GoldLabel"
	gold_lbl.text = str(main_game.player_gold)
	gold_lbl.add_theme_font_size_override("font_size", 16)
	gold_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	gold_lbl.position = Vector2(400, 42)
	bar.add_child(gold_lbl)

	# -- 掷骰奖励提示 --
	var reward_lbl := Label.new()
	reward_lbl.name = "DiceRewardLabel"
	reward_lbl.text = "🎲 掷骰奖励: 过起点 +50金"
	reward_lbl.add_theme_font_size_override("font_size", 13)
	reward_lbl.add_theme_color_override("font_color", Color(1.0, 0.7, 0.2))
	reward_lbl.position = Vector2(370, 68)
	bar.add_child(reward_lbl)

	# -- 骰子花色历史 --
	var dice_hist := Label.new()
	dice_hist.name = "DiceHistLabel"
	dice_hist.text = "花色记录: "
	dice_hist.add_theme_font_size_override("font_size", 12)
	dice_hist.add_theme_color_override("font_color", Color(0.5, 0.6, 0.7))
	dice_hist.position = Vector2(112, 84)
	bar.add_child(dice_hist)

	# ============ 紧凑属性行（装备词条实时刷新） ============
	var compact_labels: Array[Dictionary] = [
		{ "name": "StatLabel_atk",  "prefix": "⚔", "key": "atk" },
		{ "name": "StatLabel_def",  "prefix": "🛡", "key": "def" },
		{ "name": "StatLabel_hp",   "prefix": "❤", "key": "hp" },
		{ "name": "StatLabel_spd",  "prefix": "👟", "key": "spd" },
		{ "name": "StatLabel_luk",  "prefix": "🍀", "key": "luk" },
		{ "name": "StatLabel_crit", "prefix": "💥", "key": "crit" },
		{ "name": "StatLabel_dodge","prefix": "💨", "key": "dodge" },
		{ "name": "StatLabel_block","prefix": "🛡", "key": "block" },
	]
	var csx: float = 112.0
	for ci in range(compact_labels.size()):
		var cd: Dictionary = compact_labels[ci]
		var cl: Label = Label.new()
		cl.name = cd["name"]
		cl.text = cd["prefix"] + " 0"
		cl.add_theme_font_size_override("font_size", 11)
		cl.add_theme_color_override("font_color", Color(0.6, 0.65, 0.7))
		cl.position = Vector2(csx + ci * 82, 104)
		bar.add_child(cl)

	refresh_compact_stats()

	# ============ 右侧：掷骰点数 + 花色 + 牌型记录 ============
	var sep := VSeparator.new()
	sep.position = Vector2(620, 12)
	sep.size = Vector2(2, 86)
	bar.add_child(sep)

	var dice_title := Label.new()
	dice_title.text = "本次掷骰"
	dice_title.add_theme_font_size_override("font_size", 11)
	dice_title.add_theme_color_override("font_color", Color(0.5, 0.5, 0.6))
	dice_title.position = Vector2(640, 6)
	bar.add_child(dice_title)

	var dice_num := Label.new()
	dice_num.name = "DiceNumLabel"
	dice_num.text = "--"
	dice_num.add_theme_font_size_override("font_size", 36)
	dice_num.add_theme_color_override("font_color", Color(1.0, 0.9, 0.3))
	dice_num.position = Vector2(640, 18)
	dice_num.size = Vector2(60, 42)
	bar.add_child(dice_num)

	var suit_lbl := Label.new()
	suit_lbl.name = "DiceSuitLabel"
	suit_lbl.text = ""
	suit_lbl.add_theme_font_size_override("font_size", 40)
	suit_lbl.position = Vector2(708, 16)
	suit_lbl.size = Vector2(50, 48)
	bar.add_child(suit_lbl)

	var poker_title := Label.new()
	poker_title.text = "牌型记录 (3次结算)"
	poker_title.add_theme_font_size_override("font_size", 11)
	poker_title.add_theme_color_override("font_color", Color(0.5, 0.5, 0.6))
	poker_title.position = Vector2(780, 6)
	bar.add_child(poker_title)

	for i in range(3):
		var slot_bg := ColorRect.new()
		slot_bg.name = "PokerSlotBg" + str(i)
		slot_bg.position = Vector2(780 + i * 115, 20)
		slot_bg.size = Vector2(105, 62)
		slot_bg.color = Color(0.15, 0.15, 0.22)
		bar.add_child(slot_bg)

		var val_lbl := Label.new()
		val_lbl.name = "PokerVal" + str(i)
		val_lbl.text = "-"
		val_lbl.add_theme_font_size_override("font_size", 22)
		val_lbl.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
		val_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		val_lbl.position = Vector2(780 + i * 115, 22)
		val_lbl.size = Vector2(60, 30)
		bar.add_child(val_lbl)

		var suit_s := Label.new()
		suit_s.name = "PokerSuit" + str(i)
		suit_s.text = ""
		suit_s.add_theme_font_size_override("font_size", 22)
		suit_s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		suit_s.position = Vector2(780 + i * 115, 42)
		suit_s.size = Vector2(60, 30)
		bar.add_child(suit_s)

		if i < 2:
			var arrow := Label.new()
			arrow.text = "→"
			arrow.add_theme_font_size_override("font_size", 14)
			arrow.add_theme_color_override("font_color", Color(0.3, 0.3, 0.4))
			arrow.position = Vector2(888 + i * 115, 36)
			bar.add_child(arrow)

	var poker_result := Label.new()
	poker_result.name = "PokerResultLabel"
	poker_result.text = ""
	poker_result.add_theme_font_size_override("font_size", 14)
	poker_result.add_theme_color_override("font_color", Color(1.0, 0.8, 0.2))
	poker_result.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	poker_result.position = Vector2(780, 86)
	poker_result.size = Vector2(350, 20)
	bar.add_child(poker_result)

	main_game.add_child(bar)


func refresh() -> void:
	var lv_lbl: Label = main_game.get_node_or_null("TopBar/LevelLabel") as Label
	if lv_lbl:
		lv_lbl.text = "Lv." + str(main_game.player_level)
	var exp_bar: ProgressBar = main_game.get_node_or_null("TopBar/ExpBar") as ProgressBar
	if exp_bar:
		exp_bar.value = main_game.player_exp
		exp_bar.max_value = main_game.player_exp_max
	var exp_lbl: Label = main_game.get_node_or_null("TopBar/ExpLabel") as Label
	if exp_lbl:
		exp_lbl.text = str(main_game.player_exp) + "/" + str(main_game.player_exp_max)
	var gold_lbl: Label = main_game.get_node_or_null("TopBar/GoldLabel") as Label
	if gold_lbl:
		gold_lbl.text = str(main_game.player_gold)
	var rv_lbl: Label = main_game.get_node_or_null("TopBar/ReviveLabel") as Label
	if rv_lbl:
		rv_lbl.text = str(main_game.player_revive) + "/" + str(main_game.player_max_revive)
	refresh_compact_stats()


func refresh_compact_stats() -> void:
	var ps: Dictionary = main_game._calc_player_stats()
	var keys: Array[String] = ["atk", "def", "hp", "spd", "luk", "crit", "dodge", "block"]
	var prefixes: Array[String] = ["⚔", "🛡", "❤", "👟", "🍀", "💥", "💨", "🛡"]
	var bar: Node = main_game.get_node_or_null("TopBar")
	if not bar:
		return
	for i in range(keys.size()):
		var lbl: Label = bar.get_node_or_null("StatLabel_" + keys[i]) as Label
		if not lbl:
			continue
		var val = ps.get(keys[i], 0)
		var val_str: String = str(val)
		if keys[i] in ["crit", "dodge", "block"]:
			val_str = str(val) + "%"
		lbl.text = prefixes[i] + " " + val_str
		var highlight: bool = false
		match keys[i]:
			"atk", "def", "hp": highlight = (val as int) > 0
			"spd", "luk":        highlight = (val as int) > 0
			"crit", "dodge", "block": highlight = (val as int) > 0
		lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2) if highlight else Color(0.6, 0.65, 0.7))


func refresh_dice_display() -> void:
	var num_lbl: Label = main_game.get_node_or_null("TopBar/DiceNumLabel") as Label
	if num_lbl:
		num_lbl.text = str(main_game.last_dice_roll)
	var suit_lbl: Label = main_game.get_node_or_null("TopBar/DiceSuitLabel") as Label
	if suit_lbl:
		suit_lbl.text = main_game.last_dice_suit
		suit_lbl.add_theme_color_override("font_color", UIUtils.suit_color(main_game.last_dice_suit))


func refresh_poker_slots() -> void:
	for i in range(3):
		var val_lbl: Label = main_game.get_node_or_null("TopBar/PokerVal" + str(i)) as Label
		var suit_lbl: Label = main_game.get_node_or_null("TopBar/PokerSuit" + str(i)) as Label
		if i < main_game.poker_records.size():
			var rec = main_game.poker_records[i] as Dictionary
			if val_lbl:
				val_lbl.text = str(rec["value"])
			if suit_lbl:
				suit_lbl.text = rec["suit"]
				suit_lbl.add_theme_color_override("font_color", UIUtils.suit_color(rec["suit"]))
		else:
			if val_lbl:
				val_lbl.text = "-"
			if suit_lbl:
				suit_lbl.text = ""
				suit_lbl.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))


func check_poker_hand() -> void:
	if main_game.poker_records.size() < 3:
		return

	var vals: Array[int] = []
	var suits_arr: Array[String] = []
	for r in main_game.poker_records:
		vals.append(r["value"] as int)
		suits_arr.append(r["suit"] as String)

	var sorted: Array[int] = vals.duplicate()
	sorted.sort()

	var is_flush: bool = (suits_arr[0] == suits_arr[1] and suits_arr[1] == suits_arr[2])
	var is_straight: bool = (sorted[2] - sorted[1] == 1 and sorted[1] - sorted[0] == 1)

	var count_map: Dictionary = {}
	for v in vals:
		count_map[v] = count_map.get(v, 0) + 1
	var max_count: int = 0
	for c in count_map.values():
		max_count = max(max_count, c as int)

	var hand_name: String = ""
	var multiplier: int = 0

	if is_flush and is_straight:
		hand_name = "同花顺"; multiplier = 10
	elif max_count >= 3:
		hand_name = "三条"; multiplier = 6
	elif is_straight:
		hand_name = "顺子"; multiplier = 4
	elif is_flush:
		hand_name = "同花"; multiplier = 3
	elif max_count >= 2:
		hand_name = "一对"; multiplier = 2

	var result_lbl: Label = main_game.get_node_or_null("TopBar/PokerResultLabel") as Label
	if multiplier > 0:
		var bonus: int = main_game.player_level * (randi() % 41 + 10) * multiplier
		main_game.player_gold += bonus
		if result_lbl:
			result_lbl.text = hand_name + "！+" + str(bonus) + "金 (×" + str(multiplier) + ")"
	else:
		if result_lbl:
			result_lbl.text = ""
