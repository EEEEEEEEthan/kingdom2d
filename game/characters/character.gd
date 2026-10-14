extends Node2D
class_name Character

const _KEY_ID = 1
const _KEY_POSITION = 2
const _KEY_AI_TASK_STACK = 3
const _KEY_HOME_CELL_INDEX = 4
const _KEY_INDOORS = 5
const _KEY_WORKPLACE_STRUCTURE_ID = 6 # 旧档字段，关系已改由 WorkplaceIndex 保存
const _KEY_CARRIED_ITEMS = 7
const _KEY_FOOD_DAY = 8
const DEFAULT_MOVE_SPEED_PIXELS_PER_SECOND = 6.0

var id: int
var home_cell_index := -1
var indoors := false
var carried_items := ItemContainer.new()
@export var move_speed_pixels_per_second := DEFAULT_MOVE_SPEED_PIXELS_PER_SECOND
@export var show_outline := true:
	set(value):
		show_outline = value
		var outline := get_node_or_null(^"HoverOutline") as HoverOutline
		if outline:
			outline.show_outline = value
var ai_task_stack := CharacterAiTaskStack.new()

var _ai_context: CharacterAiContext
var _schedule: CharacterSchedule


func _ready() -> void:
	_get_ai_context()
	_get_schedule()
	set_process(true)
	HoverOutline.attach(self)

func _process(delta_seconds: float) -> void:
	_get_schedule().tick(delta_seconds, self)

func leave_home() -> void:
	_leave_home()

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
	carried_items = ItemContainer.deserialize(data.get(_KEY_CARRIED_ITEMS, {}))
	var schedule := _get_schedule()
	schedule.food_day = data.get(_KEY_FOOD_DAY, -1)
	schedule.reset_period()
	visible = not indoors
	ai_task_stack.deserialize(data.get(_KEY_AI_TASK_STACK, {}), _get_ai_context())

func serialize() -> Dictionary:
	return {
		_KEY_ID: id,
		_KEY_POSITION: position.x,
		_KEY_AI_TASK_STACK: ai_task_stack.serialize(),
		_KEY_HOME_CELL_INDEX: home_cell_index,
		_KEY_INDOORS: indoors,
		_KEY_CARRIED_ITEMS: carried_items.serialize(),
		_KEY_FOOD_DAY: _get_schedule().food_day,
	}


func _get_ai_context() -> CharacterAiContext:
	if not _ai_context:
		_ai_context = CharacterAiContext.new(self)
	return _ai_context


func _get_schedule() -> CharacterSchedule:
	if _schedule == null:
		_schedule = CharacterSchedule.new()
	return _schedule


func display_name() -> String:
	return CharacterNames.display_name(id)


func workplace_structure_id() -> int:
	var game := Game.find(self)
	if game == null:
		return 0
	return game.employment.workplace_of(id)


func occupation_name() -> String:
	return WorkplaceJob.occupation_of(_workplace())


func current_activity() -> String:
	return CharacterActivity.describe(self)


func _workplace() -> Structure:
	var structure_id := workplace_structure_id()
	if structure_id <= 0:
		return null
	var game := Game.find(self)
	if not game:
		return null
	return game.structure_manager.get_structure_by_id(structure_id)


func _leave_home() -> void:
	if indoors:
		position.x = _home_world_x()
	indoors = false
	visible = true

func _home_world_x() -> float:
	return Game.get_position_by_cell_index(resolved_home_cell_index()) + Game.HALF_TILE_SIZE

func resolved_home_cell_index() -> int:
	if home_cell_index >= 0:
		return home_cell_index
	var cell := roundi((position.x - Game.HALF_TILE_SIZE) / float(Game.TILE_SIZE))
	return clampi(cell, 0, Game.MAP_CELL_COUNT - 1)
