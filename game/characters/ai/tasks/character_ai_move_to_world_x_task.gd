extends CharacterAiTask
class_name CharacterAiMoveToWorldXTask

const KEY_TARGET_WORLD_X = 1

var _target_world_x: float

func _init(save_payload: Dictionary) -> void:
	_target_world_x = float(save_payload[KEY_TARGET_WORLD_X])

func get_type_id() -> CharacterAiTaskTypeId.TypeId:
	return CharacterAiTaskTypeId.TypeId.MOVE_TO_WORLD_X

func tick(delta_seconds: float, context: CharacterAiContext) -> Status:
	if context.character.advance_toward_world_x(delta_seconds, _target_world_x):
		return Status.SUCCEEDED
	return Status.RUNNING

func _serialize_payload() -> Dictionary:
	return {KEY_TARGET_WORLD_X: _target_world_x}
