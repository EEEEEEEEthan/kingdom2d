extends SceneTree

func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	load("res://game/game.gd")
	load("res://game/game_builder.gd")
	load("res://game/structures/lumber_camp.gd")
	load("res://game/characters/ai/tasks/character_ai_log_cycle_task.gd")
	if not _log_icon_ok():
		quit(1)
		return
	var game = (load("res://game/game.tscn") as PackedScene).instantiate()
	root.add_child(game)
	await process_frame
	game._clear()
	await process_frame
	load("res://game/game_builder.gd").build(game)
	var camp_cell := -1
	var oak_cell := -1
	var previous_empty := -1
	for cell_index in Game.MAP_CELL_COUNT:
		if game.structure_manager.index_to_structures[cell_index]:
			continue
		if previous_empty >= 0 and cell_index - previous_empty <= 12 and cell_index > 16:
			camp_cell = previous_empty
			oak_cell = cell_index
			break
		previous_empty = cell_index
	var lumberjack = game.spawn_resident_at_cell(camp_cell - 2)
	var near = game.spawn_resident_at_cell(camp_cell + 40)
	var bystander = game.spawn_resident_at_cell(camp_cell + 80)
	var camp = StructureConfig.lumber_camp.instantiate()
	game.structure_manager.add_structure(camp, camp_cell)
	var oak = StructureConfig.oak.instantiate()
	game.structure_manager.add_structure(oak, oak_cell)
	near.set_process(false)
	lumberjack.set_process(false)
	bystander.set_process(false)
	_set_hour(game, 12)
	if lumberjack.occupation_name() != "伐木工":
		push_error("入职伐木营地应是伐木工，实际 %s" % lumberjack.occupation_name())
		quit(1)
		return
	var workers: Array[int] = game.employment.workers_of(camp.id)
	if workers.size() != 2 or workers[0] != lumberjack.id or workers[1] != near.id:
		push_error("应自动优先安排家最近的居民 %s" % [workers])
		quit(1)
		return
	if bystander.workplace_structure_id() != 0:
		push_error("满员后不应再加人")
		quit(1)
		return
	game.employment.release(near.id)
	var camp_x = Game.get_position_by_cell_index(camp_cell) + Game.HALF_TILE_SIZE
	var saw_camp := false
	var oak_x := 0.0
	oak = null
	for _step in 400:
		lumberjack._process(0.5)
		if is_equal_approx(lumberjack.position.x, camp_x):
			saw_camp = true
		if oak == null:
			oak = _oak_occupied_by(game, lumberjack.id)
			if oak != null:
				oak_x = Game.get_position_by_cell_index(oak.cell_index) + Game.HALF_TILE_SIZE
		if oak != null and is_equal_approx(lumberjack.position.x, oak_x):
			break
	if not saw_camp or oak == null:
		push_error("应先到营地再到橡树 camp=%s oak=%s x=%s" % [saw_camp, oak, lumberjack.position.x])
		quit(1)
		return
	await process_frame
	await process_frame
	if is_zero_approx(oak.rotation):
		push_error("橡树应抖动")
		quit(1)
		return
	var oak_id = oak.id
	_set_hour(game, 19)
	lumberjack._process(0.2)
	if lumberjack.indoors or not is_equal_approx(lumberjack.position.x, oak_x):
		push_error("伐木途中到点也不应回家")
		quit(1)
		return
	for _step in 400:
		lumberjack._process(0.5)
		if camp.container.count_of(ItemConfig.TypeId.LOG) > 0:
			break
	if camp.log_count() != 1:
		push_error("一轮伐木应产出 1 原木，实际 %s" % camp.log_count())
		quit(1)
		return
	if lumberjack.indoors or not lumberjack.visible:
		push_error("工作段一轮结束后应留在屋外")
		quit(1)
		return
	lumberjack._process(0.05)
	var top = lumberjack.ai_task_stack.peek()
	if not top is CharacterAiLogCycleTask:
		push_error("工作段一轮结束后应继续伐木")
		quit(1)
		return
	_set_hour(game, 23)
	for _step in 400:
		lumberjack._process(0.5)
		if lumberjack.indoors:
			break
	if not lumberjack.indoors:
		push_error("睡眠段一轮结束后应回家")
		quit(1)
		return
	if game.structure_manager.occupant_of(oak_id) != 0:
		push_error("一轮结束后应释放橡树")
		quit(1)
		return
	if not _save_ok(game, camp):
		quit(1)
		return
	var browser = (load("res://game/info/info_browser.tscn") as PackedScene).instantiate()
	root.add_child(browser)
	browser.open_structure(camp)
	if browser.current_path() != "structure/%d" % camp.id:
		push_error("打开营地应落到 structure/id，实际 %s" % browser.current_path())
		quit(1)
		return
	var page = browser.get_node("%PageHost").get_child(0)
	var inventory = page.get_node("Rows/Inventory")
	if inventory.get_node("%Title").text != "容器 %d/%d" % [camp.log_count(), LumberCamp.LOG_CAPACITY]:
		push_error("营地窗口应显示原木容量，实际 %s" % inventory.get_node("%Title").text)
		quit(1)
		return
	var workplace = page.get_node("Rows/Workplace")
	if workplace.get_node("%Worker0").text != lumberjack.display_name():
		push_error("营地窗口应列出伐木工姓名，实际 %s" % workplace.get_node("%Worker0").text)
		quit(1)
		return
	if not _reservation_ok(game):
		quit(1)
		return
	if not _no_oak_ok(game):
		quit(1)
		return
	if not _log_cap_ok(game):
		quit(1)
		return
	if not _haul_ok(game):
		quit(1)
		return
	if not _warehouse_capacity_ok(game):
		quit(1)
		return
	if not _shared_staffing_ok(game):
		quit(1)
		return
	print("lumber_camp_ok")
	quit(0)


