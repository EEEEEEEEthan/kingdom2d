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

enum DayTimePeriod {
	MORNING_MARKET,
	WORK,
	REST,
	SLEEP,
}

enum MoonPhase {
	NEW,
	WAXING_CRESCENT,
	FIRST_QUARTER,
	WAXING_GIBBOUS,
	FULL,
	WANING_GIBBOUS,
	LAST_QUARTER,
	WANING_CRESCENT,
}

const MOON_PHASE_COUNT := 8

const _HOUR_MORNING_MARKET_START = 6
const _HOUR_WORK_START = 7
const _HOUR_REST_START = 19
const _HOUR_SLEEP_START = 22

var all_days

var day_fraction: float:
	get:
		var fraction := fmod(all_days, 1.0)
		if fraction < 0.0:
			fraction += 1.0
		return fraction

var moon_phase: MoonPhase:
	get:
		var phase_index := int(fmod(all_days, _DAYS_PER_MONTH) / _DAYS_PER_MONTH * MOON_PHASE_COUNT)
		return (phase_index % MOON_PHASE_COUNT) as MoonPhase

var hour_of_day: int:
	get:
		return mini(int(day_fraction * 24.0), 23)

var day_time_period: DayTimePeriod:
	get:
		return get_day_time_period_for_hour(hour_of_day)

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

static func get_day_time_period_for_hour(hour_of_day: int) -> DayTimePeriod:
	if hour_of_day >= _HOUR_MORNING_MARKET_START and hour_of_day < _HOUR_WORK_START:
		return DayTimePeriod.MORNING_MARKET
	if hour_of_day >= _HOUR_WORK_START and hour_of_day < _HOUR_REST_START:
		return DayTimePeriod.WORK
	if hour_of_day >= _HOUR_REST_START and hour_of_day < _HOUR_SLEEP_START:
		return DayTimePeriod.REST
	return DayTimePeriod.SLEEP


func _init(days: float = 0.0) -> void:
	all_days = days
