extends Node2D
class_name Character

const _KEY_ID = 1
const _KEY_POSITION = 2
const _KEY_AI_TASK_STACK = 3

var id: int
var ai_task_stack := CharacterAiTaskStack.new()

var _ai_context: CharacterAiContext

func _ready() -> void:
	_get_ai_context()
	set_process(true)

func _process(delta_seconds: float) -> void:
	ai_task_stack.tick(delta_seconds, _get_ai_context())

func push_ai_task(task: CharacterAiTask) -> void:
	ai_task_stack.push(task, _get_ai_context())

func abandon_ai_tasks() -> void:
	ai_task_stack.abandon(_get_ai_context())

func deserialize(data: Dictionary) -> void:
	id = data[_KEY_ID]
	position = Vector2(data[_KEY_POSITION], 0)
	ai_task_stack.deserialize(data.get(_KEY_AI_TASK_STACK, {}), _get_ai_context())

func serialize() -> Dictionary:
	return {
		_KEY_ID: id,
		_KEY_POSITION: position.x,
		_KEY_AI_TASK_STACK: ai_task_stack.serialize(),
	}

func _get_ai_context() -> CharacterAiContext:
	if not _ai_context:
		_ai_context = CharacterAiContext.new(self)
	return _ai_context