func _oak_occupied_by(game, character_id: int) -> Structure:
	for structure in game.structure_manager.index_to_structures:
		if structure and structure.config.id == StructureConfig.TypeId.OAK and game.structure_manager.occupant_of(structure.id) == character_id:
			return structure
	return null


func _log_icon_ok() -> bool:
	var icon := ItemConfig.log.icon as AtlasTexture
	if icon == null or icon.region.position != Vector2(ItemConfig.CELL_SIZE, 0):
		push_error("原木应占用 atlas 第二格")
		return false
	if icon.get_size() != Vector2(ItemConfig.CELL_SIZE, ItemConfig.CELL_SIZE):
		push_error("原木 icon 应为 %s 格，实际 %s" % [ItemConfig.CELL_SIZE, icon.get_size()])
		return false
	if icon.atlas == null or icon.atlas.get_width() != ItemConfig.CELL_SIZE * 2:
		push_error("物品 atlas 应加到两格宽")
		return false
	if ItemConfig.berry.icon.region.position != Vector2.ZERO:
		push_error("浆果应仍在第一格")
		return false
	return true


func _save_ok(game, camp: LumberCamp) -> bool:
	camp.priority = LumberCamp.Priority.HIGH
	camp.container.set_count(ItemConfig.TypeId.LOG, 4)
	var restored: Structure = Structure.deserialize(camp.serialize(), game)
	var restored_camp := restored as LumberCamp
	if restored_camp == null or restored_camp.log_count() != 4 or restored_camp.priority != LumberCamp.Priority.HIGH:
		push_error("伐木营地存档应保留原木和优先级")
		return false
	restored.free()
	camp.priority = LumberCamp.Priority.NORMAL
	return true


