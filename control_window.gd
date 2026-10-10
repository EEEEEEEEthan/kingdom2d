extends PopupPanel

signal reset_game_requested


func _ready() -> void:
	visible = false
	var panel := StyleBoxFlat.new()
	panel.bg_color = Color(0.561, 0.337, 0.231, 1)
	panel.set_content_margin_all(6)
	add_theme_stylebox_override("panel", panel)


func open_near_mouse() -> void:
	var pos := DisplayServer.mouse_get_position()
	var screen := DisplayServer.get_screen_from_rect(Rect2(pos, Vector2.ONE))
	var usable := DisplayServer.screen_get_usable_rect(screen)
	var window_size := size
	pos.x = clampi(pos.x, usable.position.x, usable.position.x + maxi(0, usable.size.x - window_size.x))
	pos.y = clampi(pos.y, usable.position.y, usable.position.y + maxi(0, usable.size.y - window_size.y))
	current_screen = screen
	popup(Rect2i(pos, size))
