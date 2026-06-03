extends Node

var _slide_pos: Vector2
var _slide_target_y: float = 0.0
var _slide_pos_y_velocity: float = 0.0
var _desired_shown := true

const SLIDE_SMOOTH_TIME := 0.2

var _game_window: Window:
	get:
		if not _game_window:
			_game_window = owner as Window
		return _game_window

func _ready() -> void:
	set_process(false)
	_slide_pos = Vector2(_game_window.position)


func set_game_shown(shown: bool) -> void:
	_desired_shown = shown
	_game_window.suppress_dock_position_in_layout = not shown
	_slide_pos_y_velocity = 0.0
	_sync_slide_targets()
	set_process(true)


func _on_game_window_size_changed() -> void:
	_sync_slide_targets()


func _sync_slide_targets() -> void:
	_slide_pos = Vector2(_game_window.position)
	if _desired_shown:
		_slide_target_y = float(_game_window.compute_docked_global_position().y)
	else:
		_slide_target_y = float(_game_window.compute_hidden_below_global_position().y)


func _process(delta: float) -> void:
	var damped: Dictionary = _smooth_damp_float(
		_slide_pos.y,
		_slide_target_y,
		_slide_pos_y_velocity,
		SLIDE_SMOOTH_TIME,
		delta,
	)
	_slide_pos.y = damped.value
	_slide_pos_y_velocity = damped.velocity
	_game_window.position = Vector2i(_slide_pos)


func _smooth_damp_float(
	current: float,
	target: float,
	velocity: float,
	smooth_time: float,
	delta: float,
) -> Dictionary:
	var time: float = maxf(0.0001, smooth_time)
	var omega: float = 2.0 / time
	var x: float = omega * delta
	var e: float = 1.0 / (1.0 + x + 0.48 * x * x + 0.235 * x * x * x)
	var change: float = current - target
	var temp: float = (velocity + omega * change) * delta
	var new_velocity: float = (velocity - omega * temp) * e
	var output: float = target + (change + temp) * e
	if (target - current) * (output - target) > 0.0:
		output = target
		new_velocity = 0.0
	return {&"value": output, &"velocity": new_velocity}
