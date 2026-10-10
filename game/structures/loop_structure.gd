extends Structure
class_name LoopStructure

enum Kind { WAREHOUSE, TENT, LUMBER, GUILD, HUT }

const HUT_LOGS := 3
const WAREHOUSE_UPGRADE_COST := 4

const _KEY_LOGS := 1
const _KEY_LEVEL := 2
const _KEY_APPLIED := 3
const _KEY_IN_FLIGHT := 4

@export var kind: Kind = Kind.WAREHOUSE
var logs := 0
var level := 1
var applied := 0
var in_flight := 0


func _serialize() -> Dictionary:
	return {
		_KEY_LOGS: logs,
		_KEY_LEVEL: level,
		_KEY_APPLIED: applied,
		_KEY_IN_FLIGHT: in_flight,
	}


func _deserialize(data: Dictionary) -> void:
	logs = data.get(_KEY_LOGS, 0)
	level = data.get(_KEY_LEVEL, 1)
	applied = data.get(_KEY_APPLIED, 0)
	in_flight = data.get(_KEY_IN_FLIGHT, 0)


func capacity() -> int:
	return 8 * level


func can_accept_log() -> bool:
	return kind == Kind.WAREHOUSE and logs < capacity()


func needs_hut_log() -> bool:
	return kind == Kind.TENT and applied + in_flight < HUT_LOGS


func on_placed(game: Game) -> void:
	if kind != Kind.TENT:
		return
	var resident := game.character_manager.create_character()
	resident.position = position
	resident.home_id = id


func inspect_text() -> String:
	match kind:
		Kind.WAREHOUSE:
			return "原木 %d/%d\n等级 %d\n可升级，不可拆除" % [logs, capacity(), level]
		Kind.TENT:
			return "免费建造\n升级进度 %d/%d" % [applied, HUT_LOGS]
		Kind.LUMBER:
			return "1 级免费\n场内原木 %d\n到岗才伐木\n升级消耗原木" % logs
		Kind.GUILD:
			return "免费建造\n待运原木 %d\n升级以后再定" % logs
		Kind.HUT:
			return "小木屋"
	return ""
