extends CanvasLayer

signal auto_hide_pin_toggled(pin_pressed: bool)
signal bar_dismiss_requested
signal control_window_open_requested
signal quit_requested


func dismiss_bar() -> void:
	bar_dismiss_requested.emit()


func sync_pin_from_auto_hide(auto_hide_enabled: bool) -> void:
	%Pin.set_pressed_no_signal(not auto_hide_enabled)

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
