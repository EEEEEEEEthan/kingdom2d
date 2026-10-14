extends CharacterAiTask
class_name CharacterAiBuildCycleTask

## 建筑工的一轮：去工会，要么去仓库搬原木，要么在工地干满 10 秒。
## 多人可以各搬一整份。送到工地后只留下还缺的，多的退回仓库。
## 一轮结束就收工；还在工时就再来一轮。材料没齐就在工会等。
## 工地包括：玩家放下后待建的建筑，以及半穴茅舍升木架。

const KEY_PHASE = 1
const KEY_ELAPSED_SECONDS = 2
const KEY_SITE_ID = 3
const KEY_WAREHOUSE_ID = 4
const KEY_GUILD_ID = 5
const KEY_WAIT_KIND = 7
const KEY_PACE_FAR = 8
const KEY_KNOCKS = 9

const _PHASE_TO_GUILD := 0
const _PHASE_IN_GUILD := 1
const _PHASE_TO_WAREHOUSE := 2
const _PHASE_HAUL := 3
const _PHASE_TO_SITE := 4
const _PHASE_BUILD := 5
const _PHASE_BACK := 6
const _PHASE_WAIT := 7
const _PHASE_RETURN := 8

const _INSIDE_SECONDS := 0.4
const _WAIT_SECONDS := 2.0
const _WAIT_JOB := 0
const _WAIT_LOGS := 1

var _phase := 0
var _elapsed_seconds := 0.0
var _site_id := 0
var _warehouse_id := 0
var _guild_id := 0
var _wait_kind := 0
var _pace_far := true
var _knocks := 0


func _init(save_payload: Dictionary) -> void:
	_phase = save_payload.get(KEY_PHASE, 0)
	_elapsed_seconds = save_payload.get(KEY_ELAPSED_SECONDS, 0.0)
	_site_id = save_payload.get(KEY_SITE_ID, 0)
	_warehouse_id = save_payload.get(KEY_WAREHOUSE_ID, 0)
	_guild_id = save_payload.get(KEY_GUILD_ID, 0)
	_wait_kind = save_payload.get(KEY_WAIT_KIND, 0)
	_pace_far = bool(save_payload.get(KEY_PACE_FAR, true))
	_knocks = save_payload.get(KEY_KNOCKS, 0)


func get_type_id() -> CharacterAiTaskTypeId.TypeId:
	return CharacterAiTaskTypeId.TypeId.BUILD_CYCLE


func activity_text() -> String:
	match _phase:
		_PHASE_TO_GUILD:
			return "正在去建筑工会"
		_PHASE_IN_GUILD:
			return "正在建筑工会"
		_PHASE_TO_WAREHOUSE:
			return "正在去仓库取原木"
		_PHASE_HAUL:
			return "正在搬运原木"
		_PHASE_RETURN:
			return "正在退回原木"
		_PHASE_TO_SITE:
			return "正在去工地"
		_PHASE_BUILD:
			return "正在施工"
		_PHASE_WAIT:
			if _wait_kind == _WAIT_LOGS:
				return "正在等待原木"
			return "正在等待工程"
		_:
			return "正在回建筑工会"


func tick(delta_seconds: float, context: CharacterAiContext) -> Status:
	var character := context.character
	if _guild_id == 0:
		_guild_id = character.workplace_structure_id()
	var guild := _guild(context)
	if guild == null:
		character.visible = true
		return Status.FAILED
	if character.indoors:
		character.leave_home()
	match _phase:
		_PHASE_TO_GUILD:
			if character.advance_toward_world_x(delta_seconds, _world_x(guild)):
				character.visible = false
				_phase = _PHASE_IN_GUILD
				_elapsed_seconds = 0.0
		_PHASE_IN_GUILD:
			character.position.x = _world_x(guild)
			character.visible = false
			_elapsed_seconds += delta_seconds
			if _elapsed_seconds < _INSIDE_SECONDS:
				return Status.RUNNING
			_decide(context, character, guild)
		_PHASE_TO_WAREHOUSE:
			if not _walk_to_warehouse(delta_seconds, context, character):
				return Status.FAILED
		_PHASE_HAUL:
			if not _haul(delta_seconds, context, character):
				return Status.FAILED
		_PHASE_RETURN:
			if not _return_surplus(delta_seconds, context, character):
				return Status.FAILED
		_PHASE_TO_SITE:
			var site := _site(context)
			if site == null or not site.builder_logs_ready():
				_phase = _PHASE_TO_GUILD
				return Status.RUNNING
			if character.advance_toward_world_x(delta_seconds, _pace_x(character, site)):
				_phase = _PHASE_BUILD
				_elapsed_seconds = 0.0
				_knocks = 0
				_pace_far = true
		_PHASE_BUILD:
			if not _build(delta_seconds, context, character):
				return Status.RUNNING
		_PHASE_BACK:
			character.visible = true
			_reset_pose(character)
			if character.advance_toward_world_x(delta_seconds, _world_x(guild)):
				character.visible = false
				return Status.SUCCEEDED
		_PHASE_WAIT:
			character.visible = true
			character.position.x = _world_x(guild)
			if context.day_time_period != GameTime.DayTimePeriod.WORK:
				return Status.SUCCEEDED
			_elapsed_seconds += delta_seconds
			if _elapsed_seconds < _WAIT_SECONDS:
				return Status.RUNNING
			_elapsed_seconds = 0.0
			_decide(context, character, guild)
	return Status.RUNNING


