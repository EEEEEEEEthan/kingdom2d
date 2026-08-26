@tool
extends Node2D
class_name Cloud

const MULTIMESH_SCRIPT := preload("res://game/terrain/clouds/cloud_multimesh.gd")
const CLOUD_TEXTURE := preload("res://game/terrain/clouds/cloud_spritesheet.png")

var _multimesh_view: MultiMeshInstance2D

@export var count: int = 32:
	set(value):
		count = maxi(value, 0)
		if not is_node_ready():
			await ready
		_ensure_multimesh_view().instance_count = count

@export var multimesh_position := Vector2(0, 0):
	set(value):
		multimesh_position = value
		if not is_node_ready():
			await ready
		_ensure_multimesh_view().position = multimesh_position

@export var area_size := Vector2(128, 8):
	set(value):
		area_size = value
		if not is_node_ready():
			await ready
		_ensure_multimesh_view().area_size = area_size

@export var cluster_radius := Vector2(64, 8):
	set(value):
		cluster_radius = value
		if not is_node_ready():
			await ready
		_ensure_multimesh_view().cluster_radius = cluster_radius


func _ensure_multimesh_view() -> MultiMeshInstance2D:
	if _multimesh_view == null or not is_instance_valid(_multimesh_view):
		_multimesh_view = _get_or_create_multimesh_node()
	return _multimesh_view


func _ready() -> void:
	_multimesh_view = _get_or_create_multimesh_node()
	_multimesh_view.configure(count, multimesh_position, area_size, cluster_radius)


func _get_or_create_multimesh_node() -> MultiMeshInstance2D:
	var existing := get_node_or_null("MultiMeshInstance2D") as MultiMeshInstance2D
	if existing:
		return existing

	var multimesh_node := MultiMeshInstance2D.new()
	multimesh_node.name = &"MultiMeshInstance2D"
	multimesh_node.use_parent_material = true
	multimesh_node.texture = CLOUD_TEXTURE
	multimesh_node.set_script(MULTIMESH_SCRIPT)
	add_child(multimesh_node)
	if Engine.is_editor_hint():
		multimesh_node.owner = null
	return multimesh_node
