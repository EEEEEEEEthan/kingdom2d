extends Structure
class_name SunkenFloorThatchHovel

## 半穴茅舍升成木架茅屋。20 原木到齐才搭脚手架，之后每 10 秒记 1 个建造单元，满 3 个就升级。
## 单元按人累加，多名建筑工可以同时干同一座。

const LOG_COST := 20
const WORK_UNITS_REQUIRED := 3
const WORK_UNIT_SECONDS := 10.0
const _KEY_ORDERED := 1
const _KEY_WORK_UNITS := 2
const _KEY_LOGS_INBOUND := 3

var upgrade_ordered := false
var work_units := 0
var logs_inbound := 0

var _scaffold: Node2D
var _knock_tween: Tween


func _serialize() -> Dictionary:
	if config != null and config.id != StructureConfig.TypeId.SUNKEN_FLOOR_THATCH_HOVEL:
		return {}
	return {
		_KEY_ORDERED: upgrade_ordered,
		_KEY_WORK_UNITS: work_units,
		_KEY_LOGS_INBOUND: logs_inbound,
	}


func _deserialize(data: Dictionary) -> void:
	upgrade_ordered = bool(data.get(_KEY_ORDERED, false))
	work_units = int(data.get(_KEY_WORK_UNITS, 0))
	logs_inbound = int(data.get(_KEY_LOGS_INBOUND, 0))
	sync_scaffold()


func _ready() -> void:
	super._ready()
	if Engine.is_editor_hint():
		return
	_scaffold = ScaffoldMark.new()
	_scaffold.name = "Scaffold"
	_scaffold.z_index = 2
	_scaffold.visible = false
	add_child(_scaffold)
	sync_scaffold()


func log_count() -> int:
	return container.count_of(ItemConfig.TypeId.LOG)


func logs_ready() -> bool:
	return log_count() >= LOG_COST


func logs_still_needed() -> int:
	if not upgrade_ordered or logs_ready():
		return 0
	return maxi(0, LOG_COST - log_count() - logs_inbound)


func order_upgrade() -> void:
	if config.id != StructureConfig.TypeId.SUNKEN_FLOOR_THATCH_HOVEL:
		return
	upgrade_ordered = true
	sync_scaffold()


func reserve_logs(amount: int) -> void:
	if amount <= 0:
		return
	logs_inbound += amount


func release_logs(amount: int) -> void:
	logs_inbound = maxi(0, logs_inbound - amount)


func sync_scaffold() -> void:
	if _scaffold == null:
		return
	_scaffold.visible = upgrade_ordered and logs_ready() and config.id == StructureConfig.TypeId.SUNKEN_FLOOR_THATCH_HOVEL
	if _scaffold.visible:
		_scaffold.queue_redraw()


func add_work_unit() -> void:
	if config.id != StructureConfig.TypeId.SUNKEN_FLOOR_THATCH_HOVEL:
		return
	if not upgrade_ordered or not logs_ready():
		return
	work_units += 1
	if work_units >= WORK_UNITS_REQUIRED:
		finish_upgrade()


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


func finish_upgrade() -> void:
	if config.id != StructureConfig.TypeId.SUNKEN_FLOOR_THATCH_HOVEL:
		return
	container.take(ItemConfig.TypeId.LOG, LOG_COST)
	upgrade_ordered = false
	work_units = 0
	logs_inbound = 0
	if _knock_tween and _knock_tween.is_valid():
		_knock_tween.kill()
	rotation = 0.0
	sync_scaffold()
	var game := Game.find(self)
	if game:
		game.structure_manager.retarget_config(self, StructureConfig.timber_frame_cottage)
	_apply_cottage_look()
	if game:
		game.save_game()


func _apply_cottage_look() -> void:
	var preview := (load("res://game/structures/timber_frame_cottage.tscn") as PackedScene).instantiate()
	var cottage_sprite := preview.get_node("Sprite2D") as Sprite2D
	var sprite := get_node("Sprite2D") as Sprite2D
	sprite.texture = cottage_sprite.texture
	sprite.offset = cottage_sprite.offset
	cottage_sprite.texture = null
	preview.free()


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
