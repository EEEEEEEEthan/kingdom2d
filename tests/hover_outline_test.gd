extends SceneTree

const _OUTLINE_SCRIPT = preload("res://game/hover_outline.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var back := _host(Color(0.2, 0.45, 0.9, 1), Vector2(16, 16))
	var front := _host(Color(0.9, 0.25, 0.2, 1), Vector2(18, 16))
	var cover := Sprite2D.new()
	cover.texture = _solid_texture(Color(0.1, 0.8, 0.2, 1), 8, 8)
	cover.centered = true
	cover.position = Vector2(22, 16)
	root.add_child(back)
	root.add_child(front)
	root.add_child(cover)
	await process_frame
	var back_outline = back.get_node("HoverOutline")
	var front_outline = front.get_node("HoverOutline")
	back_outline.set_process(false)
	front_outline.set_process(false)
	_point_at(front.get_node("Sprite2D"))
	front.show_outline = false
	front_outline.show_outline = false
	back_outline._process(0.0)
	if _ghost_visible(front_outline) or _ghost_visible(back_outline):
		push_error("前面的对象关闭描边时，不该穿透到后面")
		quit(1)
		return
	front.show_outline = true
	front_outline.show_outline = true
	_OUTLINE_SCRIPT._pick_frame = -1
	back_outline._process(0.0)
	if not _ghost_visible(front_outline) or _ghost_visible(back_outline):
		push_error("重叠处只该描最前面的对象")
		quit(1)
		return
	var image := await _render()
	DirAccess.make_dir_recursive_absolute("/opt/cursor/artifacts")
	image.save_png("/opt/cursor/artifacts/hover_outline_character.png")
	var white_on_cover := 0
	for y in image.get_height():
		for x in image.get_width():
			var pixel := image.get_pixel(x, y)
			if pixel.r > 0.9 and pixel.g > 0.9 and pixel.b > 0.9 and pixel.a > 0.5:
				white_on_cover += 1
	if white_on_cover < 4:
		push_error("描边应盖在其他物体上面，white=%s" % white_on_cover)
		quit(1)
		return
	print("hover_outline_ok white=", white_on_cover)
	quit(0)


func _host(color: Color, at: Vector2) -> Node2D:
	var host := Node2D.new()
	host.position = at
	host.set_script(load("res://tests/hover_outline_host.gd"))
	var sprite := Sprite2D.new()
	sprite.name = "Sprite2D"
	sprite.texture = _solid_texture(color, 6, 6)
	sprite.centered = true
	host.add_child(sprite)
	_OUTLINE_SCRIPT.attach(host)
	return host


func _solid_texture(color: Color, width: int, height: int) -> Texture2D:
	var image := Image.create(width, height, false, Image.FORMAT_RGBA8)
	image.fill(color)
	return ImageTexture.create_from_image(image)


func _point_at(sprite: Sprite2D) -> void:
	var center: Vector2 = sprite.to_global(sprite.get_rect().get_center())
	sprite.get_viewport().warp_mouse(Vector2i(center))


func _ghost_visible(outline: Node) -> bool:
	for child in outline.get_children():
		if child is Sprite2D and child.visible:
			return true
	return false


func _render() -> Image:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(40, 40)
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var holder := Node2D.new()
	viewport.add_child(holder)
	var nodes: Array[Node] = []
	for child in root.get_children():
		if child == viewport:
			continue
		nodes.append(child)
	for node in nodes:
		node.reparent(holder)
	await process_frame
	await process_frame
	return viewport.get_texture().get_image()
