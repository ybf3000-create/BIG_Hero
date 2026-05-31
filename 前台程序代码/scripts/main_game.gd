extends Control

## ============================================================
## 大勇者 - 主游戏界面 v0.5
## 菱形格子 + 主角叠格子 + 单行按钮 + 自动挂机
## debug_cmd 可触发: click_dice, click_bag, click_skill, click_log, click_home, toggle_auto
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
const DiceRollerCls = preload("res://scripts/dice_roller.gd")
const GridExecutorCls = preload("res://scripts/grid_executor.gd")
const InventoryCls = preload("res://scripts/inventory.gd")
const EquipmentCls = preload("res://scripts/equipment.gd")
const ItemDBRef = preload("res://scripts/item_db.gd")

# 子系统
var dice: RefCounted
var executor: RefCounted
var inventory: RefCounted
var equipment: RefCounted

# 移动动画
var _moving: bool = false
var _move_step: int = 0
var _move_total: int = 0
var _move_timer: float = 0.0
var _bounce_offset: float = 0.0     # 主角跳跃偏移
var _scroll_offset: float = 0.0     # 地块左滑偏移

const STEP_PAUSE: float = 0.3       # 每步停顿
const STEP_SLIDE: float = 0.25      # 滑动时长
const STEP_TOTAL: float = STEP_PAUSE + STEP_SLIDE  # 单步总时长

# 平行四边形地块尺寸（顶边宽 × 高，斜边由 GridTile.SHEAR 控制）
const TILE_W: float = 160.0       # 上下边水平宽度
const TILE_H: float = 90.0        # 平行四边形高度（标签内置）
const TILE_SHEAR: float = 45.0    # 斜边偏移（与 GridTile.SHEAR 一致）
const TILE_COUNT: int = 7
# TILE_Y 在 _build_map_area 中动态计算


## ============ _ready ============
func _ready() -> void:
	anchor_right  = 1.0
	anchor_bottom = 1.0

	# 初始化子系统
	dice = DiceRollerCls.new()
	executor = GridExecutorCls.new()
	inventory = InventoryCls.new()
	equipment = EquipmentCls.new()

	# 从选择界面传来的存档数据
	if has_meta("save_slot") and has_meta("save_data"):
		_current_slot = get_meta("save_slot") as int
		var data: Dictionary = get_meta("save_data") as Dictionary
		_load_from_save_data(data)

	_build_top_bar()
	_refresh_poker_slots()  # TopBar 创建后才能刷新牌型显示
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
	_btn_transparent2(avatar_btn)
	avatar_btn.pressed.connect(_show_stats_panel)
	bar.add_child(avatar_btn)

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

	# -- 平行四边形地块（下移到靠近底部，不占底部UI） --
	var total_span := TILE_COUNT * TILE_W
	var start_x := (1280.0 - total_span) / 2.0
	var tile_y: float = area.size.y - TILE_H - 12  # 靠下，留 12px 间距
	var slot_names := ["PrevGrid2", "PrevGrid1", "CurrentGrid", "NextGrid1", "NextGrid2", "NextGrid3", "NextGrid4"]
	var grid_tile_y: float = tile_y  # 主角定位用

	for i in range(TILE_COUNT):
		var tile: Control = GridTileCls.new()
		tile.name = slot_names[i]
		# x: 地块N的右下角=地块N+1的左下角（斜边公用）
		tile.position = Vector2(start_x + i * TILE_W, tile_y)
		tile.size = Vector2(TILE_W + TILE_SHEAR, TILE_H)  # 不含标签行
		tile.set_label_positions(0, 0)
		area.add_child(tile)

	# -- 主角图像（PNG 自带透明背景） --
	var hero_tex := load("res://assets/主角.png")
	if hero_tex:
		var hero := TextureRect.new()
		hero.name = "HeroOnMap"
		hero.texture = hero_tex
		hero.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		hero.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		hero.size = Vector2(130, 130)
		area.add_child(hero)
		_position_hero_on_tile(hero, 3, area)  # 初始在当前格
	else:
		var fallback := Label.new()
		fallback.name = "HeroFallback"
		fallback.text = "🚶"
		fallback.add_theme_font_size_override("font_size", 64)
		# 居中当前格
		var fcx: float = start_x + 3 * TILE_W + TILE_W / 2.0 + TILE_SHEAR / 2.0
		fallback.position = Vector2(fcx - 32, grid_tile_y - 50)
		area.add_child(fallback)

	# -- 位置计数 --
	var pos_lbl := Label.new()
	pos_lbl.name = "GridPosLabel"
	pos_lbl.text = "位置: 0/" + str(map_total_grids)
	pos_lbl.add_theme_font_size_override("font_size", 10)
	pos_lbl.add_theme_color_override("font_color", Color(0.35, 0.35, 0.4))
	pos_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pos_lbl.position = Vector2(0, grid_tile_y + TILE_H + 4)
	pos_lbl.size = Vector2(1280, 14)
	area.add_child(pos_lbl)

	# -- 右上角：自动挂机勾选（勾选框图标白色描边） --
	var auto_check := CheckBox.new()
	auto_check.name = "AutoPlayCheck"
	auto_check.text = "自动挂机"
	auto_check.add_theme_font_size_override("font_size", 15)
	auto_check.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0))
	auto_check.add_theme_color_override("font_pressed_color", Color(0.3, 1.0, 0.5))
	auto_check.button_pressed = false
	auto_check.position = Vector2(1115, 6)

	# 勾选框图标白色边框
	var chk_icon := StyleBoxFlat.new()
	chk_icon.bg_color = Color(0.08, 0.12, 0.20, 0.85)
	chk_icon.border_width_left = 1; chk_icon.border_width_right = 1
	chk_icon.border_width_top = 1; chk_icon.border_width_bottom = 1
	chk_icon.border_color = Color(1.0, 1.0, 1.0, 0.8)  # 半透白边
	chk_icon.set_corner_radius_all(3)
	auto_check.add_theme_stylebox_override("normal", chk_icon)

	area.add_child(auto_check)

	add_child(area)


