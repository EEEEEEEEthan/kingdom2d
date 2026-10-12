extends SceneTree

const _OUTLINE := preload("res://game/hover_outline.gd")

func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	load("res://game/game.gd")
	load("res://game/characters/character.gd")
	load("res://game/structures/gatherer_hut.gd")
	load("res://game/structures/structure_config.gd")
	var game = (load("res://game/game.tscn") as PackedScene).instantiate()
	root.add_child(game)
	await process_frame
	game._clear()
	await process_frame
	var character = game.spawn_resident_at_cell(10)
	character.set_process(false)
	var hut = load("res://game/structures/structure_config.gd").gatherer_hut.instantiate()
	game.structure_manager.add_structure(hut, 40)
	await process_frame
	var opened_character := [null]
	var opened_hut := [null]
	game.character_open_requested.connect(func(who) -> void: opened_character[0] = who)
	game.gatherer_hut_open_requested.connect(func(who) -> void: opened_hut[0] = who)
	var camera := game.get_node("Camera2D") as Camera2D
	camera.position_smoothing_enabled = false
	camera.position.x = character.position.x
	await process_frame
	var character_sprite := character.get_node("Sprite2D") as Sprite2D
	var hut_sprite := hut.get_node("Sprite2D") as Sprite2D
	var body := _opaque_local(character_sprite)
	var empty_beside := character_sprite.get_rect().position + Vector2(character_sprite.get_rect().size.x + 3.0, character_sprite.get_rect().size.y * 0.5)
	await _point(character_sprite, body)
	if game._character_under_mouse() != character or _OUTLINE.hovered_host() != character:
		push_error("不透明身体应同时描边并点选角色，实际 %s" % _OUTLINE.hovered_host())
		quit(1)
		return
	_click(game)
	if opened_character[0] != null:
		push_error("按下时不该打开角色窗")
		quit(1)
		return
	_release(game)
	if opened_character[0] != character:
		push_error("点在能描边的角色上应打开角色窗")
		quit(1)
		return
	opened_character[0] = null
	await _point(character_sprite, empty_beside)
	if game._character_under_mouse() != null or _OUTLINE.hovered_host() == character:
		push_error("身体旁边的空地不该描边，也不该打开角色窗")
		quit(1)
		return
	_click(game)
	_release(game)
	if opened_character[0] != null:
		push_error("空地点击不该打开角色窗")
		quit(1)
		return
	camera.position.x = hut.position.x
	await process_frame
	var hut_body := _opaque_local(hut_sprite)
	var hut_beside := hut_sprite.get_rect().position + Vector2(hut_sprite.get_rect().size.x + 4.0, hut_sprite.get_rect().size.y * 0.5)
	await _point(hut_sprite, hut_body)
	if game._structure_under_mouse() != hut or _OUTLINE.hovered_host() != hut:
		push_error("不透明小屋应同时描边并点选")
		quit(1)
		return
	_click(game)
	if opened_hut[0] != null:
		push_error("按下时不该打开小屋窗")
		quit(1)
		return
	_release(game)
	if opened_hut[0] != hut:
		push_error("点在能描边的采集小屋上应打开小屋窗")
		quit(1)
		return
	opened_hut[0] = null
	await _point(hut_sprite, hut_beside)
	if game._structure_under_mouse() != null:
		push_error("小屋旁边空地不该打开小屋窗")
		quit(1)
		return
	_click(game)
	_release(game)
	if opened_hut[0] != null:
		push_error("空地点击不该打开小屋窗")
		quit(1)
		return
	await _point(hut_sprite, hut_body)
	_click(game)
	var drag := InputEventMouseMotion.new()
	var dragged: Vector2 = game.get_viewport().get_mouse_position() + Vector2(24, 0)
	drag.position = dragged
	drag.global_position = dragged
	Input.parse_input_event(drag)
	await process_frame
	_release_at(game, dragged)
	if opened_hut[0] != null:
		push_error("拖拽松开不该打开小屋窗")
		quit(1)
		return
	print("click_matches_outline_ok")
	quit(0)


func _opaque_local(sprite: Sprite2D) -> Vector2:
	var rect := sprite.get_rect()
	var image: Image = _OUTLINE._image_of(sprite.texture)
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
	var motion := InputEventMouseMotion.new()
	motion.position = screen
	motion.global_position = screen
	Input.parse_input_event(motion)
	await sprite.get_tree().process_frame


func _click(game: Node) -> void:
	_button(game, true, game.get_viewport().get_mouse_position())


func _release(game: Node) -> void:
	_release_at(game, game.get_viewport().get_mouse_position())


func _release_at(game: Node, position: Vector2) -> void:
	_button(game, false, position)


func _button(game: Node, pressed: bool, position: Vector2) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	event.position = position
	game._input(event)
