extends CharacterAiTask
class_name CharacterAiLogCycleTask

## 进伐木营地，去橡树砍一轮，再回营地。这一轮结束前不回家。

const KEY_PHASE = 1
const KEY_ELAPSED_SECONDS = 2
const KEY_OAK_ID = 3
const KEY_WAREHOUSE_ID = 4
const KEY_CAMP_ID = 5
const KEY_HOLDING_SLOT = 6
const _INSIDE_SECONDS := 0.4
const _SHAKE_SECONDS := 2.4
const _NO_OAK_WAIT_SECONDS := 2.0
const _HARVEST_ITEM_ID := ItemConfig.TypeId.LOG
const _HARVEST_ITEM_COUNT := 1

var _phase := 0
var _elapsed_seconds := 0.0
var _oak_id := 0
var _warehouse_id := 0
var _camp_id := 0
var _holding_slot := false

func _init(save_payload: Dictionary) -> void:
	_phase = save_payload.get(KEY_PHASE, 0)
	_elapsed_seconds = save_payload.get(KEY_ELAPSED_SECONDS, 0.0)
	_oak_id = save_payload.get(KEY_OAK_ID, 0)
	_warehouse_id = save_payload.get(KEY_WAREHOUSE_ID, 0)
	_camp_id = save_payload.get(KEY_CAMP_ID, 0)
	_holding_slot = bool(save_payload.get(KEY_HOLDING_SLOT, false))

func get_type_id() -> CharacterAiTaskTypeId.TypeId:
	return CharacterAiTaskTypeId.TypeId.LOG_CYCLE

func activity_text() -> String:
	match _phase:
		0:
			return "正在去伐木营地"
		1:
			return "正在伐木营地"
		2, 3:
			return "正在伐木"
		5:
			return "正在等待可砍伐的橡树"
		6:
			return "待在伐木营地"
		7:
			return "正在把原木送到仓库"
		_:
			return "正在回伐木营地"

func tick(delta_seconds: float, context: CharacterAiContext) -> Status:
	var character := context.character
	if _camp_id == 0:
		_camp_id = character.workplace_structure_id()
	var camp := _camp(context)
	if not camp:
		character.visible = true
		return Status.FAILED
	if character.indoors:
		character.leave_home()
	var pick_and_mark := func() -> bool:
		_oak_id = _pick_oak_id(context)
		if _oak_id == 0:
			return false
		context.structure_manager().mark_occupied(_oak_id, character.id)
		return true
	match _phase:
		0:
			if character.advance_toward_world_x(delta_seconds, _world_x(camp)):
				character.visible = false
				_phase = 1
				_elapsed_seconds = 0.0
		1:
			character.position.x = _world_x(camp)
			character.visible = false
			_elapsed_seconds += delta_seconds
			if _elapsed_seconds < _INSIDE_SECONDS:
				return Status.RUNNING
			if camp.logs_full() or not _claim_harvest(context, camp):
				_phase = 6
				return Status.RUNNING
			if not pick_and_mark.call():
				_release_harvest()
				character.visible = true
				_phase = 5
				_elapsed_seconds = 0.0
				return Status.RUNNING
			character.visible = true
			_phase = 2
		2:
			var oak := _oak(context)
			if not oak:
				context.structure_manager().mark_occupied(_oak_id, 0)
				_oak_id = 0
				_release_harvest()
				_phase = 1
				return Status.RUNNING
			if character.advance_toward_world_x(delta_seconds, _world_x(oak)):
				oak.play_shake()
				_phase = 3
				_elapsed_seconds = 0.0
		3:
			_elapsed_seconds += delta_seconds
			if _elapsed_seconds >= _SHAKE_SECONDS:
				character.carried_items.add(_HARVEST_ITEM_ID, _HARVEST_ITEM_COUNT)
				_phase = 4
		4:
			if character.advance_toward_world_x(delta_seconds, _world_x(camp)):
				character.visible = false
				camp.deposit_carried(character.carried_items)
				return Status.SUCCEEDED
		5:
			character.visible = true
			if context.day_time_period != GameTime.DayTimePeriod.WORK:
				return Status.SUCCEEDED
			_elapsed_seconds += delta_seconds
			if _elapsed_seconds < _NO_OAK_WAIT_SECONDS:
				return Status.RUNNING
			if not _claim_harvest(context, camp):
				_phase = 6
				return Status.RUNNING
			if not pick_and_mark.call():
				_release_harvest()
				_elapsed_seconds = 0.0
				return Status.RUNNING
			_phase = 2
		6:
			character.position.x = _world_x(camp)
			character.visible = false
			if context.day_time_period != GameTime.DayTimePeriod.WORK:
				return Status.SUCCEEDED
			if camp.logs_full():
				_release_harvest()
				var warehouse := _nearest_warehouse(context, camp)
				if not warehouse:
					return Status.RUNNING
				if camp.withdraw_logs(character.carried_items, LumberCamp.HAUL_BATCH) <= 0:
					return Status.RUNNING
				_warehouse_id = warehouse.id
				character.visible = true
				_phase = 7
				return Status.RUNNING
			if not _claim_harvest(context, camp):
				return Status.RUNNING
			if not pick_and_mark.call():
				_release_harvest()
				character.visible = true
				_phase = 5
				_elapsed_seconds = 0.0
				return Status.RUNNING
			character.visible = true
			_phase = 2
		7:
			var warehouse := _warehouse(context)
			if not warehouse:
				camp.deposit_carried(character.carried_items)
				_warehouse_id = 0
				return Status.SUCCEEDED
			if character.advance_toward_world_x(delta_seconds, _world_x(warehouse)):
				character.carried_items.transfer_all_to(warehouse.container)
				_warehouse_id = 0
				_phase = 8
		8:
			if character.advance_toward_world_x(delta_seconds, _world_x(camp)):
				character.visible = false
				return Status.SUCCEEDED
	return Status.RUNNING

