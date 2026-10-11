extends Control

var _dragging := false
var _offset := Vector2i.ZERO


func _gui_input(event: InputEvent) -> void:
	var window := get_window()
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_dragging = true
			_offset = DisplayServer.mouse_get_position() - window.position
		else:
			_dragging = false
		accept_event()
	elif event is InputEventMouseMotion and _dragging:
		window.position = DisplayServer.mouse_get_position() - _offset
		accept_event()
