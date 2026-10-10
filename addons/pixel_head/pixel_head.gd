@tool
extends Control
class_name PixelHead

## 可直接添加的 8×8 像素头。形状是纯白遮罩，颜色填色板下标。眼睛会自己眨。

const SIZE := 8
const GENDER_COUNT := 2
const HAIR_COUNT := 5
const EYES_COUNT := 4
const SKIN_PALETTE: PixelHeadPalette = preload("res://addons/pixel_head/palettes/skin.tres")
const HAIR_PALETTE: PixelHeadPalette = preload("res://addons/pixel_head/palettes/hair.tres")
const EYES_PALETTE: PixelHeadPalette = preload("res://addons/pixel_head/palettes/eyes.tres")
const MOUTH_PALETTE: PixelHeadPalette = preload("res://addons/pixel_head/palettes/mouth.tres")
const BLUSH_PALETTE: PixelHeadPalette = preload("res://addons/pixel_head/palettes/blush.tres")
const EYE_WHITE_PALETTE: PixelHeadPalette = preload("res://addons/pixel_head/palettes/eye_white.tres")
const EYES_CLOSED_PALETTE: PixelHeadPalette = preload("res://addons/pixel_head/palettes/eyes_closed.tres")

const _BLINK_GAP_MIN := 2.2
const _BLINK_GAP_MAX := 5.0
const _BLINK_HOLD := 0.12

const _FACES: Array[Texture2D] = [
	preload("res://addons/pixel_head/masks/face_0.png"),
	preload("res://addons/pixel_head/masks/face_1.png"),
]
const _BLUSHES: Array[Texture2D] = [
	preload("res://addons/pixel_head/masks/blush_0.png"),
	preload("res://addons/pixel_head/masks/blush_1.png"),
]
const _MOUTHS: Array[Texture2D] = [
	preload("res://addons/pixel_head/masks/mouth_0.png"),
	preload("res://addons/pixel_head/masks/mouth_1.png"),
]
const _HAIRS: Array[Texture2D] = [
	preload("res://addons/pixel_head/masks/hair_0.png"),
	preload("res://addons/pixel_head/masks/hair_1.png"),
	preload("res://addons/pixel_head/masks/hair_2.png"),
	preload("res://addons/pixel_head/masks/hair_3.png"),
	preload("res://addons/pixel_head/masks/hair_4.png"),
]
const _EYE_WHITES: Array[Texture2D] = [
	preload("res://addons/pixel_head/masks/eyes_white_0.png"),
	preload("res://addons/pixel_head/masks/eyes_white_1.png"),
	preload("res://addons/pixel_head/masks/eyes_white_2.png"),
	preload("res://addons/pixel_head/masks/eyes_white_3.png"),
]
const _EYE_PUPILS: Array[Texture2D] = [
	preload("res://addons/pixel_head/masks/eyes_pupil_0.png"),
	preload("res://addons/pixel_head/masks/eyes_pupil_1.png"),
	preload("res://addons/pixel_head/masks/eyes_pupil_2.png"),
	preload("res://addons/pixel_head/masks/eyes_pupil_3.png"),
]
const _EYES_CLOSED: Texture2D = preload("res://addons/pixel_head/masks/eyes_closed.png")

@export_range(0, GENDER_COUNT - 1) var gender_id := 0:
	set(value):
		gender_id = _wrap(value, GENDER_COUNT)
		queue_redraw()
@export_range(0, HAIR_COUNT - 1) var hair_id := 0:
	set(value):
		hair_id = _wrap(value, HAIR_COUNT)
		queue_redraw()
@export_range(0, EYES_COUNT - 1) var eyes_id := 0:
	set(value):
		eyes_id = _wrap(value, EYES_COUNT)
		queue_redraw()
@export var hair_color_idx := 0:
	set(value):
		hair_color_idx = _wrap(value, HAIR_PALETTE.color_count())
		queue_redraw()
@export var eye_color_idx := 0:
	set(value):
		eye_color_idx = _wrap(value, EYES_PALETTE.color_count())
		queue_redraw()
