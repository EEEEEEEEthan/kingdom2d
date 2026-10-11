extends SceneTree

func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var character := (load("res://game/characters/character.tscn") as PackedScene).instantiate() as Character
	root.add_child(character)
	var hut := StructureConfig.gatherer_hut.instantiate() as Structure
	root.add_child(hut)
	var oak := StructureConfig.oak.instantiate() as Structure
	root.add_child(oak)
	await process_frame
	if character.get_child(0) is not HoverOutline:
		push_error("小人应有描边节点")
		quit(1)
		return
	if hut.get_child(0) is not HoverOutline:
		push_error("建筑应有描边节点")
		quit(1)
		return
	if _has_outline(oak):
		push_error("植物不应有描边")
		quit(1)
		return
	var outline := character.get_child(0) as HoverOutline
	var sprite := character.get_node("Sprite2D") as Sprite2D
	var inside := sprite.get_rect().get_center()
	if not sprite.get_rect().has_point(sprite.to_local(character.to_global(inside))):
		push_error("精灵矩形应包含中心点")
		quit(1)
		return
	outline.visible = true
	outline._sync_sprites(character)
	if outline.get_child_count() != 4:
		push_error("描边应是上下左右四向")
		quit(1)
		return
	var image := await _render_outlined(character)
	if image == null or image.is_empty():
		push_error("描边截图失败")
		quit(1)
		return
	var white := 0
	for y in image.get_height():
		for x in image.get_width():
			var pixel := image.get_pixel(x, y)
			if pixel.a > 0.5 and pixel.r > 0.9 and pixel.g > 0.9 and pixel.b > 0.9:
				white += 1
	if white < 4:
		push_error("描边截图里没有白色像素")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute("/opt/cursor/artifacts")
	image.save_png("/opt/cursor/artifacts/hover_outline_character.png")
	var hut_image := await _render_outlined(hut)
	hut_image.save_png("/opt/cursor/artifacts/hover_outline_hut.png")
	print("hover_outline_ok white=", white)
	quit(0)


func _has_outline(node: Node) -> bool:
	for child in node.get_children():
		if child is HoverOutline:
			return true
	return false


func _render_outlined(host: Node2D) -> Image:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(48, 48)
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var holder := Node2D.new()
	holder.position = Vector2(24, 32)
	viewport.add_child(holder)
	var copy := host.duplicate() as Node2D
	holder.add_child(copy)
	var outline := copy.get_child(0) as HoverOutline
	outline.visible = true
	outline._sync_sprites(copy)
	await process_frame
	await process_frame
	var texture := viewport.get_texture()
	if texture == null:
		return null
	return texture.get_image()
