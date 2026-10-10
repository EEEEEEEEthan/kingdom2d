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
	# show() 会先挂视口再映射窗口，首帧画不出来，看起来是透明的。
	# 窗口已经显示后再设一次尺寸，视口会重新接到已映射的窗口上。
	size = window_size
