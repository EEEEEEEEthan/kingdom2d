extends SceneTree

## 遮罩是纯白，颜色只来自色板下标。


func _init() -> void:
	if load("res://addons/pixel_head/plugin.gd") == null:
		push_error("脚本没编过")
		quit(1)
		return
	_assert_masks_are_white()
	_assert_canvas_size()
	_assert_reference_pixels()
	var open_head := PixelHead.create(0, 2, 2, 1, 0, 0)
	var closed_head := PixelHead.create(1, 3, 3, 0, 1, 3)
	root.add_child(open_head)
	root.add_child(closed_head)
	_assert_parts(open_head)
	_assert_color_is_independent()
	_assert_blink(open_head)
	_export_sheet(open_head, closed_head)
	_export_catalog()
	print("pixel_head_test ok")
	quit(0)


func _assert_masks_are_white() -> void:
	var image := PixelHead._HAIRS[0].get_image()
	var found := false
	for y in image.get_height():
		for x in image.get_width():
			var pixel := image.get_pixel(x, y)
			if pixel.a <= 0.0:
				continue
			found = true
			if pixel.r < 0.99 or pixel.g < 0.99 or pixel.b < 0.99:
				push_error("发型遮罩不是纯白")
				quit(1)
				return
	if not found:
		push_error("发型遮罩是空的")
		quit(1)


func _assert_canvas_size() -> void:
	var image := PixelHead._REF_OUTLINE.get_image()
	if image.get_width() != PixelHead.SIZE or image.get_height() != PixelHead.SIZE:
		push_error("脸遮罩不是 %d" % PixelHead.SIZE)
		quit(1)


func _assert_parts(head: PixelHead) -> void:
	if head.get_child_count() != 0:
		push_error("头应该是单个节点")
		quit(1)
	assert(not head.is_blinking)


func _assert_color_is_independent() -> void:
	var blonde := PixelHead.create(0, 0, 2, 0, 0, 0)
	var red := PixelHead.create(0, 0, 3, 0, 0, 0)
	assert(blonde.hair_id == red.hair_id)
	assert(PixelHead.HAIR_PALETTE.color_at(blonde.hair_color_idx) != PixelHead.HAIR_PALETTE.color_at(red.hair_color_idx))
	assert(PixelHead.SKIN_PALETTE != PixelHead.HAIR_PALETTE)


func _assert_blink(head: PixelHead) -> void:
	head.blink()
	assert(head.is_blinking)


func _assert_reference_pixels() -> void:
	var head := PixelHead.create(0, 0, 0, 0, 0, 0)
	root.add_child(head)
	var got := head.build_image()
	var ref := PixelHead._REFERENCE.get_image()
	var mismatch := 0
	for y in PixelHead.SIZE:
		for x in PixelHead.SIZE:
			var pixel := got.get_pixel(x, y)
			if pixel.a <= 0.0:
				continue
			var expect := ref.get_pixel(x, y)
			if pixel.r8 != expect.r8 or pixel.g8 != expect.g8 or pixel.b8 != expect.b8:
				mismatch += 1
	if mismatch != 0:
		push_error("和参考图像素不一致 %d" % mismatch)
		quit(1)


func _export_sheet(open_head: PixelHead, closed_head: PixelHead) -> void:
	var scale := 8
	var sheet := Image.create(PixelHead.SIZE * scale * 2, PixelHead.SIZE * scale, false, Image.FORMAT_RGBA8)
	sheet.fill(Color8(203, 219, 252))
	_blit_head(sheet, open_head, 0, 0, scale)
	closed_head.blink()
	_blit_head(sheet, closed_head, PixelHead.SIZE * scale, 0, scale)
	assert(sheet.save_png("/opt/cursor/artifacts/pixel_head_sheet.png") == OK)


func _export_catalog() -> void:
	var scale := 6
	var cell := PixelHead.SIZE * scale
	var cols := PixelHead.HAIR_COUNT
	var rows := PixelHead.EYES_COUNT
	var sheet := Image.create(cell * cols, cell * rows, false, Image.FORMAT_RGBA8)
	sheet.fill(Color8(34, 32, 52))
	for eyes_id in rows:
		for hair_id in cols:
			var head := PixelHead.create(
				eyes_id % PixelHead.GENDER_COUNT,
				hair_id,
				hair_id % PixelHead.HAIR_PALETTE.color_count(),
				eyes_id,
				eyes_id % PixelHead.EYES_PALETTE.color_count(),
				hair_id % PixelHead.SKIN_PALETTE.color_count(),
				(hair_id + eyes_id) % PixelHead.CLOTHES_PALETTE.color_count(),
			)
			root.add_child(head)
			if eyes_id == rows - 1:
				head.blink()
			_blit_head(sheet, head, hair_id * cell, eyes_id * cell, scale)
	var error := sheet.save_png("/opt/cursor/artifacts/pixel_head_catalog.png")
	if error != OK:
		push_error("catalog png %s" % error)
		quit(1)


func _blit_head(sheet: Image, head: PixelHead, origin_x: int, origin_y: int, scale: int) -> void:
	var image := head.build_image()
	for y in image.get_height():
		for x in image.get_width():
			var pixel := image.get_pixel(x, y)
			if pixel.a <= 0.0:
				continue
			sheet.fill_rect(Rect2i(origin_x + x * scale, origin_y + y * scale, scale, scale), pixel)


func _blit_mask(sheet: Image, mask: Texture2D, color: Color, origin_x: int, origin_y: int, scale: int) -> void:
	var image := mask.get_image()
	for y in image.get_height():
		for x in image.get_width():
			if image.get_pixel(x, y).a <= 0.0:
				continue
			sheet.fill_rect(Rect2i(origin_x + x * scale, origin_y + y * scale, scale, scale), color)
