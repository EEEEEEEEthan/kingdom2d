@tool
extends Node2D
class_name PixelHead

## 8×8 像素头场景。改 gender_id、hair_id、eyes_id、skin_id 即可。眼睛会自己眨。

const SIZE := 8
const GENDER_COUNT := 2
const HAIR_COUNT := 5
const EYES_COUNT := 4
const SKIN_COUNT := 4

const _BLINK_GAP_MIN := 2.2
const _BLINK_GAP_MAX := 5.0
const _BLINK_HOLD := 0.12

const _SKIN_COLORS: Array[Color] = [
	Color8(255, 224, 206),
	Color8(238, 195, 154),
	Color8(217, 160, 102),
	Color8(196, 140, 100),
]
const _HAIR_COLORS: Array[Color] = [
	Color8(69, 42, 40),
	Color8(138, 111, 48),
	Color8(251, 242, 54),
	Color8(172, 50, 50),
	Color8(40, 28, 22),
]
const _EYE_COLORS: Array[Color] = [
	Color8(34, 32, 52),
	Color8(48, 96, 130),
	Color8(75, 105, 47),
	Color8(118, 66, 138),
]
const _LINE := Color8(34, 32, 52)
const _MOUTH := Color8(172, 50, 50)
const _BLUSH := Color8(217, 87, 99)

@export_range(0, GENDER_COUNT - 1) var gender_id := 0:
	set(value):
		gender_id = _wrap(value, GENDER_COUNT)
		_paint()
@export_range(0, HAIR_COUNT - 1) var hair_id := 0:
	set(value):
		hair_id = _wrap(value, HAIR_COUNT)
		_paint()
@export_range(0, EYES_COUNT - 1) var eyes_id := 0:
	set(value):
		eyes_id = _wrap(value, EYES_COUNT)
		_paint()
@export_range(0, SKIN_COUNT - 1) var skin_id := 0:
	set(value):
		skin_id = _wrap(value, SKIN_COUNT)
		_paint()

var is_blinking := false

var _blink_left := 0.0
var _gap_left := 0.0

var skin: Sprite2D
var mouth: Sprite2D
var hair: Sprite2D
var eyes_open: Sprite2D
var eyes_closed: Sprite2D


static func create(next_gender_id: int, next_hair_id: int, next_eyes_id: int, next_skin_id: int) -> PixelHead:
	var head := (load("res://game/characters/pixel_head.tscn") as PackedScene).instantiate() as PixelHead
	head.gender_id = next_gender_id
	head.hair_id = next_hair_id
	head.eyes_id = next_eyes_id
	head.skin_id = next_skin_id
	return head


func apply(next_gender_id: int, next_hair_id: int, next_eyes_id: int, next_skin_id: int) -> void:
	gender_id = next_gender_id
	hair_id = next_hair_id
	eyes_id = next_eyes_id
	skin_id = next_skin_id


func blink() -> void:
	is_blinking = true
	_blink_left = _BLINK_HOLD
	_sync_eyes()


func _ready() -> void:
	_paint()
	_sync_eyes()
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
			_sync_eyes()
		return
	_gap_left -= delta
	if _gap_left <= 0.0:
		blink()


func _paint() -> void:
	if get_node_or_null("Skin") == null:
		return
	skin = $Skin
	mouth = $Mouth
	hair = $Hair
	eyes_open = $EyesOpen
	eyes_closed = $EyesClosed
	var skin_color := _SKIN_COLORS[skin_id]
	var hair_color := _HAIR_COLORS[hair_id]
	var eye_color := _EYE_COLORS[eyes_id]
	skin.texture = _texture(_skin_rows(), {"s": skin_color, "b": _BLUSH})
	mouth.texture = _texture(_mouth_rows(), {"m": _MOUTH})
	hair.texture = _texture(_hair_rows(), {"h": hair_color})
	eyes_open.texture = _texture(_eyes_open_rows(), {"w": Color.WHITE, "p": eye_color})
	eyes_closed.texture = _texture(_eyes_closed_rows(), {"c": _LINE})


func _sync_eyes() -> void:
	eyes_open.visible = not is_blinking
	eyes_closed.visible = is_blinking


func _skin_rows() -> PackedStringArray:
	# 男的下颌更方，女的下巴收一点。
	if gender_id == 1:
		return PackedStringArray([
			"..ssss..",
			".ssssss.",
			"ssssssss",
			"ssssssss",
			"ssbssbss",
			"ssssssss",
			"ssssssss",
			".ssssss.",
		])
	return PackedStringArray([
		"..ssss..",
		".ssssss.",
		"ssssssss",
		"ssssssss",
		"ssbssbss",
		"ssssssss",
		".ssssss.",
		"..ssss..",
	])


func _mouth_rows() -> PackedStringArray:
	if gender_id == 1:
		return PackedStringArray([
			"........",
			"........",
			"........",
			"........",
			"........",
			"........",
			"..mmmm..",
			"........",
		])
	return PackedStringArray([
		"........",
		"........",
		"........",
		"........",
		"........",
		"........",
		"...mm...",
		"........",
	])


func _hair_rows() -> PackedStringArray:
	match hair_id:
		0:
			return PackedStringArray([
				".hhhhhh.",
				"hhhhhhhh",
				"hh....hh",
				"........",
				"........",
				"........",
				"........",
				"........",
			])
		1:
			return PackedStringArray([
				".hhhhhh.",
				"hhhhhhhh",
				"hh....hh",
				"h......h",
				"h......h",
				"........",
				"........",
				"........",
			])
		2:
			return PackedStringArray([
				".hhhhhh.",
				"hhhhhhhh",
				"hh....hh",
				"h......h",
				"h......h",
				"h......h",
				"h......h",
				"........",
			])
		3:
			return PackedStringArray([
				"h..hh..h",
				".hhhhhh.",
				"hh....hh",
				"........",
				"........",
				"........",
				"........",
				"........",
			])
		_:
			return PackedStringArray([
				"..hhhh..",
				"hhhhhhhh",
				"hh....hh",
				"........",
				"........",
				"........",
				"........",
				"........",
			])


func _eyes_open_rows() -> PackedStringArray:
	match eyes_id:
		0:
			return PackedStringArray([
				"........",
				"........",
				"........",
				"..p..p..",
				"........",
				"........",
				"........",
				"........",
			])
		1:
			return PackedStringArray([
				"........",
				"........",
				".ww..ww.",
				".wp..pw.",
				"........",
				"........",
				"........",
				"........",
			])
		2:
			return PackedStringArray([
				"........",
				"........",
				"........",
				".wp..pw.",
				"........",
				"........",
				"........",
				"........",
			])
		_:
			return PackedStringArray([
				"........",
				"........",
				"wp....pw",
				".p....p.",
				"........",
				"........",
				"........",
				"........",
			])


func _eyes_closed_rows() -> PackedStringArray:
	return PackedStringArray([
		"........",
		"........",
		"........",
		".cc..cc.",
		"........",
		"........",
		"........",
		"........",
	])


func _texture(rows: PackedStringArray, inks: Dictionary) -> ImageTexture:
	var image := Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	for y in SIZE:
		var row := rows[y]
		for x in SIZE:
			var mark := row[x]
			if mark == ".":
				continue
			image.set_pixel(x, y, inks[mark])
	return ImageTexture.create_from_image(image)


static func _wrap(value: int, count: int) -> int:
	return posmod(value, count)
