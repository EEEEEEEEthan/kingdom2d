extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	load("res://game/game.gd")
	load("res://game/structures/warehouse.gd")
	load("res://game/structures/gatherer_hut.gd")
	var game = (load("res://game/game.tscn") as PackedScene).instantiate()
	root.add_child(game)
	await process_frame
	game._clear()
	var warehouse = load("res://game/structures/structure_config.gd").warehouse.instantiate()
	game.structure_manager.add_structure(warehouse, 20)
	var hut = load("res://game/structures/structure_config.gd").gatherer_hut.instantiate()
	game.structure_manager.add_structure(hut, 40)
	var browser = (load("res://game/info/info_browser.tscn") as PackedScene).instantiate()
	root.add_child(browser)
	browser._game = game
	browser.open_structure(hut)
	await process_frame
	var hut_page = browser.get_node("%PageHost").get_child(0)
	if hut_page.get_node_or_null("%PrioritySlider") != null:
		push_error("采集小屋检视器不应有优先级滑条")
		quit(1)
		return
	browser.open_warehouse(warehouse)
	await process_frame
	var empty_page = browser.get_node("%PageHost").get_child(0)
	if not empty_page.get_node("%ContainerEmpty").visible or page_item_count(empty_page) != 0:
		push_error("空仓库应显示空")
		quit(1)
		return
	warehouse.container.add(load("res://game/items/item_config.gd").TypeId.BERRY, 4)
	browser.open_warehouse(warehouse)
	await process_frame
	if browser.current_path() != "warehouse/%d" % warehouse.id:
		push_error("打开仓库应落到 warehouse/id，实际 %s" % browser.current_path())
		quit(1)
		return
	var page = browser.get_node("%PageHost").get_child(0)
	if page.get_node("%ContainerEmpty").visible:
		push_error("有浆果时不应显示空")
		quit(1)
		return
	if page_item_count(page) != 4:
		push_error("仓库检视应看到 4 个浆果，实际 %s" % page_item_count(page))
		quit(1)
		return
	if page.get_node("%PriorityLabel").text != "普通":
		push_error("默认应是普通，实际 %s" % page.get_node("%PriorityLabel").text)
		quit(1)
		return
	page.get_node("%PrioritySlider").value = 2
	await process_frame
	if warehouse.priority != 2 or page.get_node("%PriorityLabel").text != "高优先":
		push_error("滑到高优先应写入仓库，实际 %s %s" % [warehouse.priority, page.get_node("%PriorityLabel").text])
		quit(1)
		return
	page.get_node("%PrioritySlider").value = 0
	await process_frame
	if warehouse.priority != 0 or page.get_node("%PriorityLabel").text != "低优先":
		push_error("滑到低优先应写入仓库")
		quit(1)
		return
	var restored = load("res://game/structures/structure.gd").deserialize(warehouse.serialize(), game)
	if restored.priority != 0:
		push_error("仓库优先级应存档")
		quit(1)
		return
	restored.free()
	print("warehouse_inspect_ok")
	quit(0)


func page_item_count(page) -> int:
	var items = page.get_node_or_null("%Items")
	if items == null:
		return -1
	for row in items.get_children():
		if not row.visible:
			continue
		var label = row.get_child(1)
		return int(str(label.text).trim_prefix("×"))
	return 0
