extends Node
class_name Settings

signal display_scale_changed(new_scale: int)
signal game_width_ratio_changed(new_ratio: float)

const SETTINGS_FILE_PATH = "user://settings.cfg"

const _SECTION_DISPLAY = "display"
const _KEY_DISPLAY_SCALE = "display_scale"
const _KEY_GAME_WIDTH_RATIO = "game_width_ratio"

var _is_restoring_from_disk := false

var display_scale: int = 1:
	set(value):
		display_scale = value
		if not _is_restoring_from_disk:
			_save_to_disk()
		display_scale_changed.emit(value)

var game_width_ratio: float = 1.0:
	set(value):
		game_width_ratio = value
		if not _is_restoring_from_disk:
			_save_to_disk()
		game_width_ratio_changed.emit(value)


func _ready() -> void:
	if not FileAccess.file_exists(SETTINGS_FILE_PATH):
		return
	var config := ConfigFile.new()
	if config.load(SETTINGS_FILE_PATH) != OK:
		return
	_is_restoring_from_disk = true
	display_scale = config.get_value(_SECTION_DISPLAY, _KEY_DISPLAY_SCALE, display_scale)
	game_width_ratio = config.get_value(_SECTION_DISPLAY, _KEY_GAME_WIDTH_RATIO, game_width_ratio)
	_is_restoring_from_disk = false


func _save_to_disk() -> void:
	var config := ConfigFile.new()
	config.set_value(_SECTION_DISPLAY, _KEY_DISPLAY_SCALE, display_scale)
	config.set_value(_SECTION_DISPLAY, _KEY_GAME_WIDTH_RATIO, game_width_ratio)
	config.save(SETTINGS_FILE_PATH)
