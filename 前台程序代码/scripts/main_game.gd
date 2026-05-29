extends Control

## ============================================================
## 大勇者 - 主游戏界面 v0.3
## 三部分：顶部属性栏 / 中部大地图 / 底部按钮组
## ============================================================

# -- 格子类型 --
const GRID_TYPES = [
	{ "icon": "🏠", "name": "勇者之家",  "clr": Color(0.3, 0.5, 0.3) },
	{ "icon": "⚔️", "name": "战斗格",    "clr": Color(0.6, 0.2, 0.2) },
	{ "icon": "🗡️", "name": "精英战斗",  "clr": Color(0.5, 0.1, 0.3) },
	{ "icon": "🏆", "name": "挑战格",    "clr": Color(0.7, 0.5, 0.1) },
	{ "icon": "🛌", "name": "休息格",    "clr": Color(0.2, 0.5, 0.5) },
	{ "icon": "🎁", "name": "宝箱格",    "clr": Color(0.7, 0.6, 0.1) },
	{ "icon": "🔨", "name": "锻造格",    "clr": Color(0.5, 0.3, 0.1) },
	{ "icon": "🎲", "name": "命运格",    "clr": Color(0.4, 0.2, 0.6) },
	{ "icon": "🏛", "name": "神祇格",    "clr": Color(0.6, 0.6, 0.1) },
	{ "icon": "🔮", "name": "合成格",    "clr": Color(0.3, 0.2, 0.7) },
	{ "icon": "⚡", "name": "闪电格",    "clr": Color(0.8, 0.8, 0.1) },
	{ "icon": "💀", "name": "Boss格",    "clr": Color(0.6, 0.0, 0.0) },
	{ "icon": "🟩", "name": "空地",      "clr": Color(0.3, 0.5, 0.2) },
	{ "icon": "💰", "name": "空地2",     "clr": Color(0.3, 0.5, 0.2) },
]

const DICE_FACES := {
	0: "",
	1: " ⬜ ",
	2: "⬜ ⬜",
	3: "⬜⬜⬜",
	4: "⬜⬜\n⬜⬜",
	5: "⬜⬜\n ⬜ \n⬜⬜",
	6: "⬜⬜\n⬜⬜\n⬜⬜",
}

# -- 玩家状态 --
var player_name: String = "勇者"
var player_level: int = 1
var player_exp: int = 0
var player_exp_max: int = 100
var player_gold: int = 0
var player_revive: int = 3
var player_max_revive: int = 3
var player_grid_index: int = 0
var map_total_grids: int = 28
var map_grids: Array[int] = []
var last_dice_roll: int = 0
var last_dice_history: Array[int] = []

const VISIBLE_BEFORE: int = 2
const VISIBLE_AFTER: int  = 4


## ============ _ready ============
func _ready() -> void:
	anchor_right  = 1.0
	anchor_bottom = 1.0

	_build_top_bar()
	_build_map_area()
	_build_bottom_bar()
	_generate_mock_map()
	_refresh_grid_display()

	# 信号
	$BottomBar/DiceRollBtn.pressed.connect(_on_dice_roll)
	$BottomBar/BagBtn.pressed.connect(_on_bag_pressed)
	$BottomBar/SkillBtn.pressed.connect(_on_skill_pressed)
	$BottomBar/LogBtn.pressed.connect(_on_log_pressed)
	$BottomBar/SettingsBtn.pressed.connect(_on_settings_pressed)