func on_exit(context: CharacterAiContext) -> void:
	var character := context.character
	_reset_pose(character)
	if not character.visible and not character.indoors:
		character.visible = true
	var carried := character.carried_items.count_of(ItemConfig.TypeId.LOG)
	var site := _site(context)
	var warehouse := _warehouse(context)
	if carried > 0 and warehouse != null:
		character.carried_items.take(ItemConfig.TypeId.LOG, carried)
		warehouse.restore_logs(carried)
	elif carried > 0 and site != null:
		site.accept_builder_logs(character.carried_items)


func _decide(context: CharacterAiContext, character: Character, guild: BuildersGuild) -> void:
	var site := _pick_site(context, guild)
	_site_id = site.id if site != null else 0
	_warehouse_id = 0
	if site == null:
		_begin_wait(character, _WAIT_JOB)
		return
	if site.builder_logs_ready():
		character.visible = true
		_phase = _PHASE_TO_SITE
		return
	if site.builder_logs_still_needed() <= 0:
		_begin_wait(character, _WAIT_LOGS)
		return
	var warehouse := _nearest_warehouse(context, site)
	if warehouse == null:
		_begin_wait(character, _WAIT_LOGS)
		return
	_warehouse_id = warehouse.id
	character.visible = true
	_phase = _PHASE_TO_WAREHOUSE


func _begin_wait(character: Character, kind: int) -> void:
	_wait_kind = kind
	_phase = _PHASE_WAIT
	_elapsed_seconds = 0.0
	character.visible = true


func _walk_to_warehouse(delta_seconds: float, context: CharacterAiContext, character: Character) -> bool:
	var warehouse := _warehouse(context)
	var site := _site(context)
	if warehouse == null or site == null:
		return false
	character.visible = true
	if not character.advance_toward_world_x(delta_seconds, _world_x(warehouse)):
		return true
	var need := site.builder_logs_still_needed()
	var moved := warehouse.withdraw_logs(character.carried_items, need)
	if moved <= 0:
		_phase = _PHASE_TO_GUILD
		return true
	_phase = _PHASE_HAUL
	return true


func _haul(delta_seconds: float, context: CharacterAiContext, character: Character) -> bool:
	var site := _site(context)
	if site == null:
		return false
	character.visible = true
	if not character.advance_toward_world_x(delta_seconds, _world_x(site)):
		return true
	site.accept_builder_logs(character.carried_items)
	if character.carried_items.count_of(ItemConfig.TypeId.LOG) > 0:
		_phase = _PHASE_RETURN
		return true
	if site.builder_logs_ready():
		if site.builder_work_units_required() <= 0:
			site.add_work_unit()
			_phase = _PHASE_BACK
			return true
		_phase = _PHASE_BUILD
		_elapsed_seconds = 0.0
		_knocks = 0
		_pace_far = true
		return true
	_phase = _PHASE_BACK
	return true


func _return_surplus(delta_seconds: float, context: CharacterAiContext, character: Character) -> bool:
	var warehouse := _warehouse(context)
	if warehouse == null:
		return false
	character.visible = true
	if not character.advance_toward_world_x(delta_seconds, _world_x(warehouse)):
		return true
	var carried := character.carried_items.count_of(ItemConfig.TypeId.LOG)
	if carried > 0:
		character.carried_items.take(ItemConfig.TypeId.LOG, carried)
		warehouse.restore_logs(carried)
	var site := _site(context)
	if site != null and site.builder_logs_ready():
		_phase = _PHASE_TO_SITE
		_pace_far = true
		return true
	_phase = _PHASE_BACK
	return true