@export var skin_color_idx := 0:
	set(value):
		skin_color_idx = _wrap(value, SKIN_PALETTE.color_count())
		queue_redraw()
@export var mouth_color_idx := 0:
	set(value):
		mouth_color_idx = _wrap(value, MOUTH_PALETTE.color_count())
		queue_redraw()
@export var blush_color_idx := 0:
	set(value):
		blush_color_idx = _wrap(value, BLUSH_PALETTE.color_count())
		queue_redraw()
@export var eye_white_color_idx := 0:
	set(value):
		eye_white_color_idx = _wrap(value, EYE_WHITE_PALETTE.color_count())
		queue_redraw()
@export var eyes_closed_color_idx := 0:
	set(value):
		eyes_closed_color_idx = _wrap(value, EYES_CLOSED_PALETTE.color_count())
		queue_redraw()

var is_blinking := false

var _blink_left := 0.0
var _gap_left := 0.0


static func create(
	next_gender_id: int,
	next_hair_id: int,
	next_hair_color_idx: int,
	next_eyes_id: int,
	next_eye_color_idx: int,
	next_skin_color_idx: int,
) -> PixelHead:
	var head := PixelHead.new()
	head.mouse_filter = MOUSE_FILTER_IGNORE
	head.custom_minimum_size = Vector2(SIZE, SIZE)
	head.size = Vector2(SIZE, SIZE)
	head.gender_id = next_gender_id
	head.hair_id = next_hair_id
	head.hair_color_idx = next_hair_color_idx
	head.eyes_id = next_eyes_id
	head.eye_color_idx = next_eye_color_idx
	head.skin_color_idx = next_skin_color_idx
	return head


func apply(
	next_gender_id: int,
	next_hair_id: int,
	next_hair_color_idx: int,
	next_eyes_id: int,
	next_eye_color_idx: int,
	next_skin_color_idx: int,
) -> void:
	gender_id = next_gender_id
	hair_id = next_hair_id
	hair_color_idx = next_hair_color_idx
	eyes_id = next_eyes_id
	eye_color_idx = next_eye_color_idx
	skin_color_idx = next_skin_color_idx


func blink() -> void:
	is_blinking = true
	_blink_left = _BLINK_HOLD
	queue_redraw()


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(SIZE, SIZE)
	if size.x < 1.0 or size.y < 1.0:
		size = Vector2(SIZE, SIZE)
	if Engine.is_editor_hint():
		set_process(false)
		return
	_gap_left = randf_range(_BLINK_GAP_MIN, _BLINK_GAP_MAX)


func _process(delta: float) -> void:
	if is_blinking:
		_blink_left -= delta
		if _blink_left <= 0.0:
			is_blinking = false
			_gap_left = randf_range(_BLINK_GAP_MIN, _BLINK_GAP_MAX)
			queue_redraw()
		return
	_gap_left -= delta
	if _gap_left <= 0.0:
		blink()


func _draw() -> void:
	var face := gender_id
	_draw_mask(_FACES[face], SKIN_PALETTE.color_at(skin_color_idx))
	_draw_mask(_BLUSHES[face], BLUSH_PALETTE.color_at(blush_color_idx))
	_draw_mask(_MOUTHS[face], MOUTH_PALETTE.color_at(mouth_color_idx))
	_draw_mask(_HAIRS[hair_id], HAIR_PALETTE.color_at(hair_color_idx))
	if is_blinking:
		_draw_mask(_EYES_CLOSED, EYES_CLOSED_PALETTE.color_at(eyes_closed_color_idx))
		return
	_draw_mask(_EYE_WHITES[eyes_id], EYE_WHITE_PALETTE.color_at(eye_white_color_idx))
	_draw_mask(_EYE_PUPILS[eyes_id], EYES_PALETTE.color_at(eye_color_idx))


func _draw_mask(mask: Texture2D, color: Color) -> void:
	draw_texture(mask, Vector2.ZERO, color)


static func _wrap(value: int, count: int) -> int:
	return posmod(value, count)
