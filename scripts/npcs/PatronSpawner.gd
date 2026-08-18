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

# --- Eavesdropping (Story 8.5) ---
var eavesdrop_timer: Timer
var _eavesdropped_today: Dictionary = {}   # group key -> true (reset daily)
var _rumours: Array = []

func _ready():
	print("PatronSpawner initializing...")
	
	# Set up spawn timer
	spawn_timer = Timer.new()
	spawn_timer.wait_time = spawn_interval
	spawn_timer.timeout.connect(_on_spawn_timer_timeout)
	spawn_timer.one_shot = false
	add_child(spawn_timer)

	# Eavesdropping (Story 8.5): periodically check if the player is loitering near a group
	# of drinking patrons; if so, let them overhear a rumour.
	_load_rumours()
	eavesdrop_timer = Timer.new()
	eavesdrop_timer.wait_time = 1.0
	eavesdrop_timer.one_shot = false
	eavesdrop_timer.timeout.connect(_check_eavesdrop)
	add_child(eavesdrop_timer)
	eavesdrop_timer.start()
	if GameManager.has_signal("day_changed"):
		GameManager.day_changed.connect(func(_d): _eavesdropped_today.clear())
	
	# Wait for scene to be ready
	await get_tree().create_timer(2.0).timeout
	
	print("Spawning system ready")
	spawn_timer.start()

	# Restore patrons from a loaded save if there are any; otherwise spawn a fresh first patron.
	var saved: Array = GameManager.consume_restored_patrons() if GameManager.has_method("consume_restored_patrons") else []
	if saved.size() > 0:
		restore_patrons(saved)
	elif can_spawn_patron():
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

func restore_patrons(saved: Array) -> void:
	"""Rebuild patrons from save data at their exact positions/state (exact restore on load)."""
	for s in saved:
		var idx: int = int(s.get("table_index", -1))
		if idx < 0 or idx >= table_positions.size() or occupied_tables.has(idx):
			idx = get_available_table()
		var patron = PATRON_SCENE.instantiate()
		add_child(patron)  # _ready runs (random model); restore_from_save overrides it below
		var table_pos = table_positions[idx] if idx >= 0 else entrance_position
		patron.restore_from_save(s, table_pos, entrance_position, idx)
		patron.patron_finished.connect(_on_patron_finished)
		patron.wants_to_be_served.connect(_on_patron_wants_service)
		active_patrons.append(patron)
		if idx >= 0:
			occupied_tables[idx] = patron
	print("Restored ", active_patrons.size(), " patron(s) from save")

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

# =============================================================================
# EAVESDROPPING (Story 8.5)
# =============================================================================

func _load_rumours() -> void:
	var f = FileAccess.open("res://data/dialogue/rumours.json", FileAccess.READ)
	if f == null:
		return
	var parsed = JSON.parse_string(f.get_as_text())
	f.close()
	if parsed is Dictionary:
		_rumours = parsed.get("lines", [])

func _check_eavesdrop() -> void:
	if not PlayerManager or not is_instance_valid(PlayerManager.player):
		return
	var ppos: Vector3 = PlayerManager.player.global_position
	var range_m: float = DataManager.get_config("eavesdrop_range", 3.5)

	# Collect DRINKING patrons (state 2) within earshot of the player.
	var near: Array = []
	for p in active_patrons:
		if is_instance_valid(p) and p.current_state == 2 and p.global_position.distance_to(ppos) <= range_m:
			near.append(p)
	if near.size() < 2:
		return  # need a group of 2+ (a lone patron mutters nothing worth hearing)

	# One rumour per group per day: key by the sorted set of their tables.
	var idxs: Array = []
	for p in near:
		idxs.append(int(p.table_index))
	idxs.sort()
	var key := str(idxs)
	if _eavesdropped_today.has(key):
		return
	_eavesdropped_today[key] = true
	_fire_rumour()

func _fire_rumour() -> void:
	var line := _pick_rumour_line()
	if line == "":
		return
	WorldManager.overheard_rumours.append(line)   # Latest News feed pool (Epic 6 patch point)
	WorldBus.settlement_event.emit({"type": "rumour", "text": line})
	NotificationManager.show_banner("Overheard: " + line)
	print("[Eavesdrop] Rumour overheard (Latest News patch point): ", line)

func _pick_rumour_line() -> String:
	if _rumours.is_empty():
		return ""
	var raw: String = str(_rumours[randi() % _rumours.size()])
	return raw.replace("{place}", _random_place()).replace("{faction}", _random_faction())

func _random_place() -> String:
	var biomes = WorldManager.faction_data.get("biomes", []) if WorldManager else []
	if biomes is Array and not biomes.is_empty():
		var b = biomes[randi() % biomes.size()]
		if b is Dictionary:
			return b.get("name", "the frontier")
	return "the frontier"

func _random_faction() -> String:
	var names = WorldManager.faction_data.get("rival_guild_names", []) if WorldManager else []
	if names is Array and not names.is_empty():
		return str(names[randi() % names.size()])
	return "a rival guild"
