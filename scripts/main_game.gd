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

# 扑克牌花色（工具常量已移至 UIUtils）
const SUITS := ["♠", "♣", "♥", "♦"]

# -- 玩家状态 --
var player_name: String = "勇者"
var player_level: int = 1
var player_exp: int = 0
var player_exp_max: int = 100
var player_gold: int = 0
var player_revive: int = 3
var player_max_revive: int = 3
var player_hp: int = 500
var player_max_hp: int = 500
var player_boss_tier: int = 0
var player_boss_index: int = 1
# 自由属性点（每升1级+2点）
var player_free_points: int = 0
var player_stat_atk: int = 0
var player_stat_def: int = 0
var player_stat_spd: int = 0
var player_stat_luk: int = 0
var player_grid_index: int = 0
var map_total_grids: int = 28
var map_grids: Array[int] = []
var last_dice_roll: int = 0
var last_dice_suit: String = ""
var last_dice_history: Array[int] = []
var poker_records: Array[Dictionary] = []
var auto_play_enabled: bool = false
var _current_slot: int = -1  # 当前存档槽位

const VISIBLE_BEFORE: int = 3
const VISIBLE_AFTER: int  = 5
const CURRENT_TILE_SLOT: int = VISIBLE_BEFORE

const GridTileCls = preload("res://scripts/grid_tile.gd")
const DiceRollerCls = preload("res://scripts/dice_roller.gd")
const GridExecutorCls = preload("res://scripts/grid_executor.gd")
const InventoryCls = preload("res://scripts/inventory.gd")
const EquipmentCls = preload("res://scripts/equipment.gd")
const ItemDBRef = preload("res://scripts/item_db.gd")
const EquipGenCls = preload("res://scripts/equip_gen.gd")
const EquipData = preload("res://scripts/equip_data.gd")
const SkillDataRef = preload("res://scripts/skill_data.gd")
const SkillCls = preload("res://scripts/skill_system.gd")
const UIUtilsRef = preload("res://scripts/ui/ui_utils.gd")
const TopBarCls = preload("res://scripts/ui/top_bar.gd")
const ShrineBackdropCls = preload("res://scripts/ui/shrine_backdrop.gd")
const BattleViewCls = preload("res://scripts/ui/battle_view.gd")

# 子系统
var dice: RefCounted
var executor: RefCounted
var inventory: RefCounted
var skill_system: RefCounted
var equipment: RefCounted
var top_bar  # TopBar instance (no type hint to avoid parse-order issue after cache clear)

# 技能槽位（内嵌管理，6槽）

# 生成装备实例列表（每件唯一）
var equip_instances: Array[Dictionary] = []
var gem_bag: Array[Dictionary] = []   # [{gem_id, level, count}]
var lottery_tickets: Array[int] = []  # 3位数 000~999, 最多10张
var _tooltip_nodes: Array[Node] = []  # 当前打开的 tooltip 列表
var _float_text_node: Label             # 当前飘字
var active_buffs: Array[Dictionary] = []  # [{name, turns_remaining}]
var lottery_draw_at: int = 0           # 下次开奖圈数

# ============ 预留：天命卡 & 神祇祝福系统 ============
# 天命卡槽位（待开发，目前仅接口）
var _fate_cards: Array[Dictionary] = []   # [{id, name, rarity, stat_bonus: {}}]
# 神祇 buff（待开发，目前仅接口）
var _deity_buffs: Array[Dictionary] = []  # [{name, stat_bonus: {}, turns}]
# ====================================================

# 移动动画
var _moving: bool = false
var _move_step: int = 0
var _move_total: int = 0
var _move_timer: float = 0.0
var _bounce_offset: float = 0.0     # 主角跳跃偏移
var _scroll_offset: float = 0.0     # 地块左滑偏移

const STEP_PAUSE: float = 0.21      # 每步停顿（原 0.3，缩短30%）
const STEP_SLIDE: float = 0.175     # 滑动时长（原 0.25，缩短30%）
const STEP_TOTAL: float = STEP_PAUSE + STEP_SLIDE  # 单步总时长

# 平行四边形地块尺寸（顶边宽 × 高，斜边由 GridTile.SHEAR 控制）
const TILE_W: float = 160.0       # 上下边水平宽度
const TILE_H: float = 90.0        # 平行四边形高度（标签内置）
const TILE_SHEAR: float = 45.0    # 斜边偏移（与 GridTile.SHEAR 一致）
const TILE_COUNT: int = VISIBLE_BEFORE + VISIBLE_AFTER + 1
const TILE_SLOT_NAMES: Array[String] = ["PrevGrid3", "PrevGrid2", "PrevGrid1", "CurrentGrid", "NextGrid1", "NextGrid2", "NextGrid3", "NextGrid4", "NextGrid5"]
const EXPANSION_PROTECT_RADIUS: int = 3
const EXPANSION_RESHUFFLE_ATTEMPTS: int = 80
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
	skill_system = SkillCls.new()

	top_bar = TopBarCls.new(self)
	_refresh_player_hp_bounds(true)

	# 从选择界面传来的存档数据
	if has_meta("save_slot") and has_meta("save_data"):
		_current_slot = get_meta("save_slot") as int
		var data: Dictionary = get_meta("save_data") as Dictionary
		_load_from_save_data(data)

	top_bar.build()
	top_bar.refresh_poker_slots()  # TopBar 创建后才能刷新牌型显示
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
func _build_map_area() -> void:
	var area := Panel.new()
	area.name = "MapArea"
	area.position = Vector2(0, 104)
	area.size = Vector2(1280, 528)
	UIUtils.shrine_panel_style(area, Color("f6d6d6"), Color("b88d89"), 1)

	# 抽象和风背景：未来替换背景图时，保留本节点作为兜底。
	var backdrop: Control = ShrineBackdropCls.new()
	backdrop.name = "ShrineBackdrop"
	backdrop.position = Vector2.ZERO
	backdrop.size = area.size
	area.add_child(backdrop)

	# -- 平行四边形地块（下移到靠近底部，不占底部UI） --
	var total_span := TILE_COUNT * TILE_W
	var start_x := (1280.0 - total_span) / 2.0
	var tile_y: float = area.size.y - TILE_H - 12  # 靠下，留 12px 间距
	var slot_names: Array[String] = TILE_SLOT_NAMES
	var grid_tile_y: float = tile_y  # 主角定位用

	for i in range(TILE_COUNT):
		var tile: Control = GridTileCls.new()
		tile.name = slot_names[i]
		# x: 地块N的右下角=地块N+1的左下角（斜边公用）
		tile.position = Vector2(start_x + i * TILE_W, tile_y)
		tile.size = Vector2(TILE_W + TILE_SHEAR, TILE_H)  # 不含标签行
		tile.set_label_positions(0, 0)
		area.add_child(tile)

	# -- 主角图像（PNG 自带透明背景，直接读取源图避免导入压缩/透明异常） --
	var hero_tex: Texture2D = _load_hero_texture("res://assets/hreo.png")
	if hero_tex:
		var hero := TextureRect.new()
		hero.name = "HeroOnMap"
		hero.texture = hero_tex
		hero.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		hero.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		hero.size = Vector2(130, 130)
		area.add_child(hero)
		_position_hero_on_tile(hero, CURRENT_TILE_SLOT, area)  # 初始在当前格
	else:
		var fallback := Label.new()
		fallback.name = "HeroFallback"
		fallback.text = "🚶"
		fallback.add_theme_font_size_override("font_size", 64)
		# 居中当前格
		var fcx: float = start_x + CURRENT_TILE_SLOT * TILE_W + TILE_W / 2.0 + TILE_SHEAR / 2.0
		fallback.position = Vector2(fcx - 32, grid_tile_y - 50)
		area.add_child(fallback)

	# -- 左上角地图状态 --
	var status_panel := Panel.new()
	status_panel.name = "MapStatusPanel"
	status_panel.position = Vector2(20, 18)
	status_panel.size = Vector2(310, 34)
	UIUtils.shrine_panel_style(status_panel, Color(1.0, 0.976, 0.96, 0.92), Color("b88d89"), 1)
	area.add_child(status_panel)

	var pos_lbl := Label.new()
	pos_lbl.name = "GridPosLabel"
	pos_lbl.text = "格子 1 / " + str(map_total_grids) + "  ·  Boss 0 / 100"
	pos_lbl.add_theme_font_size_override("font_size", 13)
	pos_lbl.add_theme_color_override("font_color", Color("352e38"))
	pos_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	pos_lbl.position = Vector2(12, 2)
	pos_lbl.size = Vector2(286, 30)
	status_panel.add_child(pos_lbl)

	# -- 右上角：自动挂机 --
	var auto_check := CheckButton.new()
	auto_check.name = "AutoPlayCheck"
	auto_check.text = "自动挂机"
	auto_check.add_theme_font_size_override("font_size", 13)
	auto_check.add_theme_color_override("font_color", Color("352e38"))
	auto_check.add_theme_color_override("font_pressed_color", Color("527d68"))
	auto_check.button_pressed = false
	auto_check.position = Vector2(1120, 18)
	auto_check.size = Vector2(140, 34)

	var chk_icon := StyleBoxFlat.new()
	chk_icon.bg_color = Color(1.0, 0.976, 0.96, 0.92)
	chk_icon.border_width_left = 1; chk_icon.border_width_right = 1
	chk_icon.border_width_top = 1; chk_icon.border_width_bottom = 1
	chk_icon.border_color = Color("b88d89")
	chk_icon.set_corner_radius_all(3)
	auto_check.add_theme_stylebox_override("normal", chk_icon)

	area.add_child(auto_check)

	add_child(area)


func _load_hero_texture(res_path: String) -> Texture2D:
	var imported: Texture2D = load(res_path) as Texture2D
	if imported:
		return imported
	var image: Image = Image.load_from_file(res_path)
	if image != null and not image.is_empty():
		return ImageTexture.create_from_image(image)
	return null


## 调试面板开关
func _toggle_debug_panel() -> void:
	var existing := get_node_or_null("DebugOverlay")
	if existing:
		existing.queue_free()
		return
	_build_debug_panel()


## 构建调试面板（4列 × 最大5排）
func _build_debug_panel() -> void:
	const COLS: int = 4
	const MAX_ROWS: int = 5
	const BTN_W: float = 130.0
	const BTN_H: float = 36.0
	const GAP: float = 8.0
	const MARGIN: float = 14.0
	const TITLE_H: float = 32.0
	var panel_w: float = MARGIN * 2 + BTN_W * COLS + GAP * (COLS - 1)
	var panel_h: float = TITLE_H + MARGIN + (BTN_H + GAP) * MAX_ROWS + MARGIN

	# 遮罩（点击关闭）
	var overlay := ColorRect.new()
	overlay.name = "DebugOverlay"
	overlay.color = Color(0, 0, 0, 0.45)
	overlay.size = Vector2(1280, 720)
	overlay.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.pressed:
			_toggle_debug_panel()
	)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP

	# 面板
	var panel := Panel.new()
	panel.name = "DebugPanel"
	panel.position = Vector2((1280.0 - panel_w) / 2.0, (720.0 - panel_h) / 2.0)
	panel.size = Vector2(panel_w, panel_h)
	UIUtils.panel_style(panel, Color(0.10, 0.10, 0.18, 0.97))
	overlay.add_child(panel)
	add_child(overlay)

	# 标题
	var title := Label.new()
	title.text = "🔧 调试面板"
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Color(0.4, 0.7, 1.0))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.position = Vector2(0, 4)
	title.size = Vector2(panel_w, TITLE_H)
	panel.add_child(title)

	# 关闭按钮（右上角）
	var close_btn := Button.new()
	close_btn.text = "✕"
	close_btn.position = Vector2(panel_w - 32, 4)
	close_btn.size = Vector2(26, 26)
	UIUtils.btn_style_mini(close_btn, Color(0.4, 0.12, 0.12))
	close_btn.pressed.connect(_toggle_debug_panel)
	panel.add_child(close_btn)

	# ---------- 按钮定义 ----------
	var btn_defs: Array[Dictionary] = [
		# 第1排：资源生成
		{"text": "💎 生成宝石",  "clr": Color(0.38, 0.12, 0.38), "cb": _on_test_generate_gem},
		{"text": "🔧 生成装备",  "clr": Color(0.22, 0.15, 0.38), "cb": _on_test_generate_equip},
		{"text": "⭐ +自由点",   "clr": Color(0.30, 0.25, 0.10), "cb": _on_test_add_free_point},
		{"text": "🎰 生成彩票",  "clr": Color(0.38, 0.08, 0.18), "cb": _on_test_generate_lottery},
		# 第2排：战斗测试
		{"text": "⚔ 普通战斗",   "clr": Color(0.15, 0.35, 0.15), "cb": func(): _on_test_battle("battle")},
		{"text": "🗡 精英战斗",   "clr": Color(0.35, 0.20, 0.10), "cb": func(): _on_test_battle("elite")},
		{"text": "👑 Boss战斗",   "clr": Color(0.35, 0.10, 0.10), "cb": func(): _on_test_battle("boss")},
	]

	for idx in range(btn_defs.size()):
		var def: Dictionary = btn_defs[idx]
		var row: int = idx / COLS
		var col: int = idx % COLS
		if row >= MAX_ROWS:
			break
		var bx: float = MARGIN + col * (BTN_W + GAP)
		var by: float = TITLE_H + MARGIN + row * (BTN_H + GAP)
		var btn := Button.new()
		btn.text = def["text"]
		btn.position = Vector2(bx, by)
		btn.size = Vector2(BTN_W, BTN_H)
		UIUtils.btn_style_mini(btn, def["clr"] as Color)
		btn.add_theme_font_size_override("font_size", 13)
		var cb: Callable = def["cb"] as Callable
		if cb.is_valid():
			btn.pressed.connect(cb)
		panel.add_child(btn)


## -- 测试战斗触发 --
func _on_test_battle(battle_kind: String) -> void:
	var ctx := {
		"player_level": player_level,
		"player_gold": player_gold,
		"player_revive": player_revive,
		"player_hp": player_hp,
		"player_max_hp": player_max_hp,
		"player_name": player_name,
		"boss_tier": player_boss_tier,
		"boss_index": player_boss_index,
		"equip_instances": equip_instances,
		"equipment": equipment,
		"player_state": _build_player_battle_state(),
	}
	var result: Dictionary
	match battle_kind:
		"elite":
			result = GridExecutorCls._exec_elite(ctx)
		"boss":
			result = GridExecutorCls._exec_boss(ctx)
		_:
			result = GridExecutorCls._exec_battle(ctx)

	player_gold = int(ctx.get("player_gold", player_gold))
	player_revive = int(ctx.get("player_revive", player_revive))
	player_hp = clampi(int(ctx.get("player_hp", player_hp)), 0, player_max_hp)

	var edata: Dictionary = result.get("data", {})
	if edata.has("battle_result"):
		_apply_battle_result(edata)
		_show_battle_view(edata)
	var msg: String = edata.get("message", battle_kind + " 战斗完成")
	var clr: Color = Color(1.0, 0.85, 0.3)
	if edata.get("force_home", false):
		clr = Color(1.0, 0.4, 0.4)
	_show_float_text(msg, clr)

	top_bar.refresh()
	top_bar.refresh_compact_stats()
	_auto_save()


func _on_test_add_free_point() -> void:
	player_free_points += 1
	_show_float_text("+1 自由属性点 (共" + str(player_free_points) + "点)", Color(1.0, 0.85, 0.2))
	_refresh_all_stats_panels()


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
	bar.position = Vector2(0, 632)
	bar.size = Vector2(1280, 88)
	UIUtils.shrine_panel_style(bar, Color("fff9f5"), Color("b88d89"), 2)

	# 单行布局：4小按钮(w=170) + 1大按钮(w=260) = 940，剩余 340 / 6间隔 = 57
	const SMALL_W := 170
	const SMALL_H := 44
	const DICE_W := 260
	const DICE_H := 52
	const GAP := 57

	var dice_x := GAP + SMALL_W + GAP + SMALL_W + GAP  # = 57+170+57+170+57 = 511
	var btn_y := (88.0 - SMALL_H) / 2.0
	var dice_y := (88.0 - DICE_H) / 2.0

	# -- 掷骰大按钮（居中） --
	var dice_btn := Button.new()
	dice_btn.name = "DiceRollBtn"
	dice_btn.text = "🎲  掷骰前进"
	dice_btn.position = Vector2(dice_x, dice_y)
	dice_btn.size = Vector2(DICE_W, DICE_H)
	UIUtils.shrine_button_style(dice_btn, true)
	dice_btn.add_theme_font_size_override("font_size", 19)
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
		UIUtils.shrine_button_style(btn, false)
		btn.add_theme_font_size_override("font_size", 16)
		bar.add_child(btn)

	# -- 调试面板入口按钮 --
	var debug_btn := Button.new()
	debug_btn.name = "DebugPanelBtn"
	debug_btn.text = "🔧 调试"
	debug_btn.position = Vector2(8, 314)
	debug_btn.size = Vector2(80, 28)
	UIUtils.btn_style_mini(debug_btn, Color(0.22, 0.22, 0.35))
	debug_btn.pressed.connect(_toggle_debug_panel)
	add_child(debug_btn)

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


func _refresh_player_hp_bounds(fill_if_empty: bool = false) -> void:
	var ps: Dictionary = _calc_player_stats()
	player_max_hp = maxi(int(ps.get("hp", 500)), 1)
	if fill_if_empty or player_hp <= 0:
		player_hp = player_max_hp
	else:
		player_hp = clampi(player_hp, 0, player_max_hp)


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
	player_boss_tier = data.get("boss_tier", 0)
	player_boss_index = data.get("boss_index", player_boss_tier + 1)
	player_free_points = data.get("free_points", 0)
	player_stat_atk = data.get("stat_atk", 0)
	player_stat_def = data.get("stat_def", 0)
	player_stat_spd = data.get("stat_spd", 0)
	player_stat_luk = data.get("stat_luk", 0)
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
	equip_instances.clear()
	for item in data.get("equip_instances", []):
		equip_instances.append(EquipGenCls.deserialize(item as Dictionary))
	skill_system.update_max_slots(player_level)
	skill_system.from_dict(data.get("skill_system", {}))
	skill_system.update_max_slots(player_level)
	_refresh_player_hp_bounds(data.has("player_hp") == false)
	player_hp = clampi(int(data.get("player_hp", player_max_hp)), 0, player_max_hp)
	# refresh_poker_slots() 延迟到 top_bar.build() 之后


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
		"player_hp": player_hp,
		"boss_tier": player_boss_tier,
		"boss_index": player_boss_index,
		"free_points": player_free_points,
		"stat_atk": player_stat_atk,
		"stat_def": player_stat_def,
		"stat_spd": player_stat_spd,
		"stat_luk": player_stat_luk,
		"grid_index": player_grid_index,
		"map_total_grids": map_total_grids,
		"map_grids": map_grids,
		"dice_history": last_dice_history,
		"poker_records": poker_records,
		"inventory": inventory.to_dict(),
		"equipment": equipment.to_dict(),
		"equip_instances": equip_instances,
		"skill_system": skill_system.to_dict(),
	}


