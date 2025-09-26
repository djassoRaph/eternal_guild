# Enhanced PatronSpawner.gd - Multiple Patron Support for Settlement Scaling
extends Node3D
class_name PatronSpawner

# Spawn configuration - Enhanced for multiple patrons
@export var max_patrons: int = 3  # Can be modified per settlement
@export var spawn_interval: float = 20.0  # Reduced for more activity
@export var settlement_type: String = "default"

# Multiple table positions for patron management
var table_positions = [
	Vector3(-0.587034, 0.398272, 3.51529),  # Chair3
	Vector3(-1.41856, 0.431921, 2.69633),   # Chair4 (updated position)
	Vector3(0.809535, 0.378464, 3.47442),   # Chair5
]

var patron_scenes = [
	"res://scenes/npcs/PatronKnight.tscn",     # Knight patron with specific behavior
	"res://scenes/npcs/PatronRogue.tscn",      # Rogue patron with different personality
	"res://scenes/npcs/PatronMage.tscn",       # Mage patron with unique dialogue
	"res://scenes/npcs/PatronFarmer.tscn",     # Local farmer patron
]



var entrance_position = Vector3(8.7, 0.0, 3.3)

# Enhanced patron tracking
var current_patrons: Array = []
var spawn_timer: Timer
var main_scene: Node
var occupied_tables: Dictionary = {}  # table_index -> patron reference

# Settlement-specific patron behavior
var settlement_modifiers = {
	"frontier": {"patron_variety": ["Warrior", "Scout", "Hunter"], "spawn_rate_modifier": 1.3},
	"trading_hub": {"patron_variety": ["Merchant", "Diplomat", "Traveler"], "spawn_rate_modifier": 0.8},
	"scholarly": {"patron_variety": ["Scholar", "Mage", "Researcher"], "spawn_rate_modifier": 0.6},
	"military": {"patron_variety": ["Knight", "Officer", "Veteran"], "spawn_rate_modifier": 1.1}
}

func _ready():
	print("🍺 Enhanced PatronSpawner initializing for settlement type: ", settlement_type)
	
	main_scene = get_tree().current_scene
	setup_spawn_timer()
	connect_to_gamemanager()
	
	# Wait before starting spawning
	await get_tree().create_timer(3.0).timeout
	start_spawning_cycle()

func setup_spawn_timer():
	"""Initialize spawn timer with settlement-specific rates"""
	spawn_timer = Timer.new()
	
	# Apply settlement modifier to spawn rate
	var modifier = get_settlement_modifier("spawn_rate_modifier")
	if modifier == null:
		modifier = 1.0
	spawn_timer.wait_time = spawn_interval / modifier
	
	spawn_timer.timeout.connect(_on_spawn_timer_timeout)
	spawn_timer.one_shot = true
	add_child(spawn_timer)
	
	print("⏰ Spawn timer set to ", spawn_timer.wait_time, " seconds (modified by ", modifier, ")")

func connect_to_gamemanager():
	"""Connect to GameManager signals for better integration"""
	if GameManager:
		GameManager.gold_changed.connect(_on_gold_changed)
		GameManager.beer_changed.connect(_on_beer_changed)
		GameManager.day_changed.connect(_on_day_changed)

func start_spawning_cycle():
	"""Begin the enhanced patron spawning cycle"""
	if can_spawn_patron():
		print("🚀 Starting enhanced patron spawning cycle...")
		spawn_timer.start()
	else:
		# Retry in 10 seconds
		await get_tree().create_timer(10.0).timeout
		start_spawning_cycle()

func _on_spawn_timer_timeout():
	"""Timer expired - try to spawn patron if conditions allow"""
	if can_spawn_patron():
		spawn_patron()
	
	# Always restart timer for continuous spawning
	spawn_timer.start()

func can_spawn_patron() -> bool:
	"""Enhanced spawn condition checking"""
	# Check patron limit
	if current_patrons.size() >= max_patrons:
		return false
	
	# Check available tables
	if get_available_table() == -1:
		return false
	
	# Check beer availability
	if GameManager.get_beer() <= 0:
		print("❌ No beer available - delaying patron spawn")
		return false
	
	# Settlement-specific spawn chance
	var spawn_chance = get_settlement_modifier("spawn_chance")
	if spawn_chance == null:
		spawn_chance = 0.8
	if randf() > spawn_chance:
		print("🎲 Random spawn delay for variety")
		return false
	
	return true

func get_available_table() -> int:
	"""Find the next available table index"""
	for i in range(table_positions.size()):
		if not occupied_tables.has(i):
			return i
	return -1