## ============================================================
## 第一部分 — 顶部角色属性栏 (h=110)
##   头像 | 名字/等级 | 经验条 | 复活币/金币 | 掷骰奖励 | 骰子花色
## ============================================================
func _build_top_bar() -> void:
	var bar := Panel.new()
	bar.name = "TopBar"
	bar.position = Vector2(0, 0)
	bar.size = Vector2(1280, 110)
	_panel_style(bar, Color(0.10, 0.10, 0.14))

	# -- 角色头像 (88x88) --
	var avatar_bg := ColorRect.new()
	avatar_bg.name = "AvatarBg"
	avatar_bg.position = Vector2(8, 8)
	avatar_bg.size = Vector2(94, 94)
	avatar_bg.color = Color(0.18, 0.18, 0.28)
	bar.add_child(avatar_bg)

	var avatar_tex := load("res://assets/主角.bmp")
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

	# -- 名字 --
	var name_lbl := Label.new()
	name_lbl.name = "NameLabel"
	name_lbl.text = player_name
	name_lbl.add_theme_font_size_override("font_size", 24)
	name_lbl.add_theme_color_override("font_color", Color.WHITE)
	name_lbl.position = Vector2(112, 8)
	bar.add_child(name_lbl)

	# -- 等级 --
	var lv_lbl := Label.new()
	lv_lbl.name = "LevelLabel"
	lv_lbl.text = "Lv." + str(player_level)
	lv_lbl.add_theme_font_size_override("font_size", 16)
	lv_lbl.add_theme_color_override("font_color", Color(0.6, 0.8, 1.0))
	lv_lbl.position = Vector2(112, 34)
	bar.add_child(lv_lbl)

	# -- 经验条 --
	var exp_bar := ProgressBar.new()
	exp_bar.name = "ExpBar"
	exp_bar.position = Vector2(112, 58)
	exp_bar.size = Vector2(260, 16)
	exp_bar.value = player_exp
	exp_bar.max_value = player_exp_max
	_bar_style(exp_bar, Color(0.15, 0.35, 0.6))
	bar.add_child(exp_bar)

	var exp_lbl := Label.new()
	exp_lbl.name = "ExpLabel"
	exp_lbl.text = str(player_exp) + "/" + str(player_exp_max)
	exp_lbl.add_theme_font_size_override("font_size", 10)
	exp_lbl.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))
	exp_lbl.position = Vector2(117, 59)
	exp_lbl.size = Vector2(250, 14)
	exp_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bar.add_child(exp_lbl)

	# -- 复活币 --
	var rv_row_y := 8
	var rv_icon := Label.new()
	rv_icon.text = "💀"
	rv_icon.add_theme_font_size_override("font_size", 24)
	rv_icon.position = Vector2(410, rv_row_y)
	bar.add_child(rv_icon)

	var rv_lbl := Label.new()
	rv_lbl.name = "ReviveLabel"
	rv_lbl.text = str(player_revive) + "/" + str(player_max_revive)
	rv_lbl.add_theme_font_size_override("font_size", 18)
	rv_lbl.add_theme_color_override("font_color", Color(0.3, 0.9, 0.9))
	rv_lbl.position = Vector2(444, rv_row_y + 4)
	bar.add_child(rv_lbl)

	# -- 金币 --
	var gold_icon := Label.new()
	gold_icon.text = "🪙"
	gold_icon.add_theme_font_size_override("font_size", 24)
	gold_icon.position = Vector2(410, 42)
	bar.add_child(gold_icon)

	var gold_lbl := Label.new()
	gold_lbl.name = "GoldLabel"
	gold_lbl.text = "0"
	gold_lbl.add_theme_font_size_override("font_size", 18)
	gold_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	gold_lbl.position = Vector2(444, 46)
	bar.add_child(gold_lbl)

	# -- 掷骰奖励系统（大地图规则新增）--
	var reward_lbl := Label.new()
	reward_lbl.name = "DiceRewardLabel"
	reward_lbl.text = "🎲 掷骰奖励: 过起点 +50金"
	reward_lbl.add_theme_font_size_override("font_size", 14)
	reward_lbl.add_theme_color_override("font_color", Color(1.0, 0.7, 0.2))
	reward_lbl.position = Vector2(410, 78)
	bar.add_child(reward_lbl)

	# -- 骰子花色历史 --
	var dice_hist := Label.new()
	dice_hist.name = "DiceHistLabel"
	dice_hist.text = "花色记录: "
	dice_hist.add_theme_font_size_override("font_size", 13)
	dice_hist.add_theme_color_override("font_color", Color(0.6, 0.7, 0.8))
	dice_hist.position = Vector2(112, 82)
	bar.add_child(dice_hist)

	add_child(bar)


