extends SceneTree

## Six atlas rows, 16px cells. Inspector slider max follows column count. Indices wrap.


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var avatar := PixelAvatar.new()
	root.add_child(avatar)
	await process_frame
	if not avatar is Control or avatar.get_child_count() != 0:
		push_error("expected a Control with no children")
		quit(1)
		return
	if not _range_hint_is(avatar, "hair", avatar.max_part_index()):
		quit(1)
		return
	avatar.hair = avatar.variant_count() + 2
	if avatar.hair != 2:
		push_error("wrap failed %s" % avatar.hair)
		quit(1)
		return
	if avatar.part_region(1).position != Vector2(2 * PixelAvatar.CELL, PixelAvatar.CELL):
		push_error("hair region mismatch")
		quit(1)
		return
	var open_eyes := avatar.part_region(PixelAvatar.EYES_PART)
	if open_eyes.size != Vector2(PixelAvatar.CELL, PixelAvatar.HALF) or open_eyes.position.y != PixelAvatar.EYES_PART * PixelAvatar.CELL:
		push_error("open eyes should be the top half")
		quit(1)
		return
	avatar.blink()
	var shut_eyes := avatar.part_region(PixelAvatar.EYES_PART)
	if not avatar.eyes_closed or shut_eyes.position.y != open_eyes.position.y + PixelAvatar.HALF:
		push_error("closed eyes should be the bottom half")
		quit(1)
		return
	avatar.eyes_closed = false
	avatar._gap_left = 0.0
	avatar._process(0.01)
	if not avatar.eyes_closed:
		push_error("blink did not close the eyes")
		quit(1)
		return
	avatar._process(PixelAvatar._BLINK_HOLD + 0.01)
	if avatar.eyes_closed:
		push_error("blink did not reopen")
		quit(1)
		return
	var odd := Image.create(50, PixelAvatar.CELL * PixelAvatar.PART_COUNT, false, Image.FORMAT_RGBA8)
	odd.fill(Color(1, 0, 0, 1))
	avatar.atlas = ImageTexture.create_from_image(odd)
	if avatar.variant_count() != 3 or avatar.max_part_index() != 2:
		push_error("width 50 should be 3 columns, got %s" % avatar.variant_count())
		quit(1)
		return
	avatar.face = 5
	if avatar.face != 2 or not _range_hint_is(avatar, "face", 2):
		push_error("inspector range or wrap mismatch")
		quit(1)
		return
	avatar.atlas = load("res://addons/pixel_avatar/atlas.png")
	avatar.apply_id(1)
	var first := [avatar.face, avatar.hair, avatar.eyes, avatar.mouth, avatar.body]
	avatar.apply_id(2)
	var second := [avatar.face, avatar.hair, avatar.eyes, avatar.mouth, avatar.body]
	if first == second:
		push_error("不同 id 应换一张脸")
		quit(1)
		return
	avatar.apply_id(1)
	if [avatar.face, avatar.hair, avatar.eyes, avatar.mouth, avatar.body] != first:
		push_error("同一 id 头像应稳定")
		quit(1)
		return
	var columns := {}
	for character_id in 36:
		avatar.apply_id(character_id + 1)
		columns[avatar.face] = true
		columns[avatar.hair] = true
		columns[avatar.body] = true
	if columns.size() != avatar.variant_count():
		push_error("五官应能用上每一列，实际 %s" % columns.keys())
		quit(1)
		return
	avatar.face = 0
	avatar.hair = 1
	avatar.eyes = 2
	avatar.mouth = 3
	avatar.body = 1
	_export_sheet(avatar)
	print("pixel_avatar_test ok")
	quit(0)


func _range_hint_is(avatar: PixelAvatar, prop_name: String, max_index: int) -> bool:
	for prop in avatar.get_property_list():
		if prop.name != prop_name:
			continue
		if prop.hint != PROPERTY_HINT_RANGE or prop.hint_string != "0,%d,1" % max_index:
			push_error("%s range hint is %s" % [prop_name, prop.hint_string])
			return false
		return true
	push_error("missing property %s" % prop_name)
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
		push_error("failed to save preview %s" % error)
		quit(1)


func _blit_avatar(sheet: Image, source: Image, index: int, closed: bool, scale: int, origin_y: int) -> void:
	for part in PixelAvatar._DRAW_ORDER:
		var region_y := part * PixelAvatar.CELL
		var region_h := PixelAvatar.CELL
		var dest_y := 0
		if part == PixelAvatar.EYES_PART:
			region_h = PixelAvatar.HALF
			dest_y = PixelAvatar.EYE_TOP
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
