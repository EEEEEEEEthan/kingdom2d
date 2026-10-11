extends SceneTree

func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	load("res://game/game.gd")
	load("res://game/terrain/terrain.gd")
	var terrain = (load("res://game/terrain/terrain.tscn") as PackedScene).instantiate()
	root.add_child(terrain)
	await process_frame
	var cloud_y_at := func(height: float) -> float:
		return terrain.layer_drop_y(terrain._sprites.size(), height)
	var layer := CanvasLayer.new()
	root.add_child(layer)
	var apply := func(height: float) -> void:
		terrain.view_height = height
		layer.offset = Vector2(0, terrain.celestial_drop_y(height))
	apply.call(1.0)
	if not is_equal_approx(layer.offset.y, 0.0):
		push_error("完全展开时天体应在原位")
		quit(1)
		return
	if not is_equal_approx(terrain.get_node("%Cloud1").position.y, 0.0):
		push_error("完全展开时最远云应在原位")
		quit(1)
		return
	apply.call(0.5)
	var celestial_y: float = layer.offset.y
	var cloud_y: float = cloud_y_at.call(0.5)
	if not is_equal_approx(celestial_y, terrain.celestial_drop_y(0.5)):
		push_error("天体下移应走最远一层")
		quit(1)
		return
	if not is_equal_approx(terrain.get_node("%Cloud1").position.y, cloud_y):
		push_error("最远云下移与层序号不一致")
		quit(1)
		return
	if celestial_y <= cloud_y:
		push_error("半隐藏时天体应比最远云更低")
		quit(1)
		return
	apply.call(0.0)
	if layer.offset.y <= cloud_y_at.call(0.0):
		push_error("完全隐藏时天体仍应在最远云之后")
		quit(1)
		return
	print("celestial_hide_layer_ok")
	quit(0)
