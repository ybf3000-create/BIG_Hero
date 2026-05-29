class_name GridTile
extends Control
## 斜45度菱形地图格子

var fill_color: Color = Color.GRAY
var border_color: Color = Color(0.5, 0.5, 0.6, 0.7)
var icon_text: String = ""
var name_text: String = ""

var _icon_label: Label
var _name_label: Label

func _ready() -> void:
	_icon_label = Label.new()
	_icon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_icon_label.add_theme_font_size_override("font_size", 24)
	add_child(_icon_label)

	_name_label = Label.new()
	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name_label.add_theme_font_size_override("font_size", 8)
	add_child(_name_label)


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
	var points := PackedVector2Array([
		Vector2(w / 2.0, 0),
		Vector2(w, h / 2.0),
		Vector2(w / 2.0, h),
		Vector2(0, h / 2.0),
	])
	draw_colored_polygon(points, fill_color)
	draw_polyline(points, border_color, 2.0)


func set_label_positions(icon_y: float, name_y: float) -> void:
	if _icon_label:
		_icon_label.position = Vector2(0, icon_y)
		_icon_label.size = Vector2(size.x, 30)
	if _name_label:
		_name_label.position = Vector2(0, name_y)
		_name_label.size = Vector2(size.x, 14)