func spawn_patron():
	"""Create and spawn a patron at an available table"""
	var table_index = get_available_table()
	if table_index == -1:
		print("❌ No available tables for patron spawning")
		return
	
	print("🆕 Spawning patron at table ", table_index)
	
	# Load patron scene
	var patron_path = patron_scenes[randi() % patron_scenes.size()]
	var patron_scene_resource = load(patron_path)
	var patron_instance = patron_scene_resource.instantiate()
	
	# Find the CharacterBody3D in the scene (should be immediate child now)
	var patron_body = null
	for child in patron_instance.get_children():
		if child is CharacterBody3D:
			patron_body = child
			break
	
	if not patron_body:
		print("❌ No CharacterBody3D found in patron scene!")
		patron_instance.queue_free()
		return
	
	# Set up patron properties
	patron_instance.name = "Patron_" + str(Time.get_unix_time_from_system()) + "_" + str(table_index)
	
	# Set collision properties on the CharacterBody3D
	patron_body.collision_layer = 4
	patron_body.collision_mask = 2
	
	# Position at entrance
	patron_instance.position = entrance_position
	
	# Add patron script to the CharacterBody3D (not the root)
	var patron_script = preload("res://scripts/npcs/RealisticPatron.gd")
	patron_body.set_script(patron_script)
	
	# Add to scene
	add_child(patron_instance)
	
	# Set patron's target table (on the CharacterBody3D)
	patron_body.table_position = table_positions[table_index]
	patron_body.set("table_index", table_index)
	
	# Connect signals from the CharacterBody3D
	if patron_body.has_signal("patron_left"):
		patron_body.patron_left.connect(_on_patron_left.bind(patron_body, table_index))
	if patron_body.has_signal("patron_served"):
		patron_body.patron_served.connect(_on_patron_served.bind(patron_body))
	
	# Track patron and table (store the CharacterBody3D reference)
	current_patrons.append(patron_body)
	occupied_tables[table_index] = patron_body
	
	# Initialize patron with settlement-specific data
	setup_patron_for_settlement(patron_body)
	
	# Log spawn
	if main_scene and main_scene.has_method("log_message"):
		main_scene.log_message("🚪 A patron enters seeking table " + str(table_index + 1))

func setup_patron_for_settlement(patron):
	"""Configure patron based on settlement type"""
	var variety = get_settlement_modifier("patron_variety")
	if variety == null:
		variety = ["Knight", "Barbarian", "Archer"]
	patron.character_type = variety[randi() % variety.size()]
	
	# Settlement-specific behavior could be added here
	match settlement_type:
		"frontier":
			patron.payment_amount = randi_range(8, 12)  # Higher tips on frontier
		"trading_hub":
			patron.payment_amount = randi_range(6, 10)  # Standard payment
		"scholarly":
			patron.payment_amount = randi_range(5, 8)   # Lower but steady
		"military":
			patron.payment_amount = randi_range(7, 11)  # Reliable payment

func _on_patron_left(patron_body, table_index):
	"""Handle patron leaving"""
	print("Patron has left the tavern")
	
	# Free up the table
	if occupied_tables.has(table_index):
		occupied_tables.erase(table_index)
	
	# Remove from tracking
	if patron_body in current_patrons:
		current_patrons.erase(patron_body)
	
	# Free the entire scene (patron_body's parent)
	var patron_scene = patron_body.get_parent()
	if patron_scene:
		patron_scene.queue_free()
	
	print("Current patrons: ", current_patrons.size(), "/", max_patrons)

func _on_patron_served(patron):
	"""Handle patron being served"""
	print("🍺 Patron ", patron.name, " was served at table ", patron.get("table_index"))

func _on_day_changed(new_day: int):
	"""Adjust spawning behavior based on day progression"""
	# Could implement day-specific patron patterns here
	if new_day % 7 == 0:  # Every 7 days, potential for busier periods
		spawn_timer.wait_time = max(5.0, spawn_timer.wait_time * 0.8)
		print("📈 Weekend rush - increased patron spawning rate")

func _on_gold_changed(new_gold: int):
	"""React to tavern prosperity"""
	# Could adjust patron quality based on tavern wealth
	pass

func _on_beer_changed(new_beer: int):
	"""React to beer stock changes"""
	if new_beer <= 0:
		print("🚫 Beer stock empty - pausing patron spawning")
		spawn_timer.stop()
	elif new_beer > 0 and spawn_timer.is_stopped():
		print("🍺 Beer restocked - resuming patron spawning")
		spawn_timer.start()

func get_settlement_modifier(key: String):
	"""Get settlement-specific modifier value"""
	var modifiers = settlement_modifiers.get(settlement_type)
	if modifiers == null:
		return null
	return modifiers.get(key)

# Enhanced debugging
func _input(event):
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_F11:
			force_spawn_patron()
		elif event.keycode == KEY_F12:
			print_debug_info()
		elif event.keycode == KEY_F10:
			clear_all_patrons()

func force_spawn_patron():
	"""Force spawn patron for testing"""
	if current_patrons.size() < max_patrons:
		spawn_patron()
		if main_scene and main_scene.has_method("log_message"):
			main_scene.log_message("🔧 DEBUG: Force spawned patron")
	else:
		print("Cannot force spawn - maximum patrons reached (", max_patrons, ")")

func clear_all_patrons():
	"""Clear all patrons for testing"""
	for patron in current_patrons:
		patron.queue_free()
	current_patrons.clear()
	occupied_tables.clear()
	print("🧹 DEBUG: Cleared all patrons")

func print_debug_info():
	"""Print enhanced spawner state"""
	print("=== ENHANCED PATRON SPAWNER DEBUG ===")
	print("Settlement type: ", settlement_type)
	print("Current patrons: ", current_patrons.size(), "/", max_patrons)
	print("Available tables: ", table_positions.size() - occupied_tables.size())
	print("Occupied tables: ", occupied_tables.keys())
	print("Timer running: ", not spawn_timer.is_stopped())
	print("Spawn interval: ", spawn_timer.wait_time)
	print("Beer stock: ", GameManager.get_beer())
	print("====================================")

# Settlement configuration for procedural world system
func configure_for_settlement(settlement_data: Dictionary):
	"""Configure spawner for specific settlement - FUTURE EXPANSION"""
	settlement_type = settlement_data.get("type", "default")
	max_patrons = settlement_data.get("tavern_capacity", 3)
	
	# Could load settlement-specific table layouts
	if settlement_data.has("table_positions"):
		table_positions = settlement_data["table_positions"]
	
	print("⚙️ Configured for settlement: ", settlement_type, " (Max patrons: ", max_patrons, ")")
