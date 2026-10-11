@tool
extends Control
class_name PixelHead

## 14×14 开罗风头像。部位是画好的彩色图，直接叠上去。眼睛会自己眨。

const SIZE := 14
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
const CLOTHES_PALETTE: PixelHeadPalette = preload("res://addons/pixel_head/palettes/clothes.tres")
const OUTLINE_PALETTE: PixelHeadPalette = preload("res://addons/pixel_head/palettes/outline.tres")

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
const _SHIRTS: Array[Texture2D] = [
	preload("res://addons/pixel_head/masks/shirt_0.png"),
	preload("res://addons/pixel_head/masks/shirt_1.png"),
]
const _REF_SKIN: Texture2D = preload("res://addons/pixel_head/masks/ref_skin.png")
const _REF_SKIN_LIGHT: Texture2D = preload("res://addons/pixel_head/masks/ref_skin_light.png")
const _REF_BLUSH: Texture2D = preload("res://addons/pixel_head/masks/ref_blush.png")
const _REF_MOUTH: Texture2D = preload("res://addons/pixel_head/masks/ref_mouth.png")
const _REF_MOUTH_DARK: Texture2D = preload("res://addons/pixel_head/masks/ref_mouth_dark.png")
const _REF_HAIR_MID: Texture2D = preload("res://addons/pixel_head/masks/ref_hair_mid.png")
const _REF_HAIR_MID2: Texture2D = preload("res://addons/pixel_head/masks/ref_hair_mid2.png")
const _REF_HAIR_LIGHT: Texture2D = preload("res://addons/pixel_head/masks/ref_hair_light.png")
const _REF_HAIR_LIGHTER: Texture2D = preload("res://addons/pixel_head/masks/ref_hair_lighter.png")
const _REF_HAIR_DARK: Texture2D = preload("res://addons/pixel_head/masks/ref_hair_dark.png")
const _REF_FLOWER: Texture2D = preload("res://addons/pixel_head/masks/ref_flower.png")
const _REF_FLOWER_WARM: Texture2D = preload("res://addons/pixel_head/masks/ref_flower_warm.png")
const _REF_FLOWER_HOT: Texture2D = preload("res://addons/pixel_head/masks/ref_flower_hot.png")
const _REF_EYE_DARK: Texture2D = preload("res://addons/pixel_head/masks/ref_eye_dark.png")
const _REF_IRIS: Texture2D = preload("res://addons/pixel_head/masks/ref_iris.png")
const _REF_PUPIL: Texture2D = preload("res://addons/pixel_head/masks/ref_pupil.png")
const _REF_EYE_HI: Texture2D = preload("res://addons/pixel_head/masks/ref_eye_hi.png")
const _REF_OUTLINE: Texture2D = preload("res://addons/pixel_head/masks/ref_outline.png")
const _REFERENCE: Texture2D = preload("res://addons/pixel_head/reference.png")
const _MALE_REFERENCE: Texture2D = preload("res://addons/pixel_head/male_reference.png")
const _MALE_REFERENCE_B: Texture2D = preload("res://addons/pixel_head/male_reference_b.png")
const _FEMALE_REFERENCE_B: Texture2D = preload("res://addons/pixel_head/female_reference_b.png")
const _FEMALE_B: Texture2D = preload("res://addons/pixel_head/parts/female_1.png")
const _FEMALE_SKIN: Texture2D = preload("res://addons/pixel_head/parts/female_skin.png")
const _FEMALE_SKIN_LIGHT: Texture2D = preload("res://addons/pixel_head/parts/female_skin_light.png")
const _FEMALE_BLUSH: Texture2D = preload("res://addons/pixel_head/parts/female_blush.png")
const _FEMALE_MOUTH: Texture2D = preload("res://addons/pixel_head/parts/female_mouth.png")
const _FEMALE_MOUTH_DARK: Texture2D = preload("res://addons/pixel_head/parts/female_mouth_dark.png")
const _FEMALE_HAIR_MID: Texture2D = preload("res://addons/pixel_head/parts/female_hair_mid.png")
const _FEMALE_HAIR_MID2: Texture2D = preload("res://addons/pixel_head/parts/female_hair_mid2.png")
const _FEMALE_HAIR_LIGHT: Texture2D = preload("res://addons/pixel_head/parts/female_hair_light.png")
const _FEMALE_HAIR_LIGHTER: Texture2D = preload("res://addons/pixel_head/parts/female_hair_lighter.png")
const _FEMALE_HAIR_DARK: Texture2D = preload("res://addons/pixel_head/parts/female_hair_dark.png")
const _FEMALE_FLOWER: Texture2D = preload("res://addons/pixel_head/parts/female_flower.png")
const _FEMALE_FLOWER_WARM: Texture2D = preload("res://addons/pixel_head/parts/female_flower_warm.png")
const _FEMALE_FLOWER_HOT: Texture2D = preload("res://addons/pixel_head/parts/female_flower_hot.png")
const _FEMALE_EYE_DARK: Texture2D = preload("res://addons/pixel_head/parts/female_eye_dark.png")
const _FEMALE_IRIS: Texture2D = preload("res://addons/pixel_head/parts/female_iris.png")
const _FEMALE_PUPIL: Texture2D = preload("res://addons/pixel_head/parts/female_pupil.png")
const _FEMALE_EYE_HI: Texture2D = preload("res://addons/pixel_head/parts/female_eye_hi.png")
const _FEMALE_OUTLINE: Texture2D = preload("res://addons/pixel_head/parts/female_outline.png")
const _MALES: Array[Texture2D] = [
	preload("res://addons/pixel_head/parts/male_0.png"),
	preload("res://addons/pixel_head/parts/male_1.png"),
	preload("res://addons/pixel_head/parts/male_2.png"),
	preload("res://addons/pixel_head/parts/male_3.png"),
	preload("res://addons/pixel_head/parts/male_4.png"),
]

