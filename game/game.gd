extends Window

const BASE_WIDTH := 640
const BASE_HEIGHT := 64

var _dragging := false
var _drag_mouse_offset := Vector2i.ZERO

func _ready() -> void:
	reset_rect()

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


func reset_rect() -> void:
	var screen := current_screen
	var screen_pos := DisplayServer.screen_get_position(screen)
	var screen_size := DisplayServer.screen_get_size(screen)
	var usable := DisplayServer.screen_get_usable_rect(screen)
	var scale := int(round(float(screen_size.x) / float(BASE_WIDTH)))
	var width := screen_size.x
	var height := BASE_HEIGHT * scale
	content_scale_size = Vector2i(BASE_WIDTH, BASE_HEIGHT)
	content_scale_factor = float(scale)
	size = Vector2i(width, height)
	position = Vector2i(
		screen_pos.x,
		usable.position.y + usable.size.y - height,
	)
