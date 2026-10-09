@tool
extends Window

const _BUBBLE := preload("res://addons/godot_github_cursor_kanban/chat_bubble.tscn")
const _Client := preload("res://addons/godot_github_cursor_kanban/cursor_client.gd")

var session_id := ""
var _token := ""
var _busy := false


func _ready() -> void:
	close_requested.connect(queue_free)
	%Input.text_submitted.connect(func(_text: String) -> void:
		_send()
	)
	$VBoxContainer/VBoxContainer/Button.pressed.connect(_send)


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
	WorkerThreadPool.add_task(func() -> void:
		var ok := _Client.send_message(token, agent_id, text)
		if is_instance_valid(self):
			call_deferred("_on_sent", ok)
	)


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
		bubble.layout_direction = Control.LAYOUT_DIRECTION_RTL if from_user else Control.LAYOUT_DIRECTION_LTR
		bubble.get_node("%Time").text = "你" if from_user else "助手"
		bubble.get_node("%Content").text = str(message.get("text", ""))
		list.add_child(bubble)
