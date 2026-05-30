class_name GridTile
extends Control
## 平行四边形地块 — 上下边水平、左右边倾斜，等大连续拼接，2D 立体透视

var fill_color: Color = Color.GRAY
var border_color: Color = Color(0.5, 0.5, 0.6, 0.7)
var icon_text: String = ""
var name_text: String = ""

var _icon_label: Label
var _name_label: Label

const SHEAR: float = 45.0   # 水平偏移量（越大越斜，透视越强）
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
	var w := size.x - SHEAR  # 顶部宽度
	var h := size.y
	var s := SHEAR

	# 平行四边形：顶边水平(0,0)→(w,0)，底边水平(s,h)→(w+s,h)
	var points := PackedVector2Array([
		Vector2(0, 0),          # 左上
		Vector2(w, 0),          # 右上
		Vector2(w + s, h),      # 右下
		Vector2(s, h),          # 左下
	])

	draw_colored_polygon(points, fill_color)
	var border := border_color
	border.a = 0.8
	draw_polyline(points, border, BORDER_W, true)


func set_label_positions(_x: float, _y: float) -> void:
	_resize_labels()


func _resize_labels() -> void:
	var h := size.y
	if _icon_label:
		_icon_label.position = Vector2(10, h * 0.05)
		_icon_label.size = Vector2(size.x - 20, h * 0.55)
	if _name_label:
		_name_label.position = Vector2(10, h * 0.55)
		_name_label.size = Vector2(size.x - 20, h * 0.40)
