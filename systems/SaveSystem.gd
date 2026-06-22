# SaveSystem.gd - Dual-file save architecture (savegame + codex)
extends Node

const SAVE_FILE = "user://eternal_guild_save.json"
const CODEX_FILE = "user://codex.dat"
const CURRENT_SCHEMA_VERSION = 1

var autosave_timer: Timer
var save_in_progress: bool = false
var load_in_progress: bool = false

var codex_data: Dictionary = {}

signal save_completed(success: bool)
signal load_completed(success: bool)
signal autosave_triggered()

func _ready():
	print("[SaveSystem] Initialized")
	_load_codex()
	setup_autosave_timer()

	if GameManager:
		GameManager.day_changed.connect(_on_day_changed)
		GameManager.game_over_triggered.connect(_on_game_over)

func setup_autosave_timer():
	var interval = DataManager.get_config("autosave_interval_seconds", 300)
	autosave_timer = Timer.new()
	autosave_timer.wait_time = float(interval)
	autosave_timer.timeout.connect(_on_autosave_timer_timeout)
	autosave_timer.autostart = true
	add_child(autosave_timer)
	print("[SaveSystem] Autosave timer: ", interval, "s")

func _on_autosave_timer_timeout():
	autosave_triggered.emit()
	autosave_game()

func _on_day_changed(new_day: int):
	if load_in_progress:
		return
	if new_day > 1:
		autosave_game()

func _on_game_over(reason: String):
	save_game_state("game_over_save")


# === MAIN SAVE/LOAD ===

func save_game() -> bool:
	return save_game_state("manual_save")

func autosave_game() -> bool:
	return save_game_state("autosave", true)

func save_game_state(save_type: String = "manual_save", silent: bool = false) -> bool:
	if save_in_progress:
		if not silent:
			print("[SaveSystem] Save already in progress, skipping")
		return false

	save_in_progress = true

	if not silent:
		print("[SaveSystem] Saving (", save_type, ")...")

	var max_backups = int(DataManager.get_config("max_backup_files", 3))
	_create_save_backup(max_backups)

	var save_data = GameManager.get_save_data()

	save_data["schema_version"] = CURRENT_SCHEMA_VERSION
	save_data["save_type"] = save_type
	save_data["save_timestamp"] = Time.get_unix_time_from_system()
	save_data["save_date_string"] = Time.get_datetime_string_from_system()
	save_data["game_version"] = "1.0.0"
	save_data["total_playtime"] = _calculate_playtime()

	save_data["beer_shortage_days"] = GameManager.beer_shortage_days
	save_data["adventurer_morale"] = GameManager.adventurer_morale

	var success = _write_file_atomic(SAVE_FILE, save_data)

	save_in_progress = false
	save_completed.emit(success)

	if success:
		if not silent:
			print("[SaveSystem] Saved (", save_type, ")")
			if GameManager.has_method("log_message"):
				GameManager.log_message("Game saved")
	else:
		if not silent:
			print("[SaveSystem] Save FAILED")
		if GameManager.has_method("log_message"):
			GameManager.log_message("Save failed - check permissions")

	return success


func load_game() -> bool:
	if not has_save_file():
		print("[SaveSystem] No save file at: ", SAVE_FILE)
		return false

	print("[SaveSystem] Loading from: ", SAVE_FILE)

	var save_data = _read_json_file(SAVE_FILE)
	if save_data.is_empty():
		print("[SaveSystem] Failed to read save file or empty")
		return false

	save_data = _migrate_save_data(save_data)

	if not _validate_save_data(save_data):
		print("[SaveSystem] Validation failed")
		return false

	if not GameManager:
		print("[SaveSystem] GameManager not found")
		return false

	load_in_progress = true
	GameManager.load_save_data(save_data)
	load_in_progress = false

	print("[SaveSystem] Loaded Day ", save_data.get("current_day", 1))

	load_completed.emit(true)
	return true


# === CODEX (eternal cross-run persistence) ===

func _load_codex():
	if FileAccess.file_exists(CODEX_FILE):
		codex_data = _read_json_file(CODEX_FILE)
		if codex_data.is_empty():
			codex_data = _default_codex()
		print("[SaveSystem] Codex loaded: ", codex_data.keys().size(), " keys")
	else:
		codex_data = _default_codex()
		_save_codex()
		print("[SaveSystem] Codex created")

