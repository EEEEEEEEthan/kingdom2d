extends SceneTree

const _OUTLINE_SCRIPT = preload("res://game/hover_outline.gd")
const _SHADER = preload("res://game/hover_outline.gdshader")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var host := Node2D.new()
	var sprite := Sprite2D.new()
	sprite.texture = _solid_texture()
	sprite.centered = true
	sprite.offset = Vector2.ZERO
	host.add_child(sprite)
	_OUTLINE_SCRIPT.attach(host)
	root.add_child(host)
	await process_frame
	var outline = host.get_child(1)
	outline.set_process(false)
	var material := sprite.material as ShaderMaterial
	if material == null:
		outline._process(0.0)
		material = sprite.material as ShaderMaterial
	if material == null or material.shader != _SHADER:
		push_error("描边应挂 shader")
		quit(1)
		return
	_point_at(sprite)
	outline.show_outline = false
	outline._process(0.0)
	if material.get_shader_parameter("enabled") != 0.0:
		push_error("show_outline 关闭时不应描边")
		quit(1)
		return
	outline.show_outline = true
	outline._process(0.0)
	if material.get_shader_parameter("enabled") != 1.0:
		push_error("悬停时应描边")
		quit(1)
		return
	material.set_shader_parameter("region_uv", Vector4(0, 0, 1, 1))
	var image := await _render(host)
	DirAccess.make_dir_recursive_absolute("/opt/cursor/artifacts")
	image.save_png("/opt/cursor/artifacts/hover_outline_character.png")
	var white := _count_white(image)
	if white < 12:
		push_error("描边截图里没有白色像素，white=%s" % white)
		quit(1)
		return
	print("hover_outline_ok white=", white)
	quit(0)


func _point_at(sprite: Sprite2D) -> void:
	var center: Vector2 = sprite.to_global(sprite.get_rect().get_center())
	sprite.get_viewport().warp_mouse(Vector2i(center))


func _solid_texture() -> Texture2D:
	var image := Image.create(4, 6, false, Image.FORMAT_RGBA8)
	image.fill(Color(0.2, 0.45, 0.9, 1))
	return ImageTexture.create_from_image(image)


func _count_white(image: Image) -> int:
	var white := 0
	for y in image.get_height():
		for x in image.get_width():
			var pixel := image.get_pixel(x, y)
			if pixel.a > 0.5 and pixel.r > 0.9 and pixel.g > 0.9 and pixel.b > 0.9:
				white += 1
	return white


func _render(host: Node2D) -> Image:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(32, 32)
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var holder := Node2D.new()
	holder.position = Vector2(16, 16)
	viewport.add_child(holder)
	host.reparent(holder)
	host.position = Vector2.ZERO
	await process_frame
	await process_frame
	return viewport.get_texture().get_image()
