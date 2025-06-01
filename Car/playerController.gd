extends CharacterBody2D

# Grundlegende Fahrwerte – angepasst auf ein Arcade-Pixelgame
@export var steering_angle: float = 25.0        # Maximale Lenkung in Grad
@export var engine_power: float = 800.0         # Antriebskraft
@export var braking: float = -600.0             # Bremskraft
@export var idle_brake: float = 600.0           # Extra-Bremskraft, wenn kein Gas gegeben wird
@export var friction: float = -150.0            # Reibungskoeffizient in Fahrtrichtung
@export var drag: float = -1.0                  # Luftwiderstandskoeffizient

# Boost- und Speed-Parameter
@export var base_max_speed: float = 150.0       # Basis-Maxgeschwindigkeit
@export var boost_increment: float = 2.0        # Wie viel werden pro Boost-Intervall hinzugefügt
@export var boost_interval: float = 1.0         # Zeit (in Sekunden), bis ein Boost-Schritt erfolgt
@export var max_boost: float = 30.0             # Obergrenze für den dynamisch aufgebauten Boost
@export var boost_decay: float = 0.2           # Schnelligkeit, mit der der Boost abgebaut wird, wenn nicht an der Grenze
@export var zonked: float = 0.0                 # Ein Bonuswert, der später über Items erhöht wird


@export var max_speed_reverse: float = 150.0    # Maximale Rückwärtsgeschwindigkeit

# Traktion – unterschiedlich bei Drift
@export var traction_fast: float = 0.5          # Traktionsfaktor im Drift (niedriger, mehr „Schlittereffekt“)
@export var traction_slow: float = 10.0         # Traktionsfaktor ohne Drift (präzise Lenkung)

var wheel_base: float = 65.0                    # Abstand zwischen Vorder- und Hinterachse
var acceleration: Vector2 = Vector2.ZERO        # Summe der Beschleunigungsvektoren (Input, Friktion, Drag)
var steer_direction: float = 0.0                # Aktuelle Lenkrichtung in Radiant
var drifting_active: bool = false               # Driftmodus aktiv, wenn "move_drift" gedrückt wird

# Variablen für den Geschwindigkeits-Boost:

# Variablen für den Boost-Ablauf
var current_boost: float = 0.0                  # Aktuell aufgelaufener Boost
var boost_timer: float = 0.0                    # Zeit, während der das Auto konstant an der Grenze fährt

@onready var speed_label: Label = $Camera2D/Container/Label # Passe den Pfad an deine Szenenstruktur an.

func _physics_process(delta: float) -> void:
	if $Camera2D:
		$Camera2D.make_current()

	var max_speed_allowed: float = base_max_speed + zonked + current_boost
	var forward_speed: float = velocity.dot(transform.x)
	# Es wird der Betrag von velocity (sowie acceleration) angezeigt.
	# Berechne die Vorwärtsgeschwindigkeit, indem du den Dot-Product von velocity und der Fahrzeugrichtung nimmst.
	# Berechne den effektiven maximalen Speed aus Basiswert, zonked und dem aufgebauten Boost.
	var effective_max_speed = base_max_speed + zonked + current_boost

	# Aktualisiere den Text des HUD-Labels, z.B. als "aktuelle Geschwindigkeit / effektiver Max-Speed".
	speed_label.text = "Speed: " + str(round(forward_speed)) + " / " + str(round(effective_max_speed))

	acceleration = Vector2.ZERO
	
	get_input(delta)         # Abfrage von Input (Gas, Bremsen, Links/Rechts, Drift)
	process_boost(delta)     # Hier bauen wir den Boost auf, wenn permanent an der Grenze gefahren wird
	apply_friction(delta)    # Berechne Reibung & Drag (und optional auch Drift-Effekte)
	
	velocity += acceleration * delta
	
	clamp_speed()            # Stelle sicher, dass die Vorwärtsgeschwindigkeit nicht über den (boosted) Max-Wert steigt
	calculate_steering(delta)
	move_and_slide()
	
	# Optional: Pixelgenaue Positionierung
	position = position.snapped(Vector2(1, 1))


