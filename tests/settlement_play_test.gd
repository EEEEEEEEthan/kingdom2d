extends SceneTree

## 在真正的 Game 场景里把最小循环跑完：帐篷来人、伐木进仓库、工会一份一份把帐篷敲成小木屋。

func _init() -> void:
	call_deferred("_go")


func _go() -> void:
	var failed := 0
	if FileAccess.file_exists(Game.SAVE_FILE_PATH):
		DirAccess.open("user://").remove(Game.SAVE_FILE_PATH.get_file())
	var game := (load("res://game/game.tscn") as PackedScene).instantiate() as Game
	root.add_child(game)
	game.game_time.all_days = 8.0 / 24.0
	var before := game.character_manager.characters.size()
	var tent_cell := _empty_cell(game, 30)
	var camp_cell := _empty_cell(game, tent_cell + 2)
	var tent := _place(game, StructureConfig.tent, tent_cell) as WorkSite
	if game.character_manager.characters.size() != before + 1 or tent.resident_id <= 0:
		print("失败 帐篷没有带来居民")
		quit(1)
		return
	var resident := game.character_manager.characters[tent.resident_id] as Character
	resident.move_speed_pixels_per_second = 100000.0
	var camp := _place(game, StructureConfig.lumber_camp, camp_cell) as WorkSite
	resident.assign_job(camp.id)
	if not _pump_until(game, resident, func() -> bool:
		return _wood(game) >= 1):
		print("失败 原木没有进仓库")
		quit(1)
		return
	var trees_after := _count(game, StructureConfig.TypeId.OAK)
	var second_cell := _empty_cell(game, camp_cell + 2)
	var second := _place(game, StructureConfig.tent, second_cell) as WorkSite
	if second.resident_id <= 0:
		print("失败 第二顶帐篷没有来人")
		quit(1)
		return
	var builder := game.character_manager.characters[second.resident_id] as Character
	builder.move_speed_pixels_per_second = 100000.0
	var guild := _place(game, StructureConfig.builders_guild, _empty_cell(game, second_cell + 2)) as WorkSite
	builder.assign_job(guild.id)
	tent.order_cabin()
	if not _pump_until(game, builder, func() -> bool:
		resident._process(1.0)
		return tent.config.id == StructureConfig.TypeId.WOOD_CABIN):
		print("失败 帐篷没有被敲成小木屋 进度 %d" % tent.material_remaining)
		quit(1)
		return
	if _count(game, StructureConfig.TypeId.OAK) != trees_after:
		print("失败 伐木砍掉了树")
		quit(1)
		return
	if _wood(game) < 0:
		print("失败 仓库原木为负")
		quit(1)
		return
	print("通过 主场景最小循环 仓库原木 %d" % _wood(game))
	quit(0)


func _place(game: Game, config: StructureConfig, cell: int) -> Structure:
	var structure := config.instantiate() as Structure
	game.structure_manager.add_structure(structure, cell)
	if structure.has_method("on_player_placed"):
		structure.on_player_placed(game)
	return structure


func _empty_cell(game: Game, start: int) -> int:
	var cell := start
	while game.structure_manager.index_to_structures[cell]:
		cell += 1
	return cell


func _wood(game: Game) -> int:
	var total := 0
	for structure in game.structure_manager.index_to_structures:
		if structure is WorkSite and (structure as WorkSite).kind == WorkSite.Kind.WAREHOUSE and (structure as WorkSite).stock:
			total += (structure as WorkSite).stock.amount(LogisticsUnit.ITEM_WOOD)
	return total


func _count(game: Game, type_id: StructureConfig.TypeId) -> int:
	var total := 0
	for structure in game.structure_manager.index_to_structures:
		if structure and structure.config and structure.config.id == type_id:
			total += 1
	return total


func _pump_until(game: Game, worker: Character, done: Callable) -> bool:
	for _step in 80:
		if done.call():
			return true
		worker._process(1.0)
		game.game_time.all_days = 8.0 / 24.0
	return done.call()
