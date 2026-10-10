extends SceneTree

class FakeSite:
	var id: int
	var cell_index: int
	var stock: Stockpile
	var kind: int
	var material_remaining: int = 0

	func receive_one() -> void:
		if material_remaining <= 0:
			return
		material_remaining -= 1


class Mover:
	var x: float = 0.0
	var speed: float = 100000.0


func _init() -> void:
	call_deferred("_go")


func _go() -> void:
	var failed := _run()
	quit(failed)


func _run() -> int:
	var failed := 0
	failed += _check("不够一份不能扣成负数", _no_negative())
	failed += _check("清空仓库不收货，失败后爆仓放回", _clear_rejects_then_overflow())
	failed += _check("原木送进最近的接受仓库", _nearest_accept())
	failed += _check("伐木不依赖树，连续产出", _lumber_without_trees())
	failed += _check("工会取一份，建筑工一份一份敲完帐篷", _builder_one_by_one())
	failed += _check("班次外不开新单元", _shift_gate())
	failed += _check("帐篷下单后三次交付变成小木屋", _tent_upgrade_node())
	failed += _check("开局没有预置居民", _no_preset_residents())
	failed += _check("旧档里的无家小人读回来会被丢掉", _saved_demo_people_do_not_return())
	print("失败 %d" % failed)
	return 1 if failed else 0


func _check(title: String, ok: bool) -> int:
	print("%s %s" % ["通过" if ok else "失败", title])
	return 0 if ok else 1


func _no_negative() -> bool:
	var stock := Stockpile.new()
	stock.capacity = 4
	if stock.try_take(LogisticsUnit.ITEM_WOOD, 1):
		return false
	if stock.amount(LogisticsUnit.ITEM_WOOD) != 0:
		return false
	stock.put_overflow(LogisticsUnit.ITEM_WOOD, 1)
	if not stock.try_take(LogisticsUnit.ITEM_WOOD, 1):
		return false
	return stock.amount(LogisticsUnit.ITEM_WOOD) == 0 and not stock.try_take(LogisticsUnit.ITEM_WOOD, 1)


func _warehouse(site_id: int, cell: int, policy: Stockpile.Policy, wood: int) -> FakeSite:
	var site := FakeSite.new()
	site.id = site_id
	site.cell_index = cell
	site.kind = WorkSite.Kind.WAREHOUSE
	site.stock = Stockpile.new()
	site.stock.capacity = 4
	site.stock.set_policy(LogisticsUnit.ITEM_WOOD, policy)
	if wood > 0:
		site.stock.put_overflow(LogisticsUnit.ITEM_WOOD, wood)
	return site


func _bind(unit: LogisticsUnit, sites: Array) -> void:
	unit.find_site = func(site_id: int):
		for site in sites:
			if site.id == site_id:
				return site
		return null
	unit.list_warehouses = func():
		return sites.filter(func(site): return site.kind == WorkSite.Kind.WAREHOUSE)


func _run_unit(unit: LogisticsUnit, mover: Mover) -> void:
	for _i in 40:
		if unit.tick(1.0, mover):
			return


func _clear_rejects_then_overflow() -> bool:
	var camp := FakeSite.new()
	camp.id = 1
	camp.cell_index = 0
	camp.kind = WorkSite.Kind.LUMBER
	camp.stock = Stockpile.new()
	camp.stock.capacity = 1
	var clearing := _warehouse(2, 2, Stockpile.Policy.CLEAR, 0)
	var sites: Array = [camp, clearing]
	var unit := LogisticsUnit.lumber(camp.id)
	_bind(unit, sites)
	var mover := Mover.new()
	_run_unit(unit, mover)
	return clearing.stock.amount(LogisticsUnit.ITEM_WOOD) == 0 and camp.stock.amount(LogisticsUnit.ITEM_WOOD) == 1 and unit.carried == 0


func _nearest_accept() -> bool:
	var camp := FakeSite.new()
	camp.id = 1
	camp.cell_index = 0
	camp.kind = WorkSite.Kind.LUMBER
	camp.stock = Stockpile.new()
	camp.stock.capacity = 2
	var far := _warehouse(2, 9, Stockpile.Policy.ACCEPT, 0)
	var near := _warehouse(3, 1, Stockpile.Policy.ACCEPT, 0)
	var clearing := _warehouse(4, 0, Stockpile.Policy.CLEAR, 0)
	var sites: Array = [camp, far, near, clearing]
	var unit := LogisticsUnit.lumber(camp.id)
	_bind(unit, sites)
	_run_unit(unit, Mover.new())
	return near.stock.amount(LogisticsUnit.ITEM_WOOD) == 1 and far.stock.amount(LogisticsUnit.ITEM_WOOD) == 0 and clearing.stock.amount(LogisticsUnit.ITEM_WOOD) == 0


