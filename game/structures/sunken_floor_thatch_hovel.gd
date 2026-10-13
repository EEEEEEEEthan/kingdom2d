extends Structure
class_name SunkenFloorThatchHovel

## 半穴茅舍升成木架茅屋。20 原木到齐才搭脚手架，之后每 10 秒记 1 个建造单元，满 3 个就升级。
## 单元按人累加，多名建筑工可以同时干同一座。
## 初始从 0 级放下走基类修建（免费即时完工）；本类字段只管升木架。

const LOG_COST := 20
const WORK_UNITS_REQUIRED := 3
const _KEY_ORDERED := 1
const _KEY_WORK_UNITS := 2
const _KEY_LOGS_INBOUND := 3

var upgrade_ordered := false
var work_units := 0
var logs_inbound := 0


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
	if not is_built():
		return
	upgrade_ordered = true
	sync_scaffold()


func _cottage_job_active() -> bool:
	return upgrade_ordered and config.id == StructureConfig.TypeId.SUNKEN_FLOOR_THATCH_HOVEL and is_built()


func builder_job_active() -> bool:
	return super.builder_job_active() or _cottage_job_active()


func builder_log_cost() -> int:
	if is_under_construction():
		return super.builder_log_cost()
	return LOG_COST


func builder_work_units_required() -> int:
	if is_under_construction():
		return super.builder_work_units_required()
	return WORK_UNITS_REQUIRED


func builder_work_units() -> int:
	if is_under_construction():
		return super.builder_work_units()
	return work_units


func builder_logs_ready() -> bool:
	if is_under_construction():
		return super.builder_logs_ready()
	return logs_ready()


func builder_logs_still_needed() -> int:
	if is_under_construction():
		return super.builder_logs_still_needed()
	return logs_still_needed()


func reserve_logs(amount: int) -> void:
	if is_under_construction():
		super.reserve_logs(amount)
		return
	if amount <= 0:
		return
	logs_inbound += amount


func release_logs(amount: int) -> void:
	if is_under_construction():
		super.release_logs(amount)
		return
	logs_inbound = maxi(0, logs_inbound - amount)


func _add_builder_work_unit() -> void:
	if is_under_construction():
		super._add_builder_work_unit()
		return
	work_units += 1


func _finish_builder_job() -> void:
	if is_under_construction():
		super._finish_builder_job()
		return
	finish_upgrade()


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
