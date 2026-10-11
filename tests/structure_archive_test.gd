extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_remove_save()
	var game := (load("res://game/game.tscn") as PackedScene).instantiate() as Game
	root.add_child(game)
	await process_frame
	game._clear()
	await process_frame
	GameBuilder.build(game)
	await process_frame

	var cell_index := -1
	for index in Game.MAP_CELL_COUNT:
		if not game.structure_manager.index_to_structures[index]:
			cell_index = index
			break
	var placement: StructureBuildPlacement = await StructureBuildPlacement.new(game, StructureConfig.gatherer_hut)
	game.horizon.add_child(placement)
	for _i in 5:
		await process_frame
	placement._preview.cell_index = cell_index
	placement._try_place()
	await process_frame

	if not game.structure_manager.index_to_structures[cell_index] is GathererHut:
		push_error("建造完成后建筑应存在于世界中")
		quit(1)
		return

	game.queue_free()
	await process_frame

	var reloaded := (load("res://game/game.tscn") as PackedScene).instantiate() as Game
	root.add_child(reloaded)
	await process_frame
	if not reloaded.structure_manager.index_to_structures[cell_index] is GathererHut:
		push_error("建造完成后应存档：重载后新建筑丢失")
		quit(1)
		return
	print("structure_archive_ok")
	quit(0)


func _remove_save() -> void:
	if FileAccess.file_exists(Game.SAVE_FILE_PATH):
		DirAccess.open("user://").remove(Game.SAVE_FILE_PATH.get_file())