## 将主角图像定位到指定菱形格子正上方
func _position_hero_on_tile(hero: TextureRect, tile_index: int, p_area: Control = null) -> void:
	var area: Control = p_area if p_area else get_node_or_null("MapArea")
	if not area:
		return
	var total_span := TILE_COUNT * TILE_W
	var start_x := (1280.0 - total_span) / 2.0
	var tile_y: float = area.size.y - TILE_H - 12  # 与 _build_map_area 一致
	# 平行四边形几何中心
	var center_x: float = start_x + tile_index * TILE_W + TILE_W / 2.0 + TILE_SHEAR / 2.0
	var center_y: float = tile_y + TILE_H / 2.0
	hero.position = Vector2(center_x - hero.size.x / 2.0, center_y - hero.size.y + 10 + _bounce_offset)


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
	poker_records.clear()
	for item in data.get("poker_records", []):
		poker_records.append(item as Dictionary)
	inventory.from_dict(data.get("inventory", []))
	equipment.from_dict(data.get("equipment", {}))
	# _refresh_poker_slots() 延迟到 _build_top_bar() 之后


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
		"inventory": inventory.to_dict(),
		"equipment": equipment.to_dict(),
	}


## ============================================================
## 掷骰逻辑 — 使用 DiceRoller + 步进移动 + GridExecutor
## ============================================================
func _on_dice_roll() -> void:
	if _moving:
		return  # 移动中不能再次掷骰

	last_dice_roll = dice.roll()
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

	# 启动步进移动
	_move_step = 0
	_move_total = last_dice_roll
	_move_timer = 0.0
	_scroll_offset = 0.0
	_bounce_offset = 0.0
	_moving = true


