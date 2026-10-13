@tool
extends Node2D
class_name Structure

const _KEY_TYPE_ID = 1
const _KEY_INSTANCE_ID = 2
const _KEY_DATA = 3
const _KEY_CELL_INDEX = 4
const _KEY_HP = 5
const _KEY_CONTAINER = 6
const _LEGACY_REFUGEE_SHELTER = 7
const _KEY_LEVEL = 8
const _KEY_CONSTRUCTION = 9

const _CONSTRUCTION_ORDERED = 1
const _CONSTRUCTION_WORK_UNITS = 2
const _CONSTRUCTION_LOGS_INBOUND = 3

## 一个建造单元的秒数；初始修建与茅舍升级共用。
const WORK_UNIT_SECONDS := 10.0

var config: StructureConfig
var id: int
var container := ItemContainer.new()
## 可建造建筑放下时为 0，升级完工后为 1。植物/开局建筑默认 1。
var level := 1
var construction_ordered := false
var construction_work_units := 0
var construction_logs_inbound := 0
var _scaffold: Node2D
var _knock_tween: Tween
var cell_index: int:
	get:
		return cell_index
	set(value):
		cell_index = value
		if not is_node_ready(): await ready
		position = Vector2(value * Game.TILE_SIZE + Game.HALF_TILE_SIZE, 0)
		_on_cell_index_updated()

var active: bool:
	get:
		return id > 0

var hp: int
@export var show_outline := true:
	set(value):
		show_outline = value
		var outline := get_node_or_null(^"HoverOutline") as HoverOutline
		if outline:
			outline.show_outline = value

static func deserialize(data: Dictionary, parent: Node, save_version := 0) -> Structure:
	var raw_type := int(data[_KEY_TYPE_ID])
	if save_version < 1 and raw_type == _LEGACY_REFUGEE_SHELTER:
		raw_type = StructureConfig.TypeId.SUNKEN_FLOOR_THATCH_HOVEL
	var type_id := raw_type as StructureConfig.TypeId
	var structure_config = StructureConfig.configs_by_id.get(type_id)
	if not structure_config:
		printerr("type_id not found: %s" % type_id)
		return null
	var structure := structure_config.instantiate() as Structure
	parent.add_child(structure)
	structure.id = data[_KEY_INSTANCE_ID]
	structure.cell_index = data[_KEY_CELL_INDEX]
	structure.hp = data[_KEY_HP]
	structure.container = ItemContainer.deserialize(data.get(_KEY_CONTAINER, {}))
	structure.level = int(data.get(_KEY_LEVEL, 1))
	var construction: Dictionary = data.get(_KEY_CONSTRUCTION, {})
	structure.construction_ordered = bool(construction.get(_CONSTRUCTION_ORDERED, false))
	structure.construction_work_units = int(construction.get(_CONSTRUCTION_WORK_UNITS, 0))
	structure.construction_logs_inbound = int(construction.get(_CONSTRUCTION_LOGS_INBOUND, 0))
	structure._deserialize(data[_KEY_DATA])
	structure._ensure_scaffold()
	structure.sync_scaffold()
	structure._sync_built_visual()
	return structure

func _deserialize(_data: Dictionary) -> void:
	pass

func serialize() -> Dictionary:
	return {
		_KEY_TYPE_ID: int(config.id),
		_KEY_INSTANCE_ID: id,
		_KEY_DATA: _serialize(),
		_KEY_CELL_INDEX: cell_index,
		_KEY_HP: hp,
		_KEY_CONTAINER: container.serialize(),
		_KEY_LEVEL: level,
		_KEY_CONSTRUCTION: {
			_CONSTRUCTION_ORDERED: construction_ordered,
			_CONSTRUCTION_WORK_UNITS: construction_work_units,
			_CONSTRUCTION_LOGS_INBOUND: construction_logs_inbound,
		},
	}

func _serialize() -> Dictionary:
	return {}

func _ready() -> void:
	if Engine.is_editor_hint():
		return
	HoverOutline.attach(self)
	_ensure_scaffold()
	sync_scaffold()
	_sync_built_visual()


func is_built() -> bool:
	return level >= 1


func is_under_construction() -> bool:
	return construction_ordered and level < 1


## 玩家放下后调用：以 0 级进入升级；免费即时完工，有花费则等建筑工。
func begin_initial_upgrade() -> void:
	if not config.uses_construction:
		level = 1
		return
	level = 0
	construction_ordered = true
	construction_work_units = 0
	construction_logs_inbound = 0
	_ensure_scaffold()
	sync_scaffold()
	_sync_built_visual()
	if config.build_log_cost <= 0 and config.build_work_units <= 0:
		finish_construction()


