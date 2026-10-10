extends RefCounted
class_name LogisticsUnit

## 一次工作单元：伐木、从仓库取一份、或带一份材料去敲建筑。
## 完成或失败返回前，调用方不应把它从栈上拿掉。

enum Kind { LUMBER, FETCH, BUILD }
enum Phase {
	TO_CAMP,
	CHOP,
	TO_DROP,
	BACK_CAMP,
	TO_SOURCE,
	TAKE,
	TO_GUILD,
	PUT,
	BACK_SOURCE,
	TO_SITE,
	HAMMER,
	DONE,
}

const ITEM_WOOD := 1
const CHOP_SECONDS := 2.0
const HAMMER_SECONDS := 2.0

const _KEY_KIND = 1
const _KEY_PHASE = 2
const _KEY_TIMER = 3
const _KEY_CARRIED = 4
const _KEY_ORIGIN_ID = 5
const _KEY_TARGET_ID = 6
const _KEY_DROP_ID = 7

var kind: Kind = Kind.LUMBER
var phase: Phase = Phase.TO_CAMP
var timer: float = 0.0
var carried: int = 0
var origin_id: int = 0
var target_id: int = 0
var drop_id: int = 0

var find_site: Callable
var list_warehouses: Callable


static func lumber(camp_id: int) -> LogisticsUnit:
	var unit := LogisticsUnit.new()
	unit.kind = Kind.LUMBER
	unit.phase = Phase.TO_CAMP
	unit.origin_id = camp_id
	return unit


static func fetch(guild_id: int, source_id: int) -> LogisticsUnit:
	var unit := LogisticsUnit.new()
	unit.kind = Kind.FETCH
	unit.phase = Phase.TO_SOURCE
	unit.origin_id = guild_id
	unit.target_id = source_id
	return unit


static func build(guild_id: int, site_id: int) -> LogisticsUnit:
	var unit := LogisticsUnit.new()
	unit.kind = Kind.BUILD
	unit.phase = Phase.TO_GUILD
	unit.origin_id = guild_id
	unit.target_id = site_id
	return unit


func to_payload() -> Dictionary:
	return {
		_KEY_KIND: kind,
		_KEY_PHASE: phase,
		_KEY_TIMER: timer,
		_KEY_CARRIED: carried,
		_KEY_ORIGIN_ID: origin_id,
		_KEY_TARGET_ID: target_id,
		_KEY_DROP_ID: drop_id,
	}


static func from_payload(data: Dictionary) -> LogisticsUnit:
	var unit := LogisticsUnit.new()
	unit.kind = data[_KEY_KIND] as Kind
	unit.phase = data.get(_KEY_PHASE, Phase.DONE) as Phase
	unit.timer = float(data.get(_KEY_TIMER, 0.0))
	unit.carried = int(data.get(_KEY_CARRIED, 0))
	unit.origin_id = int(data.get(_KEY_ORIGIN_ID, 0))
	unit.target_id = int(data.get(_KEY_TARGET_ID, 0))
	unit.drop_id = int(data.get(_KEY_DROP_ID, 0))
	return unit


