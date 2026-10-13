extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	load("res://game/game.gd")
	load("res://game/structures/builders_guild.gd")
	load("res://game/structures/sunken_floor_thatch_hovel.gd")
	load("res://game/characters/ai/tasks/character_ai_build_cycle_task.gd")
	var game = (load("res://game/game.tscn") as PackedScene).instantiate()
	root.add_child(game)
	await process_frame
	if not await _free_place_ok(game):
		quit(1)
		return
	if not await _paid_waits_builder_ok(game):
		quit(1)
		return
	print("structure_construction_ok")
	quit(0)


func _free_place_ok(game) -> bool:
	game._clear()
	await process_frame
	var cell := 50
	var placement: StructureBuildPlacement = await StructureBuildPlacement.new(game, StructureConfig.gatherer_hut)
	game.horizon.add_child(placement)
	for _i in 3:
		await process_frame
	placement._preview.cell_index = cell
	placement._try_place()
	await process_frame
	var hut := game.structure_manager.index_to_structures[cell] as GathererHut
	if hut == null:
		push_error("免费建筑放下后应存在")
		return false
	if not hut.is_built() or hut.level != 1 or hut.is_under_construction():
		push_error("免费建筑应即时升到 1 级，level=%s ordered=%s" % [hut.level, hut.construction_ordered])
		return false
	if not hut.get_node("Sprite2D").visible:
		push_error("完工后应显示建筑精灵")
		return false
	var hovel_cell := 52
	var home_place: StructureBuildPlacement = await StructureBuildPlacement.new(game, StructureConfig.sunken_floor_thatch_hovel)
	game.horizon.add_child(home_place)
	for _i in 3:
		await process_frame
	home_place._preview.cell_index = hovel_cell
	home_place._try_place()
	await process_frame
	var hovel := game.structure_manager.index_to_structures[hovel_cell] as SunkenFloorThatchHovel
	if hovel == null or not hovel.is_built():
		push_error("一级住房应免费即时完工")
		return false
	var resident_home := 0
	for character in game.character_manager.characters.values():
		if character.home_cell_index == hovel_cell:
			resident_home += 1
	if resident_home != 1:
		push_error("住房完工后应生成居民，实际 %s" % resident_home)
		return false
	return true


func _paid_waits_builder_ok(game) -> bool:
	game._clear()
	await process_frame
	var guild = StructureConfig.builders_guild.instantiate()
	var supply = StructureConfig.warehouse.instantiate() as Warehouse
	game.structure_manager.add_structure(guild, 100)
	game.structure_manager.add_structure(supply, 104)
	guild.begin_initial_upgrade()
	if not guild.is_built():
		push_error("建筑工会免费应即时完工")
		return false
	var builder = game.spawn_resident_at_cell(98)
	builder.set_process(false)
	_set_hour(game, 12)
	if builder.occupation_name() != "建筑工":
		push_error("应招到建筑工，实际 %s" % builder.occupation_name())
		return false
	var site_cell := 108
	var placement: StructureBuildPlacement = await StructureBuildPlacement.new(game, StructureConfig.warehouse)
	game.horizon.add_child(placement)
	for _i in 3:
		await process_frame
	placement._preview.cell_index = site_cell
	placement._try_place()
	await process_frame
	var site := game.structure_manager.index_to_structures[site_cell] as Warehouse
	if site == null or not site.is_under_construction() or site.level != 0:
		push_error("仓库应 0 级待建，level=%s ordered=%s" % [site.level if site else -1, site.construction_ordered if site else false])
		return false
	if site.get_node("Sprite2D").visible:
		push_error("未完工仓库不应显示本体")
		return false
	if site.get_node("Scaffold").visible:
		push_error("原木未到不应出现脚手架")
		return false
	if not _until([builder], 80, func() -> bool: return builder.current_activity() == "正在等待原木"):
		push_error("仓库没原木时应等待，活动 %s" % builder.current_activity())
		return false
	supply.container.add(ItemConfig.TypeId.LOG, StructureConfig.warehouse.build_log_cost)
	if not _until([builder], 400, func() -> bool: return site.builder_logs_ready() and site.get_node("Scaffold").visible):
		push_error("原木到齐应搭脚手架，仓 %s 工地 %s" % [supply.container.count_of(ItemConfig.TypeId.LOG), site.container.count_of(ItemConfig.TypeId.LOG)])
		return false
	if not _until([builder], 400, func() -> bool: return builder.current_activity() == "正在施工"):
		push_error("应开始施工，活动 %s 单元 %s" % [builder.current_activity(), site.construction_work_units])
		return false
	if not _until([builder], 600, func() -> bool: return site.is_built()):
		push_error("建筑工应建完仓库，level=%s units=%s" % [site.level, site.construction_work_units])
		return false
	if site.container.count_of(ItemConfig.TypeId.LOG) != 0:
		push_error("完工应消耗原木，剩余 %s" % site.container.count_of(ItemConfig.TypeId.LOG))
		return false
	if not site.get_node("Sprite2D").visible or site.get_node("Scaffold").visible:
		push_error("完工后应显示本体并拆脚手架")
		return false
	return true


func _until(people: Array, steps: int, done: Callable) -> bool:
	for _step in steps:
		for person in people:
			person._process(0.5)
		if done.call():
			return true
	return false


func _set_hour(game, hour: int) -> void:
	game.game_time.all_days = 8.0 + (float(hour) + 0.5) / 24.0
