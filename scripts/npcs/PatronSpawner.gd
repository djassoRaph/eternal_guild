# PatronSpawner.gd - PERFORMANCE OPTIMIZED WITH OBJECT POOLING
extends Node3D
class_name PatronSpawner

# === PERFORMANCE OPTIMIZATION VARIABLES ===
@export var max_patrons: int = 3
@export var spawn_interval: float = 20.0
@export var settlement_type: String = "default"
@export var pool_size: int = 5  # Pre-load 5 patron instances

# Pre-loaded patron pools for instant spawning
var patron_scene_pool: Array = []  # Pool of inactive patron instances
var active_patrons: Array = []     # Currently active patrons
var preloaded_scenes: Dictionary = {}  # scene_path -> PackedScene

# Table and spawning configuration
var table_positions = [
	Vector3(-0.587034, 0.398272, 3.51529),  # Chair3
	Vector3(-1.41856, 0.431921, 2.69633),   # Chair4
	Vector3(0.809535, 0.378464, 3.47442),   # Chair5
]

var patron_scene_paths = [
	"res://scenes/npcs/PatronKnight.tscn",
	"res://scenes/npcs/PatronRogue.tscn", 
	"res://scenes/npcs/PatronMage.tscn",
	"res://scenes/npcs/PatronFarmer.tscn",
]

var entrance_position = Vector3(8.7, 0.0, 3.3)
var spawn_timer: Timer
var main_scene: Node
var occupied_tables: Dictionary = {}

# Settlement modifiers (existing)
var settlement_modifiers = {
	"frontier": {"patron_variety": ["Warrior", "Scout", "Hunter"], "spawn_rate_modifier": 1.3},
	"trading_hub": {"patron_variety": ["Merchant", "Diplomat", "Traveler"], "spawn_rate_modifier": 0.8},
	"scholarly": {"patron_variety": ["Scholar", "Mage", "Researcher"], "spawn_rate_modifier": 0.6},
	"military": {"patron_variety": ["Knight", "Officer", "Veteran"], "spawn_rate_modifier": 1.1}
}

# === INITIALIZATION WITH PRELOADING ===
func _ready():
	print("🚀 Performance Optimized PatronSpawner initializing...")
	
	main_scene = get_tree().current_scene
	
	# CRITICAL: Preload all assets before gameplay starts
	await preload_patron_scenes()
	await initialize_patron_pool()
	
	setup_spawn_timer()
	connect_to_gamemanager()
	
	# Wait before starting spawning
	await get_tree().create_timer(1.0).timeout
	start_spawning_cycle()
	
	print("✅ PatronSpawner ready with " + str(patron_scene_pool.size()) + " pooled instances")

func preload_patron_scenes():
	"""Preload all patron scenes during initialization to eliminate runtime loading"""
	print("📦 Preloading patron scenes...")
	
	for scene_path in patron_scene_paths:
		if ResourceLoader.exists(scene_path):
			# Load the scene resource (not instance yet)
			var scene_resource = load(scene_path)
			if scene_resource:
				preloaded_scenes[scene_path] = scene_resource
				print("✅ Preloaded: " + scene_path)
			else:
				print("❌ Failed to load: " + scene_path)
		else:
			print("⚠️ Scene not found: " + scene_path)
	
	print("📦 Preloaded " + str(preloaded_scenes.size()) + " patron scenes")

func initialize_patron_pool():
	"""Create a pool of inactive patron instances for instant spawning"""
	print("🏊 Initializing patron object pool...")
	
	for i in pool_size:
		var patron_instance = create_pooled_patron_instance()
		if patron_instance:
			patron_scene_pool.append(patron_instance)
			# Hide and disable the instance
			patron_instance.visible = false
			patron_instance.set_process_mode(Node.PROCESS_MODE_DISABLED)
			add_child(patron_instance)
	
	print("🏊 Patron pool initialized with " + str(patron_scene_pool.size()) + " instances")

