extends RefCounted
class_name CharacterAiTask

enum Status {
	RUNNING,
	SUCCEEDED,
	FAILED,
}

const _KEY_TYPE_ID = 1
const _KEY_PAYLOAD = 2

static func deserialize(data: Dictionary) -> CharacterAiTask:
	var type_id: CharacterAiTaskTypeId.TypeId = data[_KEY_TYPE_ID] as CharacterAiTaskTypeId.TypeId
	var payload: Dictionary = data.get(_KEY_PAYLOAD, {})
	match type_id:
		CharacterAiTaskTypeId.TypeId.WAIT_DURATION:
			return CharacterAiWaitDurationTask.new(payload)
		CharacterAiTaskTypeId.TypeId.MOVE_TO_WORLD_X:
			return CharacterAiMoveToWorldXTask.new(payload)
		CharacterAiTaskTypeId.TypeId.ENTER_HOME:
			return CharacterAiEnterHomeTask.new(payload)
		CharacterAiTaskTypeId.TypeId.GATHER_CYCLE:
			return CharacterAiGatherCycleTask.new(payload)
		CharacterAiTaskTypeId.TypeId.FETCH_FOOD:
			return CharacterAiFetchFoodTask.new(payload)
		CharacterAiTaskTypeId.TypeId.LOG_CYCLE:
			return CharacterAiLogCycleTask.new(payload)
		CharacterAiTaskTypeId.TypeId.BUILD_CYCLE:
			return CharacterAiBuildCycleTask.new(payload)
		_:
			printerr("CharacterAiTask type_id not found: %s" % type_id)
			return null

func get_type_id() -> CharacterAiTaskTypeId.TypeId:
	return CharacterAiTaskTypeId.TypeId.NONE

func activity_text() -> String:
	return ""

func serialize() -> Dictionary:
	return {
		_KEY_TYPE_ID: get_type_id(),
		_KEY_PAYLOAD: _serialize_payload(),
	}

func _serialize_payload() -> Dictionary:
	return {}

func on_enter(_context: CharacterAiContext) -> void:
	pass

func tick(_delta_seconds: float, _context: CharacterAiContext) -> Status:
	return Status.SUCCEEDED

func on_exit(_context: CharacterAiContext) -> void:
	pass
