extends Node2D
class_name Character

const _KEY_ID = 1
const _KEY_POSITION = 2
const _KEY_AI_TASK_STACK = 3
const _KEY_GENDER = 4
const _KEY_HAIR = 5
const _KEY_EYES = 6
const _KEY_SKIN = 7
const DEFAULT_MOVE_SPEED_PIXELS_PER_SECOND = 6.0
const _IDLE_WANDER_WAIT_SECONDS_MIN = 1.0
const _IDLE_WANDER_WAIT_SECONDS_MAX = 3.0
const _IDLE_WANDER_RADIUS_PIXELS = 32.0

var id: int
@export var move_speed_pixels_per_second := DEFAULT_MOVE_SPEED_PIXELS_PER_SECOND
var ai_task_stack := CharacterAiTaskStack.new()
var gender_id := 0
var hair_id := 0
var eyes_id := 0
var skin_id := 0
var head: PixelHead

var _ai_context: CharacterAiContext

func _ready() -> void:
	_get_ai_context()
	_ensure_head()
	set_process(true)


func set_appearance(next_gender_id: int, next_hair_id: int, next_eyes_id: int, next_skin_id: int) -> void:
	gender_id = next_gender_id
	hair_id = next_hair_id
	eyes_id = next_eyes_id
	skin_id = next_skin_id
	if is_node_ready():
		_ensure_head()

func _process(delta_seconds: float) -> void:
	ai_task_stack.tick(delta_seconds, _get_ai_context())
	if ai_task_stack.is_empty():
		_schedule_idle_wander()

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
	ai_task_stack.deserialize(data.get(_KEY_AI_TASK_STACK, {}), _get_ai_context())
	set_appearance(
		data.get(_KEY_GENDER, 0),
		data.get(_KEY_HAIR, 0),
		data.get(_KEY_EYES, 0),
		data.get(_KEY_SKIN, 0),
	)

func serialize() -> Dictionary:
	return {
		_KEY_ID: id,
		_KEY_POSITION: position.x,
		_KEY_AI_TASK_STACK: ai_task_stack.serialize(),
		_KEY_GENDER: gender_id,
		_KEY_HAIR: hair_id,
		_KEY_EYES: eyes_id,
		_KEY_SKIN: skin_id,
	}


func _ensure_head() -> void:
	head = get_node_or_null("PixelHead") as PixelHead
	if head == null:
		head = PixelHead.create(gender_id, hair_id, eyes_id, skin_id)
		head.position = Vector2(0, -12)
		add_child(head)
		return
	head.apply(gender_id, hair_id, eyes_id, skin_id)

func _get_ai_context() -> CharacterAiContext:
	if not _ai_context:
		_ai_context = CharacterAiContext.new(self)
	return _ai_context

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
