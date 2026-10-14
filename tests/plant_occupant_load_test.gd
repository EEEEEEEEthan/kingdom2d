extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	if FileAccess.file_exists(Game.SAVE_FILE_PATH):
		DirAccess.open("user://").remove(Game.SAVE_FILE_PATH.get_file())
	var game := (load("res://game/game.tscn") as PackedScene).instantiate() as Game
	root.add_child(game)
	await process_frame
	game._clear()
	await process_frame
	var center := Game.MAP_CELL_COUNT / 2
	var bush := StructureConfig.bush.instantiate() as Structure
	var oak := StructureConfig.oak.instantiate() as Structure
	if game.structure_manager.add_structure(bush, center - 4) != StructureManager.AddError.OK:
		push_error("灌木应能放下")
		quit(1)
		return
	if game.structure_manager.add_structure(oak, center + 4) != StructureManager.AddError.OK:
		push_error("橡树应能放下")
		quit(1)
		return
	var living := game.character_manager.create_character()
	living.position.x = Game.get_position_by_cell_index(center - 2) + Game.HALF_TILE_SIZE
	living.set_process(false)
	var gone := game.character_manager.create_character()
	var gone_id := gone.id
	game.structure_manager.mark_occupied(bush.id, living.id)
	game.structure_manager.mark_occupied(oak.id, gone_id)
	game.character_manager.characters.erase(gone_id)
	gone.get_parent().remove_child(gone)
	gone.free()
	var bush_id := bush.id
	var oak_id := oak.id
	var living_id := living.id
	game.save_game()
	game.load_game()
	if not game.character_manager.characters.has(living_id):
		push_error("活着的居民应还在")
		quit(1)
		return
	if game.character_manager.characters.has(gone_id):
		push_error("已删除的居民不应读回来")
		quit(1)
		return
	if game.structure_manager.occupant_of(bush_id) != living_id:
		push_error("活着的居民应继续占用灌木，实际 %s" % game.structure_manager.occupant_of(bush_id))
		quit(1)
		return
	if game.structure_manager.occupant_of(oak_id) != 0:
		push_error("指向已消失居民的橡树应解除占用，实际 %s" % game.structure_manager.occupant_of(oak_id))
		quit(1)
		return
	print("plant_occupant_load_ok")
	quit(0)
