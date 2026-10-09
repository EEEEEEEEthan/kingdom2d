@tool
extends Window

const _BUBBLE := preload("res://addons/godot_github_cursor_kanban/chat_bubble.tscn")
const _Board := preload("res://addons/godot_github_cursor_kanban/board.gd")

var session_id := ""
var _token := ""
var _http: HTTPRequest


func _ready() -> void:
	close_requested.connect(_close)
	%Refresh.pressed.connect(refresh)
	_http = HTTPRequest.new()
	_http.timeout = 8.0
	add_child(_http)
	_http.request_completed.connect(_on_messages)


func _close() -> void:
	if _http:
		_http.cancel_request()
	queue_free()


func _exit_tree() -> void:
	if _http:
		_http.cancel_request()


func open_session(token: String, id: String, title: String) -> void:
	_token = token
	session_id = id
	self.title = title if not title.is_empty() else "对话"
	refresh()
	if not visible:
		popup_centered(Vector2i(480, 640))
	else:
		grab_focus()


func refresh() -> void:
	if _token.is_empty() or session_id.is_empty():
		push_warning("看板：没有可刷新的对话。")
		return
	_http.cancel_request()
	var path := "/v0/agents/%s/conversation" % session_id.uri_encode()
	if _http.request(_Board.api_url(path), _Board.api_headers(_token)) != OK:
		push_warning("看板：请求 Cursor API 失败。")


func _on_messages(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	var list := %ChatPanel.get_node("VBoxContainer") as VBoxContainer
	for child in list.get_children():
		list.remove_child(child)
		child.free()
	if result != HTTPRequest.RESULT_SUCCESS:
		push_warning("看板：连接 Cursor API 失败。")
		return
	if response_code != 200:
		push_warning("看板：Cursor API 返回 %d。" % response_code)
		return
	for message in _Board.messages_from_payload(_Board.parse_object(body)):
		var bubble := _BUBBLE.instantiate()
		var from_user := str(message.get("type", "")).contains("user")
		bubble.layout_direction = Control.LAYOUT_DIRECTION_RTL if from_user else Control.LAYOUT_DIRECTION_LTR
		bubble.get_node("Time").text = "你" if from_user else "助手"
		bubble.get_node("%Content").text = str(message.get("text", ""))
		list.add_child(bubble)
