extends CharacterAiBehavior
class_name CharacterAiMorningMarketBehavior

var _role_chosen := false
var _is_staller := false

func get_type_id() -> CharacterAiBehaviorTypeId.TypeId:
	return CharacterAiBehaviorTypeId.TypeId.MORNING_MARKET

func schedule(context: CharacterAiContext) -> void:
	if not _role_chosen:
		_is_staller = _roll_is_staller(context)
		_role_chosen = true
	if _is_staller:
		_schedule_stall(context)
	else:
		_schedule_visit(context)

func _roll_is_staller(context: CharacterAiContext) -> bool:
	var rng := _make_day_rng(context)
	return rng.randf() < 0.5

func _make_day_rng(context: CharacterAiContext) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = context.character.id * 100003 + int(context.game_time.all_days)
	return rng

func _schedule_stall(context: CharacterAiContext) -> void:
	var character := context.character
	var cell_index := context.character_manager.get_live_stall_cell_index_for(
			character.id,
			character.ai_behavior_token
	)
	if cell_index < 0:
		cell_index = _pick_stall_cell(context)
		if cell_index < 0:
			character.push_ai_task(CharacterAiWaitDurationTask.new({
				CharacterAiWaitDurationTask.KEY_DURATION_SECONDS: 1.0,
			}))
			return
		if not context.character_manager.try_claim_stall(
				cell_index,
				character.id,
				character.ai_behavior_token
		):
			character.push_ai_task(CharacterAiWaitDurationTask.new({
				CharacterAiWaitDurationTask.KEY_DURATION_SECONDS: 1.0,
			}))
			return
	character.push_ai_task(CharacterAiWaitDurationTask.new({
		CharacterAiWaitDurationTask.KEY_DURATION_SECONDS: 600.0,
	}))
	character.push_ai_task(CharacterAiMoveToWorldXTask.new({
		CharacterAiMoveToWorldXTask.KEY_TARGET_WORLD_X: _cell_center_world_x(cell_index),
	}))

func _pick_stall_cell(context: CharacterAiContext) -> int:
	var rng := _make_day_rng(context)
	rng.randf()
	var self_cell := clampi(int(context.character.position.x / Game.TILE_SIZE), 0, Game.MAP_CELL_COUNT - 1)
	var aura_cell := _find_aura_cell(context)
	var indices: Array[int] = []
	indices.resize(Game.MAP_CELL_COUNT)
	for cell_index in Game.MAP_CELL_COUNT:
		indices[cell_index] = cell_index
	for shuffle_index in range(indices.size() - 1, 0, -1):
		var swap_index := rng.randi_range(0, shuffle_index)
		var swapped := indices[shuffle_index]
		indices[shuffle_index] = indices[swap_index]
		indices[swap_index] = swapped
	var sample_count := maxi(1, int(Game.MAP_CELL_COUNT * 0.1))
	var best_cell := -1
	var best_score := -2147483648
	for sample_index in sample_count:
		var cell_index := indices[sample_index]
		if context.character_manager.is_stall_claimed_by_other(cell_index, context.character.id):
			continue
		var score := StallCellValueCalculator.compute_score(cell_index, self_cell, aura_cell)
		if score > best_score:
			best_score = score
			best_cell = cell_index
	return best_cell

func _schedule_visit(context: CharacterAiContext) -> void:
	var stall_cells := context.character_manager.get_live_stall_cell_indices()
	if stall_cells.is_empty():
		context.character.push_ai_task(CharacterAiWaitDurationTask.new({
			CharacterAiWaitDurationTask.KEY_DURATION_SECONDS: 2.0,
		}))
		return
	for reverse_index in range(stall_cells.size() - 1, -1, -1):
		var cell_index := stall_cells[reverse_index]
		context.character.push_ai_task(CharacterAiWaitDurationTask.new({
			CharacterAiWaitDurationTask.KEY_DURATION_SECONDS: 2.0,
		}))
		context.character.push_ai_task(CharacterAiMoveToWorldXTask.new({
			CharacterAiMoveToWorldXTask.KEY_TARGET_WORLD_X: _cell_center_world_x(cell_index),
		}))

func _find_aura_cell(context: CharacterAiContext) -> int:
	for structure in context.structure_manager.index_to_structures:
		if structure and structure.config.id == StructureConfig.TypeId.SOVEREIGN_BANNER:
			return structure.cell_index
	return int(Game.MAP_CELL_COUNT / 2.0)

func _cell_center_world_x(cell_index: int) -> float:
	return Game.get_position_by_cell_index(cell_index) + Game.HALF_TILE_SIZE
