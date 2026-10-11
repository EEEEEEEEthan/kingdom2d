@tool
extends Control
class_name PixelAvatar

## Face, hair, eyes, mouth, and body share one atlas.
## The mouth cell includes the beard.
## Each cell is 16x16. Column count is width / 16. Indices wrap.
## The five parts are inspector sliders.
## Eyes are two 16x8 strips: open on top, closed on the bottom.

const CELL := 16
const HALF := 8
const EYE_TOP := 2
const EYES_PART := 2
const PART_COUNT := 5
const PART_NAMES: PackedStringArray = ["face", "hair", "eyes", "mouth", "body"]
const _DRAW_ORDER: Array[int] = [4, 0, 1, 2, 3]
const _BLINK_GAP_MIN := 2.2
const _BLINK_GAP_MAX := 5.0
const _BLINK_HOLD := 0.12

@export var atlas: Texture2D = preload("res://addons/pixel_avatar/atlas.png"):
	set(value):
		atlas = value
		_refresh()
		notify_property_list_changed()

@export var face := 0:
	set(value):
		face = _wrap(value)
		queue_redraw()
@export var hair := 0:
	set(value):
		hair = _wrap(value)
		queue_redraw()
@export var eyes := 0:
	set(value):
		eyes = _wrap(value)
		queue_redraw()
@export var mouth := 0:
	set(value):
		mouth = _wrap(value)
		queue_redraw()
@export var body := 0:
	set(value):
		body = _wrap(value)
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
			return face
		1:
			return hair
		2:
			return eyes
		3:
			return mouth
		_:
			return body


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
	set_process(true)
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
	face = face
	hair = hair
	eyes = eyes
	mouth = mouth
	body = body


func _draw() -> void:
	if atlas == null:
		return
	var dest := Rect2(Vector2.ZERO, size)
	var eye_dest := Rect2(0, size.y * EYE_TOP / CELL, size.x, size.y * HALF / CELL)
	for part in _DRAW_ORDER:
		var region := part_region(part)
		if part == EYES_PART:
			draw_texture_rect_region(atlas, eye_dest, region)
		else:
			draw_texture_rect_region(atlas, dest, region)


func _wrap(value: int) -> int:
	return posmod(value, variant_count())
