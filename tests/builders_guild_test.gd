extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	load("res://game/game.gd")
	load("res://game/structures/builders_guild.gd")
	load("res://game/structures/sunken_floor_thatch_hovel.gd")
	load("res://game/structures/timber_frame_cottage.gd")
	load("res://game/characters/ai/tasks/character_ai_build_cycle_task.gd")
	var game = (load("res://game/game.tscn") as PackedScene).instantiate()
	root.add_child(game)
	await process_frame
	if not _menu_ok(game):
		quit(1)
		return
	if not await _save_progress_ok(game):
		quit(1)
		return
	if not await _prefer_warehouse_ok(game):
		quit(1)
		return
	if not await _refuse_warehouse_ok(game):
		quit(1)
		return
	if not await _abandon_ok(game):
		quit(1)
		return
	if not await _surplus_returns_ok(game):
		quit(1)
		return
	if not await _full_site_keeps_carried_ok(game):
		quit(1)
		return
	if not await _upgrade_ok(game):
		quit(1)
		return
	print("builders_guild_ok")
	quit(0)


func _menu_ok(game) -> bool:
	if StructureConfig.timber_frame_cottage.placeable or not StructureConfig.builders_guild.placeable:
		push_error("木架茅屋不能直接建造，建筑工会可以")
		return false
	var hud = (load("res://game/game_hud.tscn") as PackedScene).instantiate()
	hud.game = game
	hud.get_node("HudRoot/MarginContainer/Label").set_process(false)
	root.add_child(hud)
	var menu: PopupMenu = hud.get_node("PopupMenu/BuildSubmenu")
	var names: PackedStringArray = []
	for index in menu.item_count:
		names.append(menu.get_item_text(index))
	hud.queue_free()
	if not names.has("建筑工会") or names.has("木架茅屋"):
		push_error("建造菜单应有建筑工会、没有木架茅屋，实际 %s" % [names])
		return false
	return true


func _save_progress_ok(game) -> bool:
	game._clear()
	await process_frame
	var hovel = StructureConfig.sunken_floor_thatch_hovel.instantiate() as SunkenFloorThatchHovel
	game.structure_manager.add_structure(hovel, 40)
	hovel.order_upgrade()
	hovel.container.add(ItemConfig.TypeId.LOG, 5)
	hovel.container.add(ItemConfig.TypeId.BERRY, 2)
	hovel.work_units = 1
	var restored = Structure.deserialize(hovel.serialize(), game) as SunkenFloorThatchHovel
	if restored == null or not restored.upgrade_ordered or restored.work_units != 1:
		push_error("升级进度应进存档")
		return false
	if restored.log_count() != 5 or restored.container.count_of(ItemConfig.TypeId.BERRY) != 2:
		push_error("存档应保留原木和浆果")
		return false
	if restored.get_node("Scaffold").visible:
		push_error("原木未齐不应出现脚手架")
		return false
	restored.container.set_count(ItemConfig.TypeId.LOG, SunkenFloorThatchHovel.LOG_COST)
	restored.sync_scaffold()
	if not restored.get_node("Scaffold").visible:
		push_error("原木齐了应搭脚手架")
		return false
	restored.free()
	return true


func _prefer_warehouse_ok(game) -> bool:
	game._clear()
	await process_frame
	var placed := _place(game, 96, 100, 104, 120)
	var builder: Character = placed[0]
	var hovel: SunkenFloorThatchHovel = placed[1]
	var near: Warehouse = placed[2]
	var far: Warehouse = placed[3]
	near.container.add(ItemConfig.TypeId.LOG, 20)
	far.container.add(ItemConfig.TypeId.LOG, 20)
	hovel.order_upgrade()
	_set_hour(game, 12)
	if not _until([builder], 300, func() -> bool: return hovel.log_count() >= 20):
		push_error("应从最近仓库搬完全部原木，茅舍 %s 近仓 %s" % [hovel.log_count(), near.container.count_of(ItemConfig.TypeId.LOG)])
		return false
	if near.container.count_of(ItemConfig.TypeId.LOG) != 0 or far.container.count_of(ItemConfig.TypeId.LOG) != 20:
		push_error("应只搬近仓，近仓 %s 远仓 %s" % [near.container.count_of(ItemConfig.TypeId.LOG), far.container.count_of(ItemConfig.TypeId.LOG)])
		return false
	return true


