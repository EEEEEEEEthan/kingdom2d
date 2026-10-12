extends CharacterAiTask
class_name CharacterAiGatherCycleTask

## 进采集者小屋，去灌木采一轮，再回小屋。这一轮结束前不回家。

const KEY_PHASE = 1
const KEY_ELAPSED_SECONDS = 2
const KEY_BUSH_ID = 3
const KEY_WAREHOUSE_ID = 4
const KEY_HUT_ID = 5
const _INSIDE_SECONDS := 0.4
const _SHAKE_SECONDS := 2.4
const _NO_BUSH_WAIT_SECONDS := 2.0
const _HARVEST_ITEM_ID := ItemConfig.TypeId.BERRY
const _HARVEST_ITEM_COUNT := 1

var _phase := 0
var _elapsed_seconds := 0.0
var _bush_id := 0
var _warehouse_id := 0
var _hut_id := 0

func _init(save_payload: Dictionary) -> void:
	_phase = save_payload.get(KEY_PHASE, 0)
	_elapsed_seconds = save_payload.get(KEY_ELAPSED_SECONDS, 0.0)
	_bush_id = save_payload.get(KEY_BUSH_ID, 0)
	_warehouse_id = save_payload.get(KEY_WAREHOUSE_ID, 0)
	_hut_id = save_payload.get(KEY_HUT_ID, 0)

func get_type_id() -> CharacterAiTaskTypeId.TypeId:
	return CharacterAiTaskTypeId.TypeId.GATHER_CYCLE

func activity_text() -> String:
	match _phase:
		0:
			return "正在去采集者小屋"
		1:
			return "正在采集者小屋"
		2, 3:
			return "正在采集"
		5:
			return "正在等待可采集的灌木"
		6:
			return "待在采集者小屋"
		7:
			return "正在把浆果送到仓库"
		_:
			return "正在回采集者小屋"

func tick(delta_seconds: float, context: CharacterAiContext) -> Status:
	var character := context.character
	if _hut_id == 0:
		_hut_id = character.workplace_structure_id()
	var hut := _hut(context)
	if not hut:
		character.visible = true
		return Status.FAILED
	if character.indoors:
		character.leave_home()
	var pick_and_mark := func() -> bool:
		_bush_id = _pick_bush_id(context)
		if _bush_id == 0:
			return false
		context.structure_manager().mark_occupied(_bush_id, character.id)
		return true
	match _phase:
		0:
			if character.advance_toward_world_x(delta_seconds, _world_x(hut)):
				character.visible = false
				_phase = 1
				_elapsed_seconds = 0.0
		1:
			character.position.x = _world_x(hut)
			character.visible = false
			_elapsed_seconds += delta_seconds
			if _elapsed_seconds < _INSIDE_SECONDS:
				return Status.RUNNING
			if hut.berries_full():
				_phase = 6
				return Status.RUNNING
			if not pick_and_mark.call():
				character.visible = true
				_phase = 5
				_elapsed_seconds = 0.0
				return Status.RUNNING
			character.visible = true
			_phase = 2
		2:
			var bush := _bush(context)
			if not bush:
				context.structure_manager().mark_occupied(_bush_id, 0)
				_bush_id = 0
				_phase = 1
				return Status.RUNNING
			if character.advance_toward_world_x(delta_seconds, _world_x(bush)):
				bush.play_shake()
				_phase = 3
				_elapsed_seconds = 0.0
		3:
			_elapsed_seconds += delta_seconds
			if _elapsed_seconds >= _SHAKE_SECONDS:
				_take_harvest(character)
				_phase = 4
		4:
			if character.advance_toward_world_x(delta_seconds, _world_x(hut)):
				character.visible = false
				hut.deposit_carried(character.carried_items)
				return Status.SUCCEEDED
		5:
			character.visible = true
			if context.day_time_period != GameTime.DayTimePeriod.WORK:
				return Status.SUCCEEDED
			_elapsed_seconds += delta_seconds
			if _elapsed_seconds < _NO_BUSH_WAIT_SECONDS:
				return Status.RUNNING
			if not pick_and_mark.call():
				_elapsed_seconds = 0.0
				return Status.RUNNING
			_phase = 2
		6:
			character.position.x = _world_x(hut)
			character.visible = false
			if context.day_time_period != GameTime.DayTimePeriod.WORK:
				return Status.SUCCEEDED
			if hut.berries_full():
				var warehouse := _nearest_warehouse(context, hut)
				if not warehouse:
					return Status.RUNNING
				if hut.withdraw_berries(character.carried_items, GathererHut.HAUL_BATCH) <= 0:
					return Status.RUNNING
				_warehouse_id = warehouse.id
				character.visible = true
				_phase = 7
				return Status.RUNNING
			if not pick_and_mark.call():
				character.visible = true
				_phase = 5
				_elapsed_seconds = 0.0
				return Status.RUNNING
			character.visible = true
			_phase = 2
		7:
			var warehouse := _warehouse(context)
			if not warehouse:
				hut.deposit_carried(character.carried_items)
				_warehouse_id = 0
				return Status.SUCCEEDED
			if character.advance_toward_world_x(delta_seconds, _world_x(warehouse)):
				_deposit_accepted(character, warehouse)
				_warehouse_id = 0
				_phase = 8
		8:
			if character.advance_toward_world_x(delta_seconds, _world_x(hut)):
				character.visible = false
				return Status.SUCCEEDED
	return Status.RUNNING

