extends Node2D

@export var tile_size: int = 256
@export var max_path_length: int = 30
@export var tile_scenes: Array[PackedScene]

@onready var start_points := $"../start_points".get_children()

func _ready():
	var start = start_points.pick_random()
	print("Track startet bei:", start.name)
	
	var marker = get_marker_connectors(start).pick_random()
	if marker == null:
		print("❌ Kein gültiger Startmarker gefunden.")
		return

	place_tiles_from_markers(marker)

func place_tiles_from_markers(start_marker: Marker2D, depth := 0):
	if depth > max_path_length:
		print("✅ Maximale Tiefe erreicht bei:", depth)
		return

	print("🧱 Plaziere Tile auf Marker:", start_marker.global_position)

	var tile_scene = tile_scenes.pick_random()
	var tile_instance = tile_scene.instantiate()

	# Füge neuen Tile hinzu und positioniere ihn an den Marker
	add_child(tile_instance)
	tile_instance.global_position = start_marker.global_position
	tile_instance.global_rotation = start_marker.global_rotation

	# Finde Marker im neuen Tile (nachdem er korrekt positioniert wurde)
	var markers = get_marker_connectors(tile_instance)
	if markers.is_empty():
		print("❌ Keine Marker gefunden im neuen Tile")
		return

	# Entferne den Marker, den wir gerade benutzt haben
	var next_options = markers.filter(func(m): return m.global_position != start_marker.global_position)

	if next_options.is_empty():
		print("🚧 Kein weiterer Anschlussmarker übrig.")
		return

	var next_marker = next_options.pick_random()
	place_tiles_from_markers(next_marker, depth + 1)

func get_marker_connectors(node: Node) -> Array[Marker2D]:
	var out: Array[Marker2D] = []
	for c in node.get_children():
		if c is Marker2D and c.is_in_group("Connector"):
			out.append(c)
	return out
