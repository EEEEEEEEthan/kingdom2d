extends CharacterAiTask
class_name CharacterAiWaitDurationTask

const KEY_ELAPSED_SECONDS = 1
const KEY_DURATION_SECONDS = 2

var _elapsed_seconds: float
var _duration_seconds: float

func _init(save_payload: Dictionary) -> void:
	_duration_seconds = save_payload[KEY_DURATION_SECONDS]
	_elapsed_seconds = save_payload.get(KEY_ELAPSED_SECONDS, 0.0)

func get_type_id() -> CharacterAiTaskTypeId.TypeId:
	return CharacterAiTaskTypeId.TypeId.WAIT_DURATION

func tick(delta_seconds: float, _context: CharacterAiContext) -> Status:
	_elapsed_seconds += delta_seconds
	if _elapsed_seconds >= _duration_seconds:
		return Status.SUCCEEDED
	return Status.RUNNING

func _serialize_payload() -> Dictionary:
	return {
		KEY_ELAPSED_SECONDS: _elapsed_seconds,
		KEY_DURATION_SECONDS: _duration_seconds,
	}
