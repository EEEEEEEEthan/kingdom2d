@tool
extends Button
class_name SideTab

signal close_pressed

var _selected := false
var _dragging := false
var _refreshing_look := false


func _ready() -> void:
	focus_mode = Control.FOCUS_NONE
	mouse_filter = Control.MOUSE_FILTER_STOP
	alignment = HORIZONTAL_ALIGNMENT_LEFT
	clip_text = true
	add_theme_font_size_override(&"font_size", 10)
	_refresh_look()


func set_tab_title(title: String) -> void:
	text = title
	update_minimum_size()
	_refresh_look()


func set_selected(selected: bool) -> void:
	_selected = selected
	_refresh_look()


func set_dragging(dragging: bool) -> void:
	_dragging = dragging
	%CloseButton.visible = not dragging and is_hovered()


func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_ENTER:
		%CloseButton.visible = not _dragging
	elif what == NOTIFICATION_MOUSE_EXIT:
		%CloseButton.visible = false
	elif what == NOTIFICATION_THEME_CHANGED:
		if not _refreshing_look:
			_refresh_look()


func _get_minimum_size() -> Vector2:
	var font := get_theme_font(&"font")
	if font == null:
		font = ThemeDB.fallback_font
	var text_width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x
	return Vector2(text_width + 18.0, 16.0)


func _refresh_look() -> void:
	if not is_node_ready() or _refreshing_look:
		return
	_refreshing_look = true
	var selected: bool = _selected
	var selected_style := _style(&"tab_selected")
	var hovered_style := _style(&"tab_hovered")
	var unselected_style := _style(&"tab_unselected")
	if selected:
		add_theme_stylebox_override(&"normal", selected_style)
		add_theme_stylebox_override(&"hover", selected_style)
		add_theme_stylebox_override(&"pressed", selected_style)
		add_theme_stylebox_override(&"focus", selected_style)
	else:
		add_theme_stylebox_override(&"normal", unselected_style)
		add_theme_stylebox_override(&"hover", hovered_style)
		add_theme_stylebox_override(&"pressed", hovered_style)
		add_theme_stylebox_override(&"focus", unselected_style)
	var selected_color := _color(&"font_selected_color")
	var hovered_color := _color(&"font_hovered_color")
	var unselected_color := _color(&"font_unselected_color")
	if selected:
		add_theme_color_override(&"font_color", selected_color)
		add_theme_color_override(&"font_hover_color", selected_color)
		add_theme_color_override(&"font_pressed_color", selected_color)
		add_theme_color_override(&"font_focus_color", selected_color)
	else:
		add_theme_color_override(&"font_color", unselected_color)
		add_theme_color_override(&"font_hover_color", hovered_color)
		add_theme_color_override(&"font_pressed_color", hovered_color)
		add_theme_color_override(&"font_focus_color", unselected_color)
	_refreshing_look = false


func _style(style_name: StringName) -> StyleBox:
	var style := get_theme_stylebox(style_name, &"TabContainer")
	if style:
		return style
	var fallback := StyleBoxFlat.new()
	fallback.bg_color = Color(0.85, 0.63, 0.4, 1.0) if style_name == &"tab_selected" else Color(0.56, 0.34, 0.23, 1.0)
	return fallback


func _color(color_name: StringName) -> Color:
	var color := get_theme_color(color_name, &"TabContainer")
	if color.a <= 0.0:
		return Color.WHITE
	return color
