extends Control

## ============================================================
## 大勇者 - 主游戏界面 v0.5
## 菱形格子 + 主角叠格子 + 单行按钮 + 自动挂机
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

# 扑克牌花色
const SUITS := ["♠", "♣", "♥", "♦"]
const SUIT_COLORS := {
	"♠": Color(0.75, 0.78, 0.82),
	"♣": Color(0.75, 0.78, 0.82),
	"♥": Color(1.0, 0.15, 0.15),
	"♦": Color(1.0, 0.15, 0.15),
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
var last_dice_suit: String = ""
var last_dice_history: Array[int] = []
var poker_records: Array[Dictionary] = []
var auto_play_enabled: bool = false
var _current_slot: int = -1  # 当前存档槽位

const VISIBLE_BEFORE: int = 2
const VISIBLE_AFTER: int  = 4

const GridTileCls = preload("res://scripts/grid_tile.gd")

# 菱形格子尺寸
const TILE_W: float = 130.0
const TILE_H: float = 65.0
const TILE_SPACING: float = 55.0  # 中心间距（重叠10px）
const TILE_COUNT: int = 7
const TILE_Y: float = 310.0  # 格子在 MapArea 内的 y 坐标


## ============ _ready ============
func _ready() -> void:
	anchor_right  = 1.0
	anchor_bottom = 1.0

	# 从选择界面传来的存档数据
	if has_meta("save_slot") and has_meta("save_data"):
		_current_slot = get_meta("save_slot") as int
		var data: Dictionary = get_meta("save_data") as Dictionary
		_load_from_save_data(data)

	_build_top_bar()
	_build_map_area()
	_build_bottom_bar()
	if map_grids.is_empty():
		_generate_mock_map()
	_refresh_grid_display()

	# 信号
	$BottomBar/DiceRollBtn.pressed.connect(_on_dice_roll)
	$BottomBar/BagBtn.pressed.connect(_on_bag_pressed)
	$BottomBar/SkillBtn.pressed.connect(_on_skill_pressed)
	$BottomBar/LogBtn.pressed.connect(_on_log_pressed)
	$BottomBar/SettingsBtn.pressed.connect(_on_settings_pressed)
	$MapArea/AutoPlayCheck.toggled.connect(_on_auto_play_toggled)


func _sm():
	return get_node_or_null("/root/SaveManager")


## ============================================================
## 第一部分 — 顶部属性栏
## ============================================================
func _build_top_bar() -> void:
	var bar := Panel.new()
	bar.name = "TopBar"
	bar.position = Vector2(0, 0)
	bar.size = Vector2(1280, 110)
	_panel_style(bar, Color(0.10, 0.10, 0.14))

	# -- 角色头像 --
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

	# -- 名字 + 等级 --
	var name_lbl := Label.new()
	name_lbl.name = "NameLabel"
	name_lbl.text = player_name
	name_lbl.add_theme_font_size_override("font_size", 24)
	name_lbl.add_theme_color_override("font_color", Color.WHITE)
	name_lbl.position = Vector2(112, 8)
	bar.add_child(name_lbl)

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
	exp_bar.size = Vector2(240, 16)
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
	rv_lbl.text = str(player_revive) + "/" + str(player_max_revive)
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
	gold_lbl.text = str(player_gold)
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

	add_child(bar)


## ============================================================
## 第二部分 — 中部大地图（菱形格子 + 主角叠加）
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
	bg_hint.position = Vector2(540, 120)
	area.add_child(bg_hint)

	# -- 菱形地图格子 --
	var total_span := (TILE_COUNT - 1) * TILE_SPACING
	var start_x := (1280.0 - total_span) / 2.0
	var slot_names := ["PrevGrid2", "PrevGrid1", "CurrentGrid", "NextGrid1", "NextGrid2", "NextGrid3", "NextGrid4"]

	for i in range(TILE_COUNT):
		var tile = GridTileCls.new()
		tile.name = slot_names[i]
		tile.position = Vector2(start_x + i * TILE_SPACING - TILE_W / 2.0, TILE_Y)
		tile.size = Vector2(TILE_W, TILE_H)
		tile.set_label_positions(10, TILE_H - 24)
		area.add_child(tile)

	# -- 主角图像（放在格子上方，最后添加=最上层） --
	var hero_tex := load("res://assets/主角.bmp")
	if hero_tex:
		var hero := TextureRect.new()
		hero.name = "HeroOnMap"
		hero.texture = hero_tex
		hero.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		hero.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		hero.size = Vector2(120, 120)
		area.add_child(hero)
		_position_hero_on_tile(hero, 3)  # 初始在当前格
	else:
		var fallback := Label.new()
		fallback.name = "HeroFallback"
		fallback.text = "🚶"
		fallback.add_theme_font_size_override("font_size", 64)
		fallback.position = Vector2(608, TILE_Y - 80)
		area.add_child(fallback)

	# -- 位置计数 --
	var pos_lbl := Label.new()
	pos_lbl.name = "GridPosLabel"
	pos_lbl.text = "位置: 0/" + str(map_total_grids)
	pos_lbl.add_theme_font_size_override("font_size", 10)
	pos_lbl.add_theme_color_override("font_color", Color(0.35, 0.35, 0.4))
	pos_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pos_lbl.position = Vector2(0, TILE_Y + TILE_H + 10)
	pos_lbl.size = Vector2(1280, 14)
	area.add_child(pos_lbl)

	# -- 右上角：自动挂机勾选 --
	var auto_check := CheckBox.new()
	auto_check.name = "AutoPlayCheck"
	auto_check.text = "自动挂机"
	auto_check.add_theme_font_size_override("font_size", 14)
	auto_check.add_theme_color_override("font_color", Color(0.7, 0.9, 0.7))
	auto_check.button_pressed = false
	auto_check.position = Vector2(1120, 10)
	area.add_child(auto_check)

	add_child(area)


## 将主角图像定位到指定菱形格子正上方
func _position_hero_on_tile(hero: TextureRect, tile_index: int) -> void:
	var total_span := (TILE_COUNT - 1) * TILE_SPACING
	var start_x := (1280.0 - total_span) / 2.0
	var tile_center_x := start_x + tile_index * TILE_SPACING
	hero.position = Vector2(tile_center_x - hero.size.x / 2.0, TILE_Y - hero.size.y + 25)


## ============================================================
## 第三部分 — 底部按钮组（单行：背包 技能 | 掷骰 | 日志 设置）
## ============================================================
func _build_bottom_bar() -> void:
	var bar := Panel.new()
	bar.name = "BottomBar"
	bar.position = Vector2(0, 514)
	bar.size = Vector2(1280, 86)
	_panel_style(bar, Color(0.10, 0.10, 0.16))

	# 单行布局：4小按钮(w=170) + 1大按钮(w=260) = 940，剩余 340 / 6间隔 = 57
	const SMALL_W := 170
	const SMALL_H := 38
	const DICE_W := 260
	const DICE_H := 42
	const GAP := 57

	var dice_x := GAP + SMALL_W + GAP + SMALL_W + GAP  # = 57+170+57+170+57 = 511
	var btn_y := (86.0 - SMALL_H) / 2.0
	var dice_y := (86.0 - DICE_H) / 2.0

	# -- 掷骰大按钮（居中） --
	var dice_btn := Button.new()
	dice_btn.name = "DiceRollBtn"
	dice_btn.text = "🎲  掷  骰"
	dice_btn.position = Vector2(dice_x, dice_y)
	dice_btn.size = Vector2(DICE_W, DICE_H)
	_btn_style(dice_btn, Color(0.15, 0.28, 0.50))
	dice_btn.add_theme_font_size_override("font_size", 22)
	bar.add_child(dice_btn)

	# -- 功能按钮（左侧2个 + 右侧2个） --
	var btn_defs := [
		{ "name": "BagBtn",       "text": "🎒 背包",  "x": GAP },
		{ "name": "SkillBtn",     "text": "⚡ 技能",  "x": GAP + SMALL_W + GAP },
		{ "name": "LogBtn",       "text": "📋 日志",  "x": dice_x + DICE_W + GAP },
		{ "name": "SettingsBtn",  "text": "🏠 主界面",  "x": dice_x + DICE_W + GAP + SMALL_W + GAP },
	]
	for b in btn_defs:
		var btn := Button.new()
		btn.name = b["name"]
		btn.text = b["text"]
		btn.position = Vector2(b["x"], btn_y)
		btn.size = Vector2(SMALL_W, SMALL_H)
		_btn_style(btn, Color(0.18, 0.22, 0.34))
		btn.add_theme_font_size_override("font_size", 16)
		bar.add_child(btn)

	add_child(bar)


## ============================================================
## 自动挂机
## ============================================================
func _on_auto_play_toggled(pressed: bool) -> void:
	auto_play_enabled = pressed
	if pressed:
		# 启动自动掷骰计时器
		_start_auto_timer()
	else:
		# 停止计时器
		_stop_auto_timer()


func _start_auto_timer() -> void:
	var timer := get_node_or_null("AutoPlayTimer") as Timer
	if not timer:
		timer = Timer.new()
		timer.name = "AutoPlayTimer"
		timer.one_shot = true
		timer.timeout.connect(_on_auto_dice_roll)
		add_child(timer)
	timer.start(1.5)


func _stop_auto_timer() -> void:
	var timer := get_node_or_null("AutoPlayTimer") as Timer
	if timer:
		timer.stop()


func _on_auto_dice_roll() -> void:
	if not auto_play_enabled:
		return
	_on_dice_roll()


## ============================================================
## 从存档数据恢复状态
## ============================================================
func _load_from_save_data(data: Dictionary) -> void:
	if data.is_empty():
		return
	player_name = data.get("character_name", "勇者")
	player_level = data.get("level", 1)
	player_exp = data.get("exp", 0)
	player_exp_max = data.get("exp_max", 100)
	player_gold = data.get("gold", 0)
	player_revive = data.get("revive_coins", 3)
	player_grid_index = data.get("grid_index", 0)
	map_total_grids = data.get("map_total_grids", 28)
	map_grids.clear()
	for item in data.get("map_grids", []):
		map_grids.append(int(item))
	last_dice_history.clear()
	for item in data.get("dice_history", []):
		last_dice_history.append(int(item))
	poker_records = data.get("poker_records", []) as Array[Dictionary]
	_refresh_poker_slots()


## ============================================================
## 构建存档数据
## ============================================================
func _build_save_data() -> Dictionary:
	return {
		"character_name": player_name,
		"level": player_level,
		"exp": player_exp,
		"exp_max": player_exp_max,
		"gold": player_gold,
		"revive_coins": player_revive,
		"grid_index": player_grid_index,
		"map_total_grids": map_total_grids,
		"map_grids": map_grids,
		"dice_history": last_dice_history,
		"poker_records": poker_records,
	}


## ============================================================
## 掷骰逻辑
## ============================================================
func _on_dice_roll() -> void:
	last_dice_roll = randi() % 6 + 1
	last_dice_suit = SUITS[randi() % 4]

	_refresh_dice_display()

	var record := { "value": last_dice_roll, "suit": last_dice_suit }
	poker_records.append(record)
	_refresh_poker_slots()

	_show_dice_popup(last_dice_roll, last_dice_suit)

	last_dice_history.append(last_dice_roll)
	while last_dice_history.size() > 6:
		last_dice_history.pop_front()
	var hist_text := "花色记录: "
	for d in last_dice_history:
		hist_text += str(d) + " "
	var hist_lbl: Label = $TopBar/DiceHistLabel as Label
	if hist_lbl:
		hist_lbl.text = hist_text

	var prev_idx := player_grid_index
	player_grid_index = (player_grid_index + last_dice_roll) % map_total_grids

	var reward_lbl: Label = $TopBar/DiceRewardLabel as Label
	if prev_idx + last_dice_roll >= map_total_grids:
		player_gold += 50
		if reward_lbl:
			reward_lbl.text = "🎲 掷骰奖励: 过起点 +50金!"

	_check_poker_hand()

	_refresh_top_bar()
	_refresh_grid_display()

	# 自动保存
	_auto_save()

	# 自动挂机：继续下一次掷骰
	if auto_play_enabled:
		_start_auto_timer()


func _auto_save() -> void:
	if _current_slot < 0:
		return
	var sm = _sm()
	if sm:
		sm.save_game(_current_slot, _build_save_data())


## ============================================================
## 扑克牌牌型检测
## ============================================================
func _check_poker_hand() -> void:
	if poker_records.size() < 3:
		return

	var vals: Array[int] = []
	var suits_arr: Array[String] = []
	for r in poker_records:
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

	var result_lbl: Label = $TopBar/PokerResultLabel as Label
	if multiplier > 0:
		var bonus := player_level * (randi() % 41 + 10) * multiplier
		player_gold += bonus
		if result_lbl:
			result_lbl.text = hand_name + "！+" + str(bonus) + "金 (×" + str(multiplier) + ")"
	else:
		if result_lbl:
			result_lbl.text = "未成牌型"

	poker_records.clear()


## ============================================================
## 刷新
## ============================================================
func _refresh_dice_display() -> void:
	var num_lbl: Label = $TopBar/DiceNumLabel as Label
	if num_lbl:
		num_lbl.text = str(last_dice_roll)
	var suit_lbl: Label = $TopBar/DiceSuitLabel as Label
	if suit_lbl:
		suit_lbl.text = last_dice_suit
		suit_lbl.add_theme_color_override("font_color", _suit_color(last_dice_suit))


func _refresh_poker_slots() -> void:
	for i in range(3):
		var val_lbl: Label = $TopBar.get_node("PokerVal" + str(i)) as Label
		var suit_lbl: Label = $TopBar.get_node("PokerSuit" + str(i)) as Label
		if i < poker_records.size():
			var rec := poker_records[i]
			if val_lbl:
				val_lbl.text = str(rec["value"])
			if suit_lbl:
				suit_lbl.text = rec["suit"]
				suit_lbl.add_theme_color_override("font_color", _suit_color(rec["suit"]))
		else:
			if val_lbl:
				val_lbl.text = "-"
			if suit_lbl:
				suit_lbl.text = ""
				suit_lbl.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))


