extends SceneTree

func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	load("res://game/game.gd")
	load("res://game/game_builder.gd")
	load("res://game/structures/gatherer_hut.gd")
	load("res://game/characters/ai/tasks/character_ai_gather_cycle_task.gd")
	var game = (load("res://game/game.tscn") as PackedScene).instantiate()
	root.add_child(game)
	await process_frame
	game._clear()
	await process_frame
	load("res://game/game_builder.gd").build(game)
	var hut_cell := -1
	var bush_cell := -1
	var previous_empty := -1
	for cell_index in Game.MAP_CELL_COUNT:
		if game.structure_manager.index_to_structures[cell_index]:
			continue
		if previous_empty >= 0 and cell_index - previous_empty <= 12 and cell_index > 16:
			hut_cell = previous_empty
			bush_cell = cell_index
			break
		previous_empty = cell_index
	var gatherer = game.spawn_resident_at_cell(hut_cell - 2)
	var near = game.spawn_resident_at_cell(hut_cell + 40)
	var bystander = game.spawn_resident_at_cell(hut_cell + 80)
	var hut = StructureConfig.gatherer_hut.instantiate()
	game.structure_manager.add_structure(hut, hut_cell)
	var bush = StructureConfig.bush.instantiate()
	game.structure_manager.add_structure(bush, bush_cell)
	near.set_process(false)
	gatherer.set_process(false)
	bystander.set_process(false)
	_set_hour(game, 12)
	var workers: Array[int] = game.employment.workers_of(hut.id)
	if workers.size() != 2 or workers[0] != gatherer.id or workers[1] != near.id:
		push_error("应自动优先安排家最近的居民 %s" % [workers])
		quit(1)
		return
	if gatherer.workplace_structure_id() != hut.id or near.workplace_structure_id() != hut.id:
		push_error("前两名最近居民应入职")
		quit(1)
		return
	if bystander.workplace_structure_id() != 0:
		push_error("满员后不应再加人")
		quit(1)
		return
	game.employment.release(near.id)
	var hut_x = Game.get_position_by_cell_index(hut_cell) + Game.HALF_TILE_SIZE
	var saw_hut := false
	var bush_x := 0.0
	bush = null
	for _step in 400:
		gatherer._process(0.5)
		if is_equal_approx(gatherer.position.x, hut_x):
			saw_hut = true
		if bush == null:
			bush = _bush_occupied_by(game, gatherer.id)
			if bush != null:
				bush_x = Game.get_position_by_cell_index(bush.cell_index) + Game.HALF_TILE_SIZE
		if bush != null and is_equal_approx(gatherer.position.x, bush_x):
			break
	if not saw_hut or bush == null:
		push_error("应先到小屋再到灌木 hut=%s bush=%s x=%s" % [saw_hut, bush, gatherer.position.x])
		quit(1)
		return
	await process_frame
	await process_frame
	if is_zero_approx(bush.rotation):
		push_error("灌木应抖动")
		quit(1)
		return
	var bush_id = bush.id
	_set_hour(game, 19)
	gatherer._process(0.2)
	if gatherer.indoors or not is_equal_approx(gatherer.position.x, bush_x):
		push_error("采集途中到点也不应回家")
		quit(1)
		return
	for _step in 400:
		gatherer._process(0.5)
		if hut.container.count_of(ItemConfig.TypeId.BERRY) > 0:
			break
	if gatherer.indoors or not gatherer.visible:
		push_error("工作段一轮结束后应留在屋外")
		quit(1)
		return
	gatherer._process(0.05)
	var top = gatherer.ai_task_stack.peek()
	if not top is CharacterAiGatherCycleTask:
		push_error("工作段一轮结束后应继续采集")
		quit(1)
		return
	_set_hour(game, 23)
	for _step in 400:
		gatherer._process(0.5)
		if gatherer.indoors:
			break
	if not gatherer.indoors:
		push_error("睡眠段一轮结束后应回家")
		quit(1)
		return
	if game.structure_manager.get_structure_by_id(bush_id) != bush:
		push_error("灌木不应消失")
		quit(1)
		return
	if game.structure_manager.occupant_of(bush_id) != 0:
		push_error("一轮结束后应释放灌木")
		quit(1)
		return
	var restored := WorkplaceIndex.new()
	restored.deserialize(game.employment.serialize())
	var restored_workers := restored.workers_of(hut.id)
	if restored_workers.size() != 1 or restored_workers[0] != gatherer.id:
		push_error("员工列表应存档")
		quit(1)
		return
	if not _priority_math_ok():
		quit(1)
		return
	var browser = (load("res://game/info/info_browser.tscn") as PackedScene).instantiate()
	root.add_child(browser)
	browser.open_structure(hut)
	if browser.current_path() != "structure/%d" % hut.id:
		push_error("打开小屋应落到 structure/id，实际 %s" % browser.current_path())
		quit(1)
		return
	var page = browser.get_node("%PageHost").get_child(0)
	var workplace = page.get_node("Rows/Workplace")
	if workplace.get_node("%Worker0").text != gatherer.display_name():
		push_error("小屋窗口应列出工人姓名，实际 %s" % workplace.get_node("%Worker0").text)
		quit(1)
		return
	if workplace.get_node("%Worker1").text != "空位":
		push_error("空位应显示空位，实际 %s" % workplace.get_node("%Worker1").text)
		quit(1)
		return
	var worker_avatar := workplace.get_node("%Worker0").get_node("Avatar") as PixelAvatar
	var expected_avatar := PixelAvatar.new()
	expected_avatar.apply_id(gatherer.id)
	if not worker_avatar.visible or worker_avatar.face != expected_avatar.face or worker_avatar.hair != expected_avatar.hair:
		push_error("在岗工人应显示自己的头像")
		quit(1)
		return
	if workplace.get_node("%Worker1").get_node("Avatar").visible:
		push_error("空位不应带头像")
		quit(1)
		return
	workplace.get_node("%Worker0").pressed.emit()
	await process_frame
	if browser.current_path() != "resident/%d" % gatherer.id:
		push_error("点工人应跳到居民，实际 %s" % browser.current_path())
		quit(1)
		return
	browser.go_back()
	if browser.current_path() != "structure/%d" % hut.id:
		push_error("从工人返回应回到小屋")
		quit(1)
		return
	browser.go_back()
	if not _priority_rebalance_ok(game):
		quit(1)
		return
	if not _reservation_ok(game):
		quit(1)
		return
	if not _no_bush_ok(game):
		quit(1)
		return
	if not _berry_cap_ok(game):
		quit(1)
		return
	if not _no_second_harvest_ok(game):
		quit(1)
		return
	if not _haul_ok(game):
		quit(1)
		return
	if not _warehouse_capacity_ok(game):
		quit(1)
		return
	print("gatherer_hut_ok")
	quit(0)


