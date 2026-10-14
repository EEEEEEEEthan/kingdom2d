extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	if FileAccess.file_exists(Game.SAVE_FILE_PATH):
		DirAccess.open("user://").remove(Game.SAVE_FILE_PATH.get_file())
	var file := FileAccess.open(Game.SAVE_FILE_PATH, FileAccess.WRITE)
	file.store_var({
		SaveFormat.SECTION_STRUCTURES: {
			StructureManager.KEY_NEXT_ID: 4,
			StructureManager.KEY_STRUCTURES: [
				{
					Structure.KEY_TYPE_ID: Structure.LEGACY_REFUGEE_SHELTER,
					Structure.KEY_INSTANCE_ID: 2,
					Structure.KEY_DATA: {},
					Structure.KEY_CELL_INDEX: 8,
					Structure.KEY_HP: 32,
				},
				{
					Structure.KEY_TYPE_ID: 99,
					Structure.KEY_INSTANCE_ID: 3,
					Structure.KEY_DATA: {},
					Structure.KEY_CELL_INDEX: 9,
					Structure.KEY_HP: 32,
				},
			],
		},
		SaveFormat.SECTION_TERRAIN: {},
		SaveFormat.SECTION_CHARACTERS: {},
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
	game.request_save()
	await process_frame
	var saved := FileAccess.open(Game.SAVE_FILE_PATH, FileAccess.READ).get_var() as Dictionary
	if int(saved.get(SaveFormat.SECTION_VERSION, 0)) != SaveFormat.VERSION:
		push_error("新存档应写存档号 %s，实际 %s" % [SaveFormat.VERSION, saved.get(SaveFormat.SECTION_VERSION, 0)])
		quit(1)
		return
	print("save_version_ok")
	quit(0)
