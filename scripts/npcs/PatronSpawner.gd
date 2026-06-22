# PatronSpawner.gd - NAVIGATION-ENABLED SPAWNING
extends Node3D
class_name PatronSpawner

@export var max_patrons: int = 3
@export var spawn_interval: float = 20.0

# Patron scene
const PATRON_SCENE = preload("res://scenes/npcs/RealisticPatron.tscn")

# Entrance and table positions
var entrance_position = Vector3(8.7, 0.0, 3.3)


var table_positions = [
	Vector3(-3.847, 0.0, -0.915),   # Table 1 - adjust these!
	Vector3(-2.1, 0.0, -2.5),   # Table 2
	Vector3(-2.715, 0.0, -3.5),   # Table 3
	Vector3(-4.2, 0.0, -2.8),       # Table 4 - ADD MORE!
	Vector3(-1.5, 0.0, -1.2),    
]

# State tracking
var active_patrons: Array = []
var occupied_tables: Dictionary = {}  # table_index: patron
var spawn_timer: Timer

func _ready():
	print("PatronSpawner initializing...")
	
	# Set up spawn timer
	spawn_timer = Timer.new()
	spawn_timer.wait_time = spawn_interval
	spawn_timer.timeout.connect(_on_spawn_timer_timeout)
	spawn_timer.one_shot = false
	add_child(spawn_timer)
	
	# Wait for scene to be ready
	await get_tree().create_timer(2.0).timeout
	
	print("Spawning system ready")
	spawn_timer.start()
	
	# Spawn first patron
	if can_spawn_patron():
		spawn_patron()

func _on_spawn_timer_timeout():
	"""Try to spawn a patron on timer"""
	if can_spawn_patron():
		spawn_patron()

func can_spawn_patron() -> bool:
	"""Check if we can spawn a new patron"""
	if active_patrons.size() >= max_patrons:
		print("Max patrons reached (", active_patrons.size(), "/", max_patrons, ")")
		return false
	
	if get_available_table() == -1:
		print("No available tables")
		return false
	
	if GameManager.get_beer() <= 0:
		print("Out of beer!")
		return false
	
	return true

func get_available_table() -> int:
	"""Find an unoccupied table"""
	for i in range(table_positions.size()):
		if not occupied_tables.has(i):
			return i
	return -1

func spawn_patron():
	"""Spawn a patron with walking behavior"""
	var table_index = get_available_table()
	if table_index == -1:
		print("No table available")
		return
	
	# Create patron
	var patron = PATRON_SCENE.instantiate()
	add_child(patron)
	
	# Position at entrance
	patron.global_position = entrance_position
	
	# Give patron their target table
	patron.setup_for_table(
		table_positions[table_index],
		entrance_position,
		table_index
	)
	
	# Connect signals
	patron.patron_finished.connect(_on_patron_finished)
	patron.wants_to_be_served.connect(_on_patron_wants_service)
	
	# Track patron and table
	active_patrons.append(patron)
	occupied_tables[table_index] = patron
	
	print("🆕 Spawned patron '", patron.patron_name, "' → Table ", table_index)
	print("Active: ", active_patrons.size(), "/", max_patrons, " | Tables: ", occupied_tables.size(), "/", table_positions.size())

func _on_patron_finished(patron: RealisticPatron):
	"""Clean up when patron leaves"""
	
	# Remove from active list
	if patron in active_patrons:
		active_patrons.erase(patron)
	
	# Free their table
	for table_idx in occupied_tables.keys():
		if occupied_tables[table_idx] == patron:
			occupied_tables.erase(table_idx)
			print("Table ", table_idx, " is now available")
			break
	
	# Remove patron from scene
	patron.queue_free()
	
	print("Patron left. Active: ", active_patrons.size(), "/", max_patrons)
	
	# Try to spawn replacement
	if can_spawn_patron() and randf() < 0.7:
		await get_tree().create_timer(randf_range(5.0, 15.0)).timeout
		if can_spawn_patron():
			spawn_patron()

func _on_patron_wants_service(patron: RealisticPatron):
	"""Patron signals they want service"""
	print("", patron.patron_name, " wants service!")
	# You can add notification to player here later

# Debug helpers
func get_patron_count() -> int:
	return active_patrons.size()

func get_available_table_count() -> int:
	return table_positions.size() - occupied_tables.size()

func despawn_all_patrons():
	"""Remove all patrons immediately (called when player sleeps)"""
	print("Despawning all patrons for night...")
	
	# Store count for logging
	var patron_count = active_patrons.size()
	
	# Remove all patrons
	for patron in active_patrons.duplicate():  # Use duplicate to avoid modification during iteration
		# Free their table
		for table_idx in occupied_tables.keys():
			if occupied_tables[table_idx] == patron:
				occupied_tables.erase(table_idx)
				break
		
		# Remove from scene
		if is_instance_valid(patron):
			patron.queue_free()
	
	# Clear arrays
	active_patrons.clear()
	occupied_tables.clear()
	
	print("Despawned " + str(patron_count) + " patron(s) for the night")
	print("Active: 0/" + str(max_patrons) + " | Tables: 0/" + str(table_positions.size()))
