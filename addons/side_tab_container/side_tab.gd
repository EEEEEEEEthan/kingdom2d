@tool
extends Button
class_name SideTab

signal close_pressed

var _selected := false
var _dragging := false


func set_tab_title(title: String) -> void:
	text = title
	custom_minimum_size = Vector2(
			get_theme_font(&"font").get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x + 18.0,
			16.0
	)


func set_selected(selected: bool) -> void:
	_selected = selected
	theme_type_variation = &"SideTabSelected" if selected else &"SideTab"


func set_dragging(dragging: bool) -> void:
	_dragging = dragging
	%CloseButton.visible = not dragging and is_hovered()


func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_ENTER:
		%CloseButton.visible = not _dragging
	elif what == NOTIFICATION_MOUSE_EXIT:
		%CloseButton.visible = false
