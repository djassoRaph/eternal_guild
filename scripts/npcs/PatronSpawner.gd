extends Node3D
class_name PatronSpawner

# Single patron spawning system - FIXED VERSION
# Addresses all parse errors and missing functions

# Spawn configuration
@export var spawn_interval: float = 30.0
@export var max_patrons: int = 1  # Only one patron at a time

# Position coordinates - FIXED: Much higher Y coordinate for testing
var entrance_position = Vector3(10.7, 10.0, 6.3)  # Spawn 10 units above ground
var table_position = Vector3(0, 10.0, 3.059)     # Also higher

# Current patron tracking - FIXED: All variables declared
var current_patron: Node3D = null
var spawn_timer: Timer
var main_scene: Node

func _ready():
	print("PatronSpawner initializing...")
	
	# Get reference to main scene for integration
	main_scene = get_tree().current_scene
	
	# Set up spawn timer
	setup_spawn_timer()
	
	# Start the spawning cycle
	start_spawning()

func setup_spawn_timer():
	"""Initialize the spawn timer with correct interval"""
	spawn_timer = Timer.new()
	spawn_timer.wait_time = spawn_interval
	spawn_timer.timeout.connect(_on_spawn_timer_timeout)
	spawn_timer.one_shot = true
	add_child(spawn_timer)
	
	print("Spawn timer set to ", spawn_interval, " seconds")

func start_spawning():
	"""Begin the patron spawning cycle"""
	if current_patron == null:
		print("Starting patron spawning cycle...")
		spawn_timer.start()

func _on_spawn_timer_timeout():
	"""Spawn a new patron when timer expires"""
	if current_patron == null:
		spawn_patron()
	else:
		print("Patron already present, delaying spawn...")
		spawn_timer.start()  # Try again later

func spawn_patron():
	"""Create and spawn a single patron at the entrance - FIXED FUNCTION"""
	print("Spawning new patron...")
	
	# CRITICAL FIX: Create CharacterBody3D with immediate collision setup
	current_patron = CharacterBody3D.new()
	current_patron.name = "Patron_" + str(Time.get_unix_time_from_system())
	
	# IMMEDIATE collision setup BEFORE adding to scene
	current_patron.collision_layer = 4
	current_patron.collision_mask = 2
	
	# Create collision shape immediately
	var collision = CollisionShape3D.new()
	var shape = CapsuleShape3D.new()
	shape.height = 2.0
	shape.radius = 0.5
	collision.shape = shape
	current_patron.add_child(collision)
	print("Added collision shape to patron")
	
	# DEBUG: Verify collision setup
	print("=== COLLISION DEBUG ===")
	print("Patron collision_layer: ", current_patron.collision_layer)
	print("Patron collision_mask: ", current_patron.collision_mask)
	print("CollisionShape3D exists: ", current_patron.get_children().any(func(child): return child is CollisionShape3D))
	print("Shape height: ", shape.height)
	print("Shape radius: ", shape.radius)
	print("======================")

	
	# Load and attach the script AFTER basic setup
	var patron_script = preload("res://scripts/npcs/RealisticPatron.gd")
	current_patron.set_script(patron_script)
	
	# Position at entrance - FIXED: Proper Y coordinate
	current_patron.position = entrance_position
	print("Patron spawned at entrance: ", entrance_position)
	
	# Add to scene
	add_child(current_patron)
	
	# Connect patron signals for cleanup
	if current_patron.has_signal("patron_left"):
		current_patron.connect("patron_left", _on_patron_left)
	
	# Send log message to main game
	if main_scene and main_scene.has_method("log_message"):
		main_scene.log_message("A patron enters the tavern looking for service!")

func _on_patron_left():
	"""Handle patron leaving the tavern"""
	print("Patron has left the tavern")
	current_patron = null
	
	# Start timer for next patron
	spawn_timer.start()
	
	if main_scene and main_scene.has_method("log_message"):
		main_scene.log_message("The patron leaves, satisfied with the service.")

func despawn_current_patron():
	"""Manually remove current patron (for debugging/testing)"""
	if current_patron:
		current_patron.queue_free()
		current_patron = null
		spawn_timer.start()
		print("Patron manually despawned")

func get_patron_count() -> int:
	"""Return current number of patrons (for debugging)"""
	return 1 if current_patron else 0

func pause_spawning():
	"""Stop spawning new patrons"""
	spawn_timer.stop()
	print("Patron spawning paused")

func resume_spawning():
	"""Resume patron spawning"""
	if current_patron == null:
		spawn_timer.start()
	print("Patron spawning resumed")

# Debug functions
func _input(event):
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_F12:  # Debug key - PatronSpawner info
			print_debug_info()
		elif event.keycode == KEY_F11:  # Force spawn for testing
			if current_patron == null:
				spawn_patron()
			else:
				print("Patron already exists, cannot spawn another")

func print_debug_info():
	"""Print current spawner state for debugging"""
	print("=== PATRON SPAWNER DEBUG ===")
	print("Current patron: ", current_patron)
	print("Timer running: ", not spawn_timer.is_stopped())
	print("Time remaining: ", spawn_timer.time_left)
	print("Entrance position: ", entrance_position)
	print("Table position: ", table_position)
	print("=============================")
