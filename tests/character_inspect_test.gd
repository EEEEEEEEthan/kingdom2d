extends SceneTree

func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	load("res://game/time.gd")
	load("res://game/game.gd")
	load("res://game/characters/character.gd")
	load("res://game/characters/character_manager.gd")
	load("res://game/characters/ai/character_ai_task.gd")
	load("res://game/characters/ai/character_ai_task_stack.gd")
	load("res://game/characters/ai/tasks/character_ai_gather_cycle_task.gd")
	load("res://game/characters/ai/tasks/character_ai_move_to_world_x_task.gd")
	load("res://game/characters/ai/tasks/character_ai_enter_home_task.gd")
	load("res://game/characters/ai/tasks/character_ai_wait_duration_task.gd")
	var game = (load("res://game/game.tscn") as PackedScene).instantiate()
	root.add_child(game)
	await process_frame
	game._clear()
	var character = game.spawn_resident_at_cell(10)
	character.set_process(false)
	if character.display_name() != "阿禾":
		push_error("id 1 姓名应为阿禾，实际 %s" % character.display_name())
		quit(1)
		return
	if character.occupation_name() != "无业":
		push_error("未分配工作时应无业")
		quit(1)
		return
	_set_hour(game, 12)
	character._process(0.05)
	if character.current_activity() != "正在闲逛" and character.current_activity() != "正在歇着":
		push_error("白天无业应在闲逛或歇着，实际 %s" % character.current_activity())
		quit(1)
		return
	character.workplace_structure_id = 1
	character.abandon_ai_tasks()
	character._process(0.05)
	if character.occupation_name() != "采集者":
		push_error("有工作地点时应是采集者")
		quit(1)
		return
	if character.current_activity() != "正在去采集者小屋":
		push_error("开始采集周期应去小屋，实际 %s" % character.current_activity())
		quit(1)
		return
	_set_hour(game, 21)
	character.abandon_ai_tasks()
	character.workplace_structure_id = 0
	character.indoors = false
	character.visible = true
	character.position.x += 24.0
	character._process(0.05)
	if character.current_activity() != "正在回家":
		push_error("夜晚在外应回家，实际 %s" % character.current_activity())
		quit(1)
		return
	character.enter_home()
	if character.current_activity() != "正在睡觉":
		push_error("夜里在家应睡觉，实际 %s" % character.current_activity())
		quit(1)
		return
	var window = (load("res://game/characters/character_window.tscn") as PackedScene).instantiate()
	root.add_child(window)
	window.open_for(character)
	await process_frame
	if window.get_node("%ActivityLabel").text != "正在睡觉":
		push_error("窗口应显示正在睡觉")
		quit(1)
		return
	_set_hour(game, 12)
	character.leave_home()
	character._process(0.05)
	window._process(0.0)
	var activity_text: String = window.get_node("%ActivityLabel").text
	if activity_text == "正在睡觉":
		push_error("白天窗口应刷新掉睡觉，实际 %s" % activity_text)
		quit(1)
		return
	var gather := CharacterAiGatherCycleTask.new({CharacterAiGatherCycleTask.KEY_PHASE: 2})
	if gather.activity_text() != "正在采集":
		push_error("去灌木应显示正在采集，实际 %s" % gather.activity_text())
		quit(1)
		return
	gather = CharacterAiGatherCycleTask.new({CharacterAiGatherCycleTask.KEY_PHASE: 4})
	if gather.activity_text() != "正在回采集者小屋":
		push_error("返回应显示正在回采集者小屋，实际 %s" % gather.activity_text())
		quit(1)
		return
	quit(0)


func _set_hour(game, hour: int) -> void:
	game.game_time.all_days = float(hour) / 24.0
