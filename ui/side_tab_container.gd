extends Control
class_name SideTabContainer

signal tab_closed(page: Control)
signal current_tab_changed(tab_index: int)
signal all_tabs_closed

var current_tab: int = 0:
	set(value):
		current_tab = value
		if not is_node_ready():
			await ready
		%TabStrip.current_tab = value
	get:
		if not is_node_ready():
			return current_tab
		return %TabStrip.current_tab


func set_tab_title(page: Control, title_text: String) -> void:
	if not is_node_ready():
		await ready
	%TabStrip.set_tab_title(page, title_text)


func restore_closed_tabs() -> void:
	if not is_node_ready():
		await ready
	%TabStrip.restore_closed_tabs()
