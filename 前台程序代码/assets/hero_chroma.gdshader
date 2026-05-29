shader_type canvas_item;
// 色键透明 —— 让接近 white 的像素变透明
uniform vec4 key_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float tolerance : hint_range(0.0, 1.0) = 0.35;

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	if (distance(c.rgb, key_color.rgb) < tolerance) {
		COLOR.a = 0.0;
	} else {
		COLOR = c;
	}
}
