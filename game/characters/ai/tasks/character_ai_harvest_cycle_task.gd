extends CharacterAiTask
class_name CharacterAiHarvestCycleTask

## 进采集小屋或伐木营地，去最近植物采一轮，再回屋。满仓则按收发策略送到最近仓库。

enum Phase {
	TO_WORKPLACE,
	IN_WORKPLACE,
	TO_PLANT,
	HARVEST,
	RETURN_HARVEST,
	WAIT_PLANT,
	STAY_IN_WORKPLACE,
	TO_WAREHOUSE,
	RETURN_HAUL,
}

const KEY_PHASE = 1
const KEY_ELAPSED_SECONDS = 2
const KEY_PLANT_ID = 3
const KEY_WAREHOUSE_ID = 4
const KEY_WORKPLACE_ID = 5
const _INSIDE_SECONDS := 0.4
const _SHAKE_SECONDS := 2.4
const _NO_PLANT_WAIT_SECONDS := 2.0
const _HARVEST_ITEM_COUNT := 1

var _phase: Phase = Phase.TO_WORKPLACE
var _elapsed_seconds := 0.0
var _plant_id := 0
var _warehouse_id := 0
var _workplace_id := 0
var _type_id := CharacterAiTaskTypeId.TypeId.GATHER_CYCLE


func _init(save_payload: Dictionary, type_id: CharacterAiTaskTypeId.TypeId = CharacterAiTaskTypeId.TypeId.GATHER_CYCLE) -> void:
	_phase = int(save_payload.get(KEY_PHASE, Phase.TO_WORKPLACE)) as Phase
	_elapsed_seconds = save_payload.get(KEY_ELAPSED_SECONDS, 0.0)
	_plant_id = save_payload.get(KEY_PLANT_ID, 0)
	_warehouse_id = save_payload.get(KEY_WAREHOUSE_ID, 0)
	_workplace_id = save_payload.get(KEY_WORKPLACE_ID, 0)
	_type_id = type_id


func get_type_id() -> CharacterAiTaskTypeId.TypeId:
	return _type_id


func activity_text() -> String:
	var is_log := _is_log()
	match _phase:
		Phase.TO_WORKPLACE:
			return "正在去伐木营地" if is_log else "正在去采集者小屋"
		Phase.IN_WORKPLACE:
			return "正在伐木营地" if is_log else "正在采集者小屋"
		Phase.TO_PLANT, Phase.HARVEST:
			return "正在伐木" if is_log else "正在采集"
		Phase.WAIT_PLANT:
			return "正在等待可砍伐的橡树" if is_log else "正在等待可采集的灌木"
		Phase.STAY_IN_WORKPLACE:
			return "待在伐木营地" if is_log else "待在采集者小屋"
		Phase.TO_WAREHOUSE:
			return "正在把原木送到仓库" if is_log else "正在把浆果送到仓库"
		_:
			return "正在回伐木营地" if is_log else "正在回采集者小屋"