func on_exit(context: CharacterAiContext) -> void:
	if context.character.visible == false and not context.character.indoors:
		context.character.visible = true
	var camp := _camp(context)
	if camp and not context.character.carried_items.is_empty():
		camp.deposit_carried(context.character.carried_items)
	_release_harvest()
	if _oak_id != 0:
		context.structure_manager().mark_occupied(_oak_id, 0)
		_oak_id = 0

func _serialize_payload() -> Dictionary:
	return {
		KEY_PHASE: _phase,
		KEY_ELAPSED_SECONDS: _elapsed_seconds,
		KEY_OAK_ID: _oak_id,
		KEY_WAREHOUSE_ID: _warehouse_id,
		KEY_CAMP_ID: _camp_id,
		KEY_HOLDING_SLOT: _holding_slot,
	}


func holds_harvest_slot() -> bool:
	return _holding_slot


func _claim_harvest(context: CharacterAiContext, camp: LumberCamp) -> bool:
	if _holding_slot:
		return true
	if camp.log_count() + _other_harvests(context, camp) >= LumberCamp.LOG_CAPACITY:
		return false
	_holding_slot = true
	return true


func _release_harvest() -> void:
	_holding_slot = false


func _other_harvests(context: CharacterAiContext, camp: LumberCamp) -> int:
	var game := Game.find(context.character)
	if game == null:
		return 0
	var committed := 0
	for worker_id in game.employment.workers_of(camp.id):
		var worker := game.character_manager.characters.get(worker_id) as Character
		if worker == null or worker == context.character:
			continue
		var top := worker.ai_task_stack.peek()
		if top is CharacterAiLogCycleTask and (top as CharacterAiLogCycleTask).holds_harvest_slot():
			committed += 1
	return committed

func _camp(context: CharacterAiContext) -> LumberCamp:
	var structure_id := _camp_id if _camp_id != 0 else context.character.workplace_structure_id()
	var structure := context.structure_manager().get_structure_by_id(structure_id)
	return structure as LumberCamp

func _warehouse(context: CharacterAiContext) -> Warehouse:
	var structure := context.structure_manager().get_structure_by_id(_warehouse_id)
	return structure as Warehouse


static func _nearest_warehouse(context: CharacterAiContext, camp: LumberCamp) -> Warehouse:
	var nearest: Warehouse
	var nearest_distance := 0
	for structure in context.structure_manager().index_to_structures:
		if not structure is Warehouse:
			continue
		var warehouse := structure as Warehouse
		if warehouse.is_full(ItemConfig.TypeId.LOG):
			continue
		var distance := absi(warehouse.cell_index - camp.cell_index)
		if not nearest or distance < nearest_distance or (distance == nearest_distance and warehouse.id < nearest.id):
			nearest = warehouse
			nearest_distance = distance
	return nearest


func _oak(context: CharacterAiContext) -> Structure:
	return context.structure_manager().get_structure_by_id(_oak_id)

func _pick_oak_id(context: CharacterAiContext) -> int:
	var structure_manager := context.structure_manager()
	var camp := _camp(context)
	if not camp:
		return 0
	var character_id := context.character.id
	var nearest: Structure
	var nearest_distance := 0
	for structure in structure_manager.structures_of_type(StructureConfig.TypeId.OAK):
		var occupant_id := structure_manager.occupant_of(structure.id)
		if occupant_id != 0 and occupant_id != character_id:
			continue
		var distance := absi(structure.cell_index - camp.cell_index)
		if not nearest or distance < nearest_distance:
			nearest = structure
			nearest_distance = distance
	if not nearest:
		return 0
	return nearest.id

func _world_x(structure: Structure) -> float:
	return Game.get_position_by_cell_index(structure.cell_index) + Game.HALF_TILE_SIZE
