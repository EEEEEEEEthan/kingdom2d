extends StatusIndicator

const MENU_ALWAYS_ON_TOP := 0
const MENU_QUIT := 1

var _tray_supported := (
	DisplayServer.has_feature(DisplayServer.FEATURE_STATUS_INDICATOR)
	and not Engine.is_embedded_in_editor()
)


func _ready() -> void:
	_apply_window_flags()
	if not _tray_supported:
		visible = false
		return

	$Menu.add_check_item("置顶", MENU_ALWAYS_ON_TOP)
	$Menu.set_item_checked(MENU_ALWAYS_ON_TOP, get_window().always_on_top)
	$Menu.add_separator()
	$Menu.add_item("退出", MENU_QUIT)
	$Menu.about_to_popup.connect(_on_menu_about_to_popup)
	$Menu.id_pressed.connect(_on_menu_id_pressed)
	pressed.connect(_on_pressed)
	menu = $Menu.get_path()
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


func _show_window() -> void:
	var win := get_window()
	win.show()
	win.mode = Window.MODE_WINDOWED


func _on_menu_about_to_popup() -> void:
	$Menu.set_item_checked(MENU_ALWAYS_ON_TOP, get_window().always_on_top)


func _on_pressed(mouse_button: int, _mouse_position: Vector2i) -> void:
	if mouse_button == MOUSE_BUTTON_LEFT:
		_show_window()


func _on_menu_id_pressed(menu_id: int) -> void:
	match menu_id:
		MENU_ALWAYS_ON_TOP:
			get_window().always_on_top = $Menu.is_item_checked(MENU_ALWAYS_ON_TOP)
		MENU_QUIT:
			get_tree().quit()