func finish_construction() -> void:
	if not is_under_construction():
		return
	var cost := config.build_log_cost
	if cost > 0:
		container.take(ItemConfig.TypeId.LOG, cost)
	construction_ordered = false
	construction_work_units = 0
	construction_logs_inbound = 0
	level = 1
	if _knock_tween and _knock_tween.is_valid():
		_knock_tween.kill()
	rotation = 0.0
	sync_scaffold()
	_sync_built_visual()
	var game := Game.find(self)
	if game:
		if self is GathererHut or self is LumberCamp or self is BuildersGuild:
			game.rebalance_workplaces()
		game.save_game()
	_on_construction_finished()


func _on_construction_finished() -> void:
	pass


func builder_job_active() -> bool:
	return is_under_construction()


func builder_log_cost() -> int:
	return config.build_log_cost


func builder_work_units_required() -> int:
	return config.build_work_units


func builder_work_units() -> int:
	return construction_work_units


func builder_logs_ready() -> bool:
	return container.count_of(ItemConfig.TypeId.LOG) >= builder_log_cost()


func builder_logs_still_needed() -> int:
	if not builder_job_active() or builder_logs_ready():
		return 0
	return maxi(0, builder_log_cost() - container.count_of(ItemConfig.TypeId.LOG) - construction_logs_inbound)


func reserve_logs(amount: int) -> void:
	if amount <= 0:
		return
	construction_logs_inbound += amount


func release_logs(amount: int) -> void:
	construction_logs_inbound = maxi(0, construction_logs_inbound - amount)


func add_work_unit() -> void:
	if not builder_job_active() or not builder_logs_ready():
		return
	if builder_work_units_required() <= 0:
		_finish_builder_job()
		return
	_add_builder_work_unit()
	if builder_work_units() >= builder_work_units_required():
		_finish_builder_job()


func _add_builder_work_unit() -> void:
	construction_work_units += 1


func _finish_builder_job() -> void:
	finish_construction()


func play_knock() -> void:
	if not is_inside_tree():
		return
	if _knock_tween and _knock_tween.is_valid():
		_knock_tween.kill()
	rotation = 0.0
	_knock_tween = create_tween()
	_knock_tween.tween_property(self, "rotation", 0.05, 0.04)
	_knock_tween.tween_property(self, "rotation", -0.03, 0.05)
	_knock_tween.tween_property(self, "rotation", 0.0, 0.05)


func sync_scaffold() -> void:
	if _scaffold == null:
		return
	_scaffold.visible = builder_job_active() and builder_logs_ready()
	if _scaffold.visible:
		_scaffold.queue_redraw()


func _ensure_scaffold() -> void:
	if _scaffold != null:
		return
	_scaffold = ScaffoldMark.new()
	_scaffold.name = "Scaffold"
	_scaffold.z_index = 2
	_scaffold.visible = false
	add_child(_scaffold)


func _sync_built_visual() -> void:
	var sprite := get_node_or_null(^"Sprite2D") as CanvasItem
	if sprite:
		sprite.visible = is_built() or not config.uses_construction


func _on_cell_index_updated() -> void:
	pass


func play_bounce(on_finished: Callable = Callable()) -> void:
	%Juice.play_bounce(on_finished)


func play_shake() -> void:
	var tween := create_tween()
	for _step in 8:
		tween.tween_property(self, "rotation", 0.14, 0.08)
		tween.tween_property(self, "rotation", -0.14, 0.08)
	tween.tween_property(self, "rotation", 0.0, 0.08)


func stop_bounce() -> void:
	%Juice.stop_bounce()


class ScaffoldMark extends Node2D:
	func _draw() -> void:
		var wood := Color("c4854a")
		var dark := Color("6b3a22")
		draw_line(Vector2(-7, -2), Vector2(-7, -18), dark, 1.0)
		draw_line(Vector2(7, -2), Vector2(7, -18), dark, 1.0)
		draw_line(Vector2(-7, -7), Vector2(7, -7), wood, 1.0)
		draw_line(Vector2(-7, -12), Vector2(7, -12), wood, 1.0)
		draw_line(Vector2(-7, -17), Vector2(7, -17), wood, 1.0)
		draw_line(Vector2(-5, -18), Vector2(0, -22), dark, 1.0)
		draw_line(Vector2(5, -18), Vector2(0, -22), dark, 1.0)
