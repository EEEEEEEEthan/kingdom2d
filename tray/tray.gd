extends StatusIndicator

signal control_window_open_requested
signal quit_requested

enum MenuId { SHOW_CONTROL_WINDOW, QUIT }

var _tray_supported := (
	DisplayServer.has_feature(DisplayServer.FEATURE_STATUS_INDICATOR)
	and not Engine.is_embedded_in_editor()
)

@onready var _menu: PopupMenu = $PopupMenu


func _on_pressed(mouse_button: int, _mouse_position: Vector2i) -> void:
	if not _tray_supported:
		return
	match mouse_button:
		MOUSE_BUTTON_LEFT:
			control_window_open_requested.emit()
		MOUSE_BUTTON_RIGHT:
			var global_mouse := DisplayServer.mouse_get_position()
			var screen := DisplayServer.get_screen_from_rect(Rect2(global_mouse, Vector2.ONE))
			var screen_mouse := global_mouse - DisplayServer.screen_get_position(screen)
			_menu.current_screen = screen
			_menu.popup(Rect2i(screen_mouse, Vector2i.ZERO))


func _on_popup_menu_id_pressed(id: int) -> void:
	if not _tray_supported:
		return
	match id as MenuId:
		MenuId.SHOW_CONTROL_WINDOW:
			control_window_open_requested.emit()
		MenuId.QUIT:
			quit_requested.emit()
