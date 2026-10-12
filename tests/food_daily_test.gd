extends SceneTree


func _initialize() -> void:
	load("res://game/game.gd")
	load("res://game/game_builder.gd")
	load("res://game/food.gd")
	load("res://game/items/item_config.gd")
	load("res://game/structures/structure_config.gd")
	load("res://game/structures/warehouse.gd")
	load("res://game/characters/character.gd")
	load("res://game/characters/ai/tasks/character_ai_fetch_food_task.gd")
	call_deferred("_run")


func _run() -> void:
	var game = (load("res://game/game.tscn") as PackedScene).instantiate()
	root.add_child(game)
	await process_frame
	game._clear()
	load("res://game/game_builder.gd").build(game)
	if not await _skip_when_no_stock(game):
		quit(1)
		return
	if not await _takes_from_nearest(game):
		quit(1)
		return
	if not await _full_pantry_skips_trip(game):
		quit(1)
		return
	if not await _once_per_day(game):
		quit(1)
		return
	print("food_daily_ok")
	quit(0)


func _skip_when_no_stock(game) -> bool:
	var home = await _place_home(game, 40)
	var character = game.spawn_resident_at_cell(40)
	character.set_process(false)
	home.container.add(ItemConfig.TypeId.BERRY, 7)
	await _clear_cell(game, 48)
	var empty_warehouse = StructureConfig.warehouse.instantiate()
	game.structure_manager.add_structure(empty_warehouse, 48)
	var origin_x: float = character.position.x
	_set_hour(game, 22)
	character._process(0.05)
	if not is_equal_approx(character.position.x, origin_x):
		push_error("仓库没货不应出门")
		return false
	if Food.stored(home) != 2:
		push_error("没领到食物也应吃掉 5，实际 %s" % Food.stored(home))
		return false
	return true


func _takes_from_nearest(game) -> bool:
	var home = await _place_home(game, 80)
	var character = game.spawn_resident_at_cell(80)
	character.set_process(false)
	character.move_speed_pixels_per_second = 100000.0
	await _clear_cell(game, 100)
	await _clear_cell(game, 86)
	var far = StructureConfig.warehouse.instantiate()
	var near = StructureConfig.warehouse.instantiate()
	game.structure_manager.add_structure(far, 100)
	game.structure_manager.add_structure(near, 86)
	far.container.add(ItemConfig.TypeId.BERRY, 9)
	near.container.add(ItemConfig.TypeId.BERRY, 4)
	_set_hour(game, 12)
	character._process(0.05)
	_set_hour(game, 22)
	character._process(0.05)
	character._process(1.0)
	character._process(1.0)
	if near.berry_count() != 0:
		push_error("应领空最近仓库，实际 %s" % near.berry_count())
		return false
	if far.berry_count() != 9:
		push_error("更远的仓库不应被领，实际 %s" % far.berry_count())
		return false
	if Food.stored(home) != 0:
		push_error("领 4 再吃 5，住房应为 0，实际 %s" % Food.stored(home))
		return false
	if not character.carried_items.is_empty():
		push_error("食物应放进住房")
		return false
	return true


func _full_pantry_skips_trip(game) -> bool:
	var home = await _place_home(game, 120)
	var character = game.spawn_resident_at_cell(120)
	character.set_process(false)
	home.container.add(ItemConfig.TypeId.BERRY, Food.HOME_CAPACITY)
	await _clear_cell(game, 130)
	var warehouse = StructureConfig.warehouse.instantiate()
	game.structure_manager.add_structure(warehouse, 130)
	warehouse.container.add(ItemConfig.TypeId.BERRY, 6)
	var origin_x: float = character.position.x
	_set_hour(game, 22)
	character._process(0.05)
	if not is_equal_approx(character.position.x, origin_x):
		push_error("住房已满不应去仓库")
		return false
	if warehouse.berry_count() != 6 or Food.stored(home) != 5:
		push_error("满仓只吃饭，住房 %s 仓库 %s" % [Food.stored(home), warehouse.berry_count()])
		return false
	return true


func _once_per_day(game) -> bool:
	var home = await _place_home(game, 150)
	var character = game.spawn_resident_at_cell(150)
	character.set_process(false)
	home.container.add(ItemConfig.TypeId.BERRY, 10)
	_set_hour(game, 22)
	character._process(0.05)
	if Food.stored(home) != 5:
		push_error("第一顿应剩 5，实际 %s" % Food.stored(home))
		return false
	character._process(0.05)
	if Food.stored(home) != 5:
		push_error("同一天不应再吃，实际 %s" % Food.stored(home))
		return false
	var data = character.serialize()
	await _clear_cell(game, 151)
	var restored = game.spawn_resident_at_cell(151)
	restored.set_process(false)
	restored.deserialize(data)
	restored._process(0.05)
	if Food.stored(home) != 5:
		push_error("读档后同一天不应再吃，实际 %s" % Food.stored(home))
		return false
	return true


func _clear_cell(game, cell: int) -> void:
	var existing = game.structure_manager.index_to_structures[cell]
	if existing:
		existing.free()
		await process_frame


func _place_home(game, cell: int):
	await _clear_cell(game, cell)
	var home = StructureConfig.sunken_floor_thatch_hovel.instantiate()
	game.structure_manager.add_structure(home, cell)
	return home


func _set_hour(game, hour: int) -> void:
	game.game_time.all_days = 8.0 + (float(hour) + 0.5) / 24.0