## ============================================================
## 掷骰逻辑 — 使用 DiceRoller + 步进移动 + GridExecutor
## ============================================================
func _on_dice_roll() -> void:
	if _moving:
		return  # 移动中不能再次掷骰

	last_dice_roll = dice.roll()
	last_dice_suit = SUITS[randi() % 4]

	top_bar.refresh_dice_display()

	var record := { "value": last_dice_roll, "suit": last_dice_suit }
	poker_records.append(record)
	top_bar.refresh_poker_slots()

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
			top_bar.refresh()

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


## 每帧更新地块位置（应用滑动偏移）
func _slide_grids() -> void:
	var area := get_node_or_null("MapArea")
	if not area:
		return
	var total_span := TILE_COUNT * TILE_W
	var start_x := (1280.0 - total_span) / 2.0
	var slot_names: Array[String] = TILE_SLOT_NAMES
	for i in range(TILE_COUNT):
		var tile := area.get_node_or_null(slot_names[i])
		if tile:
			tile.position.x = start_x + i * TILE_W + _scroll_offset

	# 主角弹跳：始终锚定在逻辑当前格槽位上
	var hero: TextureRect = area.get_node_or_null("HeroOnMap") as TextureRect
	if hero:
		var tile_y: float = area.size.y - TILE_H - 12
		var cx: float = start_x + CURRENT_TILE_SLOT * TILE_W + TILE_W / 2.0 + TILE_SHEAR / 2.0
		var cy: float = tile_y + TILE_H / 2.0
		hero.position = Vector2(cx - hero.size.x / 2.0, cy - hero.size.y + 10 + _bounce_offset)


func _on_move_complete() -> void:
	var gtype: int = map_grids[player_grid_index % map_total_grids]
	var ctx := {
		"player_level": player_level,
		"player_gold": player_gold,
		"player_revive": player_revive,
		"player_hp": player_hp,
		"player_max_hp": player_max_hp,
		"player_name": player_name,
		"boss_tier": player_boss_tier,
		"boss_index": player_boss_index,
		"equip_instances": equip_instances,
		"equipment": equipment,
		"player_state": _build_player_battle_state(),
	}
	var result: Dictionary = executor.execute(gtype, ctx)
	player_gold = int(ctx.get("player_gold", player_gold))
	player_revive = int(ctx.get("player_revive", player_revive))
	player_hp = clampi(int(ctx.get("player_hp", player_hp)), 0, player_max_hp)
	print("[Grid] 格子类型=", gtype, " → ", result["event"])

	var edata: Dictionary = result.get("data", {})
	if edata.has("battle_result"):
		_apply_battle_result(edata)
		top_bar.check_poker_hand()
		_check_lottery_draw()
		top_bar.refresh()
		top_bar.refresh_compact_stats()
		_auto_save()
		_show_battle_view(edata)
		return

	if edata.get("type", "") == "equip":
		var eqp: Dictionary = edata.get("equip", {})
		if not eqp.is_empty():
			_show_float_text("获得装备 " + EquipGenCls.full_name(eqp), Color(1.0, 0.85, 0.3))
	elif edata.get("type", "") == "gem":
		_add_gem(int(edata.get("gem_id", 0)), int(edata.get("level", 1)), 1)
	elif edata.has("jump"):
		var jump_val: int = edata["jump"]
		_do_lightning_jump(jump_val)
		return

	var msg: String = edata.get("message", "")
	if not msg.is_empty():
		var clr: Color = Color(1.0, 0.85, 0.3)
		if edata.get("type", "") == "punish":
			clr = Color(1.0, 0.4, 0.4)
		elif edata.get("type", "") == "bless":
			clr = Color(0.3, 1.0, 0.6)
		_show_float_text(msg, clr)

	if edata.get("name", "") in ["技能大赛", "攻击削弱"]:
		var turns: int = 3
		var bname: String = edata["name"]
		var bt: String = "dmg_x" + ("1.3" if bname == "技能大赛" else "0.7")
		_add_buff(bname, bt, turns)

	top_bar.check_poker_hand()
	_check_lottery_draw()

	if edata.has("exp_gain") and not edata.has("battle_result"):
		_add_exp(int(edata["exp_gain"]))

	top_bar.refresh()
	top_bar.refresh_compact_stats()
	_auto_save()
	if auto_play_enabled:
		_start_auto_timer()


func _build_player_battle_state() -> Dictionary:
	var ps: Dictionary = _calc_player_stats()
	return {
		"name": player_name,
		"level": player_level,
		"current_hp": player_hp,
		"max_hp": player_max_hp,
		"atk": ps.get("atk", 25),
		"def": ps.get("def", 15),
		"speed_points": int(ps.get("spd", 0)),
		"crit": ps.get("crit", 0),
		"critdmg": ps.get("critdmg", 150),
		"hit": ps.get("hit", 0),
		"dodge": ps.get("dodge", 0),
		"block": ps.get("block", 0),
		"skill_dmg": ps.get("skill_dmg", 0),
		"cd_reduce": ps.get("cd_reduce", 0),
		"lifesteal": ps.get("lifesteal", 0.0),
		"free_atk_pct": ps.get("free_atk_pct", 0.0),
		"free_def_pct": ps.get("free_def_pct", 0.0),
		"gold_bonus": ps.get("gold_bonus", 0.0),
		"exp_bonus": ps.get("exp_bonus", 0.0),
		"skill_slots": skill_system.to_dict().get("slots", []).duplicate(true),
		"battle_damage_mult": _calc_battle_damage_mult(),
		"set_counts": _count_equipped_suits(),
		"battle_gold": player_gold,
	}


func _show_battle_view(edata: Dictionary) -> void:
	var area := get_node_or_null("MapArea") as Control
	if not area or area.get_node_or_null("BattleView"):
		return
	_stop_auto_timer()
	var view: Control = BattleViewCls.new()
	view.name = "BattleView"
	area.add_child(view)
	view.closed.connect(func():
		if auto_play_enabled:
			_start_auto_timer()
	)
	view.setup(edata)


func _calc_battle_damage_mult() -> float:
	var mult: float = 1.0
	for buff in active_buffs:
		match String(buff.get("type", "")):
			"dmg_x1.3":
				mult *= 1.3
			"dmg_x0.7":
				mult *= 0.7
	return mult


func _apply_battle_result(edata: Dictionary) -> void:
	var battle_result: Dictionary = edata.get("battle_result", {})
	if battle_result.is_empty():
		return
	player_hp = clampi(int(battle_result.get("player_hp", player_hp)), 0, player_max_hp)
	if edata.has("exp_gain"):
		_add_exp(int(edata.get("exp_gain", 0)))
	var drop_names: Array[String] = _grant_battle_drops(edata.get("drops", []))
	if not drop_names.is_empty():
		if drop_names.size() == 1:
			_show_float_text("获得掉落 " + drop_names[0], Color(0.9, 0.8, 0.3))
		else:
			_show_float_text("获得掉落 " + str(drop_names.size()) + " 件", Color(0.9, 0.8, 0.3))
	_tick_buffs()
	if bool(edata.get("boss_cleared", false)):
		_handle_boss_clear()
	if bool(edata.get("force_home", false)):
		player_grid_index = 0
		_refresh_grid_display()
	_refresh_player_hp_bounds(false)


func _grant_battle_drops(drops: Array) -> Array[String]:
	var names: Array[String] = []
	for raw in drops:
		var drop: Dictionary = raw
		var kind: String = String(drop.get("kind", ""))
		if kind in ["equip", "boss"]:
			var eqp: Dictionary = _roll_drop_equip(drop)
			if not eqp.is_empty():
				equip_instances.append(eqp)
				names.append(EquipGenCls.full_name(eqp))
	return names


func _roll_drop_equip(drop: Dictionary) -> Dictionary:
	var kind: String = String(drop.get("kind", "equip"))
	if kind == "equip" and drop.has("chance") and randf() > float(drop.get("chance", 0.0)):
		return {}
	var options: Dictionary = {"boss_tier": player_boss_tier}
	if kind == "boss":
		options["min_quality"] = 3
		options["max_quality"] = 4
	else:
		if drop.has("quality_floor"):
			options["min_quality"] = int(drop.get("quality_floor", 0))
	var eqp: Dictionary = EquipGenCls.generate(_random_drop_slot(), player_level, options)
	var suits := _count_equipped_suits()
	if int(suits.get("引力", 0)) >= 4 and not str(eqp.get("suit_name", "")).is_empty():
		var luck := int(_calc_player_stats().get("luk", 0))
		if randf() < 0.01 + float(luck) * 0.002:
			var candidates: Array[String] = []
			for set_def in EquipGenCls.SET_POOL:
				var set_name := str(set_def.get("name", ""))
				if not set_name.is_empty() and set_name != str(eqp.get("suit_name", "")):
					candidates.append(set_name)
			if not candidates.is_empty():
				eqp["extra_suit_name"] = candidates[randi() % candidates.size()]
	return eqp


func _random_drop_slot() -> String:
	var slots: Array[String] = ["weapon", "armor", "shoes", "ring", "necklace", "cape", "helmet", "charm"]
	return slots[randi() % slots.size()]


func _handle_boss_clear() -> void:
	player_boss_tier += 1
	player_boss_index = mini(player_boss_tier + 1, 100)
	var old_total: int = map_total_grids
	if player_boss_tier <= 20:
		var new_total: int = mini(128, 28 + player_boss_tier * 5)
		if new_total > old_total:
			_rebuild_map_for_boss_clear(old_total, new_total)
			_show_float_text("👑 Boss击破！地图扩张到 " + str(map_total_grids) + " 格", Color(1.0, 0.75, 0.25))
	_refresh_grid_display()


func _rebuild_map_for_boss_clear(old_total: int, new_total: int) -> void:
	var previous_map: Array[int] = map_grids.duplicate()
	if previous_map.is_empty():
		_generate_mock_map()
		previous_map = map_grids.duplicate()
	var protected_indices: Array[int] = _collect_protected_indices(old_total)
	var protected_map: Dictionary = {}
	for idx in protected_indices:
		protected_map[idx] = previous_map[idx]
	map_total_grids = new_total
	var rebuilt: Array[int] = []
	rebuilt.resize(new_total)
	for i in range(new_total):
		rebuilt[i] = -1
	for idx in protected_indices:
		rebuilt[idx] = int(protected_map[idx])
	var counts: Dictionary = _count_grid_types(previous_map)
	for grid_type in _roll_expansion_grid_types(player_boss_tier, new_total - old_total):
		counts[grid_type] = int(counts.get(grid_type, 0)) + 1
	for grid_type in protected_map.values():
		counts[grid_type] = maxi(int(counts.get(grid_type, 0)) - 1, 0)
	var pending_types: Array[int] = _build_pending_grid_types_from_counts(counts, new_total - protected_indices.size())
	pending_types = _shuffle_grid_pool_with_constraints(pending_types)
	var pool_idx: int = 0
	for i in range(new_total):
		if rebuilt[i] != -1:
			continue
		if pool_idx >= pending_types.size():
			rebuilt[i] = GridExecutorCls.GridType.BATTLE
		else:
			rebuilt[i] = pending_types[pool_idx]
			pool_idx += 1
	map_grids.clear()
	for cell in rebuilt:
		map_grids.append(int(cell))
	_refresh_lottery_cycle_after_expansion(old_total, new_total)


func _collect_protected_indices(total: int) -> Array[int]:
	var indices: Array[int] = []
	for offset in range(-EXPANSION_PROTECT_RADIUS, EXPANSION_PROTECT_RADIUS + 1):
		var idx: int = posmod(player_grid_index + offset, total)
		if not indices.has(idx):
			indices.append(idx)
	indices.sort()
	return indices


func _count_grid_types(grid_list: Array[int]) -> Dictionary:
	var counts: Dictionary = {}
	for grid_type in grid_list:
		counts[grid_type] = int(counts.get(grid_type, 0)) + 1
	return counts


func _roll_expansion_grid_types(boss_tier: int, add_count: int) -> Array[int]:
	var plan: Array[int] = _get_expansion_addition_plan(boss_tier)
	var result: Array[int] = []
	for i in range(mini(add_count, plan.size())):
		result.append(plan[i])
	while result.size() < add_count:
		result.append(GridExecutorCls.GridType.BATTLE)
	return result


func _get_expansion_addition_plan(boss_tier: int) -> Array[int]:
	match boss_tier:
		1:
			return [GridExecutorCls.GridType.BATTLE, GridExecutorCls.GridType.BATTLE, GridExecutorCls.GridType.ELITE, GridExecutorCls.GridType.TREASURE, GridExecutorCls.GridType.EMPTY]
		2:
			return [GridExecutorCls.GridType.BATTLE, GridExecutorCls.GridType.BATTLE, GridExecutorCls.GridType.FATE, GridExecutorCls.GridType.FORGE, GridExecutorCls.GridType.EMPTY2]
		3:
			return [GridExecutorCls.GridType.BATTLE, GridExecutorCls.GridType.BATTLE, GridExecutorCls.GridType.ELITE, GridExecutorCls.GridType.TREASURE, GridExecutorCls.GridType.EMPTY2]
		4:
			return [GridExecutorCls.GridType.BATTLE, GridExecutorCls.GridType.BATTLE, GridExecutorCls.GridType.FATE, GridExecutorCls.GridType.FATE, GridExecutorCls.GridType.SYNTH]
		5:
			return [GridExecutorCls.GridType.BATTLE, GridExecutorCls.GridType.BATTLE, GridExecutorCls.GridType.ELITE, GridExecutorCls.GridType.TREASURE, GridExecutorCls.GridType.SYNTH]
		6:
			return [GridExecutorCls.GridType.BATTLE, GridExecutorCls.GridType.BATTLE, GridExecutorCls.GridType.FATE, GridExecutorCls.GridType.FORGE, GridExecutorCls.GridType.GOD]
		7:
			return [GridExecutorCls.GridType.BATTLE, GridExecutorCls.GridType.BATTLE, GridExecutorCls.GridType.ELITE, GridExecutorCls.GridType.TREASURE, GridExecutorCls.GridType.GOD]
		8:
			return [GridExecutorCls.GridType.BATTLE, GridExecutorCls.GridType.BATTLE, GridExecutorCls.GridType.FATE, GridExecutorCls.GridType.GOD, GridExecutorCls.GridType.LIGHT]
		9:
			return [GridExecutorCls.GridType.BATTLE, GridExecutorCls.GridType.BATTLE, GridExecutorCls.GridType.ELITE, GridExecutorCls.GridType.TREASURE, GridExecutorCls.GridType.LIGHT]
		10:
			return [GridExecutorCls.GridType.BATTLE, GridExecutorCls.GridType.BATTLE, GridExecutorCls.GridType.FATE, GridExecutorCls.GridType.FORGE, GridExecutorCls.GridType.CHALLENG]
		11:
			return [GridExecutorCls.GridType.BATTLE, GridExecutorCls.GridType.BATTLE, GridExecutorCls.GridType.ELITE, GridExecutorCls.GridType.TREASURE, GridExecutorCls.GridType.CHALLENG]
		12:
			return [GridExecutorCls.GridType.BATTLE, GridExecutorCls.GridType.BATTLE, GridExecutorCls.GridType.FATE, GridExecutorCls.GridType.GOD, GridExecutorCls.GridType.EMPTY2]
		13:
			return [GridExecutorCls.GridType.BATTLE, GridExecutorCls.GridType.BATTLE, GridExecutorCls.GridType.ELITE, GridExecutorCls.GridType.TREASURE, GridExecutorCls.GridType.EMPTY2]
		14:
			return [GridExecutorCls.GridType.BATTLE, GridExecutorCls.GridType.BATTLE, GridExecutorCls.GridType.FATE, GridExecutorCls.GridType.EMPTY2, GridExecutorCls.GridType.BOSS]
		15:
			return [GridExecutorCls.GridType.BATTLE, GridExecutorCls.GridType.BATTLE, GridExecutorCls.GridType.ELITE, GridExecutorCls.GridType.TREASURE, GridExecutorCls.GridType.BOSS]
		16:
			return [GridExecutorCls.GridType.BATTLE, GridExecutorCls.GridType.BATTLE, GridExecutorCls.GridType.FATE, GridExecutorCls.GridType.FORGE, GridExecutorCls.GridType.EMPTY2]
		17:
			return [GridExecutorCls.GridType.BATTLE, GridExecutorCls.GridType.BATTLE, GridExecutorCls.GridType.ELITE, GridExecutorCls.GridType.TREASURE, GridExecutorCls.GridType.EMPTY2]
		18:
			return [GridExecutorCls.GridType.BATTLE, GridExecutorCls.GridType.BATTLE, GridExecutorCls.GridType.FATE, GridExecutorCls.GridType.GOD, GridExecutorCls.GridType.BOSS]
		19:
			return [GridExecutorCls.GridType.BATTLE, GridExecutorCls.GridType.BATTLE, GridExecutorCls.GridType.ELITE, GridExecutorCls.GridType.TREASURE, GridExecutorCls.GridType.EMPTY2]
		20:
			return [GridExecutorCls.GridType.BATTLE, GridExecutorCls.GridType.BATTLE, GridExecutorCls.GridType.REST, GridExecutorCls.GridType.FORGE, GridExecutorCls.GridType.EMPTY2]
		_:
			return []


func _build_pending_grid_types_from_counts(counts: Dictionary, expected_size: int) -> Array[int]:
	var pool: Array[int] = []
	var ordered_types: Array[int] = [
		GridExecutorCls.GridType.HOME,
		GridExecutorCls.GridType.BATTLE,
		GridExecutorCls.GridType.ELITE,
		GridExecutorCls.GridType.CHALLENG,
		GridExecutorCls.GridType.REST,
		GridExecutorCls.GridType.TREASURE,
		GridExecutorCls.GridType.FORGE,
		GridExecutorCls.GridType.FATE,
		GridExecutorCls.GridType.GOD,
		GridExecutorCls.GridType.SYNTH,
		GridExecutorCls.GridType.LIGHT,
		GridExecutorCls.GridType.BOSS,
		GridExecutorCls.GridType.EMPTY,
		GridExecutorCls.GridType.EMPTY2,
	]
	for grid_type in ordered_types:
		var amount: int = maxi(int(counts.get(grid_type, 0)), 0)
		for _i in range(amount):
			pool.append(grid_type)
	while pool.size() < expected_size:
		pool.append(GridExecutorCls.GridType.BATTLE)
	if pool.size() > expected_size:
		pool.resize(expected_size)
	return pool


func _shuffle_grid_pool_with_constraints(pool: Array[int]) -> Array[int]:
	if pool.size() <= 1:
		return pool
	var best: Array[int] = pool.duplicate()
	for _attempt in range(EXPANSION_RESHUFFLE_ATTEMPTS):
		var candidate: Array[int] = pool.duplicate()
		_shuffle_int_array(candidate)
		if _passes_grid_distance_rules(candidate):
			return candidate
		best = candidate
	return best


func _shuffle_int_array(arr: Array[int]) -> void:
	for i in range(arr.size() - 1, 0, -1):
		var j: int = randi_range(0, i)
		var tmp: int = arr[i]
		arr[i] = arr[j]
		arr[j] = tmp