func create_pooled_patron_instance():
	"""Create a single patron instance for the pool"""
	if preloaded_scenes.is_empty():
		print("❌ No preloaded scenes available for pool")
		return null
	
	# Use a random preloaded scene
	var scene_paths = preloaded_scenes.keys()
	var random_path = scene_paths[randi() % scene_paths.size()]
	var scene_resource = preloaded_scenes[random_path]
	
	var patron_instance = scene_resource.instantiate()
	
	# Configure the patron for pooling
	var patron_body = find_patron_body(patron_instance)
	if patron_body:
		# Connect cleanup signal for returning to pool
		if patron_body.has_signal("patron_finished"):
			patron_body.patron_finished.connect(_on_patron_finished)
		
		# Set unique ID for tracking
		patron_body.set_meta("pool_id", Time.get_unix_time_from_system() + randi())
		return patron_instance
	else:
		print("❌ Could not find patron body in pooled instance")
		patron_instance.queue_free()
		return null

func find_patron_body(patron_instance: Node) -> Node:
	"""Find the CharacterBody3D patron within the scene"""
	if patron_instance is CharacterBody3D:
		return patron_instance
	
	for child in patron_instance.get_children():
		if child is CharacterBody3D:
			return child
		
		# Search deeper if needed
		var found = find_patron_body(child)
		if found:
			return found
	
	return null

# === OPTIMIZED SPAWNING SYSTEM ===
func spawn_patron():
	"""Spawn patron using object pooling - ZERO LAG"""
	var table_index = get_available_table()
	if table_index == -1:
		print("❌ No available tables for patron spawning")
		return
	
	# Get patron from pool instead of loading
	var patron_instance = get_patron_from_pool()
	if not patron_instance:
		print("❌ No available patrons in pool")
		return
	
	var patron_body = find_patron_body(patron_instance)
	if not patron_body:
		print("❌ Invalid patron instance from pool")
		return_patron_to_pool(patron_instance)
		return
	
	print("🆕 Spawning pooled patron at table ", table_index)
	
	# Configure patron for this spawn
	setup_patron_for_spawn(patron_body, table_index)
	
	# Activate the patron instance
	patron_instance.visible = true
	patron_instance.set_process_mode(Node.PROCESS_MODE_INHERIT)
	
	# Track active patron
	active_patrons.append(patron_instance)
	occupied_tables[table_index] = patron_body
	
	print("🍺 Active patrons: ", active_patrons.size(), "/", max_patrons)
	print("🪑 Available tables: ", table_positions.size() - occupied_tables.size())

func get_patron_from_pool():
	"""Get an inactive patron from the pool"""
	if patron_scene_pool.is_empty():
		# Pool exhausted - create new instance as fallback
		print("⚠️ Patron pool exhausted, creating new instance")
		return create_pooled_patron_instance()
	
	return patron_scene_pool.pop_back()

func setup_patron_for_spawn(patron_body: Node, table_index: int):
	"""Configure patron for spawning at specific table"""
	# Reset patron position
	patron_body.global_position = entrance_position
	
	# Set target table
	var target_position = table_positions[table_index]
	patron_body.set_meta("target_table", target_position)
	patron_body.set_meta("table_index", table_index)
	
	# Reset patron state
	if patron_body.has_method("reset_patron_state"):
		patron_body.reset_patron_state()
	
	# Generate new patron data
	if patron_body.has_method("generate_patron_data"):
		patron_body.generate_patron_data()
	
	# Apply settlement-specific traits
	apply_settlement_traits(patron_body)

func apply_settlement_traits(patron_body: Node):
	"""Apply settlement-specific traits to patron"""
	var traits = get_settlement_modifier("patron_variety")
	if traits and traits is Array and traits.size() > 0:
		var selected_trait = traits[randi() % traits.size()]  # Changed variable name
		patron_body.set_meta("settlement_trait", selected_trait)
		
		# Adjust payment based on settlement type
		match settlement_type:
			"trading_hub":
				patron_body.payment_amount = randi_range(8, 12)
			"frontier":
				patron_body.payment_amount = randi_range(5, 8)
			"scholarly":
				patron_body.payment_amount = randi_range(6, 9)
			"military":
				patron_body.payment_amount = randi_range(7, 10)

