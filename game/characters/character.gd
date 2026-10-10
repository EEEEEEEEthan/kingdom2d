extends Node2D
class_name Character

const _KEY_ID = 1
const _KEY_POSITION = 2
const _KEY_AI_TASK_STACK = 3
const _KEY_HOME = 4
const _KEY_DUTY = 5
const _KEY_WORKPLACE = 6
const _KEY_PHASE = 7
const _KEY_CARRY = 8

enum Duty { NONE, LUMBER, BUILDER }

const _CHOP_SECONDS := 1.6
const _HAMMER_SECONDS := 1.1

var home_id := 0
var duty := Duty.NONE
var workplace_id := 0
var carrying_logs := 0
var _duty_phase := 0
var _duty_timer := 0.0
var _haul_target_id := 0
const DEFAULT_MOVE_SPEED_PIXELS_PER_SECOND = 6.0
const _IDLE_WANDER_WAIT_SECONDS_MIN = 1.0
const _IDLE_WANDER_WAIT_SECONDS_MAX = 3.0
const _IDLE_WANDER_RADIUS_PIXELS = 32.0

var id: int
@export var move_speed_pixels_per_second := DEFAULT_MOVE_SPEED_PIXELS_PER_SECOND
var ai_task_stack := CharacterAiTaskStack.new()

var _ai_context: CharacterAiContext

func _ready() -> void:
	_get_ai_context()
	set_process(true)

func _process(delta_seconds: float) -> void:
	if duty != Duty.NONE:
		_tick_duty(delta_seconds)
		return
	ai_task_stack.tick(delta_seconds, _get_ai_context())
	if ai_task_stack.is_empty():
		_schedule_idle_wander()


func assign_duty(next_duty: Duty, next_workplace_id: int) -> void:
	abandon_ai_tasks()
	duty = next_duty
	workplace_id = next_workplace_id
	carrying_logs = 0
	_duty_phase = 0
	_duty_timer = 0.0
	_haul_target_id = 0
	_refresh_carry_tint()


func clear_duty() -> void:
	assign_duty(Duty.NONE, 0)

func push_ai_task(task: CharacterAiTask) -> void:
	ai_task_stack.push(task, _get_ai_context())

func abandon_ai_tasks() -> void:
	ai_task_stack.abandon(_get_ai_context())

func advance_toward_world_x(delta_seconds: float, target_world_x: float) -> bool:
	var offset := target_world_x - position.x
	if is_zero_approx(offset):
		return true
	var step := move_speed_pixels_per_second * delta_seconds
	if absf(offset) <= step:
		position.x = target_world_x
		return true
	position.x += signf(offset) * step
	return false

func deserialize(data: Dictionary) -> void:
	id = data[_KEY_ID]
	position = Vector2(data[_KEY_POSITION], 0)
	home_id = data.get(_KEY_HOME, 0)
	duty = data.get(_KEY_DUTY, Duty.NONE)
	workplace_id = data.get(_KEY_WORKPLACE, 0)
	_duty_phase = data.get(_KEY_PHASE, 0)
	carrying_logs = data.get(_KEY_CARRY, 0)
	ai_task_stack.deserialize(data.get(_KEY_AI_TASK_STACK, {}), _get_ai_context())
	_refresh_carry_tint()

func serialize() -> Dictionary:
	return {
		_KEY_ID: id,
		_KEY_POSITION: position.x,
		_KEY_AI_TASK_STACK: ai_task_stack.serialize(),
		_KEY_HOME: home_id,
		_KEY_DUTY: duty,
		_KEY_WORKPLACE: workplace_id,
		_KEY_PHASE: _duty_phase,
		_KEY_CARRY: carrying_logs,
	}


func _game() -> Game:
	return get_parent().get_parent().get_parent().get_parent() as Game


func _structure(structure_id: int) -> LoopStructure:
	var structure := _game().structure_manager.get_structure_by_id(structure_id)
	return structure as LoopStructure


func _warehouse() -> LoopStructure:
	for structure in _game().structure_manager.index_to_structures:
		if structure is LoopStructure and (structure as LoopStructure).kind == LoopStructure.Kind.WAREHOUSE:
			return structure
	return null


func _tick_duty(delta_seconds: float) -> void:
	var workplace := _structure(workplace_id)
	if workplace == null:
		clear_duty()
		return
	if duty == Duty.LUMBER:
		_tick_lumber(delta_seconds, workplace)
	elif duty == Duty.BUILDER:
		_tick_builder(delta_seconds, workplace)


func _tick_lumber(delta_seconds: float, camp: LoopStructure) -> void:
	var warehouse := _warehouse()
	if warehouse == null:
		return
	match _duty_phase:
		0:
			if advance_toward_world_x(delta_seconds, camp.position.x):
				_duty_phase = 2 if camp.logs > 0 else 1
				_duty_timer = _CHOP_SECONDS
		1:
			_duty_timer -= delta_seconds
			if _duty_timer > 0.0:
				return
			camp.logs += 1
			_duty_phase = 2
		2:
			if camp.logs <= 0:
				_duty_phase = 0
				return
			camp.logs -= 1
			carrying_logs = 1
			_refresh_carry_tint()
			_duty_phase = 3
		3:
			if advance_toward_world_x(delta_seconds, warehouse.position.x):
				if warehouse.can_accept_log():
					warehouse.logs += 1
					carrying_logs = 0
					_refresh_carry_tint()
					_duty_phase = 0
				else:
					_duty_phase = 4
		4:
			if advance_toward_world_x(delta_seconds, camp.position.x):
				camp.logs += carrying_logs
				carrying_logs = 0
				_refresh_carry_tint()
				_duty_phase = 0


