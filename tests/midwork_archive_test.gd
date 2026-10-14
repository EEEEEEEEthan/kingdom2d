extends SceneTree

## 采集、伐木停在占住植物的阶段，施工停在已预留原木的搬运阶段，整档重开后这些状态还在。


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_remove_save()
	_write_empty_save()
	var game := _open_game()
	await process_frame
	game._clear()
	await process_frame
	game.set_process(false)
	var world := _place(game)
	_set_hour(game, 12)
	var gatherer: Character = world["gatherer"]
	var lumberjack: Character = world["lumberjack"]
	var builder: Character = world["builder"]
	if not _jobs_ok(game, world):
		quit(1)
		return
	if not _until(gatherer, 200, func() -> bool: return _occupied_shake(game, gatherer, StructureConfig.TypeId.BUSH)):
		push_error("采集者应停在占住灌木的阶段，活动 %s 阶段 %s" % [gatherer.current_activity(), _phase(gatherer)])
		quit(1)
		return
	if not _until(lumberjack, 200, func() -> bool: return _occupied_shake(game, lumberjack, StructureConfig.TypeId.OAK)):
		push_error("伐木工应停在占住橡树的阶段，活动 %s 阶段 %s" % [lumberjack.current_activity(), _phase(lumberjack)])
		quit(1)
		return
	var hovel: SunkenFloorThatchHovel = world["hovel"]
	if not _until(builder, 240, func() -> bool: return _logs_reserved(builder, hovel)):
		push_error("建筑工应停在已预留原木的阶段，活动 %s 阶段 %s 携带 %s 在途 %s" % [builder.current_activity(), _phase(builder), builder.carried_items.count_of(ItemConfig.TypeId.LOG), hovel.logs_inbound])
		quit(1)
		return
	var before := _snapshot(game)
	game.save_game()
	_close(game)
	var loaded := _open_game(true)
	var mismatch := _mismatch(before, _snapshot(loaded))
	if mismatch != "":
		push_error("整档读写不一致：%s" % mismatch)
		quit(1)
		return
	print("midwork_archive_ok %s" % _brief(before))
	_close(loaded)
	quit(0)


func _place(game: Game) -> Dictionary:
	var hut := StructureConfig.gatherer_hut.instantiate()
	var bush := StructureConfig.bush.instantiate()
	var camp := StructureConfig.lumber_camp.instantiate()
	var oak := StructureConfig.oak.instantiate()
	var guild := StructureConfig.builders_guild.instantiate()
	var hovel := StructureConfig.sunken_floor_thatch_hovel.instantiate() as SunkenFloorThatchHovel
	var warehouse := StructureConfig.warehouse.instantiate() as Warehouse
	game.structure_manager.add_structure(hut, 40)
	game.structure_manager.add_structure(bush, 52)
	game.structure_manager.add_structure(camp, 140)
	game.structure_manager.add_structure(oak, 152)
	game.structure_manager.add_structure(guild, 240)
	game.structure_manager.add_structure(hovel, 248)
	game.structure_manager.add_structure(warehouse, 260)
	warehouse.container.add(ItemConfig.TypeId.LOG, SunkenFloorThatchHovel.LOG_COST)
	hovel.order_upgrade()
	var gatherer := game.spawn_resident_at_cell(38)
	var lumberjack := game.spawn_resident_at_cell(138)
	var builder := game.spawn_resident_at_cell(238)
	gatherer.set_process(false)
	lumberjack.set_process(false)
	builder.set_process(false)
	return {
		"hut": hut,
		"bush": bush,
		"camp": camp,
		"oak": oak,
		"guild": guild,
		"hovel": hovel,
		"gatherer": gatherer,
		"lumberjack": lumberjack,
		"builder": builder,
	}


