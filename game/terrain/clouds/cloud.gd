@tool
extends Node2D

@export var count: int = 48:
	set(value):
		count = maxi(value, 0)
		if not is_node_ready():
			await ready
		%MultiMeshInstance2D.instance_count = count
