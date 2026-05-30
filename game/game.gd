extends Node

var _center_x: float
var _drag_loop_active := false


func _ready() -> void:
	_center_x = _terrain_center_x()
	%Camera2D.position.x = _clamp_camera_x(_center_x)


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
	if not event is InputEventMouseButton:
		return
	var mouse_button := event as InputEventMouseButton
	if mouse_button.button_index != MOUSE_BUTTON_LEFT or not mouse_button.pressed:
		return
	if _drag_loop_active:
		return
	_drag_pan_loop()


func _drag_pan_loop() -> void:
	_drag_loop_active = true
	var anchor_mouse_x := get_viewport().get_mouse_position().x
	var anchor_camera_x: float = %Camera2D.position.x
	var camera_x = anchor_camera_x
	while Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		var delta_x := get_viewport().get_mouse_position().x - anchor_mouse_x
		var x = round(_clamp_camera_x(anchor_camera_x - delta_x))
		if abs(camera_x - %Camera2D.position.x) > 1:
			printerr(str(%Camera2D.position.x) + "-" + str(camera_x))
		%Camera2D.position.x = x
		camera_x = x
		await get_tree().process_frame
	_drag_loop_active = false


func _view_half_width() -> float:
	var viewport := get_viewport()
	if viewport is Window:
		return float(viewport.content_scale_size.x) * 0.5
	return viewport.get_visible_rect().size.x * 0.5


func _clamp_camera_x(x: float) -> float:
	var x_range := _terrain_x_range()
	var half_view := _view_half_width()
	return clampf(x, x_range.x + half_view, x_range.y - half_view)
