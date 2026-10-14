extends Node2D
class_name Character

const KEY_ID = 1
const _KEY_POSITION = 2
const KEY_AI_TASK_STACK = 3
const _KEY_HOME_CELL_INDEX = 4
const _KEY_INDOORS = 5
const KEY_WORKPLACE_STRUCTURE_ID = 6 # 旧档字段，关系已改由 WorkplaceIndex 保存
const _KEY_CARRIED_ITEMS = 7
const _KEY_FOOD_DAY = 8
const DEFAULT_MOVE_SPEED_PIXELS_PER_SECOND = 6.0
const _IDLE_WANDER_WAIT_SECONDS_MIN = 1.0
const _IDLE_WANDER_WAIT_SECONDS_MAX = 3.0
const _IDLE_WANDER_RADIUS_PIXELS = 32.0

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
var _schedule_initialized := false
var _schedule_sleeping := false
var _food_day := -1

func _ready() -> void:
	_get_ai_context()
	set_process(true)
	HoverOutline.attach(self)

func _process(delta_seconds: float) -> void:
	_apply_daily_schedule()
	ai_task_stack.tick(delta_seconds, _get_ai_context())
	if not ai_task_stack.is_empty():
		return
	if _is_sleeping():
		if _needs_food_today():
			_queue_food_errand()
			return
		if not indoors:
			_queue_enter_home()
		return
	if _is_work_time() and workplace_structure_id() > 0 and not _workplace() is Warehouse:
		if _workplace() is BuildersGuild:
			_queue_build_cycle()
		else:
			_queue_harvest_cycle()
		return
	_schedule_idle_wander()

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

func deserialize(data: Dictionary) -> bool:
	if not data.has(KEY_ID):
		return false
	id = int(data[KEY_ID])
	position = Vector2(float(data.get(_KEY_POSITION, 0.0)), 0)
	home_cell_index = int(data.get(_KEY_HOME_CELL_INDEX, -1))
	indoors = bool(data.get(_KEY_INDOORS, false))
	var carried = data.get(_KEY_CARRIED_ITEMS, {})
	if carried is Dictionary:
		carried_items = ItemContainer.deserialize(carried)
	_food_day = int(data.get(_KEY_FOOD_DAY, -1))
	visible = not indoors
	_schedule_initialized = false
	var stack = data.get(KEY_AI_TASK_STACK, {})
	if stack is Dictionary:
		ai_task_stack.deserialize(stack, _get_ai_context())
	return true

func serialize() -> Dictionary:
	return {
		KEY_ID: id,
		_KEY_POSITION: position.x,
		KEY_AI_TASK_STACK: ai_task_stack.serialize(),
		_KEY_HOME_CELL_INDEX: home_cell_index,
		_KEY_INDOORS: indoors,
		_KEY_CARRIED_ITEMS: carried_items.serialize(),
		_KEY_FOOD_DAY: _food_day,
	}


func _get_ai_context() -> CharacterAiContext:
	if not _ai_context:
		_ai_context = CharacterAiContext.new(self)
	return _ai_context

const _GIVEN_NAMES := [
	"Aldric",
	"Baldwin",
	"Cedric",
	"Dunstan",
	"Edmund",
	"Godfrey",
	"Guy",
	"Henry",
	"Humphrey",
	"Leofric",
	"Miles",
	"Osric",
	"Ralph",
	"Roger",
	"Simon",
	"Walter",
	"Wulfric",
	"Bernard",
	"Cuthbert",
	"Gilbert",
	"Beatrice",
	"Edith",
	"Eleanor",
	"Godiva",
	"Hilda",
	"Isolde",
	"Joan",
	"Matilda",
	"Maud",
	"Rowena",
	"Winifred",
	"Cecily",
]
const _SURNAMES := [
	"Ashford",
	"Baker",
	"Blackwood",
	"Carpenter",
	"Carter",
	"Cooper",
	"Crowley",
	"Dunmore",
	"Eldridge",
	"Fairfax",
	"Fletcher",
	"Grimsby",
	"Holloway",
	"Ironwood",
	"Kingsley",
	"Lockwood",
	"Marsh",
	"Mason",
	"Mercer",
	"Norwood",
	"Oakley",
	"Pemberton",
	"Ravenscroft",
	"Smith",
	"Stonemoor",
	"Tanner",
	"Thorne",
	"Underhill",
	"Vance",
	"Weaver",
	"Whitmore",
	"Wright",
]

