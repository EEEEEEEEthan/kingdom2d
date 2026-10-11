extends Node2D
class_name StructureBuildPlacement

const _PREVIEW_MODULATE := Color(0.45, 0.65, 1.0)
const _PREVIEW_MODULATE_PULSE := Color(0.58, 0.78, 1.0)

var _structure_config: StructureConfig
var _game: Game
var _preview: Structure
var _preview_juice: _StructureBuildPreviewJuice


func _init(game: Game, structure_config: StructureConfig) -> void:
	_game = game
	_structure_config = structure_config
	_preview = _structure_config.instantiate() as Structure
	_preview.modulate = _PREVIEW_MODULATE
	await ready
	_preview_juice = await _StructureBuildPreviewJuice.new(_preview)
	add_child(_preview_juice)
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
	var new_index := _mouse_to_cell_index()
	var index_changed := new_index != _preview.cell_index
	_preview.cell_index = new_index
	if index_changed:
		_preview_juice.on_cell_snapped()


func _mouse_to_cell_index() -> int:
	var structure_manager := _game.structure_manager
	var local: Vector2 = structure_manager.get_global_transform().affine_inverse() * structure_manager.get_global_mouse_position()
	var index := roundi((local.x - Game.HALF_TILE_SIZE) / float(Game.TILE_SIZE))
	return clampi(index, 0, Game.MAP_CELL_COUNT - 1)


func _try_place() -> void:
	var structure_manager := _game.structure_manager
	if structure_manager.index_to_structures[_preview.cell_index]:
		return
	_preview.modulate = Color.WHITE
	_preview_juice.dispose()
	structure_manager.add_structure(_preview, _preview.cell_index)
	if _structure_config.id == StructureConfig.TypeId.SUNKEN_FLOOR_THATCH_HOVEL:
		_game.spawn_resident_at_cell(_preview.cell_index)
	_game.save_game()
	_preview.play_bounce()
	queue_free()


func _cancel() -> void:
	queue_free()


class _StructureBuildPreviewJuice extends Node2D:
	const _IDLE_SCALE_PEAK := 1.055
	const _IDLE_HALF_CYCLE := 0.42

	var _preview: Structure
	var _idle_tween: Tween
	var _disposed: bool

	func _init(preview: Structure) -> void:
		_preview = preview
		add_child(preview)
		await ready
		_start_idle_pulse()

	func dispose() -> void:
		if _disposed: return
		_disposed = true
		remove_child(_preview)
		_stop_idle_pulse()
		_preview.stop_bounce()
		queue_free()

	func free() -> void:
		super.free()
		dispose()

	func on_cell_snapped() -> void:
		_stop_idle_pulse()
		_preview.play_bounce(_start_idle_pulse)

	func _stop_idle_pulse() -> void:
		if _idle_tween and _idle_tween.is_valid():
			_idle_tween.kill()

	func _start_idle_pulse() -> void:
		_stop_idle_pulse()
		_preview.scale = Vector2.ONE
		_preview.modulate = StructureBuildPlacement._PREVIEW_MODULATE
		_idle_tween = create_tween().set_loops()
		_idle_tween.set_parallel(true)
		_idle_tween.tween_property(_preview, "scale", Vector2(_IDLE_SCALE_PEAK, _IDLE_SCALE_PEAK), _IDLE_HALF_CYCLE).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		_idle_tween.tween_property(_preview, "modulate", StructureBuildPlacement._PREVIEW_MODULATE_PULSE, _IDLE_HALF_CYCLE).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		_idle_tween.chain().set_parallel(true)
		_idle_tween.tween_property(_preview, "scale", Vector2.ONE, _IDLE_HALF_CYCLE).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		_idle_tween.tween_property(_preview, "modulate", StructureBuildPlacement._PREVIEW_MODULATE, _IDLE_HALF_CYCLE).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
