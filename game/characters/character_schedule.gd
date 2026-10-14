extends RefCounted
class_name CharacterSchedule

const _IDLE_WANDER_WAIT_SECONDS_MIN = 1.0
const _IDLE_WANDER_WAIT_SECONDS_MAX = 3.0
const _IDLE_WANDER_RADIUS_PIXELS = 32.0

var food_day := -1
var _initialized := false
var _sleeping := false


func reset_period() -> void:
	_initialized = false


func tick(delta_seconds: float, character: Character) -> void:
	_apply(character)
	character.ai_task_stack.tick(delta_seconds, character._get_ai_context())
	if not character.ai_task_stack.is_empty():
		return
	_fill(character)


static func is_sleep_period(character: Character) -> bool:
	return character._get_ai_context().day_time_period == GameTime.DayTimePeriod.SLEEP


func _apply(character: Character) -> void:
	var sleeping := is_sleep_period(character)
	if _initialized and sleeping == _sleeping:
		return
	if _is_on_food_errand(character):
		return
	if WorkplaceJob.is_work_task(character.ai_task_stack.peek()):
		_initialized = true
		_sleeping = sleeping
		return
	_initialized = true
	_sleeping = sleeping
	character.abandon_ai_tasks()
	if sleeping:
		if _needs_food_today(character):
			_queue_food_errand(character)
		elif character.indoors:
			character.visible = false
		else:
			_queue_enter_home(character)
	else:
		character.leave_home()


func _fill(character: Character) -> void:
	if is_sleep_period(character):
		if _needs_food_today(character):
			_queue_food_errand(character)
			return
		if not character.indoors:
			_queue_enter_home(character)
		return
	if _is_work_period(character):
		var task := WorkplaceJob.make_task(character._workplace())
		if task:
			character.push_ai_task(task)
			return
	_schedule_idle_wander(character)


func _is_work_period(character: Character) -> bool:
	return character._get_ai_context().day_time_period == GameTime.DayTimePeriod.WORK


func _is_on_food_errand(character: Character) -> bool:
	return character.ai_task_stack.peek() is CharacterAiFetchFoodTask


func _needs_food_today(character: Character) -> bool:
	return food_day != _food_cycle_index(character)


func _food_cycle_index(character: Character) -> int:
	var game_time := character._get_ai_context().game_time
	var day_index := int(game_time.all_days)
	if game_time.hour_of_day < 6:
		return day_index - 1
	return day_index


func _queue_food_errand(character: Character) -> void:
	food_day = _food_cycle_index(character)
	character.push_ai_task(CharacterAiFetchFoodTask.new({}))


func _queue_enter_home(character: Character) -> void:
	if not character.indoors:
		character.visible = true
	var enter_task := CharacterAiEnterHomeTask.new({})
	var move_task := CharacterAiMoveToWorldXTask.new({
		CharacterAiMoveToWorldXTask.KEY_TARGET_WORLD_X: character._home_world_x(),
	})
	character.push_ai_task(enter_task)
	character.push_ai_task(move_task)


func _schedule_idle_wander(character: Character) -> void:
	var wait_duration_seconds := randf_range(_IDLE_WANDER_WAIT_SECONDS_MIN, _IDLE_WANDER_WAIT_SECONDS_MAX)
	var wait_task := CharacterAiWaitDurationTask.new({
		CharacterAiWaitDurationTask.KEY_DURATION_SECONDS: wait_duration_seconds,
	})
	var move_task := CharacterAiMoveToWorldXTask.new({
		CharacterAiMoveToWorldXTask.KEY_TARGET_WORLD_X: _pick_idle_wander_target_world_x(character),
	})
	character.push_ai_task(move_task)
	character.push_ai_task(wait_task)


func _pick_idle_wander_target_world_x(character: Character) -> float:
	var map_min_world_x: float = Game.get_position_by_cell_index(0) + Game.HALF_TILE_SIZE
	var map_max_world_x: float = Game.get_position_by_cell_index(Game.MAP_CELL_COUNT - 1) + Game.HALF_TILE_SIZE
	var offset_pixels := randf_range(-_IDLE_WANDER_RADIUS_PIXELS, _IDLE_WANDER_RADIUS_PIXELS)
	if is_zero_approx(offset_pixels):
		offset_pixels = 1.0 if randf() < 0.5 else -1.0
	return clampf(character.position.x + offset_pixels, map_min_world_x, map_max_world_x)
