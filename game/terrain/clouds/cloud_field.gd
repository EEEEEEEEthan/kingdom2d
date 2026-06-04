@tool
extends Node2D

const SCROLL_SPEED_META := &"scroll_speed"

@export var field_size := Vector2(720.0, 100.0):
	set(value):
		field_size = value
		if is_node_ready():
			_rebuild_clouds()

@export var cloud_count := 4:
	set(value):
		cloud_count = maxi(value, 0)
		if is_node_ready():
			_rebuild_clouds()

@export var scroll_speed_range := Vector2(8.0, 16.0)


func _ready() -> void:
	_rebuild_clouds()


func _process(delta: float) -> void:
	var field_width := field_size.x
	for child in get_children():
		if child is InstancePlaceholder:
			continue
		var cloud := child as Node2D
		cloud.position.x += cloud.get_meta(SCROLL_SPEED_META) * delta
		if cloud.position.x >= field_width:
			cloud.position.x -= field_width

func _rebuild_clouds() -> void:
	_clear_spawned_clouds()
	if cloud_count == 0:
		return

	var random := RandomNumberGenerator.new()
	random.randomize()
	var speed_minimum := minf(scroll_speed_range.x, scroll_speed_range.y)
	var speed_maximum := maxf(scroll_speed_range.x, scroll_speed_range.y)

	for index in cloud_count:
		var cloud := Cloud.new()
		cloud.use_parent_material = true
		cloud.position = Vector2(
			(float(index) + random.randf()) / float(cloud_count) * field_size.x,
			random.randf_range(0.0, field_size.y),
		)
		cloud.set_meta(
			SCROLL_SPEED_META,
			random.randf_range(speed_minimum, speed_maximum),
		)
		add_child(cloud)


func _clear_spawned_clouds() -> void:
	for child in get_children():
		if child is InstancePlaceholder:
			continue
		remove_child(child)
		child.free()
