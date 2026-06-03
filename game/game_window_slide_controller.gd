extends Node

var _slide_pos_y: float
var _slide_target_y: float = 0.0
var _slide_y_docked: float
var _slide_y_hidden: float
var _slide_pos_y_velocity: float = 0.0
var _desired_shown := true

const SLIDE_SMOOTH_TIME := 0.2

@onready var _game: Game = %Game

var _game_window: Window:
	get:
		if not _game_window:
			_game_window = owner as Window
		return _game_window

func _ready() -> void:
	_slide_pos_y = float(_game_window.compute_hidden_below_global_position().y)
	_sync_slide_targets()


func set_game_shown(shown: bool) -> void:
	_desired_shown = shown
	_game_window.suppress_dock_position_in_layout = not shown
	_slide_pos_y_velocity = 0.0
	_sync_slide_targets()


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