func _save_codex() -> bool:
	return _write_file_atomic(CODEX_FILE, codex_data)

func _default_codex() -> Dictionary:
	return {
		"schema_version": CURRENT_SCHEMA_VERSION,
		"fallen_heroes": [],
		"guild_achievements": [],
		"total_runs": 0,
		"best_day_reached": 0,
		"total_gold_earned": 0,
		"total_missions_completed": 0,
	}

func get_codex(key: String, fallback = null):
	return codex_data.get(key, fallback)

func set_codex(key: String, value) -> void:
	codex_data[key] = value

func save_codex() -> bool:
	return _save_codex()

func record_fallen_hero(adventurer: Dictionary) -> void:
	var entry = {
		"name": adventurer.get("name", "Unknown"),
		"class": adventurer.get("class", "Unknown"),
		"day_fallen": GameManager.current_day,
		"missions_completed": adventurer.get("missions_completed", 0),
		"timestamp": Time.get_unix_time_from_system(),
	}
	codex_data["fallen_heroes"].append(entry)
	_save_codex()

func record_run_end() -> void:
	codex_data["total_runs"] = codex_data.get("total_runs", 0) + 1
	var day = GameManager.current_day
	if day > codex_data.get("best_day_reached", 0):
		codex_data["best_day_reached"] = day
	codex_data["total_gold_earned"] = codex_data.get("total_gold_earned", 0) + GameManager.gold
	codex_data["total_missions_completed"] = codex_data.get("total_missions_completed", 0) + GameManager.total_missions_completed
	_save_codex()


# === SCHEMA MIGRATION ===

func _migrate_save_data(data: Dictionary) -> Dictionary:
	var version = int(data.get("schema_version", 0))

	if version == CURRENT_SCHEMA_VERSION:
		return data

	print("[SaveSystem] Migrating save from schema v", version, " to v", CURRENT_SCHEMA_VERSION)

	if version < 1:
		data["schema_version"] = 1
		print("[SaveSystem] v0 -> v1: added schema_version")

	return data


# === ATOMIC FILE I/O ===

func _write_file_atomic(filepath: String, data: Dictionary) -> bool:
	var tmp_path = filepath + ".tmp"

	var file = FileAccess.open(tmp_path, FileAccess.WRITE)
	if file == null:
		print("[SaveSystem] Cannot open tmp file: ", tmp_path)
		return false

	var json_string = JSON.stringify(data, "\t")
	file.store_string(json_string)
	file.close()

	var dir = DirAccess.open("user://")
	if dir == null:
		print("[SaveSystem] Cannot open user:// for rename")
		return false

	var fname = filepath.get_file()
	var tmp_fname = tmp_path.get_file()

	if dir.file_exists(fname):
		var err = dir.remove(fname)
		if err != OK:
			print("[SaveSystem] Cannot remove old file: ", err)
			return false

	var err = dir.rename(tmp_fname, fname)
	if err != OK:
		print("[SaveSystem] Rename failed: ", err)
		return false

	return true

func _read_json_file(filepath: String) -> Dictionary:
	if not FileAccess.file_exists(filepath):
		return {}

	var file = FileAccess.open(filepath, FileAccess.READ)
	if file == null:
		print("[SaveSystem] Cannot open: ", filepath, " error: ", FileAccess.get_open_error())
		return {}

	var json_text = file.get_as_text()
	file.close()

	if json_text.is_empty():
		return {}

	var json = JSON.new()
	var parse_result = json.parse(json_text)

	if parse_result != OK:
		print("[SaveSystem] JSON parse error in ", filepath, " line ", json.get_error_line(), ": ", json.get_error_message())
		return {}

	if not json.data is Dictionary:
		print("[SaveSystem] Parsed data is not Dictionary in: ", filepath)
		return {}

	return json.data


# === BACKUP SYSTEM ===

