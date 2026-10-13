extends Structure
class_name BuildersGuild

const SLOT_COUNT := 2
const _KEY_PRIORITY := 1

var priority := WorkplacePriority.Priority.NORMAL


func _serialize() -> Dictionary:
	return {
		_KEY_PRIORITY: priority,
	}


func _deserialize(data: Dictionary) -> void:
	priority = int(data.get(_KEY_PRIORITY, WorkplacePriority.Priority.NORMAL))


func change_priority(value: int) -> void:
	if priority == value:
		return
	priority = value
	var game := Game.find(self)
	if game:
		game.rebalance_workplaces()