## 步进移动：每步停顿→滑动→复位→刷新内容
func _process(delta: float) -> void:
	if not _moving:
		return

	_move_timer += delta
	var step_phase: float = _move_timer / STEP_TOTAL  # 当前步进度 0~1
	var slide_start: float = STEP_PAUSE / STEP_TOTAL

	if step_phase > slide_start:
		# 滑动阶段：偏移从 0 → -TILE_W
		var sp: float = (step_phase - slide_start) / (1.0 - slide_start)
		_scroll_offset = -TILE_W * sp
		_bounce_offset = -abs(sin(sp * PI)) * 22.0
	else:
		_scroll_offset = 0.0
		_bounce_offset = 0.0

	_slide_grids()

	# 单步完成 → 复位偏移 + 刷新格子内容（补右边新格子）
	if _move_timer >= STEP_TOTAL:
		_move_timer = 0.0
		_move_step += 1
		_scroll_offset = 0.0
		_bounce_offset = 0.0

		player_grid_index = (player_grid_index + 1) % map_total_grids
		var prev_idx := (player_grid_index - 1 + map_total_grids) % map_total_grids
		if prev_idx > player_grid_index:
			player_gold += 50
			var rl: Label = $TopBar/DiceRewardLabel as Label
			if rl:
				rl.text = "🎲 过起点 +50金!"
			_refresh_top_bar()

		_refresh_grid_display()
		_slide_grids()

		if _move_step >= _move_total:
			_moving = false
			_scroll_offset = 0.0
			_bounce_offset = 0.0
			_move_step = 0
			_move_total = 0
			_slide_grids()
			_on_move_complete()
			_slide_grids()
			_on_move_complete()


## 每帧更新地块位置（应用滑动偏移）
func _slide_grids() -> void:
	var area := get_node_or_null("MapArea")
	if not area:
		return
	var total_span := TILE_COUNT * TILE_W
	var start_x := (1280.0 - total_span) / 2.0
	var slot_names := ["PrevGrid2", "PrevGrid1", "CurrentGrid", "NextGrid1", "NextGrid2", "NextGrid3", "NextGrid4"]
	for i in range(TILE_COUNT):
		var tile := area.get_node_or_null(slot_names[i])
		if tile:
			tile.position.x = start_x + i * TILE_W + _scroll_offset

	# 主角弹跳：基于基准位置 + 当前弹跳偏移
	var hero: TextureRect = area.get_node_or_null("HeroOnMap") as TextureRect
	if hero:
		var tile_y: float = area.size.y - TILE_H - 12
		var cx: float = start_x + 3 * TILE_W + TILE_W / 2.0 + TILE_SHEAR / 2.0
		var cy: float = tile_y + TILE_H / 2.0
		hero.position = Vector2(cx - hero.size.x / 2.0, cy - hero.size.y + 10 + _bounce_offset)


func _on_move_complete() -> void:
	# 使用 GridExecutor 触发当前位置的格子效果
	var gtype: int = map_grids[player_grid_index % map_total_grids]
	var ctx := { "player_level": player_level, "player_gold": player_gold }
	var result: Dictionary = executor.execute(gtype, ctx)
	print("[Grid] 格子类型=", gtype, " → ", result["event"])

	_check_poker_hand()
	_refresh_top_bar()
	_auto_save()

	# 自动挂机继续
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
	var area := get_node_or_null("MapArea")
	if not area:
		return
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

		# 视野外格子半透明
		var dist := absi(i - 3)
		tile.modulate.a = 1.0 if dist <= 2 else maxf(0.15, 1.0 - (dist - 2) * 0.28)

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
func _on_bag_pressed() -> void:
	_show_inventory_panel()
func _on_skill_pressed()   -> void: print("[主界面] 打开技能")
func _on_log_pressed()     -> void: print("[主界面] 打开日志")
func _on_settings_pressed()-> void:
	_auto_save()
	if get_tree():
		get_tree().change_scene_to_file("res://scenes/select_slot.tscn")