func _create_save_backup(max_backups: int = 3):
	if not FileAccess.file_exists(SAVE_FILE):
		return

	for i in range(max_backups - 1, 0, -1):
		var current_backup = SAVE_FILE + ".backup" + str(i)
		var next_backup = SAVE_FILE + ".backup" + str(i + 1)

		if FileAccess.file_exists(current_backup):
			if i == max_backups - 1:
				DirAccess.remove_absolute(next_backup)
			else:
				DirAccess.rename_absolute(current_backup, next_backup)

	var backup_path = SAVE_FILE + ".backup1"
	DirAccess.copy_absolute(SAVE_FILE, backup_path)

func restore_from_backup(backup_number: int = 1) -> bool:
	var backup_path = SAVE_FILE + ".backup" + str(backup_number)

	if not FileAccess.file_exists(backup_path):
		print("[SaveSystem] Backup not found: ", backup_path)
		return false

	DirAccess.copy_absolute(backup_path, SAVE_FILE)
	print("[SaveSystem] Restored from backup: ", backup_path)

	return load_game()


# === VALIDATION ===

func _validate_save_data(data: Dictionary) -> bool:
	var required_fields = ["current_day", "gold", "beer_stock", "adventurers"]

	for field in required_fields:
		if not data.has(field):
			print("[SaveSystem] Missing field: ", field)
			return false

	if not (data["current_day"] is int or data["current_day"] is float):
		print("[SaveSystem] current_day not numeric")
		return false

	if int(data["current_day"]) < 1:
		print("[SaveSystem] Invalid day: ", data["current_day"])
		return false

	if not (data["gold"] is int or data["gold"] is float):
		print("[SaveSystem] gold not numeric")
		return false

	if not data["adventurers"] is Array:
		print("[SaveSystem] adventurers not Array")
		return false

	return true


# === UTILITY ===

func has_save_file() -> bool:
	return FileAccess.file_exists(SAVE_FILE)

func get_save_info() -> Dictionary:
	if not has_save_file():
		return {}

	var save_data = _read_json_file(SAVE_FILE)
	if save_data.is_empty():
		return {}

	return {
		"day": save_data.get("current_day", 1),
		"gold": save_data.get("gold", 0),
		"adventurers": save_data.get("adventurers", []).size(),
		"save_date": save_data.get("save_date_string", "Unknown"),
		"save_type": save_data.get("save_type", "manual_save"),
		"playtime": save_data.get("total_playtime", 0),
		"schema_version": save_data.get("schema_version", 0),
	}

func _calculate_playtime() -> float:
	return (GameManager.current_day - 1) * 60.0

func delete_save_file() -> bool:
	if has_save_file():
		DirAccess.remove_absolute(SAVE_FILE)
		print("[SaveSystem] Save file deleted")
		return true
	return false

func delete_codex_file() -> bool:
	if FileAccess.file_exists(CODEX_FILE):
		DirAccess.remove_absolute(CODEX_FILE)
		codex_data = _default_codex()
		print("[SaveSystem] Codex file deleted")
		return true
	return false

func get_available_backups() -> Array:
	var max_backups = int(DataManager.get_config("max_backup_files", 3))
	var backups = []
	for i in range(1, max_backups + 1):
		var backup_path = SAVE_FILE + ".backup" + str(i)
		if FileAccess.file_exists(backup_path):
			var backup_data = _read_json_file(backup_path)
			if not backup_data.is_empty():
				backups.append({
					"number": i,
					"day": backup_data.get("current_day", 1),
					"date": backup_data.get("save_date_string", "Unknown"),
					"path": backup_path
				})
	return backups


# === DEBUG ===

func print_save_debug():
	print("=== SAVE SYSTEM DEBUG ===")
	print("Save file exists: ", has_save_file())
	print("Codex file exists: ", FileAccess.file_exists(CODEX_FILE))
	print("Save in progress: ", save_in_progress)
	print("Schema version: ", CURRENT_SCHEMA_VERSION)
	print("Available backups: ", get_available_backups().size())

	if has_save_file():
		var info = get_save_info()
		print("Save - Day: ", info.get("day"), ", Gold: ", info.get("gold"), ", Schema: ", info.get("schema_version"))

	print("Codex: ", codex_data)
	print("========================")

func force_save():
	print("[SaveSystem] DEBUG force save")
	save_game_state("debug_save")

func export_save_data() -> String:
	if not has_save_file():
		return "No save file found"

	var save_data = _read_json_file(SAVE_FILE)
	return JSON.stringify(save_data, "\t")
