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


func reset_camera() -> void:
	game.reset_camera()
