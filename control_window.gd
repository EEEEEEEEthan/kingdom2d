extends Window

signal reset_game_requested
signal visibility_control_changed(auto_hide: bool, game_shown: bool)
signal display_layout_changed


func _ready() -> void:
	visible = false
	%AutoHide.set_pressed_no_signal(Settings.auto_hide)
	_update_visibility_ui()
	_emit_visibility_control()
	Settings.display_scale_changed.connect(notify_display_layout_changed)
	Settings.game_width_ratio_changed.connect(notify_display_layout_changed)


func _on_control_window_open_requested() -> void:
	var pos := DisplayServer.mouse_get_position()
	var screen := DisplayServer.get_screen_from_rect(Rect2(pos, Vector2.ONE))
	var usable := DisplayServer.screen_get_usable_rect(screen)
	var window_size := size
	pos.x = clampi(pos.x, usable.position.x, usable.position.x + maxi(0, usable.size.x - window_size.x))
	pos.y = clampi(pos.y, usable.position.y, usable.position.y + maxi(0, usable.size.y - window_size.y))
	current_screen = screen
	position = pos
	show()
	mode = MODE_WINDOWED
	grab_focus()


func _on_reset_confirm_dialog_confirmed() -> void:
	reset_game_requested.emit()


func _update_visibility_ui() -> void:
	var manual_control: bool = not %AutoHide.button_pressed
	var auto_hide: bool = %AutoHide.button_pressed
	%GameVisibleLabel.visible = manual_control
	%GameVisible.visible = manual_control
	%AutoHideDelayLabel.visible = auto_hide
	%AutoHideDelaySlider.visible = auto_hide


func _emit_visibility_control() -> void:
	visibility_control_changed.emit(
		%AutoHide.button_pressed,
		%GameVisible.button_pressed,
	)


func notify_display_layout_changed(_unused = null) -> void:
	%GameVisible.set_pressed_no_signal(true)
	_emit_visibility_control()
	display_layout_changed.emit()


func _on_auto_hide_toggled(_toggled_on: bool) -> void:
	Settings.auto_hide = %AutoHide.button_pressed
	if not %AutoHide.button_pressed:
		%GameVisible.set_pressed_no_signal(true)
	_update_visibility_ui()
	_emit_visibility_control()


func _on_game_visible_toggled(_toggled_on: bool) -> void:
	_emit_visibility_control()
