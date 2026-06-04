extends Window

signal control_window_open_requested
signal quit_requested

const BASE_HEIGHT := 64
const MAX_WIDTH := 4096

var suppress_dock_position_in_layout := false

var pined := true:
	set(value):
		if pined == value:
			return
		pined = value
		if not is_node_ready():
			await ready
		$AutoHideController.pined = value

@export var scale: int = 1:
	set(value):
		scale = value
		apply_layout()

@export var width_ratio: float = 1.0:
	set(value):
		width_ratio = value
		apply_layout()


func _ready() -> void:
	scale = Settings.display_scale
	width_ratio = Settings.game_width_ratio
	Settings.display_scale_changed.connect(_on_settings_display_scale_changed)
	Settings.game_width_ratio_changed.connect(_on_settings_game_width_ratio_changed)
	%GameHud.bar_dismiss_requested.connect(func() -> void: $AutoHideController.closed = true)
	%GameHud.auto_hide_pin_toggled.connect(func(pressed: bool) -> void: pined = pressed)
	$AutoHideController.pined_changed.connect(func(value: bool) -> void: pined = value)
	%GameHud.sync_pin_from_pined(pined)
	%GameHud.control_window_open_requested.connect(control_window_open_requested.emit)
	%GameHud.quit_requested.connect(quit_requested.emit)
	apply_layout(true)
	visible = true


func compute_docked_global_position() -> Vector2i:
	var screen := current_screen
	var screen_pos := DisplayServer.screen_get_position(screen)
	var usable := DisplayServer.screen_get_usable_rect(screen)
	var height := BASE_HEIGHT * scale
	return Vector2i(
		screen_pos.x,
		usable.position.y + usable.size.y - height,
	)


func compute_hidden_below_global_position() -> Vector2i:
	var docked_global_position := compute_docked_global_position()
	var screen := current_screen
	var screen_pos := DisplayServer.screen_get_position(screen)
	var screen_size := DisplayServer.screen_get_size(screen)
	return Vector2i(
		docked_global_position.x,
		screen_pos.y + screen_size.y,
	)


func apply_layout(align_to_bottom: bool = false) -> void:
	var screen_size := DisplayServer.screen_get_size(current_screen)
	var width := mini(maxi(1, int(round(screen_size.x * width_ratio))), MAX_WIDTH)
	var height := BASE_HEIGHT * scale
	content_scale_factor = 1.0
	%ViewportContainer.stretch_shrink = scale
	var hud_scale := clampi(scale, 1, 2)
	var new_size := Vector2i(width, height)
	if suppress_dock_position_in_layout:
		size = new_size
		%GameHud.hud_scale = hud_scale
		return
	if align_to_bottom:
		position = compute_docked_global_position()
		size = new_size
	else:
		var bottom_center := Vector2(position.x + size.x / 2.0, position.y + size.y)
		position = Vector2(bottom_center.x - new_size.x / 2.0, bottom_center.y - new_size.y)
		size = new_size
	%GameHud.hud_scale = hud_scale


func _on_settings_display_scale_changed(new_scale: int) -> void:
	scale = new_scale


func _on_settings_game_width_ratio_changed(new_ratio: float) -> void:
	width_ratio = new_ratio


func reset_game() -> void:
	%Game.reset_game()