func _passes_grid_distance_rules(pool: Array[int]) -> bool:
	if not _check_min_gap(pool, GridExecutorCls.GridType.ELITE, 3):
		return false
	if not _check_min_gap(pool, GridExecutorCls.GridType.REST, 5):
		return false
	if not _check_min_gap(pool, GridExecutorCls.GridType.EMPTY2, 6):
		return false
	if not _check_cross_gap(pool, GridExecutorCls.GridType.LIGHT, GridExecutorCls.GridType.BOSS, 8):
		return false
	if not _check_max_consecutive(pool, GridExecutorCls.GridType.EMPTY2, 2):
		return false
	return true


func _check_min_gap(pool: Array[int], target_type: int, min_gap: int) -> bool:
	var positions: Array[int] = []
	for i in range(pool.size()):
		if pool[i] == target_type:
			positions.append(i)
	if positions.size() <= 1:
		return true
	for i in range(positions.size()):
		for j in range(i + 1, positions.size()):
			if positions[j] - positions[i] < min_gap:
				return false
	return true


func _check_cross_gap(pool: Array[int], type_a: int, type_b: int, min_gap: int) -> bool:
	var positions_a: Array[int] = []
	var positions_b: Array[int] = []
	for i in range(pool.size()):
		if pool[i] == type_a:
			positions_a.append(i)
		elif pool[i] == type_b:
			positions_b.append(i)
	if positions_a.is_empty() or positions_b.is_empty():
		return true
	for a in positions_a:
		for b in positions_b:
			if absi(a - b) < min_gap:
				return false
	return true


func _check_max_consecutive(pool: Array[int], target_type: int, max_run: int) -> bool:
	var run: int = 0
	for grid_type in pool:
		if grid_type == target_type:
			run += 1
			if run > max_run:
				return false
		else:
			run = 0
	return true


func _refresh_lottery_cycle_after_expansion(old_total: int, new_total: int) -> void:
	if lottery_tickets.is_empty() or lottery_draw_at <= 0:
		return
	var old_cycle: int = maxi(int(ceil(float(old_total) / 7.0)), 1)
	var new_cycle: int = maxi(int(ceil(float(new_total) / 7.0)), 1)
	var progressed: int = clampi(old_cycle - lottery_draw_at, 0, old_cycle)
	lottery_draw_at = maxi(new_cycle - progressed, 1)


func _auto_save() -> void:
	if _current_slot < 0:
		return
	var sm = _sm()
	if sm:
		sm.save_game(_current_slot, _build_save_data())


## ============================================================
## 经验/升级系统
## ============================================================
## 增加经验，若经验满则自动升级
func _add_exp(amount: int) -> void:
	if amount <= 0:
		return
	player_exp += amount
	while player_exp >= player_exp_max:
		player_exp -= player_exp_max
		player_level += 1
		player_free_points += 2
		player_exp_max = int(100.0 * pow(1.12, player_level - 1))
		_refresh_player_hp_bounds(false)
		_show_float_text("🎉 升级! Lv." + str(player_level) + " 获得2点自由属性点", Color(0.3, 1.0, 0.6))
	top_bar.refresh()


## 消耗自由属性点加点
func _add_free_stat(stat_name: String) -> void:
	if player_free_points <= 0:
		_show_float_text("没有可用属性点", Color(0.6, 0.6, 0.7))
		return
	match stat_name:
		"atk":
			player_stat_atk += 1
		"def":
			player_stat_def += 1
		"spd":
			player_stat_spd += 1
		"luk":
			player_stat_luk += 1
		_:
			return
	player_free_points -= 1
	_refresh_all_stats_panels()


## 洗点：重置自由属性点
func _reset_stats() -> void:
	var cost: int = player_level * 200
	if player_gold < cost:
		_show_float_text("金币不足！洗点需要 " + str(cost) + " 金", Color(1.0, 0.3, 0.3))
		return
	var total_used: int = player_stat_atk + player_stat_def + player_stat_spd + player_stat_luk
	if total_used <= 0 and player_free_points > 0:
		_show_float_text("没有已分配的属性点需要重置", Color(0.6, 0.6, 0.7))
		return
	if total_used <= 0:
		return
	player_gold -= cost
	player_free_points += total_used
	player_stat_atk = 0
	player_stat_def = 0
	player_stat_spd = 0
	player_stat_luk = 0
	_show_float_text("洗点成功！消耗 " + str(cost) + " 金币，归还 " + str(total_used) + " 自由属性点", Color(0.3, 1.0, 0.6))
	_refresh_all_stats_panels()


## ============ 闪电跳跃 ============
func _do_lightning_jump(jump_val: int) -> void:
	_show_float_text("⚡ 闪电跳跃 " + str(jump_val) + " 格！", Color(1.0, 1.0, 0.3))
	# 粒子特效(竖着上升)
	_spawn_lightning_particles()
	# 跳跃
	player_grid_index = (player_grid_index + jump_val) % map_total_grids
	_refresh_grid_display()
	_on_move_complete()  # 触发新格子


func _spawn_lightning_particles() -> void:
	var hero: TextureRect = get_node_or_null("MapArea/HeroOnMap") as TextureRect
	if not hero: return
	var particles := CPUParticles2D.new()
	particles.emitting = true
	particles.amount = 20
	particles.lifetime = 0.8
	particles.direction = Vector2(0, -1)
	particles.spread = 30.0
	particles.gravity = Vector2(0, 0)
	particles.initial_velocity_min = 80.0
	particles.initial_velocity_max = 160.0
	particles.color = Color(1.0, 1.0, 0.3, 0.8)
	particles.scale_amount_min = 2.0
	particles.scale_amount_max = 4.0
	particles.position = hero.position + Vector2(hero.size.x/2, hero.size.y/2)
	hero.get_parent().add_child(particles)
	# 人物闪烁消失
	var tw := create_tween()
	tw.tween_property(hero, "modulate:a", 0.0, 0.3)
	tw.tween_property(hero, "modulate:a", 1.0, 0.3)
	hero.modulate.a = 1.0
	# 自动清理粒子
	var t := get_tree().create_timer(1.5)
	t.timeout.connect(particles.queue_free)


## ============ Buff 管理 ============
func _add_buff(name: String, type_tag: String, turns: int) -> void:
	active_buffs.append({ "name": name, "type": type_tag, "turns": turns })
	_show_float_text(name + "(" + str(turns) + "场)", Color(0.3, 1.0, 0.6))


func _tick_buffs() -> void:
	for i in range(active_buffs.size() - 1, -1, -1):
		active_buffs[i]["turns"] -= 1
		if active_buffs[i]["turns"] <= 0:
			active_buffs.remove_at(i)


## ============ 彩票开奖 ============
func _check_lottery_draw() -> void:
	if lottery_tickets.is_empty() or lottery_draw_at <= 0:
		if lottery_tickets.size() > 0 and lottery_draw_at <= 0:
			lottery_draw_at = int(ceil(map_total_grids / 7.0))  # 约5圈
		return
	lottery_draw_at -= 1
	if lottery_draw_at > 0:
		return

	# 开奖
	var win_num: int = randi_range(0, 999)
	var win_s: String = _fmt_lottery(win_num)
	var hit: bool = lottery_tickets.has(win_num)

	_show_lottery_popup(win_s, hit)
	lottery_tickets.clear()
	lottery_draw_at = int(ceil(map_total_grids / 7.0))


func _show_lottery_popup(win_num: String, hit: bool) -> void:
	# 遮罩
	var ov: ColorRect = ColorRect.new()
	ov.name = "LotteryOverlay"
	ov.position = Vector2(0, 0)
	ov.size = Vector2(1280, 720)
	ov.color = Color(0, 0, 0, 0.6)
	add_child(ov)

	# 弹窗
	var popup: Panel = Panel.new()
	popup.position = Vector2(390, 180)
	popup.size = Vector2(500, 320)
	UIUtils.panel_style(popup, Color(0.08, 0.06, 0.15, 0.98))
	ov.add_child(popup)

	var title: Label = Label.new()
	title.text = "🎰 彩票开奖"
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.position = Vector2(0, 20)
	title.size = Vector2(500, 36)
	popup.add_child(title)

	# 中奖号码
	var num_lbl: Label = Label.new()
	num_lbl.text = win_num
	num_lbl.add_theme_font_size_override("font_size", 72)
	num_lbl.add_theme_color_override("font_color", Color(1.0, 0.9, 0.1))
	num_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	num_lbl.position = Vector2(0, 80)
	num_lbl.size = Vector2(500, 80)
	popup.add_child(num_lbl)

	if hit:
		var win_lbl: Label = Label.new()
		win_lbl.text = "🎉 恭喜中奖！ 🎉"
		win_lbl.add_theme_font_size_override("font_size", 32)
		win_lbl.add_theme_color_override("font_color", Color(1.0, 0.3, 0.8))
		win_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		win_lbl.position = Vector2(0, 180)
		win_lbl.size = Vector2(500, 44)
		popup.add_child(win_lbl)

		var rewards: Label = Label.new()
		rewards.text = "💰 金币  🟢宝石  ⚔️稀有装备  📦金币大包  🎴史诗卡  🟣史诗装备  🟠传说装备"
		rewards.add_theme_font_size_override("font_size", 13)
		rewards.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
		rewards.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		rewards.position = Vector2(0, 240)
		rewards.size = Vector2(500, 30)
		popup.add_child(rewards)

		# 彩带粒子
		_spawn_confetti(ov)
	else:
		var lose_lbl: Label = Label.new()
		lose_lbl.text = "未中奖，彩票已清空"
		lose_lbl.add_theme_font_size_override("font_size", 18)
		lose_lbl.add_theme_color_override("font_color", Color(0.5, 0.5, 0.6))
		lose_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lose_lbl.position = Vector2(0, 200)
		lose_lbl.size = Vector2(500, 30)
		popup.add_child(lose_lbl)

	# 3秒后关闭
	var t := get_tree().create_timer(3.0)
	t.timeout.connect(func():
		if is_instance_valid(ov): ov.queue_free()
	)


func _spawn_confetti(parent: Control) -> void:
	var particles := CPUParticles2D.new()
	particles.emitting = true
	particles.amount = 60
	particles.lifetime = 1.5
	particles.gravity = Vector2(0, 80)
	particles.initial_velocity_min = 100.0
	particles.initial_velocity_max = 300.0
	particles.spread = 180.0
	particles.position = Vector2(640, 240)
	particles.color = Color(1.0, 0.8, 0.2, 0.9)
	particles.scale_amount_min = 3.0
	particles.scale_amount_max = 6.0
	parent.add_child(particles)
	var t := get_tree().create_timer(3.0)
	t.timeout.connect(particles.queue_free)


## ============================================================
## 扑克牌牌型检测
## ============================================================


## 统一刷新所有属性面板（穿脱装备后调用）
func _refresh_all_stats_panels() -> void:
	_refresh_player_hp_bounds(false)
	top_bar.refresh()
	top_bar.refresh_compact_stats()
	# 如果属性面板正打开着，关闭后下次打开会显示最新值
	var sp: Node = get_node_or_null("StatsPanel")
	if sp:
		sp.queue_free()


func _refresh_grid_display() -> void:
	var area := get_node_or_null("MapArea")
	if not area:
		return
	var idx := player_grid_index
	var offsets: Array[int] = []
	for offset in range(-VISIBLE_BEFORE, VISIBLE_AFTER + 1):
		offsets.append(offset)
	var slot_names: Array[String] = TILE_SLOT_NAMES

	for i in range(TILE_COUNT):
		var grid_idx: int = idx + offsets[i]
		var tile = area.get_node(slot_names[i])
		if not tile:
			continue

		var info := _get_grid_info(grid_idx)
		var is_current := (i == CURRENT_TILE_SLOT)
		var clr: Color = info["clr"]
		var fill: Color = clr.lightened(0.24) if is_current else clr.lightened(0.52)
		var border: Color = Color("d9a441") if is_current else Color("ab7772")
		tile.setup(info["icon"], info["name"] + "#" + str(grid_idx), fill, border)

		# 视野外格子半透明
		var dist := absi(i - CURRENT_TILE_SLOT)
		tile.modulate.a = 1.0 if dist <= 2 else maxf(0.15, 1.0 - (dist - 2) * 0.28)

	# 主角位置更新
	var hero: TextureRect = area.get_node_or_null("HeroOnMap") as TextureRect
	if hero:
		_position_hero_on_tile(hero, CURRENT_TILE_SLOT)

	var pos_lbl: Label = area.get_node("MapStatusPanel/GridPosLabel") as Label
	if pos_lbl:
		pos_lbl.text = "格子 " + str(idx + 1) + " / " + str(map_total_grids) + "  ·  Boss " + str(player_boss_index - 1) + " / 100"


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
	UIUtils.panel_style(popup, Color(0.12, 0.12, 0.20, 0.94))

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
	suit_label.add_theme_color_override("font_color", UIUtils.suit_color(suit))
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


## 画面正中偏上，渐入上浮渐出，3秒消失，新提示顶替旧提示
func _show_float_text(text: String, clr: Color = Color.WHITE) -> void:
	if _float_text_node and is_instance_valid(_float_text_node):
		_float_text_node.queue_free()

	# 确保浮字在最上层（使用独立 CanvasLayer）
	var layer: CanvasLayer = get_node_or_null("FloatTextLayer")
	if not layer:
		layer = CanvasLayer.new()
		layer.name = "FloatTextLayer"
		layer.layer = 128  # 最高渲染层
		add_child(layer)

	var lbl: Label = Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 26)
	lbl.add_theme_color_override("font_color", clr)
	lbl.add_theme_color_override("font_outline_color", Color.BLACK)
	lbl.add_theme_constant_override("outline_size", 4)
	lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.72))
	lbl.add_theme_constant_override("shadow_offset_x", 2)
	lbl.add_theme_constant_override("shadow_offset_y", 3)
	lbl.add_theme_constant_override("shadow_outline_size", 2)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.position = Vector2(390, 270)
	lbl.size = Vector2(500, 44)
	lbl.modulate.a = 0.0
	layer.add_child(lbl)
	_float_text_node = lbl

	var tw := create_tween()
	tw.set_parallel(false)
	tw.tween_property(lbl, "modulate:a", 1.0, 0.2)
	tw.tween_property(lbl, "position:y", 225, 1.8)
	tw.parallel().tween_property(lbl, "modulate:a", 0.0, 1.8)
	tw.tween_callback(func():
		if _float_text_node == lbl:
			_float_text_node = null
		if is_instance_valid(lbl):
			lbl.queue_free()
	)


## 统计已装备中各套装的件数
func _count_equipped_suits() -> Dictionary:
	var counts: Dictionary = {}
	for ei in range(equip_instances.size()):
		var ep: Dictionary = equip_instances[ei]
		if not ep.get("equipped", false):
			continue
		var sn: String = ep.get("suit_name", "")
		if not sn.is_empty():
			counts[sn] = counts.get(sn, 0) + 1
		var extra_sn: String = ep.get("extra_suit_name", "")
		if not extra_sn.is_empty() and extra_sn != sn:
			counts[extra_sn] = counts.get(extra_sn, 0) + 1
	return counts

func _close_all_tooltips() -> void:
	for t in _tooltip_nodes:
		if is_instance_valid(t):
			t.queue_free()
	_tooltip_nodes.clear()
	# 移除遮罩层
	var ov: Node = get_node_or_null("TooltipOverlay")
	if ov:
		ov.queue_free()
	# 也清理确认对话框（可能因遮罩点击而触发）
	var d1: Node = get_node_or_null("ExpansionConfirm")
	if d1:
		d1.queue_free()
	var d2: Node = get_node_or_null("ResetConfirmDialog")
	if d2:
		d2.queue_free()

func _on_test_generate_equip() -> void:
	var slots: Array[String] = ["weapon","armor","shoes","ring","necklace","cape","helmet","charm"]
	var slot: String = slots[randi() % slots.size()]
	var eqp: Dictionary = EquipGenCls.generate(slot, player_level)
	equip_instances.append(eqp)
	print("[装备测试] 生成:", EquipGenCls.full_name(eqp), "品质:", eqp["quality_name"], "孔数:", eqp["gem_slots"])
	_auto_save()


func _on_test_generate_gem() -> void:
	var gid: int = randi_range(1, 8)
	_add_gem(gid, 1, 1)
	var gdef: Dictionary = EquipData.GEM_DEFS.get(gid, {})
	_show_float_text(gdef.get("icon", "🔘") + " " + gdef.get("name", "???") + " Lv.1", Color(1, 0.7, 0.3))


## 添加宝石到背包
func _add_gem(gid: int, lv: int, cnt: int) -> void:
	for g in gem_bag:
		if g["id"] == gid and g["level"] == lv:
			g["count"] += cnt
			return
	gem_bag.append({ "id": gid, "level": lv, "count": cnt })


## 宝石合成：右键同等级宝石
func _synthesize_gem(gid: int, lv: int) -> void:
	var idx: int = -1
	for i in range(gem_bag.size()):
		if gem_bag[i]["id"] == gid and gem_bag[i]["level"] == lv:
			idx = i
			break
	if idx < 0 or gem_bag[idx]["count"] < 3:
		_show_float_text("需要3颗同等级宝石才能合成", Color(1, 0.4, 0.4))
		return
	gem_bag[idx]["count"] -= 3
	if gem_bag[idx]["count"] <= 0:
		gem_bag.remove_at(idx)
	_add_gem(gid, lv + 1, 1)
	var gdef: Dictionary = EquipData.GEM_DEFS.get(gid, {})
	_show_float_text(gdef.get("icon", "🔘") + " 合成 → Lv." + str(lv + 1), Color(0.3, 1.0, 0.6))


func _on_test_generate_lottery() -> void:
	if lottery_tickets.size() >= 10:
		_show_float_text("彩票已满（最多10张）", Color(1, 0.4, 0.4))
		return
	var num: int = randi_range(0, 999)
	lottery_tickets.append(num)
	_show_float_text("🎟️ 获得彩票 " + _fmt_lottery(num), Color(1, 0.7, 0.2))


func _fmt_lottery(num: int) -> String:
	return str(num).pad_zeros(3)