# Liest den Input aus. Bei "move_up" wird Gas gegeben, solange die Vorwärtsgeschwindigkeit
# unter dem aktuellen effektiven Maximum liegt (base_max_speed + zonked + current_boost).
func get_input(delta: float) -> void:
	var turn: float = Input.get_axis("move_left", "move_right")
	steer_direction = turn * deg_to_rad(steering_angle)
	
	drifting_active = Input.is_action_pressed("move_drift")
	
	if Input.is_action_pressed("move_up"):
		var forward_speed: float = velocity.dot(transform.x)
		var effective_max_speed: float = base_max_speed + zonked + current_boost

		if forward_speed < effective_max_speed:
			acceleration = transform.x * engine_power
		else:
			acceleration = Vector2.ZERO
	elif Input.is_action_pressed("move_down"):
		acceleration = transform.x * braking
	else:
		velocity = velocity.move_toward(Vector2.ZERO, idle_brake * delta)

func process_boost(delta: float) -> void:
	if Input.is_action_pressed("move_up"):
		var forward_speed: float = velocity.dot(transform.x)
		var effective_max_speed: float = base_max_speed + zonked + current_boost
		if drifting_active:
			effective_max_speed -= 50
			
		if forward_speed >= effective_max_speed - 25.0:
			boost_timer += delta
			if boost_timer >= boost_interval:
				boost_timer = 0.0
				current_boost = min(current_boost + boost_increment, max_boost)
		else:
			boost_timer = max(boost_timer - delta, 0.0)
			current_boost = max(current_boost - boost_decay * delta, 0.0)
	else:
		boost_timer = 0.0
		current_boost = max(current_boost - boost_decay * delta, 0.0)


# Beschränkt die Vorwärtsgeschwindigkeit (Projektion auf transform.x) auf den effektiven Max-Speed.
func clamp_speed() -> void:
	var effective_max_speed: float = base_max_speed + zonked + current_boost
	var forward_speed: float = velocity.dot(transform.x)
	if forward_speed > effective_max_speed:
		var forward_vec = transform.x.normalized()
		var side_component = velocity - forward_vec * forward_speed
		velocity = forward_vec * effective_max_speed + side_component


# Wendet Reibungs- und Drag-Kräfte an. Beim Drift (üblicherweise aktiviert über "move_drift")
# wird die seitliche Reibung reduziert, sodass mehr Schlittereffekt entsteht.
func apply_friction(delta: float) -> void:
	if acceleration == Vector2.ZERO and velocity.length() < 20.0:
		velocity = Vector2.ZERO
		return
		 
	var forward_vec: Vector2 = transform.x.normalized()
	var side_vec: Vector2 = transform.y.normalized()
	
	var forward_speed: float = forward_vec.dot(velocity)
	var side_speed: float = side_vec.dot(velocity)
	
	steering_angle = 25
	
	var friction_forward: float = friction
	var friction_side: float = friction
	if drifting_active:
		friction_side *= 0.5  # Reduzierte seitliche Reibung im Driftmodus
		steering_angle = 55
		
	var friction_force_forward: Vector2 = forward_vec * forward_speed * friction_forward * delta
	var friction_force_side: Vector2 = side_vec * side_speed * friction_side * delta
	var friction_force: Vector2 = friction_force_forward + friction_force_side
	
	var drag_force: Vector2 = velocity * velocity.length() * drag * delta
	
	acceleration += friction_force + drag_force


# Berechnet den Einfluss der Lenkung durch virtuelle Radpositionen an Hinter- und Vorderachse.
# Die Traktion wird dabei, abhängig vom Driftstatus, angepasst.
func calculate_steering(delta: float) -> void:
	var rear_wheel: Vector2 = position - transform.x * (wheel_base * 0.5)
	var front_wheel: Vector2 = position + transform.x * (wheel_base * 0.5)
	
	rear_wheel += velocity * delta
	front_wheel += velocity.rotated(steer_direction) * delta
	
	var new_heading: Vector2 = rear_wheel.direction_to(front_wheel)
	
	var traction: float = drifting_active if traction_fast else traction_slow
	if velocity.length() > 0.001:
		var alignment: float = new_heading.dot(velocity.normalized())
		if alignment > 0.0:
			var target: Vector2 = new_heading * velocity.length()
			velocity = velocity + (target - velocity) * (traction * delta)
		elif alignment < 0.0:
			velocity = -new_heading * min(velocity.length(), max_speed_reverse)
	
	rotation = new_heading.angle()