func _refuse_warehouse_ok(game) -> bool:
	game._clear()
	await process_frame
	var placed := _place(game, 96, 100, 104, 112)
	var builder: Character = placed[0]
	var hovel: SunkenFloorThatchHovel = placed[1]
	var near: Warehouse = placed[2]
	var far: Warehouse = placed[3]
	near.container.add(ItemConfig.TypeId.LOG, 20)
	near.set_storage_policy(ItemConfig.TypeId.LOG, Warehouse.StoragePolicy.REFUSE)
	far.container.add(ItemConfig.TypeId.LOG, 20)
	hovel.order_upgrade()
	_set_hour(game, 12)
	if not _until([builder], 400, func() -> bool: return hovel.log_count() >= 20):
		push_error("近仓不接收时应改搬远仓，茅舍 %s 活动 %s" % [hovel.log_count(), builder.current_activity()])
		return false
	if near.container.count_of(ItemConfig.TypeId.LOG) != 20 or far.container.count_of(ItemConfig.TypeId.LOG) != 0:
		push_error("不接收的仓库不能被取出，近仓 %s 远仓 %s" % [near.container.count_of(ItemConfig.TypeId.LOG), far.container.count_of(ItemConfig.TypeId.LOG)])
		return false
	return true


func _abandon_ok(game) -> bool:
	game._clear()
	await process_frame
	var placed := _place(game, 96, 100, 104, 120)
	var builder: Character = placed[0]
	var hovel: SunkenFloorThatchHovel = placed[1]
	var near: Warehouse = placed[2]
	near.container.add(ItemConfig.TypeId.LOG, 20)
	hovel.order_upgrade()
	_set_hour(game, 12)
	if not _until([builder], 300, func() -> bool:
		return builder.current_activity() == "正在搬运原木" and builder.carried_items.count_of(ItemConfig.TypeId.LOG) > 0
	):
		push_error("应进入搬运，活动 %s 携带 %s" % [builder.current_activity(), builder.carried_items.count_of(ItemConfig.TypeId.LOG)])
		return false
	builder.abandon_ai_tasks()
	if near.container.count_of(ItemConfig.TypeId.LOG) != 20 or hovel.log_count() != 0 or builder.carried_items.count_of(ItemConfig.TypeId.LOG) != 0:
		push_error("中断搬运应把原木退回仓库，仓 %s 茅舍 %s 携带 %s" % [near.container.count_of(ItemConfig.TypeId.LOG), hovel.log_count(), builder.carried_items.count_of(ItemConfig.TypeId.LOG)])
		return false
	return true


func _surplus_returns_ok(game) -> bool:
	game._clear()
	await process_frame
	var guild = StructureConfig.builders_guild.instantiate()
	var hovel = StructureConfig.sunken_floor_thatch_hovel.instantiate() as SunkenFloorThatchHovel
	var warehouse = StructureConfig.warehouse.instantiate() as Warehouse
	game.structure_manager.add_structure(guild, 100)
	game.structure_manager.add_structure(hovel, 106)
	game.structure_manager.add_structure(warehouse, 112)
	var left = game.spawn_resident_at_cell(98)
	var right = game.spawn_resident_at_cell(102)
	left.set_process(false)
	right.set_process(false)
	hovel.container.add(ItemConfig.TypeId.BERRY, 4)
	warehouse.container.add(ItemConfig.TypeId.LOG, 40)
	hovel.order_upgrade()
	_set_hour(game, 12)
	var crew: Array = [left, right]
	var saw_return := false
	for _step in 800:
		for person in crew:
			person._process(0.5)
		if hovel.log_count() > SunkenFloorThatchHovel.LOG_COST:
			push_error("住房里的原木不能超过 %s，实际 %s" % [SunkenFloorThatchHovel.LOG_COST, hovel.log_count()])
			return false
		var returning: Character = null
		if left.current_activity() == "正在退回原木":
			returning = left
		elif right.current_activity() == "正在退回原木":
			returning = right
		if returning != null:
			saw_return = true
		if saw_return and hovel.log_count() == SunkenFloorThatchHovel.LOG_COST and warehouse.container.count_of(ItemConfig.TypeId.LOG) == 20 and left.carried_items.count_of(ItemConfig.TypeId.LOG) == 0 and right.carried_items.count_of(ItemConfig.TypeId.LOG) == 0:
			break
	if not saw_return or hovel.log_count() != 20 or warehouse.container.count_of(ItemConfig.TypeId.LOG) != 20:
		push_error("多搬的原木应退回仓库，茅舍 %s 仓 %s 退回 %s 活动 %s %s 携带 %s %s" % [hovel.log_count(), warehouse.container.count_of(ItemConfig.TypeId.LOG), saw_return, left.current_activity(), right.current_activity(), left.carried_items.count_of(ItemConfig.TypeId.LOG), right.carried_items.count_of(ItemConfig.TypeId.LOG)])
		return false
	if Food.stored(hovel) != 4 or not hovel.get_node("Scaffold").visible:
		push_error("退回后应留下浆果并搭起脚手架")
		return false
	warehouse.set_storage_policy(ItemConfig.TypeId.LOG, Warehouse.StoragePolicy.WITHDRAW_ONLY)
	warehouse.container.set_count(ItemConfig.TypeId.LOG, 1000)
	warehouse.restore_logs(20)
	if warehouse.container.count_of(ItemConfig.TypeId.LOG) != 1020 or hovel.log_count() != 20:
		push_error("退回应允许爆仓，仓 %s 茅舍 %s" % [warehouse.container.count_of(ItemConfig.TypeId.LOG), hovel.log_count()])
		return false
	return true