func _build(delta_seconds: float, context: CharacterAiContext, character: Character) -> bool:
	var site := _site(context)
	if site == null or not site.builder_logs_ready():
		_reset_pose(character)
		_phase = _PHASE_BACK
		return true
	_elapsed_seconds += delta_seconds
	var target := _pace_x(character, site)
	if character.advance_toward_world_x(delta_seconds, target):
		_pace_far = not _pace_far
	_pose(character)
	var knocks := int(_elapsed_seconds / 0.5)
	if knocks != _knocks:
		_knocks = knocks
		site.play_knock()
	if _elapsed_seconds >= Structure.WORK_UNIT_SECONDS:
		_reset_pose(character)
		site.add_work_unit()
		_phase = _PHASE_BACK
		_elapsed_seconds = 0.0
	return true


func _pose(character: Character) -> void:
	var sprite := character.get_node_or_null(^"Sprite2D") as Sprite2D
	if sprite == null:
		return
	var strike := sin(_elapsed_seconds * TAU * 2.5) > 0.2
	sprite.rotation = -0.6 if strike else 0.15
	sprite.position.y = 1.0 if strike else 0.0
	sprite.scale = Vector2(-_side(character), 1.0)


func _reset_pose(character: Character) -> void:
	var sprite := character.get_node_or_null(^"Sprite2D") as Sprite2D
	if sprite == null:
		return
	sprite.rotation = 0.0
	sprite.position = Vector2.ZERO
	sprite.scale = Vector2.ONE


func _serialize_payload() -> Dictionary:
	return {
		KEY_PHASE: _phase,
		KEY_ELAPSED_SECONDS: _elapsed_seconds,
		KEY_SITE_ID: _site_id,
		KEY_WAREHOUSE_ID: _warehouse_id,
		KEY_GUILD_ID: _guild_id,
		KEY_WAIT_KIND: _wait_kind,
		KEY_PACE_FAR: _pace_far,
		KEY_KNOCKS: _knocks,
	}


func _guild(context: CharacterAiContext) -> BuildersGuild:
	var structure_id := _guild_id if _guild_id != 0 else context.character.workplace_structure_id()
	return context.structure_manager().get_structure_by_id(structure_id) as BuildersGuild


func _warehouse(context: CharacterAiContext) -> Warehouse:
	return context.structure_manager().get_structure_by_id(_warehouse_id) as Warehouse


func _site(context: CharacterAiContext) -> Structure:
	var structure := context.structure_manager().get_structure_by_id(_site_id)
	if structure == null or not structure.builder_job_active():
		return null
	return structure


func _pick_site(context: CharacterAiContext, guild: BuildersGuild) -> Structure:
	var nearest: Structure
	var nearest_distance := 0
	for structure in context.structure_manager().structures.values():
		var site := structure as Structure
		if site == null or not site.builder_job_active():
			continue
		var distance := absi(site.cell_index - guild.cell_index)
		if nearest == null or distance < nearest_distance or (distance == nearest_distance and site.id < nearest.id):
			nearest = site
			nearest_distance = distance
	return nearest


func _nearest_warehouse(context: CharacterAiContext, site: Structure) -> Warehouse:
	return Warehouse.nearest(
		context.structure_manager(),
		site.cell_index,
		ItemConfig.TypeId.LOG,
		false,
		true,
		true,
	)


func _pace_x(character: Character, site: Structure) -> float:
	var side := _side(character)
	var reach := 12.0 if _pace_far else 5.0
	return _clamp_x(_world_x(site) + side * reach)


func _side(character: Character) -> float:
	return -1.0 if character.id % 2 == 0 else 1.0


func _world_x(structure: Structure) -> float:
	return _clamp_x(Game.get_position_by_cell_index(structure.cell_index) + Game.HALF_TILE_SIZE)


func _clamp_x(world_x: float) -> float:
	var map_min := float(Game.get_position_by_cell_index(0) + Game.HALF_TILE_SIZE)
	var map_max := float(Game.get_position_by_cell_index(Game.MAP_CELL_COUNT - 1) + Game.HALF_TILE_SIZE)
	return clampf(world_x, map_min, map_max)
