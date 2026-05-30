class_name GridTile
extends Control
## 平行四边形地块 — 上边靠右（透视方向），等大连续拼接，2D 立体透视
## 图标+名称在平行四边形下方横排

var fill_color: Color = Color.GRAY
var border_color: Color = Color(0.5, 0.5, 0.6, 0.7)
var icon_text: String = ""
var name_text: String = ""

var _icon_label: Label
var _name_label: Label

const SHEAR: float = 45.0       # 水平偏移
const BORDER_W: float = 2.0
const LABEL_H: float = 20.0     # 标签行高度


func _ready() -> void:
	_icon_label = Label.new()
	_icon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_icon_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_icon_label.add_theme_font_size_override("font_size", 16)
	add_child(_icon_label)

	_name_label = Label.new()
	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_name_label.add_theme_font_size_override("font_size", 10)
	_name_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.75))
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
	var para_h := size.y - LABEL_H  # 平行四边形高度
	var w := size.x - SHEAR         # 上下边水平宽度
	var s := SHEAR

	# 上边靠右：(s,0)→(w+s,0)，下边靠左：(0,para_h)→(w,para_h)
	var points := PackedVector2Array([
		Vector2(s, 0),              # 左上
		Vector2(w + s, 0),          # 右上
		Vector2(w, para_h),         # 右下
		Vector2(0, para_h),         # 左下
	])

	draw_colored_polygon(points, fill_color)
	var border := border_color
	border.a = 0.8
	draw_polyline(points, border, BORDER_W, true)


func set_label_positions(_x: float, _y: float) -> void:
	_resize_labels()


func _resize_labels() -> void:
	var para_h := size.y - LABEL_H
	if _icon_label:
		_icon_label.position = Vector2(SHEAR + 4, para_h)
		_icon_label.size = Vector2(22, LABEL_H)
	if _name_label:
		_name_label.position = Vector2(SHEAR + 28, para_h)
		_name_label.size = Vector2(size.x - SHEAR - 30, LABEL_H)