func _bush_occupied_by(game, character_id: int) -> Structure:
	for structure in game.structure_manager.index_to_structures:
		if structure and structure.config.id == StructureConfig.TypeId.BUSH and game.structure_manager.occupant_of(structure.id) == character_id:
			return structure
	return null


func _reservation_ok(game) -> bool:
	game._clear()
	var hut = StructureConfig.gatherer_hut.instantiate()
	game.structure_manager.add_structure(hut, 100)
	var left = StructureConfig.bush.instantiate()
	game.structure_manager.add_structure(left, 90)
	var right = StructureConfig.bush.instantiate()
	game.structure_manager.add_structure(right, 110)
	var first = game.spawn_resident_at_cell(99)
	var second = game.spawn_resident_at_cell(101)
	first.set_process(false)
	second.set_process(false)
	_set_hour(game, 12)
	for _step in 60:
		first._process(0.5)
		second._process(0.5)
		if _bush_occupied_by(game, first.id) and _bush_occupied_by(game, second.id):
			break
	var first_bush = _bush_occupied_by(game, first.id)
	var second_bush = _bush_occupied_by(game, second.id)
	if first_bush == null or second_bush == null or first_bush == second_bush:
		push_error("两名采集者不应抢同一棵灌木 %s %s" % [first_bush, second_bush])
		return false
	return true


