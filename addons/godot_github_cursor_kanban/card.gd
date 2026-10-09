@tool
extends PanelContainer

signal checkout_requested(branch: String)

const _WORKING_COLOR := Color(0.95, 0.78, 0.2)


func apply(card: Dictionary) -> void:
	%CardName.text = str(card.get("title", ""))
	# 正在工作用黄色标题，否则用主题默认色。
	if bool(card.get("working", false)):
		%CardName.add_theme_color_override("font_color", _WORKING_COLOR)
	else:
		%CardName.remove_theme_color_override("font_color")
	var has_session := not str(card.get("session_id", "")).is_empty()
	$VBoxContainer/SessionInfo.visible = has_session
	var checkout := $VBoxContainer/Checkout as Button
	checkout.disabled = str(card.get("branch", "")).is_empty()
	if not checkout.pressed.is_connected(_on_checkout_pressed):
		checkout.set_meta("branch", str(card.get("branch", "")))
		checkout.pressed.connect(_on_checkout_pressed)
	else:
		checkout.set_meta("branch", str(card.get("branch", "")))


func _on_checkout_pressed() -> void:
	var checkout := $VBoxContainer/Checkout as Button
	checkout_requested.emit(str(checkout.get_meta("branch", "")))
