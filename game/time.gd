extends Node
class_name GameTime

const _DAYS_PER_MONTH = 7
const _MONTHS_PER_YEAR = 12
const _DAYS_PER_YEAR = _MONTHS_PER_YEAR * _DAYS_PER_MONTH
const _GAME_TIME_SCALE = 24.0  # 现实1小时是游戏的24小时
const REAL_SECONDS_TO_GAME_DAYS = _GAME_TIME_SCALE / 60.0 / 60.0 / 24.0

enum Seasons{
	SPRING,
	SUMMER,
	AUTUMN,
	WINTER,
}

var all_days

var year: int:
	get:
		return int(all_days / _DAYS_PER_YEAR) + 1

var month: int:
	get:
		var days = all_days - (year - 1) * _DAYS_PER_YEAR
		return int(days / _DAYS_PER_MONTH) + 1

var day: int:
	get:
		return int(all_days) % _DAYS_PER_MONTH + 1

var season: Seasons:
	get:
		match month:
			1: return Seasons.WINTER
			2: return Seasons.SPRING
			3: return Seasons.SPRING
			4: return Seasons.SPRING
			5: return Seasons.SUMMER
			6: return Seasons.SUMMER
			7: return Seasons.SUMMER
			8: return Seasons.AUTUMN
			9: return Seasons.AUTUMN
			10: return Seasons.AUTUMN
			11: return Seasons.WINTER
			12: return Seasons.WINTER
		printerr("unexpected month %s" %month)
		return  Seasons.SPRING

func _init(days: float = 0.0) -> void:
	all_days = days
