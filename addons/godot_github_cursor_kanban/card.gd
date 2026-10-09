@tool
extends PanelContainer

signal checkout_requested(branch: String)
signal chat_requested(session_id: String, title: String)

const _CHAT_ICON := "res://addons/godot_github_cursor_kanban/icons/chat.png"
const _CHECKOUT_ICON := "res://addons/godot_github_cursor_kanban/icons/checkout.png"

var _dot_working: Texture2D
var _dot_idle: Texture2D
var _icons_ready := false


func apply(card: Dictionary) -> void:
	_ensure_icons()
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


func _ensure_icons() -> void:
	if _icons_ready:
		return
	_icons_ready = true
	# 图标只赋给 Button.icon，按钮本身保持编辑器按钮样式。
	_set_symbol(%Chat, [], _CHAT_ICON, tr("打开聊天"))
	_set_symbol(%Checkout, ["VcsBranches", "VcsBranch"], _CHECKOUT_ICON, tr("检出分支"))


func _set_symbol(button: Button, theme_names: Array, fallback_path: String, tip: String) -> void:
	button.text = ""
	button.flat = false
	button.expand_icon = false
	button.icon = _theme_icon(theme_names, fallback_path)
	button.tooltip_text = tip
	button.custom_minimum_size = Vector2(28, 28)


func _theme_icon(names: Array, fallback_path: String) -> Texture2D:
	var base := EditorInterface.get_base_control()
	if base:
		for icon_name in names:
			if base.has_theme_icon(icon_name, "EditorIcons"):
				return base.get_theme_icon(icon_name, "EditorIcons")
	return _load_png(fallback_path)


func _load_png(path: String) -> Texture2D:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return null
	var image := Image.new()
	if image.load_png_from_buffer(file.get_buffer(file.get_length())) != OK:
		return null
	return ImageTexture.create_from_image(image)


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