# === PATRON LIFECYCLE MANAGEMENT ===
func _on_patron_finished(patron_body: Node):
	"""Handle patron finishing their visit - return to pool"""
	print("👋 Patron finished, returning to pool")
	
	# Find the full patron instance
	var patron_instance = patron_body.get_parent()
	while patron_instance and patron_instance.get_parent() != self:
		patron_instance = patron_instance.get_parent()
	
	if patron_instance in active_patrons:
		return_patron_to_pool(patron_instance)

func return_patron_to_pool(patron_instance: Node):
	"""Return patron instance to pool for reuse"""
	# Remove from active tracking
	if patron_instance in active_patrons:
		active_patrons.erase(patron_instance)
	
	# Free up table
	var patron_body = find_patron_body(patron_instance)
	if patron_body:
		var table_index = patron_body.get_meta("table_index", -1)
		if table_index != -1 and occupied_tables.has(table_index):
			occupied_tables.erase(table_index)
	
	# Reset instance for pool
	patron_instance.visible = false
	patron_instance.set_process_mode(Node.PROCESS_MODE_DISABLED)
	
	# Return to pool
	patron_scene_pool.append(patron_instance)
	
	print("🔄 Patron returned to pool. Pool size: ", patron_scene_pool.size())

# === EXISTING FUNCTIONS (unchanged) ===
func setup_spawn_timer():
	"""Initialize spawn timer with settlement-specific rates"""
	spawn_timer = Timer.new()
	
	var modifier = get_settlement_modifier("spawn_rate_modifier")
	if modifier == null:
		modifier = 1.0
	spawn_timer.wait_time = spawn_interval / modifier
	
	spawn_timer.timeout.connect(_on_spawn_timer_timeout)
	spawn_timer.one_shot = true
	add_child(spawn_timer)
	
	print("⏰ Spawn timer set to ", spawn_timer.wait_time, " seconds")
	
	
func connect_to_gamemanager():
	"""Connect to GameManager - MINIMAL VERSION"""
	# PatronSpawner only needs to check beer availability
	# No signal connections needed - just direct calls to GameManager.get_beer()
	pass

func start_spawning_cycle():
	"""Begin spawning cycle"""
	if can_spawn_patron():
		print("🚀 Starting optimized patron spawning cycle...")
		spawn_timer.start()
	else:
		await get_tree().create_timer(10.0).timeout
		start_spawning_cycle()

func _on_spawn_timer_timeout():
	"""Timer expired - spawn if possible"""
	if can_spawn_patron():
		spawn_patron()
	spawn_timer.start()

func can_spawn_patron() -> bool:
	"""Check if patron can spawn"""
	if active_patrons.size() >= max_patrons:
		return false
	
	if get_available_table() == -1:
		return false
	
	if GameManager.get_beer() <= 0:
		return false
	
	var spawn_chance = get_settlement_modifier("spawn_chance")
	if spawn_chance == null:
		spawn_chance = 0.8
	
	return randf() <= spawn_chance

func get_available_table() -> int:
	"""Find available table index"""
	for i in range(table_positions.size()):
		if not occupied_tables.has(i):
			return i
	return -1

func get_settlement_modifier(key: String):
	"""Get settlement-specific modifier"""
	var modifiers = settlement_modifiers.get(settlement_type)
	if modifiers == null:
		return null
	return modifiers.get(key)

# === DEBUG FUNCTIONS ===
func _input(event):
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_F11:
			force_spawn_patron()
		elif event.keycode == KEY_F12:
			print_performance_debug()

func force_spawn_patron():
	"""Force spawn for testing"""
	if active_patrons.size() < max_patrons:
		spawn_patron()

func print_performance_debug():
	"""Print performance statistics"""
	print("=== PERFORMANCE DEBUG ===")
	print("Preloaded scenes: ", preloaded_scenes.size())
	print("Pool size: ", patron_scene_pool.size())
	print("Active patrons: ", active_patrons.size())
	print("========================")
