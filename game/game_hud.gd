extends CanvasLayer

signal control_window_open_requested
signal quit_requested

@export var game: Game


var hud_scale: int = 1:
	set(value):
		hud_scale = value
		if not is_node_ready(): await ready
		var vbox := %VBoxContainer
		var s := float(hud_scale)
		vbox.scale = Vector2.ONE
		vbox.pivot_offset = Vector2(0, vbox.get_combined_minimum_size().y)
		vbox.scale = Vector2(s, s)


func _on_reset_camera_pressed() -> void:
	game.reset_camera()


func _on_popup_control_window_open_requested() -> void:
	control_window_open_requested.emit()


func _on_popup_quit_requested() -> void:
	quit_requested.emit()


func _on_build_requested(structure_config: StructureConfig) -> void:
	game.start_build_placement(structure_config)
