extends Node
class_name StructureBuildPlacement

const _PREVIEW_MODULATE := Color(0.45, 0.65, 1.0)

var _structure_type_id: int
var _game: Game
var _structure_manager: StructureManager
var _preview: Structure
var _cell_index: int


func _init(structure_type_id: int) -> void:
	_structure_type_id = structure_type_id


func _ready() -> void:
	_game = get_parent() as Game
	_structure_manager = _game.structure_manager
	_preview = StructureConfig.configs_by_id[_structure_type_id].instantiate() as Structure
	_preview.modulate = _PREVIEW_MODULATE
	_structure_manager.add_child(_preview)
	_update_cell_index_from_mouse()


func _process(_delta: float) -> void:
	_update_cell_index_from_mouse()


func _input(event: InputEvent) -> void:
	if not event is InputEventMouseButton:
		return
	var mouse_button := event as InputEventMouseButton
	if not mouse_button.pressed:
		return
	match mouse_button.button_index:
		MOUSE_BUTTON_LEFT:
			_try_place()
			get_viewport().set_input_as_handled()
		MOUSE_BUTTON_RIGHT:
			_cancel()
			get_viewport().set_input_as_handled()


func _update_cell_index_from_mouse() -> void:
	if not _preview:
		return
	_cell_index = _mouse_to_cell_index()
	_preview.cell_index = _cell_index


func _mouse_to_cell_index() -> int:
	var local: Vector2 = _structure_manager.get_global_transform().affine_inverse() * _structure_manager.get_global_mouse_position()
	var index := roundi((local.x - Game.HALF_TILE_SIZE) / float(Game.TILE_SIZE))
	return clampi(index, 0, Game.MAP_CELL_COUNT - 1)


func _try_place() -> void:
	if _structure_manager.index_to_structures[_cell_index]:
		return
	set_process(false)
	var structure := _preview
	_preview = null
	structure.modulate = Color.WHITE
	_structure_manager.add_structure(structure, _cell_index)
	queue_free()


func _cancel() -> void:
	set_process(false)
	_preview.queue_free()
	_preview = null
	queue_free()
