@tool
extends PanelContainer

signal checkout_requested(branch: String)
signal chat_requested(session_id: String, title: String)

var _dot_working: Texture2D
var _dot_idle: Texture2D


func apply(card: Dictionary) -> void:
	%CardName.text = str(card.get("title", ""))
	var has_session := not str(card.get("session_id", "")).is_empty()
	%Chat.visible = has_session
	%SessionStatus.visible = has_session
	if has_session:
		# SessionStatus 表示这个聊天是否正在工作。
		%SessionStatus.texture = _working_texture() if bool(card.get("working", false)) else _idle_texture()
		%SessionStatus.tooltip_text = "工作中" if bool(card.get("working", false)) else "空闲"
		%SessionStatus.custom_minimum_size = Vector2(12, 12)
	var has_branch := not str(card.get("branch", "")).is_empty()
	%Checkout.visible = has_branch
	%Checkout.set_meta("branch", str(card.get("branch", "")))
	if not %Checkout.pressed.is_connected(_on_checkout_pressed):
		%Checkout.pressed.connect(_on_checkout_pressed)
	%Chat.set_meta("session_id", str(card.get("session_id", "")))
	%Chat.set_meta("title", str(card.get("title", "")))
	if not %Chat.pressed.is_connected(_on_chat_pressed):
		%Chat.pressed.connect(_on_chat_pressed)


func _on_chat_pressed() -> void:
	var chat := %Chat as Button
	chat_requested.emit(str(chat.get_meta("session_id", "")), str(chat.get_meta("title", "")))


func _on_checkout_pressed() -> void:
	var checkout := %Checkout as Button
	checkout_requested.emit(str(checkout.get_meta("branch", "")))


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