## ============================================================
## 第二部分 — 中部大地图 (y=112, h=400)
##   背景 + 主角图像 + 格子（在底部，比"点数: ?"高）
## ============================================================
func _build_map_area() -> void:
	var area := Panel.new()
	area.name = "MapArea"
	area.position = Vector2(0, 112)
	area.size = Vector2(1280, 400)
	_panel_style(area, Color(0.06, 0.07, 0.09))

	# -- 场景背景提示 --
	var bg_hint := Label.new()
	bg_hint.text = "（场景背景区域）"
	bg_hint.add_theme_font_size_override("font_size", 14)
	bg_hint.add_theme_color_override("font_color", Color(0.2, 0.2, 0.25))
	bg_hint.position = Vector2(540, 100)
	area.add_child(bg_hint)

	# -- 主角在格子上的图像 --
	var hero_tex := load("res://assets/主角.bmp")
	if hero_tex:
		var hero := TextureRect.new()
		hero.name = "HeroOnMap"
		hero.position = Vector2(560, 130)
		hero.size = Vector2(160, 160)
		hero.texture = hero_tex
		hero.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		hero.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		area.add_child(hero)
	else:
		var fallback := Label.new()
		fallback.name = "HeroFallback"
		fallback.text = "🚶"
		fallback.add_theme_font_size_override("font_size", 72)
		fallback.position = Vector2(600, 170)
		area.add_child(fallback)

	# -- 地图格子行（在 MapArea 底部，比底部"点数"高） --
	const G_W := 92
	const G_H := 88
	var total_w := 7 * G_W
	var start_x := (1280.0 - float(total_w)) / 2.0
	var grid_y := 290  # 在 MapArea 内部 y，格子底部大约在 378，留空间给位置标签
	var slot_names := ["PrevGrid2", "PrevGrid1", "CurrentGrid", "NextGrid1", "NextGrid2", "NextGrid3", "NextGrid4"]

	for i in range(7):
		var grid := Panel.new()
		grid.name = slot_names[i]
		grid.position = Vector2(start_x + i * G_W, grid_y)
		grid.size = Vector2(G_W - 4, G_H)

		var bg := ColorRect.new()
		bg.name = "BG"
		bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		grid.add_child(bg)

		var icon := Label.new()
		icon.name = "Icon"
		icon.add_theme_font_size_override("font_size", 30)
		icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		icon.position = Vector2(0, 8)
		icon.size = Vector2(G_W - 4, 36)
		grid.add_child(icon)

		var name_lbl := Label.new()
		name_lbl.name = "Name"
		name_lbl.add_theme_font_size_override("font_size", 9)
		name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_lbl.position = Vector2(0, G_H - 22)
		name_lbl.size = Vector2(G_W - 4, 14)
		grid.add_child(name_lbl)

		area.add_child(grid)

	# 位置计数器
	var pos_lbl := Label.new()
	pos_lbl.name = "GridPosLabel"
	pos_lbl.text = "位置: 0/" + str(map_total_grids)
	pos_lbl.add_theme_font_size_override("font_size", 10)
	pos_lbl.add_theme_color_override("font_color", Color(0.35, 0.35, 0.4))
	pos_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pos_lbl.position = Vector2(0, grid_y + G_H + 4)
	pos_lbl.size = Vector2(1280, 14)
	area.add_child(pos_lbl)

	add_child(area)


## ============================================================
## 第三部分 — 底部功能按钮组 (y=514, h=86)
##   "点数: ?" 在上 + 5个功能按钮在下
## ============================================================
func _build_bottom_bar() -> void:
	var bar := Panel.new()
	bar.name = "BottomBar"
	bar.position = Vector2(0, 514)
	bar.size = Vector2(1280, 86)
	_panel_style(bar, Color(0.10, 0.10, 0.16))

	# -- 点数显示（顶部） --
	var result_lbl := Label.new()
	result_lbl.name = "DiceResultLabel"
	result_lbl.text = "点数: ?"
	result_lbl.add_theme_font_size_override("font_size", 28)
	result_lbl.add_theme_color_override("font_color", Color(1.0, 0.9, 0.3))
	result_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_lbl.position = Vector2(0, 2)
	result_lbl.size = Vector2(1280, 32)
	bar.add_child(result_lbl)

	# -- 功能按钮 --
	var btn_data := [
		{ "name": "DiceRollBtn",  "text": "🎲 掷骰",  "x":  80 },
		{ "name": "BagBtn",       "text": "🎒 背包",  "x": 340 },
		{ "name": "SkillBtn",     "text": "⚡ 技能",  "x": 560 },
		{ "name": "LogBtn",       "text": "📋 日志",  "x": 780 },
		{ "name": "SettingsBtn",  "text": "⚙️ 设置",  "x": 1000 },
	]
	for b in btn_data:
		var btn := Button.new()
		btn.name = b["name"]
		btn.text = b["text"]
		btn.position = Vector2(b["x"], 42)
		btn.size = Vector2(200, 36)
		_btn_style(btn, Color(0.18, 0.22, 0.34))
		bar.add_child(btn)

	add_child(bar)


