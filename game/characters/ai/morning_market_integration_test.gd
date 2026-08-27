extends SceneTree

func _init() -> void:
	if FileAccess.file_exists(Game.SAVE_FILE_PATH):
		DirAccess.open("user://").remove(Game.SAVE_FILE_PATH.get_file())
	var game: Game = load("res://game/game.tscn").instantiate() as Game
	root.add_child(game)
	await process_frame
	game.game_time.all_days = 7.25
	for _i in 8:
		await process_frame
	var ok := true
	print("all_days=%s hour=%s period=%s" % [game.game_time.all_days, game.game_time.hour_of_day, game.game_time.day_time_period])
	ok = _check(ok, game.game_time.day_time_period == GameTime.DayTimePeriod.MORNING_MARKET, "starts in morning market")
	var stall_cells := {}
	var stallers := 0
	var visitors := 0
	for character in game.character_manager.characters.values():
		var c := character as Character
		var cell: int = game.character_manager.get_live_stall_cell_index_for(c.id, c.ai_behavior_token)
		if cell >= 0:
			stallers += 1
			ok = _check(ok, not stall_cells.has(cell), "unique stall cell %s" % cell)
			stall_cells[cell] = c.id
			ok = _check(ok, c.ai_behavior_text in ["前往摆摊", "摆摊"], "staller text %s" % c.ai_behavior_text)
		else:
			visitors += 1
	ok = _check(ok, stallers + visitors == game.character_manager.characters.size(), "all classified")
	print("stallers=%s visitors=%s cells=%s" % [stallers, visitors, stall_cells.keys()])
	if ok:
		print("Morning market integration tests passed")
		quit(0)
	else:
		print("Morning market integration tests failed")
		quit(1)

func _check(ok: bool, cond: bool, name: String) -> bool:
	if not cond:
		print("FAIL: %s" % name)
		return false
	print("PASS: %s" % name)
	return ok
