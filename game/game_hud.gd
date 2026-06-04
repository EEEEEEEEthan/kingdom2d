extends CanvasLayer

signal bar_dismiss_requested
signal control_window_open_requested
signal quit_requested


func dismiss_bar() -> void:
	bar_dismiss_requested.emit()

@export var game: Game


var hud_scale: int = 1:
	set(value):
		hud_scale = value
		if not is_node_ready(): await ready
		%HudRoot.scale = Vector2(value, value)
		%HudRoot.anchor_left = 0
		%HudRoot.anchor_right = 1.0 / value
		%HudRoot.anchor_top = 0
		%HudRoot.anchor_bottom = 1.0 / value
		%HudRoot.offset_left = 0
		%HudRoot.offset_right = 0
		%HudRoot.offset_bottom = 0
		%HudRoot.offset_top = 0

func reset_camera() -> void:
	game.reset_camera()
