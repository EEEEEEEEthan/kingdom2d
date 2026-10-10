extends CharacterAiTask
class_name CharacterAiEnterHomeTask

## 走到门口之后进房，角色从场景上消失。

func _init(_save_payload: Dictionary) -> void:
	pass

func get_type_id() -> CharacterAiTaskTypeId.TypeId:
	return CharacterAiTaskTypeId.TypeId.ENTER_HOME

func tick(_delta_seconds: float, context: CharacterAiContext) -> Status:
	context.character.enter_home()
	return Status.SUCCEEDED
