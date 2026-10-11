extends Node2D
class_name HoverOutline

const _SHADER := preload("res://game/hover_outline.gdshader")
const _DRAW_Z := 4096

static var _outlines: Array = []
static var _pick_frame := -1
static var _winner: Node2D

var show_outline := true
var _ghosts: Array[Sprite2D] = []


static func attach(host: Node2D) -> Node:
	var outline := preload("res://game/hover_outline.gd").new()
	outline.name = "HoverOutline"
	outline.z_as_relative = false
	outline.z_index = _DRAW_Z
	host.add_child(outline)
	if "show_outline" in host:
		outline.show_outline = host.show_outline
	return outline


func _enter_tree() -> void:
	_outlines.append(self)


func _exit_tree() -> void:
	_outlines.erase(self)
	if _winner == get_parent():
		_winner = null


func _process(_delta: float) -> void:
	var frame := Engine.get_process_frames()
	if _pick_frame == frame:
		return
	_pick_frame = frame
	_winner = _pick_winner()
	for outline: Node in _outlines.duplicate():
		outline._show_outline(outline.get_parent() == _winner)


func _show_outline(active: bool) -> void:
	var host := get_parent() as Node2D
	if host == null or not active:
		for ghost in _ghosts:
			ghost.visible = false
		return
	var sprites: Array[Sprite2D] = []
	for child in host.get_children():
		if child == self or not child is Sprite2D:
			continue
		var sprite := child as Sprite2D
		if sprite.visible and sprite.texture != null:
			sprites.append(sprite)
	while _ghosts.size() < sprites.size():
		var ghost := Sprite2D.new()
		var material := ShaderMaterial.new()
		material.shader = _SHADER
		ghost.material = material
		ghost.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		ghost.z_as_relative = false
		ghost.z_index = _DRAW_Z
		add_child(ghost)
		_ghosts.append(ghost)
	for index in sprites.size():
		var source := sprites[index]
		var ghost := _ghosts[index]
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
		ghost.global_transform = source.global_transform
		(ghost.material as ShaderMaterial).set_shader_parameter("region_uv", _region_uv(source))
	for extra in range(sprites.size(), _ghosts.size()):
		_ghosts[extra].visible = false


static func _pick_winner() -> Node2D:
	var viewport: Viewport = null
	if not _outlines.is_empty():
		viewport = (_outlines[0] as Node).get_viewport()
	if viewport == null or not viewport.get_visible_rect().has_point(viewport.get_mouse_position()):
		return null
	var mouse: Vector2 = viewport.get_canvas_transform().affine_inverse() * viewport.get_mouse_position()
	var opaque: Array[Node2D] = []
	var ring: Array[Node2D] = []
	for outline: Node in _outlines:
		var host := outline.get_parent() as Node2D
		if host == null or not host.is_visible_in_tree():
			continue
		var hit := _hit_kind(host, mouse)
		if hit == 2:
			opaque.append(host)
		elif hit == 1 and outline.show_outline:
			ring.append(host)
	if not opaque.is_empty():
		var blocker := _frontmost(opaque)
		var blocker_outline := blocker.get_node_or_null(^"HoverOutline")
		if blocker_outline and blocker_outline.show_outline:
			return blocker
		return null
	if ring.is_empty():
		return null
	return _frontmost(ring)


static func _frontmost(hosts: Array[Node2D]) -> Node2D:
	var front := hosts[0]
	for index in range(1, hosts.size()):
		if _is_in_front(hosts[index], front):
			front = hosts[index]
	return front


static func _hit_kind(host: Node2D, world_mouse: Vector2) -> int:
	var kind := 0
	for child in host.get_children():
		if not child is Sprite2D:
			continue
		var sprite := child as Sprite2D
		if not sprite.visible or sprite.texture == null:
			continue
		var local := sprite.to_local(world_mouse)
		var rect := sprite.get_rect()
		if not rect.grow(1.0).has_point(local):
			continue
		if rect.has_point(local) and _opaque(sprite, local):
			kind = 2
		elif kind == 0:
			kind = 1
	return kind


static func _opaque(sprite: Sprite2D, local: Vector2) -> bool:
	var image := _image_of(sprite.texture)
	if image == null or image.is_empty():
		return true
	var rect := sprite.get_rect()
	if rect.size.x == 0.0 or rect.size.y == 0.0:
		return false
	var unit := (local - rect.position) / rect.size
	var region := _region_uv(sprite)
	var uv := Vector2(region.x, region.y) + Vector2(region.z - region.x, region.w - region.y) * unit
	var x := clampi(int(uv.x * image.get_width()), 0, image.get_width() - 1)
	var y := clampi(int(uv.y * image.get_height()), 0, image.get_height() - 1)
	return image.get_pixel(x, y).a > 0.001


static func _image_of(texture: Texture2D) -> Image:
	if texture is CanvasTexture and (texture as CanvasTexture).diffuse_texture:
		texture = (texture as CanvasTexture).diffuse_texture
	return texture.get_image()


static func _is_in_front(front: Node, back: Node) -> bool:
	var front_key := _draw_key(front)
	var back_key := _draw_key(back)
	var shared := mini(front_key.size(), back_key.size())
	for index in shared:
		var ahead: Vector3 = front_key[index]
		var behind: Vector3 = back_key[index]
		if ahead.is_equal_approx(behind):
			continue
		if not is_equal_approx(ahead.x, behind.x):
			return ahead.x > behind.x
		if not is_equal_approx(ahead.y, behind.y):
			return ahead.y > behind.y
		return ahead.z > behind.z
	if front_key.size() == back_key.size():
		return false
	if front_key.size() > back_key.size():
		return front_key[shared].x > 0.0
	return back_key[shared].x <= 0.0


static func _draw_key(node: Node) -> Array[Vector3]:
	var key: Array[Vector3] = []
	var current := node
	while current:
		var behind := 1.0
		var z := 0.0
		var order := float(current.get_index())
		if current is CanvasItem:
			var item := current as CanvasItem
			behind = 0.0 if item.show_behind_parent else 1.0
			z = float(item.z_index)
		var parent := current.get_parent()
		if parent is Node2D and (parent as Node2D).y_sort_enabled and current is Node2D:
			order = (current as Node2D).position.y
		key.push_front(Vector3(behind, z, order))
		current = parent
	return key


static func _region_uv(sprite: Sprite2D) -> Vector4:
	var size := sprite.texture.get_size()
	if not sprite.region_enabled or size.x <= 0.0 or size.y <= 0.0:
		return Vector4(0.0, 0.0, 1.0, 1.0)
	var rect := sprite.region_rect
	return Vector4(rect.position.x / size.x, rect.position.y / size.y, rect.end.x / size.x, rect.end.y / size.y)