func _suit_color(s: String) -> Color:
	return SUIT_COLORS.get(s, Color(0.8, 0.8, 0.8))


func _refresh_top_bar() -> void:
	var gold_lbl: Label = $TopBar/GoldLabel as Label
	if gold_lbl:
		gold_lbl.text = str(player_gold)
	var rv_lbl: Label = $TopBar/ReviveLabel as Label
	if rv_lbl:
		rv_lbl.text = str(player_revive) + "/" + str(player_max_revive)


func _refresh_grid_display() -> void:
	var area := $MapArea
	var idx := player_grid_index
	var offsets := [-2, -1, 0, 1, 2, 3, 4]
	var slot_names := ["PrevGrid2", "PrevGrid1", "CurrentGrid", "NextGrid1", "NextGrid2", "NextGrid3", "NextGrid4"]

	for i in range(TILE_COUNT):
		var grid_idx: int = idx + offsets[i]
		var tile = area.get_node(slot_names[i])
		if not tile:
			continue

		var info := _get_grid_info(grid_idx)
		var is_current := (i == 3)
		var clr: Color = info["clr"]
		var fill: Color = clr if is_current else clr.darkened(0.55)
		var border: Color = Color(1.0, 1.0, 0.2, 0.9) if is_current else Color(0.5, 0.5, 0.6, 0.5)
		tile.setup(info["icon"], info["name"] + "#" + str(grid_idx), fill, border)

	# 主角位置更新
	var hero: TextureRect = area.get_node_or_null("HeroOnMap") as TextureRect
	if hero:
		_position_hero_on_tile(hero, 3)

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
	map_grids.append(0)
	for i in range(1, map_total_grids):
		map_grids.append(1 + (i % 13))