const _OUTLINES: Array[Texture2D] = [
	preload("res://addons/pixel_head/masks/outline_0_0.png"),
	preload("res://addons/pixel_head/masks/outline_0_1.png"),
	preload("res://addons/pixel_head/masks/outline_0_2.png"),
	preload("res://addons/pixel_head/masks/outline_0_3.png"),
	preload("res://addons/pixel_head/masks/outline_0_4.png"),
	preload("res://addons/pixel_head/masks/outline_1_0.png"),
	preload("res://addons/pixel_head/masks/outline_1_1.png"),
	preload("res://addons/pixel_head/masks/outline_1_2.png"),
	preload("res://addons/pixel_head/masks/outline_1_3.png"),
	preload("res://addons/pixel_head/masks/outline_1_4.png"),
]

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
@export var clothes_color_idx := 0:
	set(value):
		clothes_color_idx = _wrap(value, CLOTHES_PALETTE.color_count())
		queue_redraw()
@export var outline_color_idx := 0:
	set(value):
		outline_color_idx = _wrap(value, OUTLINE_PALETTE.color_count())
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
	next_clothes_color_idx: int = 0,
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
	head.clothes_color_idx = next_clothes_color_idx
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


func build_image() -> Image:
	var image := Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	if gender_id == 0 and hair_id == 1:
		_blit_part(image, _FEMALE_B)
	elif gender_id == 0:
		for part in [
			_FEMALE_SKIN, _FEMALE_SKIN_LIGHT, _FEMALE_BLUSH, _FEMALE_MOUTH, _FEMALE_MOUTH_DARK,
			_FEMALE_HAIR_MID, _FEMALE_HAIR_MID2, _FEMALE_HAIR_LIGHT, _FEMALE_HAIR_LIGHTER, _FEMALE_HAIR_DARK,
			_FEMALE_FLOWER, _FEMALE_FLOWER_WARM, _FEMALE_FLOWER_HOT,
		]:
			_blit_part(image, part)
		if is_blinking:
			_blit_part(image, _FEMALE_PUPIL)
		else:
			_blit_part(image, _FEMALE_EYE_DARK)
			_blit_part(image, _FEMALE_IRIS)
			_blit_part(image, _FEMALE_PUPIL)
			_blit_part(image, _FEMALE_EYE_HI)
		_blit_part(image, _FEMALE_OUTLINE)
	else:
		_blit_part(image, _MALES[hair_id])
		if is_blinking:
			_blit_part(image, _FEMALE_PUPIL)
	return image


func _draw() -> void:
	draw_texture(ImageTexture.create_from_image(build_image()), Vector2.ZERO)


func _blit_part(image: Image, part: Texture2D) -> void:
	var src := part.get_image()
	for y in src.get_height():
		for x in src.get_width():
			var pixel := src.get_pixel(x, y)
			if pixel.a <= 0.0:
				continue
			image.set_pixel(x, y, pixel)


func _draw_mask(mask: Texture2D, color: Color) -> void:
	draw_texture(mask, Vector2.ZERO, color)


static func _wrap(value: int, count: int) -> int:
	return posmod(value, count)
