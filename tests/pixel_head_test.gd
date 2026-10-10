extends SceneTree

## 无界面检查：部件拼头、肤色、眨眼两帧。


func _init() -> void:
	if load("res://game/characters/character.gd") == null or load("res://game/game_builder.gd") == null:
		push_error("角色脚本没编过")
		quit(1)
		return
	var open_head := PixelHead.create(0, 2, 1, 0)
	var closed_head := PixelHead.create(1, 3, 0, 3)
	root.add_child(open_head)
	root.add_child(closed_head)
	_assert_parts(open_head)
	_assert_skin_differs()
	_assert_blink(open_head)
	_export_sheet(open_head, closed_head)
	_export_catalog()
	print("pixel_head_test ok")
	quit(0)


func _assert_parts(head: PixelHead) -> void:
	for part_name in ["Skin", "Mouth", "Hair", "EyesOpen", "EyesClosed"]:
		var part := head.get_node(part_name) as Sprite2D
		if part == null or part.texture == null:
			push_error("缺少部件 %s" % part_name)
			quit(1)
			return
		if part.texture.get_width() != PixelHead.SIZE or part.texture.get_height() != PixelHead.SIZE:
			push_error("尺寸不对 %s" % part_name)
			quit(1)
			return
	assert(head.eyes_open.visible)
	assert(not head.eyes_closed.visible)


func _assert_skin_differs() -> void:
	var light := PixelHead.create(0, 0, 0, 0)
	var dark := PixelHead.create(0, 0, 0, 3)
	root.add_child(light)
	root.add_child(dark)
	var light_pixel := light.skin.texture.get_image().get_pixel(3, 3)
	var dark_pixel := dark.skin.texture.get_image().get_pixel(3, 3)
	assert(light_pixel != dark_pixel)


func _assert_blink(head: PixelHead) -> void:
	head.blink()
	assert(head.is_blinking)
	assert(not head.eyes_open.visible)
	assert(head.eyes_closed.visible)


func _export_sheet(open_head: PixelHead, closed_head: PixelHead) -> void:
	var scale := 8
	var sheet := Image.create(PixelHead.SIZE * scale * 2, PixelHead.SIZE * scale, false, Image.FORMAT_RGBA8)
	sheet.fill(Color8(203, 219, 252))
	_blit_head(sheet, open_head, 0, 0, scale)
	closed_head.blink()
	_blit_head(sheet, closed_head, PixelHead.SIZE * scale, 0, scale)
	var path := "/opt/cursor/artifacts/pixel_head_sheet.png"
	var error := sheet.save_png(path)
	assert(error == OK, "save png %s" % error)


func _export_catalog() -> void:
	var scale := 6
	var cell := PixelHead.SIZE * scale
	var cols := PixelHead.HAIR_COUNT
	var rows := PixelHead.EYES_COUNT
	var sheet := Image.create(cell * cols, cell * rows, false, Image.FORMAT_RGBA8)
	sheet.fill(Color8(34, 32, 52))
	for eyes_id in rows:
		for hair_id in cols:
			var head := PixelHead.create(eyes_id % PixelHead.GENDER_COUNT, hair_id, eyes_id, hair_id % PixelHead.SKIN_COUNT)
			root.add_child(head)
			if eyes_id == rows - 1:
				head.blink()
			_blit_head(sheet, head, hair_id * cell, eyes_id * cell, scale)
	var error := sheet.save_png("/opt/cursor/artifacts/pixel_head_catalog.png")
	if error != OK:
		push_error("catalog png %s" % error)
		quit(1)


func _blit_head(sheet: Image, head: PixelHead, origin_x: int, origin_y: int, scale: int) -> void:
	var layers: Array[Sprite2D] = [head.skin, head.mouth, head.hair]
	if head.is_blinking:
		layers.append(head.eyes_closed)
	else:
		layers.append(head.eyes_open)
	for layer in layers:
		var image := layer.texture.get_image()
		for y in PixelHead.SIZE:
			for x in PixelHead.SIZE:
				var pixel := image.get_pixel(x, y)
				if pixel.a <= 0.0:
					continue
				sheet.fill_rect(Rect2i(origin_x + x * scale, origin_y + y * scale, scale, scale), pixel)
