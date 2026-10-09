@tool
extends VBoxContainer

const _CARD := preload("res://addons/godot_github_cursor_kanban/card.tscn")
const _CHAT := preload("res://addons/godot_github_cursor_kanban/chat_box.tscn")
const _Client := preload("res://addons/godot_github_cursor_kanban/cursor_client.gd")
const _SETTING_TOKEN := "kanban/cursor_token"
const _SETTING_RESTART := "kanban/restart_editor_after_branch_switch"
const _SECTION := "kanban"

var _refreshing := false
var _list_pending := false
var _next_cursor := ""
var _repo_slug := ""
var _page_token := 0
var _verify_left := 0
var _page_notice := ""
var _page_slots: Array = []
var _archive_checks: Array = []
var _chat_windows := {}
var _new_chat_seq := 0
var _mutex := Mutex.new()
var _pending: Dictionary = {}
var _pending_ready := false


func _ready() -> void:
	set_process(true)
	$HBoxContainer/Refresh.pressed.connect(_refresh_from_start)
	$"HBoxContainer/Checkout Master".pressed.connect(_checkout_master)
	$"HBoxContainer/New Chat".pressed.connect(_open_new_chat)
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
		if int(payload.get("page", -1)) != _page_token:
			return
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
	if _refreshing:
		return
	_refreshing = true
	_page_token += 1
	_verify_left = 0
	_archive_checks = []
	$HBoxContainer/Refresh.disabled = true
	var token := _token()
	var page := _page_token
	var root := ProjectSettings.globalize_path("res://").trim_suffix("/")
	var slug := _origin_slug(root)
	if not slug.is_empty():
		_repo_slug = slug
	_show_cached_sessions(slug)
	_fetch_page("", false, page, slug, token)


func _fetch_page(cursor: String, append: bool, page: int, slug: String, token: String) -> void:
	_list_pending = true
	WorkerThreadPool.add_task(func() -> void:
		var payload: Dictionary = _Client.list_unarchived_sessions(token, slug, cursor)
		payload["repo_slug"] = slug
		payload["append"] = append
		payload["page"] = page
		if not is_instance_valid(self):
			return
		_mutex.lock()
		_pending = payload
		_pending_ready = true
		_mutex.unlock()
	)


func _apply_sessions(sessions: Array, notice: String, next_cursor: String, append: bool, repo_slug: String) -> void:
	if not is_inside_tree():
		_list_pending = false
		_refreshing = false
		return
	_next_cursor = next_cursor
	_page_notice = notice
	if not repo_slug.is_empty():
		_repo_slug = repo_slug
	_list_pending = false
	var list := $ScrollContainer/VBoxContainer
	if not append:
		_remove_notice()
	var entries: Array = []
	var seen := {}
	for session in sessions:
		if typeof(session) != TYPE_DICTIONARY:
			continue
		if bool(session.get("archived", false)):
			_remove_card(str(session.get("id", "")))
			continue
		entries.append(session)
		seen[str(session.get("id", ""))] = true
	_page_slots = []
	_page_slots.resize(entries.size())
	var token := _token()
	var page := _page_token
	for i in entries.size():
		var session: Dictionary = _with_cached_link(entries[i])
		var agent_id := str(session.get("id", ""))
		var cached := _Client.cached_repo_match(agent_id, _repo_slug)
		if cached == 0 or _Client.cached_merged(agent_id) == 1:
			_page_slots[i] = {}
			_remove_card(agent_id)
			if cached == 1:
				_archive_checks.append(session)
		elif cached == 1:
			_page_slots[i] = session
			_upsert_card(session)
			_archive_checks.append(session)
		else:
			_verify_left += 1
			_verify_session(page, i, session, token, _repo_slug)
	if not append:
		for child in list.get_children():
			var agent_id := str(child.get_meta("session_id", ""))
			if agent_id.is_empty() or seen.has(agent_id):
				continue
			var cached_session: Variant = child.get_meta("session", {})
			if typeof(cached_session) == TYPE_DICTIONARY:
				_archive_checks.append(cached_session)
	_flush_archive_checks()
	_persist_sessions()
	if not _next_cursor.is_empty():
		_fetch_page(_next_cursor, true, _page_token, _repo_slug, token)
		return
	_maybe_finish()


func _verify_session(page: int, index: int, session: Dictionary, token: String, repo_slug: String) -> void:
	var agent_id := str(session.get("id", ""))
	WorkerThreadPool.add_task(func() -> void:
		var detail := _Client.request(
			token,
			HTTPClient.METHOD_GET,
			"/v1/agents/%s" % agent_id.uri_encode()
		)
		_Client.remember_repos(agent_id, detail)
		var patch := _Client.detail_patch(detail, repo_slug)
		if is_instance_valid(self):
			call_deferred("_on_verified", page, index, session, patch)
	)


