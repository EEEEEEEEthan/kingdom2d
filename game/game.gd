extends Window

var _dragging := false
var _drag_mouse_offset := Vector2i.ZERO

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse_button := event as InputEventMouseButton
		if mouse_button.button_index != MOUSE_BUTTON_LEFT:
			return
		if mouse_button.pressed:
			_dragging = true
			_drag_mouse_offset = DisplayServer.mouse_get_position() - position
		else:
			_dragging = false
	elif event is InputEventMouseMotion and _dragging:
		position = DisplayServer.mouse_get_position() - _drag_mouse_offset
