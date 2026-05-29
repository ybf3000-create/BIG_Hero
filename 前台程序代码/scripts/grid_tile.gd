class_name GridTile
extends Control
## 透视梯形地块 — 底边平行界面，上窄下宽，左右连续相接

var fill_color: Color = Color.GRAY
var border_color: Color = Color(0.5, 0.5, 0.6, 0.7)
var icon_text: String = ""
var name_text: String = ""

var _icon_label: Label
var _name_label: Label

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
	var w := size.x
	var h := size.y
	var top_w := w * 0.58  # 顶部宽度（透视收窄）
	var left_inset := (w - top_w) / 2.0

	var points := PackedVector2Array([
		Vector2(left_inset, 0),              # 左上
		Vector2(left_inset + top_w, 0),      # 右上
		Vector2(w, h),                        # 右下
		Vector2(0, h),                        # 左下
	])

	var border := border_color
	border.a = 0.8
	draw_colored_polygon(points, fill_color)
	draw_polyline(points, border, BORDER_W, true)


func set_label_positions(_icon_y: float, _name_y: float) -> void:
	_resize_labels()


func _resize_labels() -> void:
	var h := size.y
	if _icon_label:
		_icon_label.position = Vector2(0, h * 0.05)
		_icon_label.size = Vector2(size.x, h * 0.55)
	if _name_label:
		_name_label.position = Vector2(0, h * 0.55)
		_name_label.size = Vector2(size.x, h * 0.40)