func _no_bush_ok(game) -> bool:
	game._clear()
	var hut = StructureConfig.gatherer_hut.instantiate()
	game.structure_manager.add_structure(hut, 100)
	var bush = StructureConfig.bush.instantiate()
	game.structure_manager.add_structure(bush, 90)
	var first = game.spawn_resident_at_cell(99)
	var second = game.spawn_resident_at_cell(101)
	first.set_process(false)
	second.set_process(false)
	_set_hour(game, 12)
	for _step in 12:
		first._process(0.5)
		second._process(0.5)
	var waiting = first if _bush_occupied_by(game, first.id) == null else second
	if not waiting.visible or waiting.indoors:
		push_error("无可采灌木时应出屋等待，不应隐身")
		return false
	if waiting.current_activity() != "正在等待可采集的灌木":
		push_error("应显示正在等待可采集的灌木，实际 %s" % waiting.current_activity())
		return false
	return true


func _berry_cap_ok(game) -> bool:
	game._clear()
	var hut = StructureConfig.gatherer_hut.instantiate()
	game.structure_manager.add_structure(hut, 100)
	var bush = StructureConfig.bush.instantiate()
	game.structure_manager.add_structure(bush, 110)
	var gatherer = game.spawn_resident_at_cell(98)
	gatherer.set_process(false)
	_set_hour(game, 12)
	hut.container.add(ItemConfig.TypeId.BERRY, GathererHut.BERRY_CAPACITY)
	var hut_x = Game.get_position_by_cell_index(100) + Game.HALF_TILE_SIZE
	for _step in 80:
		gatherer._process(0.5)
	if gatherer.visible or not is_equal_approx(gatherer.position.x, hut_x):
		push_error("浆果满仓时应待在采集小屋")
		return false
	if gatherer.current_activity() != "待在采集者小屋":
		push_error("满仓应显示待在采集者小屋，实际 %s" % gatherer.current_activity())
		return false
	if game.structure_manager.occupant_of(bush.id) != 0:
		push_error("满仓不应去灌木")
		return false
	if hut.berry_count() != GathererHut.BERRY_CAPACITY:
		push_error("满仓数量应停在 %s" % GathererHut.BERRY_CAPACITY)
		return false
	hut.container.set_count(ItemConfig.TypeId.BERRY, GathererHut.BERRY_CAPACITY - 1)
	var left := false
	for _step in 80:
		gatherer._process(0.5)
		if game.structure_manager.occupant_of(bush.id) == gatherer.id:
			left = true
			break
	if not left:
		push_error("浆果不满 10 后应继续采集")
		return false
	gatherer.carried_items.add(ItemConfig.TypeId.BERRY, 5)
	hut.deposit_carried(gatherer.carried_items)
	if hut.berry_count() != GathererHut.BERRY_CAPACITY - 1 + 5 or not gatherer.carried_items.is_empty():
		push_error("溢出不应丢弃，实际 %s" % hut.berry_count())
		return false
	hut.container.set_count(ItemConfig.TypeId.BERRY, GathererHut.BERRY_CAPACITY)
	gatherer.carried_items.add(ItemConfig.TypeId.BERRY, 2)
	gatherer.abandon_ai_tasks()
	if hut.berry_count() != GathererHut.BERRY_CAPACITY + 2 or not gatherer.carried_items.is_empty():
		push_error("打断后也不应截断，实际 %s" % hut.berry_count())
		return false
	return true


