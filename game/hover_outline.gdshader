shader_type canvas_item;

uniform float enabled = 0.0;
uniform vec4 region_uv = vec4(0.0, 0.0, 1.0, 1.0);
uniform float width = 1.0;

void vertex() {
	vec2 region_min = region_uv.xy;
	vec2 region_max = region_uv.zw;
	vec2 region_center = (region_min + region_max) * 0.5;
	vec2 region_half = max((region_max - region_min) * 0.5, vec2(0.00001));
	vec2 corner = (UV - region_center) / region_half;
	VERTEX += corner * width * step(0.5, enabled);
}

float _inside(vec2 uv, vec2 region_min, vec2 region_max) {
	return step(region_min.x, uv.x) * step(uv.x, region_max.x) * step(region_min.y, uv.y) * step(uv.y, region_max.y);
}

void fragment() {
	if (enabled < 0.5) {
		COLOR = texture(TEXTURE, UV);
	} else {
		vec2 region_min = region_uv.xy;
		vec2 region_max = region_uv.zw;
		vec2 region_size = max(region_max - region_min, vec2(0.00001));
		vec2 px = TEXTURE_PIXEL_SIZE * width;
		vec2 uv_in_region = (UV - region_min) / region_size;
		vec2 tex_uv = region_min + uv_in_region * (region_size + px * 2.0) - px;
		float base_alpha = _inside(tex_uv, region_min, region_max) * texture(TEXTURE, clamp(tex_uv, region_min, region_max)).a;
		vec2 right_uv = tex_uv + vec2(px.x, 0.0);
		vec2 left_uv = tex_uv - vec2(px.x, 0.0);
		vec2 down_uv = tex_uv + vec2(0.0, px.y);
		vec2 up_uv = tex_uv - vec2(0.0, px.y);
		float neighbor = max(
			max(
				_inside(right_uv, region_min, region_max) * texture(TEXTURE, clamp(right_uv, region_min, region_max)).a,
				_inside(left_uv, region_min, region_max) * texture(TEXTURE, clamp(left_uv, region_min, region_max)).a
			),
			max(
				_inside(down_uv, region_min, region_max) * texture(TEXTURE, clamp(down_uv, region_min, region_max)).a,
				_inside(up_uv, region_min, region_max) * texture(TEXTURE, clamp(up_uv, region_min, region_max)).a
			)
		);
		vec4 base = texture(TEXTURE, clamp(tex_uv, region_min, region_max));
		base.a = base_alpha;
		COLOR = mix(vec4(1.0, 1.0, 1.0, neighbor), base, base.a);
	}
}