func _reservation_ok(game) -> bool:
	game._clear()
	var camp = StructureConfig.lumber_camp.instantiate()
	game.structure_manager.add_structure(camp, 100)
	var left = StructureConfig.oak.instantiate()
	game.structure_manager.add_structure(left, 90)
	var right = StructureConfig.oak.instantiate()
	game.structure_manager.add_structure(right, 110)
	var first = game.spawn_resident_at_cell(99)
	var second = game.spawn_resident_at_cell(101)
	first.set_process(false)
	second.set_process(false)
	_set_hour(game, 12)
	for _step in 60:
		first._process(0.5)
		second._process(0.5)
		if _oak_occupied_by(game, first.id) and _oak_occupied_by(game, second.id):
			break
	var first_oak = _oak_occupied_by(game, first.id)
	var second_oak = _oak_occupied_by(game, second.id)
	if first_oak == null or second_oak == null or first_oak == second_oak:
		push_error("两名伐木工不应抢同一棵橡树 %s %s" % [first_oak, second_oak])
		return false
	return true


func _no_oak_ok(game) -> bool:
	game._clear()
	var camp = StructureConfig.lumber_camp.instantiate()
	game.structure_manager.add_structure(camp, 100)
	var oak = StructureConfig.oak.instantiate()
	game.structure_manager.add_structure(oak, 90)
	var first = game.spawn_resident_at_cell(99)
	var second = game.spawn_resident_at_cell(101)
	first.set_process(false)
	second.set_process(false)
	_set_hour(game, 12)
	for _step in 12:
		first._process(0.5)
		second._process(0.5)
	var waiting = first if _oak_occupied_by(game, first.id) == null else second
	if not waiting.visible or waiting.indoors:
		push_error("无可砍橡树时应出屋等待，不应隐身")
		return false
	if waiting.current_activity() != "正在等待可砍伐的橡树":
		push_error("应显示正在等待可砍伐的橡树，实际 %s" % waiting.current_activity())
		return false
	return true


func _log_cap_ok(game) -> bool:
	game._clear()
	var camp = StructureConfig.lumber_camp.instantiate()
	game.structure_manager.add_structure(camp, 100)
	var oak = StructureConfig.oak.instantiate()
	game.structure_manager.add_structure(oak, 110)
	var lumberjack = game.spawn_resident_at_cell(98)
	lumberjack.set_process(false)
	_set_hour(game, 12)
	camp.container.add(ItemConfig.TypeId.LOG, LumberCamp.LOG_CAPACITY)
	var camp_x = Game.get_position_by_cell_index(100) + Game.HALF_TILE_SIZE
	for _step in 80:
		lumberjack._process(0.5)
	if lumberjack.visible or not is_equal_approx(lumberjack.position.x, camp_x):
		push_error("原木满仓时应待在伐木营地")
		return false
	if lumberjack.current_activity() != "待在伐木营地":
		push_error("满仓应显示待在伐木营地，实际 %s" % lumberjack.current_activity())
		return false
	if game.structure_manager.occupant_of(oak.id) != 0:
		push_error("满仓不应去橡树")
		return false
	camp.container.set_count(ItemConfig.TypeId.LOG, LumberCamp.LOG_CAPACITY - 1)
	var left := false
	for _step in 80:
		lumberjack._process(0.5)
		if game.structure_manager.occupant_of(oak.id) == lumberjack.id:
			left = true
			break
	if not left:
		push_error("原木不满 10 后应继续伐木")
		return false
	lumberjack.carried_items.add(ItemConfig.TypeId.LOG, 5)
	camp.deposit_carried(lumberjack.carried_items)
	if camp.log_count() != LumberCamp.LOG_CAPACITY or not lumberjack.carried_items.is_empty():
		push_error("存入应截断到 10，实际 %s" % camp.log_count())
		return false
	return true


