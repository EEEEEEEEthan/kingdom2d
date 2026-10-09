@tool
extends PanelContainer

signal chat_requested(session_id: String, title: String)
signal checkout_requested(branch: String)
signal detail_settled(kept: bool)
signal session_updated

const _Client := preload("res://addons/godot_github_cursor_kanban/cursor_client.gd")

var _dot_working: Texture2D
var _dot_idle: Texture2D
var _url := ""
var _checking := false


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
	var branch := str(session.get("branch", ""))
	var pr_url := str(session.get("pr_url", ""))
	%Checkout.visible = not pr_url.is_empty()
	%Checkout.set_meta("branch", branch)
	var stored: Variant = get_meta("session", {})
	if typeof(stored) == TYPE_DICTIONARY:
		var copy := (stored as Dictionary).duplicate()
		copy["name"] = %CardName.text
		copy["url"] = _url
		copy["working"] = working
		copy["branch"] = branch
		copy["pr_url"] = pr_url
		set_meta("session", copy)
	if not %Chat.pressed.is_connected(_on_chat_pressed):
		%Chat.pressed.connect(_on_chat_pressed)
	if not %Checkout.pressed.is_connected(_on_checkout_pressed):
		%Checkout.pressed.connect(_on_checkout_pressed)


func begin_self_check(token: String, repo_slug: String, repo_path: String) -> void:
	if _checking:
		return
	var agent_id := str(%Chat.get_meta("session_id", ""))
	if token.is_empty() or agent_id.is_empty():
		detail_settled.emit(true)
		return
	_checking = true
	var branch := str(%Checkout.get_meta("branch", ""))
	WorkerThreadPool.add_task(func() -> void:
		var detail := _Client.request(
			token,
			HTTPClient.METHOD_GET,
			"/v1/agents/%s" % agent_id.uri_encode()
		)
		_Client.remember_repos(agent_id, detail)
		var patch := _Client.detail_patch(detail, repo_slug)
		if not bool(patch.get("_error", false)) and not patch.is_empty():
			if _drop_merged(agent_id, repo_path, str(patch.get("branch", branch))):
				patch = {}
		if is_instance_valid(self):
			call_deferred("_finish_self_check", patch)
	)


func _drop_merged(agent_id: String, repo_path: String, branch: String) -> bool:
	var head := branch.strip_edges()
	if head.is_empty():
		head = _Client.cached_branch(agent_id)
	if head.is_empty() or head == "master":
		_Client.remember_merged(agent_id, false)
		return false
	if OS.execute("git", ["-C", repo_path, "fetch", "origin", head, "master"], [], true) != 0:
		return false
	var merged := _Client.branch_merged(repo_path, head)
	if merged == 1:
		_Client.remember_merged(agent_id, true)
		return true
	if merged == 0:
		_Client.remember_merged(agent_id, false)
	return false


func _finish_self_check(patch: Dictionary) -> void:
	_checking = false
	if not is_inside_tree():
		return
	if bool(patch.get("_error", false)):
		detail_settled.emit(true)
		return
	if patch.is_empty():
		detail_settled.emit(false)
		queue_free()
		return
	var branch := str(patch.get("branch", ""))
	if branch.is_empty():
		branch = str(%Checkout.get_meta("branch", ""))
	var pr_url := str(patch.get("pr_url", ""))
	if pr_url.is_empty():
		var stored: Variant = get_meta("session", {})
		if typeof(stored) == TYPE_DICTIONARY:
			pr_url = str(stored.get("pr_url", ""))
	apply({
		"id": str(%Chat.get_meta("session_id", "")),
		"name": str(patch.get("name", %CardName.text)),
		"url": str(patch.get("url", _url)),
		"working": bool(patch.get("working", false)),
		"branch": branch,
		"pr_url": pr_url,
	})
	visible = true
	session_updated.emit()
	detail_settled.emit(true)


func _on_chat_pressed() -> void:
	chat_requested.emit(str(%Chat.get_meta("session_id", "")), str(%Chat.get_meta("title", "")))


func _on_checkout_pressed() -> void:
	checkout_requested.emit(str(%Checkout.get_meta("branch", "")))


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
