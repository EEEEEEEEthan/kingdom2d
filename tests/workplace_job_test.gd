extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	load("res://game/game.gd")
	load("res://game/characters/character.gd")
	load("res://game/characters/workplace_job.gd")
	load("res://game/structures/gatherer_hut.gd")
	load("res://game/structures/warehouse.gd")
	var game = (load("res://game/game.tscn") as PackedScene).instantiate()
	root.add_child(game)
	await process_frame
	game._clear()
	var gatherer = game.spawn_resident_at_cell(10)
	gatherer.set_process(false)
	var hut = StructureConfig.gatherer_hut.instantiate()
	game.structure_manager.add_structure(hut, 14)
	var depot = StructureConfig.warehouse.instantiate()
	game.structure_manager.add_structure(depot, 30)
	var clerk = game.spawn_resident_at_cell(28)
	clerk.set_process(false)
	game.employment.assign(clerk.id, depot.id)
	_set_hour(game, 12)
	gatherer.abandon_ai_tasks()
	gatherer._process(0.05)
	if gatherer.occupation_name() != "采集者":
		push_error("采集小屋应是采集者，实际 %s" % gatherer.occupation_name())
		quit(1)
		return
	if not gatherer.ai_task_stack.peek() is CharacterAiGatherCycleTask:
		push_error("采集小屋应派采集任务")
		quit(1)
		return
	if gatherer.current_activity() != "正在去采集者小屋":
		push_error("采集活动文案不对，实际 %s" % gatherer.current_activity())
		quit(1)
		return
	clerk.abandon_ai_tasks()
	clerk._process(0.05)
	if clerk.occupation_name() != "仓库管理员":
		push_error("仓库应是仓库管理员，实际 %s" % clerk.occupation_name())
		quit(1)
		return
	if WorkplaceJob.is_work_task(clerk.ai_task_stack.peek()):
		push_error("仓库管理员不应派工")
		quit(1)
		return
	await _shot(gatherer)
	var stub_script = load("res://tests/stub_workplace.gd")
	var stub = stub_script.new()
	stub.config = StructureConfig.lumber_camp
	game.structure_manager.add_structure(stub, 50)
	WorkplaceJob.register(stub_script, "测试工", CharacterAiLogCycleTask)
	var recruit = game.spawn_resident_at_cell(48)
	recruit.set_process(false)
	game.employment.assign(recruit.id, stub.id)
	recruit.abandon_ai_tasks()
	recruit._process(0.05)
	if recruit.occupation_name() != "测试工":
		push_error("新工种注册后职业应为测试工，实际 %s" % recruit.occupation_name())
		quit(1)
		return
	if not recruit.ai_task_stack.peek() is CharacterAiLogCycleTask:
		push_error("新工种应派注册的任务")
		quit(1)
		return
	if not _character_source_has_no_job_branch():
		quit(1)
		return
	print("workplace_job_ok")
	quit(0)


func _character_source_has_no_job_branch() -> bool:
	var source := FileAccess.get_file_as_string("res://game/characters/character.gd")
	for token in ["LumberCamp", "BuildersGuild", "GathererHut", "Warehouse", "CharacterAiLogCycleTask", "CharacterAiGatherCycleTask", "CharacterAiBuildCycleTask"]:
		if source.contains(token):
			push_error("Character 仍引用工种 %s" % token)
			return false
	return true


func _shot(character) -> void:
	var dir := OS.get_environment("KINGDOM_SHOT_DIR")
	if dir.is_empty():
		return
	var game = character.get_parent()
	while game != null and not (game is Game):
		game = game.get_parent()
	var host = game.get_parent()
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1024, 64)
	viewport.transparent_bg = false
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var holder := Node2D.new()
	viewport.add_child(holder)
	game.reparent(holder)
	var layer := CanvasLayer.new()
	layer.layer = 128
	holder.add_child(layer)
	var panel := ColorRect.new()
	panel.color = Color(0.349, 0.227, 0.145)
	panel.position = Vector2(4, 16)
	panel.size = Vector2(280, 32)
	layer.add_child(panel)
	var label := Label.new()
	label.position = Vector2(8, 18)
	label.size = Vector2(270, 28)
	label.add_theme_font_override("font", load("res://fusion-pixel-10px-monospaced-zh_hant.otf"))
	label.add_theme_font_size_override("font_size", 10)
	label.add_theme_color_override("font_color", Color(0.95, 0.9, 0.8))
	var job: String = character.occupation_name()
	var identity: String = character.display_name()
	if not job.is_empty():
		identity = "%s，%s" % [identity, job]
	label.text = "%s  %s" % [identity, character.current_activity()]
	layer.add_child(label)
	await process_frame
	await process_frame
	var image: Image = viewport.get_texture().get_image()
	game.reparent(host)
	viewport.queue_free()
	if image == null:
		push_error("没拿到居民页画面")
		return
	DirAccess.make_dir_recursive_absolute(dir)
	image.save_png(dir.path_join("resident_activity.png"))


func _set_hour(game, hour: int) -> void:
	game.game_time.all_days = 8.0 + (float(hour) + 0.5) / 24.0