func _haul_ok(game) -> bool:
	game._clear()
	var camp = StructureConfig.lumber_camp.instantiate()
	game.structure_manager.add_structure(camp, 100)
	var far = StructureConfig.warehouse.instantiate()
	game.structure_manager.add_structure(far, 140)
	var near = StructureConfig.warehouse.instantiate()
	game.structure_manager.add_structure(near, 108)
	var lumberjack = game.spawn_resident_at_cell(98)
	lumberjack.set_process(false)
	_set_hour(game, 12)
	camp.container.add(ItemConfig.TypeId.LOG, LumberCamp.LOG_CAPACITY)
	var saw_haul := false
	for _step in 200:
		lumberjack._process(0.5)
		if lumberjack.current_activity() == "正在把原木送到仓库":
			saw_haul = true
		if near.container.count_of(ItemConfig.TypeId.LOG) > 0:
			break
	if not saw_haul:
		push_error("满仓应去送仓库")
		return false
	if near.container.count_of(ItemConfig.TypeId.LOG) != LumberCamp.HAUL_BATCH:
		push_error("应把 10 个原木送到最近仓库，实际 %s" % near.container.count_of(ItemConfig.TypeId.LOG))
		return false
	if far.container.count_of(ItemConfig.TypeId.LOG) != 0:
		push_error("较远仓库不应收到原木")
		return false
	if camp.log_count() != 0:
		push_error("送出后营地应空，实际 %s" % camp.log_count())
		return false
	camp.container.add(ItemConfig.TypeId.LOG, LumberCamp.LOG_CAPACITY)
	lumberjack.abandon_ai_tasks()
	for _step in 30:
		lumberjack._process(0.5)
		if lumberjack.current_activity() == "正在把原木送到仓库" and not is_equal_approx(lumberjack.position.x, Game.get_position_by_cell_index(100) + Game.HALF_TILE_SIZE):
			break
	game.employment.release(lumberjack.id)
	lumberjack.abandon_ai_tasks()
	if camp.log_count() != LumberCamp.LOG_CAPACITY or near.container.count_of(ItemConfig.TypeId.LOG) != LumberCamp.HAUL_BATCH:
		push_error("运送中断应把原木退回营地 camp=%s warehouse=%s carried=%s" % [camp.log_count(), near.container.count_of(ItemConfig.TypeId.LOG), lumberjack.carried_items.count_of(ItemConfig.TypeId.LOG)])
		return false
	return true


func _warehouse_capacity_ok(game) -> bool:
	game._clear()
	var camp = StructureConfig.lumber_camp.instantiate()
	game.structure_manager.add_structure(camp, 100)
	var full = StructureConfig.warehouse.instantiate() as Warehouse
	game.structure_manager.add_structure(full, 108)
	var open = StructureConfig.warehouse.instantiate() as Warehouse
	game.structure_manager.add_structure(open, 140)
	var lumberjack = game.spawn_resident_at_cell(98)
	lumberjack.set_process(false)
	_set_hour(game, 12)
	full.container.add(ItemConfig.TypeId.LOG, Warehouse.LOG_CAPACITY)
	camp.container.add(ItemConfig.TypeId.LOG, LumberCamp.LOG_CAPACITY)
	for _step in 300:
		lumberjack._process(0.5)
		if open.container.count_of(ItemConfig.TypeId.LOG) > 0:
			break
	if open.container.count_of(ItemConfig.TypeId.LOG) != LumberCamp.HAUL_BATCH:
		push_error("近仓已满应改送远仓，实际 %s" % open.container.count_of(ItemConfig.TypeId.LOG))
		return false
	if full.log_count() != Warehouse.LOG_CAPACITY:
		push_error("满仓出发前不应再收货，实际 %s" % full.log_count())
		return false
	game._clear()
	camp = StructureConfig.lumber_camp.instantiate()
	game.structure_manager.add_structure(camp, 100)
	var only = StructureConfig.warehouse.instantiate() as Warehouse
	game.structure_manager.add_structure(only, 108)
	lumberjack = game.spawn_resident_at_cell(98)
	lumberjack.set_process(false)
	_set_hour(game, 12)
	only.container.add(ItemConfig.TypeId.LOG, Warehouse.LOG_CAPACITY)
	camp.container.add(ItemConfig.TypeId.LOG, LumberCamp.LOG_CAPACITY)
	for _step in 40:
		lumberjack._process(0.5)
		if lumberjack.current_activity() == "正在把原木送到仓库":
			push_error("目标仓已满不应开始搬运")
			return false
	if camp.log_count() != LumberCamp.LOG_CAPACITY or only.log_count() != Warehouse.LOG_CAPACITY:
		push_error("满仓时应货留营地 camp=%s warehouse=%s" % [camp.log_count(), only.log_count()])
		return false
	if lumberjack.current_activity() != "待在伐木营地":
		push_error("满仓应待在伐木营地，实际 %s" % lumberjack.current_activity())
		return false
	game._clear()
	camp = StructureConfig.lumber_camp.instantiate()
	game.structure_manager.add_structure(camp, 100)
	var warehouse = StructureConfig.warehouse.instantiate() as Warehouse
	game.structure_manager.add_structure(warehouse, 140)
	lumberjack = game.spawn_resident_at_cell(98)
	lumberjack.set_process(false)
	_set_hour(game, 12)
	warehouse.container.add(ItemConfig.TypeId.LOG, Warehouse.LOG_CAPACITY - 1)
	camp.container.add(ItemConfig.TypeId.LOG, LumberCamp.LOG_CAPACITY)
	var hauling := false
	for _step in 300:
		lumberjack._process(0.5)
		if lumberjack.current_activity() == "正在把原木送到仓库" and not lumberjack.carried_items.is_empty():
			hauling = true
			warehouse.container.set_count(ItemConfig.TypeId.LOG, Warehouse.LOG_CAPACITY)
		if hauling and warehouse.log_count() > Warehouse.LOG_CAPACITY:
			break
	if not hauling:
		push_error("出发时应还能启运")
		return false
	if warehouse.log_count() != Warehouse.LOG_CAPACITY + LumberCamp.HAUL_BATCH:
		push_error("途中满仓到达应爆仓，实际 %s" % warehouse.log_count())
		return false
	return true


