extends Node2D

@export var tile_scenes: Array[PackedScene] # Deine 4+ Packets: Straight, Curve, Cross, Ramp…
@export var tile_size: int = 256
@export var max_path_length: int = 30

@onready var start_points := $"../start_points".get_children()
@onready var end_point   := $"../end_point"

# Hier speichern wir scene + deren connections
var tile_types := []
var used_positions := {}

func _ready():
	# 1) Alle Tiles instanziieren, connections auslesen, Instanzen wieder löschen
	for scene in tile_scenes:
		var tmp = scene.instantiate()
		tile_types.append({ "scene": scene, "conns": tmp.connections.duplicate() })
		tmp.queue_free()

	# 2) Path generieren + Tiles platzieren
	var start = start_points.pick_random().global_position
	var goal  = end_point.global_position
	var path  = generate_path(start, goal)
	place_tiles(path)

func generate_path(start: Vector2, goal: Vector2) -> Array[Vector2]:
	var start_cell : Vector2         = world_to_tile(start)
	var goal_cell  : Vector2         = world_to_tile(goal)
	var open_set   : Array[Vector2]  = [ start_cell ]
	var closed_set : Dictionary      = {}
	var came_from  : Dictionary      = {}
	var g_score    : Dictionary      = { start_cell: 0.0 }
	var f_score    : Dictionary      = { start_cell: start_cell.distance_to(goal_cell) }
	var directions : Array[Vector2]  = [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]

	while !open_set.is_empty():
		var current : Vector2 = _get_lowest_f(open_set, f_score)
		if current == goal_cell:
			return _reconstruct_path(came_from, current)

		open_set.erase(current)
		closed_set[current] = true

		for dir in directions:
			var neighbor : Vector2 = current + dir
			if closed_set.has(neighbor):
				continue

			var tentative_g = g_score[current] + 1
			if not open_set.has(neighbor):
				open_set.append(neighbor)
			elif tentative_g >= g_score.get(neighbor, INF):
				continue

			came_from[neighbor] = current
			g_score[neighbor]     = tentative_g
			var noise = randf_range(-0.2, 0.2)
			var h     = neighbor.distance_to(goal_cell)
			f_score[neighbor] = tentative_g + (1.0 + noise) * h

	# Falls kein Weg gefunden wurde, leeres typed Array zurückliefern
	return [] as Array[Vector2]

func _reconstruct_path(came_from: Dictionary, current: Vector2) -> Array[Vector2]:
	var total_path: Array[Vector2] = [ current ]
	while came_from.has(current):
		current = came_from[current]
		total_path.insert(0, current)
	return total_path


# hilfs-Funktion: Knoten mit dem kleinsten f_score finden
func _get_lowest_f(open_set: Array[Vector2], f_score: Dictionary) -> Vector2:
	var best = open_set[0]
	for cell in open_set:
		var f_cell = f_score.get(cell, INF)
		var f_best = f_score.get(best, INF)
		if f_cell < f_best:
			best = cell
		# bei Gleichstand können wir nach Zufall wechseln,
		# um mehrere äquidistante Wege zu erlauben
		elif f_cell == f_best and randf() < 0.5:
			best = cell
	return best

# (Optional) Prüfen, ob eine Zelle im erlaubten Spielfeld liegt
#func _is_in_bounds(cell: Vector2) -> bool:
	#return cell.x >= 0 and cell.y >= 0 and cell.x < map_width and cell.y < map_height


func place_tiles(path: Array[Vector2]) -> void:
	for i in range(path.size()):
		var cell : Vector2 = path[i]
		# default auf ZERO setzen
		var entry_dir : Vector2 = Vector2.ZERO
		var exit_dir  : Vector2 = Vector2.ZERO

		# nur wenn i>0 wirklich einen prev-Wert holen
		if i > 0:
			var prev_cell : Vector2 = path[i - 1]
			entry_dir = prev_cell - cell

		# nur wenn nicht das letzte Element
		if i < path.size() - 1:
			var next_cell : Vector2 = path[i + 1]
			exit_dir = next_cell - cell

		# now you can safely filter:
		var candidates: Array[PackedScene] = []
		for t in tile_types:
			var conns = t.conns  # Array[Vector2] der Verbindungen
			# Entry nur checken, wenn ungleich ZERO
			if entry_dir != Vector2.ZERO and entry_dir not in conns:
				continue
			# Exit nur checken, wenn ungleich ZERO
			if exit_dir  != Vector2.ZERO and exit_dir  not in conns:
				continue
			candidates.append(t.scene)
		if candidates.is_empty():
			push_warning("Kein Tile für E=%s, X=%s an %s" % [entry_dir, exit_dir, cell])
			continue

		var chosen = candidates[randi() % candidates.size()]
		var inst   = chosen.instantiate()
		inst.position = cell * tile_size
		add_child(inst)



func world_to_tile(pos: Vector2) -> Vector2:
	return Vector2(floor(pos.x / tile_size), floor(pos.y / tile_size))
