extends RefCounted
class_name CharacterAiTask

enum Status {
	RUNNING,
	SUCCEEDED,
	FAILED,
}

const KEY_TYPE_ID = 1
const KEY_PAYLOAD = 2

static func is_unknown_type(data: Dictionary) -> bool:
	if not data.has(KEY_TYPE_ID):
		return false
	var type_id := int(data[KEY_TYPE_ID])
	if type_id == CharacterAiTaskTypeId.TypeId.NONE:
		return false
	return _open(type_id, {}, true) == null

static func deserialize(data: Dictionary) -> CharacterAiTask:
	if not data.has(KEY_TYPE_ID):
		return null
	var opened = _open(int(data[KEY_TYPE_ID]), _payload_of(data))
	if opened is CharacterAiTask:
		return opened
	return null

## 已知类型、缺必填键时返回 false；未知类型返回 null。类型只在这里列一次。
static func _open(type_id: int, payload: Dictionary, presence_only := false) -> Variant:
	match type_id:
		CharacterAiTaskTypeId.TypeId.WAIT_DURATION:
			if presence_only:
				return false
			if not payload.has(CharacterAiWaitDurationTask.KEY_DURATION_SECONDS):
				return false
			return CharacterAiWaitDurationTask.new(payload)
		CharacterAiTaskTypeId.TypeId.MOVE_TO_WORLD_X:
			if presence_only:
				return false
			if not payload.has(CharacterAiMoveToWorldXTask.KEY_TARGET_WORLD_X):
				return false
			return CharacterAiMoveToWorldXTask.new(payload)
		CharacterAiTaskTypeId.TypeId.ENTER_HOME:
			if presence_only:
				return false
			return CharacterAiEnterHomeTask.new(payload)
		CharacterAiTaskTypeId.TypeId.GATHER_CYCLE:
			if presence_only:
				return false
			return CharacterAiHarvestCycleTask.new(payload, CharacterAiTaskTypeId.TypeId.GATHER_CYCLE)
		CharacterAiTaskTypeId.TypeId.FETCH_FOOD:
			if presence_only:
				return false
			return CharacterAiFetchFoodTask.new(payload)
		CharacterAiTaskTypeId.TypeId.LOG_CYCLE:
			if presence_only:
				return false
			return CharacterAiHarvestCycleTask.new(payload, CharacterAiTaskTypeId.TypeId.LOG_CYCLE)
		CharacterAiTaskTypeId.TypeId.BUILD_CYCLE:
			if presence_only:
				return false
			return CharacterAiBuildCycleTask.new(payload)
		_:
			return null

static func _payload_of(data: Dictionary) -> Dictionary:
	var raw = data.get(KEY_PAYLOAD, {})
	if raw is Dictionary:
		return raw
	return {}

func get_type_id() -> CharacterAiTaskTypeId.TypeId:
	return CharacterAiTaskTypeId.TypeId.NONE

func serialize() -> Dictionary:
	return {
		KEY_TYPE_ID: get_type_id(),
		KEY_PAYLOAD: _serialize_payload(),
	}

func _serialize_payload() -> Dictionary:
	return {}

func on_enter(_context: CharacterAiContext) -> void:
	pass

func tick(_delta_seconds: float, _context: CharacterAiContext) -> Status:
	return Status.SUCCEEDED

func on_exit(_context: CharacterAiContext) -> void:
	pass
