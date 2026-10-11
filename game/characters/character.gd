extends Node2D
class_name Character

const _KEY_ID = 1
const _KEY_POSITION = 2
const _KEY_AI_TASK_STACK = 3
const _KEY_HOME_CELL_INDEX = 4
const _KEY_INDOORS = 5
const DEFAULT_MOVE_SPEED_PIXELS_PER_SECOND = 6.0
const _IDLE_WANDER_WAIT_SECONDS_MIN = 1.0
const _IDLE_WANDER_WAIT_SECONDS_MAX = 3.0
const _IDLE_WANDER_RADIUS_PIXELS = 32.0
const _SLEEP_START_HOUR = 20
const _WAKE_HOUR = 5

var id: int
var home_cell_index := -1
var indoors := false
@export var move_speed_pixels_per_second := DEFAULT_MOVE_SPEED_PIXELS_PER_SECOND
var ai_task_stack := CharacterAiTaskStack.new()

var _ai_context: CharacterAiContext
var _schedule_initialized := false
var _schedule_sleeping := false

func _ready() -> void:
	_get_ai_context()
	set_process(true)

func _process(delta_seconds: float) -> void:
	_apply_daily_schedule()
	ai_task_stack.tick(delta_seconds, _get_ai_context())
	if ai_task_stack.is_empty() and not _is_sleeping():
		_schedule_idle_wander()

func enter_home() -> void:
	position.x = _home_world_x()
	indoors = true
	visible = false

func push_ai_task(task: CharacterAiTask) -> void:
	ai_task_stack.push(task, _get_ai_context())

func abandon_ai_tasks() -> void:
	ai_task_stack.abandon(_get_ai_context())

func advance_toward_world_x(delta_seconds: float, target_world_x: float) -> bool:
	var offset := target_world_x - position.x
	if is_zero_approx(offset):
		return true
	var step := move_speed_pixels_per_second * delta_seconds
	if absf(offset) <= step:
		position.x = target_world_x
		return true
	position.x += signf(offset) * step
	return false

func deserialize(data: Dictionary) -> void:
	id = data[_KEY_ID]
	position = Vector2(data[_KEY_POSITION], 0)
	home_cell_index = data.get(_KEY_HOME_CELL_INDEX, -1)
	indoors = data.get(_KEY_INDOORS, false)
	visible = not indoors
	_schedule_initialized = false
	ai_task_stack.deserialize(data.get(_KEY_AI_TASK_STACK, {}), _get_ai_context())

func serialize() -> Dictionary:
	return {
		_KEY_ID: id,
		_KEY_POSITION: position.x,
		_KEY_AI_TASK_STACK: ai_task_stack.serialize(),
		_KEY_HOME_CELL_INDEX: home_cell_index,
		_KEY_INDOORS: indoors,
	}


func _get_ai_context() -> CharacterAiContext:
	if not _ai_context:
		_ai_context = CharacterAiContext.new(self)
	return _ai_context

func _is_sleeping() -> bool:
	var hour := _get_ai_context().game_time.hour_of_day
	return hour >= _SLEEP_START_HOUR or hour < _WAKE_HOUR

func _apply_daily_schedule() -> void:
	var sleeping := _is_sleeping()
	if _schedule_initialized and sleeping == _schedule_sleeping:
		return
	_schedule_initialized = true
	_schedule_sleeping = sleeping
	abandon_ai_tasks()
	if sleeping:
		if indoors:
			visible = false
		else:
			_queue_enter_home()
	else:
		_leave_home()

func _queue_enter_home() -> void:
	var enter_task := CharacterAiEnterHomeTask.new({})
	var move_task := CharacterAiMoveToWorldXTask.new({
		CharacterAiMoveToWorldXTask.KEY_TARGET_WORLD_X: _home_world_x(),
	})
	push_ai_task(enter_task)
	push_ai_task(move_task)

func _leave_home() -> void:
	if indoors:
		position.x = _home_world_x()
	indoors = false
	visible = true

func _home_world_x() -> float:
	return Game.get_position_by_cell_index(_resolved_home_cell_index()) + Game.HALF_TILE_SIZE

func _resolved_home_cell_index() -> int:
	if home_cell_index >= 0:
		return home_cell_index
	var cell := roundi((position.x - Game.HALF_TILE_SIZE) / float(Game.TILE_SIZE))
	return clampi(cell, 0, Game.MAP_CELL_COUNT - 1)

func _schedule_idle_wander() -> void:
	var wait_duration_seconds := randf_range(_IDLE_WANDER_WAIT_SECONDS_MIN, _IDLE_WANDER_WAIT_SECONDS_MAX)
	var wait_task := CharacterAiWaitDurationTask.new({
		CharacterAiWaitDurationTask.KEY_DURATION_SECONDS: wait_duration_seconds,
	})
	var move_task := CharacterAiMoveToWorldXTask.new({
		CharacterAiMoveToWorldXTask.KEY_TARGET_WORLD_X: _pick_idle_wander_target_world_x(),
	})
	push_ai_task(move_task)
	push_ai_task(wait_task)

func _pick_idle_wander_target_world_x() -> float:
	var map_min_world_x: float = Game.get_position_by_cell_index(0) + Game.HALF_TILE_SIZE
	var map_max_world_x: float = Game.get_position_by_cell_index(Game.MAP_CELL_COUNT - 1) + Game.HALF_TILE_SIZE
	var offset_pixels := randf_range(-_IDLE_WANDER_RADIUS_PIXELS, _IDLE_WANDER_RADIUS_PIXELS)
	if is_zero_approx(offset_pixels):
		offset_pixels = 1.0 if randf() < 0.5 else -1.0
	return clampf(position.x + offset_pixels, map_min_world_x, map_max_world_x)
