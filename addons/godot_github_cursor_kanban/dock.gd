@tool
extends VBoxContainer

const _CARD := preload("res://addons/godot_github_cursor_kanban/card.tscn")
const _CHAT := preload("res://addons/godot_github_cursor_kanban/chat_box.tscn")
const _Client := preload("res://addons/godot_github_cursor_kanban/cursor_client.gd")
const _SETTING_TOKEN := "kanban/cursor_token"
const _SETTING_RESTART := "kanban/restart_editor_after_branch_switch"
const _SECTION := "kanban"

var _refreshing := false
var _next_cursor := ""
var _detail_pending := 0
var _repo_slug := ""
var _chat_windows := {}
var _mutex := Mutex.new()
var _pending: Dictionary = {}
var _pending_ready := false


func _ready() -> void:
	set_process(true)
	$HBoxContainer/Refresh.pressed.connect(_refresh_from_start)
	$"HBoxContainer/Checkout Master".pressed.connect(_checkout_master)
	%Settings.pressed.connect(_open_settings)
	_clear_cards()
	call_deferred("_refresh_from_start")


func _process(_delta: float) -> void:
	var ready := false
	var payload := {}
	_mutex.lock()
	if _pending_ready:
		ready = true
		_pending_ready = false
		payload = _pending
	_mutex.unlock()
	if ready:
		_apply_sessions(
			payload.get("sessions", []),
			str(payload.get("notice", "")),
			str(payload.get("next_cursor", "")),
			bool(payload.get("append", false)),
			str(payload.get("repo_slug", ""))
		)


func _exit_tree() -> void:
	for session_id in _chat_windows.keys():
		var window: Window = _chat_windows[session_id] as Window
		if is_instance_valid(window):
			window.queue_free()
	_chat_windows.clear()


func _refresh_from_start() -> void:
	_load_page("", false)


func _load_more() -> void:
	if _next_cursor.is_empty():
		return
	_load_page(_next_cursor, true)


func _load_page(cursor: String, append: bool) -> void:
	if _refreshing:
		return
	_refreshing = true
	$HBoxContainer/Refresh.disabled = true
	var more := _more_button()
	if more:
		more.disabled = true
	var token := _token()
	var root := ProjectSettings.globalize_path("res://").trim_suffix("/")
	WorkerThreadPool.add_task(func() -> void:
		var slug := _origin_slug(root)
		var payload: Dictionary = _Client.list_unarchived_sessions(token, slug, cursor)
		payload["repo_slug"] = slug
		payload["append"] = append
		if not is_instance_valid(self):
			return
		_mutex.lock()
		_pending = payload
		_pending_ready = true
		_mutex.unlock()
	)


func _apply_sessions(sessions: Array, notice: String, next_cursor: String, append: bool, repo_slug: String) -> void:
	_refreshing = false
	$HBoxContainer/Refresh.disabled = false
	if not is_inside_tree():
		return
	_next_cursor = next_cursor
	if not repo_slug.is_empty():
		_repo_slug = repo_slug
	var list := $ScrollContainer/VBoxContainer
	if not append:
		_clear_cards()
		_detail_pending = 0
	else:
		var more := _more_button()
		if more:
			list.remove_child(more)
			more.free()
	var token := _token()
	var added := 0
	for session in sessions:
		if typeof(session) != TYPE_DICTIONARY:
			continue
		if bool(session.get("archived", false)):
			continue
		var card := _CARD.instantiate()
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.apply(session)
		card.chat_requested.connect(_open_chat)
		card.checkout_requested.connect(_confirm_checkout)
		card.detail_settled.connect(_on_detail_settled)
		list.add_child(card)
		_detail_pending += 1
		card.begin_detail(token, _repo_slug)
		added += 1
	if added == 0 and not notice.is_empty():
		var label := Label.new()
		label.text = notice
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		list.add_child(label)
	if not _next_cursor.is_empty():
		var button := Button.new()
		button.text = "More"
		button.set_meta("kanban_more", true)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(_load_more)
		list.add_child(button)


