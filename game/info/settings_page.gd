extends Control

signal reset_game_requested

const MAX_GAME_WIDTH := 4096


func _ready() -> void:
	%ScaleSlider.set_value_no_signal(float(Settings.display_scale))
	Settings.display_scale_changed.connect(_on_settings_display_scale_changed)
	%ScaleSlider.value_changed.connect(_on_scale_slider)
	_sync_width_slider_range()
	Settings.game_width_ratio_changed.connect(_on_settings_game_width_ratio_changed)
	%WidthSlider.value_changed.connect(_on_width_slider)
	%ResetGame.pressed.connect(_on_reset_pressed)
	%ResetConfirm.visible = false
	%ResetDelete.pressed.connect(_on_reset_confirmed)
	%ResetCancel.pressed.connect(_on_reset_cancel)


func _on_settings_display_scale_changed(new_scale: int) -> void:
	%ScaleSlider.set_value_no_signal(float(new_scale))


func _on_scale_slider(new_value: float) -> void:
	Settings.display_scale = int(new_value)


func _sync_width_slider_range() -> void:
	var screen_width := DisplayServer.screen_get_size(get_window().current_screen).x
	var max_ratio := minf(1.0, float(MAX_GAME_WIDTH) / float(maxi(1, screen_width)))
	%WidthSlider.max_value = max_ratio
	if Settings.game_width_ratio > max_ratio:
		Settings.game_width_ratio = max_ratio
	%WidthSlider.set_value_no_signal(minf(Settings.game_width_ratio, %WidthSlider.max_value))


func _on_settings_game_width_ratio_changed(new_ratio: float) -> void:
	%WidthSlider.set_value_no_signal(minf(new_ratio, %WidthSlider.max_value))


func _on_width_slider(new_value: float) -> void:
	Settings.game_width_ratio = new_value


func _on_reset_pressed() -> void:
	%ResetConfirm.visible = true


func _on_reset_cancel() -> void:
	%ResetConfirm.visible = false


func _on_reset_confirmed() -> void:
	%ResetConfirm.visible = false
	reset_game_requested.emit()