## ============ 背包 UI 面板 ============
func _show_inventory_panel() -> void:
	# 本地类型常量（ItemDB class_name 未注册编辑器时不可用）
	const TYPE_WEAPON: int = 1
	const TYPE_ARMOR: int = 2
	const TYPE_SHOES: int = 3
	const TYPE_RING: int = 4
	const TYPE_NECKLACE: int = 5
	const TYPE_CAPE: int = 6
	const TYPE_HELMET: int = 7
	const TYPE_CHARM: int = 8
	const TYPE_MATERIAL: int = 9

	_auto_save()
	var panel: Panel = Panel.new()
	panel.name = "InventoryPanel"
	panel.position = Vector2(140, 60)
	panel.size = Vector2(1000, 550)
	_panel_style(panel, Color(0.10, 0.10, 0.16))

	# 标题
	var title: Label = Label.new()
	title.text = "🎒 背包  |  💰 " + str(player_gold) + " 金币"
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	title.position = Vector2(20, 10)
	panel.add_child(title)

	# 装备栏（左侧）
	var equip_panel: Panel = Panel.new()
	equip_panel.position = Vector2(16, 50)
	equip_panel.size = Vector2(280, 420)
	_panel_style(equip_panel, Color(0.08, 0.09, 0.13))
	panel.add_child(equip_panel)

	var equip_title: Label = Label.new()
	equip_title.text = "装备栏"
	equip_title.add_theme_font_size_override("font_size", 16)
	equip_title.add_theme_color_override("font_color", Color(0.7, 0.85, 1.0))
	equip_title.position = Vector2(10, 8)
	equip_panel.add_child(equip_title)

	var equip_slots: Array[Dictionary] = [
		{ "name": "weapon",   "label": "武器" },
		{ "name": "armor",    "label": "防具" },
		{ "name": "shoes",    "label": "鞋子" },
		{ "name": "ring",     "label": "戒指" },
		{ "name": "necklace", "label": "项链" },
		{ "name": "cape",     "label": "披风" },
		{ "name": "helmet",   "label": "头盔" },
		{ "name": "charm",    "label": "护符" },
	]
	var row_h: float = 40.0
	for j in range(equip_slots.size()):
		var es: Dictionary = equip_slots[j]
		var ry: float = 38.0 + j * row_h

		var eq_lbl: Label = Label.new()
		eq_lbl.text = es["label"]
		eq_lbl.add_theme_font_size_override("font_size", 13)
		eq_lbl.add_theme_color_override("font_color", Color(0.5, 0.5, 0.6))
		eq_lbl.position = Vector2(10, ry)
		equip_panel.add_child(eq_lbl)

		var slot_bg: ColorRect = ColorRect.new()
		slot_bg.name = "EqSlot_" + es["name"]
		slot_bg.position = Vector2(48, ry + 16)
		slot_bg.size = Vector2(218, 28)
		slot_bg.color = Color(0.14, 0.15, 0.22)
		equip_panel.add_child(slot_bg)

		var item_id: int = equipment.get_slot_item(es["name"])
		var slot_lbl: Label = Label.new()
		slot_lbl.name = "EqText_" + es["name"]
		if item_id > 0:
			slot_lbl.text = ItemDBRef.get_icon(item_id) + " " + ItemDBRef.get_name(item_id)
			slot_lbl.add_theme_color_override("font_color", Color(1.0, 0.9, 0.5))
		else:
			slot_lbl.text = "[ 空 ]"
			slot_lbl.add_theme_color_override("font_color", Color(0.3, 0.3, 0.4))
		slot_lbl.add_theme_font_size_override("font_size", 12)
		slot_lbl.position = Vector2(54, ry + 19)
		equip_panel.add_child(slot_lbl)

	# 道具列表（右侧）
	var item_panel: Panel = Panel.new()
	item_panel.position = Vector2(310, 50)
	item_panel.size = Vector2(674, 420)
	_panel_style(item_panel, Color(0.08, 0.09, 0.13))
	panel.add_child(item_panel)

	var cnt: int = inventory.get_slot_count()
	var item_title: Label = Label.new()
	item_title.text = "道具 (" + str(cnt) + "/30)"
	item_title.add_theme_font_size_override("font_size", 14)
	item_title.add_theme_color_override("font_color", Color(0.5, 0.5, 0.6))
	item_title.position = Vector2(10, 8)
	item_panel.add_child(item_title)

	for i in range(cnt):
		var slot: Dictionary = inventory.get_slot(i)
		var defn: Dictionary = ItemDBRef.get_item(slot["item_id"])
		var row_y: float = 34.0 + i * 28.0

		var icon_lbl: Label = Label.new()
		icon_lbl.text = defn.get("icon", "?")
		icon_lbl.add_theme_font_size_override("font_size", 16)
		icon_lbl.position = Vector2(10, row_y)
		item_panel.add_child(icon_lbl)

		var name_lbl: Label = Label.new()
		name_lbl.text = defn.get("name", "???") + "  ×" + str(slot["count"])
		name_lbl.add_theme_font_size_override("font_size", 13)
		name_lbl.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))
		name_lbl.position = Vector2(40, row_y)
		item_panel.add_child(name_lbl)

		var type_lbl: Label = Label.new()
		var tname: String = "消耗"
		match defn.get("type", 0):
			TYPE_WEAPON:    tname = "武器"
			TYPE_ARMOR:     tname = "防具"
			TYPE_SHOES:     tname = "鞋子"
			TYPE_RING:      tname = "戒指"
			TYPE_NECKLACE:  tname = "项链"
			TYPE_CAPE:      tname = "披风"
			TYPE_HELMET:    tname = "头盔"
			TYPE_CHARM:     tname = "护符"
			TYPE_MATERIAL:  tname = "材料"
		type_lbl.text = "[" + tname + "]"
		type_lbl.add_theme_font_size_override("font_size", 11)
		type_lbl.add_theme_color_override("font_color", Color(0.4, 0.5, 0.7))
		type_lbl.position = Vector2(200, row_y + 2)
		item_panel.add_child(type_lbl)

		# 使用/装备按钮
		var btn: Button = Button.new()
		var itype_int: int = defn.get("type", 0)
		var is_equip: bool = (itype_int >= TYPE_WEAPON and itype_int <= TYPE_CHARM)
		btn.text = "装备" if is_equip else "使用"
		btn.position = Vector2(260, row_y - 2)
		btn.size = Vector2(50, 22)
		btn.add_theme_font_size_override("font_size", 11)
		_btn_style_mini(btn, Color(0.18, 0.25, 0.40))
		var idx: int = i
		btn.pressed.connect(func():
			_on_item_action(idx)
			panel.queue_free()
			_show_inventory_panel()  # 刷新面板
		)
		item_panel.add_child(btn)

	# 关闭按钮
	var close_btn: Button = Button.new()
	close_btn.text = "✕ 关闭"
	close_btn.position = Vector2(460, 490)
	close_btn.size = Vector2(80, 30)
	_btn_style_mini(close_btn, Color(0.25, 0.15, 0.15))
	close_btn.pressed.connect(panel.queue_free)
	panel.add_child(close_btn)

	add_child(panel)


