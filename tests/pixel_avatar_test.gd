extends SceneTree

## atlas 六行、每格 16。检查器滑条上限随列数变，下标取模。Control 自己画。


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var avatar := PixelAvatar.new()
	root.add_child(avatar)
	await process_frame
	if not avatar is Control or avatar.get_child_count() != 0:
		push_error("应是没有子节点的 Control")
		quit(1)
		return
	if not _range_hint_is(avatar, "头发", avatar.max_part_index()):
		quit(1)
		return
	avatar.头发 = avatar.variant_count() + 2
	if avatar.头发 != 2:
		push_error("取模失败 %s" % avatar.头发)
		quit(1)
		return
	if avatar.part_region(1).position != Vector2(2 * PixelAvatar.CELL, PixelAvatar.CELL):
		push_error("头发区域不对")
		quit(1)
		return
	var open_eyes := avatar.part_region(PixelAvatar.EYES_PART)
	if open_eyes.size != Vector2(PixelAvatar.CELL, PixelAvatar.HALF) or open_eyes.position.y != PixelAvatar.EYES_PART * PixelAvatar.CELL:
		push_error("睁眼应是格子上半")
		quit(1)
		return
	avatar.blink()
	var shut_eyes := avatar.part_region(PixelAvatar.EYES_PART)
	if not avatar.eyes_closed or shut_eyes.position.y != open_eyes.position.y + PixelAvatar.HALF:
		push_error("闭眼应是格子下半")
		quit(1)
		return
	avatar.eyes_closed = false
	var odd := Image.create(50, PixelAvatar.CELL * PixelAvatar.PART_COUNT, false, Image.FORMAT_RGBA8)
	odd.fill(Color(1, 0, 0, 1))
	avatar.atlas = ImageTexture.create_from_image(odd)
	if avatar.variant_count() != 3 or avatar.max_part_index() != 2:
		push_error("50 宽应只有 3 列，实际 %s" % avatar.variant_count())
		quit(1)
		return
	avatar.脸 = 5
	if avatar.脸 != 2 or not _range_hint_is(avatar, "脸", 2):
		push_error("检查器滑条上限或取模不对")
		quit(1)
		return
	avatar.atlas = load("res://addons/pixel_avatar/atlas.png")
	avatar.脸 = 0
	avatar.头发 = 1
	avatar.眼睛 = 2
	avatar.胡子 = 3
	avatar.嘴 = 0
	avatar.身体 = 1
	_export_sheet(avatar)
	print("pixel_avatar_test ok")
	quit(0)


func _range_hint_is(avatar: PixelAvatar, prop_name: String, max_index: int) -> bool:
	for prop in avatar.get_property_list():
		if prop.name != prop_name:
			continue
		if prop.hint != PROPERTY_HINT_RANGE or prop.hint_string != "0,%d,1" % max_index:
			push_error("%s 滑条提示是 %s" % [prop_name, prop.hint_string])
			return false
		return true
	push_error("没有属性 %s" % prop_name)
	return false


func _export_sheet(avatar: PixelAvatar) -> void:
	var scale := 8
	var count := avatar.variant_count()
	var sheet := Image.create(PixelAvatar.CELL * scale * count, PixelAvatar.CELL * scale * 2, false, Image.FORMAT_RGBA8)
	sheet.fill(Color8(34, 32, 52))
	var source := avatar.atlas.get_image()
	for row in 2:
		var closed := row == 1
		for index in count:
			_blit_avatar(sheet, source, index, closed, scale, row * PixelAvatar.CELL * scale)
	var error := sheet.save_png("/opt/cursor/artifacts/pixel_avatar_sheet.png")
	if error != OK:
		push_error("预览图保存失败 %s" % error)
		quit(1)


func _blit_avatar(sheet: Image, source: Image, index: int, closed: bool, scale: int, origin_y: int) -> void:
	for part in PixelAvatar._DRAW_ORDER:
		var region_y := part * PixelAvatar.CELL
		var region_h := PixelAvatar.CELL
		var dest_y := 0
		if part == PixelAvatar.EYES_PART:
			region_h = PixelAvatar.HALF
			if closed:
				region_y += PixelAvatar.HALF
		var cell := source.get_region(Rect2i(index * PixelAvatar.CELL, region_y, PixelAvatar.CELL, region_h))
		for y in region_h:
			for x in PixelAvatar.CELL:
				var pixel := cell.get_pixel(x, y)
				if pixel.a <= 0.0:
					continue
				var py := origin_y + (dest_y + y) * scale
				sheet.fill_rect(Rect2i((index * PixelAvatar.CELL + x) * scale, py, scale, scale), pixel)