# 姓名由「名 + 姓」组合而来，id 与组合一一对应，储备 32×32 保证不重名。
func display_name() -> String:
	var given_count := _GIVEN_NAMES.size()
	var index := posmod(id - 1, given_count * _SURNAMES.size())
	return "%s %s" % [_GIVEN_NAMES[index % given_count], _SURNAMES[index / given_count]]

func workplace_structure_id() -> int:
	var game := Game.find(self)
	if game == null:
		return 0
	return game.employment.workplace_of(id)


func occupation_name() -> String:
	var workplace := _workplace()
	if workplace is Warehouse:
		return "仓库管理员"
	if workplace is LumberCamp:
		return "伐木工"
	if workplace is BuildersGuild:
		return "建筑工"
	if workplace_structure_id() > 0:
		return "采集者"
	return ""

func current_activity() -> String:
	if indoors and _is_sleeping():
		return "正在睡觉"
	if indoors:
		return "正在家里"
	var top := ai_task_stack.peek()
	if top == null:
		return "正在发呆"
	if top is CharacterAiEnterHomeTask:
		return "正在进屋"
	if top is CharacterAiHarvestCycleTask:
		return (top as CharacterAiHarvestCycleTask).activity_text()
	if top is CharacterAiBuildCycleTask:
		return (top as CharacterAiBuildCycleTask).activity_text()
	if top is CharacterAiFetchFoodTask:
		return (top as CharacterAiFetchFoodTask).activity_text()
	if top is CharacterAiMoveToWorldXTask and ai_task_stack.has_task(CharacterAiEnterHomeTask):
		return "正在回家"
	if top is CharacterAiWaitDurationTask:
		return "正在歇着"
	if top is CharacterAiMoveToWorldXTask:
		return "正在闲逛"
	return "正在发呆"

func _is_sleeping() -> bool:
	return _get_ai_context().day_time_period == GameTime.DayTimePeriod.SLEEP

func _is_work_time() -> bool:
	return _get_ai_context().day_time_period == GameTime.DayTimePeriod.WORK

func _apply_daily_schedule() -> void:
	var sleeping := _is_sleeping()
	if _schedule_initialized and sleeping == _schedule_sleeping:
		return
	if _is_on_food_errand():
		return
	if _is_on_harvest_cycle() or _is_on_build_cycle():
		_schedule_initialized = true
		_schedule_sleeping = sleeping
		return
	_schedule_initialized = true
	_schedule_sleeping = sleeping
	abandon_ai_tasks()
	if sleeping:
		if _needs_food_today():
			_queue_food_errand()
		elif indoors:
			visible = false
		else:
			_queue_enter_home()
	else:
		_leave_home()

func _workplace() -> Structure:
	var structure_id := workplace_structure_id()
	if structure_id <= 0:
		return null
	var game := Game.find(self)
	if not game:
		return null
	return game.structure_manager.get_structure_by_id(structure_id)


func _queue_harvest_cycle() -> void:
	var workplace := _workplace()
	var type_id := (
		CharacterAiTaskTypeId.TypeId.LOG_CYCLE
		if workplace is LumberCamp
		else CharacterAiTaskTypeId.TypeId.GATHER_CYCLE
	)
	push_ai_task(CharacterAiHarvestCycleTask.new({}, type_id))

func _is_on_harvest_cycle() -> bool:
	return ai_task_stack.peek() is CharacterAiHarvestCycleTask


func _queue_build_cycle() -> void:
	push_ai_task(CharacterAiBuildCycleTask.new({}))

func _is_on_build_cycle() -> bool:
	return ai_task_stack.peek() is CharacterAiBuildCycleTask


func _is_on_food_errand() -> bool:
	return ai_task_stack.peek() is CharacterAiFetchFoodTask


func _needs_food_today() -> bool:
	return _food_day != _food_cycle_index()


func _food_cycle_index() -> int:
	var game_time := _get_ai_context().game_time
	var day_index := int(game_time.all_days)
	if game_time.hour_of_day < 6:
		return day_index - 1
	return day_index


func _queue_food_errand() -> void:
	_food_day = _food_cycle_index()
	push_ai_task(CharacterAiFetchFoodTask.new({}))

func _queue_enter_home() -> void:
	if not indoors:
		visible = true
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
	return Game.get_position_by_cell_index(resolved_home_cell_index()) + Game.HALF_TILE_SIZE

func resolved_home_cell_index() -> int:
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