func _jobs_ok(game: Game, world: Dictionary) -> bool:
	var gatherer: Character = world["gatherer"]
	var lumberjack: Character = world["lumberjack"]
	var builder: Character = world["builder"]
	var hut: Structure = world["hut"]
	var camp: Structure = world["camp"]
	var guild: Structure = world["guild"]
	if gatherer.workplace_structure_id() != hut.id or gatherer.occupation_name() != "采集者":
		push_error("家在小屋旁的居民应是采集者，实际 %s 岗位 %s" % [gatherer.occupation_name(), gatherer.workplace_structure_id()])
		return false
	if lumberjack.workplace_structure_id() != camp.id or lumberjack.occupation_name() != "伐木工":
		push_error("家在营地旁的居民应是伐木工，实际 %s 岗位 %s" % [lumberjack.occupation_name(), lumberjack.workplace_structure_id()])
		return false
	if builder.workplace_structure_id() != guild.id or builder.occupation_name() != "建筑工":
		push_error("家在工会旁的居民应是建筑工，实际 %s 岗位 %s" % [builder.occupation_name(), builder.workplace_structure_id()])
		return false
	return true


func _occupied_shake(game: Game, person: Character, plant_type: int) -> bool:
	if _phase(person) != 3:
		return false
	return _plant_occupied_by(game, person.id, plant_type) != null


func _logs_reserved(builder: Character, hovel: SunkenFloorThatchHovel) -> bool:
	if _phase(builder) != CharacterAiBuildCycleTask._PHASE_HAUL:
		return false
	if builder.carried_items.count_of(ItemConfig.TypeId.LOG) <= 0 or hovel.logs_inbound <= 0:
		return false
	var top := builder.ai_task_stack.peek()
	if top == null:
		return false
	var payload: Dictionary = top.serialize()[CharacterAiTask._KEY_PAYLOAD]
	return int(payload.get(CharacterAiBuildCycleTask.KEY_RESERVED, 0)) > 0


func _snapshot(game: Game) -> Dictionary:
	var people: Array[Dictionary] = []
	var ids: Array[int] = []
	for character_id in game.character_manager.characters:
		ids.append(int(character_id))
	ids.sort()
	for character_id in ids:
		var character: Character = game.character_manager.characters[character_id]
		var carried := ""
		for item_id in character.carried_items.item_ids():
			if carried != "":
				carried += ","
			carried += "%s:%s" % [item_id, character.carried_items.count_of(item_id)]
		var reserved := 0
		var top := character.ai_task_stack.peek()
		if top != null:
			var payload: Dictionary = top.serialize()[CharacterAiTask._KEY_PAYLOAD]
			reserved = int(payload.get(CharacterAiBuildCycleTask.KEY_RESERVED, 0))
		people.append({
			"id": character.id,
			"depth": _stack_depth(character),
			"phase": _phase(character),
			"type_id": _type_id(character),
			"reserved": reserved,
			"workplace": game.employment.workplace_of(character.id),
			"occupation": character.occupation_name(),
			"carried": carried,
		})
	var occupants := ""
	var structure_ids: Array[int] = []
	for structure_id in game.structure_manager.structures:
		structure_ids.append(int(structure_id))
	structure_ids.sort()
	for structure_id in structure_ids:
		var occupant_id := game.structure_manager.occupant_of(structure_id)
		if occupant_id == 0:
			continue
		if occupants != "":
			occupants += ","
		occupants += "%s:%s" % [structure_id, occupant_id]
	var inbound := 0
	var workers := ""
	for structure_id in structure_ids:
		var structure := game.structure_manager.get_structure_by_id(structure_id)
		if structure is SunkenFloorThatchHovel and structure.config.id == StructureConfig.TypeId.SUNKEN_FLOOR_THATCH_HOVEL:
			inbound = (structure as SunkenFloorThatchHovel).logs_inbound
		if structure is GathererHut or structure is LumberCamp or structure is BuildersGuild:
			if workers != "":
				workers += ";"
			workers += "%s:%s" % [structure_id, _join_ids(game.employment.workers_of(structure_id))]
	return {
		"people": people,
		"occupants": occupants,
		"logs_inbound": inbound,
		"workers": workers,
	}