func tick(delta_seconds: float, context: CharacterAiContext) -> Status:
	var character := context.character
	if _workplace_id == 0:
		_workplace_id = character.workplace_structure_id()
	var workplace := _workplace(context)
	if not workplace:
		character.visible = true
		return Status.FAILED
	_sync_type_id(workplace)
	if character.indoors:
		character.leave_home()
	var pick_and_mark := func() -> bool:
		_plant_id = _pick_plant_id(context, workplace)
		if _plant_id == 0:
			return false
		context.structure_manager().mark_occupied(_plant_id, character.id)
		return true
	match _phase:
		Phase.TO_WORKPLACE:
			if character.advance_toward_world_x(delta_seconds, _world_x(workplace)):
				character.visible = false
				_phase = Phase.IN_WORKPLACE
				_elapsed_seconds = 0.0
		Phase.IN_WORKPLACE:
			character.position.x = _world_x(workplace)
			character.visible = false
			_elapsed_seconds += delta_seconds
			if _elapsed_seconds < _INSIDE_SECONDS:
				return Status.RUNNING
			if workplace.storage_full():
				_phase = Phase.STAY_IN_WORKPLACE
				return Status.RUNNING
			if not pick_and_mark.call():
				character.visible = true
				_phase = Phase.WAIT_PLANT
				_elapsed_seconds = 0.0
				return Status.RUNNING
			character.visible = true
			_phase = Phase.TO_PLANT
		Phase.TO_PLANT:
			var plant := _plant(context)
			if not plant:
				context.structure_manager().mark_occupied(_plant_id, 0)
				_plant_id = 0
				_phase = Phase.IN_WORKPLACE
				return Status.RUNNING
			if character.advance_toward_world_x(delta_seconds, _world_x(plant)):
				plant.play_shake()
				_phase = Phase.HARVEST
				_elapsed_seconds = 0.0
		Phase.HARVEST:
			_elapsed_seconds += delta_seconds
			if _elapsed_seconds >= _SHAKE_SECONDS:
				character.carried_items.add(workplace.harvest_item_id(), _HARVEST_ITEM_COUNT)
				_phase = Phase.RETURN_HARVEST
		Phase.RETURN_HARVEST:
			if character.advance_toward_world_x(delta_seconds, _world_x(workplace)):
				character.visible = false
				workplace.deposit_carried(character.carried_items)
				return Status.SUCCEEDED
		Phase.WAIT_PLANT:
			character.visible = true
			if context.day_time_period != GameTime.DayTimePeriod.WORK:
				return Status.SUCCEEDED
			_elapsed_seconds += delta_seconds
			if _elapsed_seconds < _NO_PLANT_WAIT_SECONDS:
				return Status.RUNNING
			if not pick_and_mark.call():
				_elapsed_seconds = 0.0
				return Status.RUNNING
			_phase = Phase.TO_PLANT
		Phase.STAY_IN_WORKPLACE:
			character.position.x = _world_x(workplace)
			character.visible = false
			if context.day_time_period != GameTime.DayTimePeriod.WORK:
				return Status.SUCCEEDED
			if workplace.storage_full():
				var warehouse := Warehouse.nearest(
					context.structure_manager(),
					workplace.cell_index,
					workplace.harvest_item_id(),
					true,
				)
				if not warehouse:
					return Status.RUNNING
				if workplace.withdraw_harvest(character.carried_items, HarvestWorkplace.HAUL_BATCH) <= 0:
					return Status.RUNNING
				_warehouse_id = warehouse.id
				character.visible = true
				_phase = Phase.TO_WAREHOUSE
				return Status.RUNNING
			if not pick_and_mark.call():
				character.visible = true
				_phase = Phase.WAIT_PLANT
				_elapsed_seconds = 0.0
				return Status.RUNNING
			character.visible = true
			_phase = Phase.TO_PLANT
		Phase.TO_WAREHOUSE:
			var warehouse := _warehouse(context)
			if not warehouse:
				workplace.deposit_carried(character.carried_items)
				_warehouse_id = 0
				return Status.SUCCEEDED
			if character.advance_toward_world_x(delta_seconds, _world_x(warehouse)):
				_deposit_accepted(character, warehouse)
				_warehouse_id = 0
				_phase = Phase.RETURN_HAUL
		Phase.RETURN_HAUL:
			if character.advance_toward_world_x(delta_seconds, _world_x(workplace)):
				character.visible = false
				return Status.SUCCEEDED
	return Status.RUNNING


func on_exit(context: CharacterAiContext) -> void:
	if context.character.visible == false and not context.character.indoors:
		context.character.visible = true
	var workplace := _workplace(context)
	if workplace and not context.character.carried_items.is_empty():
		workplace.deposit_carried(context.character.carried_items)
	if _plant_id != 0:
		context.structure_manager().mark_occupied(_plant_id, 0)
		_plant_id = 0


func _serialize_payload() -> Dictionary:
	return {
		KEY_PHASE: _phase,
		KEY_ELAPSED_SECONDS: _elapsed_seconds,
		KEY_PLANT_ID: _plant_id,
		KEY_WAREHOUSE_ID: _warehouse_id,
		KEY_WORKPLACE_ID: _workplace_id,
	}


func _workplace(context: CharacterAiContext) -> HarvestWorkplace:
	var structure_id := _workplace_id if _workplace_id != 0 else context.character.workplace_structure_id()
	var structure := context.structure_manager().get_structure_by_id(structure_id)
	return structure as HarvestWorkplace


func _sync_type_id(workplace: HarvestWorkplace) -> void:
	_type_id = (
		CharacterAiTaskTypeId.TypeId.LOG_CYCLE
		if workplace is LumberCamp
		else CharacterAiTaskTypeId.TypeId.GATHER_CYCLE
	)


func _is_log() -> bool:
	return _type_id == CharacterAiTaskTypeId.TypeId.LOG_CYCLE


func _deposit_accepted(character: Character, warehouse: Warehouse) -> void:
	for item_id in character.carried_items.item_ids():
		if not warehouse.accepts_deposit(item_id):
			continue
		var moved := character.carried_items.take(item_id, character.carried_items.count_of(item_id))
		if moved > 0:
			warehouse.container.add(item_id, moved)


func _warehouse(context: CharacterAiContext) -> Warehouse:
	var structure := context.structure_manager().get_structure_by_id(_warehouse_id)
	return structure as Warehouse


func _plant(context: CharacterAiContext) -> Structure:
	return context.structure_manager().get_structure_by_id(_plant_id)


func _pick_plant_id(context: CharacterAiContext, workplace: HarvestWorkplace) -> int:
	var structure_manager := context.structure_manager()
	var character_id := context.character.id
	var nearest: Structure
	var nearest_distance := 0
	for structure in structure_manager.structures_of_type(workplace.harvest_plant_type_id()):
		var occupant_id := structure_manager.occupant_of(structure.id)
		if occupant_id != 0 and occupant_id != character_id:
			continue
		var distance := absi(structure.cell_index - workplace.cell_index)
		if not nearest or distance < nearest_distance:
			nearest = structure
			nearest_distance = distance
	if not nearest:
		return 0
	return nearest.id


func _world_x(structure: Structure) -> float:
	return Game.get_position_by_cell_index(structure.cell_index) + Game.HALF_TILE_SIZE
