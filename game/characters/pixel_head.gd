extends Node2D
class_name PixelHead

## 8×8 像素头。皮肤、头发、眼睛、嘴是分开的精灵，眼睛会自己眨。

const SIZE := 8
const GENDER_COUNT := 2
const HAIR_COUNT := 5
const EYES_COUNT := 4
const SKIN_COUNT := 4

const _BLINK_GAP_MIN := 2.2
const _BLINK_GAP_MAX := 5.0
const _BLINK_HOLD := 0.12

const _SKIN_COLORS: Array[Color] = [
	Color8(238, 195, 154),
	Color8(217, 160, 102),
	Color8(143, 86, 59),
	Color8(102, 57, 49),
]
const _HAIR_COLORS: Array[Color] = [
	Color8(69, 42, 40),
	Color8(138, 111, 48),
	Color8(251, 242, 54),
	Color8(172, 50, 50),
	Color8(63, 63, 116),
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

var gender_id := 0
var hair_id := 0
var eyes_id := 0
var skin_id := 0
var is_blinking := false

var _blink_left := 0.0
var _gap_left := 0.0

var skin: Sprite2D
var mouth: Sprite2D
var hair: Sprite2D
var eyes_open: Sprite2D
var eyes_closed: Sprite2D


static func create(gender_id: int, hair_id: int, eyes_id: int, skin_id: int) -> PixelHead:
	var head := PixelHead.new()
	head.name = "PixelHead"
	head.gender_id = _wrap(gender_id, GENDER_COUNT)
	head.hair_id = _wrap(hair_id, HAIR_COUNT)
	head.eyes_id = _wrap(eyes_id, EYES_COUNT)
	head.skin_id = _wrap(skin_id, SKIN_COUNT)
	head._mount_parts()
	head._paint()
	head._sync_eyes()
	return head


func apply(next_gender_id: int, next_hair_id: int, next_eyes_id: int, next_skin_id: int) -> void:
	gender_id = _wrap(next_gender_id, GENDER_COUNT)
	hair_id = _wrap(next_hair_id, HAIR_COUNT)
	eyes_id = _wrap(next_eyes_id, EYES_COUNT)
	skin_id = _wrap(next_skin_id, SKIN_COUNT)
	_paint()


func blink() -> void:
	is_blinking = true
	_blink_left = _BLINK_HOLD
	_sync_eyes()


func _ready() -> void:
	_gap_left = randf_range(_BLINK_GAP_MIN, _BLINK_GAP_MAX)
	_sync_eyes()


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


func _mount_parts() -> void:
	skin = _add_part("Skin")
	mouth = _add_part("Mouth")
	hair = _add_part("Hair")
	eyes_open = _add_part("EyesOpen")
	eyes_closed = _add_part("EyesClosed")
	eyes_closed.visible = false


func _add_part(part_name: String) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.name = part_name
	add_child(sprite)
	return sprite


func _paint() -> void:
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
