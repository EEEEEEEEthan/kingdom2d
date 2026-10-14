extends Structure
class_name Dwelling

## 半穴茅舍和木架茅屋共用。升木架仍是建筑工工程；生活等级见 DwellingGrade。
## 升木架的原木不预留：多人可各搬一份，工地只留下还缺的，多的退回仓库。

const COTTAGE_LOG_COST := 20
const COTTAGE_WORK_UNITS := 3
const _KEY_ORDERED := 1
const _KEY_WORK_UNITS := 2

var upgrade_ordered := false
var work_units := 0
var _tier_mark: Node2D


func _ready() -> void:
	super._ready()
	_ensure_tier_mark()
	_sync_tier_mark()


func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		return
	maintain_grade()


func display_name() -> String:
	if level >= DwellingGrade.LEVEL_TIMBER:
		return "原木宅"
	return super.display_name()


func _serialize() -> Dictionary:
	if config != null and config.id != StructureConfig.TypeId.SUNKEN_FLOOR_THATCH_HOVEL:
		return {}
	return {
		_KEY_ORDERED: upgrade_ordered,
		_KEY_WORK_UNITS: work_units,
	}


func _deserialize(data: Dictionary) -> void:
	if config != null and config.id == StructureConfig.TypeId.TIMBER_FRAME_COTTAGE and level < DwellingGrade.LEVEL_COTTAGE:
		level = DwellingGrade.LEVEL_COTTAGE
	upgrade_ordered = bool(data.get(_KEY_ORDERED, false))
	work_units = int(data.get(_KEY_WORK_UNITS, 0))
	sync_scaffold()
	_sync_tier_mark()


func log_count() -> int:
	return container.count_of(ItemConfig.TypeId.LOG)


func logs_ready() -> bool:
	return log_count() >= COTTAGE_LOG_COST


func logs_still_needed() -> int:
	if not upgrade_ordered or logs_ready():
		return 0
	return maxi(0, COTTAGE_LOG_COST - log_count())


func order_upgrade() -> void:
	if config.id != StructureConfig.TypeId.SUNKEN_FLOOR_THATCH_HOVEL:
		return
	if not is_built():
		return
	upgrade_ordered = true
	sync_scaffold()


func cancel_upgrade() -> void:
	if not upgrade_ordered:
		return
	upgrade_ordered = false
	work_units = 0
	# 只退到可取料的仓（排除 REFUSE/未完工）；退不到就留在住房。
	var amount := log_count()
	if amount > 0:
		var game := Game.find(self)
		if game != null:
			var warehouse := Warehouse.nearest(
				game.structure_manager,
				cell_index,
				ItemConfig.TypeId.LOG,
				false,
				true,
			)
			if warehouse != null:
				container.take(ItemConfig.TypeId.LOG, amount)
				warehouse.restore_logs(amount)
	sync_scaffold()


func promote_timber() -> void:
	if not DwellingGrade.can_raise(self, DwellingGrade.LEVEL_TIMBER):
		return
	level = DwellingGrade.LEVEL_TIMBER
	_sync_tier_mark()
	_save()


func maintain_grade() -> void:
	if not is_inside_tree() or Engine.is_editor_hint() or config == null:
		return
	if is_under_construction() or not is_built():
		return
	var cap := DwellingGrade.sustainable_level(self)
	if upgrade_ordered and cap < DwellingGrade.LEVEL_COTTAGE:
		cancel_upgrade()
	if level > cap:
		_drop_to(cap)


func _cottage_job_active() -> bool:
	return upgrade_ordered and config.id == StructureConfig.TypeId.SUNKEN_FLOOR_THATCH_HOVEL and is_built()


func builder_job_active() -> bool:
	return super.builder_job_active() or _cottage_job_active()


func builder_log_cost() -> int:
	if _cottage_job_active():
		return COTTAGE_LOG_COST
	return super.builder_log_cost()


func builder_work_units_required() -> int:
	if _cottage_job_active():
		return COTTAGE_WORK_UNITS
	return super.builder_work_units_required()


func builder_work_units() -> int:
	if _cottage_job_active():
		return work_units
	return super.builder_work_units()


func builder_logs_ready() -> bool:
	if _cottage_job_active():
		return logs_ready()
	return super.builder_logs_ready()


func builder_logs_still_needed() -> int:
	if _cottage_job_active():
		return logs_still_needed()
	return super.builder_logs_still_needed()


func _add_builder_work_unit() -> void:
	if _cottage_job_active():
		work_units += 1
		return
	super._add_builder_work_unit()


func _finish_builder_job() -> void:
	if _cottage_job_active():
		finish_upgrade()
		return
	super._finish_builder_job()


func finish_upgrade() -> void:
	if config.id != StructureConfig.TypeId.SUNKEN_FLOOR_THATCH_HOVEL:
		return
	container.take(ItemConfig.TypeId.LOG, COTTAGE_LOG_COST)
	upgrade_ordered = false
	work_units = 0
	level = DwellingGrade.LEVEL_COTTAGE
	if _knock_tween and _knock_tween.is_valid():
		_knock_tween.kill()
	rotation = 0.0
	sync_scaffold()
	_apply_look(StructureConfig.timber_frame_cottage)
	_sync_tier_mark()
	_save()


func _drop_to(next: int) -> void:
	if level <= next:
		return
	level = next
	if next < DwellingGrade.LEVEL_COTTAGE and config.id != StructureConfig.TypeId.SUNKEN_FLOOR_THATCH_HOVEL:
		upgrade_ordered = false
		work_units = 0
		_apply_look(StructureConfig.sunken_floor_thatch_hovel)
		sync_scaffold()
	_sync_tier_mark()
	_save()


func _apply_look(next_config: StructureConfig) -> void:
	var preview := next_config.instantiate()
	var source := preview.get_node("Sprite2D") as Sprite2D
	var sprite := get_node("Sprite2D") as Sprite2D
	sprite.texture = source.texture
	sprite.offset = source.offset
	source.texture = null
	preview.free()
	var game := Game.find(self)
	if game != null and config != next_config:
		game.structure_manager.retarget_config(self, next_config)


func _save() -> void:
	var game := Game.find(self)
	if game:
		game.save_game()


func _ensure_tier_mark() -> void:
	if _tier_mark != null or not is_inside_tree():
		return
	_tier_mark = TierMark.new()
	_tier_mark.name = "TierMark"
	_tier_mark.z_index = 3
	_tier_mark.visible = false
	add_child(_tier_mark)


func _sync_tier_mark() -> void:
	_ensure_tier_mark()
	if _tier_mark == null:
		return
	_tier_mark.visible = level >= DwellingGrade.LEVEL_TIMBER
	if _tier_mark.visible:
		_tier_mark.queue_redraw()


class TierMark extends Node2D:
	func _draw() -> void:
		var stone := Color("9aa0a6")
		var dark := Color("2c3338")
		draw_rect(Rect2(-1, -16, 3, 6), dark)
		draw_rect(Rect2(-3, -18, 7, 3), stone)