func _build_lottery_tab(area: Panel, _main_panel: Panel) -> void:
	var gap: float = 10.0
	var sy: float = gap

	var title: Label = Label.new()
	title.text = "🎫 彩票 (" + str(lottery_tickets.size()) + "/10)"
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_color_override("font_color", Color(1.0, 0.8, 0.3))
	title.position = Vector2(gap, sy)
	area.add_child(title)
	sy += 28

	if lottery_tickets.is_empty():
		var empty_lbl: Label = Label.new()
		empty_lbl.text = "暂无彩票，走到彩票格可获取"
		empty_lbl.add_theme_font_size_override("font_size", 12)
		empty_lbl.add_theme_color_override("font_color", Color(0.4, 0.45, 0.5))
		empty_lbl.position = Vector2(gap, sy + 20)
		area.add_child(empty_lbl)

	for tx in range(lottery_tickets.size()):
		var row_y: float = sy + tx * 44
		if row_y > 280:
			break

		# 彩票卡片
		var card: Panel = Panel.new()
		card.position = Vector2(gap, row_y)
		card.size = Vector2(300, 38)
		var cs := StyleBoxFlat.new()
		cs.bg_color = Color(0.08, 0.08, 0.15)
		cs.border_width_left = 1; cs.border_width_right = 1
		cs.border_width_top = 1; cs.border_width_bottom = 1
		cs.border_color = Color(1.0, 0.6, 0.2, 0.5)
		cs.set_corner_radius_all(6)
		card.add_theme_stylebox_override("panel", cs)
		area.add_child(card)

		# 数字（大字）
		var num_lbl: Label = Label.new()
		num_lbl.text = _fmt_lottery(lottery_tickets[tx])
		num_lbl.add_theme_font_size_override("font_size", 28)
		num_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
		num_lbl.position = Vector2(gap + 12, row_y + 2)
		area.add_child(num_lbl)

		# 编号
		var idx_lbl: Label = Label.new()
		idx_lbl.text = "#" + str(tx + 1)
		idx_lbl.add_theme_font_size_override("font_size", 9)
		idx_lbl.add_theme_color_override("font_color", Color(0.4, 0.45, 0.5))
		idx_lbl.position = Vector2(gap + 100, row_y + 4)
		area.add_child(idx_lbl)

	sy += lottery_tickets.size() * 44 + 20

	# 底部说明
	var rounds_left: int = 10 - (player_grid_index / map_total_grids) % 10
	rounds_left = maxi(1, rounds_left)
	var footer: Label = Label.new()
	footer.text = "🔄 还有 " + str(rounds_left) + " 圈开奖  |  中奖号码 = 开奖时随机生成的3位数字"
	footer.add_theme_font_size_override("font_size", 11)
	footer.add_theme_color_override("font_color", Color(0.5, 0.55, 0.6))
	footer.position = Vector2(gap, sy)
	footer.size = Vector2(640, 20)
	area.add_child(footer)


func _on_bag_pressed() -> void:
	_show_inventory_panel()
func _on_skill_pressed() -> void:
	_stats_tab = "skill"
	_show_stats_panel()
func _on_log_pressed()     -> void: print("[主界面] 打开日志")
func _on_settings_pressed()-> void:
	_auto_save()
	if get_tree():
		get_tree().change_scene_to_file("res://scenes/select_slot.tscn")


## ============ 背包 UI 面板 (重制版) ============
var _inv_tab: String = "equip"   # "consume" | "equip"
var _inv_filter_quality: Array[int] = []   # 空=全部, 选中多个
var _inv_filter_slot: Array[int] = []       # 空=全部, 选中多个

## 洗点确认弹窗
func _show_reset_confirm() -> void:
	if get_node_or_null("ResetConfirmDialog"):
		return

	var cost: int = player_level * 200
	var total_used: int = player_stat_atk + player_stat_def + player_stat_spd + player_stat_luk
	if total_used <= 0:
		_show_float_text("没有已分配的属性点需要重置", Color(0.6, 0.6, 0.7))
		return
	if player_gold < cost:
		_show_float_text("金币不足！洗点需要 " + str(cost) + " 金", Color(1.0, 0.3, 0.3))
		return

	# 遮罩（由 _close_all_tooltips 统一清理）
	_ensure_overlay()

	var dialog: Panel = Panel.new()
	dialog.name = "ResetConfirmDialog"
	dialog.position = Vector2(340, 280)
	dialog.size = Vector2(360, 180)
	UIUtils.panel_style(dialog, Color(0.06, 0.07, 0.14, 0.95))

	var title: Label = Label.new()
	title.text = "🔄 洗点确认"
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	title.position = Vector2(20, 16)
	dialog.add_child(title)

	var body: Label = Label.new()
	body.text = "重置全部 " + str(total_used) + " 点自由属性点\n消耗金币: " + str(cost) + " 金"
	body.add_theme_font_size_override("font_size", 14)
	body.add_theme_color_override("font_color", Color(0.8, 0.8, 0.85))
	body.position = Vector2(20, 52)
	dialog.add_child(body)

	var confirm_btn: Button = Button.new()
	confirm_btn.text = "确认洗点"
	confirm_btn.position = Vector2(60, 120)
	confirm_btn.size = Vector2(100, 36)
	UIUtils.btn_style_mini(confirm_btn, Color(0.3, 0.12, 0.12))
	confirm_btn.add_theme_color_override("font_color", Color(1.0, 0.6, 0.6))
	confirm_btn.pressed.connect(func():
		_reset_stats()
		var d3 := get_node_or_null("ResetConfirmDialog")
		if d3: d3.queue_free()
		_close_all_tooltips()
	)
	dialog.add_child(confirm_btn)

	var cancel_btn: Button = Button.new()
	cancel_btn.text = "取消"
	cancel_btn.position = Vector2(200, 120)
	cancel_btn.size = Vector2(80, 36)
	UIUtils.btn_style_mini(cancel_btn, Color(0.2, 0.2, 0.3))
	cancel_btn.pressed.connect(func():
		var d4 := get_node_or_null("ResetConfirmDialog")
		if d4: d4.queue_free()
		_close_all_tooltips()
	)
	dialog.add_child(cancel_btn)

	add_child(dialog)


## ============================================================
## 第三部分续 — 背包面板
## ============================================================
func _show_inventory_panel() -> void:
	# queue_free 要到帧末才生效；先移出场景树，避免刷新时叠出多个同名面板。
	var old: Node = get_node_or_null("InventoryPanel")
	if old and is_instance_valid(old):
		remove_child(old)
		old.queue_free()
	_auto_save()
	_build_inventory_panel()


func _build_inventory_panel() -> void:

	var panel: Panel = Panel.new()
	panel.name = "InventoryPanel"
	panel.position = Vector2(140, 60)
	panel.size = Vector2(1000, 550)
	UIUtils.panel_style(panel, Color(0.10, 0.10, 0.16))

	# 标题
	var title: Label = Label.new()
	title.text = "🎒 背包 (" + str(inventory.get_slot_count()) + "/" + str(inventory.capacity) + ")  |  💰 " + str(player_gold) + " 金币"
	if inventory.is_expansion_maxed():
		title.text = "🎒 背包 (" + str(inventory.get_slot_count()) + "/" + str(inventory.capacity) + "·满)  |  💰 " + str(player_gold) + " 金币"
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	title.position = Vector2(20, 10)
	panel.add_child(title)

	# 分页按钮（标签风格）
	var tabs := [
		{ "id": "consume", "text": "消耗品" },
		{ "id": "equip",   "text": "装    备" },
		{ "id": "lottery", "text": "彩    票" },
	]
	for ti in range(tabs.size()):
		var tb: Button = Button.new()
		tb.text = tabs[ti]["text"]
		tb.position = Vector2(310 + ti * 136, 4)
		tb.size = Vector2(120, 36)
		tb.add_theme_font_size_override("font_size", 16)
		var is_tab_active: bool = (_inv_tab == tabs[ti]["id"])
		if is_tab_active:
			var ta := StyleBoxFlat.new()
			ta.bg_color = Color(0.15, 0.18, 0.28)
			ta.set_content_margin_all(4)
			ta.border_width_bottom = 3
			ta.border_color = Color(0.3, 0.6, 1.0)
			tb.add_theme_stylebox_override("normal", ta)
			tb.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0))
		else:
			var ta2 := StyleBoxFlat.new()
			ta2.bg_color = Color(0.08, 0.09, 0.15)
			ta2.set_content_margin_all(4)
			tb.add_theme_stylebox_override("normal", ta2)
			tb.add_theme_color_override("font_color", Color(0.4, 0.45, 0.5))
		tb.flat = true
		var tid: String = tabs[ti]["id"]
		tb.pressed.connect(func():
			if _inv_tab == tid:
				return
			_inv_tab = tid
			# 重建 tab 按钮样式
			for c in panel.get_children():
				if c is Button and c.has_meta("tab_id"):
					_restyle_tab(c, c.get_meta("tab_id") == _inv_tab)
			_refresh_item_area(panel)
		)
		tb.set_meta("tab_id", tid)
		panel.add_child(tb)

	# 装备栏（左侧）
	var equip_panel: Panel = Panel.new()
	equip_panel.position = Vector2(16, 50)
	equip_panel.size = Vector2(280, 390)
	UIUtils.panel_style(equip_panel, Color(0.08, 0.09, 0.13))
	panel.add_child(equip_panel)

	var equip_title: Label = Label.new()
	equip_title.text = "装备栏"
	equip_title.add_theme_font_size_override("font_size", 14)
	equip_title.add_theme_color_override("font_color", Color(0.7, 0.85, 1.0))
	equip_title.position = Vector2(10, 8)
	equip_panel.add_child(equip_title)

	var stat_btn: Button = Button.new()
	stat_btn.text = "?"
	stat_btn.position = Vector2(70, 4)
	stat_btn.size = Vector2(26, 22)
	UIUtils.btn_style_mini(stat_btn, Color(0.15, 0.22, 0.38))
	stat_btn.pressed.connect(_show_stats_panel)
	equip_panel.add_child(stat_btn)

	# 2列布局：左列 4 个，右列 4 个
	var cols2: Array[Array] = [
		[{ "name": "weapon",   "label": "武器" }, { "name": "armor",    "label": "防具" }],
		[{ "name": "shoes",    "label": "鞋子" }, { "name": "ring",     "label": "戒指" }],
		[{ "name": "necklace", "label": "项链" }, { "name": "cape",     "label": "披风" }],
		[{ "name": "helmet",   "label": "头盔" }, { "name": "charm",    "label": "护符" }],
	]
	var icon_s: float = 48.0
	var col_x: Array[float] = [12.0, 150.0]
	var row_start: float = 38.0
	var row_h2: float = 84.0

	for ri in range(cols2.size()):
		for ci in range(2):
			var es: Dictionary = cols2[ri][ci]
			var rx: float = col_x[ci]
			var ry: float = row_start + ri * row_h2

			# 标签
			var eq_lbl: Label = Label.new()
			eq_lbl.text = es["label"]
			eq_lbl.add_theme_font_size_override("font_size", 11)
			eq_lbl.add_theme_color_override("font_color", Color(0.5, 0.5, 0.6))
			eq_lbl.position = Vector2(rx, ry)
			equip_panel.add_child(eq_lbl)

			# 灰色边框框（空槽也显示）
			var frame_p: Panel = Panel.new()
			frame_p.position = Vector2(rx, ry + 16)
			frame_p.size = Vector2(icon_s + 2, icon_s + 2)
			var fb := StyleBoxFlat.new()
			fb.bg_color = Color(0.10, 0.11, 0.18)
			fb.border_width_left = 1; fb.border_width_right = 1
			fb.border_width_top = 1; fb.border_width_bottom = 1
			fb.border_color = Color(0.3, 0.3, 0.4)
			frame_p.add_theme_stylebox_override("panel", fb)
			equip_panel.add_child(frame_p)

			var eqp: Dictionary = equipment.get_slot_item(es["name"])
			if not eqp.is_empty():
				# 品质色边框
				var qclr: Color = UIUtils.qcolor(eqp.get("quality", 0))
				var qb2 := StyleBoxFlat.new()
				qb2.bg_color = Color(1,1,1,0)
				qb2.border_width_left = 2; qb2.border_width_right = 2
				qb2.border_width_top = 2; qb2.border_width_bottom = 2
				qb2.border_color = qclr
				frame_p.add_theme_stylebox_override("panel", qb2)
				frame_p.remove_theme_stylebox_override("panel")
				frame_p.add_theme_stylebox_override("panel", qb2)

				var eq_icon: Label = Label.new()
				eq_icon.text = eqp.get("icon", "?")
				eq_icon.add_theme_font_size_override("font_size", 26)
				eq_icon.position = Vector2(rx + 4, ry + 18)
				equip_panel.add_child(eq_icon)

				# 信息行
				var info_y: float = ry + 68
				if eqp.get("enhance", 0) > 0:
					var eh: Label = Label.new()
					eh.text = "+" + str(eqp["enhance"])
					eh.add_theme_font_size_override("font_size", 8)
					eh.add_theme_color_override("font_color", Color(1,0.85,0.2))
					eh.position = Vector2(rx + 40, info_y)
					equip_panel.add_child(eh)

				var suit: String = eqp.get("suit_name", "")
				if not suit.is_empty():
					var st: Label = Label.new()
					st.text = suit.substr(0, 1)
					st.add_theme_font_size_override("font_size", 8)
					st.add_theme_color_override("font_color", Color(0.3, 1.0, 0.6))
					st.position = Vector2(rx + 2, info_y)
					equip_panel.add_child(st)

				var gem_s: int = eqp.get("gem_slots", 0)
				if gem_s > 0:
					var gem_filled: int = 0
					for gv in eqp.get("gems", []):
						if gv > 0: gem_filled += 1
					var gt: Label = Label.new()
					gt.text = "◆" + str(gem_filled) + "/" + str(gem_s)
					gt.add_theme_font_size_override("font_size", 7)
					gt.add_theme_color_override("font_color", Color(0.8, 0.5, 1.0))
					gt.position = Vector2(rx + 2, info_y + 12)
					equip_panel.add_child(gt)

				# 点击已装备 → tips
				var slot_btn: Button = Button.new()
				slot_btn.flat = true
				slot_btn.position = Vector2(rx, ry + 16)
				slot_btn.size = Vector2(50, 50)
				UIUtils.btn_transparent2(slot_btn)
				var esn: String = es["name"]
				slot_btn.gui_input.connect(func(ev: InputEvent):
					if ev is InputEventMouseButton and ev.pressed:
						if ev.button_index == MOUSE_BUTTON_RIGHT:
							slot_btn.accept_event()
							_on_unequip_instance(esn)
							_show_inventory_panel()
						else:
							_close_all_tooltips()
							_show_equip_tooltip(eqp, -1, esn, panel)
					)
				equip_panel.add_child(slot_btn)

	# 套装统计
	var suit_counts: Dictionary = _count_equipped_suits()
	if not suit_counts.is_empty():
		var ssy: float = row_start + 4 * row_h2 + 8
		var suit_line: Label = Label.new()
		var stxt: String = "套装:"
		for sk in suit_counts:
			stxt += " " + sk + "×" + str(suit_counts[sk])
		suit_line.text = stxt
		suit_line.add_theme_font_size_override("font_size", 10)
		suit_line.add_theme_color_override("font_color", Color(0.3, 1.0, 0.6))
		suit_line.position = Vector2(12, ssy)
		equip_panel.add_child(suit_line)

	# 道具区域（右侧）
	var item_area: Panel = Panel.new()
	item_area.name = "ItemArea"
	item_area.position = Vector2(310, 50)
	item_area.size = Vector2(674, 390)
	UIUtils.panel_style(item_area, Color(0.08, 0.09, 0.13))
	panel.add_child(item_area)

	# 过滤 + 内容（由 _rebuild_filters 统一管理）
	_rebuild_filters(item_area, panel)
	var content_area: Panel = Panel.new()
	content_area.name = "ItemContent"
	content_area.position = Vector2(0, 56)
	content_area.size = Vector2(674, 334)
	var ca_style := StyleBoxFlat.new()
	ca_style.bg_color = Color(1,1,1,0)
	content_area.add_theme_stylebox_override("panel", ca_style)
	item_area.add_child(content_area)

	if _inv_tab == "consume":
		_build_consume_tab(content_area, panel)
	elif _inv_tab == "lottery":
		_build_lottery_tab(content_area, panel)
	else:
		_build_equip_tab(content_area, panel)

	# 底部按钮
	var bottom_y: float = 450.0

	var dismantle_btn: Button = Button.new()
	dismantle_btn.text = "♻ 分解"
	dismantle_btn.position = Vector2(900, bottom_y)
	dismantle_btn.size = Vector2(80, 30)
	UIUtils.btn_style_mini(dismantle_btn, Color(0.2, 0.12, 0.2))
	dismantle_btn.pressed.connect(func(): _show_dismantle_panel(panel))
	panel.add_child(dismantle_btn)

	# 关闭
	var close_btn: Button = Button.new()
	close_btn.text = "✕ 关闭"
	close_btn.position = Vector2(910, 8)
	close_btn.size = Vector2(70, 24)
	UIUtils.btn_style_mini(close_btn, Color(0.25, 0.15, 0.15))
	close_btn.pressed.connect(panel.queue_free)
	panel.add_child(close_btn)

	add_child(panel)


## 刷新物品区域（不关面板）
func _restyle_tab(tb: Button, active: bool) -> void:
	if active:
		var ta := StyleBoxFlat.new()
		ta.bg_color = Color(0.15, 0.18, 0.28)
		ta.set_content_margin_all(4)
		ta.border_width_bottom = 3
		ta.border_color = Color(0.3, 0.6, 1.0)
		tb.add_theme_stylebox_override("normal", ta)
		tb.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0))
	else:
		var ta2 := StyleBoxFlat.new()
		ta2.bg_color = Color(0.08, 0.09, 0.15)
		ta2.set_content_margin_all(4)
		tb.add_theme_stylebox_override("normal", ta2)
		tb.add_theme_color_override("font_color", Color(0.4, 0.45, 0.5))

func _rebuild_filters(item_area: Panel, main_panel: Panel) -> void:
	# 清除旧过滤按钮（保留 ItemContent）
	for c in item_area.get_children():
		if c.get("name") != "ItemContent":
			c.queue_free()

	var qlabels: Array[String] = ["全部", "灰", "绿", "蓝", "紫", "橙"]
	var qclrvals: Array[Color] = [Color(0.5,0.5,0.5), Color(0.6,0.6,0.6), Color(0.2,0.8,0.2), Color(0.2,0.4,1.0), Color(0.7,0.2,1.0), Color(1.0,0.6,0.1)]
	for qi in range(qlabels.size()):
		var qb: Button = Button.new()
		qb.text = qlabels[qi]
		qb.position = Vector2(4 + qi * 52, 4)
		qb.size = Vector2(48, 22)
		qb.add_theme_font_size_override("font_size", 12)
		qb.alignment = HORIZONTAL_ALIGNMENT_LEFT
		var qv: int = qi - 1
		var selected: bool = (qv == -1 and _inv_filter_quality.is_empty()) or _inv_filter_quality.has(qv)
		var clr: Color = qclrvals[qi]
		UIUtils.btn_style_mini(qb, clr.darkened(0.3) if not selected else clr.lightened(0.1))
		if qi == 0:
			qb.add_theme_color_override("font_color", Color(1,1,1))
		else:
			qb.add_theme_color_override("font_color", clr.lightened(0.3) if selected else clr)
		qb.pressed.connect(func():
			if qv == -1:
				_inv_filter_quality.clear()
			else:
				if _inv_filter_quality.has(qv):
					_inv_filter_quality.erase(qv)
				else:
					_inv_filter_quality.append(qv)
			_rebuild_filters(item_area, main_panel)
			# 刷新内容
			var content: Node = item_area.get_node_or_null("ItemContent")
			if content:
				for c2 in content.get_children():
					c2.queue_free()
				if _inv_tab == "consume":
					_build_consume_tab(content, main_panel)
				else:
					_build_equip_tab(content, main_panel)
		)
		item_area.add_child(qb)

	# 部位过滤（仅装备页显示）
	if _inv_tab == "equip":
		var slabels: Array[String] = ["全部", "武器", "防具", "鞋子", "戒指", "项链", "披风", "头盔", "护符"]
		for si in range(slabels.size()):
			var sb: Button = Button.new()
			sb.text = slabels[si]
			sb.position = Vector2(4 + si * 52, 32)
			sb.size = Vector2(48, 20)
			sb.add_theme_font_size_override("font_size", 12)
			sb.alignment = HORIZONTAL_ALIGNMENT_LEFT
			var sv: int = si - 1
			var ssel: bool = (sv == -1 and _inv_filter_slot.is_empty()) or _inv_filter_slot.has(sv)
			UIUtils.btn_style_mini(sb, Color(0.15, 0.18, 0.35) if not ssel else Color(0.25, 0.40, 0.60))
			sb.add_theme_color_override("font_color", Color(1,1,1) if ssel else Color(0.7,0.75,0.8))
			sb.pressed.connect(func():
				if sv == -1:
					_inv_filter_slot.clear()
				else:
					if _inv_filter_slot.has(sv):
						_inv_filter_slot.erase(sv)
					else:
						_inv_filter_slot.append(sv)
				_rebuild_filters(item_area, main_panel)
				var content2: Node = item_area.get_node_or_null("ItemContent")
				if content2:
					for c3 in content2.get_children():
						c3.queue_free()
					_build_equip_tab(content2, main_panel)
			)
			item_area.add_child(sb)


