extends SceneTree

const GameWindowScript := preload("res://game/game_window.gd")


func _initialize() -> void:
	var screen_x := 0
	var screen_width := 1920
	var old_size := Vector2i(960, 64)
	var new_size := Vector2i(1920, 64)
	var near_right := GameWindowScript.anchored_position_on_screen(
		Vector2i(800, 1000),
		old_size,
		new_size,
		screen_x,
		screen_width,
	)
	if near_right.x != 0 or near_right.y != 1000:
		push_error("贴右扩宽应贴齐屏幕左缘并保持底边，实际 %s" % near_right)
		quit(1)
		return
	var near_left := GameWindowScript.anchored_position_on_screen(
		Vector2i(-200, 1000),
		old_size,
		new_size,
		screen_x,
		screen_width,
	)
	if near_left.x != 0:
		push_error("贴左扩宽不应再往左，实际 %s" % near_left.x)
		quit(1)
		return
	var centered := GameWindowScript.anchored_position_on_screen(
		Vector2i(480, 1000),
		old_size,
		Vector2i(480, 128),
		screen_x,
		screen_width,
	)
	if centered != Vector2i(720, 936):
		push_error("屏内缩放应保持底边中心，实际 %s" % centered)
		quit(1)
		return
	print("game_window_layout_ok")
	quit(0)