func _no_second_harvest_ok(game) -> bool:
	game._clear()
	var hut = StructureConfig.gatherer_hut.instantiate()
	game.structure_manager.add_structure(hut, 100)
	var left = StructureConfig.bush.instantiate()
	game.structure_manager.add_structure(left, 90)
	var right = StructureConfig.bush.instantiate()
	game.structure_manager.add_structure(right, 110)
	var first = game.spawn_resident_at_cell(99)
	var second = game.spawn_resident_at_cell(101)
	first.set_process(false)
	second.set_process(false)
	_set_hour(game, 12)
	hut.container.add(ItemConfig.TypeId.BERRY, GathererHut.BERRY_CAPACITY - 1)
	var saw_one := false
	for _step in 400:
		first._process(0.5)
		second._process(0.5)
		var occupied := 0
		if game.structure_manager.occupant_of(left.id) != 0:
			occupied += 1
		if game.structure_manager.occupant_of(right.id) != 0:
			occupied += 1
		if occupied > 1:
			push_error("只剩 1 个空位时不应两人同时出去采")
			return false
		if occupied == 1:
			saw_one = true
		if saw_one and hut.berry_count() >= GathererHut.BERRY_CAPACITY:
			break
	if not saw_one:
		push_error("应有一人出去采")
		return false
	if hut.berry_count() != GathererHut.BERRY_CAPACITY:
		push_error("一人回来应正好到 10，实际 %s" % hut.berry_count())
		return false
	return true


func _haul_ok(game) -> bool:
	game._clear()
	var hut = StructureConfig.gatherer_hut.instantiate()
	game.structure_manager.add_structure(hut, 100)
	var far = StructureConfig.warehouse.instantiate()
	game.structure_manager.add_structure(far, 140)
	var near = StructureConfig.warehouse.instantiate()
	game.structure_manager.add_structure(near, 108)
	var gatherer = game.spawn_resident_at_cell(98)
	gatherer.set_process(false)
	_set_hour(game, 12)
	hut.container.add(ItemConfig.TypeId.BERRY, GathererHut.BERRY_CAPACITY)
	var saw_haul := false
	for _step in 200:
		gatherer._process(0.5)
		if gatherer.current_activity() == "正在把浆果送到仓库":
			saw_haul = true
		if near.container.count_of(ItemConfig.TypeId.BERRY) > 0:
			break
	if not saw_haul:
		push_error("满仓应去送仓库")
		return false
	if near.container.count_of(ItemConfig.TypeId.BERRY) != GathererHut.HAUL_BATCH:
		push_error("应把 10 个浆果送到最近仓库，实际 %s" % near.container.count_of(ItemConfig.TypeId.BERRY))
		return false
	if far.container.count_of(ItemConfig.TypeId.BERRY) != 0:
		push_error("较远仓库不应收到浆果")
		return false
	if hut.berry_count() != 0:
		push_error("送出后小屋应空，实际 %s" % hut.berry_count())
		return false
	if not gatherer.carried_items.is_empty():
		push_error("送到仓库后身上应为空")
		return false
	hut.container.add(ItemConfig.TypeId.BERRY, GathererHut.BERRY_CAPACITY)
	gatherer.abandon_ai_tasks()
	for _step in 30:
		gatherer._process(0.5)
		if gatherer.current_activity() == "正在把浆果送到仓库" and not is_equal_approx(gatherer.position.x, Game.get_position_by_cell_index(100) + Game.HALF_TILE_SIZE):
			break
	game.employment.release(gatherer.id)
	gatherer.abandon_ai_tasks()
	if hut.berry_count() != GathererHut.BERRY_CAPACITY or near.container.count_of(ItemConfig.TypeId.BERRY) != GathererHut.HAUL_BATCH:
		push_error("运送中断应把浆果退回小屋 hut=%s warehouse=%s carried=%s" % [hut.berry_count(), near.container.count_of(ItemConfig.TypeId.BERRY), gatherer.carried_items.count_of(ItemConfig.TypeId.BERRY)])
		return false
	return true


