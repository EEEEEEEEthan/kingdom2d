shader_type canvas_item;

void fragment() {
	vec4 texel = texture(TEXTURE, UV);
	COLOR = vec4(1.0, 1.0, 1.0, texel.a);
}
