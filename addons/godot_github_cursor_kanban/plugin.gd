@tool
extends EditorPlugin

const _DOCK_SCENE := preload("res://addons/godot_github_cursor_kanban/dock.tscn")
const _CARD_SCENE := preload("res://addons/godot_github_cursor_kanban/card.tscn")
const _CHAT_WINDOW := preload("res://addons/godot_github_cursor_kanban/chat_window.tscn")
const _Board := preload("res://addons/godot_github_cursor_kanban/board.gd")
const _GEAR_PATH := "res://addons/godot_github_cursor_kanban/icons/gear.png"
const _MAIN_BRANCH_ICON := "res://addons/godot_github_cursor_kanban/icons/main_branch.png"
const _REFRESH_PATH := "res://addons/godot_github_cursor_kanban/icons/refresh.png"
const _SECTION := "kanban"
const _TRANSLATION_CSV := "res://addons/godot_github_cursor_kanban/translations/kanban.csv"
# 英文蛇形键，显示名交给属性翻译域（中文默认，英文编辑器语言下为英文）。
const _SETTING_RESTART := "kanban/restart_editor_after_branch_switch"
const _SETTING_RESTART_LEGACY := "kanban/切换分支后自动重启编辑器"
const _SETTING_TOKEN := "kanban/cursor_token"
const _PROPERTY_DOMAIN := "godot.properties"

var _dock: EditorDock
var _translations: Array[Translation] = []
var _card_list: VBoxContainer
var _refresh_button: Button
var _refreshing := false
var _chat_windows := {}
var _thread: Thread
var _job: Dictionary = {}
const _RUN_CONCURRENCY := 16

var _agents_http: HTTPRequest
var _run_pool: Array[HTTPRequest] = []
var _run_busy: Dictionary = {}
var _fetch_gen := 0
var _fetch_token := ""
var _fetch_slug := ""
var _fetch_prs: Array[Dictionary] = []
var _fetch_merged: Array[Dictionary] = []
var _fetch_sessions: Array[Dictionary] = []
var _fetch_agents: Array[Dictionary] = []
var _fetch_runs: Array[Dictionary] = []
var _fetch_cursor := ""
var _fetch_page := 0
var _run_gen: Dictionary = {}
var _agent_cache: Dictionary = {}
var _prs_done := false
var _agents_done := false


func _enter_tree() -> void:
	_install_translations()
	_register_editor_settings()

	var content := _DOCK_SCENE.instantiate() as Control
	content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var toolbar := HBoxContainer.new()
	toolbar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(toolbar)
	content.move_child(toolbar, 0)
	var settings_button := content.get_node("Settings") as Button
	content.remove_child(settings_button)
	settings_button.owner = null
	settings_button.icon = _settings_button_icon()
	settings_button.tooltip_text = tr("看板设置")
	settings_button.pressed.connect(_open_kanban_editor_settings)
	_refresh_button = Button.new()
	_refresh_button.icon = _refresh_button_icon()
	_refresh_button.tooltip_text = tr("刷新")
	_refresh_button.pressed.connect(_refresh_cards)
	toolbar.add_child(_refresh_button)
	var main_button := Button.new()
	main_button.icon = _load_png_texture(_MAIN_BRANCH_ICON)
	main_button.tooltip_text = tr("切回主分支")
	main_button.pressed.connect(_confirm_reset_to_main)
	toolbar.add_child(main_button)
	toolbar.add_child(settings_button)
	_card_list = content.get_node("ScrollContainer/VBoxContainer") as VBoxContainer
	_agents_http = _make_http(_on_agents_http, false)
	for _i in _RUN_CONCURRENCY:
		_run_pool.append(_make_http(_on_run_http, true))

	_dock = EditorDock.new()
	_dock.title = tr("看板")
	# 独立 layout_key，不沿用上次停在错误槽位的布局记录。
	_dock.layout_key = "godot_github_cursor_kanban"
	_dock.default_slot = EditorDock.DOCK_SLOT_LEFT_BR
	_dock.add_child(content)
	_dock.add_child(_agents_http)
	for http in _run_pool:
		_dock.add_child(http)
	add_dock(_dock)
	# 启动时只排队，不在主线程上拉会话和 PR。
	call_deferred("_refresh_cards")


