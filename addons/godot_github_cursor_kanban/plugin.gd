@tool
extends EditorPlugin

const _DOCK_SCENE := preload("res://addons/godot_github_cursor_kanban/dock.tscn")
const _TRANSLATION_CSV := "res://addons/godot_github_cursor_kanban/translations/kanban.csv"
const _PROPERTY_DOMAIN := "godot.properties"
const _SETTING_RESTART := "kanban/restart_editor_after_branch_switch"
const _SETTING_TOKEN := "kanban/cursor_token"

var _dock: EditorDock
var _translations: Array[Translation] = []


func _enter_tree() -> void:
	_install_translations()
	_register_editor_settings()
	var content := _DOCK_SCENE.instantiate() as Control
	content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_dock = EditorDock.new()
	_dock.title = "看板"
	# 独立 layout_key，不沿用上次停在错误槽位的布局记录。
	_dock.layout_key = "godot_github_cursor_kanban"
	_dock.default_slot = EditorDock.DOCK_SLOT_LEFT_BR
	_dock.add_child(content)
	add_dock(_dock)


func _exit_tree() -> void:
	_uninstall_translations()
	if _dock:
		remove_dock(_dock)
		_dock.free()
		_dock = null


func _register_editor_settings() -> void:
	var settings := EditorInterface.get_editor_settings()
	_ensure_setting(settings, _SETTING_RESTART, true, TYPE_BOOL, PROPERTY_HINT_NONE)
	_ensure_setting(settings, _SETTING_TOKEN, "", TYPE_STRING, PROPERTY_HINT_PASSWORD)


func _ensure_setting(settings: EditorSettings, key: String, default_value: Variant, type: int, hint: int) -> void:
	if not settings.has_setting(key):
		settings.set_setting(key, default_value)
	settings.set_initial_value(key, default_value, false)
	settings.add_property_info({
		"name": key,
		"type": type,
		"hint": hint,
	})


func _install_translations() -> void:
	_uninstall_translations()
	var rows := _read_translation_rows()
	if rows.is_empty():
		return
	var property_domain := TranslationServer.get_or_add_domain(_PROPERTY_DOMAIN)
	for locale in ["zh", "zh_CN", "en"]:
		var translation := Translation.new()
		translation.locale = locale
		for row in rows:
			var message: String = row["zh"] if locale.begins_with("zh") else row["en"]
			translation.add_message(row["key"], message)
		TranslationServer.add_translation(translation)
		property_domain.add_translation(translation)
		_translations.append(translation)


func _uninstall_translations() -> void:
	if _translations.is_empty():
		return
	var property_domain := TranslationServer.get_or_add_domain(_PROPERTY_DOMAIN)
	for translation in _translations:
		TranslationServer.remove_translation(translation)
		property_domain.remove_translation(translation)
	_translations.clear()


func _read_translation_rows() -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	var file := FileAccess.open(_TRANSLATION_CSV, FileAccess.READ)
	if file == null:
		return rows
	file.get_line()
	while not file.eof_reached():
		var line := file.get_line().strip_edges()
		if line.is_empty():
			continue
		var parts := line.split(",", false)
		if parts.size() < 3:
			continue
		rows.append({"key": parts[0], "en": parts[1], "zh": parts[2]})
	return rows
