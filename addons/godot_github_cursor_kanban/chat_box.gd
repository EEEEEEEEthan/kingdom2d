@tool
extends Window

signal session_created(session_id: String)

const _BUBBLE := preload("res://addons/godot_github_cursor_kanban/chat_bubble.tscn")
const _Client := preload("res://addons/godot_github_cursor_kanban/cursor_client.gd")
const _USER_COLOR := Color(0.75, 0.95, 0.72)
const _TIME_CACHE_PATH := "user://kanban_message_times.json"

var session_id := ""
var _token := ""
var _repository := ""
var _ref := ""
var _busy := false


func _ready() -> void:
	close_requested.connect(queue_free)
	%Input.text_submitted.connect(func(_text: String) -> void:
		_send()
	)
	$VBoxContainer/VBoxContainer/Button.pressed.connect(_send)


func open_new(token: String, repository: String, ref: String) -> void:
	_token = token
	session_id = ""
	_repository = repository
	_ref = ref
	self.title = "新对话"
	if not visible:
		popup_centered(Vector2i(600, 800))
	else:
		grab_focus()
	%Input.grab_focus()


func open_session(token: String, id: String, title: String) -> void:
	_token = token
	session_id = id
	self.title = title if not title.is_empty() else "对话"
	refresh()
	if not visible:
		popup_centered(Vector2i(600, 800))
	else:
		grab_focus()


func refresh() -> void:
	var messages := _Client.list_messages(_token, session_id)
	if is_instance_valid(self):
		_show_messages(messages)


func _send() -> void:
	var text: String = (%Input as LineEdit).text.strip_edges()
	if text.is_empty() or _busy:
		return
	_busy = true
	$VBoxContainer/VBoxContainer/Button.disabled = true
	%Input.editable = false
	var token := _token
	var agent_id := session_id
	var repository := _repository
	var ref := _ref
	WorkerThreadPool.add_task(func() -> void:
		if agent_id.is_empty():
			var created := _Client.create_agent(token, text, repository, ref)
			if is_instance_valid(self):
				call_deferred("_on_created", created)
			return
		var ok := _Client.send_message(token, agent_id, text)
		if is_instance_valid(self):
			call_deferred("_on_sent", ok)
	)


func _on_created(created: Dictionary) -> void:
	_busy = false
	$VBoxContainer/VBoxContainer/Button.disabled = false
	%Input.editable = true
	var agent_id := str(created.get("id", ""))
	if agent_id.is_empty():
		push_warning("看板：新建会话失败。")
		return
	session_id = agent_id
	var name := str(created.get("name", ""))
	self.title = name if not name.is_empty() else "新对话"
	%Input.text = ""
	session_created.emit(session_id)
	refresh()


func _on_sent(ok: bool) -> void:
	_busy = false
	$VBoxContainer/VBoxContainer/Button.disabled = false
	%Input.editable = true
	if not ok:
		push_warning("看板：发送失败。")
		return
	%Input.text = ""
	refresh()


func _show_messages(messages: Array) -> void:
	var list := $VBoxContainer/ScrollContainer/VBoxContainer as VBoxContainer
	for child in list.get_children():
		list.remove_child(child)
		child.free()
	for message in messages:
		var bubble := _BUBBLE.instantiate()
		var from_user := str(message.get("type", "")).contains("user")
		var stamp := str(message.get("time", ""))
		if stamp.is_empty():
			stamp = _remembered_time(message, list.get_child_count())
		var time_label := bubble.get_node("%Time") as Label
		time_label.text = stamp
		time_label.add_theme_color_override("font_color", _USER_COLOR if from_user else Color.WHITE)
		var content := bubble.get_node("%Content") as RichTextLabel
		content.text = str(message.get("text", ""))
		if from_user:
			content.add_theme_color_override("default_color", _USER_COLOR)
		list.add_child(bubble)


func _remembered_time(message: Dictionary, index: int) -> String:
	var key := "%s|%d|%s|%s" % [
		session_id,
		index,
		str(message.get("type", "")),
		str(message.get("text", "")).md5_text(),
	]
	var cache := _read_time_cache()
	if cache.has(key):
		return str(cache[key])
	var stamp := _Client.format_now()
	cache[key] = stamp
	var file := FileAccess.open(_TIME_CACHE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(cache))
	return stamp


func _read_time_cache() -> Dictionary:
	if not FileAccess.file_exists(_TIME_CACHE_PATH):
		return {}
	var file := FileAccess.open(_TIME_CACHE_PATH, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	return parsed if typeof(parsed) == TYPE_DICTIONARY else {}