func _on_detail_settled(_kept: bool) -> void:
	_detail_pending = maxi(_detail_pending - 1, 0)
	if _detail_pending > 0 or not _next_cursor.is_empty():
		return
	if _card_count() > 0:
		return
	var list := $ScrollContainer/VBoxContainer
	var label := Label.new()
	label.text = "当前仓库没有未归档的云端会话。"
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_child(label)


func _card_count() -> int:
	var count := 0
	for child in $ScrollContainer/VBoxContainer.get_children():
		if child.has_signal("detail_settled") and not bool(child.get_meta("kanban_dropping", false)):
			count += 1
	return count


func _more_button() -> Button:
	for child in $ScrollContainer/VBoxContainer.get_children():
		if child is Button and bool(child.get_meta("kanban_more", false)):
			return child
	return null


func _clear_cards() -> void:
	var list := $ScrollContainer/VBoxContainer
	for child in list.get_children():
		list.remove_child(child)
		child.free()


func _open_chat(session_id: String, title: String) -> void:
	if session_id.is_empty():
		return
	var window: Window = _chat_windows.get(session_id) as Window
	if window == null or not is_instance_valid(window):
		window = _CHAT.instantiate()
		EditorInterface.get_base_control().add_child(window)
		_chat_windows[session_id] = window
		window.tree_exited.connect(func() -> void:
			if _chat_windows.get(session_id) == window:
				_chat_windows.erase(session_id)
		)
	window.open_session(_token(), session_id, title)


func _checkout_master() -> void:
	_confirm_checkout("master")


func _confirm_checkout(branch: String) -> void:
	if branch.is_empty():
		return
	var dialog := ConfirmationDialog.new()
	dialog.title = "切换分支"
	dialog.dialog_text = "放弃所有修改并切换到 %s？" % branch
	dialog.ok_button_text = "是"
	dialog.cancel_button_text = "否"
	dialog.confirmed.connect(_checkout_and_restart.bind(branch))
	dialog.confirmed.connect(dialog.queue_free)
	dialog.canceled.connect(dialog.queue_free)
	EditorInterface.get_base_control().add_child(dialog)
	dialog.popup_centered()


func _checkout_and_restart(branch: String) -> void:
	var path := ProjectSettings.globalize_path("res://").trim_suffix("/")
	if not _checkout_branch(path, branch):
		return
	var restart := true
	var settings := EditorInterface.get_editor_settings()
	if settings.has_setting(_SETTING_RESTART):
		restart = bool(settings.get_setting(_SETTING_RESTART))
	if restart and EditorInterface.has_method("restart_editor"):
		EditorInterface.call("restart_editor", true)


func _open_settings() -> void:
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
		if line_edit.placeholder_text == "Filter Settings" or line_edit.placeholder_text == "筛选设置":
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


func _token() -> String:
	var settings := EditorInterface.get_editor_settings()
	if not settings.has_setting(_SETTING_TOKEN):
		return ""
	return str(settings.get_setting(_SETTING_TOKEN))


static func _origin_slug(path: String) -> String:
	var output: Array = []
	var code := OS.execute("git", ["-C", path, "remote", "get-url", "origin"], output, true)
	if code != 0 or output.is_empty():
		return ""
	var text := str(output[0]).strip_edges().trim_suffix(".git")
	if text.contains("github.com"):
		return text.split("github.com")[-1].trim_prefix(":").trim_prefix("/").strip_edges()
	return text


static func _checkout_branch(path: String, branch: String) -> bool:
	if OS.execute("git", ["-C", path, "fetch", "origin", branch], [], true) != 0:
		push_warning("看板：拉取远程分支失败。")
		return false
	if OS.execute("git", ["-C", path, "reset", "--hard"], [], true) != 0:
		push_warning("看板：丢弃本地修改失败。")
		return false
	if OS.execute("git", ["-C", path, "clean", "-fd"], [], true) != 0:
		push_warning("看板：清理未跟踪文件失败。")
		return false
	if OS.execute("git", ["-C", path, "checkout", "-B", branch, "--track", "origin/" + branch], [], true) != 0:
		push_warning("看板：检出分支失败。")
		return false
	return true
