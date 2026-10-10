extends Window

signal reset_game_requested


func _ready() -> void:
	visible = false


func open_near_mouse() -> void:
	var pos := DisplayServer.mouse_get_position()
	var screen := DisplayServer.get_screen_from_rect(Rect2(pos, Vector2.ONE))
	var usable := DisplayServer.screen_get_usable_rect(screen)
	var window_size := size
	pos.x = clampi(pos.x, usable.position.x, usable.position.x + maxi(0, usable.size.x - window_size.x))
	pos.y = clampi(pos.y, usable.position.y, usable.position.y + maxi(0, usable.size.y - window_size.y))
	current_screen = screen
	position = pos
	show()
	mode = MODE_WINDOWED
	grab_focus()
	_commit_first_frame(window_size)


# 隐藏状态下创建的原生窗口，第一次显示时系统往往不发尺寸变化，画布停在透明。
# 改一次尺寸再改回，才会提交首帧。
func _commit_first_frame(window_size: Vector2i) -> void:
	size = window_size + Vector2i(1, 0)
	await get_tree().process_frame
	if not is_inside_tree() or not visible:
		return
	size = window_size
