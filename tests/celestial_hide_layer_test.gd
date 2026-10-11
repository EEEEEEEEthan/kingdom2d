extends SceneTree

func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var game = (load("res://game/game.tscn") as PackedScene).instantiate()
	root.add_child(game)
	await process_frame
	var terrain: Terrain = game.terrain
	var cloud_y_at := func(height: float) -> float:
		return terrain.layer_drop_y(terrain._sprites.size(), height)
	game.view_height = 1.0
	await process_frame
	if not is_equal_approx(game.get_node("%CelestialLayer").offset.y, 0.0):
		push_error("完全展开时天体应在原位")
		quit(1)
		return
	game.view_height = 0.5
	await process_frame
	var celestial_y: float = game.get_node("%CelestialLayer").offset.y
	var cloud_y: float = cloud_y_at.call(0.5)
	if not is_equal_approx(celestial_y, terrain.celestial_drop_y(0.5)):
		push_error("天体下移应走最远一层")
		quit(1)
		return
	if celestial_y <= cloud_y:
		push_error("半隐藏时天体应比最远云更低")
		quit(1)
		return
	game.view_height = 0.0
	await process_frame
	if game.get_node("%CelestialLayer").offset.y <= cloud_y_at.call(0.0):
		push_error("完全隐藏时天体仍应在最远云之后")
		quit(1)
		return
	print("celestial_hide_layer_ok")
	quit(0)