func _warehouse_capacity_ok(game) -> bool:
	game._clear()
	var hut = StructureConfig.gatherer_hut.instantiate()
	game.structure_manager.add_structure(hut, 100)
	var full = StructureConfig.warehouse.instantiate() as Warehouse
	game.structure_manager.add_structure(full, 108)
	var open = StructureConfig.warehouse.instantiate() as Warehouse
	game.structure_manager.add_structure(open, 140)
	var gatherer = game.spawn_resident_at_cell(98)
	gatherer.set_process(false)
	_set_hour(game, 12)
	full.container.add(ItemConfig.TypeId.BERRY, Warehouse.BERRY_CAPACITY)
	hut.container.add(ItemConfig.TypeId.BERRY, GathererHut.BERRY_CAPACITY)
	for _step in 300:
		gatherer._process(0.5)
		if open.container.count_of(ItemConfig.TypeId.BERRY) > 0:
			break
	if open.container.count_of(ItemConfig.TypeId.BERRY) != GathererHut.HAUL_BATCH:
		push_error("近仓已满应改送远仓，实际 %s" % open.container.count_of(ItemConfig.TypeId.BERRY))
		return false
	if full.berry_count() != Warehouse.BERRY_CAPACITY:
		push_error("满仓出发前不应再收货，实际 %s" % full.berry_count())
		return false
	game._clear()
	hut = StructureConfig.gatherer_hut.instantiate()
	game.structure_manager.add_structure(hut, 100)
	var only = StructureConfig.warehouse.instantiate() as Warehouse
	game.structure_manager.add_structure(only, 108)
	gatherer = game.spawn_resident_at_cell(98)
	gatherer.set_process(false)
	_set_hour(game, 12)
	only.container.add(ItemConfig.TypeId.BERRY, Warehouse.BERRY_CAPACITY)
	hut.container.add(ItemConfig.TypeId.BERRY, GathererHut.BERRY_CAPACITY)
	for _step in 40:
		gatherer._process(0.5)
		if gatherer.current_activity() == "正在把浆果送到仓库":
			push_error("目标仓已满不应开始搬运")
			return false
	if hut.berry_count() != GathererHut.BERRY_CAPACITY or only.berry_count() != Warehouse.BERRY_CAPACITY:
		push_error("满仓时应货留小屋 hut=%s warehouse=%s" % [hut.berry_count(), only.berry_count()])
		return false
	if gatherer.current_activity() != "待在采集者小屋":
		push_error("满仓应待在小屋，实际 %s" % gatherer.current_activity())
		return false
	game._clear()
	hut = StructureConfig.gatherer_hut.instantiate()
	game.structure_manager.add_structure(hut, 100)
	var warehouse = StructureConfig.warehouse.instantiate() as Warehouse
	game.structure_manager.add_structure(warehouse, 140)
	gatherer = game.spawn_resident_at_cell(98)
	gatherer.set_process(false)
	_set_hour(game, 12)
	warehouse.container.add(ItemConfig.TypeId.BERRY, Warehouse.BERRY_CAPACITY - 1)
	hut.container.add(ItemConfig.TypeId.BERRY, GathererHut.BERRY_CAPACITY)
	var hauling := false
	for _step in 300:
		gatherer._process(0.5)
		if gatherer.current_activity() == "正在把浆果送到仓库" and not gatherer.carried_items.is_empty():
			hauling = true
			warehouse.container.set_count(ItemConfig.TypeId.BERRY, Warehouse.BERRY_CAPACITY)
		if hauling and warehouse.berry_count() > Warehouse.BERRY_CAPACITY:
			break
	if not hauling:
		push_error("出发时应还能启运")
		return false
	if warehouse.berry_count() != Warehouse.BERRY_CAPACITY + GathererHut.HAUL_BATCH:
		push_error("途中满仓到达应爆仓，实际 %s" % warehouse.berry_count())
		return false
	return true


func _priority_math_ok() -> bool:
	var counts = GathererHut.allocate_tier_counts([50, 0, 10], 40)
	if counts != [30, 0, 10]:
		push_error("40 人应按权重落到低优先 30、高优先 10，实际 %s" % [counts])
		return false
	var shares = GathererHut.spread_evenly(30, [10, 10, 10])
	if shares != [10, 10, 10]:
		push_error("30 人应均匀分到三栋普通建筑，实际 %s" % [shares])
		return false
	return true


