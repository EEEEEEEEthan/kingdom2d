extends CharacterAiBehavior
class_name CharacterAiIdleWanderBehavior

func get_type_id() -> CharacterAiBehaviorTypeId.TypeId:
	return CharacterAiBehaviorTypeId.TypeId.IDLE_WANDER

func schedule(context: CharacterAiContext) -> void:
	var wait_task := CharacterAiWaitDurationTask.new({
		CharacterAiWaitDurationTask.KEY_DURATION_SECONDS: randf_range(1.0, 3.0),
	})
	var move_task := CharacterAiMoveToWorldXTask.new({
		CharacterAiMoveToWorldXTask.KEY_TARGET_WORLD_X: _pick_wander_world_x(context.character),
	})
	context.character.push_ai_task(move_task)
	context.character.push_ai_task(wait_task)

func _pick_wander_world_x(character: Character) -> float:
	var map_min_world_x: float = Game.get_position_by_cell_index(0) + Game.HALF_TILE_SIZE
	var map_max_world_x: float = Game.get_position_by_cell_index(Game.MAP_CELL_COUNT - 1) + Game.HALF_TILE_SIZE
	var offset_pixels := randf_range(-32.0, 32.0)
	if is_zero_approx(offset_pixels):
		offset_pixels = 1.0 if randf() < 0.5 else -1.0
	return clampf(character.position.x + offset_pixels, map_min_world_x, map_max_world_x)
