@tool
extends Control
class_name PixelAvatar

## 脸、头发、眼睛、胡子、嘴、身体叠在同一张 atlas 上。
## 每格固定 16×16。列数是贴图宽度除以 16 的整数，下标超出后取模。
## 六个部位在检查器里用滑条调。

const CELL := 16
const PART_COUNT := 6
const PART_NAMES: PackedStringArray = ["脸", "头发", "眼睛", "胡子", "嘴", "身体"]
const _DRAW_ORDER: Array[int] = [5, 0, 1, 2, 3, 4]

@export var atlas: Texture2D = preload("res://addons/pixel_avatar/atlas.png"):
	set(value):
		atlas = value
		_refresh()
		notify_property_list_changed()

@export var 脸 := 0:
	set(value):
		脸 = _wrap(value)
		queue_redraw()
@export var 头发 := 0:
	set(value):
		头发 = _wrap(value)
		queue_redraw()
@export var 眼睛 := 0:
	set(value):
		眼睛 = _wrap(value)
		queue_redraw()
@export var 胡子 := 0:
	set(value):
		胡子 = _wrap(value)
		queue_redraw()
@export var 嘴 := 0:
	set(value):
		嘴 = _wrap(value)
		queue_redraw()
@export var 身体 := 0:
	set(value):
		身体 = _wrap(value)
		queue_redraw()


func variant_count() -> int:
	if atlas == null:
		return 1
	return maxi(atlas.get_width() / CELL, 1)


func max_part_index() -> int:
	return variant_count() - 1


func part_index(part: int) -> int:
	match part:
		0:
			return 脸
		1:
			return 头发
		2:
			return 眼睛
		3:
			return 胡子
		4:
			return 嘴
		_:
			return 身体


func part_region(part: int) -> Rect2:
	return Rect2(part_index(part) * CELL, part * CELL, CELL, CELL)


func _validate_property(property: Dictionary) -> void:
	if property.name in PART_NAMES:
		property.hint = PROPERTY_HINT_RANGE
		property.hint_string = "0,%d,1" % max_part_index()


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	texture_filter = TEXTURE_FILTER_NEAREST
	custom_minimum_size = Vector2(CELL, CELL)
	if size.x < 1.0 or size.y < 1.0:
		size = Vector2(CELL, CELL)


func _refresh() -> void:
	脸 = 脸
	头发 = 头发
	眼睛 = 眼睛
	胡子 = 胡子
	嘴 = 嘴
	身体 = 身体


func _draw() -> void:
	if atlas == null:
		return
	var dest := Rect2(Vector2.ZERO, size)
	for part in _DRAW_ORDER:
		draw_texture_rect_region(atlas, dest, part_region(part))


func _wrap(value: int) -> int:
	return posmod(value, variant_count())
