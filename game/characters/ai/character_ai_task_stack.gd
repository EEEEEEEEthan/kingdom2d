extends RefCounted
class_name CharacterAiTaskStack

## 任务自底向上执行；栈顶返回 FAILED 时整栈废弃。

const KEY_TASKS = 1

var _tasks: Array[CharacterAiTask] = []
var _preserved: Array[Dictionary] = []

func is_empty() -> bool:
	return _tasks.is_empty()

func peek() -> CharacterAiTask:
	if _tasks.is_empty():
		return null
	return _tasks[_tasks.size() - 1]

func has_task(task_script: Script) -> bool:
	for task in _tasks:
		if task.get_script() == task_script:
			return true
	return false

func push(task: CharacterAiTask, context: CharacterAiContext) -> void:
	_tasks.append(task)
	task.on_enter(context)

func abandon(context: CharacterAiContext) -> void:
	while not _tasks.is_empty():
		var task: CharacterAiTask = _tasks.pop_back()
		task.on_exit(context)
	_tasks.clear()

func tick(delta_seconds: float, context: CharacterAiContext) -> void:
	if _tasks.is_empty():
		return
	var top_task: CharacterAiTask = _tasks[_tasks.size() - 1]
	match top_task.tick(delta_seconds, context):
		CharacterAiTask.Status.RUNNING:
			pass
		CharacterAiTask.Status.SUCCEEDED:
			_complete_top_task(context)
		CharacterAiTask.Status.FAILED:
			abandon(context)

func serialize() -> Dictionary:
	var serialized_tasks: Array[Dictionary] = []
	for task in _tasks:
		serialized_tasks.append(task.serialize())
	for raw in _preserved:
		serialized_tasks.append(raw)
	return {KEY_TASKS: serialized_tasks}

func deserialize(data: Dictionary, context: CharacterAiContext) -> void:
	abandon(context)
	_preserved.clear()
	var listed = data.get(KEY_TASKS, [])
	if not listed is Array:
		return
	for task_data in listed:
		if not task_data is Dictionary:
			continue
		if CharacterAiTask.is_unknown_type(task_data):
			_preserved.append(task_data.duplicate(true))
			continue
		var task := CharacterAiTask.deserialize(task_data)
		if task:
			push(task, context)

func _complete_top_task(context: CharacterAiContext) -> void:
	var finished_task: CharacterAiTask = _tasks.pop_back()
	finished_task.on_exit(context)
	if not _tasks.is_empty():
		_tasks[_tasks.size() - 1].on_enter(context)