func _tick_builder(delta_seconds: float, guild: LoopStructure) -> void:
	var warehouse := _warehouse()
	match _duty_phase:
		0:
			if advance_toward_world_x(delta_seconds, guild.position.x):
				_duty_phase = 1
		1:
			if carrying_logs > 0 and _haul_target_id != 0:
				_duty_phase = 3
				return
			var target := _pick_tent()
			if target == null:
				return
			if guild.logs > 0:
				guild.logs -= 1
			elif warehouse != null and warehouse.logs > 0:
				warehouse.logs -= 1
				guild.logs += 1
				guild.logs -= 1
			else:
				return
			target.in_flight += 1
			_haul_target_id = target.id
			carrying_logs = 1
			_refresh_carry_tint()
			_duty_phase = 3
		2:
			var reserved := _structure(_haul_target_id)
			if reserved == null or not reserved.needs_hut_log() and reserved.kind == LoopStructure.Kind.TENT:
				pass
			var next_target := reserved if reserved != null and reserved.kind == LoopStructure.Kind.TENT else _pick_tent()
			if next_target == null:
				return
			if next_target.id != _haul_target_id:
				if reserved != null:
					reserved.in_flight = maxi(0, reserved.in_flight - 1)
				next_target.in_flight += 1
				_haul_target_id = next_target.id
			_duty_phase = 3
		3:
			var site := _structure(_haul_target_id)
			if site == null or site.kind != LoopStructure.Kind.TENT:
				_return_log_to_guild(guild)
				return
			if advance_toward_world_x(delta_seconds, site.position.x):
				_duty_phase = 4
				_duty_timer = _HAMMER_SECONDS
		4:
			_duty_timer -= delta_seconds
			if _duty_timer > 0.0:
				return
			var site := _structure(_haul_target_id)
			carrying_logs = 0
			_refresh_carry_tint()
			if site == null or site.kind != LoopStructure.Kind.TENT:
				_duty_phase = 0
				return
			site.in_flight = maxi(0, site.in_flight - 1)
			site.applied += 1
			_haul_target_id = 0
			if site.applied >= LoopStructure.HUT_LOGS:
				_game().structure_manager.replace_tent_with_hut(site, _game())
			_duty_phase = 0


func _return_log_to_guild(guild: LoopStructure) -> void:
	if _haul_target_id != 0:
		var site := _structure(_haul_target_id)
		if site:
			site.in_flight = maxi(0, site.in_flight - 1)
		_haul_target_id = 0
	guild.logs += carrying_logs
	carrying_logs = 0
	_refresh_carry_tint()
	_duty_phase = 0


func _pick_tent() -> LoopStructure:
	var best: LoopStructure
	var best_distance := 1_000_000
	for structure in _game().structure_manager.index_to_structures:
		if not structure is LoopStructure:
			continue
		var tent := structure as LoopStructure
		if not tent.needs_hut_log():
			continue
		var distance := absi(tent.cell_index - int(position.x / Game.TILE_SIZE))
		if distance < best_distance:
			best_distance = distance
			best = tent
	return best


func _refresh_carry_tint() -> void:
	modulate = Color(1, 0.86, 0.55) if carrying_logs > 0 else Color.WHITE

func _get_ai_context() -> CharacterAiContext:
	if not _ai_context:
		_ai_context = CharacterAiContext.new(self)
	return _ai_context

func _schedule_idle_wander() -> void:
	var wait_duration_seconds := randf_range(_IDLE_WANDER_WAIT_SECONDS_MIN, _IDLE_WANDER_WAIT_SECONDS_MAX)
	var wait_task := CharacterAiWaitDurationTask.new({
		CharacterAiWaitDurationTask.KEY_DURATION_SECONDS: wait_duration_seconds,
	})
	var move_task := CharacterAiMoveToWorldXTask.new({
		CharacterAiMoveToWorldXTask.KEY_TARGET_WORLD_X: _pick_idle_wander_target_world_x(),
	})
	push_ai_task(move_task)
	push_ai_task(wait_task)

func _pick_idle_wander_target_world_x() -> float:
	var map_min_world_x: float = Game.get_position_by_cell_index(0) + Game.HALF_TILE_SIZE
	var map_max_world_x: float = Game.get_position_by_cell_index(Game.MAP_CELL_COUNT - 1) + Game.HALF_TILE_SIZE
	var offset_pixels := randf_range(-_IDLE_WANDER_RADIUS_PIXELS, _IDLE_WANDER_RADIUS_PIXELS)
	if is_zero_approx(offset_pixels):
		offset_pixels = 1.0 if randf() < 0.5 else -1.0
	return clampf(position.x + offset_pixels, map_min_world_x, map_max_world_x)
