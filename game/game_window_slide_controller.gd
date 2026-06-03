extends Node

var _slide_pos_y: float
var _slide_target_y: float = 0.0
var _slide_y_docked: float
var _slide_y_hidden: float
var _slide_pos_y_velocity: float = 0.0
var _desired_shown := true

var _auto_hide := true
var _game_visible_setting := true
var _auto_hide_delay_seconds := 2.0
var _outside_safe_timer := 0.0

const SLIDE_SMOOTH_TIME := 0.2
const SHOW_TRIGGER_ABOVE_PX := 5

@onready var _game: Game = %Game

var _game_window: Window:
	get:
		if not _game_window:
			_game_window = owner as Window
		return _game_window

func _ready() -> void:
	if not _game_window.is_node_ready():
		await _game_window.ready
	_slide_pos_y = float(_game_window.compute_hidden_below_global_position().y)
	var pos := _game_window.position
	_game_window.position = Vector2i(pos.x, int(_slide_pos_y))
	_sync_slide_targets()
	await get_tree().process_frame
	force_show()

func force_show() -> void:
	_outside_safe_timer = -5
	set_game_shown(true)

func configure_visibility_control(auto_hide: bool, game_shown: bool) -> void:
	_auto_hide = auto_hide
	_game_visible_setting = game_shown
	_outside_safe_timer = 0.0
	_apply_visibility_policy()


func configure_auto_hide(auto_hide: bool) -> void:
	_auto_hide = auto_hide
	_outside_safe_timer = 0.0
	_apply_visibility_policy()


func configure_auto_hide_delay(seconds: float) -> void:
	_auto_hide_delay_seconds = seconds
	_outside_safe_timer = 0.0


func set_game_shown(shown: bool) -> void:
	_desired_shown = shown
	_game_window.suppress_dock_position_in_layout = not shown
	_slide_pos_y_velocity = 0.0
	_sync_slide_targets()


func _apply_visibility_policy() -> void:
	if not _auto_hide:
		set_game_shown(_game_visible_setting)


func _update_auto_hide(delta: float) -> void:
	var mouse := DisplayServer.mouse_get_position()
	if _desired_shown:
		if _is_mouse_in_safe_zone(mouse):
			_outside_safe_timer = 0.0
		else:
			_outside_safe_timer += delta
			if _outside_safe_timer >= _auto_hide_delay_seconds:
				set_game_shown(false)
	else:
		if _is_mouse_in_show_trigger(mouse):
			set_game_shown(true)
		else:
			_outside_safe_timer = 0.0


func _is_mouse_in_safe_zone(mouse: Vector2i) -> bool:
	var window_position := _game_window.position
	var window_size := _game_window.size
	var screen_bottom := _screen_bottom_global_y()
	if window_position.y >= screen_bottom:
		return false
	var zone := Rect2i(window_position.x, window_position.y, window_size.x, screen_bottom - window_position.y)
	return zone.has_point(mouse)


func _screen_bottom_global_y() -> int:
	var screen := _game_window.current_screen
	var screen_origin := DisplayServer.screen_get_position(screen)
	return screen_origin.y + DisplayServer.screen_get_size(screen).y


func _is_mouse_in_show_trigger(mouse: Vector2i) -> bool:
	var docked: Vector2i = _game_window.compute_docked_global_position()
	var window_size := _game_window.size
	var screen_bottom := _screen_bottom_global_y()
	var zone := Rect2i(
		docked.x,
		screen_bottom - SHOW_TRIGGER_ABOVE_PX,
		window_size.x,
		SHOW_TRIGGER_ABOVE_PX,
	)
	return zone.has_point(mouse)


func _on_game_window_size_changed() -> void:
	_sync_slide_targets()


func _sync_slide_targets() -> void:
	_slide_pos_y = float(_game_window.position.y)
	_slide_y_docked = float(_game_window.compute_docked_global_position().y)
	_slide_y_hidden = float(_game_window.compute_hidden_below_global_position().y)
	if _desired_shown:
		_slide_target_y = _slide_y_docked
	else:
		_slide_target_y = _slide_y_hidden


func _process(delta: float) -> void:
	if _auto_hide:
		_update_auto_hide(delta)
	var current: float = _slide_pos_y
	var target: float = _slide_target_y
	var omega: float = 2.0 / maxf(0.0001, SLIDE_SMOOTH_TIME)
	var x: float = omega * delta
	var e: float = 1.0 / (1.0 + x + 0.48 * x * x + 0.235 * x * x * x)
	var change: float = current - target
	var temp: float = (_slide_pos_y_velocity + omega * change) * delta
	_slide_pos_y_velocity = (_slide_pos_y_velocity - omega * temp) * e
	_slide_pos_y = target + (change + temp) * e
	if (target - current) * (_slide_pos_y - target) > 0.0:
		_slide_pos_y = target
		_slide_pos_y_velocity = 0.0
	var pos := _game_window.position
	_game_window.position = Vector2i(pos.x, int(_slide_pos_y))
	var progress := inverse_lerp(_slide_y_docked, _slide_y_hidden, _slide_pos_y)
	_game.view_height = 1.0 - clampf(progress, 0.0, 1.0)