## ============================================================
## 骰子花色弹窗（显示 1 秒后自动消失）
## ============================================================
func _show_dice_popup(roll: int) -> void:
	# 先移除旧弹窗
	var old_popup := get_node_or_null("DicePopup")
	if old_popup:
		old_popup.queue_free()

	var dice_face: String = DICE_FACES[roll]
	var popup := Panel.new()
	popup.name = "DicePopup"
	popup.position = Vector2(480, 200)
	popup.size = Vector2(320, 220)
	_panel_style(popup, Color(0.12, 0.12, 0.20, 0.94))

	var label := Label.new()
	label.text = dice_face
	label.add_theme_font_size_override("font_size", 56)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.position = Vector2(20, 10)
	label.size = Vector2(280, 200)
	popup.add_child(label)

	add_child(popup)

	# 1 秒后自动移除
	var timer := get_tree().create_timer(1.0)
	timer.timeout.connect(func():
		if popup and is_instance_valid(popup):
			popup.queue_free()
	)


## ============================================================
## 掷骰逻辑
## ============================================================
func _on_dice_roll() -> void:
	last_dice_roll = randi() % 6 + 1

	# 花色弹窗（显示 1 秒）
	_show_dice_popup(last_dice_roll)

	# 更新点数显示
	var result_lbl: Label = $BottomBar/DiceResultLabel as Label
	if result_lbl:
		result_lbl.text = "点数: " + str(last_dice_roll)

	# 骰子花色历史记录（最近6次）
	last_dice_history.append(last_dice_roll)
	while last_dice_history.size() > 6:
		last_dice_history.pop_front()
	var hist_text := "花色记录: "
	for d in last_dice_history:
		hist_text += _dice_suit(d) + " "
	var hist_lbl: Label = $TopBar/DiceHistLabel as Label
	if hist_lbl:
		hist_lbl.text = hist_text

	# 前进
	var prev_idx := player_grid_index
	player_grid_index = (player_grid_index + last_dice_roll) % map_total_grids

	# 过起点奖励
	var reward_lbl: Label = $TopBar/DiceRewardLabel as Label
	if prev_idx + last_dice_roll >= map_total_grids:
		player_gold += 50
		if reward_lbl:
			reward_lbl.text = "🎲 掷骰奖励: 过起点 +50金!"
	else:
		# 普通奖励提示（按点数）
		var bonus := last_dice_roll * 2
		player_gold += bonus
		if reward_lbl:
			reward_lbl.text = "🎲 掷骰奖励: 点数" + str(last_dice_roll) + " +" + str(bonus) + "金"

	_refresh_top_bar()
	_refresh_grid_display()


## ============================================================
## 骰子花色符号
## ============================================================
func _dice_suit(n: int) -> String:
	match n:
		1: return "⚀"
		2: return "⚁"
		3: return "⚂"
		4: return "⚃"
		5: return "⚄"
		6: return "⚅"
	return "?"


## ============================================================
## 刷新
## ============================================================
func _refresh_top_bar() -> void:
	var gold_lbl: Label = $TopBar/GoldLabel as Label
	if gold_lbl:
		gold_lbl.text = str(player_gold)
	var rv_lbl: Label = $TopBar/ReviveLabel as Label
	if rv_lbl:
		rv_lbl.text = str(player_revive) + "/" + str(player_max_revive)
	var lv_lbl: Label = $TopBar/LevelLabel as Label
	if lv_lbl:
		lv_lbl.text = "Lv." + str(player_level)
	var exp_bar: ProgressBar = $TopBar/ExpBar as ProgressBar
	if exp_bar:
		exp_bar.value = player_exp
		exp_bar.max_value = player_exp_max
	var exp_lbl: Label = $TopBar/ExpLabel as Label
	if exp_lbl:
		exp_lbl.text = str(player_exp) + "/" + str(player_exp_max)


