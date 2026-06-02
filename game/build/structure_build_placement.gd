extends Node
class_name StructureBuildPlacement

const _PREVIEW_MODULATE := Color(0.45, 0.65, 1.0)

var _structure_config: StructureConfig
var _game: Game
var _preview: Structure


func _init(game: Game, structure_config: StructureConfig) -> void:
	_game = game
	_structure_config = structure_config
	_preview = _structure_config.instantiate() as Structure
	_preview.modulate = _PREVIEW_MODULATE
	_game.structure_manager.add_child(_preview)
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
	_preview.cell_index = _mouse_to_cell_index()


func _mouse_to_cell_index() -> int:
	var structure_manager := _game.structure_manager
	var local: Vector2 = structure_manager.get_global_transform().affine_inverse() * structure_manager.get_global_mouse_position()
	var index := roundi((local.x - Game.HALF_TILE_SIZE) / float(Game.TILE_SIZE))
	return clampi(index, 0, Game.MAP_CELL_COUNT - 1)


func _try_place() -> void:
	var structure_manager := _game.structure_manager
	if structure_manager.index_to_structures[_preview.cell_index]:
		return
	set_process(false)
	var structure := _preview
	_preview = null
	structure.modulate = Color.WHITE
	structure_manager.add_structure(structure, structure.cell_index)
	queue_free()


func _cancel() -> void:
	set_process(false)
	_preview.queue_free()
	_preview = null
	queue_free()
