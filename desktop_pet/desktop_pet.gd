extends StatusIndicator

func _ready() -> void:
	if not Engine.is_embedded_in_editor():
		var win := get_window()
		win.always_on_top = true
		win.unfocusable = false
	get_tree().auto_accept_quit = false


func _apply_window_flags() -> void:
	if Engine.is_embedded_in_editor():
		return
	var win := get_window()
	win.always_on_top = true
	win.unfocusable = false


func _notification(what: int) -> void:
	if Engine.is_embedded_in_editor():
		return
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		get_window().hide()

func _on_pressed(mouse_button: int, _mouse_position: Vector2i) -> void:
	if mouse_button == MOUSE_BUTTON_LEFT:
		var win := get_window()
		win.show()
		win.mode = Window.MODE_WINDOWED
		win.grab_focus()
