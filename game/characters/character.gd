extends Node2D
class_name Character

const _KEY_ID = 1
const _KEY_POSITION = 2
const _KEY_AI_TASK_STACK = 3
const _KEY_HOME_ID = 4
const _KEY_JOB_ID = 5

var home_structure_id: int = 0
var job_structure_id: int = 0
const DEFAULT_MOVE_SPEED_PIXELS_PER_SECOND = 6.0
const _IDLE_WANDER_WAIT_SECONDS_MIN = 1.0
const _IDLE_WANDER_WAIT_SECONDS_MAX = 3.0
const _IDLE_WANDER_RADIUS_PIXELS = 32.0

var id: int
@export var move_speed_pixels_per_second := DEFAULT_MOVE_SPEED_PIXELS_PER_SECOND
var ai_task_stack := CharacterAiTaskStack.new()

var _ai_context: CharacterAiContext

func _ready() -> void:
	_get_ai_context()
	set_process(true)

func _process(delta_seconds: float) -> void:
	ai_task_stack.tick(delta_seconds, _get_ai_context())
	if ai_task_stack.is_empty():
		if not _try_start_work():
			_idle_or_go_home()


func assign_job(structure_id: int) -> void:
	job_structure_id = structure_id
	abandon_ai_tasks()


func clear_job() -> void:
	job_structure_id = 0
	abandon_ai_tasks()

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
	home_structure_id = int(data.get(_KEY_HOME_ID, 0))
	job_structure_id = int(data.get(_KEY_JOB_ID, 0))
	ai_task_stack.deserialize(data.get(_KEY_AI_TASK_STACK, {}), _get_ai_context())

func serialize() -> Dictionary:
	return {
		_KEY_ID: id,
		_KEY_POSITION: position.x,
		_KEY_AI_TASK_STACK: ai_task_stack.serialize(),
		_KEY_HOME_ID: home_structure_id,
		_KEY_JOB_ID: job_structure_id,
	}

func _get_ai_context() -> CharacterAiContext:
	if not _ai_context:
		_ai_context = CharacterAiContext.new(self)
	return _ai_context

func _try_start_work() -> bool:
	if job_structure_id <= 0:
		return false
	var game := _find_game()
	if game == null:
		return false
	# 班次用现有昼夜。工作单元还在栈上时不会进到这里，所以单元结束前不下班。
	if game.game_time.day_time_period != GameTime.DayTimePeriod.WORK:
		return false
	var site := game.structure_manager.get_structure_by_id(job_structure_id)
	if not site is WorkSite:
		return false
	var sites: Array = []
	for structure in game.structure_manager.index_to_structures:
		if structure is WorkSite:
			sites.append(structure)
	var unit := WorkSite.plan_job(site, sites)
	if unit == null:
		var site_x := float(site.cell_index) * float(Game.TILE_SIZE) + float(Game.HALF_TILE_SIZE)
		if absf(position.x - site_x) > 1.0:
			push_ai_task(CharacterAiMoveToWorldXTask.new({
				CharacterAiMoveToWorldXTask.KEY_TARGET_WORLD_X: site_x,
			}))
		else:
			push_ai_task(CharacterAiWaitDurationTask.new({
				CharacterAiWaitDurationTask.KEY_DURATION_SECONDS: 0.5,
			}))
		return true
	push_ai_task(CharacterAiWorkUnitTask.new(unit.to_payload()))
	return true


func _idle_or_go_home() -> void:
	if home_structure_id > 0:
		var game := _find_game()
		if game:
			var home := game.structure_manager.get_structure_by_id(home_structure_id)
			if home:
				var home_x := float(home.cell_index) * float(Game.TILE_SIZE) + float(Game.HALF_TILE_SIZE)
				if absf(position.x - home_x) > 1.0:
					push_ai_task(CharacterAiMoveToWorldXTask.new({
						CharacterAiMoveToWorldXTask.KEY_TARGET_WORLD_X: home_x,
					}))
					return
	_schedule_idle_wander()


func _find_game() -> Game:
	var node: Node = self
	while node:
		if node is Game:
			return node
		node = node.get_parent()
	return null


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
