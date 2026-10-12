extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	load("res://game/game.gd")
	load("res://game/structures/structure_config.gd")
	load("res://game/structures/warehouse.gd")
	load("res://game/structures/plant.gd")
	var game = (load("res://game/game.tscn") as PackedScene).instantiate()
	root.add_child(game)
	await process_frame
	game._clear()
	await process_frame
	var oak = StructureConfig.oak.instantiate()
	var bush = StructureConfig.bush.instantiate()
	var hut = StructureConfig.gatherer_hut.instantiate()
	var home = StructureConfig.sunken_floor_thatch_hovel.instantiate()
	var warehouse = StructureConfig.warehouse.instantiate() as Warehouse
	game.structure_manager.add_structure(oak, 10)
	game.structure_manager.add_structure(bush, 12)
	game.structure_manager.add_structure(hut, 14)
	game.structure_manager.add_structure(home, 16)
	game.structure_manager.add_structure(warehouse, 18)
	home.container.add(ItemConfig.TypeId.BERRY, 3)
	warehouse.container.add(ItemConfig.TypeId.BERRY, 4)
	var manager = game.spawn_resident_at_cell(18)
	manager.set_process(false)
	warehouse.assign_manager(manager)
	var browser = (load("res://game/info/info_browser.tscn") as PackedScene).instantiate()
	root.add_child(browser)
	for structure in [oak, bush, hut, home, warehouse]:
		browser.open_structure(structure)
		await process_frame
		if browser.current_path() != "structure/%d" % structure.id:
			push_error("应打开 %s" % structure.config.name)
			quit(1)
			return
		var page = browser.get_node("%PageHost").get_child(0)
		if page.get_script() != load("res://game/info/structure_page.gd"):
			push_error("建筑应共用 structure_page")
			quit(1)
			return
		if page.get_node("Rows").get_child(0).text != String(structure.config.name):
			push_error("标题应为建筑名")
			quit(1)
			return
	var hut_page = browser.get_node("%PageHost").get_child(0)
	browser.open_structure(hut)
	await process_frame
	hut_page = browser.get_node("%PageHost").get_child(0)
	if hut_page.get_node_or_null("Rows/Workplace") == null or hut_page.get_node_or_null("Rows/Inventory") == null:
		push_error("工坊应有优先级和库存")
		quit(1)
		return
	if hut_page.get_node("Rows/Workplace").get_node("%PrioritySlider") == null:
		push_error("工坊应有优先级滑条")
		quit(1)
		return
	browser.open_structure(oak)
	await process_frame
	var oak_page = browser.get_node("%PageHost").get_child(0)
	if oak_page.get_node_or_null("Rows/Inventory") or oak_page.get_node_or_null("Rows/Workplace"):
		push_error("树不应带库存或岗位")
		quit(1)
		return
	browser.open_structure(warehouse)
	await process_frame
	var warehouse_page = browser.get_node("%PageHost").get_child(0)
	var workplace = warehouse_page.get_node("Rows/Workplace")
	if workplace.get_node("%Worker0").text != manager.display_name():
		push_error("仓库管理员应出现在工人列表，实际 %s" % workplace.get_node("%Worker0").text)
		quit(1)
		return
	if workplace.get_node("%Worker1").visible:
		push_error("仓库只有一个工人位")
		quit(1)
		return
	workplace.get_node("%PrioritySlider").value = GathererHut.Priority.HIGH
	if warehouse.priority != GathererHut.Priority.HIGH:
		push_error("仓库优先级滑条应写回")
		quit(1)
		return
	var stock = warehouse_page.get_node("Rows/Inventory")
	var policy: OptionButton = null
	for row in stock.get_node("%Items").get_children():
		if row.visible and row.get_node_or_null("Policy"):
			policy = row.get_node("Policy")
			break
	if policy == null or policy.get_item_text(policy.selected) != "接收":
		push_error("仓库每项应有存储策略，默认接收")
		quit(1)
		return
	policy.select(Warehouse.StoragePolicy.REFUSE)
	policy.item_selected.emit(Warehouse.StoragePolicy.REFUSE)
	if warehouse.policy_of(ItemConfig.TypeId.BERRY) != Warehouse.StoragePolicy.REFUSE:
		push_error("下拉应写回仓库策略")
		quit(1)
		return
	var saved := Structure.deserialize(warehouse.serialize(), game)
	if (saved as Warehouse).policy_of(ItemConfig.TypeId.BERRY) != Warehouse.StoragePolicy.REFUSE:
		push_error("存储策略应进存档")
		quit(1)
		return
	if (saved as Warehouse).priority != GathererHut.Priority.HIGH:
		push_error("仓库优先级应进存档")
		quit(1)
		return
	var hauled := ItemContainer.new()
	if warehouse.withdraw_berries(hauled, 1) != 0:
		push_error("不接收时不能取出")
		quit(1)
		return
	warehouse.set_storage_policy(ItemConfig.TypeId.BERRY, Warehouse.StoragePolicy.WITHDRAW_ONLY)
	if warehouse.accepts_deposit(ItemConfig.TypeId.BERRY) or warehouse.withdraw_berries(hauled, 1) != 1:
		push_error("只出不进应能取出、不能存入")
		quit(1)
		return
	saved.free()
	browser.open_structure(home)
	await process_frame
	var home_page = browser.get_node("%PageHost").get_child(0)
	if home_page.get_node_or_null("Rows/Inventory") == null or home_page.get_node_or_null("Rows/Residents") == null:
		push_error("住房应有库存和住户")
		quit(1)
		return
	if home_page.get_node("Rows/Inventory").get_node("%Title").text != "库存 3/10":
		push_error("住房库存数量不对，实际 %s" % home_page.get_node("Rows/Inventory").get_node("%Title").text)
		quit(1)
		return
	print("structure_inspector_ok")
	quit(0)
