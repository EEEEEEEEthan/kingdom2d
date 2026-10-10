extends SceneTree

func _init() -> void:
	call_deferred("_go")


func _go() -> void:
	var main := (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await process_frame
	var controller := main.get_node("DisplayScaleWheelController")
	var settings := root.get_node("Settings")
	settings.display_scale = 2
	settings.game_width_ratio = 1.0
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_WHEEL_DOWN
	down.pressed = true
	down.alt_pressed = true
	controller._try_apply_display_scale_wheel(down, main.get_window())
	var width_ok := is_equal_approx(settings.game_width_ratio, 0.875)
	var scale_unchanged: bool = settings.display_scale == 2
	var up := InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_WHEEL_UP
	up.pressed = true
	up.ctrl_pressed = true
	controller._try_apply_display_scale_wheel(up, main.get_window())
	var scale_ok: bool = settings.display_scale == 3
	var width_still := is_equal_approx(settings.game_width_ratio, 0.875)
	if width_ok and scale_unchanged and scale_ok and width_still:
		print("通过 alt滚轮调宽度")
		quit(0)
	else:
		print("失败 alt滚轮调宽度 ratio=%s scale=%s" % [settings.game_width_ratio, settings.display_scale])
		quit(1)
