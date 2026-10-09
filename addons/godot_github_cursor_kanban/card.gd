@tool
extends PanelContainer

signal chat_requested(session_id: String, title: String)
signal checkout_requested(branch: String)
signal detail_settled(kept: bool)

const _Client := preload("res://addons/godot_github_cursor_kanban/cursor_client.gd")

const _SPINNER_SIZE := 14
const _SPIN_TURNS_PER_SEC := 1.1

var _spinner: Texture2D
var _spinning := false
var _url := ""


func apply(session: Dictionary) -> void:
	%CardName.text = str(session.get("name", ""))
	_set_working(bool(session.get("working", false)))
	_url = str(session.get("url", _url))
	%Chat.set_meta("session_id", str(session.get("id", "")))
	%Chat.set_meta("title", str(session.get("name", "")))
	var branch := str(session.get("branch", ""))
	var pr_url := str(session.get("pr_url", ""))
	%Checkout.visible = not pr_url.is_empty()
	%Checkout.set_meta("branch", branch)
	if not %Chat.pressed.is_connected(_on_chat_pressed):
		%Chat.pressed.connect(_on_chat_pressed)
	if not %Checkout.pressed.is_connected(_on_checkout_pressed):
		%Checkout.pressed.connect(_on_checkout_pressed)


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
		"branch": str(patch.get("branch", %Checkout.get_meta("branch", ""))),
		"pr_url": str(patch.get("pr_url", "")),
	})
	detail_settled.emit(true)


func _on_chat_pressed() -> void:
	chat_requested.emit(str(%Chat.get_meta("session_id", "")), str(%Chat.get_meta("title", "")))


func _on_checkout_pressed() -> void:
	checkout_requested.emit(str(%Checkout.get_meta("branch", "")))


func _enter_tree() -> void:
	set_process(_spinning)


func _process(delta: float) -> void:
	var status := %SessionStatus
	status.pivot_offset = status.size * 0.5
	status.rotation = fposmod(status.rotation + delta * TAU * _SPIN_TURNS_PER_SEC, TAU)


func _set_working(working: bool) -> void:
	_spinning = working
	var status := %SessionStatus
	status.visible = working
	status.tooltip_text = "工作中" if working else ""
	status.mouse_filter = Control.MOUSE_FILTER_IGNORE
	status.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	status.custom_minimum_size = Vector2(_SPINNER_SIZE, _SPINNER_SIZE)
	status.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	if working:
		status.texture = _spinner_texture()
	else:
		status.rotation = 0.0
	set_process(working and is_inside_tree())


func _spinner_texture() -> Texture2D:
	if _spinner != null:
		return _spinner
	var n := _SPINNER_SIZE
	var image := Image.create(n, n, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	var center := Vector2(n - 1, n - 1) * 0.5
	for y in n:
		for x in n:
			var offset := Vector2(x, y) - center
			var radius := offset.length()
			if radius < 3.4 or radius > 5.6:
				continue
			var along := fposmod(atan2(offset.y, offset.x) + PI, TAU) / TAU
			if along > 0.78:
				continue
			image.set_pixel(x, y, Color(0.9, 0.9, 0.9, lerpf(0.15, 1.0, along / 0.78)))
	_spinner = ImageTexture.create_from_image(image)
	return _spinner
