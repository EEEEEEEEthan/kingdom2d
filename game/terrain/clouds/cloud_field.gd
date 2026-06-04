@tool
extends Node2D

@export var field_size: Vector2
@export var cloud_count: int

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# 生成cloud, 均匀分布在0-fileld_size的坐标上
	pass

func _process(delta: float) -> void:
	pass
	# 所有的云按照固定速度向右移动(定义速度区间)
	# 坐标超出field_width的云瞬移到0位置重新移动
