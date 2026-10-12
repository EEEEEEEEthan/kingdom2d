extends SceneTree

func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var game := (load("res://game/game.tscn") as PackedScene).instantiate() as Game
	root.add_child(game)
	await process_frame
	game._clear()
	GameBuilder.build(game)
	if game.character_manager.characters.size() != 1:
		push_error("开局应有 1 个居民，实际 %s" % game.character_manager.characters.size())
		quit(1)
		return
	var manager: Character = game.character_manager.characters.values()[0]
	if manager.occupation_name() != "仓库管理员":
		push_error("开局居民应是仓库管理员，实际 %s" % manager.occupation_name())
		quit(1)
		return
	var cell_index := -1
	for index in Game.MAP_CELL_COUNT:
		if not game.structure_manager.index_to_structures[index]:
			cell_index = index
			break
	var hut := StructureConfig.sunken_floor_thatch_hovel.instantiate() as Structure
	var texture := (hut.get_node("Sprite2D") as Sprite2D).texture
	if texture.get_width() != 14 or texture.get_height() != 13:
		push_error("半穴茅舍贴图尺寸异常 %s" % texture.get_size())
		quit(1)
		return
	hut.queue_free()
	var placement: StructureBuildPlacement = await StructureBuildPlacement.new(game, StructureConfig.sunken_floor_thatch_hovel)
	game.horizon.add_child(placement)
	for _i in 5:
		await process_frame
	placement._preview.cell_index = cell_index
	placement._try_place()
	await process_frame
	var character: Character = null
	for resident in game.character_manager.characters.values():
		if resident.home_cell_index == cell_index:
			character = resident
			break
	if character == null:
		push_error("半穴茅舍应带出 1 个居民")
		quit(1)
		return
	var expected_x: float = Game.get_position_by_cell_index(cell_index) + Game.HALF_TILE_SIZE
	if not is_equal_approx(character.position.x, expected_x):
		push_error("居民不在茅舍的格子上")
		quit(1)
		return
	print("sunken_floor_thatch_hovel_ok")
	quit(0)
