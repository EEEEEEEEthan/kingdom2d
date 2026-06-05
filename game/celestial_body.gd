extends Sprite2D

const _SUNRISE_FRACTION := 0.25
const _SUNSET_FRACTION := 0.75
const _NIGHT_DURATION := 1.0 - (_SUNSET_FRACTION - _SUNRISE_FRACTION)
const _SKY_Y_APEX := 7.0
const _SKY_Y_HORIZON := 52.0
const _SKY_X_SPAN_RATIO := 0.72
const _MOON_FRAME_COUNT := 8

const _SUN_TEXTURE := preload("res://game/celestial/sun.png")
const _MOON_SPRITESHEET := preload("res://game/celestial/moon_spritesheet.png")

var _game: Game:
	get:
		return owner as Game


func _ready() -> void:
	top_level = true
	light_mask = 0
	centered = true
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_update_visual()


func _process(_delta: float) -> void:
	_update_visual()


func _update_visual() -> void:
	var day_fraction := _game.game_time.day_fraction
	var sun_height := _sun_height_from_day_fraction(day_fraction)
	if sun_height > 0.0:
		visible = true
		hframes = 1
		vframes = 1
		frame = 0
		texture = _SUN_TEXTURE
		_apply_screen_arc_position(_sun_arc_fraction(day_fraction), sun_height)
		return
	visible = true
	texture = _MOON_SPRITESHEET
	hframes = _MOON_FRAME_COUNT
	vframes = 1
	frame = _game.game_time.moon_phase
	_apply_screen_arc_position(_moon_arc_fraction(day_fraction), _moon_height_from_day_fraction(day_fraction))


func _sun_arc_fraction(day_fraction: float) -> float:
	return _sun_phase(day_fraction) / PI


func _moon_arc_fraction(day_fraction: float) -> float:
	return _night_fraction(day_fraction)


func _sun_phase(day_fraction: float) -> float:
	return (day_fraction - _SUNRISE_FRACTION) / (_SUNSET_FRACTION - _SUNRISE_FRACTION) * PI


func _night_fraction(day_fraction: float) -> float:
	return fmod(day_fraction - _SUNSET_FRACTION + 1.0, 1.0) / _NIGHT_DURATION


func _sun_height_from_day_fraction(day_fraction: float) -> float:
	var sun_phase := _sun_phase(day_fraction)
	if sun_phase <= 0.0 or sun_phase >= PI:
		return 0.0
	return sin(sun_phase)


func _moon_height_from_day_fraction(day_fraction: float) -> float:
	return sin(_night_fraction(day_fraction) * PI)


func _apply_screen_arc_position(arc_fraction: float, height: float) -> void:
	var viewport := get_viewport()
	var half_viewport_width := viewport.get_visible_rect().size.x * 0.5
	var offset_x := (0.5 - arc_fraction) * half_viewport_width * 2.0 * _SKY_X_SPAN_RATIO
	var screen_position := Vector2(
		half_viewport_width + offset_x,
		lerpf(_SKY_Y_HORIZON, _SKY_Y_APEX, height),
	)
	global_position = viewport.get_canvas_transform().affine_inverse() * screen_position
