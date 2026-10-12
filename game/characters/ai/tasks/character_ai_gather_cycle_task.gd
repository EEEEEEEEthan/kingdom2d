extends CharacterAiTask
class_name CharacterAiGatherCycleTask

## 进采集者小屋，去灌木采一轮，再回小屋。这一轮结束前不回家。

const KEY_PHASE = 1
const KEY_ELAPSED_SECONDS = 2
const KEY_BUSH_ID = 3
const _INSIDE_SECONDS := 0.4
const _SHAKE_SECONDS := 2.4
const _NO_BUSH_WAIT_SECONDS := 2.0
const _HARVEST_ITEM_ID := ItemConfig.TypeId.BERRY
const _HARVEST_ITEM_COUNT := 1

var _phase := 0
var _elapsed_seconds := 0.0
var _bush_id := 0

func _init(save_payload: Dictionary) -> void:
	_phase = save_payload.get(KEY_PHASE, 0)
	_elapsed_seconds = save_payload.get(KEY_ELAPSED_SECONDS, 0.0)
	_bush_id = save_payload.get(KEY_BUSH_ID, 0)

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
		_:
			return "正在回采集者小屋"

func tick(delta_seconds: float, context: CharacterAiContext) -> Status:
	var character := context.character
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
				character.carried_items.add(_HARVEST_ITEM_ID, _HARVEST_ITEM_COUNT)
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
				return Status.RUNNING
			if not pick_and_mark.call():
				character.visible = true
				_phase = 5
				_elapsed_seconds = 0.0
				return Status.RUNNING
			character.visible = true
			_phase = 2
	return Status.RUNNING

func on_exit(context: CharacterAiContext) -> void:
	if context.character.visible == false and not context.character.indoors:
		context.character.visible = true
	if _bush_id != 0:
		context.structure_manager().mark_occupied(_bush_id, 0)
		_bush_id = 0

func _serialize_payload() -> Dictionary:
	return {
		KEY_PHASE: _phase,
		KEY_ELAPSED_SECONDS: _elapsed_seconds,
		KEY_BUSH_ID: _bush_id,
	}

static func _hut(context: CharacterAiContext) -> GathererHut:
	var structure := context.structure_manager().get_structure_by_id(context.character.workplace_structure_id)
	return structure as GathererHut

func _bush(context: CharacterAiContext) -> Structure:
	return context.structure_manager().get_structure_by_id(_bush_id)

static func _pick_bush_id(context: CharacterAiContext) -> int:
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
