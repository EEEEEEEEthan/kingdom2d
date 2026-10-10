extends SceneTree

func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var game := (load("res://game/game.tscn") as PackedScene).instantiate() as Game
	root.add_child(game)
	await process_frame
	game._clear()
	GameBuilder.build(game)
	if game.character_manager.characters.size() != 0:
		push_error("开局居民应为 0，实际 %s" % game.character_manager.characters.size())
		quit(1)
		return
	var cell_index := -1
	for index in Game.MAP_CELL_COUNT:
		if not game.structure_manager.index_to_structures[index]:
			cell_index = index
			break
	var hut := StructureConfig.refugee_hut.instantiate() as Structure
	var texture := (hut.get_node("Sprite2D") as Sprite2D).texture
	if texture.get_width() != 14 or texture.get_height() != 10:
		push_error("帐篷贴图尺寸异常 %s" % texture.get_size())
		quit(1)
		return
	game.structure_manager.add_structure(hut, cell_index)
	var character := game.spawn_resident_at_cell(cell_index)
	if game.character_manager.characters.size() != 1:
		push_error("难民棚应带出 1 个居民")
		quit(1)
		return
	var expected_x: float = Game.get_position_by_cell_index(cell_index) + Game.HALF_TILE_SIZE
	if not is_equal_approx(character.position.x, expected_x):
		push_error("居民不在棚的格子上")
		quit(1)
		return
	print("refugee_hut_ok")
	quit(0)
