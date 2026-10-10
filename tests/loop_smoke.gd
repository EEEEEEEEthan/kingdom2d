extends SceneTree

func _init() -> void:
	var save := "user://save.dat"
	if FileAccess.file_exists(save):
		DirAccess.open("user://").remove(save.get_file())
	var game := (load("res://game/game.tscn") as PackedScene).instantiate() as Game
	root.add_child(game)
	call_deferred("_run", game)


func _run(game: Game) -> void:
	await process_frame
	game.reset_game()
	await process_frame
	var residents := game.character_manager.characters.size()
	var warehouses := 0
	for structure in game.structure_manager.index_to_structures:
		if structure is LoopStructure and (structure as LoopStructure).kind == LoopStructure.Kind.WAREHOUSE:
			warehouses += 1
	print("SMOKE_START residents=%d warehouses=%d" % [residents, warehouses])
	var center := Game.MAP_CELL_COUNT / 2
	var tent_cell := _empty_cell(game, center + 2)
	var camp_cell := _empty_cell(game, tent_cell + 2)
	var tent := StructureConfig.tent.instantiate() as LoopStructure
	game.structure_manager.add_structure(tent, tent_cell)
	tent.on_placed(game)
	var camp := StructureConfig.lumber_camp.instantiate() as LoopStructure
	game.structure_manager.add_structure(camp, camp_cell)
	var worker: Character = game.character_manager.characters.values()[0]
	worker.assign_duty(Character.Duty.LUMBER, camp.id)
	worker.set_process(false)
	var warehouse := _warehouse(game)
	var steps := 0
	while warehouse.logs < 3 and steps < 800:
		worker._process(0.2)
		steps += 1
	print("SMOKE_LOGS logs=%d steps=%d phase=%d carry=%d camp=%d cost=%d" % [warehouse.logs, steps, worker._duty_phase, worker.carrying_logs, camp.logs, StructureConfig.lumber_camp.build_cost_logs])
	var tent_b_cell := _empty_cell(game, center - 3)
	var guild_cell := _empty_cell(game, tent_b_cell - 2)
	var tent_b := StructureConfig.tent.instantiate() as LoopStructure
	game.structure_manager.add_structure(tent_b, tent_b_cell)
	tent_b.on_placed(game)
	var guild := StructureConfig.guild.instantiate() as LoopStructure
	game.structure_manager.add_structure(guild, guild_cell)
	var builder: Character
	for character in game.character_manager.characters.values():
		if character.duty == Character.Duty.NONE:
			builder = character
			break
	builder.assign_duty(Character.Duty.BUILDER, guild.id)
	builder.set_process(false)
	worker.set_process(false)
	steps = 0
	var hut := false
	while steps < 2000:
		worker._process(0.2)
		builder._process(0.2)
		steps += 1
		var at_cell := game.structure_manager.index_to_structures[tent_b_cell]
		if at_cell is LoopStructure and (at_cell as LoopStructure).kind == LoopStructure.Kind.HUT:
			hut = true
			break
	print("SMOKE_HUT hut=%s steps=%d warehouse=%d" % [hut, steps, warehouse.logs])
	quit(0 if residents == 0 and warehouses == 1 and warehouse.logs >= 0 and hut else 1)


func _empty_cell(game: Game, preferred: int) -> int:
	if game.structure_manager.index_to_structures[preferred] == null:
		return preferred
	for index in range(preferred, Game.MAP_CELL_COUNT):
		if game.structure_manager.index_to_structures[index] == null:
			return index
	return preferred


func _warehouse(game: Game) -> LoopStructure:
	for structure in game.structure_manager.index_to_structures:
		if structure is LoopStructure and (structure as LoopStructure).kind == LoopStructure.Kind.WAREHOUSE:
			return structure
	return null
