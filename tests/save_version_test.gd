extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	if FileAccess.file_exists(Game.SAVE_FILE_PATH):
		DirAccess.open("user://").remove(Game.SAVE_FILE_PATH.get_file())
	var file := FileAccess.open(Game.SAVE_FILE_PATH, FileAccess.WRITE)
	file.store_var({
		1: {
			1: 4,
			2: [
				{1: 7, 2: 2, 3: {}, 4: 8, 5: 32},
				{1: 99, 2: 3, 3: {}, 4: 9, 5: 32},
			],
		},
		3: {},
		2: {},
	})
	file.close()
	var game := (load("res://game/game.tscn") as PackedScene).instantiate() as Game
	root.add_child(game)
	await process_frame
	var home: Structure = game.structure_manager.index_to_structures[8]
	if home == null or home.config.id != StructureConfig.TypeId.SUNKEN_FLOOR_THATCH_HOVEL:
		push_error("旧档难民棚应读成半穴茅舍")
		quit(1)
		return
	if game.structure_manager.index_to_structures[9] != null:
		push_error("未知建筑应跳过")
		quit(1)
		return
	if game.structure_manager.get_structure_by_id(3) != null:
		push_error("未知建筑不应登记")
		quit(1)
		return
	game.save_game()
	var saved := FileAccess.open(Game.SAVE_FILE_PATH, FileAccess.READ).get_var() as Dictionary
	if int(saved.get(6, 0)) != Game.SAVE_VERSION:
		push_error("新存档应写存档号 %s，实际 %s" % [Game.SAVE_VERSION, saved.get(6, 0)])
		quit(1)
		return
	print("save_version_ok")
	quit(0)