func tick(delta_seconds: float, mover: Object) -> bool:
	if phase == Phase.DONE:
		return true
	match phase:
		Phase.TO_CAMP:
			if _move_to_site(delta_seconds, mover, origin_id):
				phase = Phase.CHOP
				timer = 0.0
		Phase.CHOP:
			timer += delta_seconds
			if timer >= CHOP_SECONDS:
				# 伐木不消耗树，到岗砍满一个单元就产出一份原木。
				carried = 1
				var drop = _nearest_dropoff(_site(origin_id))
				if drop == null:
					phase = Phase.BACK_CAMP
				else:
					drop_id = drop.id
					phase = Phase.TO_DROP
		Phase.TO_DROP:
			if _move_to_site(delta_seconds, mover, drop_id):
				var drop = _site(drop_id)
				if drop and drop.stock and drop.stock.try_receive(ITEM_WOOD, 1):
					carried = 0
					phase = Phase.DONE
				else:
					phase = Phase.BACK_CAMP
		Phase.BACK_CAMP:
			if _move_to_site(delta_seconds, mover, origin_id):
				_overflow_to(origin_id)
				phase = Phase.DONE
		Phase.TO_SOURCE:
			if _move_to_site(delta_seconds, mover, target_id):
				phase = Phase.TAKE
		Phase.TAKE:
			var source = _site(target_id if kind == Kind.FETCH else origin_id)
			if source and source.stock and source.stock.try_take(ITEM_WOOD, 1):
				carried = 1
				phase = Phase.TO_SITE if kind == Kind.BUILD else Phase.TO_GUILD
			else:
				phase = Phase.DONE
		Phase.TO_GUILD:
			if _move_to_site(delta_seconds, mover, origin_id):
				phase = Phase.TAKE if kind == Kind.BUILD and carried == 0 else Phase.PUT
		Phase.PUT:
			var guild = _site(origin_id)
			if guild and guild.stock and guild.stock.try_store(ITEM_WOOD, 1):
				carried = 0
				phase = Phase.DONE
			else:
				phase = Phase.BACK_SOURCE
		Phase.BACK_SOURCE:
			if _move_to_site(delta_seconds, mover, target_id):
				_overflow_to(target_id)
				phase = Phase.DONE
		Phase.TO_SITE:
			if _move_to_site(delta_seconds, mover, target_id):
				phase = Phase.HAMMER
				timer = 0.0
		Phase.HAMMER:
			timer += delta_seconds
			if timer >= HAMMER_SECONDS:
				var site = _site(target_id)
				if site and int(site.material_remaining) > 0:
					site.receive_one()
					carried = 0
					phase = Phase.DONE
				else:
					# 工地已经不收这份材料，带回工会并允许爆仓放回。
					target_id = origin_id
					phase = Phase.BACK_SOURCE
	return phase == Phase.DONE


func refund() -> void:
	if carried <= 0:
		return
	_overflow_to(origin_id)
	if carried > 0:
		_overflow_to(target_id)


func _overflow_to(site_id: int) -> void:
	if carried <= 0:
		return
	var site = _site(site_id)
	if site and site.stock:
		site.stock.put_overflow(ITEM_WOOD, carried)
		carried = 0


func _site(site_id: int):
	if not find_site.is_valid():
		return null
	return find_site.call(site_id)


func _move_to_site(delta_seconds: float, mover: Object, site_id: int) -> bool:
	var site = _site(site_id)
	if site == null:
		return true
	var target_x := float(site.cell_index) * float(Game.TILE_SIZE) + float(Game.HALF_TILE_SIZE)
	var offset: float = target_x - float(mover.x)
	var step: float = float(mover.speed) * delta_seconds
	if absf(offset) <= step:
		mover.x = target_x
		return true
	mover.x = float(mover.x) + signf(offset) * step
	return false


func _nearest_dropoff(origin):
	if origin == null or not list_warehouses.is_valid():
		return null
	var best = null
	var best_distance := 1 << 30
	for warehouse in list_warehouses.call():
		if warehouse == null or warehouse.stock == null:
			continue
		if warehouse.kind != WorkSite.Kind.WAREHOUSE:
			continue
		if not warehouse.stock.can_receive(ITEM_WOOD, 1):
			continue
		var distance := absi(int(warehouse.cell_index) - int(origin.cell_index))
		if distance < best_distance:
			best = warehouse
			best_distance = distance
	return best


static func nearest_fetch_source(origin_cell: int, warehouses: Array):
	var best = null
	var best_distance := 1 << 30
	for warehouse in warehouses:
		if warehouse == null or warehouse.stock == null:
			continue
		if warehouse.kind != WorkSite.Kind.WAREHOUSE:
			continue
		var item_policy: Stockpile.Policy = warehouse.stock.policy(ITEM_WOOD)
		if item_policy != Stockpile.Policy.ACCEPT and item_policy != Stockpile.Policy.CLEAR:
			continue
		if warehouse.stock.amount(ITEM_WOOD) < 1:
			continue
		var distance := absi(int(warehouse.cell_index) - origin_cell)
		if distance < best_distance:
			best = warehouse
			best_distance = distance
	return best
