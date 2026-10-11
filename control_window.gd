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
	# 原生窗口在 show() 里才创建，视口还挂在无效窗口上，首帧是透明的。
	# 再走一次内容缩放会把视口接到已经映射的窗口，不用改窗口尺寸。
	content_scale_factor = content_scale_factor
