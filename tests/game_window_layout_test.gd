extends SceneTree

const GameWindowScript := preload("res://game/window_screen_anchor.gd")


func _initialize() -> void:
	var screen_x := 100
	var screen_width := 1920
	var screen_right := screen_x + screen_width
	var flush_left := GameWindowScript.anchored_x_on_screen(screen_x, 960, 480, screen_x, screen_width)
	if flush_left != screen_x:
		push_error("贴左缩小应继续贴左，实际 %s" % flush_left)
		quit(1)
		return
	var flush_right := GameWindowScript.anchored_x_on_screen(screen_right - 960, 960, 480, screen_x, screen_width)
	if flush_right != screen_right - 480:
		push_error("贴右缩小应继续贴右，实际 %s" % flush_right)
		quit(1)
		return
	var centered := GameWindowScript.anchored_x_on_screen(screen_x + 480, 960, 480, screen_x, screen_width)
	if centered != screen_x + 720:
		push_error("未贴边应保持中心，实际 %s" % centered)
		quit(1)
		return
	var grew_past_right := GameWindowScript.anchored_x_on_screen(screen_x + 1400, 400, 800, screen_x, screen_width)
	if grew_past_right != screen_right - 800:
		push_error("未贴边放大不应探出右缘，实际 %s" % grew_past_right)
		quit(1)
		return
	var full_width := GameWindowScript.anchored_x_on_screen(screen_x, screen_width, 480, screen_x, screen_width)
	if full_width != screen_x:
		push_error("铺满后缩小应贴左，实际 %s" % full_width)
		quit(1)
		return
	print("game_window_layout_ok")
	quit(0)
