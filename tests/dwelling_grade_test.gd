extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	load("res://game/game.gd")
	load("res://game/structures/dwelling.gd")
	load("res://game/structures/sunken_floor_thatch_hovel.gd")
	load("res://game/structures/timber_frame_cottage.gd")
	load("res://game/info/parts/upgrade_part.gd")
	var game = (load("res://game/game.tscn") as PackedScene).instantiate()
	root.add_child(game)
	await process_frame
	if not await _button_gate_ok(game):
		quit(1)
		return
	if not await _food_drop_ok(game):
		quit(1)
		return
	if not await _log_spend_ok(game):
		quit(1)
		return
	if not await _shared_stock_ok(game):
		quit(1)
		return
	if not await _empty_house_ok(game):
		quit(1)
		return
	if not await _cancel_build_ok(game):
		quit(1)
		return
	print("dwelling_grade_ok")
	quit(0)


func _button_gate_ok(game) -> bool:
	game._clear()
	await process_frame
	var home := _home(game, 40)
	var browser := _browser()
	browser.open_structure(home)
	await process_frame
	var button := _button(browser)
	if button.text != "升级为木架茅屋" or not button.disabled:
		push_error("没有居民和食物时不能升级，实际 %s disabled=%s" % [button.text, button.disabled])
		return false
	if _status(browser) != "居民 0 · 浆果 0/%d" % Food.PER_DAY:
		push_error("应显示食物门槛，实际 %s" % _status(browser))
		return false
	game.spawn_resident_at_cell(40).set_process(false)
	home.container.add(ItemConfig.TypeId.BERRY, Food.PER_DAY - 1)
	await process_frame
	if not button.disabled:
		push_error("浆果差 1 时按钮应仍禁用")
		return false
	home.container.add(ItemConfig.TypeId.BERRY, 1)
	await process_frame
	if button.disabled or button.text != "升级为木架茅屋":
		push_error("食物够了应能点升级，实际 %s" % _status(browser))
		return false
	browser.queue_free()
	return true


func _food_drop_ok(game) -> bool:
	game._clear()
	await process_frame
	var home := _home(game, 50)
	game.spawn_resident_at_cell(50).set_process(false)
	home.container.add(ItemConfig.TypeId.BERRY, Food.PER_DAY)
	home.order_upgrade()
	home.container.add(ItemConfig.TypeId.LOG, Dwelling.COTTAGE_LOG_COST)
	home.finish_upgrade()
	if home.level != 2 or home.config.name != &"木架茅屋" or home.display_name() != "木架茅屋":
		push_error("食物够时应升到 2 级木架茅屋，level=%s name=%s" % [home.level, home.display_name()])
		return false
	if (home.get_node("Sprite2D") as Sprite2D).texture.get_height() != 16:
		push_error("2 级应换成木架茅屋外形")
		return false
	home.container.take(ItemConfig.TypeId.BERRY, 1)
	home.maintain_grade()
	if home.level != 1 or home.config.id != StructureConfig.TypeId.SUNKEN_FLOOR_THATCH_HOVEL:
		push_error("食物不够应降回半穴茅舍，level=%s id=%s" % [home.level, home.config.id])
		return false
	if (home.get_node("Sprite2D") as Sprite2D).texture.get_height() != 13:
		push_error("降级后应恢复半穴茅舍外形")
		return false
	if home.get_node("TierMark").visible:
		push_error("1 级不应有烟囱")
		return false
	var restored := Structure.deserialize(home.serialize(), game)
	if restored.config.name != &"半穴茅舍" or restored.level != 1:
		push_error("降级应写入存档")
		return false
	restored.free()
	return true


func _log_spend_ok(game) -> bool:
	game._clear()
	await process_frame
	var home := _home(game, 60)
	game.spawn_resident_at_cell(60).set_process(false)
	home.container.add(ItemConfig.TypeId.BERRY, Food.HOME_CAPACITY)
	home.order_upgrade()
	home.container.add(ItemConfig.TypeId.LOG, Dwelling.COTTAGE_LOG_COST)
	home.finish_upgrade()
	var warehouse := StructureConfig.warehouse.instantiate() as Warehouse
	game.structure_manager.add_structure(warehouse, 64)
	warehouse.container.add(ItemConfig.TypeId.LOG, DwellingGrade.LOG_NEED - 1)
	var browser := _browser()
	browser.open_structure(home)
	await process_frame
	var button := _button(browser)
	if button.text != "升级为原木宅" or not button.disabled:
		push_error("原木差 1 时不能升 3 级，实际 %s %s" % [button.text, _status(browser)])
		return false
	warehouse.container.add(ItemConfig.TypeId.LOG, 1)
	await process_frame
	if button.disabled:
		push_error("仓库原木够了应能升原木宅，实际 %s" % _status(browser))
		return false
	button.pressed.emit()
	if home.level != 3 or home.display_name() != "原木宅" or not home.get_node("TierMark").visible:
		push_error("3 级应是带烟囱的原木宅，level=%s" % home.level)
		return false
	if warehouse.log_count() != 0:
		push_error("升原木宅应扣掉仓库里的 %d 根，剩余 %s" % [DwellingGrade.LOG_NEED, warehouse.log_count()])
		return false
	await process_frame
	if browser.get_node("%PageHost").get_child(0).get_node("Rows/Title").text != "原木宅":
		push_error("检查页标题应是原木宅")
		return false
	if not _status(browser).contains("原木已扣"):
		push_error("已升原木宅应显示原木已扣，实际 %s" % _status(browser))
		return false
	# 别的工程搬走原木时，仓库数字再低也不掉级。
	home.maintain_grade()
	if home.level != 3 or home.display_name() != "原木宅":
		push_error("仓库已空也不应掉级，level=%s name=%s" % [home.level, home.display_name()])
		return false
	if Food.stored(home) != Food.HOME_CAPACITY:
		push_error("升级不应动食物")
		return false
	var timber := Structure.deserialize(home.serialize(), game) as Dwelling
	if timber.level != 3 or timber.display_name() != "原木宅" or not timber.get_node("TierMark").visible:
		push_error("3 级应能读档，level=%s mark=%s" % [timber.level, timber.get_node_or_null("TierMark")])
		return false
	timber.free()
	browser.queue_free()
	return true


