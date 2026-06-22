# SaveSystem.gd - COMPLETE SAVE/LOAD IMPLEMENTATION
extends Node

const SAVE_FILE = "user://eternal_guild_save.json"
const AUTOSAVE_INTERVAL = 300.0  # Auto-save every 5 minutes
const MAX_BACKUP_FILES = 3

var autosave_timer: Timer
var save_in_progress: bool = false
var load_in_progress: bool = false

signal save_completed(success: bool)
signal load_completed(success: bool)
signal autosave_triggered()

func _ready():
	print("💾 SaveSystem initialized")
	setup_autosave_timer()
	
	# Connect to GameManager for automatic save triggers
	if GameManager:
		GameManager.day_changed.connect(_on_day_changed)
		GameManager.game_over_triggered.connect(_on_game_over)

func setup_autosave_timer():
	"""Set up automatic saving every 5 minutes"""
	autosave_timer = Timer.new()
	autosave_timer.wait_time = AUTOSAVE_INTERVAL
	autosave_timer.timeout.connect(_on_autosave_timer_timeout)
	autosave_timer.autostart = true
	add_child(autosave_timer)
	print("⏰ Autosave timer configured (", AUTOSAVE_INTERVAL, " seconds)")

func _on_autosave_timer_timeout():
	"""Trigger autosave"""
	autosave_triggered.emit()
	autosave_game()

func _on_day_changed(new_day: int):
	if load_in_progress:
		return
	if new_day > 1:
		autosave_game()

func _on_game_over(reason: String):
	"""Save game state even when game over occurs"""
	save_game_state("game_over_save")

# === MAIN SAVE/LOAD FUNCTIONS ===

func save_game() -> bool:
	"""Manual save game - called by player"""
	return save_game_state("manual_save")

func autosave_game() -> bool:
	"""Automatic save - silent operation"""
	return save_game_state("autosave", true)

func save_game_state(save_type: String = "manual_save", silent: bool = false) -> bool:
	"""Core save function with backup system"""
	if save_in_progress:
		if not silent:
			print("Save already in progress, skipping...")
		return false
	
	save_in_progress = true
	
	if not silent:
		print("💾 Saving game state...")
	
	# Create backup of existing save
	create_save_backup()
	
	# Gather all save data from GameManager
	var save_data = GameManager.get_save_data()
	
	# Add save metadata
	save_data["save_type"] = save_type
	save_data["save_timestamp"] = Time.get_unix_time_from_system()
	save_data["save_date_string"] = Time.get_datetime_string_from_system()
	save_data["game_version"] = "1.0.0"  # Update as needed
	save_data["total_playtime"] = calculate_playtime()
	
	# Add beer shortage tracking
	save_data["beer_shortage_days"] = GameManager.beer_shortage_days
	save_data["adventurer_morale"] = GameManager.adventurer_morale
	
	# Save to file
	var success = write_save_file(SAVE_FILE, save_data)
	
	save_in_progress = false
	save_completed.emit(success)
	
	if success:
		if not silent:
			print("✅ Game saved successfully (", save_type, ")")
			if GameManager.has_method("log_message"):
				GameManager.log_message("💾 Game saved")
	else:
		if not silent:
			print("❌ Save failed!")
		if GameManager.has_method("log_message"):
			GameManager.log_message("💾 Save failed - check permissions")
	
	return success


func load_game() -> bool:
	if not has_save_file():
		print("No save file found at: ", SAVE_FILE)
		return false

	print("Loading game state from: ", SAVE_FILE)

	var save_data = read_save_file(SAVE_FILE)
	if save_data == null or save_data.is_empty():
		print("Failed to read save file or file is empty")
		return false

	if not validate_save_data(save_data):
		print("Save file validation failed")
		return false

	if not GameManager:
		print("GameManager not found!")
		return false

	# Suppress autosave while signals fire during load
	load_in_progress = true
	GameManager.load_save_data(save_data)
	load_in_progress = false

	print("Game loaded successfully from Day ", save_data.get("current_day", 1))

	load_completed.emit(true)
	return true

# === FILE OPERATIONS ===

func write_save_file(filepath: String, data: Dictionary) -> bool:
	"""Write save data to file with error handling"""
	var file = FileAccess.open(filepath, FileAccess.WRITE)
	if file == null:
		print("Cannot open save file for writing: ", filepath)
		return false
	
	var json_string = JSON.stringify(data, "\t")  # Pretty print with tabs
	file.store_string(json_string)
	file.close()
	
	return true

func read_save_file(filepath: String) -> Dictionary:
	"""Read and parse save file - IMPROVED WITH DEBUG"""
	print("🔍 Attempting to read: ", filepath)
	
	if not FileAccess.file_exists(filepath):
		print("❌ File does not exist: ", filepath)
		return {}
	
	var file = FileAccess.open(filepath, FileAccess.READ)
	if file == null:
		var error = FileAccess.get_open_error()
		print("❌ Cannot open save file. Error code: ", error)
		return {}
	
	var json_text = file.get_as_text()
	file.close()
	
	if json_text.is_empty():
		print("❌ Save file is empty")
		return {}
	
	print("✅ File content length: ", json_text.length(), " characters")
	print("   First 100 chars: ", json_text.substr(0, 100))
	
	var json = JSON.new()
	var parse_result = json.parse(json_text)
	
	if parse_result != OK:
		print("❌ JSON parse error at line ", json.get_error_line())
		print("   Error message: ", json.get_error_message())
		return {}
	
	var data = json.data
	
	if not data is Dictionary:
		print("❌ Parsed data is not a Dictionary, it's: ", typeof(data))
		return {}
	
	print("✅ JSON parsed successfully")
	return data