func _refresh_item_area(main_panel: Panel) -> void:
	var item_area: Panel = main_panel.get_node_or_null("ItemArea") as Panel
	if not item_area:
		return
	# 重建过滤按钮（部位筛选仅装备页显示）
	_rebuild_filters(item_area, main_panel)

	var content: Node = item_area.get_node_or_null("ItemContent")
	if not content:
		return
	for c in content.get_children():
		c.queue_free()
	if _inv_tab == "consume":
		_build_consume_tab(content, main_panel)
	elif _inv_tab == "lottery":
		_build_lottery_tab(content, main_panel)
	else:
		_build_equip_tab(content, main_panel)


## 背包扩容确认弹窗
func _show_expansion_confirm(main_panel: Panel) -> void:
	var cost: int = inventory.get_next_expansion_cost()
	if cost < 0:
		_show_float_text("背包已达到最大容量", Color(0.6, 0.6, 0.7))
		return

	# 避免重复弹窗
	if get_node_or_null("ExpansionConfirm"):
		return

	# 遮罩（已有 overlay 不重复创建，由 _close_all_tooltips 统一清理）
	_ensure_overlay()

	var dialog: Panel = Panel.new()
	dialog.name = "ExpansionConfirm"
	dialog.position = Vector2(340, 280)
	dialog.size = Vector2(360, 180)
	UIUtils.panel_style(dialog, Color(0.06, 0.07, 0.14, 0.95))

	var title: Label = Label.new()
	title.text = "📦 背包扩容"
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	title.position = Vector2(20, 16)
	dialog.add_child(title)

	var body: Label = Label.new()
	var new_cap: int = inventory.capacity + InventoryCls.SLOTS_PER_EXPAND
	body.text = "扩容 +" + str(InventoryCls.SLOTS_PER_EXPAND) + " 格\n当前: " + str(inventory.capacity) + " → " + str(new_cap) + " 格\n消耗金币: " + str(cost)
	body.add_theme_font_size_override("font_size", 14)
	body.add_theme_color_override("font_color", Color(0.8, 0.8, 0.85))
	body.position = Vector2(20, 52)
	dialog.add_child(body)

	var confirm_btn: Button = Button.new()
	confirm_btn.text = "确认扩容"
	confirm_btn.position = Vector2(60, 120)
	confirm_btn.size = Vector2(100, 36)
	UIUtils.btn_style_mini(confirm_btn, Color(0.1, 0.3, 0.15))
	confirm_btn.add_theme_color_override("font_color", Color(0.3, 1.0, 0.5))
	confirm_btn.pressed.connect(func():
		# 点击确认时才检查金币
		var cost2: int = inventory.get_next_expansion_cost()
		if cost2 < 0:
			_show_float_text("背包已达到最大容量", Color(0.6, 0.6, 0.7))
		elif player_gold < cost2:
			_show_float_text("金币不足！扩容需要 " + str(cost2) + " 金", Color(1.0, 0.3, 0.3))
		else:
			player_gold -= cost2
			inventory.expand()
			_show_float_text("扩容成功！背包 " + str(inventory.capacity) + " 格", Color(0.3, 1.0, 0.6))
		# 关闭弹窗
		var d3 := get_node_or_null("ExpansionConfirm")
		if d3: d3.queue_free()
		_close_all_tooltips()
		if is_instance_valid(main_panel):
			main_panel.queue_free()
		_show_inventory_panel()
		top_bar.refresh()
	)
	dialog.add_child(confirm_btn)

	var cancel_btn: Button = Button.new()
	cancel_btn.text = "取消"
	cancel_btn.position = Vector2(200, 120)
	cancel_btn.size = Vector2(80, 36)
	UIUtils.btn_style_mini(cancel_btn, Color(0.2, 0.2, 0.3))
	cancel_btn.pressed.connect(func():
		var d4 := get_node_or_null("ExpansionConfirm")
		if d4: d4.queue_free()
		_close_all_tooltips()
	)
	dialog.add_child(cancel_btn)

	add_child(dialog)


func _build_consume_tab(area: Panel, main_panel: Panel) -> void:
	var cols: int = 8
	var gap: float = 8.0
	var icon_s: float = 48.0
	var row_h: float = icon_s + gap + 14  # 每行高度（含底部标签空间）

	# 计算可见范围内最多能放多少格
	var max_y: float = 370.0
	var max_visible_rows: int = int(max_y / row_h)
	var total_cells: int = mini(inventory.capacity, max_visible_rows * cols)

	# 构建格子底框样式
	var cell_style := StyleBoxFlat.new()
	cell_style.bg_color = Color(0.12, 0.13, 0.20)
	cell_style.border_width_left = 1; cell_style.border_width_right = 1
	cell_style.border_width_top = 1; cell_style.border_width_bottom = 1
	cell_style.border_color = Color(0.25, 0.25, 0.35)

	var empty_style := StyleBoxFlat.new()
	empty_style.bg_color = Color(0.08, 0.09, 0.14)
	empty_style.border_width_left = 1; empty_style.border_width_right = 1
	empty_style.border_width_top = 1; empty_style.border_width_bottom = 1
	empty_style.border_color = Color(0.18, 0.18, 0.25)

	for i in range(total_cells):
		var col: int = i % cols
		var row: int = i / cols
		var x: float = gap + col * (icon_s + gap)
		var y: float = gap + row * (icon_s + gap + 14)

		# 格子底框
		var cell_bg: Panel = Panel.new()
		cell_bg.position = Vector2(x, y)
		cell_bg.size = Vector2(icon_s, icon_s)
		area.add_child(cell_bg)

		var slot: Dictionary = inventory.get_slot(i)
		if slot.is_empty():
			# 空格子
			cell_bg.add_theme_stylebox_override("panel", empty_style)
		else:
			# 有物品
			cell_bg.add_theme_stylebox_override("panel", cell_style)
			var defn: Dictionary = ItemDBRef.get_item(slot["item_id"])

			var icon: Label = Label.new()
			icon.text = defn.get("icon", "?")
			icon.add_theme_font_size_override("font_size", 24)
			icon.position = Vector2(x + 4, y + 4)
			area.add_child(icon)

			var cnt_lbl: Label = Label.new()
			cnt_lbl.text = "×" + str(slot["count"])
			cnt_lbl.add_theme_font_size_override("font_size", 9)
			cnt_lbl.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
			cnt_lbl.position = Vector2(x + 2, y + icon_s - 12)
			area.add_child(cnt_lbl)

			# 点击使用
			var btn: Button = Button.new()
			btn.flat = true
			btn.position = Vector2(x, y)
			btn.size = Vector2(icon_s, icon_s)
			UIUtils.btn_transparent2(btn)
			var si: int = i
			btn.pressed.connect(func():
				_on_item_action(si)
				main_panel.queue_free()
				_show_inventory_panel()
			)
			area.add_child(btn)


func _build_equip_tab(area: Panel, main_panel: Panel) -> void:
	var cols: int = 8
	var gap: float = 8.0
	var icon_s: float = 48.0
	var row_h: float = icon_s + gap + 22
	var max_y: float = 360.0
	var max_visible_rows: int = int(max_y / row_h)
	var total_cells: int = max_visible_rows * cols

	# 空格子样式
	var empty_style := StyleBoxFlat.new()
	empty_style.bg_color = Color(0.08, 0.09, 0.14)
	empty_style.border_width_left = 1; empty_style.border_width_right = 1
	empty_style.border_width_top = 1; empty_style.border_width_bottom = 1
	empty_style.border_color = Color(0.18, 0.18, 0.25)

	var filtered: Array[int] = []
	for j in range(equip_instances.size()):
		var eqp: Dictionary = equip_instances[j]
		if eqp.get("equipped", false):
			continue
		if not _inv_filter_quality.is_empty() and not _inv_filter_quality.has(eqp.get("quality", -1)):
			continue
		if not _inv_filter_slot.is_empty() and not _inv_filter_slot.has(eqp.get("slot_type_id", -1)):
			continue
		filtered.append(j)

	for i in range(total_cells):
		var col: int = i % cols
		var row: int = i / cols
		var x: float = gap + col * (icon_s + gap)
		var y: float = gap + row * (icon_s + gap + 22)

		if y > max_y:
			break

		if i < filtered.size():
			# 有装备
			var ei: int = filtered[i]
			var eqp: Dictionary = equip_instances[ei]

			# 品质边框
			var qclr: Color = UIUtils.qcolor(eqp.get("quality", 0))
			var qborder: Panel = Panel.new()
			qborder.position = Vector2(x - 1, y - 1)
			qborder.size = Vector2(icon_s + 2, icon_s + 2)
			var qb := StyleBoxFlat.new()
			qb.bg_color = Color(0.10, 0.11, 0.18)
			qb.border_width_left = 2; qb.border_width_right = 2
			qb.border_width_top = 2; qb.border_width_bottom = 2
			qb.border_color = qclr
			qborder.add_theme_stylebox_override("panel", qb)
			area.add_child(qborder)

			# 图标
			var icon: Label = Label.new()
			icon.text = eqp.get("icon", "?")
			icon.add_theme_font_size_override("font_size", 22)
			icon.position = Vector2(x + 2, y)
			area.add_child(icon)

			# 名称（品质色）
			var ename: Label = Label.new()
			var short_name: String = eqp.get("base_name", "???")
			if eqp.get("enhance", 0) > 0:
				ename.text = short_name.substr(0, 3) + "+" + str(eqp["enhance"])
			else:
				ename.text = short_name.substr(0, 4)
			ename.add_theme_font_size_override("font_size", 9)
			ename.add_theme_color_override("font_color", qclr)
			ename.position = Vector2(x, y + icon_s + 2)
			ename.size = Vector2(icon_s, 12)
			ename.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			area.add_child(ename)

			# 点击 → tooltip, 右键快速装备
			var btn: Button = Button.new()
			btn.flat = true
			btn.position = Vector2(x, y)
			btn.size = Vector2(icon_s, icon_s + 16)
			UIUtils.btn_transparent2(btn)
			var eidx: int = ei
			btn.gui_input.connect(func(ev: InputEvent):
				if ev is InputEventMouseButton and ev.pressed:
					if ev.button_index == MOUSE_BUTTON_RIGHT:
						btn.accept_event()
						_on_equip_instance(eidx)
						_show_inventory_panel()
					else:
						_close_all_tooltips()
						var s: String = eqp.get("slot", "")
						var weq: Dictionary = equipment.get_slot_item(s)
						if not weq.is_empty():
							_show_compare_tooltips(eqp, weq, s, main_panel)
						else:
							_show_equip_tooltip(eqp, eidx, "", main_panel)
			)
			area.add_child(btn)
		elif i == total_cells - 1 and not inventory.is_expansion_maxed():
			# --- 扩容 + 号按钮（装备页签底部） ---
			var plus_cell_style := StyleBoxFlat.new()
			plus_cell_style.bg_color = Color(0.10, 0.11, 0.18)
			plus_cell_style.border_width_left = 1; plus_cell_style.border_width_right = 1
			plus_cell_style.border_width_top = 1; plus_cell_style.border_width_bottom = 1
			plus_cell_style.border_color = Color(0.35, 0.5, 0.35)

			var plus_cell: Panel = Panel.new()
			plus_cell.position = Vector2(x, y)
			plus_cell.size = Vector2(icon_s, icon_s)
			plus_cell.add_theme_stylebox_override("panel", plus_cell_style)
			area.add_child(plus_cell)

			var plus_lbl: Label = Label.new()
			plus_lbl.text = "+"
			plus_lbl.add_theme_font_size_override("font_size", 32)
			plus_lbl.add_theme_color_override("font_color", Color(0.3, 0.8, 0.3))
			plus_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			plus_lbl.position = Vector2(x, y + 4)
			plus_lbl.size = Vector2(icon_s, icon_s)
			area.add_child(plus_lbl)

			var plus_btn: Button = Button.new()
			plus_btn.flat = true
			plus_btn.position = Vector2(x, y)
			plus_btn.size = Vector2(icon_s, icon_s)
			UIUtils.btn_transparent2(plus_btn)
			plus_btn.pressed.connect(func():
				_show_expansion_confirm(main_panel)
			)
			area.add_child(plus_btn)
		else:
			# 空格子
			var empty_frame: Panel = Panel.new()
			empty_frame.position = Vector2(x, y)
			empty_frame.size = Vector2(icon_s, icon_s)
			empty_frame.add_theme_stylebox_override("panel", empty_style)
			area.add_child(empty_frame)


## 装备完整 tooltip
func _show_equip_tooltip(eqp: Dictionary, idx: int, slot_name: String, main_panel: Panel, x_pos: float = 340.0) -> void:
	# 确保全屏遮罩层存在
	_ensure_overlay()

	var tip: Panel = Panel.new()
	tip.name = "EquipTooltip"
	tip.position = Vector2(x_pos, 60)
	tip.size = Vector2(340, 340)
	UIUtils.panel_style(tip, Color(0.06, 0.07, 0.14, 0.97))
	_tooltip_nodes.append(tip)

	var sy: float = 8.0
	var qclr: Color = UIUtils.qcolor(eqp.get("quality", 0))
	var qname: String = eqp.get("quality_name", "")

	# 品质色条
	var qbar: ColorRect = ColorRect.new()
	qbar.position = Vector2(0, 0)
	qbar.size = Vector2(340, 3)
	qbar.color = qclr
	tip.add_child(qbar)

	# 是否已装备标记
	if not slot_name.is_empty():
		var badge: Label = Label.new()
		badge.text = "【装备中】"
		badge.add_theme_font_size_override("font_size", 10)
		badge.add_theme_color_override("font_color", Color(0.3, 1.0, 0.5))
		badge.position = Vector2(265, sy)
		tip.add_child(badge)

	# 名称 + 强化
	var name_lbl: Label = Label.new()
	name_lbl.text = "[" + qname + "] " + eqp.get("base_name", "???")
	if eqp.get("enhance", 0) > 0:
		name_lbl.text += " +" + str(eqp["enhance"])
	name_lbl.add_theme_font_size_override("font_size", 18)
	name_lbl.add_theme_color_override("font_color", qclr)
	name_lbl.position = Vector2(12, sy)
	tip.add_child(name_lbl)
	sy += 24

	# 套装信息
	var suit: String = eqp.get("suit_name", "")
	if not suit.is_empty():
		var suit_counts: Dictionary = _count_equipped_suits()
		var scnt: int = suit_counts.get(suit, 0)
		var sl: Label = Label.new()
		sl.text = "套装: " + suit + "  (" + str(scnt) + "/4)"
		if scnt >= 4:
			sl.text += "  ●已激活"
		elif scnt >= 2:
			sl.text += "  ●2件效果"
		sl.add_theme_font_size_override("font_size", 12)
		sl.add_theme_color_override("font_color", Color(0.3, 1.0, 0.6))
		sl.position = Vector2(12, sy)
		tip.add_child(sl)
		sy += 18

	# 装备等级
	var lv_lbl: Label = Label.new()
	lv_lbl.text = "装备等级 Lv." + str(player_level)
	lv_lbl.add_theme_font_size_override("font_size", 11)
	lv_lbl.add_theme_color_override("font_color", Color(0.5, 0.5, 0.6))
	lv_lbl.position = Vector2(12, sy)
	tip.add_child(lv_lbl)
	sy += 18

	# 分割线
	sy += 4
	var sep: ColorRect = ColorRect.new()
	sep.position = Vector2(8, sy)
	sep.size = Vector2(324, 1)
	sep.color = Color(0.2, 0.2, 0.3)
	tip.add_child(sep)
	sy += 8

	# 主属性 + 强化收益
	var main_lbl: Label = Label.new()
	main_lbl.text = eqp.get("main_stat", "") + ": " + str(eqp.get("main_value", 0))
	if eqp.get("enhance", 0) > 0:
		var enhance_bonus: float = eqp["main_value"] * (eqp["enhance"] * 0.03)
		main_lbl.text += "  (+" + str(snapped(enhance_bonus, 0.1)) + " 强化)"
	main_lbl.add_theme_font_size_override("font_size", 13)
	main_lbl.add_theme_color_override("font_color", Color(1.0, 0.9, 0.3))
	main_lbl.position = Vector2(12, sy)
	tip.add_child(main_lbl)
	sy += 18

	# 词条
	var affixes: Array = eqp.get("affixes", [])
	for aff in affixes:
		var al: Label = Label.new()
		al.text = aff.get("name", "") + "  " + aff.get("display", "")
		al.add_theme_font_size_override("font_size", 12)
		al.add_theme_color_override("font_color", Color(0.8, 0.85, 0.9))
		al.position = Vector2(12, sy)
		tip.add_child(al)
		sy += 16

	# 宝石
	var gem_slots: int = eqp.get("gem_slots", 0)
	var gems: Array = eqp.get("gems", [])
	if gem_slots > 0:
		sy += 2
		var gsep: ColorRect = ColorRect.new()
		gsep.position = Vector2(8, sy)
		gsep.size = Vector2(324, 1)
		gsep.color = Color(0.2, 0.2, 0.3)
		tip.add_child(gsep)
		sy += 6

		var gtitle: Label = Label.new()
		gtitle.text = "宝石槽位 (" + str(gem_slots) + ")"
		gtitle.add_theme_font_size_override("font_size", 11)
		gtitle.add_theme_color_override("font_color", Color(0.6, 0.4, 0.8))
		gtitle.position = Vector2(12, sy)
		tip.add_child(gtitle)
		sy += 18

		for k in range(gem_slots):
			var gid: int = gems[k] if k < gems.size() else 0
			var gdef: Dictionary = EquipData.GEM_DEFS.get(gid, {})
			var gl: Label = Label.new()
			if gid > 0:
				gl.text = gdef.get("icon", "🔘") + " " + gdef.get("name", "???") + " Lv.1  —  " + gdef.get("desc", "")
				gl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
			else:
				gl.text = "○  空槽位"
				gl.add_theme_color_override("font_color", Color(0.3, 0.3, 0.4))
			gl.add_theme_font_size_override("font_size", 11)
			gl.position = Vector2(16, sy)
			tip.add_child(gl)
			sy += 16

	# 底部按钮
	var btn_y: float = 305
	if idx >= 0:
		var equip_btn: Button = Button.new()
		equip_btn.text = "装备"
		equip_btn.position = Vector2(12, btn_y)
		equip_btn.size = Vector2(60, 26)
		UIUtils.btn_style_mini(equip_btn, Color(0.15, 0.28, 0.45))
		var eid: int = idx
		equip_btn.pressed.connect(func():
			_close_all_tooltips()
			_on_equip_instance(eid)
			main_panel.queue_free()
			_show_inventory_panel()
		)
		tip.add_child(equip_btn)
	elif not slot_name.is_empty():
		var unequip_btn: Button = Button.new()
		unequip_btn.text = "卸下"
		unequip_btn.position = Vector2(12, btn_y)
		unequip_btn.size = Vector2(60, 26)
		UIUtils.btn_style_mini(unequip_btn, Color(0.35, 0.12, 0.12))
		var esn: String = slot_name
		unequip_btn.pressed.connect(func():
			_close_all_tooltips()
			_on_unequip_instance(esn)
			main_panel.queue_free()
			_show_inventory_panel()
		)
		tip.add_child(unequip_btn)

	# 装备/卸下按钮结束

	# 把 tip 放到 root 层，确保在遮罩层之上
	add_child(tip)


