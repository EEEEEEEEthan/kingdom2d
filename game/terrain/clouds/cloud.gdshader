shader_type canvas_item;

uniform float fps = 3.0;
uniform vec2 frame_count = vec2(4.0, 8.0);
uniform vec2 speed_range = vec2(0.6, 1.4);

varying flat vec4 anim_params;

void vertex() {
	anim_params = COLOR;
	COLOR = vec4(1.0);
}

void fragment() {
	vec2 frame_size = vec2(1.0) / frame_count;
	int row = int(floor(anim_params.r * (frame_count.y - 0.001)));
	float start_frame = anim_params.g * frame_count.x;
	float speed_factor = mix(speed_range.x, speed_range.y, anim_params.b);
	float frame_index = mod(
		floor(TIME * fps * speed_factor) + start_frame,
		frame_count.x
	);
	int column = int(frame_index);
	vec2 local_uv = vec2(UV.x, 1.0 - UV.y);
	vec2 sheet_uv = local_uv * frame_size + vec2(float(column), float(row)) * frame_size;
	vec4 tex = texture(TEXTURE, sheet_uv);
	COLOR = tex * vec4(1.0, 1.0, 1.0, anim_params.a);
}