func _on_item_action(slot_idx: int) -> void:
	const TYPE_WEAPON: int = 1
	const TYPE_ARMOR: int = 2
	const TYPE_SHOES: int = 3
	const TYPE_RING: int = 4
	const TYPE_NECKLACE: int = 5
	const TYPE_CAPE: int = 6
	const TYPE_HELMET: int = 7
	const TYPE_CHARM: int = 8

	var slot: Dictionary = inventory.get_slot(slot_idx)
	if slot.is_empty():
		return
	var defn: Dictionary = ItemDBRef.get_item(slot["item_id"])
	var itype: int = defn.get("type", 0)

	if itype >= TYPE_WEAPON and itype <= TYPE_CHARM:
		var slot_name: String = ""
		match itype:
			TYPE_WEAPON:   slot_name = "weapon"
			TYPE_ARMOR:    slot_name = "armor"
			TYPE_SHOES:    slot_name = "shoes"
			TYPE_RING:     slot_name = "ring"
			TYPE_NECKLACE: slot_name = "necklace"
			TYPE_CAPE:     slot_name = "cape"
			TYPE_HELMET:   slot_name = "helmet"
			TYPE_CHARM:    slot_name = "charm"
		var old_id: int = equipment.unequip(slot_name)
		if old_id > 0:
			inventory.add_item(old_id, 1)
		equipment.equip(slot_name, slot["item_id"])
		inventory.remove_item(slot_idx, 1)
	else:
		# 消耗品
		var stats: Dictionary = defn.get("stats", {})
		player_gold += stats.get("gold_bonus", 0)
		player_exp += stats.get("exp_bonus", 0)
		_refresh_top_bar()
		inventory.remove_item(slot_idx, 1)


