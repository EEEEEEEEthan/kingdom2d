extends Structure
class_name Warehouse

const _KEY_MANAGER_ID := 1


func _serialize() -> Dictionary:
	return {}


func _deserialize(_data: Dictionary) -> void:
	pass


func assign_manager(character: Character) -> void:
	var game := Game.find(self)
	if game:
		game.employment.assign(character.id, id)
	character.abandon_ai_tasks()
