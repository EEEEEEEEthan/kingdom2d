@tool
extends Node2D
class_name PixelAvatar

## 脸、头发、眼睛、胡子、嘴、身体叠在同一张 atlas 上。
## 每格固定 16×16。列数是贴图宽度除以 16 的整数，下标超出后取模。

const CELL := 16
const PART_COUNT := 6
const PART_NAMES: PackedStringArray = ["脸", "头发", "眼睛", "胡子", "嘴", "身体"]
const _DRAW_ORDER: Array[int] = [1, 2, 3, 4, 5, 0]

@export var atlas: Texture2D = preload("res://addons/pixel_avatar/atlas.png"):
	set(value):
		atlas = value
		_refresh()

var part_index: Array[int] = [0, 0, 0, 0, 0, 0]

var _sprites: Array[Sprite2D] = []
var _sliders: Array[HSlider] = []


func variant_count() -> int:
	if atlas == null:
		return 1
	return maxi(atlas.get_width() / CELL, 1)


func max_part_index() -> int:
	return variant_count() - 1


func set_part_index(part: int, value: int) -> void:
	part_index[part] = posmod(value, variant_count())
	_apply_sprite(part)
	if part < _sliders.size():
		_sliders[part].max_value = max_part_index()
		_sliders[part].set_value_no_signal(part_index[part])


func _init() -> void:
	_ensure_nodes()
	_refresh()


func _ensure_nodes() -> void:
	if _sprites.size() == PART_COUNT and _sliders.size() == PART_COUNT:
		return
	var parts := get_node_or_null(^"Parts") as Node2D
	if parts == null:
		parts = Node2D.new()
		parts.name = "Parts"
		parts.scale = Vector2(6, 6)
		parts.position = Vector2(56, 56)
		add_child(parts)
	_sprites.clear()
	for part in PART_COUNT:
		var sprite := parts.get_node_or_null(NodePath(PART_NAMES[part])) as Sprite2D
		if sprite == null:
			sprite = Sprite2D.new()
			sprite.name = PART_NAMES[part]
			sprite.centered = true
			sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			parts.add_child(sprite)
		sprite.z_index = _DRAW_ORDER[part]
		_sprites.append(sprite)
	var layer := get_node_or_null(^"滑条") as CanvasLayer
	if layer == null:
		layer = CanvasLayer.new()
		layer.name = "滑条"
		add_child(layer)
		var box := VBoxContainer.new()
		box.position = Vector2(120, 12)
		box.add_theme_constant_override("separation", 6)
		layer.add_child(box)
		for part in PART_COUNT:
			var row := HBoxContainer.new()
			var label := Label.new()
			label.text = PART_NAMES[part]
			label.custom_minimum_size = Vector2(40, 0)
			var slider := HSlider.new()
			slider.custom_minimum_size = Vector2(180, 18)
			slider.step = 1
			slider.min_value = 0
			var captured := part
			slider.value_changed.connect(func(next_value: float) -> void:
				set_part_index(captured, int(next_value))
			)
			row.add_child(label)
			row.add_child(slider)
			box.add_child(row)
	_sliders.clear()
	var rows := layer.get_child(0)
	for part in PART_COUNT:
		_sliders.append(rows.get_child(part).get_child(1) as HSlider)


func _refresh() -> void:
	if _sprites.size() != PART_COUNT:
		return
	var count := variant_count()
	for part in PART_COUNT:
		part_index[part] = posmod(part_index[part], count)
		_apply_sprite(part)
		if part < _sliders.size():
			_sliders[part].max_value = count - 1
			_sliders[part].set_value_no_signal(part_index[part])


func _apply_sprite(part: int) -> void:
	if part >= _sprites.size():
		return
	var sprite := _sprites[part]
	sprite.texture = atlas
	sprite.region_enabled = true
	sprite.region_rect = Rect2(part_index[part] * CELL, part * CELL, CELL, CELL)