func _ensure_overlay() -> void:
	if get_node_or_null("TooltipOverlay"):
		return
	var ov: Button = Button.new()
	ov.name = "TooltipOverlay"
	ov.flat = true
	ov.position = Vector2(0, 0)
	ov.size = Vector2(1280, 720)
	var os := StyleBoxFlat.new()
	os.bg_color = Color(0, 0, 0, 0.01)
	ov.add_theme_stylebox_override("normal", os)
	ov.pressed.connect(_close_all_tooltips)
	add_child(ov)


## 对比 tooltips（背包装备 + 已装备同部位）
func _show_compare_tooltips(bag_eqp: Dictionary, wear_eqp: Dictionary, slot: String, main_panel: Panel) -> void:
	# 背包的在左边，已装备的在右边
	_show_equip_tooltip(bag_eqp, _find_instance_idx(bag_eqp), "", main_panel, 320.0)
	_show_equip_tooltip(wear_eqp, -1, slot, main_panel, 670.0)


func _find_instance_idx(eqp: Dictionary) -> int:
	for i in range(equip_instances.size()):
		if equip_instances[i].get("uid", -1) == eqp.get("uid", -1):
			return i
	return -1


## 卸下装备
func _on_unequip_instance(slot_name: String) -> void:
	print("[DEBUG] _on_unequip_instance called, slot=", slot_name)
	var eqp: Dictionary = equipment.unequip(slot_name)
	if eqp.is_empty():
		print("[DEBUG] unequip returned empty for ", slot_name)
		return
	print("[DEBUG] unequipped: ", eqp.get("base_name","?"), " uid=", eqp.get("uid",-1))
	# 在 equip_instances 中找到原始条目，标记为未装备
	var uid: int = eqp.get("uid", -1)
	for i in range(equip_instances.size()):
		if equip_instances[i].get("uid", -1) == uid:
			equip_instances[i]["equipped"] = false
			print("[DEBUG] 卸下完成:", equip_instances[i].get("base_name","?"), "←", slot_name)
			# 卸下装备后刷新所有属性面板
			_refresh_all_stats_panels()
			return
	# 没找到原始条目（装备来自宝箱等直接装备的情况），追加
	eqp["equipped"] = false
	equip_instances.append(eqp)
	print("[DEBUG] 卸下: 原始条目未找到，追加")


func _on_equip_instance(idx: int) -> void:
	print("[DEBUG] _on_equip_instance called, idx=", idx, " total=", equip_instances.size())
	if idx < 0 or idx >= equip_instances.size():
		print("[DEBUG] _on_equip_instance OUT OF BOUNDS")
		return
	var eqp: Dictionary = equip_instances[idx]
	print("[DEBUG] eqp keys: ", eqp.keys(), " slot: ", eqp.get("slot","?"))
	var slot_name: String = eqp.get("slot", "")
	if slot_name.is_empty():
		print("[DEBUG] _on_equip_instance slot empty")
		return
	# 卸下同部位旧装备
	for i in range(equip_instances.size()):
		if i != idx and equip_instances[i].get("equipped", false) and equip_instances[i].get("slot", "") == slot_name:
			equip_instances[i]["equipped"] = false
			break
	eqp["equipped"] = true
	var ok: bool = equipment.equip_instance(slot_name, eqp)
	print("[DEBUG] equip_instance returned: ", ok, " slot: ", slot_name, " name: ", eqp.get("base_name","?"))
	# 穿戴装备后刷新所有属性面板
	_refresh_all_stats_panels()
	print("[装备] 穿戴:", EquipGenCls.full_name(eqp), "→", slot_name)


## 装备分解面板
func _show_dismantle_panel(main_panel: Panel) -> void:
	var old: Node = main_panel.get_node_or_null("DismantlePanel")
	if old:
		old.queue_free()
		return

	var dp: Panel = Panel.new()
	dp.name = "DismantlePanel"
	dp.position = Vector2(310, 50)
	dp.size = Vector2(674, 390)
	UIUtils.panel_style(dp, Color(0.06, 0.07, 0.13, 0.98))

	var dtitle: Label = Label.new()
	dtitle.text = "♻ 装备分解"
	dtitle.add_theme_font_size_override("font_size", 16)
	dtitle.add_theme_color_override("font_color", Color(0.8, 0.5, 0.9))
	dtitle.position = Vector2(12, 8)
	dp.add_child(dtitle)

	# 精华说明
	var info: Label = Label.new()
	info.text = "灰+1 / 绿+3 / 蓝+8 / 紫+20 / 橙+50   宝石自动拆卸返还"
	info.add_theme_font_size_override("font_size", 10)
	info.add_theme_color_override("font_color", Color(0.5, 0.5, 0.6))
	info.position = Vector2(12, 28)
	dp.add_child(info)

	var dismantle_targets: Array[int] = []
	var essence_label: Label = Label.new()
	essence_label.text = "预计获得: 0 精华"
	essence_label.add_theme_font_size_override("font_size", 12)
	essence_label.add_theme_color_override("font_color", Color(1.0, 0.7, 0.3))
	essence_label.position = Vector2(500, 8)
	dp.add_child(essence_label)

	# 全选/取消
	var select_all_btn: Button = Button.new()
	select_all_btn.text = "全选"
	select_all_btn.position = Vector2(500, 30)
	select_all_btn.size = Vector2(50, 22)
	UIUtils.btn_style_mini(select_all_btn, Color(0.15, 0.22, 0.38))
	select_all_btn.add_theme_font_size_override("font_size", 10)
	dp.add_child(select_all_btn)

	var deselect_btn: Button = Button.new()
	deselect_btn.text = "取消"
	deselect_btn.position = Vector2(558, 30)
	deselect_btn.size = Vector2(50, 22)
	UIUtils.btn_style_mini(deselect_btn, Color(0.2, 0.12, 0.12))
	deselect_btn.add_theme_font_size_override("font_size", 10)
	dp.add_child(deselect_btn)

	# 刷新精华显示
	var _update_essence := func():
		var total: int = 0
		for ei in dismantle_targets:
			if ei < 0 or ei >= equip_instances.size():
				continue
			var q: int = equip_instances[ei].get("quality", 0)
			total += [1, 3, 8, 20, 50][q]
		essence_label.text = "预计获得: " + str(total) + " 精华"

	# 装备列表
	var cols: int = 6
	var gap: float = 8.0
	var icon_s: float = 48.0
	var dy: float = 60.0
	var checkboxes: Array[CheckBox] = []

	for j in range(equip_instances.size()):
		var eqp: Dictionary = equip_instances[j]
		if eqp.get("equipped", false):
			continue
		var col: int = j % cols
		var row: int = j / cols
		var x: float = gap + col * (icon_s + gap + 26)
		var y: float = dy + row * (icon_s + gap + 24)

		if y > 340:
			break

		# 品质框
		var qclr: Color = UIUtils.qcolor(eqp.get("quality", 0))
		var qp: Panel = Panel.new()
		qp.position = Vector2(x - 1, y - 1)
		qp.size = Vector2(icon_s + 2, icon_s + 2)
		var qb := StyleBoxFlat.new()
		qb.bg_color = Color(1,1,1,0)
		qb.border_width_left = 2; qb.border_width_right = 2
		qb.border_width_top = 2; qb.border_width_bottom = 2
		qb.border_color = qclr
		qp.add_theme_stylebox_override("panel", qb)
		dp.add_child(qp)

		var bg: ColorRect = ColorRect.new()
		bg.position = Vector2(x, y)
		bg.size = Vector2(icon_s, icon_s)
		bg.color = Color(0.10, 0.11, 0.18)
		dp.add_child(bg)

		var eq_icon: Label = Label.new()
		eq_icon.text = eqp.get("icon", "?")
		eq_icon.add_theme_font_size_override("font_size", 22)
		eq_icon.position = Vector2(x + 4, y + 2)
		dp.add_child(eq_icon)

		# 名字 + 精华数
		var q: int = eqp.get("quality", 0)
		var ename: Label = Label.new()
		ename.text = eqp.get("base_name","?") + "  +" + str([1,3,8,20,50][q])
		ename.add_theme_font_size_override("font_size", 8)
		ename.add_theme_color_override("font_color", qclr)
		ename.position = Vector2(x, y + icon_s + 2)
		ename.size = Vector2(icon_s, 12)
		ename.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		dp.add_child(ename)

		# 复选框
		var cb: CheckBox = CheckBox.new()
		cb.position = Vector2(x + 2, y + 2)
		cb.size = Vector2(14, 14)
		cb.button_pressed = false
		var cbi := StyleBoxFlat.new()
		cbi.bg_color = Color(0.1, 0.1, 0.2, 0.85)
		cbi.border_width_left = 1; cbi.border_width_right = 1
		cbi.border_width_top = 1; cbi.border_width_bottom = 1
		cbi.border_color = Color(0.6, 0.6, 0.6)
		cbi.set_corner_radius_all(2)
		cb.add_theme_stylebox_override("normal", cbi)
		var cbi2 := StyleBoxFlat.new()
		cbi2.bg_color = Color(0.3, 0.6, 0.3, 0.85)
		cbi2.border_width_left = 1; cbi2.border_width_right = 1
		cbi2.border_width_top = 1; cbi2.border_width_bottom = 1
		cbi2.border_color = Color(0.3, 1.0, 0.3)
		cbi2.set_corner_radius_all(2)
		cb.add_theme_stylebox_override("pressed", cbi2)
		var ej: int = j
		cb.toggled.connect(func(p: bool):
			if p:
				dismantle_targets.append(ej)
			else:
				dismantle_targets.erase(ej)
			_update_essence.call()
		)
		dp.add_child(cb)
		checkboxes.append(cb)

	# 全选/取消 联动
	select_all_btn.pressed.connect(func():
		for cb in checkboxes:
			cb.button_pressed = true
	)
	deselect_btn.pressed.connect(func():
		for cb in checkboxes:
			cb.button_pressed = false
	)

	# 确认分解
	var confirm_btn: Button = Button.new()
	confirm_btn.text = "确认分解"
	confirm_btn.position = Vector2(12, 350)
	confirm_btn.size = Vector2(100, 30)
	UIUtils.btn_style_mini(confirm_btn, Color(0.25, 0.1, 0.15))
	confirm_btn.pressed.connect(func():
		if dismantle_targets.is_empty():
			return
		var total_essence: int = 0
		var removed: Array[int] = []
		for ei in dismantle_targets:
			if ei < 0 or ei >= equip_instances.size():
				continue
			var ep: Dictionary = equip_instances[ei]
			total_essence += [1, 3, 8, 20, 50][ep.get("quality", 0)]
			removed.append(ei)
		removed.sort()
		for k in range(removed.size() - 1, -1, -1):
			equip_instances.remove_at(removed[k])
		print("[装备] 分解完成, 获得精华:", total_essence)
		dp.queue_free()
		main_panel.queue_free()
		_show_inventory_panel()
	)
	dp.add_child(confirm_btn)

	main_panel.add_child(dp)


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
		top_bar.refresh()
		inventory.remove_item(slot_idx, 1)


## ============ 主角属性详情面板 ============
## ============ 主角属性计算 ============
func _calc_player_stats() -> Dictionary:
	var lv: int = player_level
	var hp_base: int = 500 + (lv - 1) * 80
	var atk_base: int = 25 + (lv - 1) * 2
	var def_base: int = 15 + (lv - 1) * 1
	var hp_equip: int = 0
	var atk_equip: int = 0
	var def_equip: int = 0
	var spd: int = 0
	var luk: int = 0
	var crit: float = 0
	var critdmg: float = 0
	var hit: float = 0
	var dodge: float = 0
	var block: float = 0
	var skill_dmg: float = 0
	var cd_reduce: float = 0
	var lifesteal: float = 0.0
	var gold_bonus: float = 0.0
	var exp_bonus: float = 0.0

	# 遍历已装备的
	for ei in range(equip_instances.size()):
		var ep: Dictionary = equip_instances[ei]
		if not ep.get("equipped", false):
			continue
		var mv: float = ep.get("main_value", 0.0)
		var ms: String = ep.get("main_stat", "")
		var enhance: int = ep.get("enhance", 0)
		var mult: float = 1.0 + enhance * 0.03
		match ms:
			"生命值":   hp_equip += int(mv * mult)
			"攻击力":   atk_equip += int(mv * mult)
			"防御力":   def_equip += int(mv * mult)
			"速度":     spd += int(mv)
			"暴击率":   crit += mv
			"技能伤害": skill_dmg += mv
			"格挡率":   block += mv
			"闪避率":   dodge += mv

		# 词条加成（18词条全覆盖）
		for aff in ep.get("affixes", []):
			var av: float = aff.get("value", 0.0)
			match aff.get("name", ""):
				"攻击%":      atk_equip += int(atk_base * av / 100.0)
				"攻击(数值)": atk_equip += int(av)
				"防御%":      def_equip += int(def_base * av / 100.0)
				"防御(数值)": def_equip += int(av)
				"生命%":      hp_equip += int(hp_base * av / 100.0)
				"速度":       spd += int(av)
				"幸运":       luk += int(av)
				"暴击率":     crit += av
				"暴击伤害":   critdmg += av
				"命中":       hit += av
				"闪避率":     dodge += av
				"格挡率":     block += av
				"技能伤害":   skill_dmg += av
				"冷却缩减":   cd_reduce += av
				"吸血":       lifesteal += av
				"金币加成":   gold_bonus += av
				"经验加成":   exp_bonus += av

	# 预留：天命卡加成
	# 套装 2 件效果统一在最终属性入口结算；3/4 件触发效果由战斗引擎处理。
	var suit_counts := _count_equipped_suits()
	if int(suit_counts.get("龙鳞", 0)) >= 2:
		def_equip += int((def_base + def_equip) * 0.15)
	if int(suit_counts.get("烈焰", 0)) >= 2:
		atk_equip += int((atk_base + atk_equip) * 0.10)
	if int(suit_counts.get("冰霜", 0)) >= 2:
		spd += 10
	if int(suit_counts.get("雷霆", 0)) >= 2:
		crit += 8.0
	if int(suit_counts.get("疾风", 0)) >= 2:
		spd += 20
	if int(suit_counts.get("铁壁", 0)) >= 2:
		block += 8.0
	if int(suit_counts.get("暗影", 0)) >= 2:
		critdmg += 25.0
	if int(suit_counts.get("自然", 0)) >= 2:
		lifesteal += 3.0
	if int(suit_counts.get("引力", 0)) >= 2:
		gold_bonus += 30.0
	if int(suit_counts.get("引力", 0)) >= 3:
		luk += 15
	if int(suit_counts.get("星辰", 0)) >= 2:
		cd_reduce += 10.0
	if int(suit_counts.get("幻影", 0)) >= 2:
		dodge += 8.0
	if int(suit_counts.get("口才", 0)) >= 2:
		luk += 10
	if int(suit_counts.get("奢侈", 0)) >= 2:
		gold_bonus -= 50.0

	# 预留：天命卡加成
	var fate: Dictionary = _calc_fate_bonus()
	# 预留：神祇祝福加成
	var deity: Dictionary = _calc_deity_bonus()

	# 自由属性点加成（v0.2: 每级2点）
	var free_atk_pct: float = player_stat_atk * 0.018    # 每点+1.8%最终伤害
	var free_def_pct: float = minf(player_stat_def * 0.015, 0.50)    # 每点+1.5%直接减伤（上限50%）
	var free_spd_pct: float = minf(player_stat_spd * 0.008, 0.50)    # 每点-0.8%出手CD（上限50%）
	var free_luk_pct: float = player_stat_luk * 0.015    # 每点+1.5%稀有掉落

	return {
		"hp": hp_base + hp_equip, "hp_base": hp_base, "hp_equip": hp_equip,
		"atk": atk_base + atk_equip, "atk_base": atk_base, "atk_equip": atk_equip, "free_atk_pct": free_atk_pct,
		"def": def_base + def_equip, "def_base": def_base, "def_equip": def_equip, "free_def_pct": free_def_pct,
		"spd": spd + player_stat_spd, "luk": luk + player_stat_luk,
		"free_spd_pct": free_spd_pct, "free_luk_pct": free_luk_pct,
		"crit": int(crit), "critdmg": int(150 + critdmg),
		"hit": int(hit), "dodge": int(dodge), "block": int(block),
		"skill_dmg": int(skill_dmg), "cd_reduce": int(cd_reduce),
		"lifesteal": lifesteal,
		"gold_bonus": gold_bonus, "exp_bonus": exp_bonus,
		"free_stat_atk": player_stat_atk,
		"free_stat_def": player_stat_def,
		"free_stat_spd": player_stat_spd,
		"free_stat_luk": player_stat_luk,
	}


## 预留：计算天命卡加成（待天命卡系统开发后实现）
## 遍历 _fate_cards，叠加 stat_bonus
func _calc_fate_bonus() -> Dictionary:
	return {}  # TODO: 从 _fate_cards 累加各卡片的 stat_bonus


## 预留：计算神祇祝福加成（待神祇系统开发后实现）
## 遍历 _deity_buffs，叠加 stat_bonus
func _calc_deity_bonus() -> Dictionary:
	return {}  # TODO: 从 _deity_buffs 累加各祝福的 stat_bonus


