extends Node

var _dragging := false
var _center_x: float


func _ready() -> void:
	var camera := %Camera2D
	camera.position_smoothing_enabled = false
	_center_x = _terrain_center_x()
	camera.position.x = _clamp_camera_x(_center_x)
	camera.position_smoothing_enabled = true


func _on_reset_camera_pressed() -> void:
	var camera := %Camera2D
	camera.position.x = _clamp_camera_x(_center_x)


func _terrain_x_range() -> Vector2:
	var terrain := %Terrain
	var used: Rect2i = terrain.get_used_rect()
	var tile_w := float(terrain.tile_set.tile_size.x)
	var min_x: float = terrain.position.x + used.position.x * tile_w
	var max_x: float = terrain.position.x + (used.position.x + used.size.x) * tile_w
	return Vector2(min_x, max_x)


func _terrain_center_x() -> float:
	var x_range := _terrain_x_range()
	return (x_range.x + x_range.y) * 0.5


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
	var x_range := _terrain_x_range()
	var half_view := get_viewport().get_visible_rect().size.x * 0.5
	return clampf(x, x_range.x + half_view, x_range.y - half_view)