func _full_site_keeps_carried_ok(game) -> bool:
	game._clear()
	await process_frame
	var guild = StructureConfig.builders_guild.instantiate()
	var hovel = StructureConfig.sunken_floor_thatch_hovel.instantiate() as SunkenFloorThatchHovel
	game.structure_manager.add_structure(guild, 100)
	game.structure_manager.add_structure(hovel, 106)
	var builder = game.spawn_resident_at_cell(98)
	builder.set_process(false)
	hovel.order_upgrade()
	hovel.container.add(ItemConfig.TypeId.LOG, SunkenFloorThatchHovel.LOG_COST)
	builder.carried_items.add(ItemConfig.TypeId.LOG, 8)
	builder.push_ai_task(CharacterAiBuildCycleTask.new({
		CharacterAiBuildCycleTask.KEY_PHASE: 3,
		CharacterAiBuildCycleTask.KEY_SITE_ID: hovel.id,
		CharacterAiBuildCycleTask.KEY_GUILD_ID: guild.id,
	}))
	builder.abandon_ai_tasks()
	if hovel.log_count() != SunkenFloorThatchHovel.LOG_COST or builder.carried_items.count_of(ItemConfig.TypeId.LOG) != 8:
		push_error("没有仓库且工地已满时，多搬的原木应留在身上，茅舍 %s 携带 %s" % [hovel.log_count(), builder.carried_items.count_of(ItemConfig.TypeId.LOG)])
		return false
	game._clear()
	await process_frame
	guild = StructureConfig.builders_guild.instantiate()
	hovel = StructureConfig.sunken_floor_thatch_hovel.instantiate() as SunkenFloorThatchHovel
	game.structure_manager.add_structure(guild, 100)
	game.structure_manager.add_structure(hovel, 106)
	builder = game.spawn_resident_at_cell(98)
	builder.set_process(false)
	hovel.order_upgrade()
	hovel.container.add(ItemConfig.TypeId.LOG, 15)
	builder.carried_items.add(ItemConfig.TypeId.LOG, 10)
	builder.push_ai_task(CharacterAiBuildCycleTask.new({
		CharacterAiBuildCycleTask.KEY_PHASE: 3,
		CharacterAiBuildCycleTask.KEY_SITE_ID: hovel.id,
		CharacterAiBuildCycleTask.KEY_GUILD_ID: guild.id,
	}))
	builder.abandon_ai_tasks()
	if hovel.log_count() != SunkenFloorThatchHovel.LOG_COST or builder.carried_items.count_of(ItemConfig.TypeId.LOG) != 5:
		push_error("没有仓库时只补缺口，剩下的留在身上，茅舍 %s 携带 %s" % [hovel.log_count(), builder.carried_items.count_of(ItemConfig.TypeId.LOG)])
		return false
	return true