func _lumber_without_trees() -> bool:
	var trees := 12
	var camp := FakeSite.new()
	camp.id = 1
	camp.cell_index = 0
	camp.kind = WorkSite.Kind.LUMBER
	camp.stock = Stockpile.new()
	camp.stock.capacity = 1
	var warehouse := _warehouse(2, 1, Stockpile.Policy.ACCEPT, 0)
	warehouse.stock.capacity = 8
	var sites: Array = [camp, warehouse]
	for _chop in 3:
		var unit := LogisticsUnit.lumber(camp.id)
		_bind(unit, sites)
		_run_unit(unit, Mover.new())
	return trees == 12 and warehouse.stock.amount(LogisticsUnit.ITEM_WOOD) == 3


func _builder_one_by_one() -> bool:
	var guild := FakeSite.new()
	guild.id = 10
	guild.cell_index = 0
	guild.kind = WorkSite.Kind.GUILD
	guild.stock = Stockpile.new()
	guild.stock.capacity = 4
	var warehouse := _warehouse(11, 1, Stockpile.Policy.ACCEPT, 3)
	var tent := FakeSite.new()
	tent.id = 12
	tent.cell_index = 3
	tent.kind = WorkSite.Kind.HOME
	tent.material_remaining = 3
	var sites: Array = [guild, warehouse, tent]
	if LogisticsUnit.nearest_fetch_source(guild.cell_index, sites) != warehouse:
		return false
	for trip in 3:
		var fetch := LogisticsUnit.fetch(guild.id, warehouse.id)
		_bind(fetch, sites)
		_run_unit(fetch, Mover.new())
		if guild.stock.amount(LogisticsUnit.ITEM_WOOD) != 1:
			return false
		if warehouse.stock.amount(LogisticsUnit.ITEM_WOOD) != 2 - trip:
			return false
		var build := LogisticsUnit.build(guild.id, tent.id)
		_bind(build, sites)
		_run_unit(build, Mover.new())
		if tent.material_remaining != 2 - trip:
			return false
		if guild.stock.amount(LogisticsUnit.ITEM_WOOD) != 0:
			return false
	return warehouse.stock.amount(LogisticsUnit.ITEM_WOOD) == 0 and tent.material_remaining == 0


func _shift_gate() -> bool:
	var off := GameTime.new(0.0)
	var on := GameTime.new(8.0 / 24.0)
	var unit_running := true
	var starts_off := off.day_time_period == GameTime.DayTimePeriod.WORK
	var starts_on := on.day_time_period == GameTime.DayTimePeriod.WORK
	return not starts_off and starts_on and unit_running


func _no_preset_residents() -> bool:
	if FileAccess.file_exists(Game.SAVE_FILE_PATH):
		DirAccess.open("user://").remove(Game.SAVE_FILE_PATH.get_file())
	var game := (load("res://game/game.tscn") as PackedScene).instantiate() as Game
	root.add_child(game)
	game.new_game()
	var empty: bool = game.character_manager.characters.is_empty()
	var visible := 0
	for child in game.character_manager.get_children():
		if child is Character:
			visible += 1
	game.free()
	return empty and visible == 0


func _saved_demo_people_do_not_return() -> bool:
	if FileAccess.file_exists(Game.SAVE_FILE_PATH):
		DirAccess.open("user://").remove(Game.SAVE_FILE_PATH.get_file())
	var game := (load("res://game/game.tscn") as PackedScene).instantiate() as Game
	root.add_child(game)
	game.new_game()
	for _index in 8:
		game.character_manager.create_character()
	game.save_game()
	game.free()
	var loaded := (load("res://game/game.tscn") as PackedScene).instantiate() as Game
	root.add_child(loaded)
	var demo_gone: bool = loaded.character_manager.characters.is_empty()
	var visible := 0
	for child in loaded.character_manager.get_children():
		if child is Character:
			visible += 1
	var tent := StructureConfig.tent.instantiate() as WorkSite
	loaded.structure_manager.add_structure(tent, 20)
	tent.on_player_placed(loaded)
	var from_tent: bool = loaded.character_manager.characters.size() == 1
	loaded.save_game()
	loaded.free()
	var again := (load("res://game/game.tscn") as PackedScene).instantiate() as Game
	root.add_child(again)
	var kept: bool = again.character_manager.characters.size() == 1
	again.free()
	if FileAccess.file_exists(Game.SAVE_FILE_PATH):
		DirAccess.open("user://").remove(Game.SAVE_FILE_PATH.get_file())
	return demo_gone and visible == 0 and from_tent and kept


func _tent_upgrade_node() -> bool:
	var holder := Node.new()
	root.add_child(holder)
	var tent := StructureConfig.tent.instantiate() as WorkSite
	holder.add_child(tent)
	tent.cell_index = 4
	tent.order_cabin()
	if tent.material_remaining != WorkSite.CABIN_LOG_COST:
		return false
	tent.receive_one()
	if tent.config.id != StructureConfig.TypeId.TENT or tent.material_remaining != 2:
		return false
	tent.receive_one()
	tent.receive_one()
	var became_cabin: bool = tent.config.id == StructureConfig.TypeId.WOOD_CABIN and tent.material_remaining == 0
	holder.free()
	return became_cabin
