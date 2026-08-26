extends Window

var character: Character:
	set(value):
		if character == value:
			return
		if character and character.tree_exiting.is_connected(hide):
			character.tree_exiting.disconnect(hide)
		character = value
		if character:
			character.tree_exiting.connect(hide)
		if not is_node_ready():
			await ready
		%InventoryLabel.refresh()


func _ready() -> void:
	visible = false


func open_for_character(opened_character: Character) -> void:
	character = opened_character
	title = "角色 %s 背包" % opened_character.id
	var mouse_position := DisplayServer.mouse_get_position()
	var screen := DisplayServer.get_screen_from_rect(Rect2(mouse_position, Vector2.ONE))
	var usable := DisplayServer.screen_get_usable_rect(screen)
	var window_size := size
	mouse_position.x = clampi(
			mouse_position.x,
			usable.position.x,
			usable.position.x + maxi(0, usable.size.x - window_size.x)
	)
	mouse_position.y = clampi(
			mouse_position.y,
			usable.position.y,
			usable.position.y + maxi(0, usable.size.y - window_size.y)
	)
	current_screen = screen
	position = mouse_position
	show()
	mode = MODE_WINDOWED
	grab_focus()
