extends CharacterAiTask
class_name CharacterAiGatherCycleTask

## 进采集者小屋，去灌木采一轮，再回小屋。这一轮结束前不回家。

const KEY_PHASE = 1
const KEY_ELAPSED_SECONDS = 2
const KEY_BUSH_ID = 3
const _INSIDE_SECONDS := 0.4
const _SHAKE_SECONDS := 2.4

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
			return "去采集者小屋"
		1:
			return "在采集者小屋"
		2:
			return "去灌木"
		3:
			return "采集"
		_:
			return "回采集者小屋"

func tick(delta_seconds: float, context: CharacterAiContext) -> Status:
	var character := context.character
	var hut := _hut(context)
	if not hut:
		character.visible = true
		return Status.FAILED
	if character.indoors:
		character.leave_home()
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
			_bush_id = _pick_bush_id(context, hut)
			if _bush_id == 0:
				if character.is_asleep():
					character.visible = true
					return Status.SUCCEEDED
				return Status.RUNNING
			character.visible = true
			_phase = 2
		2:
			var bush := _bush(context)
			if not bush:
				_phase = 1
				return Status.RUNNING
			if character.advance_toward_world_x(delta_seconds, _world_x(bush)):
				bush.play_shake()
				_phase = 3
				_elapsed_seconds = 0.0
		3:
			_elapsed_seconds += delta_seconds
			if _elapsed_seconds >= _SHAKE_SECONDS:
				_phase = 4
		4:
			if character.advance_toward_world_x(delta_seconds, _world_x(hut)):
				character.visible = false
				return Status.SUCCEEDED
	return Status.RUNNING

func on_exit(context: CharacterAiContext) -> void:
	if context.character.visible == false and not context.character.indoors:
		context.character.visible = true

func _serialize_payload() -> Dictionary:
	return {
		KEY_PHASE: _phase,
		KEY_ELAPSED_SECONDS: _elapsed_seconds,
		KEY_BUSH_ID: _bush_id,
	}

func _hut(context: CharacterAiContext) -> GathererHut:
	var structure := context.structure_manager().get_structure_by_id(context.character.workplace_structure_id)
	return structure as GathererHut

func _bush(context: CharacterAiContext) -> Structure:
	return context.structure_manager().get_structure_by_id(_bush_id)

func _pick_bush_id(context: CharacterAiContext, hut: GathererHut) -> int:
	var nearest: Structure
	var nearest_distance := 0
	for structure in context.structure_manager().index_to_structures:
		if not structure or structure.config.id != StructureConfig.TypeId.BUSH:
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
