extends Node

var _dragging := false
var _center_x: float
var _drag_camera_x: float
var _drag_anchor_mouse_x: float


func _ready() -> void:
	var camera := %Camera2D
	camera.position_smoothing_enabled = false
	_center_x = _terrain_center_x()
	camera.position.x = _clamp_camera_x(_center_x)
	camera.position_smoothing_enabled = true


func _on_reset_camera_pressed() -> void:
	%Camera2D.position.x = _clamp_camera_x(_center_x)


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
		var camera := %Camera2D
		_dragging = mouse_button.pressed
		camera.position_smoothing_enabled = not _dragging
		if _dragging:
			camera.reset_smoothing()
			_drag_camera_x = camera.position.x
			_drag_anchor_mouse_x = mouse_button.position.x
	elif _dragging and event is InputEventMouseMotion:
		var motion := event as InputEventMouseMotion
		var delta_x := motion.position.x - _drag_anchor_mouse_x
		%Camera2D.position.x = _clamp_camera_x(_drag_camera_x - delta_x)


func _view_half_width() -> float:
	var viewport := get_viewport()
	if viewport is Window:
		return float(viewport.content_scale_size.x) * 0.5
	return viewport.get_visible_rect().size.x * 0.5


func _clamp_camera_x(x: float) -> float:
	var x_range := _terrain_x_range()
	var half_view := _view_half_width()
	return clampf(x, x_range.x + half_view, x_range.y - half_view)