# === BACKUP SYSTEM ===

func create_save_backup():
	"""Create rotating backups of save files"""
	if not FileAccess.file_exists(SAVE_FILE):
		return
	
	# Rotate existing backups
	for i in range(MAX_BACKUP_FILES - 1, 0, -1):
		var current_backup = SAVE_FILE + ".backup" + str(i)
		var next_backup = SAVE_FILE + ".backup" + str(i + 1)
		
		if FileAccess.file_exists(current_backup):
			if i == MAX_BACKUP_FILES - 1:
				# Delete oldest backup
				DirAccess.remove_absolute(next_backup)
			else:
				# Move to next slot
				DirAccess.rename_absolute(current_backup, next_backup)
	
	# Create new backup from current save
	var backup_path = SAVE_FILE + ".backup1"
	DirAccess.copy_absolute(SAVE_FILE, backup_path)

func restore_from_backup(backup_number: int = 1) -> bool:
	"""Restore save from backup file"""
	var backup_path = SAVE_FILE + ".backup" + str(backup_number)
	
	if not FileAccess.file_exists(backup_path):
		print("Backup file not found: ", backup_path)
		return false
	
	# Copy backup to main save file
	DirAccess.copy_absolute(backup_path, SAVE_FILE)
	print("Restored from backup: ", backup_path)
	
	return load_game()

# === VALIDATION ===

func validate_save_data(data: Dictionary) -> bool:
	"""Validate save data integrity"""
	print("🔍 Validating save data...")
	
	var required_fields = ["current_day", "gold", "beer_stock", "adventurers"]
	
	for field in required_fields:
		if not data.has(field):
			print("❌ Missing required field: ", field)
			return false
		print("   ✅ Found: ", field, " = ", data[field])
	
	# Accept both int and float for numeric values
	if not (data["current_day"] is int or data["current_day"] is float):
		print("❌ current_day is not numeric: ", typeof(data["current_day"]))
		return false
	
	if int(data["current_day"]) < 1:
		print("❌ Invalid day value: ", data["current_day"])
		return false
	
	if not (data["gold"] is int or data["gold"] is float):
		print("❌ gold is not numeric: ", typeof(data["gold"]))
		return false
	
	if not data["adventurers"] is Array:
		print("❌ adventurers is not Array: ", typeof(data["adventurers"]))
		return false
	
	print("✅ Save data validation passed")
	return true

# === UTILITY FUNCTIONS ===

func has_save_file() -> bool:
	"""Check if save file exists"""
	return FileAccess.file_exists(SAVE_FILE)

func get_save_info() -> Dictionary:
	"""Get information about save file without loading it"""
	if not has_save_file():
		return {}
	
	var save_data = read_save_file(SAVE_FILE)
	if save_data.is_empty():
		return {}
	
	return {
		"day": save_data.get("current_day", 1),
		"gold": save_data.get("gold", 0),
		"adventurers": save_data.get("adventurers", []).size(),
		"save_date": save_data.get("save_date_string", "Unknown"),
		"save_type": save_data.get("save_type", "manual_save"),
		"playtime": save_data.get("total_playtime", 0)
	}

func calculate_playtime() -> float:
	"""Calculate total playtime in seconds"""
	# This is a simple version - could be enhanced with pause tracking
	return (GameManager.current_day - 1) * 60.0  # Rough estimate

func delete_save_file() -> bool:
	"""Delete the save file (for new game)"""
	if has_save_file():
		DirAccess.remove_absolute(SAVE_FILE)
		print("Save file deleted")
		return true
	return false

func get_available_backups() -> Array:
	"""Get list of available backup files"""
	var backups = []
	for i in range(1, MAX_BACKUP_FILES + 1):
		var backup_path = SAVE_FILE + ".backup" + str(i)
		if FileAccess.file_exists(backup_path):
			var backup_data = read_save_file(backup_path)
			if not backup_data.is_empty():
				backups.append({
					"number": i,
					"day": backup_data.get("current_day", 1),
					"date": backup_data.get("save_date_string", "Unknown"),
					"path": backup_path
				})
	return backups

# === DEBUG FUNCTIONS ===

func print_save_debug():
	"""Print save system debug information"""
	print("=== SAVE SYSTEM DEBUG ===")
	print("Save file exists: ", has_save_file())
	print("Save in progress: ", save_in_progress)
	print("Autosave interval: ", AUTOSAVE_INTERVAL, " seconds")
	print("Available backups: ", get_available_backups().size())
	
	if has_save_file():
		var info = get_save_info()
		print("Current save - Day: ", info.get("day"), ", Gold: ", info.get("gold"))
	
	print("========================")

func force_save():
	"""Debug function to force immediate save"""
	print("🔧 DEBUG: Force saving...")
	save_game_state("debug_save")

func export_save_data() -> String:
	"""Export save data as readable string for debugging"""
	if not has_save_file():
		return "No save file found"
	
	var save_data = read_save_file(SAVE_FILE)
	return JSON.stringify(save_data, "\t")
