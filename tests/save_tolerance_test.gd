extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	if not await _partial_save_keeps_file():
		quit(1)
		return
	if not await _unreadable_save_keeps_file():
		quit(1)
		return
	print("save_tolerance_ok")
	quit(0)


func _partial_save_keeps_file() -> bool:
	_remove_save()
	var file := FileAccess.open(Game.SAVE_FILE_PATH, FileAccess.WRITE)
	file.store_var({
		SaveFormat.SECTION_STRUCTURES: {
			StructureManager.KEY_STRUCTURES: [{
				Structure.KEY_TYPE_ID: StructureConfig.TypeId.SUNKEN_FLOOR_THATCH_HOVEL,
				Structure.KEY_INSTANCE_ID: 2,
				Structure.KEY_CELL_INDEX: 8,
			}],
		},
		SaveFormat.SECTION_CHARACTERS: {
			CharacterManager.KEY_CHARACTERS: [{
				Character.KEY_ID: 3,
				Character.KEY_AI_TASK_STACK: {
					CharacterAiTaskStack.KEY_TASKS: [
						{
							CharacterAiTask.KEY_TYPE_ID: CharacterAiTaskTypeId.TypeId.MOVE_TO_WORLD_X,
							CharacterAiTask.KEY_PAYLOAD: {CharacterAiMoveToWorldXTask.KEY_TARGET_WORLD_X: 40},
						},
						{
							CharacterAiTask.KEY_TYPE_ID: 99,
							CharacterAiTask.KEY_PAYLOAD: {"keep": true},
						},
						{
							CharacterAiTask.KEY_TYPE_ID: CharacterAiTaskTypeId.TypeId.MOVE_TO_WORLD_X,
							CharacterAiTask.KEY_PAYLOAD: {},
						},
					],
				},
			}],
		},
	})
	file.close()
	var original := FileAccess.get_file_as_bytes(Game.SAVE_FILE_PATH)
	var game := (load("res://game/game.tscn") as PackedScene).instantiate() as Game
	root.add_child(game)
	var person: Character = game.character_manager.characters.get(3)
	if person == null:
		push_error("角色应读入")
		return false
	person.set_process(false)
	await process_frame
	if FileAccess.get_file_as_bytes(Game.SAVE_FILE_PATH) != original:
		push_error("缺键读档不应改写原档")
		return false
	var home: Structure = game.structure_manager.index_to_structures[8]
	if home == null or home.config.id != StructureConfig.TypeId.SUNKEN_FLOOR_THATCH_HOVEL:
		push_error("缺字段的茅舍应读入")
		return false
	var top := person.ai_task_stack.peek()
	if top == null or top.get_type_id() != CharacterAiTaskTypeId.TypeId.MOVE_TO_WORLD_X:
		push_error("缺目标的移动任务应跳过，完整的应留下")
		return false
	if not _task_types(person).has(99):
		push_error("未知任务类型应留在档数据里")
		return false
	var bush := StructureConfig.bush.instantiate() as Structure
	if game.structure_manager.add_structure(bush, 20) != StructureManager.AddError.OK or bush.id != 3:
		push_error("缺 next id 时应从已有 id 往后排，实际 %s" % bush.id)
		return false
	var created := game.character_manager.create_character()
	if created.id != 4:
		push_error("缺角色 next id 时应从已有 id 往后排，实际 %s" % created.id)
		return false
	game.request_save()
	await process_frame
	if not _saved_file_has_unknown_task():
		push_error("再次写盘仍应保留未知任务")
		return false
	game.queue_free()
	await process_frame
	return true


func _unreadable_save_keeps_file() -> bool:
	_remove_save()
	var file := FileAccess.open(Game.SAVE_FILE_PATH, FileAccess.WRITE)
	file.store_var("not-a-save")
	file.close()
	var original := FileAccess.get_file_as_bytes(Game.SAVE_FILE_PATH)
	var game := (load("res://game/game.tscn") as PackedScene).instantiate() as Game
	root.add_child(game)
	await process_frame
	if FileAccess.get_file_as_bytes(Game.SAVE_FILE_PATH) != original:
		push_error("整档读失败不应覆盖原档")
		return false
	var center := Game.MAP_CELL_COUNT / 2
	if game.structure_manager.index_to_structures[center] == null:
		push_error("坏档时内存里应另开一局")
		return false
	game.free()
	return true


func _task_types(person: Character) -> Array:
	var types: Array = []
	var tasks: Array = person.ai_task_stack.serialize()[CharacterAiTaskStack.KEY_TASKS]
	for task in tasks:
		types.append(int(task[CharacterAiTask.KEY_TYPE_ID]))
	return types


func _saved_file_has_unknown_task() -> bool:
	var saved := FileAccess.open(Game.SAVE_FILE_PATH, FileAccess.READ).get_var() as Dictionary
	var characters: Dictionary = saved.get(SaveFormat.SECTION_CHARACTERS, {})
	for item in characters.get(CharacterManager.KEY_CHARACTERS, []):
		if not item is Dictionary:
			continue
		var stack: Dictionary = item.get(Character.KEY_AI_TASK_STACK, {})
		for task in stack.get(CharacterAiTaskStack.KEY_TASKS, []):
			if task is Dictionary and int(task.get(CharacterAiTask.KEY_TYPE_ID, 0)) == 99:
				return true
	return false


func _remove_save() -> void:
	if FileAccess.file_exists(Game.SAVE_FILE_PATH):
		DirAccess.open("user://").remove(Game.SAVE_FILE_PATH.get_file())
