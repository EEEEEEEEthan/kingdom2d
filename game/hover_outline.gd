extends Node2D
class_name HoverOutline

const _SHADER := preload("res://game/hover_outline.gdshader")

var show_outline := true
var _materials: Dictionary = {}


static func attach(host: Node2D) -> Node:
	var outline := preload("res://game/hover_outline.gd").new()
	outline.name = "HoverOutline"
	host.add_child(outline)
	if "show_outline" in host:
		outline.show_outline = host.show_outline
	return outline


func _process(_delta: float) -> void:
	var host := get_parent() as Node2D
	if host == null:
		return
	var hovered := show_outline and host.is_visible_in_tree() and _pointer_hits(host)
	for child in host.get_children():
		if not child is Sprite2D:
			continue
		var sprite := child as Sprite2D
		if sprite.texture == null:
			continue
		var material := _material_for(sprite)
		material.set_shader_parameter("enabled", 1.0 if hovered and sprite.visible else 0.0)
		material.set_shader_parameter("region_uv", _region_uv(sprite))


func _pointer_hits(host: Node2D) -> bool:
	var viewport := host.get_viewport()
	if viewport == null:
		return false
	if not viewport.get_visible_rect().has_point(viewport.get_mouse_position()):
		return false
	var global_mouse := host.get_global_mouse_position()
	for child in host.get_children():
		if not child is Sprite2D:
			continue
		var sprite := child as Sprite2D
		if not sprite.visible or sprite.texture == null:
			continue
		if sprite.get_rect().grow(1.0).has_point(sprite.to_local(global_mouse)):
			return true
	return false


func _material_for(sprite: Sprite2D) -> ShaderMaterial:
	var existing: Variant = _materials.get(sprite)
	if existing is ShaderMaterial:
		return existing
	var material := ShaderMaterial.new()
	material.shader = _SHADER
	sprite.material = material
	_materials[sprite] = material
	return material


func _region_uv(sprite: Sprite2D) -> Vector4:
	var size := sprite.texture.get_size()
	if not sprite.region_enabled or size.x <= 0.0 or size.y <= 0.0:
		return Vector4(0.0, 0.0, 1.0, 1.0)
	var rect := sprite.region_rect
	return Vector4(rect.position.x / size.x, rect.position.y / size.y, rect.end.x / size.x, rect.end.y / size.y)
