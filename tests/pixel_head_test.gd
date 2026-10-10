extends SceneTree

## 遮罩是纯白，颜色只来自色板下标。


func _init() -> void:
	if load("res://addons/pixel_head/plugin.gd") == null:
		push_error("脚本没编过")
		quit(1)
		return
	_assert_masks_are_white()
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
	var face := head.gender_id
	_blit_mask(sheet, PixelHead._FACES[face], PixelHead.SKIN_PALETTE.color_at(head.skin_color_idx), origin_x, origin_y, scale)
	_blit_mask(sheet, PixelHead._BLUSHES[face], PixelHead.BLUSH_PALETTE.color_at(head.blush_color_idx), origin_x, origin_y, scale)
	_blit_mask(sheet, PixelHead._MOUTHS[face], PixelHead.MOUTH_PALETTE.color_at(head.mouth_color_idx), origin_x, origin_y, scale)
	_blit_mask(sheet, PixelHead._HAIRS[head.hair_id], PixelHead.HAIR_PALETTE.color_at(head.hair_color_idx), origin_x, origin_y, scale)
	if head.is_blinking:
		_blit_mask(sheet, PixelHead._EYES_CLOSED, PixelHead.EYES_CLOSED_PALETTE.color_at(head.eyes_closed_color_idx), origin_x, origin_y, scale)
		return
	_blit_mask(sheet, PixelHead._EYE_WHITES[head.eyes_id], PixelHead.EYE_WHITE_PALETTE.color_at(head.eye_white_color_idx), origin_x, origin_y, scale)
	_blit_mask(sheet, PixelHead._EYE_PUPILS[head.eyes_id], PixelHead.EYES_PALETTE.color_at(head.eye_color_idx), origin_x, origin_y, scale)


func _blit_mask(sheet: Image, mask: Texture2D, color: Color, origin_x: int, origin_y: int, scale: int) -> void:
	var image := mask.get_image()
	for y in image.get_height():
		for x in image.get_width():
			if image.get_pixel(x, y).a <= 0.0:
				continue
			sheet.fill_rect(Rect2i(origin_x + x * scale, origin_y + y * scale, scale, scale), color)
