extends StatusIndicator

enum MenuId { SHOW_LAUNCHER, QUIT }

var _tray_supported := (
	DisplayServer.has_feature(DisplayServer.FEATURE_STATUS_INDICATOR)
	and not Engine.is_embedded_in_editor()
)

const ENGINE_ROOT_OFFSCREEN_POS := Vector2i(-32000, -32000)
const ENGINE_ROOT_SIZE := Vector2i(1, 1)

var _launcher: Window

@onready var _menu: PopupMenu = $PopupMenu


func _ready() -> void:
	visible = false
	if not _tray_supported:
		return

	get_tree().auto_accept_quit = false
	_menu.id_pressed.connect(_on_menu_id_pressed)

	await get_tree().process_frame
	_launcher = get_tree().current_scene.get_node(^"Launcher") as Window
	_launcher.close_requested.connect(_on_launcher_close_requested)

	_pin_engine_root_offscreen()
	await get_tree().process_frame
	_pin_engine_root_offscreen()
	get_window().close_requested.connect(_on_engine_root_close_requested)


func _notification(what: int) -> void:
	if not _tray_supported:
		return
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_hide_to_tray()


func _pin_engine_root_offscreen() -> void:
	var root := get_window()
	root.unfocusable = true
	root.min_size = ENGINE_ROOT_SIZE
	root.max_size = ENGINE_ROOT_SIZE
	root.size = ENGINE_ROOT_SIZE
	root.position = ENGINE_ROOT_OFFSCREEN_POS


func _on_engine_root_close_requested() -> void:
	_hide_to_tray()


func _on_launcher_close_requested() -> void:
	_hide_to_tray()


func _hide_to_tray() -> void:
	_launcher.hide()
	_pin_engine_root_offscreen()
	visible = true


func _show_launcher() -> void:
	_launcher.show()
	_launcher.mode = Window.MODE_WINDOWED
	_launcher.grab_focus()
	visible = false


func _on_menu_id_pressed(id: int) -> void:
	match id as MenuId:
		MenuId.SHOW_LAUNCHER:
			_show_launcher()
		MenuId.QUIT:
			get_tree().quit()
