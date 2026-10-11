extends SceneTree

## atlas 六行、每格 16，下标按列数取模，六个滑条改部位。


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var avatar := PixelAvatar.new()
	root.add_child(avatar)
	await process_frame
	if avatar.get_child_count() < 2:
		push_error("缺少部位节点或滑条")
		quit(1)
		return
	if avatar._sliders.size() != PixelAvatar.PART_COUNT:
		push_error("滑条数量不对")
		quit(1)
		return
	if avatar.variant_count() != avatar.atlas.get_width() / PixelAvatar.CELL:
		push_error("列数应按 16 整除")
		quit(1)
		return
	avatar.set_part_index(1, avatar.variant_count() + 2)
	if avatar.part_index[1] != 2:
		push_error("取模失败 %s" % avatar.part_index[1])
		quit(1)
		return
	if avatar._sprites[1].region_rect.position != Vector2(2 * PixelAvatar.CELL, PixelAvatar.CELL):
		push_error("头发区域不对")
		quit(1)
		return
	var odd := Image.create(50, PixelAvatar.CELL * PixelAvatar.PART_COUNT, false, Image.FORMAT_RGBA8)
	odd.fill(Color(1, 0, 0, 1))
	avatar.atlas = ImageTexture.create_from_image(odd)
	if avatar.variant_count() != 3 or avatar.max_part_index() != 2:
		push_error("50 宽应只有 3 列，实际 %s" % avatar.variant_count())
		quit(1)
		return
	avatar.set_part_index(0, 5)
	if avatar.part_index[0] != 2 or avatar._sliders[0].max_value != 2:
		push_error("滑条上限或取模不对")
		quit(1)
		return
	avatar.atlas = load("res://addons/pixel_avatar/atlas.png")
	for part in PixelAvatar.PART_COUNT:
		avatar._sliders[part].value = part % avatar.variant_count()
		if avatar.part_index[part] != part % avatar.variant_count():
			push_error("滑条没有写回部位")
			quit(1)
			return
	_export_sheet(avatar)
	print("pixel_avatar_test ok")
	quit(0)


func _export_sheet(avatar: PixelAvatar) -> void:
	var scale := 8
	var count := avatar.variant_count()
	var sheet := Image.create(PixelAvatar.CELL * scale * count, PixelAvatar.CELL * scale, false, Image.FORMAT_RGBA8)
	sheet.fill(Color8(34, 32, 52))
	var source := avatar.atlas.get_image()
	for index in count:
		for part in PixelAvatar.PART_COUNT:
			var from := Rect2i(index * PixelAvatar.CELL, part * PixelAvatar.CELL, PixelAvatar.CELL, PixelAvatar.CELL)
			var cell := source.get_region(from)
			for y in PixelAvatar.CELL:
				for x in PixelAvatar.CELL:
					var pixel := cell.get_pixel(x, y)
					if pixel.a <= 0.0:
						continue
					sheet.fill_rect(Rect2i((index * PixelAvatar.CELL + x) * scale, y * scale, scale, scale), pixel)
	var error := sheet.save_png("/opt/cursor/artifacts/pixel_avatar_sheet.png")
	if error != OK:
		push_error("预览图保存失败 %s" % error)
		quit(1)
