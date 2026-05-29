extends StatusIndicator

var _tray_supported := (
	DisplayServer.has_feature(DisplayServer.FEATURE_STATUS_INDICATOR)
	and not Engine.is_embedded_in_editor()
)


func _ready() -> void:
	_apply_window_flags()
	if not _tray_supported:
		visible = false
		return

	$Menu.add_item("显示窗口", 0)
	$Menu.add_item("退出", 1)
	$Menu.id_pressed.connect(_on_menu_id_pressed)
	get_tree().auto_accept_quit = false


func _apply_window_flags() -> void:
	if Engine.is_embedded_in_editor():
		return
	var win := get_window()
	win.always_on_top = true
	win.unfocusable = true


func _notification(what: int) -> void:
	if not _tray_supported:
		return
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		get_window().hide()


func _on_menu_id_pressed(id: int) -> void:
	match id:
		0:
			var win := get_window()
			win.show()
			win.mode = Window.MODE_WINDOWED
		1:
			get_tree().quit()
