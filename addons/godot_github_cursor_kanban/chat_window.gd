@tool
extends Window

const _BUBBLE := preload("res://addons/godot_github_cursor_kanban/chat_bubble.tscn")
const _Board := preload("res://addons/godot_github_cursor_kanban/board.gd")

var session_id := ""
var _token := ""


func _ready() -> void:
	close_requested.connect(queue_free)
	%Refresh.pressed.connect(refresh)


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
	var list := %ChatPanel.get_node("VBoxContainer") as VBoxContainer
	for child in list.get_children():
		list.remove_child(child)
		child.free()
	for message in _Board.list_messages(_token, session_id):
		var bubble := _BUBBLE.instantiate()
		var from_user := str(message.get("type", "")).contains("user")
		bubble.layout_direction = Control.LAYOUT_DIRECTION_RTL if from_user else Control.LAYOUT_DIRECTION_LTR
		bubble.get_node("Time").text = "你" if from_user else "助手"
		bubble.get_node("%Content").text = str(message.get("text", ""))
		list.add_child(bubble)