## 预留：激活天命卡（待天命卡系统开发后实现）
func _apply_fate_card(card_data: Dictionary) -> void:
	_fate_cards.append(card_data)
	_refresh_all_stats_panels()


## 预留：应用神祇祝福（待神祇系统开发后实现）
func _apply_deity_buff(buff_data: Dictionary) -> void:
	_deity_buffs.append(buff_data)
	_refresh_all_stats_panels()


## ============ 技能面板 ============
func _build_skill_tab(panel: Panel) -> void:
	var sec_y: float = 50.0

	# 装备技能槽位
	var eq_title: Label = Label.new()
	eq_title.text = "装备技能槽位"
	eq_title.add_theme_font_size_override("font_size", 13)
	eq_title.add_theme_color_override("font_color", Color(0.7, 0.85, 1.0))
	eq_title.position = Vector2(16, sec_y)
	panel.add_child(eq_title)

	# ? 说明按钮
	var help_btn: Button = Button.new()
	help_btn.text = "?"
	help_btn.position = Vector2(114, sec_y - 3)
	help_btn.size = Vector2(22, 22)
	help_btn.add_theme_font_size_override("font_size", 11)
	UIUtils.btn_style_mini(help_btn, Color(0.15, 0.22, 0.38))
	help_btn.pressed.connect(func():
		_show_stat_tooltip("优先级规则", "点击数字 ①/②/③ 切换优先级\n右键已装备技能可卸下\n\n技能按自身行动次数冷却\n同时就绪时：③>②>①\n同级按槽位从左到右释放\n全部冷却中→普攻\n\n槽位解锁(角色等级):\nLv.1=2槽  Lv.5=3槽  Lv.15=4槽\nLv.35=5槽  Lv.45=6槽")
	)
	panel.add_child(help_btn)

	var slot_w: float = 280.0
	var slot_h: float = 64.0
	var gap_x: float = 12.0
	var gap_y: float = 8.0
	var cols: int = 2
	var max_slots: int = skill_system.get_slot_count()
	var unlocked: int = skill_system.get_unlocked_slots()

	for i in range(max_slots):
		var col: int = i % cols
		var row: int = i / cols
		var sx: float = 16.0 + col * (slot_w + gap_x)
		var sy: float = sec_y + 30.0 + row * (slot_h + gap_y)
		var sid: Variant = skill_system.get_slot_skill_id(i)
		var is_locked: bool = (i >= unlocked)

		if is_locked:
			# 锁定槽
			var lock_bg: Panel = Panel.new()
			lock_bg.position = Vector2(sx, sy)
			lock_bg.size = Vector2(slot_w, slot_h)
			var lock_st := StyleBoxFlat.new()
			lock_st.bg_color = Color(0.08, 0.09, 0.14)
			lock_st.border_width_left = 1
			lock_st.border_width_right = 1
			lock_st.border_width_top = 1
			lock_st.border_width_bottom = 1
			lock_st.border_color = Color(0.2, 0.2, 0.3)
			lock_bg.add_theme_stylebox_override("panel", lock_st)
			panel.add_child(lock_bg)
			var lock_lbl: Label = Label.new()
			var unlock_lv: int = [0, 0, 0, 5, 15, 35, 45][i+1] if i+1 < 7 else 45
			lock_lbl.text = "🔒 角色Lv." + str(unlock_lv) + " 解锁"
			lock_lbl.add_theme_font_size_override("font_size", 12)
			lock_lbl.add_theme_color_override("font_color", Color(0.4, 0.4, 0.5))
			lock_lbl.position = Vector2(sx + 100, sy + 22)
			panel.add_child(lock_lbl)
		elif sid != null:
			# 已装备技能
			var sdata: Dictionary = SkillDataRef.get_skill(sid)
			var priority: int = skill_system.get_slot_priority(i)
			var prio_icons: String = ["①", "②", "③"][priority-1]
			var school_clr: Color = _skill_school_color(sdata.get("school", 0))

			var skill_bg: Panel = Panel.new()
			skill_bg.position = Vector2(sx, sy)
			skill_bg.size = Vector2(slot_w, slot_h)
			var sb := StyleBoxFlat.new()
			sb.bg_color = school_clr.darkened(0.7)
			sb.border_width_left = 1
			sb.border_width_right = 1
			sb.border_width_top = 1
			sb.border_width_bottom = 1
			sb.border_color = school_clr
			skill_bg.add_theme_stylebox_override("panel", sb)
			panel.add_child(skill_bg)

			var icon_lbl: Label = Label.new()
			icon_lbl.text = sdata.get("icon", "?")
			icon_lbl.add_theme_font_size_override("font_size", 22)
			icon_lbl.position = Vector2(sx + 8, sy + 10)
			panel.add_child(icon_lbl)

			var name_lbl: Label = Label.new()
			name_lbl.text = sdata.get("name", "??")
			name_lbl.add_theme_font_size_override("font_size", 14)
			name_lbl.add_theme_color_override("font_color", Color(1, 1, 1))
			name_lbl.position = Vector2(sx + 52, sy + 12)
			panel.add_child(name_lbl)

			var cd_lbl: Label = Label.new()
			cd_lbl.text = "间隔 " + SkillDataRef.action_cd_text(sdata)
			cd_lbl.add_theme_font_size_override("font_size", 11)
			cd_lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7))
			cd_lbl.position = Vector2(sx + 52, sy + 32)
			panel.add_child(cd_lbl)

			# 优先级按钮（2.5x放大）
			var prio_btn: Button = Button.new()
			prio_btn.text = prio_icons
			prio_btn.position = Vector2(sx + slot_w - 100, sy + 7)
			prio_btn.size = Vector2(90, 50)
			prio_btn.add_theme_font_size_override("font_size", 26)
			var prio_clr: Color = [Color(0.6, 0.6, 0.6), Color(0.3, 1.0, 0.6), Color(0.3, 0.6, 1.0)][priority-1]
			UIUtils.btn_style_mini(prio_btn, Color(0.12, 0.14, 0.22))
			prio_btn.add_theme_color_override("font_color", prio_clr)
			var si: int = i
			prio_btn.pressed.connect(func():
				skill_system.toggle_priority(si)
				_stats_tab = "skill"
				_refresh_stats_panel()
			)
			panel.add_child(prio_btn)

			# 点击查看详情
			var detail_btn: Button = Button.new()
			detail_btn.flat = true
			detail_btn.position = Vector2(sx, sy)
			detail_btn.size = Vector2(slot_w - 50, slot_h)
			UIUtils.btn_transparent2(detail_btn)
			var sid_cap: int = sid
			detail_btn.gui_input.connect(func(ev: InputEvent):
				if ev is InputEventMouseButton and ev.pressed:
					if ev.button_index == MOUSE_BUTTON_RIGHT:
						skill_system.unequip_skill(si)
						panel.queue_free()
						_show_stats_panel()
					elif ev.button_index == MOUSE_BUTTON_LEFT:
						_show_skill_tooltip(sid_cap, true, si, panel)
			)
			panel.add_child(detail_btn)
		else:
			# 空槽
			var empty_bg: Panel = Panel.new()
			empty_bg.position = Vector2(sx, sy)
			empty_bg.size = Vector2(slot_w, slot_h)
			var es := StyleBoxFlat.new()
			es.bg_color = Color(1,1,1,0)
			es.border_width_left = 1
			es.border_width_right = 1
			es.border_width_top = 1
			es.border_width_bottom = 1
			es.border_color = Color(0.25, 0.25, 0.35)
			es.set_corner_radius_all(4)
			empty_bg.add_theme_stylebox_override("panel", es)
			panel.add_child(empty_bg)
			var empty_lbl: Label = Label.new()
			empty_lbl.text = "空槽位 " + str(i+1) + "/" + str(max_slots)
			empty_lbl.add_theme_font_size_override("font_size", 12)
			empty_lbl.add_theme_color_override("font_color", Color(0.35, 0.35, 0.4))
			empty_lbl.position = Vector2(sx + 100, sy + 22)
			panel.add_child(empty_lbl)

	# 分隔
	var pool_y: float = sec_y + 30.0 + ((max_slots + 1) / cols) * (slot_h + gap_y) + 8
	var sep: ColorRect = ColorRect.new()
	sep.position = Vector2(16, pool_y)
	sep.size = Vector2(568, 1)
	sep.color = Color(0.2, 0.2, 0.3)
	panel.add_child(sep)

	# 技能池标题
	pool_y += 10
	var pool_title: Label = Label.new()
	pool_title.text = "技能池"
	pool_title.add_theme_font_size_override("font_size", 13)
	pool_title.add_theme_color_override("font_color", Color(0.7, 0.85, 1.0))
	pool_title.position = Vector2(16, pool_y)
	panel.add_child(pool_title)

	# 流派筛选按钮
	pool_y += 22
	var school_names: Array[String] = ["全部", "爆发", "持续", "控制", "生存", "Dot", "贯穿"]
	var school_colors: Array[Color] = [
		Color(0.5,0.5,0.5), Color(0.8,0.3,0.3), Color(0.3,0.7,0.9),
		Color(0.3,0.6,1.0), Color(0.2,0.8,0.4), Color(0.7,0.3,0.9), Color(1.0,0.6,0.2)
	]
	for qi in range(school_names.size()):
		var qb: Button = Button.new()
		qb.text = school_names[qi]
		qb.position = Vector2(16 + qi * 48, pool_y)
		qb.size = Vector2(44, 22)
		qb.add_theme_font_size_override("font_size", 11)
		var selected: bool = (_skill_filter == qi - 1 and qi > 0) or (qi == 0 and _skill_filter < 0)
		if selected:
			# 选中：亮背景 + 白色边框
			var sel_s := StyleBoxFlat.new()
			sel_s.bg_color = school_colors[qi].lightened(0.2)
			sel_s.border_width_left = 2; sel_s.border_width_right = 2
			sel_s.border_width_top = 2; sel_s.border_width_bottom = 2
			sel_s.border_color = Color(1.0, 1.0, 1.0, 0.85)
			sel_s.set_corner_radius_all(3)
			qb.add_theme_stylebox_override("normal", sel_s)
		else:
			UIUtils.btn_style_mini(qb, school_colors[qi].darkened(0.5))
		qb.add_theme_color_override("font_color", Color(1,1,1) if selected else school_colors[qi])
		qb.pressed.connect(func():
			_skill_filter = qi - 1 if qi > 0 else -1
			_stats_tab = "skill"
			_refresh_stats_panel()
		)
		panel.add_child(qb)

	# 技能网格（ScrollContainer 支持滚动查看全部技能）
	var pcol: int = 4
	var grid_y: float = pool_y + 30.0
	var icon_s: float = 140.0
	var i_gap: float = 8.0

	# 筛选可用技能
	var all_skills: Array[Dictionary] = []
	for s in SkillDataRef.SKILLS:
		if _skill_filter >= 0 and s["school"] != _skill_filter:
			continue
		all_skills.append(s)
	all_skills.sort_custom(func(a: Dictionary, b: Dictionary):
		var a_unlocked: bool = bool(skill_system.is_skill_unlocked(int(a["id"])))
		var b_unlocked: bool = bool(skill_system.is_skill_unlocked(int(b["id"])))
		if a_unlocked != b_unlocked:
			return a_unlocked
		return int(a["id"]) < int(b["id"])
	)

	# ScrollContainer 包裹技能网格
	var scroll: ScrollContainer = ScrollContainer.new()
	var scroll_top: float = grid_y
	var scroll_height: float = panel.size.y - scroll_top - 10
	scroll.position = Vector2(8, scroll_top)
	scroll.size = Vector2(panel.size.x - 20, scroll_height)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true

	# 滚动内容容器
	var content: Control = Control.new()
	content.name = "SkillGridContent"
	var total_rows: int = ceili(float(all_skills.size()) / pcol)
	var content_h: float = total_rows * 52.0 + 8
	content.custom_minimum_size = Vector2(panel.size.x - 24, content_h)
	scroll.add_child(content)

	for si in range(all_skills.size()):
		var sdata: Dictionary = all_skills[si]
		var is_unlocked: bool = skill_system.is_skill_unlocked(int(sdata["id"]))
		var col_i: int = si % pcol
		var row_i: int = si / pcol
		var cx: float = 4.0 + col_i * (icon_s + i_gap)
		var cy: float = 4.0 + row_i * 52.0

		var equipped: bool = false
		var equipped_slot: int = -1
		for ei in range(unlocked):
			var esid = skill_system.get_slot_skill_id(ei)
			if esid == sdata["id"]:
				equipped = true
				equipped_slot = ei
				break

		var sc: Color = _skill_school_color(sdata.get("school", 0))
		var p_style: StyleBoxFlat = StyleBoxFlat.new()
		p_style.bg_color = (sc.darkened(0.5) if not equipped else sc.darkened(0.3)) if is_unlocked else Color(0.08, 0.08, 0.1)
		p_style.border_width_left = 1
		p_style.border_width_right = 1
		p_style.border_width_top = 1
		p_style.border_width_bottom = 1
		p_style.border_color = sc if is_unlocked else Color(0.28, 0.28, 0.32)
		p_style.set_corner_radius_all(4)
		var pool_bg: Panel = Panel.new()
		pool_bg.position = Vector2(cx, cy)
		pool_bg.size = Vector2(icon_s, 48)
		pool_bg.add_theme_stylebox_override("panel", p_style)
		content.add_child(pool_bg)

		var pool_icon: Label = Label.new()
		pool_icon.text = sdata.get("icon", "?")
		pool_icon.add_theme_font_size_override("font_size", 18)
		pool_icon.position = Vector2(cx + 6, cy + 6)
		content.add_child(pool_icon)

		var pool_name: Label = Label.new()
		pool_name.text = sdata.get("name", "??")
		pool_name.add_theme_font_size_override("font_size", 12)
		pool_name.add_theme_color_override("font_color", Color(1,1,1) if is_unlocked else Color(0.55,0.55,0.58))
		pool_name.position = Vector2(cx + 34, cy + 6)
		content.add_child(pool_name)

		var pool_info: Label = Label.new()
		if equipped:
			pool_info.text = "已装备 · " + SkillDataRef.action_cd_text(sdata)
		elif is_unlocked:
			pool_info.text = SkillDataRef.action_cd_text(sdata) + " · 已解锁"
		else:
			pool_info.text = "🔒 " + str(sdata.get("price", 0)) + " 金币"
		pool_info.add_theme_font_size_override("font_size", 10)
		pool_info.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7))
		pool_info.position = Vector2(cx + 34, cy + 24)
		content.add_child(pool_info)

		# 点击查看详情 + 装备/卸下（tooltip内操作）
		var click_btn: Button = Button.new()
		click_btn.flat = true
		click_btn.position = Vector2(cx, cy)
		click_btn.size = Vector2(icon_s, 48)
		UIUtils.btn_transparent2(click_btn)
		var sid_val: int = sdata["id"]
		var eq_slot: int = equipped_slot
		click_btn.pressed.connect(func():
			_close_all_tooltips()
			_show_skill_tooltip(sid_val, equipped, eq_slot, panel)
		)
		content.add_child(click_btn)

	panel.add_child(scroll)


## 技能提示（支持装备/卸下操作）
## already_equipped: 是否已装备, equipped_slot: 已装备的槽位号(-1=未装备), parent_panel: 父面板(用于刷新)
func _show_skill_tooltip(skill_id: int, already_equipped: bool = false, equipped_slot: int = -1, parent_panel: Panel = null) -> void:
	var sdata: Dictionary = SkillDataRef.get_skill(skill_id)
	if sdata.is_empty():
		return
	var is_unlocked: bool = skill_system.is_skill_unlocked(skill_id)

	# 清除旧 tooltip
	var old_tip: Node = get_node_or_null("SkillTooltip")
	if old_tip:
		old_tip.queue_free()

	var tip: Panel = Panel.new()
	tip.name = "SkillTooltip"
	tip.position = Vector2(360, 160)
	tip.size = Vector2(300, 260)
	UIUtils.panel_style(tip, Color(0.05, 0.06, 0.12, 0.96))
	_tooltip_nodes.append(tip)

	var sc: Color = _skill_school_color(sdata.get("school", 0))
	# 顶部品质色条
	var top_bar_rect: ColorRect = ColorRect.new()
	top_bar_rect.position = Vector2(0, 0)
	top_bar_rect.size = Vector2(300, 3)
	top_bar_rect.color = sc
	tip.add_child(top_bar_rect)

	var title: Label = Label.new()
	title.text = sdata.get("icon", "?") + " " + sdata.get("name", "???")
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", sc)
	title.position = Vector2(16, 10)
	tip.add_child(title)

	# 流派 + CD + 目标
	var school_lbl: Label = Label.new()
	var target_str: String = ""
	match sdata.get("target", -1):
		0: target_str = "前单"
		1: target_str = "后单"
		2: target_str = "最低HP"
		3: target_str = "最低HP%"
		4: target_str = "最高攻"
		5: target_str = "最高防"
		6: target_str = "前排全体"
		7: target_str = "全体"
		8: target_str = "后排全体"
		9: target_str = "贯穿"
		10: target_str = "自身"
		11: target_str = "自身治疗"
	school_lbl.text = SkillDataRef.school_name(sdata.get("school", 0)) + "  |  间隔 " + SkillDataRef.action_cd_text(sdata) + ("  |  " + target_str if not target_str.is_empty() else "")
	school_lbl.add_theme_font_size_override("font_size", 12)
	school_lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7))
	school_lbl.position = Vector2(16, 34)
	tip.add_child(school_lbl)

	# 分隔
	var sep1: ColorRect = ColorRect.new()
	sep1.position = Vector2(8, 54)
	sep1.size = Vector2(284, 1)
	sep1.color = Color(0.2, 0.2, 0.3)
	tip.add_child(sep1)

	# 详细效果
	var sy: float = 60.0
	var desc: String = sdata.get("desc", "")
	if sdata.has("dmg_pct"):
		desc += "\n伤害倍率: " + str(sdata["dmg_pct"]) + "%"
		if sdata.has("hits") and sdata["hits"] > 1:
			desc += " ×" + str(sdata["hits"]) + "次"
	if sdata.has("control"):
		var cname: String = SkillDataRef.control_name(sdata.get("control", -1))
		if not cname.is_empty():
			desc += "\n控制: " + cname + " " + str(sdata.get("control_dur", 0)) + "秒"
	if sdata.has("dot_pct"):
		desc += "\nDot: " + str(sdata["dot_pct"]) + "%/次 ×" + str(sdata.get("dot_dur", 0)) + "秒"
	if sdata.has("shield_pct"):
		desc += "\n护盾: " + str(sdata["shield_pct"]) + "% " + sdata.get("shield_stat", "def")
	if sdata.has("heal_pct"):
		desc += "\n治疗: " + str(sdata["heal_pct"]) + "% " + sdata.get("heal_stat", "atk")

	if sdata.has("bonus"):
		var bonus: Dictionary = sdata["bonus"]
		if bonus.has("ignore_def_pct"):
			desc += "\n无视防御: " + str(bonus["ignore_def_pct"]) + "%"
		if bonus.has("execute_threshold"):
			desc += "\nHP<" + str(int(bonus["execute_threshold"] * 100)) + "%时伤害×" + str(bonus["execute_mult"])
		if bonus.has("missing_hp_scale"):
			desc += "\n每损失1%HP +" + str(bonus["missing_hp_scale"]) + "%伤害"
		if bonus.has("detonate_dot"):
			desc += "\n结算Dot剩余伤害×" + str(bonus["detonate_dot"])
		if bonus.has("spread_dot"):
			desc += "\n复制Dot到全体敌人"

	var body: Label = Label.new()
	body.text = desc
	body.add_theme_font_size_override("font_size", 12)
	body.add_theme_color_override("font_color", Color(0.8, 0.8, 0.85))
	body.position = Vector2(16, sy)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD
	body.size = Vector2(270, 120)
	tip.add_child(body)

	# 底部操作按钮
	var btn_y: float = tip.size.y - 38
	if not is_unlocked:
		var buy_btn: Button = Button.new()
		var price: int = int(sdata.get("price", 0))
		buy_btn.text = "解锁  " + str(price) + " 金币"
		buy_btn.position = Vector2(16, btn_y)
		buy_btn.size = Vector2(150, 28)
		UIUtils.btn_style_mini(buy_btn, Color(0.35, 0.25, 0.08))
		buy_btn.disabled = player_gold < price
		var sid_buy: int = skill_id
		buy_btn.pressed.connect(func():
			if player_gold < price:
				_show_float_text("金币不足，需要 " + str(price) + " 金币", Color(1.0, 0.4, 0.3))
				return
			player_gold -= price
			skill_system.unlock_skill(sid_buy)
			_auto_save()
			_close_all_tooltips()
			if is_instance_valid(parent_panel):
				parent_panel.queue_free()
			_show_stats_panel()
		)
		tip.add_child(buy_btn)
	elif already_equipped and equipped_slot >= 0:
		# 已装备 → 卸下按钮
		var unequip_btn: Button = Button.new()
		unequip_btn.text = "卸下"
		unequip_btn.position = Vector2(16, btn_y)
		unequip_btn.size = Vector2(80, 28)
		UIUtils.btn_style_mini(unequip_btn, Color(0.35, 0.12, 0.12))
		unequip_btn.add_theme_color_override("font_color", Color(1.0, 0.6, 0.6))
		var slot_idx: int = equipped_slot
		unequip_btn.pressed.connect(func():
			skill_system.unequip_skill(slot_idx)
			_close_all_tooltips()
			if is_instance_valid(parent_panel):
				parent_panel.queue_free()
			_show_stats_panel()
		)
		tip.add_child(unequip_btn)
	else:
		# 未装备 → 装备按钮（按1~6找空位）
		var equip_btn: Button = Button.new()
		equip_btn.text = "装备"
		equip_btn.position = Vector2(16, btn_y)
		equip_btn.size = Vector2(80, 28)
		UIUtils.btn_style_mini(equip_btn, Color(0.15, 0.28, 0.45))
		equip_btn.add_theme_color_override("font_color", Color(0.3, 1.0, 0.6))
		var sid_v: int = skill_id
		equip_btn.pressed.connect(func():
			var ok: bool = skill_system.equip_skill(sid_v)
			if ok:
				_close_all_tooltips()
				if is_instance_valid(parent_panel):
					parent_panel.queue_free()
				_show_stats_panel()
			else:
				_show_float_text("技能槽位已满，无空位可装备", Color(1.0, 0.5, 0.3))
		)
		tip.add_child(equip_btn)

	# 关闭按钮
	var close_btn: Button = Button.new()
	close_btn.text = "✕"
	close_btn.position = Vector2(tip.size.x - 38, btn_y)
	close_btn.size = Vector2(26, 28)
	UIUtils.btn_style_mini(close_btn, Color(0.25, 0.1, 0.1))
	close_btn.pressed.connect(_close_all_tooltips)
	tip.add_child(close_btn)

	# 遮罩
	_ensure_overlay()
	add_child(tip)


