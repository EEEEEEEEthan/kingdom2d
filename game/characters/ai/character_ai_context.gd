extends RefCounted
class_name CharacterAiContext

var character: Character

var game_time: GameTime:
	get:
		return _resolve_game().game_time

var day_time_period: GameTime.DayTimePeriod:
	get:
		return game_time.day_time_period

func structure_manager() -> StructureManager:
	return _resolve_game().structure_manager

func _init(owner_character: Character) -> void:
	character = owner_character

func _resolve_game() -> Game:
	var game := Game.find(character)
	assert(game != null, "Character must live under Game")
	return game
