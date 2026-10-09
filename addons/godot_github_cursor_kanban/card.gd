@tool
extends PanelContainer

signal checkout_requested(branch: String)
signal chat_requested(session_id: String, title: String)

const _CHAT_ICON := "res://addons/godot_github_cursor_kanban/icons/chat.png"
const _CHECKOUT_ICON := "res://addons/godot_github_cursor_kanban/icons/checkout.png"

var _icons_ready := false
var _spinner: Texture2D
var _spinning := false


func _enter_tree() -> void:
	set_process(false)


func apply(card: Dictionary) -> void:
	_ensure_icons()
	%CardName.text = str(card.get("title", ""))
	var has_session := not str(card.get("session_id", "")).is_empty()
	%Chat.visible = has_session
	%SessionStatus.visible = has_session
	_set_spinning(has_session and bool(card.get("working", false)))
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


func _set_spinning(working: bool) -> void:
	var status := %SessionStatus as TextureRect
	status.texture = _spinner_texture()
	status.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	status.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	status.custom_minimum_size = Vector2(16, 16)
	status.tooltip_text = "工作中" if working else "空闲"
	# 不工作时留着占位，只把图标打成全透明。
	status.modulate.a = 1.0 if working else 0.0
	status.pivot_offset = status.custom_minimum_size * 0.5
	if not working:
		status.rotation = 0.0
	_spinning = working
	set_process(working)


func _process(delta: float) -> void:
	if not _spinning:
		return
	var status := %SessionStatus as TextureRect
	status.pivot_offset = status.size * 0.5
	status.rotation = wrapf(status.rotation + delta * TAU, 0.0, TAU)


func _spinner_texture() -> Texture2D:
	if _spinner == null:
		_spinner = _theme_icon(["Reload", "Loop", "RotateRight"], "")
		if _spinner == null:
			_spinner = _make_spinner()
	return _spinner


func _make_spinner() -> Texture2D:
	var image := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	var center := Vector2(7.5, 7.5)
	for y in 16:
		for x in 16:
			var offset := Vector2(x, y) - center
			var radius := offset.length()
			if radius < 4.2 or radius > 6.6:
				continue
			var angle := fposmod(offset.angle(), TAU)
			if angle > PI:
				continue
			image.set_pixel(x, y, Color(0.75, 0.75, 0.75, 1.0 - angle / PI))
	return ImageTexture.create_from_image(image)