func _on_verified(page: int, index: int, session: Dictionary, patch: Dictionary) -> void:
	if page != _page_token or not is_inside_tree():
		return
	var merged := _session_after_patch(session, patch)
	if index >= 0 and index < _page_slots.size():
		_page_slots[index] = merged
	if merged.is_empty():
		_remove_card(str(session.get("id", "")))
	else:
		_upsert_card(merged)
	_verify_left -= 1
	_persist_sessions()
	_maybe_finish()


func _session_after_patch(session: Dictionary, patch: Dictionary) -> Dictionary:
	if bool(patch.get("_error", false)):
		return session
	if patch.is_empty():
		return {}
	var merged := session.duplicate()
	merged["name"] = str(patch.get("name", session.get("name", "")))
	merged["url"] = str(patch.get("url", session.get("url", "")))
	merged["working"] = bool(patch.get("working", false))
	var branch := str(patch.get("branch", ""))
	if not branch.is_empty():
		merged["branch"] = branch
	var pr_url := str(patch.get("pr_url", ""))
	if not pr_url.is_empty():
		merged["pr_url"] = pr_url
	return merged


func _flush_archive_checks() -> void:
	var checks := _archive_checks
	_archive_checks = []
	var token := _token()
	var page := _page_token
	for session in checks:
		if typeof(session) != TYPE_DICTIONARY:
			continue
		_refresh_archive(page, session, token, _repo_slug)


func _maybe_finish() -> void:
	if _list_pending or _verify_left > 0 or not _next_cursor.is_empty():
		return
	_page_slots = []
	_finish_page(_card_count())


func _refresh_archive(page: int, session: Dictionary, token: String, repo_slug: String) -> void:
	var agent_id := str(session.get("id", ""))
	WorkerThreadPool.add_task(func() -> void:
		var detail := _Client.request(
			token,
			HTTPClient.METHOD_GET,
			"/v1/agents/%s" % agent_id.uri_encode()
		)
		_Client.remember_repos(agent_id, detail)
		var patch := _Client.detail_patch(detail, repo_slug)
		patch = _drop_if_branch_merged(agent_id, session, patch)
		if is_instance_valid(self):
			call_deferred("_on_archive", page, session, patch)
	)


func _on_archive(page: int, session: Dictionary, patch: Dictionary) -> void:
	if page != _page_token or not is_inside_tree():
		return
	var agent_id := str(session.get("id", ""))
	if bool(patch.get("_error", false)):
		return
	if patch.is_empty():
		_remove_card(agent_id)
		_persist_sessions()
		_show_empty_if_needed()
		return
	var merged := _session_after_patch(session, patch)
	_remove_notice()
	_upsert_card(merged)
	_persist_sessions()


func _show_cached_sessions(repo_slug: String) -> void:
	_clear_cards()
	for session in _Client.load_session_list(repo_slug):
		if typeof(session) != TYPE_DICTIONARY:
			continue
		session = _with_cached_link(session)
		if _Client.cached_merged(str(session.get("id", ""))) == 1:
			continue
		_add_card(session)


func _with_cached_link(session: Dictionary) -> Dictionary:
	var copy := session.duplicate()
	var agent_id := str(copy.get("id", ""))
	var pr: Variant = _Client.cached_pr_url(agent_id)
	if pr != null and str(copy.get("pr_url", "")).is_empty():
		copy["pr_url"] = str(pr)
	var branch := _Client.cached_branch(agent_id)
	if not branch.is_empty() and str(copy.get("branch", "")).is_empty():
		copy["branch"] = branch
	return copy


func _drop_if_branch_merged(agent_id: String, session: Dictionary, patch: Dictionary) -> Dictionary:
	if bool(patch.get("_error", false)) or patch.is_empty():
		return patch
	var branch := str(patch.get("branch", session.get("branch", "")))
	if branch.is_empty():
		branch = _Client.cached_branch(agent_id)
	if branch.is_empty() or branch == "master":
		_Client.remember_merged(agent_id, false)
		return patch
	var root := ProjectSettings.globalize_path("res://").trim_suffix("/")
	if OS.execute("git", ["-C", root, "fetch", "origin", branch, "master"], [], true) != 0:
		return patch
	var merged := _Client.branch_merged(root, branch)
	if merged == 1:
		_Client.remember_merged(agent_id, true)
		return {}
	if merged == 0:
		_Client.remember_merged(agent_id, false)
	return patch


func _persist_sessions() -> void:
	if _repo_slug.is_empty():
		return
	var sessions: Array = []
	for child in $ScrollContainer/VBoxContainer.get_children():
		var session: Variant = child.get_meta("session", null)
		if typeof(session) != TYPE_DICTIONARY:
			continue
		sessions.append(session)
	_Client.save_session_list(_repo_slug, sessions)


func _upsert_card(session: Dictionary) -> void:
	var agent_id := str(session.get("id", ""))
	var card := _find_card(agent_id)
	if card:
		card.set_meta("session", session.duplicate())
		card.apply(session)
		return
	_add_card(session)


