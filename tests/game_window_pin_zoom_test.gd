extends SceneTree

func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var window := (load("res://game/game_window.tscn") as PackedScene).instantiate()
	root.add_child(window)
	await process_frame
	await process_frame
	window.pined = true
	window.scale = 1
	await process_frame
	var slide := window.get_node("GameWindowSlideController")
	var dock_before: int = window.compute_docked_global_position().y
	if window.position.y != dock_before:
		push_error("钉住时应贴底，实际 %s 期望 %s" % [window.position.y, dock_before])
		quit(1)
		return
	window.scale = 2
	var dock_after: int = window.compute_docked_global_position().y
	if int(slide._slide_pos_y) != dock_after:
		push_error("钉住时缩放应马上记下贴底坐标，实际 %s 期望 %s" % [slide._slide_pos_y, dock_after])
		quit(1)
		return
	slide._process(0.05)
	if window.position.y != dock_after:
		push_error("钉住时缩放应立即贴底，实际 %s 期望 %s" % [window.position.y, dock_after])
		quit(1)
		return
	print("game_window_pin_zoom_ok")
	quit(0)
