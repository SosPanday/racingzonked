extends Node2D

@export var tile_scenes: Array[PackedScene] # Deine Tile-Szenen (Straight, Curve, Cross...)
@export var cross_tile_scene: PackedScene
@export var tile_size: int = 64
@export var max_path_length: int = 30

@onready var start_points := $"../start_points".get_children()
@onready var end_point := $"../end_point"

enum Direction {
	NORTH,
	EAST,
	SOUTH,
	WEST
}

var used_positions := {}          # key=Vector2 (Tile Grid Pos), value=Node (TrackTile)
var visited_positions := {}       # Nur für die Pfadgenerierung: key=Vector2, value=true
var open_connectors := []         # Array von Dictionaries {position: Vector2, direction: Direction, parent_tile: Node}

func _ready():
	var start_point = start_points.pick_random()
	print_debug(start_point)
	var path = generate_path(world_to_tile(start_point.global_position), world_to_tile(end_point.global_position))
	print(path)
	place_first_tile(path[0] * tile_size)  # Starttile an Anfang platzieren

	for i in range(1, path.size()):
		var next_pos = path[i]
		print("Placing tile at: ", next_pos)
		print("Offene Connectoren:", open_connectors)
		if not place_tile_at(next_pos):
			print("❌ Kein passendes Tile für: ", next_pos)

func generate_path(start: Vector2, goal: Vector2) -> Array[Vector2]:
	var current_pos = start
	var goal_pos = goal
	var path: Array[Vector2] = [current_pos]
	visited_positions[current_pos] = true
	
	var directions = [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]
	var attempts = 0
	
	while current_pos != goal_pos and path.size() < max_path_length and attempts < 1000:
		var possible_moves = directions.filter(
			func(dir):
				var next = current_pos + dir
				return not visited_positions.has(next)
		)
	
		if possible_moves.is_empty():
			break
	
		possible_moves.sort_custom(func(a, b):
			return (current_pos + a).distance_to(goal_pos) < (current_pos + b).distance_to(goal_pos)
		)
		
		var next_move = possible_moves[0] # Beste Richtung
		current_pos += next_move
		path.append(current_pos)
		visited_positions[current_pos] = true
		attempts += 1
	
	return path

# Wandelt Weltposition in Tile-Grid-Position um
func world_to_tile(pos: Vector2) -> Vector2:
	return Vector2(floor(pos.x / tile_size), floor(pos.y / tile_size))

# Wandelt Tile-Grid-Position zurück in Weltkoordinaten
func tile_to_world(tile_pos: Vector2) -> Vector2:
	return tile_pos * tile_size

# Platzieren des Start-Tiles direkt an Startposition
func place_first_tile(tile_pos: Vector2):
	var randomTile = tile_scenes.pick_random()
	var start_scene = randomTile
	var tile = start_scene.instantiate()
	tile.position = tile_to_world(tile_pos)
	add_child(tile)
	used_positions[tile_pos] = tile
	
	# Alle Connectoren vom Starttile zur offenen Liste hinzufügen
	for connector in tile.get_connectors():
		var global_pos = connector.global_position
		var conn_grid_pos = world_to_tile(global_pos)
		#print("Open connector at: ", conn_grid_pos)
		#print("Offene Connectoren:", open_connectors)
		print("Tile Pos:", tile_pos, " Conn-World:", connector.global_position, " Conn-Grid:", world_to_tile(connector.global_position))
		var connectors = tile.get_connectors()
		print(connectors)
		open_connectors.append({
			"position": conn_grid_pos,
			"direction": connector.direction,
			"parent_tile": tile
		})

# Hauptfunktion: platziere an Position tile_pos ein Tile, das an einen offenen Connector passt
func place_tile_at(tile_pos: Vector2) -> bool:
	if used_positions.has(tile_pos):
		# Position schon belegt -> Kreuzung setzen
		var old_tile = used_positions[tile_pos]
		old_tile.queue_free()
		used_positions.erase(tile_pos)
		
		var cross_tile = cross_tile_scene.instantiate()
		cross_tile.position = tile_to_world(tile_pos)
		add_child(cross_tile)
		used_positions[tile_pos] = cross_tile
		
		# Connector des Kreuzungstiles zur offenen Liste hinzufügen
		for connector in cross_tile.get_connectors():
			var global_pos = connector.global_position
			var conn_grid_pos = world_to_tile(global_pos)
			open_connectors.append({
				"position": conn_grid_pos,
				"direction": connector.direction,
				"parent_tile": cross_tile
			})
		return true
	
	# --- Rest der Funktion: Finde einen offenen Connector, der zu dieser Position passt ---
	var matched_connector = null
	for i in range(open_connectors.size()):
		var conn = open_connectors[i]
		if conn.global_position == tile_pos:
			matched_connector = conn
			open_connectors.remove_at(i)
			break
	
	if matched_connector == null:
		#print("❌ Kein offener Connector passt zu ", tile_pos)
		return false # Kein offener Connector passt
	
	var needed_direction = opposite_direction(matched_connector.direction)
	
	for scene in tile_scenes:
		var tile = scene.instantiate()
		print_debug(tile)
		var connectors = tile.get_connectors()
		for connector in connectors:
			if connector.direction == needed_direction:
				var offset = connector.position
				tile.position = tile_to_world(tile_pos)
				if not is_position_occupied(tile):
					add_child(tile)
					used_positions[tile_pos] = tile
					for c in connectors:
						if c != connector:
							var global_pos = c.global_position
							var conn_grid_pos = world_to_tile(global_pos)
							open_connectors.append({
								"position": conn_grid_pos,
								"direction": c.direction,
								"parent_tile": tile
							})
					return true
				else:
					tile.queue_free()
	return false

# Hilfsfunktion: Prüft ob das Tile an seiner Position mit einem anderen Tile überlappt
func is_position_occupied(tile: Node2D) -> bool:
	var tile_grid_pos = world_to_tile(tile.position)
	if used_positions.has(tile_grid_pos):
		return true
	return false

# Hilfsfunktion: Wandelt Direction in Vector2 um
func direction_to_vector(dir: int) -> Vector2:
	match dir:
		Direction.NORTH:
			return Vector2(0, -1)
		Direction.EAST:
			return Vector2(1, 0)
		Direction.SOUTH:
			return Vector2(0, 1)
		Direction.WEST:
			return Vector2(-1, 0)
	return Vector2.ZERO

# Hilfsfunktion: Gegenrichtung bestimmen
func opposite_direction(dir: int) -> int:
	match dir:
		Direction.NORTH:
			return Direction.SOUTH
		Direction.EAST:
			return Direction.WEST
		Direction.SOUTH:
			return Direction.NORTH
		Direction.WEST:
			return Direction.EAST
	return dir