## ============ 主角属性详情面板 ============
func _show_stats_panel() -> void:
	# 移除旧面板
	var old: Node = get_node_or_null("StatsPanel")
	if old:
		old.queue_free()
		return

	var panel: Panel = Panel.new()
	panel.name = "StatsPanel"
	panel.position = Vector2(140, 40)
	panel.size = Vector2(500, 620)
	_panel_style(panel, Color(0.08, 0.09, 0.15))

	# 标题
	var title: Label = Label.new()
	title.text = "📋 " + player_name + "  Lv." + str(player_level)
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	title.position = Vector2(20, 12)
	panel.add_child(title)

	# 经验条
	var exp_bar: ProgressBar = ProgressBar.new()
	exp_bar.position = Vector2(20, 44)
	exp_bar.size = Vector2(460, 14)
	exp_bar.value = player_exp
	exp_bar.max_value = player_exp_max
	_bar_style(exp_bar, Color(0.15, 0.35, 0.6))
	panel.add_child(exp_bar)

	var exp_lbl: Label = Label.new()
	exp_lbl.text = str(player_exp) + " / " + str(player_exp_max)
	exp_lbl.add_theme_font_size_override("font_size", 10)
	exp_lbl.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	exp_lbl.position = Vector2(20, 60)
	panel.add_child(exp_lbl)

	# 属性列表
	var stats: Array[Dictionary] = [
		{ "icon": "❤️", "name": "生命值 (HP)",   "value": "500", "desc": "归零则战斗失败，消耗1枚复活币复活。\n每级+80" },
		{ "icon": "⚔️", "name": "攻击力 (ATK)",  "value": "25", "desc": "基础攻击力，与装备攻击力相加后\n受自由属性点和装备词条加成" },
		{ "icon": "🛡️", "name": "防御力 (DEF)",  "value": "15", "desc": "决定受到的伤害减免。\n每点防御→减伤系数增加" },
		{ "icon": "👟", "name": "速度 (SPD)",    "value": "0",  "desc": "每点-1%出手CD（上限50%）。\n3.0秒× (1-速度%) = 实际CD" },
		{ "icon": "🍀", "name": "幸运 (LUK)",    "value": "0",  "desc": "每点+2%稀有掉落/好事件概率。\n影响宝箱品质、命运事件、战斗掉落" },
		{ "icon": "💥", "name": "暴击率",        "value": "5%", "desc": "攻击时触发暴击的概率。\n暴击伤害=攻击力×暴击倍率" },
		{ "icon": "💢", "name": "暴击伤害",       "value": "150%","desc": "暴击时的伤害倍率。\n基础150%，装备/宝石可提高" },
		{ "icon": "🎯", "name": "命中率",        "value": "100%","desc": "决定攻击是否命中。\n可抵消目标的闪避率" },
		{ "icon": "💨", "name": "闪避率",        "value": "0%", "desc": "完全躲避攻击的概率。\n实际闪避=我方闪避-敌方命中" },
		{ "icon": "🛡️", "name": "格挡率",        "value": "0%", "desc": "格挡后伤害减半。\n暴击+格挡同时触发=暴击×0.5" },
	]

	var sy: float = 88.0
	for st in stats:
		# 行背景
		var row: ColorRect = ColorRect.new()
		row.position = Vector2(16, sy)
		row.size = Vector2(468, 44)
		row.color = Color(0.10, 0.11, 0.18)
		panel.add_child(row)

		# 图标
		var icon: Label = Label.new()
		icon.text = st["icon"]
		icon.add_theme_font_size_override("font_size", 18)
		icon.position = Vector2(24, sy + 8)
		panel.add_child(icon)

		# 名称
		var name_lbl: Label = Label.new()
		name_lbl.text = st["name"]
		name_lbl.add_theme_font_size_override("font_size", 14)
		name_lbl.add_theme_color_override("font_color", Color(0.8, 0.85, 0.9))
		name_lbl.position = Vector2(55, sy + 10)
		panel.add_child(name_lbl)

		# 数值
		var val_lbl: Label = Label.new()
		val_lbl.text = st["value"]
		val_lbl.add_theme_font_size_override("font_size", 16)
		val_lbl.add_theme_color_override("font_color", Color(1.0, 0.9, 0.3))
		val_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		val_lbl.position = Vector2(194, sy + 8)
		val_lbl.size = Vector2(120, 24)
		panel.add_child(val_lbl)

		# 点击查看说明
		var btn: Button = Button.new()
		btn.text = "?"
		btn.position = Vector2(435, sy + 8)
		btn.size = Vector2(36, 24)
		btn.add_theme_font_size_override("font_size", 12)
		_btn_style_mini(btn, Color(0.15, 0.22, 0.38))
		var desc: String = st["desc"]
		btn.pressed.connect(func(): _show_stat_tooltip(st["name"], desc))
		panel.add_child(btn)

		sy += 47.0

	# 底部信息
	sy += 10.0
	var footer: Label = Label.new()
	footer.text = "💰 " + str(player_gold) + "金币  |  ♻️ " + str(player_revive) + "/" + str(player_max_revive) + "复活币  |  位置 " + str(player_grid_index) + "/" + str(map_total_grids)
	footer.add_theme_font_size_override("font_size", 12)
	footer.add_theme_color_override("font_color", Color(0.5, 0.55, 0.6))
	footer.position = Vector2(20, sy)
	panel.add_child(footer)

	# 关闭
	var close: Button = Button.new()
	close.text = "✕"
	close.position = Vector2(458, 8)
	close.size = Vector2(30, 28)
	_btn_style_mini(close, Color(0.3, 0.1, 0.1))
	close.pressed.connect(panel.queue_free)
	panel.add_child(close)

	add_child(panel)


