extends RefCounted
class_name WorkplaceJob

## 工种只在这里登记一次：工作地点、职业名、上班时压入的任务。
## 仓库管理员没有任务，工时里不派工。

class Entry:
	var workplace_script: GDScript
	var occupation: String
	var task_script: GDScript

static var _entries: Array[Entry] = []
static var _builtins_ready := false


static func register(workplace_script: GDScript, occupation: String, task_script: GDScript) -> void:
	var entry: Entry = Entry.new()
	entry.workplace_script = workplace_script
	entry.occupation = occupation
	entry.task_script = task_script
	_entries.append(entry)


static func occupation_of(workplace: Structure) -> String:
	var entry: Entry = _entry_for(workplace)
	if entry == null:
		return ""
	return entry.occupation


static func make_task(workplace: Structure) -> CharacterAiTask:
	var entry: Entry = _entry_for(workplace)
	if entry == null or entry.task_script == null:
		return null
	return entry.task_script.new({}) as CharacterAiTask


static func is_work_task(task: CharacterAiTask) -> bool:
	_ensure_builtins()
	if task == null:
		return false
	var script: Script = task.get_script()
	for entry in _entries:
		if entry.task_script != null and script == entry.task_script:
			return true
	return false


static func _entry_for(workplace: Structure) -> Entry:
	_ensure_builtins()
	if workplace == null:
		return null
	for entry in _entries:
		if is_instance_of(workplace, entry.workplace_script):
			return entry
	return null


static func _ensure_builtins() -> void:
	if _builtins_ready:
		return
	_builtins_ready = true
	register(LumberCamp, "伐木工", CharacterAiLogCycleTask)
	register(BuildersGuild, "建筑工", CharacterAiBuildCycleTask)
	register(GathererHut, "采集者", CharacterAiGatherCycleTask)
	register(Warehouse, "仓库管理员", null)
