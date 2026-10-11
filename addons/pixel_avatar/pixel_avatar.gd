@tool
extends Control
class_name PixelAvatar

## 脸、头发、眼睛、胡子、嘴、身体叠在同一张 atlas 上。
## 每格固定 16×16。列数是贴图宽度除以 16 的整数，下标超出后取模。
## 六个部位在检查器里用滑条调。

const CELL := 16
const HALF := 8
const EYES_PART := 2
const PART_COUNT := 6
const PART_NAMES: PackedStringArray = ["脸", "头发", "眼睛", "胡子", "嘴", "身体"]
const _DRAW_ORDER: Array[int] = [5, 0, 1, 2, 3, 4]
const _BLINK_GAP_MIN := 2.2
const _BLINK_GAP_MAX := 5.0
const _BLINK_HOLD := 0.12

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

var eyes_closed := false

var _blink_left := 0.0
var _gap_left := 0.0


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
	var origin := Vector2(part_index(part) * CELL, part * CELL)
	if part == EYES_PART:
		if eyes_closed:
			origin.y += HALF
		return Rect2(origin, Vector2(CELL, HALF))
	return Rect2(origin, Vector2(CELL, CELL))


func blink() -> void:
	eyes_closed = true
	_blink_left = _BLINK_HOLD
	queue_redraw()


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
	if Engine.is_editor_hint():
		set_process(false)
		return
	_gap_left = randf_range(_BLINK_GAP_MIN, _BLINK_GAP_MAX)


func _process(delta: float) -> void:
	if eyes_closed:
		_blink_left -= delta
		if _blink_left <= 0.0:
			eyes_closed = false
			_gap_left = randf_range(_BLINK_GAP_MIN, _BLINK_GAP_MAX)
			queue_redraw()
		return
	_gap_left -= delta
	if _gap_left <= 0.0:
		blink()


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
	var eye_dest := Rect2(0, 0, size.x, size.y * 0.5)
	for part in _DRAW_ORDER:
		var region := part_region(part)
		if part == EYES_PART:
			draw_texture_rect_region(atlas, eye_dest, region)
		else:
			draw_texture_rect_region(atlas, dest, region)


func _wrap(value: int) -> int:
	return posmod(value, variant_count())
