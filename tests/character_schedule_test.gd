extends SceneTree

func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	load("res://game/game.gd")
	load("res://game/game_builder.gd")
	load("res://game/characters/character.gd")
	var game = (load("res://game/game.tscn") as PackedScene).instantiate()
	root.add_child(game)
	await process_frame
	game._clear()
	load("res://game/game_builder.gd").build(game)
	var character = game.spawn_resident_at_cell(10)
	character.set_process(false)
	_set_hour(game, 12)
	character._process(0.05)
	if not character.visible or character.indoors:
		push_error("白天应在外面")
		quit(1)
		return
	var home_x = character.position.x
	character.position.x = home_x + 24.0
	_set_hour(game, 20)
	character._process(0.05)
	if is_equal_approx(character.position.x, home_x):
		push_error("20:00 应先走向门口")
		quit(1)
		return
	character._process(10.0)
	character._process(0.05)
	if not character.indoors or character.visible:
		push_error("走到门口后应消失睡觉")
		quit(1)
		return
	if not is_equal_approx(character.position.x, home_x):
		push_error("睡觉位置应在家门口")
		quit(1)
		return
	_set_hour(game, 4)
	character._process(0.05)
	if not character.indoors:
		push_error("4:00 仍应在房间里")
		quit(1)
		return
	_set_hour(game, 5)
	character._process(0.05)
	if character.indoors or not character.visible:
		push_error("5:00 应出门")
		quit(1)
		return
	if not is_equal_approx(character.position.x, home_x):
		push_error("出门应出现在门口")
		quit(1)
		return
	var origin_x = character.position.x
	character._process(5.0)
	character._process(10.0)
	if is_equal_approx(character.position.x, origin_x):
		push_error("白天应随机移动")
		quit(1)
		return
	var data = character.serialize()
	var restored = game.spawn_resident_at_cell(3)
	restored.set_process(false)
	restored.deserialize(data)
	if restored.home_cell_index != 10:
		push_error("家的格子没有存下来")
		quit(1)
		return
	print("character_schedule_ok")
	quit(0)


func _set_hour(game, hour: int) -> void:
	game.game_time.all_days = 8.0 + float(hour) / 24.0
