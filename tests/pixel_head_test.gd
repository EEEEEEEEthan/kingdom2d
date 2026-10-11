extends SceneTree

## 彩色部位直接叠。女性默认组合对齐参考图。


func _init() -> void:
	if load("res://addons/pixel_head/plugin.gd") == null:
		push_error("脚本没编过")
		quit(1)
		return
	_assert_parts_are_colored()
	_assert_canvas_size()
	_assert_reference_pixels()
	_assert_male_reference_pixels()
	_assert_male_reference_b_pixels()
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


func _assert_parts_are_colored() -> void:
	var image := PixelHead._FEMALE_HAIR_MID.get_image()
	var found := false
	for y in image.get_height():
		for x in image.get_width():
			var pixel := image.get_pixel(x, y)
			if pixel.a <= 0.0:
				continue
			found = true
			if pixel.r > 0.99 and pixel.g > 0.99 and pixel.b > 0.99:
				push_error("头发部位不该是纯白遮罩")
				quit(1)
				return
	if not found:
		push_error("头发部位是空的")
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
	var female := PixelHead.create(0, 0, 0, 0, 0, 0)
	var male_a := PixelHead.create(1, 0, 0, 0, 0, 0)
	var male_b := PixelHead.create(1, 2, 0, 0, 0, 0)
	root.add_child(female)
	root.add_child(male_a)
	root.add_child(male_b)
	var female_image := female.build_image()
	var male_image := male_a.build_image()
	var other_image := male_b.build_image()
	if _count_diff(female_image, male_image) == 0:
		push_error("男性和女性头像一样")
		quit(1)
	if _count_diff(male_image, other_image) == 0:
		push_error("两款男性头发一样")
		quit(1)


func _count_diff(left: Image, right: Image) -> int:
	var diff := 0
	for y in left.get_height():
		for x in left.get_width():
			if left.get_pixel(x, y) != right.get_pixel(x, y):
				diff += 1
	return diff


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
	_assert_covered(got, ref)


func _assert_male_reference_pixels() -> void:
	var head := PixelHead.create(1, 0, 0, 0, 0, 0)
	root.add_child(head)
	var got := head.build_image()
	var ref := PixelHead._MALE_REFERENCE.get_image()
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
		push_error("和男性模板像素不一致 %d" % mismatch)
		quit(1)
	_assert_covered(got, ref)


func _assert_male_reference_b_pixels() -> void:
	var head := PixelHead.create(1, 1, 0, 0, 0, 0)
	root.add_child(head)
	var got := head.build_image()
	var ref := PixelHead._MALE_REFERENCE_B.get_image()
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
		push_error("和第二张男性模板像素不一致 %d" % mismatch)
		quit(1)
	_assert_covered(got, ref)


func _assert_covered(got: Image, ref: Image) -> void:
	var missing := 0
	for y in ref.get_height():
		for x in ref.get_width():
			var expect := ref.get_pixel(x, y)
			if expect.a <= 0.0:
				continue
			var pixel := got.get_pixel(x, y)
			if pixel.a <= 0.0 or pixel.r8 != expect.r8 or pixel.g8 != expect.g8 or pixel.b8 != expect.b8:
				missing += 1
	if missing != 0:
		push_error("模板像素没画全 %d" % missing)
		quit(1)
		return


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