func _refresh_cards() -> void:
	if _card_list == null or _refreshing:
		return
	_refreshing = true
	if is_instance_valid(_refresh_button):
		_refresh_button.disabled = true
		_refresh_button.tooltip_text = tr("刷新中")
	var settings := EditorInterface.get_editor_settings()
	var token := ""
	if settings.has_setting(_SETTING_TOKEN):
		token = str(settings.get_setting(_SETTING_TOKEN))
	_fetch_gen += 1
	_cancel_work()
	_join_thread()
	_prs_done = false
	_agents_done = false
	_job = {"cancel": false, "pids": [], "mutex": Mutex.new()}
	_fetch_slug = _Board.origin_slug(_Board.project_path())
	_agent_cache = _Board.load_agent_cache()
	_fetch_prs = _dict_array(_agent_cache.get("open_prs", []))
	_fetch_merged = _dict_array(_agent_cache.get("merged_prs", []))
	_fetch_sessions = []
	_fetch_agents = []
	_fetch_runs = []
	_fetch_cursor = ""
	_fetch_page = 0
	_fetch_token = token
	_paint_cards()
	_thread = Thread.new()
	var err := _thread.start(_load_prs_off_thread.bind(_Board.project_path(), _job, _fetch_gen))
	if err != OK:
		_prs_done = true
		push_warning("看板：刷新线程启动失败。")
	if token.is_empty():
		push_warning("看板：未配置 Cursor token，只列出 PR。")
		_agents_done = true
	else:
		_request_agents_page()
	_maybe_idle()


func _load_prs_off_thread(root: String, job: Dictionary, gen: int) -> void:
	var slug := _Board.origin_slug(root, job)
	var bundle: Dictionary = _Board.list_board_prs(slug, job)
	if is_instance_valid(self):
		call_deferred("_continue_prs", slug, bundle.get("open", []), bundle.get("merged", []), gen)


func _continue_prs(slug: String, prs: Array, merged: Array, gen: int) -> void:
	if gen != _fetch_gen or not is_inside_tree():
		return
	_join_thread()
	if not slug.is_empty():
		_fetch_slug = slug
	_fetch_prs = _dict_array(prs)
	_fetch_merged = _dict_array(merged)
	_agent_cache["open_prs"] = _fetch_prs
	_agent_cache["merged_prs"] = _fetch_merged
	_prs_done = true
	_paint_cards()
	_maybe_idle()


func _request_agents_page() -> void:
	var err := _agents_http.request(_Board.api_url(_Board.agents_path(_fetch_cursor)), _Board.api_headers(_fetch_token))
	if err != OK:
		push_warning("看板：请求 Cursor API 失败。")
		_finish_cards()


