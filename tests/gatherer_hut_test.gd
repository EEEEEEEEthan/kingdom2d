extends SceneTree

func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	load("res://game/game.gd")
	load("res://game/game_builder.gd")
	load("res://game/structures/gatherer_hut.gd")
	load("res://game/characters/ai/tasks/character_ai_gather_cycle_task.gd")
	var game = (load("res://game/game.tscn") as PackedScene).instantiate()
	root.add_child(game)
	await process_frame
	game._clear()
	load("res://game/game_builder.gd").build(game)
	var hut_cell := -1
	var bush_cell := -1
	var previous_empty := -1
	for cell_index in Game.MAP_CELL_COUNT:
		if game.structure_manager.index_to_structures[cell_index]:
			continue
		if previous_empty >= 0 and cell_index - previous_empty <= 12 and cell_index > 16:
			hut_cell = previous_empty
			bush_cell = cell_index
			break
		previous_empty = cell_index
	var hut = StructureConfig.gatherer_hut.instantiate()
	game.structure_manager.add_structure(hut, hut_cell)
	var bush = StructureConfig.bush.instantiate()
	game.structure_manager.add_structure(bush, bush_cell)
	var gatherer = game.spawn_resident_at_cell(hut_cell - 8)
	var bystander = game.spawn_resident_at_cell(32)
	gatherer.set_process(false)
	bystander.set_process(false)
	_set_hour(game, 12)
	if not hut.try_assign_unemployed():
		push_error("应能安排无职业居民")
		quit(1)
		return
	if gatherer.workplace_structure_id != hut.id:
		push_error("第一个居民应成为采集者")
		quit(1)
		return
	if not hut.try_assign_unemployed():
		push_error("第二个空位应还能加人")
		quit(1)
		return
	if bystander.workplace_structure_id != hut.id:
		push_error("第二个居民应入职")
		quit(1)
		return
	if hut.try_assign_unemployed():
		push_error("没有空位或没有无职业居民时不应再加人")
		quit(1)
		return
	bystander.workplace_structure_id = 0
	hut.worker_ids.resize(1)
	var hut_x = Game.get_position_by_cell_index(hut_cell) + Game.HALF_TILE_SIZE
	var nearest_bush: Structure = bush
	var nearest_distance := absi(bush_cell - hut_cell)
	for structure in game.structure_manager.index_to_structures:
		if not structure or structure.config.id != StructureConfig.TypeId.BUSH:
			continue
		var distance := absi(structure.cell_index - hut_cell)
		if distance < nearest_distance:
			nearest_bush = structure
			nearest_distance = distance
	bush = nearest_bush
	var bush_x = Game.get_position_by_cell_index(bush.cell_index) + Game.HALF_TILE_SIZE
	var saw_hut := false
	var saw_bush := false
	for _step in 400:
		gatherer._process(0.5)
		if is_equal_approx(gatherer.position.x, hut_x):
			saw_hut = true
		if is_equal_approx(gatherer.position.x, bush_x):
			saw_bush = true
			break
	if not saw_hut or not saw_bush:
		push_error("应先到小屋再到灌木 hut=%s bush=%s x=%s" % [saw_hut, saw_bush, gatherer.position.x])
		quit(1)
		return
	await process_frame
	await process_frame
	if is_zero_approx(bush.rotation):
		push_error("灌木应抖动")
		quit(1)
		return
	var bush_id = bush.id
	_set_hour(game, 20)
	gatherer._process(0.2)
	if gatherer.indoors or not is_equal_approx(gatherer.position.x, bush_x):
		push_error("采集途中到点也不应回家")
		quit(1)
		return
	for _step in 400:
		gatherer._process(0.5)
		if gatherer.indoors:
			break
	if not gatherer.indoors:
		push_error("一轮结束后应回家")
		quit(1)
		return
	if game.structure_manager.get_structure_by_id(bush_id) != bush:
		push_error("灌木不应消失")
		quit(1)
		return
	var restored = StructureConfig.gatherer_hut.instantiate()
	restored._deserialize(hut._serialize())
	if restored.worker_ids.size() != 1 or restored.worker_ids[0] != gatherer.id:
		push_error("员工列表应存档")
		quit(1)
		return
	print("gatherer_hut_ok")
	quit(0)


func _set_hour(game, hour: int) -> void:
	game.game_time.all_days = 8.0 + float(hour) / 24.0
