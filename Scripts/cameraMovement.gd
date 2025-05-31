extends Camera2D

@export var scroll_speed: float = 200.0
@export var border_threshold: int = 10

func _process(delta):
	var viewport_size = get_viewport_rect().size
	var mouse_pos = get_viewport().get_mouse_position()
	
	var movement = Vector2.ZERO
	
	# Bewegung nach links/rechts
	if mouse_pos.x < border_threshold:
		movement.x -= scroll_speed * delta
	elif mouse_pos.x > viewport_size.x - border_threshold:
		movement.x += scroll_speed * delta
	
	# Bewegung nach oben/unten
	if mouse_pos.y < border_threshold:
		movement.y -= scroll_speed * delta
	elif mouse_pos.y > viewport_size.y - border_threshold:
		movement.y += scroll_speed * delta
	
	# Kamera bewegen
	position += movement
