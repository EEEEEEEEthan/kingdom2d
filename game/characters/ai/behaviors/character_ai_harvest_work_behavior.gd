extends CharacterAiBehavior
class_name CharacterAiHarvestWorkBehavior

func get_type_id() -> CharacterAiBehaviorTypeId.TypeId:
	return CharacterAiBehaviorTypeId.TypeId.HARVEST_WORK

func schedule(context: CharacterAiContext) -> void:
	var structure := _find_nearest_work_target(context)
	if not structure:
		context.character.push_ai_task(CharacterAiWaitDurationTask.new({
			CharacterAiWaitDurationTask.KEY_DURATION_SECONDS: 1.0,
		}))
		return
	var harvest_payload := {}
	match context.character.occupation:
		OccupationId.TypeId.LUMBERJACK:
			harvest_payload = {
				CharacterAiHarvestStructureTask.KEY_STRUCTURE_ID: structure.id,
				CharacterAiHarvestStructureTask.KEY_DURATION_SECONDS: 10.0,
				CharacterAiHarvestStructureTask.KEY_ITEM_TYPE_ID: ItemTypeId.TypeId.LOG,
				CharacterAiHarvestStructureTask.KEY_ITEM_COUNT: 1,
			}
		OccupationId.TypeId.SCAVENGER:
			harvest_payload = {
				CharacterAiHarvestStructureTask.KEY_STRUCTURE_ID: structure.id,
				CharacterAiHarvestStructureTask.KEY_DURATION_SECONDS: 5.0,
				CharacterAiHarvestStructureTask.KEY_ITEM_TYPE_ID: ItemTypeId.TypeId.BERRY,
				CharacterAiHarvestStructureTask.KEY_ITEM_COUNT: 5,
			}
		_:
			context.character.push_ai_task(CharacterAiWaitDurationTask.new({
				CharacterAiWaitDurationTask.KEY_DURATION_SECONDS: 1.0,
			}))
			return
	context.character.push_ai_task(CharacterAiHarvestStructureTask.new(harvest_payload))
	context.character.push_ai_task(CharacterAiMoveToWorldXTask.new({
		CharacterAiMoveToWorldXTask.KEY_TARGET_WORLD_X: structure.position.x,
	}))

func _find_nearest_work_target(context: CharacterAiContext) -> Structure:
	var target_type_id := StructureConfig.TypeId.NONE
	match context.character.occupation:
		OccupationId.TypeId.LUMBERJACK:
			target_type_id = StructureConfig.TypeId.OAK
		OccupationId.TypeId.SCAVENGER:
			target_type_id = StructureConfig.TypeId.BUSH
		_:
			return null
	var nearest_structure: Structure = null
	var nearest_distance := INF
	var character := context.character
	for structure in context.structure_manager.index_to_structures:
		if not structure:
			continue
		if structure.config.id != target_type_id:
			continue
		if context.structure_manager.is_harvest_claimed_by_other(
				structure.id,
				character.id,
				character.ai_behavior_token
		):
			continue
		var distance := absf(structure.position.x - character.position.x)
		if distance >= nearest_distance:
			continue
		nearest_distance = distance
		nearest_structure = structure
	return nearest_structure
