extends CanvasLayer

signal control_window_open_requested
signal quit_requested

@export var game: Game


func _on_reset_camera_pressed() -> void:
	game.reset_camera()


func _on_popup_control_window_open_requested() -> void:
	control_window_open_requested.emit()


func _on_popup_quit_requested() -> void:
	quit_requested.emit()


func _on_build_requested(structure_config: StructureConfig) -> void:
	game.start_build_placement(structure_config)