## 属性气泡说明
func _show_stat_tooltip(stat_name: String, desc: String) -> void:
	var old: Node = get_node_or_null("StatTooltip")
	if old:
		old.queue_free()

	var tip: Panel = Panel.new()
	tip.name = "StatTooltip"
	tip.position = Vector2(360, 280)
	tip.size = Vector2(320, 120)
	_panel_style(tip, Color(0.05, 0.06, 0.12, 0.95))

	var title: Label = Label.new()
	title.text = stat_name
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	title.position = Vector2(16, 10)
	tip.add_child(title)

	var body: Label = Label.new()
	body.text = desc
	body.add_theme_font_size_override("font_size", 12)
	body.add_theme_color_override("font_color", Color(0.8, 0.8, 0.85))
	body.position = Vector2(16, 34)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD
	body.size = Vector2(288, 76)
	tip.add_child(body)

	# 自动消失
	var t: SceneTreeTimer = get_tree().create_timer(3.0)
	t.timeout.connect(func():
		if is_instance_valid(tip):
			tip.queue_free()
	)

	add_child(tip)


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

func _btn_style_mini(btn: Button, clr: Color) -> void:
	var n: StyleBoxFlat = StyleBoxFlat.new()
	n.bg_color = clr
	n.set_corner_radius_all(3)
	btn.add_theme_stylebox_override("normal", n)
	btn.add_theme_color_override("font_color", Color.WHITE)
	btn.flat = true

## 透明按钮（hover 微弱高亮）
func _btn_transparent2(btn: Button) -> void:
	var normal: StyleBoxFlat = StyleBoxFlat.new()
	normal.bg_color = Color(1, 1, 1, 0)
	var hover: StyleBoxFlat = StyleBoxFlat.new()
	hover.bg_color = Color(1, 1, 1, 0.06)
	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", normal)

func _btn_style(btn: Button, clr: Color) -> void:
	var n: StyleBoxFlat = StyleBoxFlat.new()
	n.bg_color = clr
	n.border_width_left = 2; n.border_width_right = 2
	n.border_width_top = 2; n.border_width_bottom = 2
	n.border_color = Color(0.5, 0.5, 0.6, 0.7)
	n.set_corner_radius_all(6)
	btn.add_theme_stylebox_override("normal", n)
	var h: StyleBoxFlat = n.duplicate() as StyleBoxFlat
	h.bg_color = clr.lightened(0.15)
	btn.add_theme_stylebox_override("hover", h)
	var p: StyleBoxFlat = n.duplicate() as StyleBoxFlat
	p.bg_color = clr.darkened(0.15)
	btn.add_theme_stylebox_override("pressed", p)
	btn.add_theme_color_override("font_color", Color.WHITE)