func _shared_staffing_ok(game) -> bool:
	game._clear()
	var hut = StructureConfig.gatherer_hut.instantiate()
	hut.priority = GathererHut.Priority.HIGH
	game.structure_manager.add_structure(hut, 0)
	var camp = StructureConfig.lumber_camp.instantiate()
	game.structure_manager.add_structure(camp, 100)
	var at_hut = game.spawn_resident_at_cell(0)
	var beside_hut = game.spawn_resident_at_cell(1)
	var at_camp = game.spawn_resident_at_cell(100)
	at_hut.set_process(false)
	beside_hut.set_process(false)
	at_camp.set_process(false)
	game.employment.clear()
	game.rebalance_workplaces()
	if game.employment.workers_of(hut.id).size() != 2 or game.employment.workers_of(camp.id).size() != 1:
		push_error("高优先采集小屋应占 2 人、普通伐木营地占 1 人 %s %s" % [game.employment.workers_of(hut.id), game.employment.workers_of(camp.id)])
		return false
	if at_camp.workplace_structure_id() != camp.id or at_camp.occupation_name() != "伐木工":
		push_error("家在营地旁的居民应成为伐木工")
		return false
	if beside_hut.occupation_name() != "采集者":
		push_error("采集小屋的工人应仍是采集者，实际 %s" % beside_hut.occupation_name())
		return false
	var warehouse = StructureConfig.warehouse.instantiate()
	game.structure_manager.add_structure(warehouse, 200)
	var manager = game.spawn_resident_at_cell(200)
	warehouse.assign_manager(manager)
	game.rebalance_workplaces()
	if game.employment.count_of(hut.id) != 2 or game.employment.count_of(camp.id) != 1:
		push_error("仓库管理员不应占用伐木或采集名额")
		return false
	if manager.workplace_structure_id() != warehouse.id:
		push_error("仓库管理员应留在仓库")
		return false
	return true


func _set_hour(game, hour: int) -> void:
	game.game_time.all_days = 8.0 + (float(hour) + 0.5) / 24.0