## 技能流派颜色
func _skill_school_color(school: int) -> Color:
	match school:
		0: return Color(0.8, 0.3, 0.2)   # 爆发流·红
		1: return Color(0.3, 0.7, 0.9)   # 持续流·蓝
		2: return Color(0.3, 0.6, 1.0)   # 控制流·靛蓝
		3: return Color(0.2, 0.8, 0.4)   # 生存流·绿
		4: return Color(0.7, 0.3, 0.9)   # Dot流·紫
		5: return Color(1.0, 0.6, 0.2)   # 贯穿流·橙
	return Color(0.5, 0.5, 0.5)


var _skill_filter: int = -1  # -1=全部, 0~5=流派


## ============ 面板内部刷新（不触发 toggle） ============
func _refresh_stats_panel() -> void:
	var old: Node = get_node_or_null("StatsPanel")
	if old:
		old.queue_free()
	# 直接重建（用 call_deferred 等当前帧释放完）
	call_deferred("_show_stats_panel")


## ============ 属性面板 ============## ============ 角色属性/技能面板（分页） ============
var _stats_tab: String = "stats"  # "stats" | "skill"

## 强制打开面板（头像点击用，不 toggle 关闭，始终重建）
func _open_stats_panel() -> void:
	var old: Node = get_node_or_null("StatsPanel")
	if old:
		old.queue_free()
	call_deferred("_show_stats_panel")


func _show_stats_panel() -> void:
	# 移除旧面板（点击✕关闭时用于 toggle）
	var old: Node = get_node_or_null("StatsPanel")
	if old:
		old.queue_free()
		return

	var panel: Panel = Panel.new()
	panel.name = "StatsPanel"
	panel.position = Vector2(140, 40)
	panel.size = Vector2(600, 680)
	UIUtils.panel_style(panel, Color(0.08, 0.09, 0.15))

	# 标题 + 分页按钮
	var title: Label = Label.new()
	title.text = "📋 " + player_name + "  Lv." + str(player_level)
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	title.position = Vector2(20, 12)
	panel.add_child(title)

	# 分页按钮
	var tab_defs := [
		{ "id": "stats", "text": "属性", "x": 400 },
		{ "id": "skill", "text": "技能", "x": 480 },
	]
	for td in tab_defs:
		var tb: Button = Button.new()
		tb.text = td["text"]
		tb.position = Vector2(td["x"], 8)
		tb.size = Vector2(70, 28)
		tb.add_theme_font_size_override("font_size", 14)
		var is_active: bool = (_stats_tab == td["id"])
		if is_active:
			var ta := StyleBoxFlat.new()
			ta.bg_color = Color(0.15, 0.18, 0.28)
			ta.border_width_bottom = 2
			ta.border_color = Color(0.3, 0.6, 1.0)
			tb.add_theme_stylebox_override("normal", ta)
			tb.add_theme_color_override("font_color", Color(1,1,1))
		else:
			var ta2 := StyleBoxFlat.new()
			ta2.bg_color = Color(0.08, 0.09, 0.15)
			tb.add_theme_stylebox_override("normal", ta2)
			tb.add_theme_color_override("font_color", Color(0.4, 0.45, 0.5))
		tb.flat = true
		var tid: String = td["id"]
		tb.pressed.connect(func():
			if _stats_tab == tid:
				return
			_stats_tab = tid
			_refresh_stats_panel()
		)
		panel.add_child(tb)

	var close: Button = Button.new()
	close.text = "✕"
	close.position = Vector2(558, 8)
	close.size = Vector2(30, 28)
	UIUtils.btn_style_mini(close, Color(0.3, 0.1, 0.1))
	close.pressed.connect(panel.queue_free)
	panel.add_child(close)

	if _stats_tab == "skill":
		_build_skill_tab(panel)
		add_child(panel)
		return

	# ========== 属性面板内容 ==========

	# 经验条
	var exp_bar: ProgressBar = ProgressBar.new()
	exp_bar.position = Vector2(20, 44)
	exp_bar.size = Vector2(560, 14)
	exp_bar.value = player_exp
	exp_bar.max_value = player_exp_max
	UIUtils.bar_style(exp_bar, Color(0.15, 0.35, 0.6))
	panel.add_child(exp_bar)

	var exp_lbl: Label = Label.new()
	exp_lbl.text = str(player_exp) + " / " + str(player_exp_max)
	exp_lbl.add_theme_font_size_override("font_size", 10)
	exp_lbl.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	exp_lbl.position = Vector2(20, 60)
	panel.add_child(exp_lbl)

	# ============ 自由属性点区域 ============
	var free_sec_y: float = 82.0

	var free_bg: ColorRect = ColorRect.new()
	free_bg.position = Vector2(16, free_sec_y)
	free_bg.size = Vector2(568, 80)
	free_bg.color = Color(0.12, 0.14, 0.22)
	panel.add_child(free_bg)

	var free_title: Label = Label.new()
	free_title.text = "✨ 自由属性点: " + str(player_free_points)
	free_title.add_theme_font_size_override("font_size", 14)
	free_title.add_theme_color_override("font_color", Color(0.3, 1.0, 0.6) if player_free_points > 0 else Color(0.6, 0.6, 0.7))
	free_title.position = Vector2(28, free_sec_y + 4)
	panel.add_child(free_title)

	# 洗点按钮
	var reset_btn: Button = Button.new()
	reset_btn.text = "洗点"
	reset_btn.position = Vector2(480, free_sec_y + 2)
	reset_btn.size = Vector2(60, 22)
	UIUtils.btn_style_mini(reset_btn, Color(0.3, 0.12, 0.12))
	reset_btn.add_theme_color_override("font_color", Color(1.0, 0.6, 0.6))
	reset_btn.pressed.connect(_show_reset_confirm)
	panel.add_child(reset_btn)

	# 4维自由属性
	var free_stats: Array[Dictionary] = [
		{ "name": "攻击", "key": "atk", "icon": "⚔", "value": player_stat_atk, "desc": "每点+1.8%最终伤害(无上限)" },
		{ "name": "防御", "key": "def", "icon": "🛡", "value": player_stat_def, "desc": "每点+1.2%直接减伤(上限50%)" },
		{ "name": "速度", "key": "spd", "icon": "👟", "value": player_stat_spd, "desc": "每点-0.8%出手CD(上限50%)" },
		{ "name": "幸运", "key": "luk", "icon": "🍀", "value": player_stat_luk, "desc": "每点+1.5%稀有掉落/好事件概率" },
	]
	for fi in range(free_stats.size()):
		var fs: Dictionary = free_stats[fi]
		var fx: float = 28.0 + fi * 138.0
		var fy: float = free_sec_y + 28.0

		# 标签: 图标 + 名称
		var fl: Label = Label.new()
		fl.text = fs["icon"] + " " + fs["name"]
		fl.add_theme_font_size_override("font_size", 12)
		fl.add_theme_color_override("font_color", Color(0.8, 0.85, 0.9))
		fl.position = Vector2(fx, fy)
		panel.add_child(fl)

		# 数值
		var fv: Label = Label.new()
		fv.name = "FreeStatVal_" + fs["key"]
		fv.text = str(fs["value"])
		fv.add_theme_font_size_override("font_size", 16)
		fv.add_theme_color_override("font_color", Color(1.0, 0.9, 0.3))
		fv.position = Vector2(fx, fy + 18)
		panel.add_child(fv)

		# + 按钮（有点数才显示）
		if player_free_points > 0:
			var plus_btn: Button = Button.new()
			plus_btn.text = "+"
			plus_btn.position = Vector2(fx + 50, fy + 14)
			plus_btn.size = Vector2(28, 24)
			plus_btn.add_theme_font_size_override("font_size", 16)
			var sk: String = fs["key"]
			plus_btn.pressed.connect(func(): _add_free_stat(sk))
			var pb_style := StyleBoxFlat.new()
			pb_style.bg_color = Color(0.15, 0.35, 0.15)
			pb_style.border_width_left = 1; pb_style.border_width_right = 1
			pb_style.border_width_top = 1; pb_style.border_width_bottom = 1
			pb_style.border_color = Color(0.3, 0.8, 0.3)
			plus_btn.add_theme_stylebox_override("normal", pb_style)
			plus_btn.add_theme_color_override("font_color", Color(0.3, 1.0, 0.3))
			panel.add_child(plus_btn)

	# 分隔线
	var sep_line: ColorRect = ColorRect.new()
	sep_line.position = Vector2(16, free_sec_y + 82)
	sep_line.size = Vector2(568, 1)
	sep_line.color = Color(0.2, 0.2, 0.3)
	panel.add_child(sep_line)

	# ============ 属性列表分隔结束 ============

	# 属性列表（使用真实计算的数值）—— 18词条全属性
	var ps: Dictionary = _calc_player_stats()
	var stats: Array[Dictionary] = [
		{ "icon": "❤️", "name": "生命值 (HP)",   "value": str(ps["hp"]), "raw": ps["hp_base"], "eqp": ps["hp_equip"], "desc": "归零则战斗失败，消耗1枚复活币复活。\n每级+80" },
		{ "icon": "⚔️", "name": "攻击力 (ATK)",  "value": str(ps["atk"]), "raw": ps["atk_base"], "eqp": ps["atk_equip"], "desc": "基础攻击力，与装备攻击力相加后\n受自由属性点和装备词条加成" },
		{ "icon": "🛡️", "name": "防御力 (DEF)",  "value": str(ps["def"]), "raw": ps["def_base"], "eqp": ps["def_equip"], "desc": "决定受到的伤害减免。\n减伤率 = DEF/(DEF+400)" },
		{ "icon": "👟", "name": "速度 (SPD)",    "value": str(ps["spd"]), "raw": 0, "eqp": ps["spd"], "desc": "每点-0.8%出手CD（上限50%）。\n3.0秒× (1-速度%) = 实际CD" },
		{ "icon": "🍀", "name": "幸运 (LUK)",    "value": str(ps["luk"]), "raw": 0, "eqp": ps["luk"], "desc": "每点+1.5%稀有掉落/好事件概率。\n影响宝箱品质、命运事件、战斗掉落" },
		{ "icon": "💥", "name": "暴击率",        "value": str(ps["crit"]) + "%", "raw": 0, "eqp": ps["crit"], "desc": "攻击时触发暴击的概率，普攻也可暴击。\n暴击伤害=攻击力×暴击倍率" },
		{ "icon": "💢", "name": "暴击伤害",       "value": str(ps["critdmg"]) + "%", "raw": 150, "eqp": ps["critdmg"], "desc": "暴击时的伤害倍率。\n基础150%，装备/宝石可提高" },
		{ "icon": "🎯", "name": "命中率",        "value": str(ps["hit"]) + "%", "raw": 0, "eqp": ps["hit"], "desc": "决定攻击是否命中。\n可抵消目标的闪避率" },
		{ "icon": "💨", "name": "闪避率",        "value": str(ps["dodge"]) + "%", "raw": 0, "eqp": ps["dodge"], "desc": "完全躲避攻击的概率。\n实际闪避=我方闪避-敌方命中" },
		{ "icon": "🛡️", "name": "格挡率",        "value": str(ps["block"]) + "%", "raw": 0, "eqp": ps["block"], "desc": "格挡后伤害减半。\n暴击+格挡同时触发=暴击×0.5" },
		{ "icon": "💥", "name": "技能伤害",       "value": "+" + str(ps["skill_dmg"]) + "%", "raw": 0, "eqp": ps["skill_dmg"], "desc": "技能造成的额外伤害加成。\n装备词条/宝石可提高" },
		{ "icon": "⏳", "name": "冷却缩减",       "value": "-" + str(ps["cd_reduce"]) + "%", "raw": 0, "eqp": ps["cd_reduce"], "desc": "减少技能冷却时间。\n装备词条/宝石可提高" },
		{ "icon": "🩸", "name": "吸血%",         "value": "+" + str(ps["lifesteal"]) + "%", "raw": 0, "eqp": ps["lifesteal"], "desc": "攻击时吸取伤害百分比的生命。\n装备词条可提高" },
		{ "icon": "💰", "name": "金币加成",       "value": "+" + str(ps["gold_bonus"]) + "%", "raw": 0, "eqp": ps["gold_bonus"], "desc": "战斗/宝箱获得金币的额外加成。\n天命卡/装备词条可提高" },
		{ "icon": "📖", "name": "经验加成",       "value": "+" + str(ps["exp_bonus"]) + "%", "raw": 0, "eqp": ps["exp_bonus"], "desc": "战斗获得经验的额外加成。\n天命卡/装备词条可提高" },
	]

	var sy: float = free_sec_y + 92.0
	var left_x: float = 16.0
	var right_x: float = 310.0
	var row_w: float = 278.0

	for i in range(stats.size()):
		var col: int = i % 2
		var row_idx: int = i / 2
		var rx: float = left_x if col == 0 else right_x
		var ry: float = sy + row_idx * 47.0
		var st: Dictionary = stats[i]

		# 行背景
		var row_bg: ColorRect = ColorRect.new()
		row_bg.position = Vector2(rx, ry)
		row_bg.size = Vector2(row_w, 44)
		row_bg.color = Color(0.10, 0.11, 0.18)
		panel.add_child(row_bg)

		# 图标
		var icon: Label = Label.new()
		icon.text = st["icon"]
		icon.add_theme_font_size_override("font_size", 16)
		icon.position = Vector2(rx + 8, ry + 10)
		panel.add_child(icon)

		# 名称
		var name_lbl: Label = Label.new()
		name_lbl.text = st["name"]
		name_lbl.add_theme_font_size_override("font_size", 11)
		name_lbl.add_theme_color_override("font_color", Color(0.8, 0.85, 0.9))
		name_lbl.position = Vector2(rx + 32, ry + 12)
		panel.add_child(name_lbl)

		# 数值
		var val_lbl: Label = Label.new()
		val_lbl.text = st["value"]
		val_lbl.add_theme_font_size_override("font_size", 13)
		val_lbl.add_theme_color_override("font_color", Color(1.0, 0.9, 0.3))
		val_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		val_lbl.position = Vector2(rx + 148, ry + 10)
		val_lbl.size = Vector2(80, 20)
		panel.add_child(val_lbl)

		# 点击查看说明
		var btn: Button = Button.new()
		btn.text = "?"
		btn.position = Vector2(rx + row_w - 40, ry + 8)
		btn.size = Vector2(28, 24)
		btn.add_theme_font_size_override("font_size", 10)
		UIUtils.btn_style_mini(btn, Color(0.15, 0.22, 0.38))
		var desc: String = st["desc"]
		btn.pressed.connect(func(): _show_stat_tooltip(st["name"], desc))
		panel.add_child(btn)

	sy += ceil(stats.size() / 2.0) * 47.0

	# 底部信息
	sy += 10.0
	var footer: Label = Label.new()
	footer.text = "💰 " + str(player_gold) + "金币  |  ♻️ " + str(player_revive) + "/" + str(player_max_revive) + "复活币  |  位置 " + str(player_grid_index) + "/" + str(map_total_grids)
	footer.add_theme_font_size_override("font_size", 12)
	footer.add_theme_color_override("font_color", Color(0.5, 0.55, 0.6))
	footer.position = Vector2(20, sy)
	panel.add_child(footer)

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
	UIUtils.panel_style(tip, Color(0.05, 0.06, 0.12, 0.95))

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
