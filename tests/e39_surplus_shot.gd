extends SceneTree

## 拍取食余量不进工位的检视截图，不计入常规回归。


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	load("res://game/game.gd")
	load("res://game/food.gd")
	load("res://game/structures/lumber_camp.gd")
	load("res://game/characters/ai/tasks/character_ai_harvest_cycle_task.gd")
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MINIMIZED)
	var game = (load("res://game/game.tscn") as PackedScene).instantiate()
	root.add_child(game)
	await process_frame
	game._clear()
	await process_frame
	var camp = StructureConfig.lumber_camp.instantiate()
	game.structure_manager.add_structure(camp, 100)
	var home = StructureConfig.sunken_floor_thatch_hovel.instantiate()
	game.structure_manager.add_structure(home, 96)
	var warehouse = StructureConfig.warehouse.instantiate()
	game.structure_manager.add_structure(warehouse, 104)
	var lumberjack = game.spawn_resident_at_cell(98)
	lumberjack.set_process(false)
	lumberjack.home_cell_index = 96
	home.container.set_count(ItemConfig.TypeId.BERRY, Food.HOME_CAPACITY)
	camp.container.set_count(ItemConfig.TypeId.LOG, 4)
	lumberjack.carried_items.add(ItemConfig.TypeId.LOG, 1)
	lumberjack.carried_items.add(ItemConfig.TypeId.BERRY, 3)
	lumberjack.push_ai_task(CharacterAiHarvestCycleTask.new({
		CharacterAiHarvestCycleTask.KEY_PHASE: CharacterAiHarvestCycleTask.Phase.RETURN_HARVEST,
		CharacterAiHarvestCycleTask.KEY_WORKPLACE_ID: camp.id,
		CharacterAiHarvestCycleTask.KEY_OWED_TO_WORKPLACE: 1,
	}, CharacterAiTaskTypeId.TypeId.LOG_CYCLE))
	lumberjack.abandon_ai_tasks()
	var browser = (load("res://game/info/info_browser.tscn") as PackedScene).instantiate() as Window
	browser.always_on_top = false
	root.add_child(browser)
	browser.position = Vector2i(120, 120)
	browser.size = Vector2i(280, 360)
	browser.open_structure(camp)
	await _shot(browser, "e39-camp-no-berry.png")
	browser.open_structure(warehouse)
	await _shot(browser, "e39-warehouse-surplus.png")
	browser.open_structure(home)
	await _shot(browser, "e39-home-full.png")
	print("e39_surplus_shot_ok camp_log=%s camp_berry=%s warehouse=%s home=%s carried=%s" % [
		camp.log_count(),
		camp.container.count_of(ItemConfig.TypeId.BERRY),
		warehouse.berry_count(),
		Food.stored(home),
		lumberjack.carried_items.count_of(ItemConfig.TypeId.BERRY),
	])
	quit(0)


func _shot(browser: Window, file_name: String) -> void:
	browser.show()
	browser.grab_focus()
	for _i in 8:
		await process_frame
	await RenderingServer.frame_post_draw
	var image: Image = browser.get_texture().get_image()
	if image == null or image.is_empty():
		var screen := DisplayServer.screen_get_image(0)
		if screen == null:
			push_error("没拿到画面 %s" % file_name)
			return
		var scale := maxi(1, int(browser.content_scale_factor))
		var rect := Rect2i(browser.position, Vector2i(browser.size) * scale)
		rect = rect.intersection(Rect2i(Vector2i.ZERO, screen.get_size()))
		if rect.size.x <= 0 or rect.size.y <= 0:
			push_error("窗口矩形无效 %s %s" % [file_name, rect])
			return
		image = screen.get_region(rect)
	var path := ProjectSettings.globalize_path("res://%s" % file_name)
	image.save_png(path)
	print("saved %s size=%s" % [file_name, image.get_size()])
