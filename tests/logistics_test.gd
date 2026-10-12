extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	load("res://game/game.gd")
	load("res://game/game_builder.gd")
	load("res://game/items/item_config.gd")
	load("res://game/items/item_container.gd")
	load("res://game/structures/gatherer_hut.gd")
	load("res://game/characters/ai/tasks/character_ai_gather_cycle_task.gd")
	if not _berry_icon_is_atlas_cell():
		quit(1)
		return
	if not _container_round_trip():
		quit(1)
		return
	var game = (load("res://game/game.tscn") as PackedScene).instantiate()
	root.add_child(game)
	await process_frame
	game._clear()
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
	gatherer.set_process(false)
	var hut = StructureConfig.gatherer_hut.instantiate()
	game.structure_manager.add_structure(hut, hut_cell)
	var bush = StructureConfig.bush.instantiate()
	game.structure_manager.add_structure(bush, bush_cell)
	_set_hour(game, 12)
	if gatherer.workplace_structure_id() != hut.id:
		push_error("采集者应入职小屋 %s" % [gatherer.workplace_structure_id()])
		quit(1)
		return
	var deposited := false
	for _step in 2000:
		gatherer._process(0.5)
		if hut.container.count_of(ItemConfig.TypeId.BERRY) > 0:
			deposited = true
			break
	if not deposited:
		push_error("采集者应把浆果送到小屋容器")
		quit(1)
		return
	if hut.container.count_of(ItemConfig.TypeId.BERRY) != 1:
		push_error("一轮采集应产出 1 浆果，实际 %s" % hut.container.count_of(ItemConfig.TypeId.BERRY))
		quit(1)
		return
	if not gatherer.carried_items.is_empty():
		push_error("浆果送到小屋后采集者身上应为空")
		quit(1)
		return
	if not _structure_container_round_trip(game, hut):
		quit(1)
		return
	var browser = (load("res://game/info/info_browser.tscn") as PackedScene).instantiate()
	root.add_child(browser)
	browser.open_structure(hut)
	await process_frame
	if not _page_shows_berry(browser):
		quit(1)
		return
	print("logistics_ok")
	quit(0)


func _berry_icon_is_atlas_cell() -> bool:
	var icon := ItemConfig.berry.icon as AtlasTexture
	if icon == null:
		push_error("浆果 icon 应取自物品 atlas")
		return false
	if icon.atlas == null or icon.atlas.get_width() < ItemConfig.CELL_SIZE:
		push_error("物品 atlas 缺失或过窄")
		return false
	if icon.get_size() != Vector2(ItemConfig.CELL_SIZE, ItemConfig.CELL_SIZE):
		push_error("浆果 icon 应为 %s×%s 格，实际 %s" % [ItemConfig.CELL_SIZE, ItemConfig.CELL_SIZE, icon.get_size()])
		return false
	return true


func _container_round_trip() -> bool:
	var container := ItemContainer.new()
	container.add(ItemConfig.TypeId.BERRY, 3)
	var restored := ItemContainer.deserialize(container.serialize())
	if restored.count_of(ItemConfig.TypeId.BERRY) != 3:
		push_error("容器存档应保留数量")
		return false
	var target := ItemContainer.new()
	restored.transfer_all_to(target)
	if not restored.is_empty() or target.count_of(ItemConfig.TypeId.BERRY) != 3:
		push_error("转移后来源应清空、目标应收到")
		return false
	return true


func _structure_container_round_trip(game, hut) -> bool:
	var restored: Structure = Structure.deserialize(hut.serialize(), game)
	if restored.container.count_of(ItemConfig.TypeId.BERRY) != 1:
		push_error("建筑容器应随存档保留")
		return false
	restored.free()
	return true


func _page_shows_berry(browser) -> bool:
	var page = browser.get_node("%PageHost").get_child(0)
	var items = page.get_node("%Items")
	for row in items.get_children():
		if not row.visible:
			continue
		var label := row.get_child(1) as Label
		if label and label.text == "×1":
			return true
	push_error("小屋信息应显示容器里的浆果")
	return false


func _set_hour(game, hour: int) -> void:
	game.game_time.all_days = 8.0 + float(hour) / 24.0