func _upgrade_ok(game) -> bool:
	game._clear()
	await process_frame
	var guild = StructureConfig.builders_guild.instantiate()
	var hovel = StructureConfig.sunken_floor_thatch_hovel.instantiate() as SunkenFloorThatchHovel
	var warehouse = StructureConfig.warehouse.instantiate() as Warehouse
	game.structure_manager.add_structure(guild, 100)
	game.structure_manager.add_structure(hovel, 101)
	game.structure_manager.add_structure(warehouse, 104)
	var left = game.spawn_resident_at_cell(98)
	var right = game.spawn_resident_at_cell(102)
	var resident = game.spawn_resident_at_cell(101)
	left.set_process(false)
	right.set_process(false)
	resident.set_process(false)
	_set_hour(game, 12)
	if left.occupation_name() != "建筑工" or right.occupation_name() != "建筑工":
		push_error("建筑工会应招募建筑工，实际 %s %s" % [left.occupation_name(), right.occupation_name()])
		return false
	if resident.workplace_structure_id() != 0:
		push_error("满员后不应再招人")
		return false
	var manager = game.spawn_resident_at_cell(140)
	manager.set_process(false)
	var office = StructureConfig.warehouse.instantiate() as Warehouse
	game.structure_manager.add_structure(office, 140)
	office.assign_manager(manager)
	game.rebalance_workplaces()
	if manager.workplace_structure_id() != office.id or game.employment.count_of(guild.id) != 2:
		push_error("仓库管理员不应占建筑工名额")
		return false
	hovel.container.add(ItemConfig.TypeId.BERRY, 4)
	var browser = (load("res://game/info/info_browser.tscn") as PackedScene).instantiate()
	root.add_child(browser)
	browser.open_structure(guild)
	await process_frame
	var guild_page = browser.get_node("%PageHost").get_child(0)
	if guild_page.get_node("Rows/Workplace").get_node("%Worker0").text != left.display_name():
		push_error("工会窗口应列出建筑工，实际 %s" % guild_page.get_node("Rows/Workplace").get_node("%Worker0").text)
		return false
	browser.open_structure(hovel)
	await process_frame
	var page = browser.get_node("%PageHost").get_child(0)
	var button: Button = page.get_node("Rows/Upgrade/UpgradeButton")
	if button.text != "升级为木架茅屋" or button.disabled:
		push_error("半穴茅舍应有可点的升级按钮，实际 %s" % button.text)
		return false
	button.pressed.emit()
	if not hovel.upgrade_ordered or warehouse.container.count_of(ItemConfig.TypeId.LOG) != 0:
		push_error("没有原木也要能下单")
		return false
	if not button.disabled or page.get_node("Rows/Upgrade/Status").text != "原木 0/%d · 建造 0/%d" % [SunkenFloorThatchHovel.LOG_COST, SunkenFloorThatchHovel.WORK_UNITS_REQUIRED]:
		push_error("下单后应显示等待材料，实际 %s" % page.get_node("Rows/Upgrade/Status").text)
		return false
	if hovel.get_node("Scaffold").visible:
		push_error("材料没到不应搭脚手架")
		return false
	var crew: Array = [left, right]
	if not _until(crew, 80, func() -> bool: return left.current_activity() == "正在等待原木" or right.current_activity() == "正在等待原木"):
		push_error("仓库没原木时应等待，活动 %s %s" % [left.current_activity(), right.current_activity()])
		return false
	warehouse.container.add(ItemConfig.TypeId.LOG, 7)
	if not _until(crew, 400, func() -> bool: return hovel.log_count() == 7 and (left.current_activity() == "正在等待原木" or right.current_activity() == "正在等待原木")):
		push_error("原木不够应先搬走现有的再等，茅舍 %s 仓 %s 活动 %s %s" % [hovel.log_count(), warehouse.container.count_of(ItemConfig.TypeId.LOG), left.current_activity(), right.current_activity()])
		return false
	if hovel.get_node("Scaffold").visible:
		push_error("7 根原木不应搭脚手架")
		return false
	warehouse.container.add(ItemConfig.TypeId.LOG, 13)
	if not _until(crew, 400, func() -> bool: return hovel.logs_ready() and hovel.get_node("Scaffold").visible):
		push_error("20 原木到齐应出现脚手架，茅舍 %s" % hovel.log_count())
		return false
	if not _until(crew, 400, func() -> bool: return left.current_activity() == "正在施工" and right.current_activity() == "正在施工"):
		push_error("两名建筑工应同时施工，活动 %s %s 单元 %s" % [left.current_activity(), right.current_activity(), hovel.work_units])
		return false
	left._process(0.2)
	right._process(0.2)
	var sprite := left.get_node("Sprite2D") as Sprite2D
	if is_zero_approx(sprite.rotation):
		push_error("施工时应有敲打姿态")
		return false
	var site_x := _x(101)
	if left.position.x <= site_x or right.position.x >= site_x:
		push_error("两人应分站茅舍两侧 %s %s 屋 %s" % [left.position.x, right.position.x, site_x])
		return false
	var units: int = hovel.work_units
	left._process(SunkenFloorThatchHovel.WORK_UNIT_SECONDS)
	right._process(SunkenFloorThatchHovel.WORK_UNIT_SECONDS)
	if hovel.work_units != units + 2:
		push_error("同时施工应各记一个单元，之前 %s 现在 %s" % [units, hovel.work_units])
		return false
	if hovel.config.name != &"半穴茅舍":
		push_error("两个单元还不应升级")
		return false
	if not _until(crew, 600, func() -> bool: return hovel.config.name == &"木架茅屋"):
		push_error("三个建造单元后应升级，单元 %s 活动 %s %s" % [hovel.work_units, left.current_activity(), right.current_activity()])
		return false
	if hovel.log_count() != 0 or Food.stored(hovel) != 4:
		push_error("升级应消耗 20 原木并留下浆果，原木 %s 浆果 %s" % [hovel.log_count(), Food.stored(hovel)])
		return false
	if hovel.config.id != StructureConfig.TypeId.TIMBER_FRAME_COTTAGE:
		push_error("升级后类型应为木架茅屋")
		return false
	if game.structure_manager.get_structure_by_id(hovel.id) != hovel:
		push_error("升级应留在原来的建筑上")
		return false
	if Food.home_of(resident) != hovel:
		push_error("住户应还住在升级后的房子里")
		return false
	if hovel.get_node("Scaffold").visible:
		push_error("升级完成后应拆掉脚手架")
		return false
	var texture := (hovel.get_node("Sprite2D") as Sprite2D).texture
	if texture.get_height() != 16:
		push_error("木架茅屋应比半穴茅舍更高，实际 %s" % texture.get_height())
		return false
	await process_frame
	if page.get_node("Rows/Title").text != "木架茅屋":
		push_error("检查页标题应改成新名字，实际 %s" % page.get_node("Rows/Title").text)
		return false
	if page.get_node("Rows/Upgrade").visible:
		push_error("升级后不应再显示升级按钮")
		return false
	var restored = Structure.deserialize(hovel.serialize(), game)
	if restored.config.name != &"木架茅屋" or restored.container.count_of(ItemConfig.TypeId.BERRY) != 4 or restored is SunkenFloorThatchHovel:
		push_error("读档应得到木架茅屋")
		return false
	restored.free()
	return true


func _place(game, guild_cell: int, hovel_cell: int, near_cell: int, far_cell: int) -> Array:
	var guild = StructureConfig.builders_guild.instantiate()
	var hovel = StructureConfig.sunken_floor_thatch_hovel.instantiate() as SunkenFloorThatchHovel
	var near = StructureConfig.warehouse.instantiate() as Warehouse
	var far = StructureConfig.warehouse.instantiate() as Warehouse
	game.structure_manager.add_structure(guild, guild_cell)
	game.structure_manager.add_structure(hovel, hovel_cell)
	game.structure_manager.add_structure(near, near_cell)
	game.structure_manager.add_structure(far, far_cell)
	var builder = game.spawn_resident_at_cell(guild_cell - 2)
	builder.set_process(false)
	return [builder, hovel, near, far]


func _until(people: Array, steps: int, done: Callable) -> bool:
	for _step in steps:
		for person in people:
			person._process(0.5)
		if done.call():
			return true
	return false


func _x(cell: int) -> float:
	return Game.get_position_by_cell_index(cell) + Game.HALF_TILE_SIZE


func _set_hour(game, hour: int) -> void:
	game.game_time.all_days = 8.0 + (float(hour) + 0.5) / 24.0