func _shared_stock_ok(game) -> bool:
	game._clear()
	await process_frame
	var first := _cottage(game, 60)
	var second := _cottage(game, 70)
	game.spawn_resident_at_cell(60).set_process(false)
	game.spawn_resident_at_cell(70).set_process(false)
	first.container.add(ItemConfig.TypeId.BERRY, Food.PER_DAY)
	second.container.add(ItemConfig.TypeId.BERRY, Food.PER_DAY)
	var warehouse := StructureConfig.warehouse.instantiate() as Warehouse
	game.structure_manager.add_structure(warehouse, 65)
	warehouse.container.add(ItemConfig.TypeId.LOG, DwellingGrade.LOG_NEED)
	first.promote_timber()
	if first.level != 3 or warehouse.log_count() != 0:
		push_error("第一户应扣光仓库原木，level=%s stock=%s" % [first.level, warehouse.log_count()])
		return false
	second.promote_timber()
	if second.level != 2:
		push_error("第二户不能共用已扣掉的原木，level=%s" % second.level)
		return false
	warehouse.container.add(ItemConfig.TypeId.LOG, DwellingGrade.LOG_NEED)
	second.promote_timber()
	if second.level != 3 or warehouse.log_count() != 0:
		push_error("第二户有自己的原木后应能升级，level=%s stock=%s" % [second.level, warehouse.log_count()])
		return false
	warehouse.container.take(ItemConfig.TypeId.LOG, warehouse.log_count())
	first.maintain_grade()
	second.maintain_grade()
	if first.level != 3 or second.level != 3:
		push_error("两户升完后仓库清空也不应掉级")
		return false
	return true


func _empty_house_ok(game) -> bool:
	game._clear()
	await process_frame
	var home := _home(game, 70)
	var resident = game.spawn_resident_at_cell(70)
	resident.set_process(false)
	home.container.add(ItemConfig.TypeId.BERRY, Food.PER_DAY)
	var warehouse := StructureConfig.warehouse.instantiate() as Warehouse
	game.structure_manager.add_structure(warehouse, 74)
	warehouse.container.add(ItemConfig.TypeId.LOG, DwellingGrade.LOG_NEED)
	home.order_upgrade()
	home.container.add(ItemConfig.TypeId.LOG, Dwelling.COTTAGE_LOG_COST)
	home.finish_upgrade()
	home.promote_timber()
	if home.level != 3:
		push_error("居民、食物、原木齐时应到 3 级")
		return false
	resident.home_cell_index = 90
	home.maintain_grade()
	if home.level != 1 or home.config.id != StructureConfig.TypeId.SUNKEN_FLOOR_THATCH_HOVEL:
		push_error("没有居民应直接降到 1 级，level=%s" % home.level)
		return false
	return true


func _cancel_build_ok(game) -> bool:
	game._clear()
	await process_frame
	var home := _home(game, 80)
	game.spawn_resident_at_cell(80).set_process(false)
	home.container.add(ItemConfig.TypeId.BERRY, Food.PER_DAY)
	home.order_upgrade()
	home.container.add(ItemConfig.TypeId.LOG, 4)
	home.work_units = 1
	home.container.take(ItemConfig.TypeId.BERRY, Food.PER_DAY)
	home.maintain_grade()
	if home.upgrade_ordered or home.work_units != 0:
		push_error("食物不够应取消未完成的升级")
		return false
	if home.log_count() != 4 or home.level != 1:
		push_error("取消升级应留下已送到的原木，原木 %s level %s" % [home.log_count(), home.level])
		return false
	return true


func _home(game, cell: int) -> Dwelling:
	var home := StructureConfig.sunken_floor_thatch_hovel.instantiate() as Dwelling
	game.structure_manager.add_structure(home, cell)
	return home


func _cottage(game, cell: int) -> Dwelling:
	var home := _home(game, cell)
	home.order_upgrade()
	home.container.add(ItemConfig.TypeId.LOG, Dwelling.COTTAGE_LOG_COST)
	home.finish_upgrade()
	return home


func _browser() -> Node:
	var browser := (load("res://game/info/info_browser.tscn") as PackedScene).instantiate()
	root.add_child(browser)
	return browser


func _button(browser: Node) -> Button:
	return browser.get_node("%PageHost").get_child(0).get_node("Rows/Upgrade/UpgradeButton")


func _status(browser: Node) -> String:
	return browser.get_node("%PageHost").get_child(0).get_node("Rows/Upgrade/Status").text
