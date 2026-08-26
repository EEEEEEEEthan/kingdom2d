extends CharacterAiTask
class_name CharacterAiHarvestStructureTask

const KEY_STRUCTURE_ID = 1
const KEY_DURATION_SECONDS = 2
const KEY_ELAPSED_SECONDS = 3
const KEY_ITEM_TYPE_ID = 4
const KEY_ITEM_COUNT = 5

var _structure_id: int
var _duration_seconds: float
var _elapsed_seconds: float
var _item_type_id: ItemTypeId.TypeId
var _item_count: int
var _claim_token: int = -1

func _init(save_payload: Dictionary) -> void:
	_structure_id = save_payload[KEY_STRUCTURE_ID]
	_duration_seconds = save_payload[KEY_DURATION_SECONDS]
	_elapsed_seconds = save_payload.get(KEY_ELAPSED_SECONDS, 0.0)
	_item_type_id = save_payload[KEY_ITEM_TYPE_ID] as ItemTypeId.TypeId
	_item_count = save_payload[KEY_ITEM_COUNT]

func get_type_id() -> CharacterAiTaskTypeId.TypeId:
	return CharacterAiTaskTypeId.TypeId.HARVEST_STRUCTURE

func get_progress_ratio() -> float:
	if _duration_seconds <= 0.0:
		return 1.0
	return clampf(_elapsed_seconds / _duration_seconds, 0.0, 1.0)

func on_enter(context: CharacterAiContext) -> void:
	_claim_token = context.character.get_ai_behavior_token()
	if not context.structure_manager.try_claim_harvest(
			_structure_id,
			context.character.id,
			_claim_token
	):
		_claim_token = -1

func tick(delta_seconds: float, context: CharacterAiContext) -> Status:
	if _claim_token < 0:
		return Status.FAILED
	if context.structure_manager.is_harvest_claimed_by_other(
			_structure_id,
			context.character.id,
			_claim_token
	):
		return Status.FAILED
	if context.character.get_ai_behavior_token() != _claim_token:
		return Status.FAILED
	var structure := context.structure_manager.get_structure_by_id(_structure_id)
	if not structure:
		return Status.FAILED
	_elapsed_seconds += delta_seconds
	if _elapsed_seconds < _duration_seconds:
		return Status.RUNNING
	context.character.inventory.add_item(_item_type_id, _item_count)
	structure.queue_free()
	return Status.SUCCEEDED

func _serialize_payload() -> Dictionary:
	return {
		KEY_STRUCTURE_ID: _structure_id,
		KEY_DURATION_SECONDS: _duration_seconds,
		KEY_ELAPSED_SECONDS: _elapsed_seconds,
		KEY_ITEM_TYPE_ID: _item_type_id,
		KEY_ITEM_COUNT: _item_count,
	}
