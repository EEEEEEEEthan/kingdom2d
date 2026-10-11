extends Node2D
class_name HoverOutline

const _OFFSETS: Array[Vector2] = [
	Vector2(1, 0),
	Vector2(-1, 0),
	Vector2(0, 1),
	Vector2(0, -1),
]

var _ghosts: Array[Sprite2D] = []
var _material: ShaderMaterial


static func attach(host: Node2D) -> void:
	var outline := HoverOutline.new()
	host.add_child(outline)
	host.move_child(outline, 0)


func _ready() -> void:
	_material = ShaderMaterial.new()
	_material.shader = preload("res://game/hover_outline.gdshader")
	visible = false


func _process(_delta: float) -> void:
	var host := get_parent() as Node2D
	if host == null or not host.is_visible_in_tree():
		visible = false
		return
	var hovered := _pointer_hits(host)
	visible = hovered
	if hovered:
		_sync_sprites(host)


func _pointer_hits(host: Node2D) -> bool:
	var viewport := host.get_viewport()
	if viewport == null:
		return false
	if not viewport.get_visible_rect().has_point(viewport.get_mouse_position()):
		return false
	var global_mouse := host.get_global_mouse_position()
	for child in host.get_children():
		if child == self or not child is Sprite2D:
			continue
		var sprite := child as Sprite2D
		if not sprite.visible or sprite.texture == null:
			continue
		if sprite.get_rect().has_point(sprite.to_local(global_mouse)):
			return true
	return false


func _sync_sprites(host: Node2D) -> void:
	var sprites: Array[Sprite2D] = []
	for child in host.get_children():
		if child == self or not child is Sprite2D:
			continue
		var sprite := child as Sprite2D
		if sprite.visible and sprite.texture != null:
			sprites.append(sprite)
	var needed := sprites.size() * _OFFSETS.size()
	while _ghosts.size() < needed:
		var ghost := Sprite2D.new()
		ghost.material = _material
		ghost.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		add_child(ghost)
		_ghosts.append(ghost)
	for sprite_index in sprites.size():
		var source := sprites[sprite_index]
		for offset_index in _OFFSETS.size():
			var ghost := _ghosts[sprite_index * _OFFSETS.size() + offset_index]
			ghost.visible = true
			ghost.texture = source.texture
			ghost.centered = source.centered
			ghost.offset = source.offset
			ghost.flip_h = source.flip_h
			ghost.flip_v = source.flip_v
			ghost.region_enabled = source.region_enabled
			ghost.region_rect = source.region_rect
			ghost.hframes = source.hframes
			ghost.vframes = source.vframes
			ghost.frame = source.frame
			ghost.scale = source.scale
			ghost.rotation = source.rotation
			ghost.position = source.position + _OFFSETS[offset_index]
	for extra_index in range(needed, _ghosts.size()):
		_ghosts[extra_index].visible = false
