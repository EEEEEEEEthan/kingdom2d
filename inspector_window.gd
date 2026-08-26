extends Window
class_name InspectorWindow

func inspect_character(character: Character) -> void:
	title = "角色 %s" % character.id
	if not is_node_ready():
		await ready
	if not has_node("%InventoryPanel"):
		var inventory_panel := %InventoryPanelPlaceHolder.create_instance()
		inventory_panel.name = "InventoryPanel"
		inventory_panel.unique_name_in_owner = true
	%InventoryPanel.inventory = character.inventory
	var mouse_position := DisplayServer.mouse_get_position()
	var window_position := mouse_position + Vector2i(24, 24)
	var screen := DisplayServer.get_screen_from_rect(Rect2(mouse_position, Vector2.ONE))
	var usable := DisplayServer.screen_get_usable_rect(screen)
	var window_size := size
	if window_position.x + window_size.x > usable.position.x + usable.size.x:
		window_position.x = mouse_position.x - window_size.x - 24
	if window_position.y + window_size.y > usable.position.y + usable.size.y:
		window_position.y = mouse_position.y - window_size.y - 24
	window_position.x = clampi(
			window_position.x,
			usable.position.x,
			usable.position.x + maxi(0, usable.size.x - window_size.x)
	)
	window_position.y = clampi(
			window_position.y,
			usable.position.y,
			usable.position.y + maxi(0, usable.size.y - window_size.y)
	)
	current_screen = screen
	position = window_position
	show()
	mode = MODE_WINDOWED
	grab_focus()


func _ready() -> void:
	visible = false
