shader_type canvas_item;
render_mode unshaded, blend_mix;

// 将画面 RGB 吸附到色板最近色，原样保留 alpha（桌宠透明窗口依赖这条通道）。
// 必须挂在 SubViewportContainer 上采样 TEXTURE：hint_screen_texture 的 alpha 恒为 1。
uniform vec4 palette[32] : source_color;
uniform int palette_count : hint_range(1, 32) = 16;

void fragment() {
	vec4 src = texture(TEXTURE, UV);
	if (src.a <= 0.001) {
		COLOR = vec4(0.0);
		return;
	}

	int count = clamp(palette_count, 1, 32);
	vec3 best = palette[0].rgb;
	float best_d = 1e20;
	vec3 luma_w = vec3(0.3, 0.59, 0.11);
	for (int i = 0; i < 32; i++) {
		if (i >= count) {
			break;
		}
		vec3 delta = src.rgb - palette[i].rgb;
		float dist2 = dot(delta * delta, luma_w);
		if (dist2 < best_d) {
			best_d = dist2;
			best = palette[i].rgb;
		}
	}
	COLOR = vec4(best, src.a);
}
