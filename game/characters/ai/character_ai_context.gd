extends RefCounted
class_name CharacterAiContext

var character: Character

var game_time: GameTime:
	get:
		return _resolve_game().game_time

var day_time_period: GameTime.DayTimePeriod:
	get:
		return game_time.day_time_period

var structure_manager: StructureManager:
	get:
		return _resolve_game().structure_manager

func _init(owner_character: Character) -> void:
	character = owner_character

func _resolve_game() -> Game:
	var node: Node = character.owner
	while node:
		if node is Game:
			return node
		node = node.owner
	assert(false, "Character must live under Game")
	return null