func _priority_rebalance_ok(game) -> bool:
	game._clear()
	var very = StructureConfig.gatherer_hut.instantiate()
	very.priority = GathererHut.Priority.HIGH
	game.structure_manager.add_structure(very, 0)
	var normal = StructureConfig.gatherer_hut.instantiate()
	game.structure_manager.add_structure(normal, 100)
	var at_very = game.spawn_resident_at_cell(0)
	var beside_very = game.spawn_resident_at_cell(1)
	var at_normal = game.spawn_resident_at_cell(100)
	at_very.set_process(false)
	beside_very.set_process(false)
	at_normal.set_process(false)
	game.employment.clear()
	game.rebalance_workplaces()
	var very_workers: Array[int] = game.employment.workers_of(very.id)
	var normal_workers: Array[int] = game.employment.workers_of(normal.id)
	if very_workers.size() != 2 or normal_workers.size() != 1:
		push_error("高优先应占 2 人、普通占 1 人 %s %s" % [very_workers, normal_workers])
		return false
	if at_normal.workplace_structure_id() != normal.id or beside_very.workplace_structure_id() != very.id:
		push_error("家近的建筑应留下对应居民")
		return false
	game.employment.assign(at_normal.id, very.id)
	game.rebalance_workplaces()
	if game.employment.workers_of(very.id).has(at_normal.id) or game.employment.count_of(normal.id) != 1:
		push_error("超编应先辞家最远的人")
		return false
	var warehouse = StructureConfig.warehouse.instantiate()
	game.structure_manager.add_structure(warehouse, 200)
	var manager = game.spawn_resident_at_cell(200)
	warehouse.assign_manager(manager)
	game.rebalance_workplaces()
	if game.employment.count_of(very.id) != 2 or game.employment.count_of(normal.id) != 1:
		push_error("仓库管理员不应占用采集名额 %s %s" % [game.employment.workers_of(very.id), game.employment.workers_of(normal.id)])
		return false
	if manager.workplace_structure_id() != warehouse.id:
		push_error("仓库管理员应留在仓库")
		return false
	if not _dangling_ids_ok(game):
		return false
	return true


func _dangling_ids_ok(game) -> bool:
	game._clear()
	var hut = StructureConfig.gatherer_hut.instantiate()
	game.structure_manager.add_structure(hut, 40)
	var resident = game.spawn_resident_at_cell(40)
	resident.set_process(false)
	game.employment.assign(999, hut.id)
	game.employment.assign(resident.id, 99999)
	game.rebalance_workplaces()
	if game.employment.workplace_of(999) != 0 or game.employment.workplace_of(resident.id) == 99999:
		push_error("对不上的岗位关系应在编制前清掉")
		return false
	if game.employment.workers_of(hut.id) != [resident.id]:
		push_error("清掉失效关系后空位应重新分配 %s" % [game.employment.workers_of(hut.id)])
		return false
	var legacy_structures := {
		StructureManager._KEY_STRUCTURES: [{
			Structure._KEY_INSTANCE_ID: hut.id,
			Structure._KEY_DATA: {GathererHut._KEY_WORKER_IDS: [resident.id, 404]},
		}],
	}
	var legacy_characters := {
		CharacterManager._KEY_CHARACTERS: [
			{Character._KEY_ID: resident.id, Character._KEY_WORKPLACE_STRUCTURE_ID: hut.id},
			{Character._KEY_ID: 7, Character._KEY_WORKPLACE_STRUCTURE_ID: 12345},
		],
	}
	var imported := WorkplaceIndex.new()
	imported.import_legacy(legacy_structures, legacy_characters, game.character_manager.characters, game.structure_manager.structures)
	if imported.workers_of(hut.id) != [resident.id] or imported.workplace_of(7) != 0:
		push_error("旧档只应留下对得上的关系 %s" % [imported.workers_of(hut.id)])
		return false
	return true


func _set_hour(game, hour: int) -> void:
	game.game_time.all_days = 8.0 + (float(hour) + 0.5) / 24.0