func on_exit(context: CharacterAiContext) -> void:
	if context.character.visible == false and not context.character.indoors:
		context.character.visible = true
	var hut := _hut(context)
	if hut and not context.character.carried_items.is_empty():
		hut.deposit_carried(context.character.carried_items)
	if _bush_id != 0:
		context.structure_manager().mark_occupied(_bush_id, 0)
		_bush_id = 0

func _serialize_payload() -> Dictionary:
	return {
		KEY_PHASE: _phase,
		KEY_ELAPSED_SECONDS: _elapsed_seconds,
		KEY_BUSH_ID: _bush_id,
		KEY_WAREHOUSE_ID: _warehouse_id,
		KEY_HUT_ID: _hut_id,
	}

func _take_harvest(character: Character) -> void:
	var before := character.carried_items.count_of(_HARVEST_ITEM_ID)
	character.carried_items.add(_HARVEST_ITEM_ID, _HARVEST_ITEM_COUNT)
	var gained := character.carried_items.count_of(_HARVEST_ITEM_ID) - before
	if gained <= 0:
		return
	var game := Game.find(character)
	if game:
		game.item_gained.emit(_HARVEST_ITEM_ID, gained, character.global_position)


func _hut(context: CharacterAiContext) -> GathererHut:
	var structure_id := _hut_id if _hut_id != 0 else context.character.workplace_structure_id()
	var structure := context.structure_manager().get_structure_by_id(structure_id)
	return structure as GathererHut

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


static func _nearest_warehouse(context: CharacterAiContext, hut: GathererHut) -> Warehouse:
	var nearest: Warehouse
	var nearest_distance := 0
	for structure in context.structure_manager().index_to_structures:
		if not structure is Warehouse:
			continue
		var warehouse := structure as Warehouse
		if not warehouse.accepts_deposit(ItemConfig.TypeId.BERRY):
			continue
		var distance := absi(warehouse.cell_index - hut.cell_index)
		if not nearest or distance < nearest_distance or (distance == nearest_distance and warehouse.id < nearest.id):
			nearest = warehouse
			nearest_distance = distance
	return nearest


func _bush(context: CharacterAiContext) -> Structure:
	return context.structure_manager().get_structure_by_id(_bush_id)

func _pick_bush_id(context: CharacterAiContext) -> int:
	var structure_manager := context.structure_manager()
	var hut := _hut(context)
	if not hut:
		return 0
	var character_id := context.character.id
	var nearest: Structure
	var nearest_distance := 0
	for structure in structure_manager.structures_of_type(StructureConfig.TypeId.BUSH):
		var occupant_id := structure_manager.occupant_of(structure.id)
		if occupant_id != 0 and occupant_id != character_id:
			continue
		var distance := absi(structure.cell_index - hut.cell_index)
		if not nearest or distance < nearest_distance:
			nearest = structure
			nearest_distance = distance
	if not nearest:
		return 0
	return nearest.id

func _world_x(structure: Structure) -> float:
	return Game.get_position_by_cell_index(structure.cell_index) + Game.HALF_TILE_SIZE
