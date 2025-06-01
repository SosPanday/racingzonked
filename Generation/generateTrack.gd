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

func _ready():
	var start_point = start_points.pick_random()
	var path = generate_path(start_point.global_position, end_point.global_position)
	place_tiles(path)
	spawn

func generate_path(start: Vector2, goal: Vector2) -> Array[Vector2]:
	var current_pos = world_to_tile(start)
	var goal_pos = world_to_tile(goal)
	var path: Array[Vector2] = [current_pos]
	used_positions[current_pos] = true

	var directions = [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]
	var attempts = 0

	while current_pos != goal_pos and path.size() < max_path_length and attempts < 1000:
		var possible_moves = directions.filter(
			func(dir):
				var next = current_pos + dir
				return not used_positions.has(next)
		)

		if possible_moves.is_empty():
			break

		possible_moves.sort_custom(func(a, b):
			return (current_pos + a).distance_to(goal_pos) < (current_pos + b).distance_to(goal_pos)
		)
		
		var next_move = possible_moves[0] # Beste Richtung
		current_pos += next_move
		path.append(current_pos)
		used_positions[current_pos] = true
		attempts += 1

	return path

func place_tiles(path: Array[Vector2]):
	for i in path.size():
		var tile_pos = path[i] * tile_size
		var scene_index = 0

		if i > 0:
			var prev = path[i - 1]
			var curr = path[i]
			var dir = curr - prev

			# Logik für Tileauswahl basierend auf Richtung 
			# (Placeholder - hier könntest du Curve oder Ramp erkennen)
			if dir.x != 0 and dir.y != 0:
				scene_index = 1 # Kurve
			elif randf() < 0.1:
				scene_index = 2 # Kreuzung
			elif randf() < 0.1:
				scene_index = 3 # Rampe
			else:
				scene_index = 0 # Gerade

		var tile_instance = tile_scenes[scene_index].instantiate()
		tile_instance.position = tile_pos
		add_child(tile_instance)

func world_to_tile(pos: Vector2) -> Vector2:
	return Vector2(floor(pos.x / tile_size), floor(pos.y / tile_size))
