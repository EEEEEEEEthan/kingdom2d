@tool
extends MultiMeshInstance2D

const FRAME_COLUMNS := 4
const FRAME_ROWS := 8
const FRAME_SIZE := Vector2(16.0, 8.0)

const SPRITES_PER_MASS_MIN := 5
const SPRITES_PER_MASS_MAX := 14

@export var area_size := Vector2(720.0, 100.0):
	set(value):
		area_size = value
		if not is_node_ready(): await ready
		_rebuild()
		
@export var cluster_radius := Vector2(36.0, 18.0):
	set(value):
		cluster_radius = value
		if not is_node_ready(): await ready
		_rebuild()

@export var instance_count: int:
	set(value):
		instance_count = value
		if not is_node_ready(): await ready
		_rebuild()

func _rebuild() -> void:
	if not is_node_ready():
		await ready
	var target_count := instance_count
	multimesh.instance_count = 0
	_ensure_multimesh_format()
	multimesh.instance_count = target_count
	if target_count == 0:
		return

	var random := RandomNumberGenerator.new()
	random.randomize()
	var positions := _build_clustered_positions(instance_count, random)

	for index in instance_count:
		var row := random.randi_range(0, FRAME_ROWS - 1)
		var start_frame := random.randf_range(0.0, float(FRAME_COLUMNS))
		var speed_normalized := random.randf()

		multimesh.set_instance_transform_2d(
			index,
			Transform2D(0.0, Vector2.ONE, 0.0, positions[index]),
		)
		multimesh.set_instance_color(
			index,
			Color(
				float(row) / float(FRAME_ROWS - 1),
				start_frame / float(FRAME_COLUMNS),
				speed_normalized,
				random.randf_range(0.82, 1.0),
			),
		)


func _build_clustered_positions(instance_count: int, random: RandomNumberGenerator) -> PackedVector2Array:
	var positions := PackedVector2Array()
	positions.resize(instance_count)
	var index := 0
	while index < instance_count:
		var mass_center := Vector2(
			random.randf_range(-area_size.x * 0.5, area_size.x * 0.5),
			random.randf_range(-area_size.y * 0.5, area_size.y * 0.5),
		)
		var sprites_in_mass := mini(
			random.randi_range(SPRITES_PER_MASS_MIN, SPRITES_PER_MASS_MAX),
			instance_count - index,
		)
		for _sprite in sprites_in_mass:
			positions[index] = mass_center + _sample_cluster_offset(random)
			index += 1
	return positions


func _sample_cluster_offset(random: RandomNumberGenerator) -> Vector2:
	var direction := Vector2.from_angle(random.randf() * TAU)
	var radius := random.randf() * random.randf()
	return direction * radius * cluster_radius


func _ensure_multimesh_format() -> void:
	multimesh.transform_format = MultiMesh.TRANSFORM_2D
	multimesh.use_custom_data = false
	multimesh.use_colors = true
	var quad_mesh := multimesh.mesh as QuadMesh
	if quad_mesh:
		quad_mesh.size = FRAME_SIZE
