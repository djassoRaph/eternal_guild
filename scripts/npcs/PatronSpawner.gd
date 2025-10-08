# PatronSpawner.gd - NAVIGATION-ENABLED SPAWNING SYSTEM
extends Node3D
class_name PatronSpawner

@export var max_patrons: int = 3
@export var spawn_interval: float = 20.0

# Patron scene to spawn
const PATRON_SCENE = preload("res://scenes/npcs/RealisticPatron.tscn")

# Table positions (your existing configuration)
var table_positions = [
	Vector3(-0.587034, 0.398272, 3.51529),
	Vector3(-1.41856, 0.431921, 2.69633),
	Vector3(0.809535, 0.378464, 3.47442),
]

var entrance_position = Vector3(8.7, 0.0, 3.3)

# State tracking
var active_patrons: Array = []
var occupied_tables: Dictionary = {}
var spawn_timer: Timer
var main_scene: Node

func _ready():
	print("🚀 PatronSpawner initializing with navigation support...")
	
	main_scene = get_tree().current_scene
	
	# Set up spawn timer
	spawn_timer = Timer.new()
	spawn_timer.wait_time = spawn_interval
	spawn_timer.timeout.connect(_on_spawn_timer_timeout)
	spawn_timer.one_shot = false
	add_child(spawn_timer)
	
	# Wait for scene to be fully ready
	await get_tree().create_timer(2.0).timeout
	
	# Verify navigation is ready
	if not verify_navigation_ready():
		push_error("❌ Navigation system not ready! Make sure NavigationRegion3D exists in scene!")
		return
	
	# Start spawning
	print("✅ Navigation verified, starting spawn cycle")
	spawn_timer.start()
	
	# Spawn first patron immediately
	if can_spawn_patron():
		spawn_patron()

func verify_navigation_ready() -> bool:
	"""Check if navigation system is properly set up"""
	var nav_region = get_tree().current_scene.find_child("TavernNavigation", true, false)
	
	if nav_region and nav_region is NavigationRegion3D:
		print("✅ Found NavigationRegion3D: ", nav_region.name)
		return true
	else:
		print("❌ NavigationRegion3D not found in scene!")
		print("⚠️ You need to add a NavigationRegion3D node to your MainTavern scene")
		return false

func _on_spawn_timer_timeout():
	"""Try to spawn a patron on timer"""
	if can_spawn_patron():
		spawn_patron()

func can_spawn_patron() -> bool:
	"""Check if we can spawn a new patron"""
	if active_patrons.size() >= max_patrons:
		print("⚠️ Max patrons reached (", active_patrons.size(), "/", max_patrons, ")")
		return false
	
	if get_available_table() == -1:
		print("⚠️ No available tables")
		return false
	
	if GameManager.get_beer() <= 0:
		print("⚠️ Out of beer!")
		return false
	
	return true

func get_available_table() -> int:
	"""Find an available table index"""
	for i in range(table_positions.size()):
		if not occupied_tables.has(i):
			return i
	return -1

func spawn_patron():
	"""Spawn a new patron with navigation"""
	var table_index = get_available_table()
	if table_index == -1:
		print("❌ No table available")
		return
	
	print("🔍 DEBUG: Attempting to load: ", PATRON_SCENE.resource_path)
	
	# Create patron instance
	var patron = PATRON_SCENE.instantiate()
	
	print("🔍 DEBUG: Instantiated type: ", patron.get_class())
	print("🔍 DEBUG: Has script: ", patron.get_script() != null)
	
	# Create patron instance
	add_child(patron)
	
	# Position at entrance
	patron.global_position = entrance_position
	
	# Set target table via metadata (patron reads this in _ready())
	patron.set_meta("target_table", table_positions[table_index])
	patron.set_meta("entrance_position", entrance_position)
	patron.set_meta("table_index", table_index)
	
	# Generate patron data
	patron.generate_patron_data()
	
	# Connect cleanup signal
	patron.patron_finished.connect(_on_patron_finished)
	
	# Track patron
	active_patrons.append(patron)
	occupied_tables[table_index] = patron
	
	print("🆕 Spawned patron '", patron.patron_name, "' for table ", table_index)
	print("🍺 Active patrons: ", active_patrons.size(), "/", max_patrons)
	print("🪑 Available tables: ", table_positions.size() - occupied_tables.size())

func _on_patron_finished(patron: RealisticPatron):
	"""Clean up when patron leaves"""
	
	# Remove from active list
	if patron in active_patrons:
		active_patrons.erase(patron)
	
	# Free table
	for table_idx in occupied_tables.keys():
		if occupied_tables[table_idx] == patron:
			occupied_tables.erase(table_idx)
			print("🪑 Table ", table_idx, " is now available")
			break
	
	# Remove patron from scene
	patron.queue_free()
	
	print("👋 Patron left. Active: ", active_patrons.size(), "/", max_patrons)
	
	# Try to spawn replacement if possible
	if can_spawn_patron() and randf() < 0.7:
		await get_tree().create_timer(randf_range(5.0, 15.0)).timeout
		if can_spawn_patron():
			spawn_patron()

# Debug function
func get_patron_count() -> int:
	return active_patrons.size()

func get_available_table_count() -> int:
	return table_positions.size() - occupied_tables.size()
