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
	# 普通 Window 在这套逐像素透明下客户区不绘制。弹层和菜单同一条路径，内容才看得到。
	popup(Rect2i(pos, window_size))
