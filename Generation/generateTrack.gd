# Tilebased Procedural Track Generator in Godot 4.4 (GDScript)
# Voraussetzungen:
# - Eine TileMap mit verschiedenen Track-Tiles: Gerade, Kurven, Kreuzungen, Rampen etc.
# - Start- und End-Knoten als Node2D-Instanzen im Editor vorhanden
# - Jedes Tile ist eine eigene Scene, z.B. "Straight.tscn", "Curve.tscn", etc.

extends Node2D

@export var tile_scenes: Array[PackedScene] # Scenes für Straight, Curve, Cross, Ramp
@export var tile_size: int = 64
@export var max_path_length: int = 30

@onready var start_points := $"../start_points".get_children()
@onready var end_point := $"../end_point"

var used_positions := {}

# Erweiterte place_tiles()-Logik mit Marker2D-System (Rotation + offene Richtungen)

func _ready():
	var start_point = start_points.pick_random()
	place_tiles_from_markers(start_point)

func place_tiles_from_markers(start_tile: Node2D, max_steps: int = 30):
	var open_exits = []
	var used_positions = {}

	# Initiale Marker als Startpunkt (z. B. 1 Marker2D namens "Start")
	for child in start_tile.get_children():
		if child.is_in_group("connector"):
			open_exits.append({
				"position": child.global_position,
				"direction": child.global_transform.x.normalized(),
				"from_tile": start_tile
			})

	for step in max_steps:
		if open_exits.is_empty():
			break

		var exit = open_exits.pop_front()
		var pos = exit.position
		var dir = exit.direction

		# Vermeide Dopplungen anhand gerasterter Koordinaten
		var grid_pos = Vector2(round(pos.x / tile_size), round(pos.y / tile_size))
		if used_positions.has(grid_pos):
			continue
		used_positions[grid_pos] = true

		# Finde passende Szene
		var candidates = []
		for scene in tile_scenes:
			var inst = scene.instantiate()
			var connectors = get_marker_connectors(inst)
			for marker in connectors:
				var in_dir = -marker.transform.x.normalized()
				if abs(in_dir.angle_to(dir)) < deg_to_rad(10):
					candidates.append({
						"scene": scene,
						"entry_marker": marker
					})

		if candidates.is_empty():
			continue

		var choice = candidates.pick_random()
		var new_tile = choice.scene.instantiate()
		var entry_marker = choice.entry_marker

		# Setze Tile-Position so, dass entry_marker mit exit-Position matcht
		var offset = new_tile.to_global(entry_marker.position) - new_tile.global_position
		new_tile.global_position = pos - offset

		add_child(new_tile)

		# Neue offenen Richtungen registrieren
		for child in new_tile.get_children():
			if child.is_in_group("connector") and child != entry_marker:
				open_exits.append({
					"position": child.global_position,
					"direction": child.global_transform.x.normalized(),
					"from_tile": new_tile
				})


# Holt alle Marker2D-Knoten in Gruppe "connector" aus einem Tile
func get_marker_connectors(tile: Node) -> Array:
	var list := []
	for child in tile.get_children():
		if child.is_in_group("connector"):
			list.append(child)
	return list
