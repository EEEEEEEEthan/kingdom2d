@tool
extends EditorPlugin

const _DOCK_SCENE := preload("res://addons/godot_github_cursor_kanban/dock.tscn")
const _GEAR_PATH := "res://addons/godot_github_cursor_kanban/icons/gear.png"
const _SECTION := "kanban"
# 勾选框文案直接作为设置名，检查器会按原样显示。
const _SETTING_RESTART := "kanban/切换分支后自动重启编辑器"
const _SETTING_TOKEN := "kanban/cursor_token"

var _dock: EditorDock


func _enter_tree() -> void:
	_register_editor_settings()

	var content := _DOCK_SCENE.instantiate() as Control
	content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var settings_button := content.get_node("Settings") as Button
	settings_button.icon = _settings_button_icon()
	settings_button.tooltip_text = "看板设置"
	settings_button.pressed.connect(_open_kanban_editor_settings)

	_dock = EditorDock.new()
	_dock.title = "看板"
	# 独立 layout_key，不沿用上次停在错误槽位的布局记录。
	_dock.layout_key = "godot_github_cursor_kanban"
	_dock.default_slot = EditorDock.DOCK_SLOT_LEFT_BR
	_dock.add_child(content)
	add_dock(_dock)


func _exit_tree() -> void:
	if _dock:
		remove_dock(_dock)
		_dock.free()
		_dock = null


func _register_editor_settings() -> void:
	var settings := EditorInterface.get_editor_settings()
	_ensure_setting(settings, _SETTING_RESTART, true, TYPE_BOOL, PROPERTY_HINT_NONE)
	_ensure_setting(settings, _SETTING_TOKEN, "", TYPE_STRING, PROPERTY_HINT_PASSWORD)


func _ensure_setting(
	settings: EditorSettings,
	key: String,
	default_value: Variant,
	type: int,
	hint: int
) -> void:
	# 已有值时不覆盖，避免把用户填过的 token 清掉。
	if not settings.has_setting(key):
		settings.set_setting(key, default_value)
	settings.set_initial_value(key, default_value, false)
	settings.add_property_info({
		"name": key,
		"type": type,
		"hint": hint,
	})


func _settings_button_icon() -> Texture2D:
	var base := EditorInterface.get_base_control()
	if base:
		# 4.7 的 EditorIcons 没有齿轮；若以后版本加了，优先用主题图标。
		for icon_name in ["Gear", "Settings", "Cog"]:
			if base.has_theme_icon(icon_name, "EditorIcons"):
				return base.get_theme_icon(icon_name, "EditorIcons")
	return _load_gear_texture()


func _load_gear_texture() -> Texture2D:
	var file := FileAccess.open(_GEAR_PATH, FileAccess.READ)
	if file == null:
		return null
	var image := Image.new()
	if image.load_png_from_buffer(file.get_buffer(file.get_length())) != OK:
		return null
	return ImageTexture.create_from_image(image)


func _open_kanban_editor_settings() -> void:
	# Godot 4.7 的 EditorInterface 没有 edit_settings，改走编辑器菜单同一条路径。
	if EditorInterface.has_method("edit_settings"):
		EditorInterface.call("edit_settings")
	elif not _emit_editor_settings_menu():
		push_warning("看板：打不开编辑器设置。")
		return
	_focus_kanban_section.call_deferred()


func _emit_editor_settings_menu() -> bool:
	var base := EditorInterface.get_base_control()
	if base == null:
		return false
	var menu := _find_editor_settings_menu(base)
	if menu == null:
		return false
	for index in menu.item_count:
		var text := menu.get_item_text(index)
		if _is_editor_settings_label(text):
			menu.emit_signal("id_pressed", menu.get_item_id(index))
			return true
	return false


func _is_editor_settings_label(text: String) -> bool:
	var normalized := text.replace(".", "").replace("…", "").strip_edges()
	return normalized == "Editor Settings" or normalized == "编辑器设置"


func _focus_kanban_section() -> void:
	var base := EditorInterface.get_base_control()
	if base == null:
		return
	var dialog := _find_by_class(base, "EditorSettingsDialog")
	if dialog == null or not dialog.visible:
		return
	var sectioned := _find_by_class(dialog, "SectionedInspector")
	if sectioned == null:
		return
	var search_box := _find_filter_line_edit(dialog)
	if search_box:
		search_box.text = _SECTION
	if sectioned.has_method("update_category_list"):
		sectioned.call("update_category_list")
	var tree := _find_by_class(sectioned, "Tree") as Tree
	if tree == null or tree.get_root() == null:
		return
	var item := _find_section_item(tree.get_root(), _SECTION)
	if item:
		item.select(0)
		tree.scroll_to_item(item)


func _find_editor_settings_menu(node: Node) -> PopupMenu:
	if node is PopupMenu:
		var menu := node as PopupMenu
		for index in menu.item_count:
			if _is_editor_settings_label(menu.get_item_text(index)):
				return menu
	for child in node.get_children():
		var found := _find_editor_settings_menu(child)
		if found:
			return found
	return null


func _find_by_class(node: Node, wanted_class: String) -> Node:
	if node.get_class() == wanted_class:
		return node
	for child in node.get_children():
		var found := _find_by_class(child, wanted_class)
		if found:
			return found
	return null


func _find_filter_line_edit(dialog: Node) -> LineEdit:
	var matches: Array[LineEdit] = []
	_collect_line_edits(dialog, matches)
	for line_edit in matches:
		if line_edit.placeholder == "Filter Settings" or line_edit.placeholder == "筛选设置":
			return line_edit
	return matches[0] if not matches.is_empty() else null


func _collect_line_edits(node: Node, into: Array[LineEdit]) -> void:
	if node is LineEdit:
		into.append(node)
	for child in node.get_children():
		_collect_line_edits(child, into)


func _find_section_item(item: TreeItem, section: String) -> TreeItem:
	var sibling := item
	while sibling:
		if str(sibling.get_metadata(0)) == section:
			return sibling
		if sibling.get_child_count() > 0:
			var nested := _find_section_item(sibling.get_first_child(), section)
			if nested:
				return nested
		sibling = sibling.get_next()
	return null
