extends Window

const BASE_WIDTH := 640
const BASE_HEIGHT := 64

var _dragging := false
var _drag_mouse_offset := Vector2i.ZERO
var _scale := 1
var _scale_initialized := false

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse_button := event as InputEventMouseButton
		if mouse_button.button_index != MOUSE_BUTTON_RIGHT:
			return
		if mouse_button.pressed:
			_dragging = true
			_drag_mouse_offset = DisplayServer.mouse_get_position() - position
		else:
			_dragging = false
	elif event is InputEventMouseMotion and _dragging:
		position = DisplayServer.mouse_get_position() - _drag_mouse_offset


func apply_scale(scale: int) -> void:
	_scale = scale
	content_scale_size = Vector2i(BASE_WIDTH, BASE_HEIGHT)
	content_scale_factor = float(scale)
	var height := BASE_HEIGHT * scale
	var width := size.x if _scale_initialized else BASE_WIDTH * scale
	_scale_initialized = true
	size = Vector2i(width, height)
	_align_to_screen_bottom(height)


func apply_width_ratio(width_ratio: float) -> void:
	var width := _width_from_screen_ratio(width_ratio)
	var height := BASE_HEIGHT * _scale
	content_scale_size = Vector2i(BASE_WIDTH, BASE_HEIGHT)
	content_scale_factor = float(_scale)
	size = Vector2i(width, height)
	_align_to_screen_bottom(height)


func _width_from_screen_ratio(width_ratio: float) -> int:
	var screen_size := DisplayServer.screen_get_size(current_screen)
	return maxi(1, int(round(screen_size.x * width_ratio)))


func _align_to_screen_bottom(height: int) -> void:
	var screen := current_screen
	var screen_pos := DisplayServer.screen_get_position(screen)
	var usable := DisplayServer.screen_get_usable_rect(screen)
	position = Vector2i(
		screen_pos.x,
		usable.position.y + usable.size.y - height,
	)
