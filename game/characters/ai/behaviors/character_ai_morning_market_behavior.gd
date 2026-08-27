extends CharacterAiBehavior
class_name CharacterAiMorningMarketBehavior

func get_type_id() -> CharacterAiBehaviorTypeId.TypeId:
	return CharacterAiBehaviorTypeId.TypeId.MORNING_MARKET


func schedule(context: CharacterAiContext) -> void:
	if context.cell_traffic.is_character_stalling(
			context.character,
			context.character_manager
	):
		_push_stall_wait(context)
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = context.character.id + int(context.game_time.all_days)
	if rng.randf() < 0.5:
		_schedule_stall(context)
	else:
		_schedule_visit_stalls(context)


func _schedule_stall(context: CharacterAiContext) -> void:
	var cell_index := context.cell_traffic.pick_hottest_unclaimed_cell(
			context.character_manager
	)
	if cell_index < 0:
		_schedule_visit_stalls(context)
		return
	if not context.cell_traffic.try_claim_stall(
			cell_index,
			context.character,
			context.character_manager
	):
		_schedule_visit_stalls(context)
		return
	_push_stall_wait(context)
	context.character.push_ai_task(CharacterAiMoveToWorldXTask.new({
		CharacterAiMoveToWorldXTask.KEY_TARGET_WORLD_X: _cell_center_world_x(cell_index),
	}))


func _schedule_visit_stalls(context: CharacterAiContext) -> void:
	var stall_cells := context.cell_traffic.get_live_stall_cell_indices(
			context.character_manager
	)
	if stall_cells.is_empty():
		context.character.push_ai_task(CharacterAiWaitDurationTask.new({
			CharacterAiWaitDurationTask.KEY_DURATION_SECONDS: 1.0,
		}))
		return
	for index in range(stall_cells.size() - 1, -1, -1):
		var cell_index: int = stall_cells[index]
		context.character.push_ai_task(CharacterAiWaitDurationTask.new({
			CharacterAiWaitDurationTask.KEY_DURATION_SECONDS: 2.0,
		}))
		context.character.push_ai_task(CharacterAiMoveToWorldXTask.new({
			CharacterAiMoveToWorldXTask.KEY_TARGET_WORLD_X: _cell_center_world_x(cell_index),
		}))


func _push_stall_wait(context: CharacterAiContext) -> void:
	context.character.push_ai_task(CharacterAiWaitDurationTask.new({
		CharacterAiWaitDurationTask.KEY_DURATION_SECONDS: 600.0,
	}))


func _cell_center_world_x(cell_index: int) -> float:
	return Game.get_position_by_cell_index(cell_index) + Game.HALF_TILE_SIZE