func _add_card(session: Dictionary) -> void:
	var list := $ScrollContainer/VBoxContainer
	var card := _CARD.instantiate()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.set_meta("session_id", str(session.get("id", "")))
	card.set_meta("session", session.duplicate())
	card.apply(session)
	card.chat_requested.connect(_open_chat)
	card.checkout_requested.connect(_checkout_branch_prompt)
	list.add_child(card)


func _find_card(session_id: String) -> Node:
	for child in $ScrollContainer/VBoxContainer.get_children():
		if str(child.get_meta("session_id", "")) == session_id:
			return child
	return null


func _remove_card(session_id: String) -> void:
	var card := _find_card(session_id)
	if card == null:
		return
	var list := $ScrollContainer/VBoxContainer
	list.remove_child(card)
	card.free()


func _remove_notice() -> void:
	var list := $ScrollContainer/VBoxContainer
	for child in list.get_children():
		if child is Label:
			list.remove_child(child)
			child.free()


func _show_empty_if_needed() -> void:
	if _card_count() > 0 or not _next_cursor.is_empty() or _refreshing:
		return
	if _has_notice():
		return
	var label := Label.new()
	label.text = "当前仓库没有未归档的云端会话。"
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	$ScrollContainer/VBoxContainer.add_child(label)


func _has_notice() -> bool:
	for child in $ScrollContainer/VBoxContainer.get_children():
		if child is Label:
			return true
	return false


func _finish_page(added: int) -> void:
	if not is_inside_tree():
		_refreshing = false
		return
	_refreshing = false
	$HBoxContainer/Refresh.disabled = false
	var list := $ScrollContainer/VBoxContainer
	var text := ""
	if _page_notice.contains("失败") or (added == 0 and not _page_notice.is_empty()):
		text = _page_notice
	elif added == 0:
		text = "当前仓库没有未归档的云端会话。"
	if not text.is_empty():
		var label := Label.new()
		label.text = text
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		list.add_child(label)


func _card_count() -> int:
	var count := 0
	for child in $ScrollContainer/VBoxContainer.get_children():
		if child.has_signal("detail_settled"):
			count += 1
	return count


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


func _open_new_chat() -> void:
	if _token().is_empty():
		push_warning("看板：未配置 Cursor token。")
		return
	var path := ProjectSettings.globalize_path("res://").trim_suffix("/")
	var slug := _origin_slug(path)
	if slug.is_empty():
		push_warning("看板：读不到当前仓库的 origin。")
		return
	var ref := _current_branch(path)
	if ref.is_empty():
		ref = "master"
	_new_chat_seq += 1
	var key := "new:%d" % _new_chat_seq
	var window: Window = _CHAT.instantiate()
	EditorInterface.get_base_control().add_child(window)
	_chat_windows[key] = window
	window.tree_exited.connect(func() -> void:
		if _chat_windows.get(key) == window:
			_chat_windows.erase(key)
	)
	window.session_created.connect(_on_new_session_created.bind(key))
	window.open_new(_token(), "https://github.com/" + slug, ref)


func _on_new_session_created(session_id: String, key: String) -> void:
	var window: Window = _chat_windows.get(key) as Window
	if window != null and is_instance_valid(window):
		_chat_windows.erase(key)
		_chat_windows[session_id] = window
		if not window.tree_exited.is_connected(_forget_chat.bind(session_id, window)):
			window.tree_exited.connect(_forget_chat.bind(session_id, window))
	_refresh_from_start()


func _forget_chat(session_id: String, window: Window) -> void:
	if _chat_windows.get(session_id) == window:
		_chat_windows.erase(session_id)


func _checkout_master() -> void:
	_checkout_branch_prompt("master")


func _checkout_branch_prompt(branch: String) -> void:
	if branch.is_empty():
		push_warning("看板：这个会话没有远程分支。")
		return
	var dialog := ConfirmationDialog.new()
	dialog.title = "切换分支"
	dialog.dialog_text = "放弃所有修改并切换到 %s？" % branch
	dialog.ok_button_text = "是"
	dialog.cancel_button_text = "否"
	dialog.confirmed.connect(_do_checkout.bind(branch))
	dialog.confirmed.connect(dialog.queue_free)
	dialog.canceled.connect(dialog.queue_free)
	EditorInterface.get_base_control().add_child(dialog)
	dialog.popup_centered()


func _do_checkout(branch: String) -> void:
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


static func _current_branch(path: String) -> String:
	var output: Array = []
	var code := OS.execute("git", ["-C", path, "rev-parse", "--abbrev-ref", "HEAD"], output, true)
	if code != 0 or output.is_empty():
		return ""
	var branch := str(output[0]).strip_edges()
	if branch.is_empty() or branch == "HEAD":
		return ""
	return branch


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