func _on_agents_http(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if not _refreshing or not is_inside_tree():
		return
	if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
		_warn_http(result, response_code)
		_finish_cards()
		return
	_consume_agents_page(_Board.parse_object(body))


func _pump_details() -> void:
	if not _refreshing:
		return
	for http in _run_pool:
		var id := http.get_instance_id()
		if _run_busy.has(id):
			continue
		var kind := ""
		var item := {}
		var run_id := ""
		if not _fetch_agents.is_empty():
			item = _fetch_agents.pop_front()
			kind = "agent"
		elif not _fetch_runs.is_empty():
			var entry: Dictionary = _fetch_runs.pop_front()
			item = entry.get("item", {})
			run_id = str(entry.get("run_id", ""))
			kind = "run"
		else:
			break
		var path := "/v1/agents/%s" % str(item.get("id", "")).uri_encode()
		if kind == "run":
			path = "/v1/agents/%s/runs/%s" % [str(item.get("id", "")), run_id]
		_run_busy[id] = {"item": item, "kind": kind, "run_id": run_id}
		_run_gen[id] = _fetch_gen
		if http.request(_Board.api_url(path), _Board.api_headers(_fetch_token)) != OK:
			_run_busy.erase(id)
			push_warning("看板：请求 Cursor API 失败。")
	if _run_busy.is_empty() and _fetch_agents.is_empty() and _fetch_runs.is_empty():
		_finish_cards()


func _on_run_http(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray, http: HTTPRequest) -> void:
	var id := http.get_instance_id()
	var job: Dictionary = _run_busy.get(id, {})
	var item: Dictionary = job.get("item", {})
	var gen := int(_run_gen.get(id, -1))
	_run_busy.erase(id)
	if gen != _fetch_gen or not _refreshing or not is_inside_tree():
		return
	if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
		_warn_http(result, response_code)
		if str(job.get("kind", "")) == "run":
			_keep_session(item, {})
	elif str(job.get("kind", "")) == "agent":
		_on_agent_body(item, _Board.parse_object(body))
	else:
		_keep_session(item, _Board.parse_object(body))
	_pump_details()


func _on_agent_body(list_item: Dictionary, agent: Dictionary) -> void:
	var merged := list_item.duplicate()
	merged["repos"] = agent.get("repos", [])
	var repo := str(_Board.agent_repo_key(merged))
	var run_id := str(list_item.get("latestRunId", ""))
	if repo.is_empty() or not _Board._same_repo(repo, _fetch_slug):
		if not repo.is_empty():
			_remember_agent(list_item, repo, "", "")
		return
	if run_id.is_empty():
		_keep_session(merged, {})
		return
	_fetch_runs.append({"item": merged, "run_id": run_id})


func _keep_session(item: Dictionary, run: Dictionary) -> void:
	var session := _Board.session_from_agent(item, run, _fetch_slug)
	if session.is_empty():
		return
	_fetch_sessions.append(session)
	_remember_agent(item, _Board.agent_repo_key(item), str(session.get("branch", "")), str(session.get("pr_url", "")))


func _remember_agent(item: Dictionary, repo: String, branch: String, pr_url: String) -> void:
	var agent_id := str(item.get("id", ""))
	if agent_id.is_empty() or repo.is_empty():
		return
	_agents()[agent_id] = {
		"run_id": str(item.get("latestRunId", "")),
		"updated_at": str(item.get("updatedAt", "")),
		"repo": repo,
		"branch": branch,
		"pr_url": pr_url,
		"name": str(item.get("name", "")),
		"url": str(item.get("url", "")),
		"status": str(item.get("status", "")),
	}


func _make_http(callback: Callable, bind_self: bool) -> HTTPRequest:
	var http := HTTPRequest.new()
	http.timeout = 8.0
	if bind_self:
		http.request_completed.connect(callback.bind(http))
	else:
		http.request_completed.connect(callback)
	return http


func _warn_http(result: int, response_code: int) -> void:
	if result != HTTPRequest.RESULT_SUCCESS:
		push_warning("看板：连接 Cursor API 失败。")
	else:
		push_warning("看板：Cursor API 返回 %d。" % response_code)


func _consume_agents_page(payload: Dictionary) -> void:
	var items: Variant = payload.get("items", [])
	if typeof(items) != TYPE_ARRAY:
		_finish_cards()
		return
	var page_stable := true
	for item in items:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		if _reuse_cached(item):
			continue
		page_stable = false
		_fetch_agents.append(item)
	_fetch_page += 1
	_fetch_cursor = str(payload.get("nextCursor", ""))
	# 整页都命中缓存时，更旧的页也不会变，不再继续翻。
	if _fetch_cursor.is_empty() or _fetch_page >= 1 or (page_stable and not items.is_empty()):
		_pump_details()
	else:
		_request_agents_page()


func _reuse_cached(item: Dictionary) -> bool:
	var cached: Dictionary = _agents().get(str(item.get("id", "")), {})
	if cached.is_empty():
		return false
	if str(cached.get("run_id", "")) != str(item.get("latestRunId", "")):
		return false
	if str(cached.get("repo", "")).is_empty():
		return false
	var session := _Board.session_from_cache(item, cached, _fetch_slug)
	if not session.is_empty():
		_fetch_sessions.append(session)
	return true


func _finish_cards() -> void:
	_agents_done = true
	_paint_cards()
	_maybe_idle()


func _paint_cards() -> void:
	if not is_inside_tree():
		return
	var sessions := _sessions_for_board()
	_apply_cards(_Board.merge_cards(sessions, _fetch_prs, _fetch_merged))
	_refreshing = not (_prs_done and _agents_done)
	if _refreshing:
		if is_instance_valid(_refresh_button):
			_refresh_button.disabled = true
			_refresh_button.tooltip_text = tr("刷新中")
	else:
		_set_refresh_idle()


func _maybe_idle() -> void:
	if not _prs_done or not _agents_done:
		return
	if is_inside_tree():
		_Board.save_agent_cache(_agent_cache)
	_refreshing = false
	_set_refresh_idle()


func _sessions_for_board() -> Array[Dictionary]:
	var sessions: Array[Dictionary] = []
	var seen := {}
	for session in _fetch_sessions:
		var sid := str(session.get("id", ""))
		seen[sid] = true
		sessions.append(session)
	for agent_id in _agents().keys():
		if seen.has(str(agent_id)):
			continue
		var cached: Dictionary = _agents()[agent_id]
		var item := {
			"id": str(agent_id),
			"name": str(cached.get("name", "")),
			"url": str(cached.get("url", "")),
			"status": str(cached.get("status", "")),
		}
		var session := _Board.session_from_cache(item, cached, _fetch_slug)
		if not session.is_empty():
			sessions.append(session)
	return sessions


func _agents() -> Dictionary:
	if typeof(_agent_cache.get("agents", {})) != TYPE_DICTIONARY:
		_agent_cache["agents"] = {}
	return _agent_cache["agents"]


func _dict_array(items: Array) -> Array[Dictionary]:
	var typed: Array[Dictionary] = []
	for item in items:
		if typeof(item) == TYPE_DICTIONARY:
			typed.append(item)
	return typed


func _cancel_work() -> void:
	if not _job.is_empty() and _job.get("mutex") is Mutex:
		var mutex: Mutex = _job["mutex"]
		mutex.lock()
		_job["cancel"] = true
		var pids: Array = (_job["pids"] as Array).duplicate()
		mutex.unlock()
		for pid in pids:
			if OS.is_process_running(int(pid)):
				OS.kill(int(pid))
	if _agents_http:
		_agents_http.cancel_request()
	for http in _run_pool:
		http.cancel_request()
	_run_busy.clear()


func _join_thread() -> void:
	if _thread != null and _thread.is_started():
		_thread.wait_to_finish()
	_thread = null


func _set_refresh_idle() -> void:
	if is_instance_valid(_refresh_button):
		_refresh_button.disabled = false
		_refresh_button.tooltip_text = tr("刷新")


func _apply_cards(cards: Array) -> void:
	if _card_list == null or not is_inside_tree():
		return
	for child in _card_list.get_children():
		_card_list.remove_child(child)
		child.free()
	for card_data in cards:
		var card := _CARD_SCENE.instantiate()
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.apply(card_data)
		card.checkout_requested.connect(_on_checkout_requested)
		card.chat_requested.connect(_on_chat_requested)
		_card_list.add_child(card)


func _confirm_reset_to_main() -> void:
	var dialog := ConfirmationDialog.new()
	dialog.title = tr("切回主分支")
	dialog.dialog_text = tr("用最新远程主分支覆盖本地并切换过去？未提交的改动会丢失。")
	dialog.ok_button_text = tr("是")
	dialog.cancel_button_text = tr("否")
	dialog.confirmed.connect(_reset_to_main)
	dialog.confirmed.connect(dialog.queue_free)
	dialog.canceled.connect(dialog.queue_free)
	EditorInterface.get_base_control().add_child(dialog)
	dialog.popup_centered()


func _reset_to_main() -> void:
	if not _Board.reset_to_remote_default(_Board.project_path()):
		return
	_restart_after_branch_switch()


func _on_chat_requested(session_id: String, title: String) -> void:
	if session_id.is_empty():
		return
	var window: Window = _chat_windows.get(session_id) as Window
	if window == null or not is_instance_valid(window):
		window = _CHAT_WINDOW.instantiate()
		EditorInterface.get_base_control().add_child(window)
		_chat_windows[session_id] = window
		window.tree_exited.connect(func() -> void:
			if _chat_windows.get(session_id) == window:
				_chat_windows.erase(session_id)
		)
	var settings := EditorInterface.get_editor_settings()
	var token := ""
	if settings.has_setting(_SETTING_TOKEN):
		token = str(settings.get_setting(_SETTING_TOKEN))
	window.open_session(token, session_id, title)


func _on_checkout_requested(branch: String) -> void:
	if branch.is_empty():
		return
	var dialog := ConfirmationDialog.new()
	dialog.title = tr("切换分支")
	dialog.dialog_text = tr("放弃所有修改并切换到 %s？") % branch
	dialog.ok_button_text = tr("是")
	dialog.cancel_button_text = tr("否")
	dialog.confirmed.connect(_checkout_and_restart.bind(branch))
	dialog.confirmed.connect(dialog.queue_free)
	dialog.canceled.connect(dialog.queue_free)
	EditorInterface.get_base_control().add_child(dialog)
	dialog.popup_centered()


func _checkout_and_restart(branch: String) -> void:
	if not _Board.checkout_branch(_Board.project_path(), branch):
		return
	_restart_after_branch_switch()


func _restart_after_branch_switch() -> void:
	var settings := EditorInterface.get_editor_settings()
	var restart := true
	if settings.has_setting(_SETTING_RESTART):
		restart = bool(settings.get_setting(_SETTING_RESTART))
	elif settings.has_setting(_SETTING_RESTART_LEGACY):
		restart = bool(settings.get_setting(_SETTING_RESTART_LEGACY))
	if restart and EditorInterface.has_method("restart_editor"):
		EditorInterface.call("restart_editor", true)


func _exit_tree() -> void:
	_fetch_gen += 1
	_refreshing = false
	_cancel_work()
	_join_thread()
	_uninstall_translations()
	for session_id in _chat_windows.keys():
		var window: Window = _chat_windows[session_id] as Window
		if is_instance_valid(window):
			window.queue_free()
	_chat_windows.clear()
	if _dock:
		remove_dock(_dock)
		_dock.free()
		_dock = null


func _install_translations() -> void:
	_uninstall_translations()
	var rows := _read_translation_rows()
	if rows.is_empty():
		return
	# 主域给 tr()，属性域给编辑器设置分区和设置项标题。
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
		push_warning("看板：读不到翻译表。")
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


func _register_editor_settings() -> void:
	var settings := EditorInterface.get_editor_settings()
	_migrate_restart_setting(settings)
	_ensure_setting(settings, _SETTING_RESTART, true, TYPE_BOOL, PROPERTY_HINT_NONE)
	_ensure_setting(settings, _SETTING_TOKEN, "", TYPE_STRING, PROPERTY_HINT_PASSWORD)


func _migrate_restart_setting(settings: EditorSettings) -> void:
	if not settings.has_setting(_SETTING_RESTART_LEGACY):
		return
	if not settings.has_setting(_SETTING_RESTART):
		settings.set_setting(_SETTING_RESTART, settings.get_setting(_SETTING_RESTART_LEGACY))
	settings.erase(_SETTING_RESTART_LEGACY)


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


func _refresh_button_icon() -> Texture2D:
	var base := EditorInterface.get_base_control()
	if base:
		for icon_name in ["Reload", "Loop", "RotateRight"]:
			if base.has_theme_icon(icon_name, "EditorIcons"):
				return base.get_theme_icon(icon_name, "EditorIcons")
	return _load_png_texture(_REFRESH_PATH)


func _settings_button_icon() -> Texture2D:
	var base := EditorInterface.get_base_control()
	if base:
		# 4.7 的 EditorIcons 没有齿轮；若以后版本加了，优先用主题图标。
		for icon_name in ["Gear", "Settings", "Cog"]:
			if base.has_theme_icon(icon_name, "EditorIcons"):
				return base.get_theme_icon(icon_name, "EditorIcons")
	return _load_gear_texture()


func _load_gear_texture() -> Texture2D:
	return _load_png_texture(_GEAR_PATH)


func _load_png_texture(path: String) -> Texture2D:
	var file := FileAccess.open(path, FileAccess.READ)
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
		push_warning(tr("看板：打不开编辑器设置。"))
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