## ============================================================
## 骰子花色弹窗（1秒消失）
## ============================================================
func _show_dice_popup(roll: int, suit: String) -> void:
	var old_popup := get_node_or_null("DicePopup")
	if old_popup:
		old_popup.queue_free()

	var popup := Panel.new()
	popup.name = "DicePopup"
	popup.position = Vector2(500, 170)
	popup.size = Vector2(280, 180)
	_panel_style(popup, Color(0.12, 0.12, 0.20, 0.94))

	var num_label := Label.new()
	num_label.text = str(roll)
	num_label.add_theme_font_size_override("font_size", 56)
	num_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.3))
	num_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	num_label.position = Vector2(20, 20)
	num_label.size = Vector2(120, 60)
	popup.add_child(num_label)

	var suit_label := Label.new()
	suit_label.text = suit
	suit_label.add_theme_font_size_override("font_size", 56)
	suit_label.add_theme_color_override("font_color", _suit_color(suit))
	suit_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	suit_label.position = Vector2(140, 20)
	suit_label.size = Vector2(120, 60)
	popup.add_child(suit_label)

	add_child(popup)

	var timer := get_tree().create_timer(1.0)
	timer.timeout.connect(func():
		if popup and is_instance_valid(popup):
			popup.queue_free()
	)


## ============ 按钮回调 ============
func _on_bag_pressed()     -> void: print("[主界面] 打开背包")
func _on_skill_pressed()   -> void: print("[主界面] 打开技能")
func _on_log_pressed()     -> void: print("[主界面] 打开日志")
func _on_settings_pressed()-> void:
	_auto_save()
	if get_tree():
		get_tree().change_scene_to_file("res://scenes/select_slot.tscn")


## ============ 样式工具 ============
func _panel_style(node: Panel, clr: Color) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = clr
	sb.border_width_left = 1; sb.border_width_right = 1
	sb.border_width_top = 1; sb.border_width_bottom = 1
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
	btn.add_theme_color_override("font_color", Color.WHITE)
