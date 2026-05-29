extends StatusIndicator

var _always_on_top := true


func _ready() -> void:
	if not Engine.is_embedded_in_editor():
		_sync_window_flags()
	get_tree().auto_accept_quit = false


func is_always_on_top_enabled() -> bool:
	return _always_on_top


func toggle_always_on_top() -> void:
	_always_on_top = not _always_on_top
	if Engine.is_embedded_in_editor():
		return
	_sync_window_flags()


func _sync_window_flags() -> void:
	var win := get_window()
	win.borderless = true
	win.transparent = true
	win.unfocusable = false
	win.always_on_top = _always_on_top
	get_viewport().transparent_bg = true


func _notification(what: int) -> void:
	if Engine.is_embedded_in_editor():
		return
	match what:
		NOTIFICATION_WM_CLOSE_REQUEST:
			get_window().hide()
		NOTIFICATION_APPLICATION_FOCUS_IN, NOTIFICATION_APPLICATION_FOCUS_OUT:
			_sync_window_flags()


func _on_pressed(mouse_button: int, _mouse_position: Vector2i) -> void:
	if mouse_button == MOUSE_BUTTON_LEFT:
		var win := get_window()
		win.show()
		win.mode = Window.MODE_WINDOWED
		win.grab_focus()