func _mismatch(before: Dictionary, after: Dictionary) -> String:
	for key in ["occupants", "logs_inbound", "workers"]:
		if str(before[key]) != str(after[key]):
			return "%s %s -> %s" % [key, before[key], after[key]]
	var before_people: Array = before["people"]
	var after_people: Array = after["people"]
	if before_people.size() != after_people.size():
		return "居民数量 %s -> %s" % [before_people.size(), after_people.size()]
	for index in before_people.size():
		var left: Dictionary = before_people[index]
		var right: Dictionary = after_people[index]
		for key in ["id", "depth", "phase", "type_id", "reserved", "workplace", "occupation", "carried"]:
			if str(left[key]) != str(right[key]):
				return "居民 %s %s %s -> %s" % [left["id"], key, left[key], right[key]]
	return ""


func _brief(snapshot: Dictionary) -> String:
	var parts := ""
	for person in snapshot["people"]:
		if parts != "":
			parts += " "
		parts += "%s:栈%s/阶段%s/岗%s/%s/物品[%s]/预留%s" % [person["occupation"], person["depth"], person["phase"], person["workplace"], person["id"], person["carried"], person["reserved"]]
	return "%s 占用[%s] 在途%s 编制[%s]" % [parts, snapshot["occupants"], snapshot["logs_inbound"], snapshot["workers"]]


func _stack_depth(character: Character) -> int:
	var stack: Dictionary = character.serialize()[Character._KEY_AI_TASK_STACK]
	return (stack.get(CharacterAiTaskStack._KEY_TASKS, []) as Array).size()


func _phase(character: Character) -> int:
	var top := character.ai_task_stack.peek()
	if top == null:
		return -1
	var payload: Dictionary = top.serialize()[CharacterAiTask._KEY_PAYLOAD]
	return int(payload.get(CharacterAiGatherCycleTask.KEY_PHASE, -1))


func _type_id(character: Character) -> int:
	var top := character.ai_task_stack.peek()
	if top == null:
		return -1
	return int(top.get_type_id())


func _plant_occupied_by(game: Game, character_id: int, plant_type: int) -> Structure:
	for structure in game.structure_manager.structures_of_type(plant_type):
		if game.structure_manager.occupant_of(structure.id) == character_id:
			return structure
	return null


func _join_ids(ids: Array[int]) -> String:
	var text := ""
	for character_id in ids:
		if text != "":
			text += ","
		text += str(character_id)
	return text


func _until(person: Character, steps: int, done: Callable) -> bool:
	for _step in steps:
		person._process(0.25)
		if done.call():
			return true
	return false


func _open_game(frozen := false) -> Game:
	var game := (load("res://game/game.tscn") as PackedScene).instantiate() as Game
	if frozen:
		game.process_mode = Node.PROCESS_MODE_DISABLED
	root.add_child(game)
	if frozen:
		game.set_process(false)
		for character in game.character_manager.characters.values():
			(character as Character).set_process(false)
	return game


func _close(game: Game) -> void:
	root.remove_child(game)
	game.free()


func _remove_save() -> void:
	if FileAccess.file_exists(Game.SAVE_FILE_PATH):
		DirAccess.open("user://").remove(Game.SAVE_FILE_PATH.get_file())


func _write_empty_save() -> void:
	var file := FileAccess.open(Game.SAVE_FILE_PATH, FileAccess.WRITE)
	file.store_var({
		Game._SERKEY_VERSION: Game.SAVE_VERSION,
		Game._SERKEY_STRUCTURE_MANAGER: {StructureManager._KEY_NEXT_ID: 0, StructureManager._KEY_STRUCTURES: []},
		Game._SERKEY_CHARACTER_MANAGER: {CharacterManager._KEY_NEXT_ID: 0, CharacterManager._KEY_CHARACTERS: []},
		Game._SERKEY_TERRAIN: {},
		Game._SERKEY_DAYS: 8.5,
		Game._SERKEY_EMPLOYMENT: {WorkplaceIndex._KEY_PAIRS: []},
	})
	file.close()


func _set_hour(game: Game, hour: int) -> void:
	game.game_time.all_days = 8.0 + (float(hour) + 0.5) / 24.0
