extends Node

const ENGINE_ROOT_OFFSCREEN_POS := Vector2i(-32000, -32000)
const ENGINE_ROOT_SIZE := Vector2i(1, 1)


func _ready() -> void:
	get_tree().auto_accept_quit = false
	%GameWindow.get_node("%Game").structure_inspect_requested.connect(_open_structure_window)
	if not _uses_system_tray():
		return
	%Tray.game_show_requested.connect(func ():
		%GameWindow.closed = false
		%GameWindow.pined = true)
	await get_tree().process_frame
	_pin_engine_root_offscreen()
	await get_tree().process_frame
	_pin_engine_root_offscreen()


func _open_structure_window(structure_id: int) -> void:
	%StructureWindow.open_for(%GameWindow.get_node("%Game"), structure_id)


func _uses_system_tray() -> bool:
	return (
		DisplayServer.has_feature(DisplayServer.FEATURE_STATUS_INDICATOR)
		and not Engine.is_embedded_in_editor()
	)


func _pin_engine_root_offscreen() -> void:
	var root := get_window()
	root.unfocusable = true
	root.min_size = ENGINE_ROOT_SIZE
	root.max_size = ENGINE_ROOT_SIZE
	root.size = ENGINE_ROOT_SIZE
	root.position = ENGINE_ROOT_OFFSCREEN_POS


func request_quit() -> void:
	%QuitConfirmDialog.visible = true
