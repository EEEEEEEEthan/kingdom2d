extends Window

signal reset_game_requested


func _ready() -> void:
	visible = false
	# 工程开了逐像素透明。设置窗若不走透明视口，客户区在合成器里是空的。
	# 下面用实色铺满，文字和滑条才能看清。
	transparent = true
	transparent_bg = true


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
