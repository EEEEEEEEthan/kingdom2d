@tool
extends PanelContainer

signal chat_requested(session_id: String, title: String)

var _dot_working: Texture2D
var _dot_idle: Texture2D


func apply(session: Dictionary) -> void:
	%CardName.text = str(session.get("name", ""))
	var working := bool(session.get("working", false))
	%SessionStatus.texture = _working_texture() if working else _idle_texture()
	%SessionStatus.tooltip_text = "工作中" if working else "空闲"
	%SessionStatus.custom_minimum_size = Vector2(12, 12)
	%SessionStatus.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	%Chat.set_meta("session_id", str(session.get("id", "")))
	%Chat.set_meta("title", str(session.get("name", "")))
	if not %Chat.pressed.is_connected(_on_chat_pressed):
		%Chat.pressed.connect(_on_chat_pressed)


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