func _refresh_grid_display() -> void:
	var area := $MapArea
	var idx := player_grid_index
	var offsets := [-2, -1, 0, 1, 2, 3, 4]
	var slot_names := ["PrevGrid2", "PrevGrid1", "CurrentGrid", "NextGrid1", "NextGrid2", "NextGrid3", "NextGrid4"]

	for i in range(7):
		var grid_idx: int = idx + offsets[i]
		var panel: Panel = area.get_node(slot_names[i]) as Panel
		if not panel:
			continue

		var info := _get_grid_info(grid_idx)
		var bg: ColorRect = panel.get_node("BG") as ColorRect
		var icon_lbl: Label = panel.get_node("Icon") as Label
		var name_lbl: Label = panel.get_node("Name") as Label

		bg.color = info["clr"].darkened(0.65) if i != 3 else info["clr"]

		# 当前格高亮
		if i == 3:
			var hl := StyleBoxFlat.new()
			hl.bg_color = info["clr"]
			hl.border_width_left = 3
			hl.border_width_right = 3
			hl.border_width_top = 3
			hl.border_width_bottom = 3
			hl.border_color = Color(1.0, 1.0, 0.2, 0.9)
			panel.add_theme_stylebox_override("panel", hl)

		icon_lbl.text = info["icon"]
		name_lbl.text = info["name"] + "#" + str(grid_idx)

	var pos_lbl: Label = area.get_node("GridPosLabel") as Label
	if pos_lbl:
		pos_lbl.text = "位置: " + str(idx) + "/" + str(map_total_grids)


func _get_grid_info(index: int) -> Dictionary:
	var wrapped := index % map_total_grids
	if wrapped < 0:
		wrapped += map_total_grids
	return GRID_TYPES[map_grids[wrapped]]


func _generate_mock_map() -> void:
	map_grids.clear()
	map_grids.append(0)  # 勇者之家
	for i in range(1, map_total_grids):
		map_grids.append(1 + (i % 13))


## ============ 按钮回调 ============
func _on_bag_pressed()     -> void: print("[主界面] 打开背包")
func _on_skill_pressed()   -> void: print("[主界面] 打开技能")
func _on_log_pressed()     -> void: print("[主界面] 打开日志")
func _on_settings_pressed()-> void: print("[主界面] 打开设置")


## ============ 样式工具 ============
func _panel_style(node: Panel, clr: Color) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = clr
	sb.border_width_left   = 1
	sb.border_width_right  = 1
	sb.border_width_top    = 1
	sb.border_width_bottom = 1
	sb.border_color = Color(0.35, 0.35, 0.45, 0.6)
	node.add_theme_stylebox_override("panel", sb)

func _bar_style(node: ProgressBar, clr: Color) -> void:
	var bg := StyleBoxFlat.new()
	bg.bg_color = clr.darkened(0.3)
	bg.border_width_left = 1; bg.border_width_right = 1
	bg.border_width_top = 1; bg.border_width_bottom = 1
	bg.border_color = Color(0.35, 0.35, 0.45)
	node.add_theme_stylebox_override("background", bg)
	var fill := StyleBoxFlat.new()
	fill.bg_color = clr
	node.add_theme_stylebox_override("fill", fill)

func _btn_style(btn: Button, clr: Color) -> void:
	var n := StyleBoxFlat.new()
	n.bg_color = clr
	n.border_width_left = 2; n.border_width_right = 2
	n.border_width_top = 2; n.border_width_bottom = 2
	n.border_color = Color(0.5, 0.5, 0.6, 0.7)
	n.set_corner_radius_all(6)
	btn.add_theme_stylebox_override("normal", n)
	var h := n.duplicate() as StyleBoxFlat
	h.bg_color = clr.lightened(0.15)
	btn.add_theme_stylebox_override("hover", h)
	var p := n.duplicate() as StyleBoxFlat
	p.bg_color = clr.darkened(0.15)
	btn.add_theme_stylebox_override("pressed", p)
	btn.add_theme_font_size_override("font_size", 16)
	btn.add_theme_color_override("font_color", Color.WHITE)
