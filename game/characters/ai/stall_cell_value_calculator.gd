extends RefCounted
class_name StallCellValueCalculator

## 分数 = (总格子数 - 距自己) + (总格子数 - 距气质/王权旌旗)
static func compute_score(cell_index: int, self_cell_index: int, aura_cell_index: int) -> int:
	var cell_count := Game.MAP_CELL_COUNT
	return (cell_count - absi(cell_index - self_cell_index)) + (cell_count - absi(cell_index - aura_cell_index))
