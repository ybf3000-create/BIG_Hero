class_name GridTile
extends Control
## 圆角矩形地图格子 — 底边平行界面，左右相接

var fill_color: Color = Color.GRAY
var border_color: Color = Color(0.5, 0.5, 0.6, 0.7)
var icon_text: String = ""
var name_text: String = ""

var _icon_label: Label
var _name_label: Label

const CORNER_R: float = 8.0  # 圆角半径
const BORDER_W: float = 2.0

func _ready() -> void:
	_icon_label = Label.new()
	_icon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_icon_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_icon_label.add_theme_font_size_override("font_size", 28)
	add_child(_icon_label)

	_name_label = Label.new()
	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_name_label.add_theme_font_size_override("font_size", 10)
	add_child(_name_label)

	# 初始占位布局，由 main_game 的 _refresh_grid_display 覆盖
	_resize_labels()


func setup(icon: String, gname: String, fill: Color, border: Color) -> void:
	icon_text = icon
	name_text = gname
	fill_color = fill
	border_color = border
	if _icon_label:
		_icon_label.text = icon
	if _name_label:
		_name_label.text = gname
	queue_redraw()


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	r = r.grow(-BORDER_W)  # 让边框不超出
	draw_rect(r, fill_color)
	draw_rect(r, border_color, false, BORDER_W)


func set_label_positions(_icon_y: float, _name_y: float) -> void:
	_resize_labels()


func _resize_labels() -> void:
	var h := size.y
	if _icon_label:
		_icon_label.position = Vector2(0, h * 0.02)
		_icon_label.size = Vector2(size.x, h * 0.62)
	if _name_label:
		_name_label.position = Vector2(0, h * 0.60)
		_name_label.size = Vector2(size.x, h * 0.38)
