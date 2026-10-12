extends SceneTree

func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	load("res://game/game.gd")
	var game = (load("res://game/game.tscn") as PackedScene).instantiate()
	root.add_child(game)
	await process_frame
	game._clear()
	await process_frame
	var character = game.spawn_resident_at_cell(10)
	character.set_process(false)
	var hut = StructureConfig.gatherer_hut.instantiate()
	game.structure_manager.add_structure(hut, 40)
	await process_frame
	var opened_character: Character = null
	var opened_hut: GathererHut = null
	game.character_open_requested.connect(func(who: Character) -> void: opened_character = who)
	game.gatherer_hut_open_requested.connect(func(who: GathererHut) -> void: opened_hut = who)
	var camera := game.get_node("Camera2D") as Camera2D
	camera.position_smoothing_enabled = false
	camera.position.x = character.position.x
	await process_frame
	var character_sprite := character.get_node("Sprite2D") as Sprite2D
	var hut_sprite := hut.get_node("Sprite2D") as Sprite2D
	var body := _opaque_local(character_sprite)
	var empty_beside := character_sprite.get_rect().position + Vector2(character_sprite.get_rect().size.x + 3.0, character_sprite.get_rect().size.y * 0.5)
	_point(character_sprite, body)
	if game._character_under_mouse() != character or HoverOutline.hovered_host() != character:
		push_error("不透明身体应同时描边并点选角色")
		quit(1)
		return
	_click(game)
	if opened_character != character:
		push_error("点在能描边的角色上应打开角色窗")
		quit(1)
		return
	opened_character = null
	_point(character_sprite, empty_beside)
	if game._character_under_mouse() != null or HoverOutline.hovered_host() == character:
		push_error("身体旁边的空地不该描边，也不该打开角色窗")
		quit(1)
		return
	_click(game)
	if opened_character != null:
		push_error("空地点击不该打开角色窗")
		quit(1)
		return
	camera.position.x = hut.position.x
	await process_frame
	var hut_body := _opaque_local(hut_sprite)
	var hut_beside := hut_sprite.get_rect().position + Vector2(hut_sprite.get_rect().size.x + 4.0, hut_sprite.get_rect().size.y * 0.5)
	_point(hut_sprite, hut_body)
	if game._gatherer_hut_under_mouse() != hut or HoverOutline.hovered_host() != hut:
		push_error("不透明小屋应同时描边并点选")
		quit(1)
		return
	_click(game)
	if opened_hut != hut:
		push_error("点在能描边的采集小屋上应打开小屋窗")
		quit(1)
		return
	opened_hut = null
	_point(hut_sprite, hut_beside)
	if game._gatherer_hut_under_mouse() != null:
		push_error("小屋旁边空地不该打开小屋窗")
		quit(1)
		return
	print("click_matches_outline_ok")
	quit(0)


func _opaque_local(sprite: Sprite2D) -> Vector2:
	var rect := sprite.get_rect()
	var image := sprite.texture.get_image()
	if sprite.texture is CanvasTexture:
		image = (sprite.texture as CanvasTexture).diffuse_texture.get_image()
	for y in image.get_height():
		for x in image.get_width():
			if image.get_pixel(x, y).a > 0.001:
				var unit := Vector2((float(x) + 0.5) / float(image.get_width()), (float(y) + 0.5) / float(image.get_height()))
				return rect.position + rect.size * unit
	push_error("精灵没有不透明像素")
	return rect.get_center()


func _point(sprite: Sprite2D, local: Vector2) -> void:
	var world: Vector2 = sprite.to_global(local)
	var viewport := sprite.get_viewport()
	var screen: Vector2 = viewport.get_canvas_transform() * world
	viewport.warp_mouse(Vector2i(screen.round()))


func _click(game: Node) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	event.position = game.get_viewport().get_mouse_position()
	game._input(event)
	if not event.is_echo():
		game._unhandled_input(event)
