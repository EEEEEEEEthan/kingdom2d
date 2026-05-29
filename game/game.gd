extends Window


func _ready() -> void:
	%ColorRect.resized.connect(_sync_mouse_passthrough_polygon)
	_sync_mouse_passthrough_polygon()


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_VISIBILITY_CHANGED:
			if visible:
				_sync_mouse_passthrough_polygon()
		NOTIFICATION_WM_SIZE_CHANGED:
			_sync_mouse_passthrough_polygon()


func _sync_mouse_passthrough_polygon() -> void:
	var hit_rect: Rect2 = %ColorRect.get_global_rect()
	mouse_passthrough_polygon = PackedVector2Array([
		hit_rect.position,
		hit_rect.position + Vector2(hit_rect.size.x, 0.0),
		hit_rect.position + hit_rect.size,
		hit_rect.position + Vector2(0.0, hit_rect.size.y),
	])
