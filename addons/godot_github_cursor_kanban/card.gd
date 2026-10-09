@tool
extends PanelContainer

signal chat_requested(session_id: String, title: String)
signal detail_settled(kept: bool)

const _Client := preload("res://addons/godot_github_cursor_kanban/cursor_client.gd")

var _dot_working: Texture2D
var _dot_idle: Texture2D
var _url := ""


func apply(session: Dictionary) -> void:
	%CardName.text = str(session.get("name", ""))
	var working := bool(session.get("working", false))
	%SessionStatus.texture = _working_texture() if working else _idle_texture()
	%SessionStatus.tooltip_text = "工作中" if working else "空闲"
	%SessionStatus.custom_minimum_size = Vector2(12, 12)
	%SessionStatus.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_url = str(session.get("url", _url))
	%Chat.set_meta("session_id", str(session.get("id", "")))
	%Chat.set_meta("title", str(session.get("name", "")))
	if not %Chat.pressed.is_connected(_on_chat_pressed):
		%Chat.pressed.connect(_on_chat_pressed)


func begin_detail(token: String, repo_slug: String) -> void:
	var agent_id := str(%Chat.get_meta("session_id", ""))
	if token.is_empty() or agent_id.is_empty():
		detail_settled.emit(true)
		return
	var cached := _Client.cached_repo_match(agent_id, repo_slug)
	if cached == 1:
		detail_settled.emit(true)
		return
	if cached == 0:
		detail_settled.emit(false)
		queue_free()
		return
	WorkerThreadPool.add_task(func() -> void:
		var detail := _Client.request(
			token,
			HTTPClient.METHOD_GET,
			"/v1/agents/%s" % agent_id.uri_encode()
		)
		_Client.remember_repos(agent_id, detail)
		var patch := _Client.detail_patch(detail, repo_slug)
		if is_instance_valid(self):
			call_deferred("_finish_detail", patch)
	)


func _finish_detail(patch: Dictionary) -> void:
	if not is_inside_tree():
		return
	if bool(patch.get("_error", false)):
		detail_settled.emit(true)
		return
	if patch.is_empty():
		detail_settled.emit(false)
		queue_free()
		return
	apply({
		"id": str(%Chat.get_meta("session_id", "")),
		"name": str(patch.get("name", %CardName.text)),
		"url": str(patch.get("url", _url)),
		"working": bool(patch.get("working", false)),
	})
	detail_settled.emit(true)


func _on_chat_pressed() -> void:
	chat_requested.emit(str(%Chat.get_meta("session_id", "")), str(%Chat.get_meta("title", "")))


func _working_texture() -> Texture2D:
	if _dot_working == null:
		_dot_working = _make_dot(Color(0.2, 0.75, 0.35))
	return _dot_working


func _idle_texture() -> Texture2D:
	if _dot_idle == null:
		_dot_idle = _make_dot(Color(0.55, 0.55, 0.55))
	return _dot_idle


func _make_dot(color: Color) -> Texture2D:
	var image := Image.create(12, 12, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	for y in 12:
		for x in 12:
			if Vector2(x - 5.5, y - 5.5).length() <= 5.0:
				image.set_pixel(x, y, color)
	return ImageTexture.create_from_image(image)
