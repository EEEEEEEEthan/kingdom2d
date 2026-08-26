shader_type canvas_item;
render_mode unshaded, blend_mix;

// 将画面 RGB 吸附到色板贴图最近色，原样保留 alpha。
// 色板任意宽高；行优先遍历全部纹素。透明纹素跳过。
// 编译期循环上限 256，超出部分忽略。
// 挂在 SubViewportContainer 上采样 TEXTURE，避免 screen texture 丢 alpha。
uniform sampler2D palette : filter_nearest, repeat_disable;

void fragment() {
	vec4 src = texture(TEXTURE, UV);
	if (src.a <= 0.001) {
		COLOR = vec4(0.0);
	}
<<<<<<< HEAD
	else{
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
=======

	ivec2 pal_size = textureSize(palette, 0);
	int n = pal_size.x * pal_size.y;
	vec3 best = vec3(0.0);
	float best_d = 1e20;
	bool found = false;
	vec3 luma_w = vec3(0.3, 0.59, 0.11);
	for (int i = 0; i < 256; i++) {
		if (i >= n) {
			break;
		}
		ivec2 pcoord = ivec2(i % pal_size.x, i / pal_size.x);
		vec4 pal = texelFetch(palette, pcoord, 0);
		if (pal.a <= 0.001) {
			continue;
		}
		vec3 delta = src.rgb - pal.rgb;
		float dist2 = dot(delta * delta, luma_w);
		if (dist2 < best_d) {
			best_d = dist2;
			best = pal.rgb;
			found = true;
>>>>>>> 6f69826 (色板改为任意尺寸贴图参数。)
		}
		COLOR = vec4(best, src.a);
	}
<<<<<<< HEAD
=======
	COLOR = vec4(found ? best : src.rgb, src.a);
>>>>>>> 6f69826 (色板改为任意尺寸贴图参数。)
}
