extends RefCounted
class_name CharacterAiBehavior

static func create(type_id: CharacterAiBehaviorTypeId.TypeId) -> CharacterAiBehavior:
	match type_id:
		CharacterAiBehaviorTypeId.TypeId.IDLE_WANDER:
			return CharacterAiIdleWanderBehavior.new()
		CharacterAiBehaviorTypeId.TypeId.HARVEST_WORK:
			return CharacterAiHarvestWorkBehavior.new()
		_:
			return CharacterAiBehavior.new()

func get_type_id() -> CharacterAiBehaviorTypeId.TypeId:
	return CharacterAiBehaviorTypeId.TypeId.NONE

func schedule(_context: CharacterAiContext) -> void:
	pass
