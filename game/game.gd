extends Node

const WORLD_WIDTH := 4096.0

var _dragging := false


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse_button := event as InputEventMouseButton
		if mouse_button.button_index != MOUSE_BUTTON_LEFT:
			return
		_dragging = mouse_button.pressed
	elif _dragging and event is InputEventMouseMotion:
		var motion := event as InputEventMouseMotion
		var camera := %Camera2D
		camera.position.x = _clamp_camera_x(camera.position.x - motion.relative.x)


func _clamp_camera_x(x: float) -> float:
	var half_view := get_viewport().get_visible_rect().size.x * 0.5
	return clampf(x, half_view, WORLD_WIDTH - half_view)
