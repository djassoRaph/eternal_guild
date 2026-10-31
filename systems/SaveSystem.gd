# SaveSystem.gd - Dual-file save architecture (savegame + codex)
extends Node

const SAVE_FILE = "user://eternal_guild_save.json"
const CODEX_FILE = "user://codex.dat"
const CURRENT_SCHEMA_VERSION = 2
# Story 25.9 replaced the Cleric with the Healer (one class list, six demo classes): old saves and
# codex entries are renamed on load (v1 -> v2), so they get the Healer's body, lines and bonus.
const RENAMED_CLASSES := {"Cleric": "Healer"}

# Story 11.2: the save this session reads and writes. Tests and Stage D runs point it at a copy, so they never
# touch the player's save.
var save_path: String = SAVE_FILE
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
	if not can_autosave():
		return
	autosave_triggered.emit()
	autosave_game()

## Story 11.2: the timer autosave runs only in a scene the save can resume into (the hall, outside: their roots are
## in the player_scene group). In the main menu it saved the menu as the resume scene (Continue then reopened the
## menu), and on a fresh launch the default Day-1 state over the player's run.
func can_autosave() -> bool:
	if not is_inside_tree():
		return false
	var cs := get_tree().current_scene
	return cs != null and cs.is_in_group("player_scene")

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

	var save_data = GameManager.get_save_data()

	save_data["schema_version"] = CURRENT_SCHEMA_VERSION
	save_data["save_type"] = save_type
	save_data["save_timestamp"] = Time.get_unix_time_from_system()
	save_data["save_date_string"] = Time.get_datetime_string_from_system()
	save_data["game_version"] = "1.0.0"
	save_data["total_playtime"] = _calculate_playtime()

	save_data["beer_shortage_days"] = GameManager.beer_shortage_days
	save_data["adventurer_morale"] = GameManager.adventurer_morale

	# Story 11.3: the backups rotate only once the new save is written and confirmed, just before it replaces the
	# old one, so a failed save leaves the save and every backup as they were.
	var success = _write_file_atomic(save_path, save_data, _create_save_backup.bind(_max_backups()))

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


## Story 11.2: reads the save (or its newest readable backup), applies it to GameManager and returns the state it
## applied (player_position / player_scene included; SaveSystem.player_spot() reads them), or {} when nothing could
## be loaded. Callers test .is_empty(), then go to resume_scene().
func load_game() -> Dictionary:
	var save_data := read_save()
	if save_data.is_empty():
		load_completed.emit(false)
		return {}

	load_in_progress = true
	GameManager.load_save_data(save_data)
	load_in_progress = false

	print("[SaveSystem] loaded: Day ", save_data.get("current_day", 1))

	load_completed.emit(true)
	return save_data


## Story 11.2: the save's state, migrated and validated, without applying it: the main file, else the newest
## readable backup (game-architecture: a corrupt save loads the most recent valid backup). {} when none is readable.
func read_save() -> Dictionary:
	var paths: Array[String] = [save_path]
	for i in range(1, _max_backups() + 1):
		paths.append(save_path + ".backup" + str(i))
	for i in paths.size():
		if not FileAccess.file_exists(paths[i]):
			continue
		print("[SaveSystem] Loading from: ", paths[i])
		var data := _read_json_file(paths[i])
		if data.is_empty():
			continue
		data = _migrate_save_data(data)
		if not _validate_save_data(data):
			continue
		if i > 0:
			push_warning("[SaveSystem] warn: save unreadable, loaded backup %d" % i)
		return data
	print("[SaveSystem] No readable save at: ", save_path)
	return {}


## Story 11.2: the player's saved spot as {"scene", "x", "y", "z"} (the save keeps player_position [x, y, z] and
## player_scene), or {} when the save has no position of three numbers.
static func player_spot(data: Dictionary) -> Dictionary:
	var p = data.get("player_position", [])
	if not (p is Array and p.size() == 3):
		return {}
	for c in p:
		if not (c is int or c is float):
			return {}
	var scene = data.get("player_scene", "")
	return {"scene": scene if scene is String else "", "x": float(p[0]), "y": float(p[1]), "z": float(p[2])}


# === RESUME (Story 11.2) ===

const DEFAULT_RESUME_SCENE := "res://scenes/MainTavern.tscn"   # its PlayerSpawnPoint is the New Game start
const WARN_SCENE_NOT_FOUND := "[SaveSystem] warn: saved scene not found, falling back to default spawn"

## Where a loaded save resumes. A saved scene that is empty, missing, or not a player scene (no player_scene group
## on its root: the main menu, the hex map) goes to the tavern's spawn point; the saved spot is dropped then, as it
## belongs to another scene. Pure, so the failsafe suite can walk the table: {scene, keep_spawn, warning}.
static func resume_target_for(saved: String, exists: bool, is_player: bool) -> Dictionary:
	if saved == "":
		return {"scene": DEFAULT_RESUME_SCENE, "keep_spawn": false, "warning": ""}
	if not exists:
		return {"scene": DEFAULT_RESUME_SCENE, "keep_spawn": false, "warning": WARN_SCENE_NOT_FOUND}
	if not is_player:
		return {"scene": DEFAULT_RESUME_SCENE, "keep_spawn": false,
			"warning": "[SaveSystem] warn: saved scene is not a player scene (%s), falling back to default spawn" % saved}
	return {"scene": saved, "keep_spawn": true, "warning": ""}


## True when the scene file's root is in the player_scene group (read from the PackedScene, not instanced).
static func is_player_scene(path: String) -> bool:
	if not (path.ends_with(".tscn") or path.ends_with(".scn")) or not ResourceLoader.exists(path):
		return false
	var ps = load(path)
	if not (ps is PackedScene):
		return false
	var st: SceneState = (ps as PackedScene).get_state()
	return st.get_node_count() > 0 and st.get_node_groups(0).has("player_scene")


## The scene Continue and the pause menu's Load change to after load_game(): the saved scene, or the tavern (with
## the warning, and PlayerManager's pending spot dropped).
func resume_scene() -> String:
	var saved: String = GameManager.saved_player_scene
	var exists := saved != "" and ResourceLoader.exists(saved)
	var t := resume_target_for(saved, exists, exists and is_player_scene(saved))
	if t.warning != "":
		push_warning(t.warning)
	if not t.keep_spawn:
		PlayerManager.clear_pending_spawn()
	return t.scene


func _max_backups() -> int:
	return maxi(1, int(DataManager.get_config("max_backup_files", 3)))


# === CODEX (eternal cross-run persistence) ===

func _load_codex():
	if FileAccess.file_exists(CODEX_FILE):
		codex_data = _read_json_file(CODEX_FILE)
		if codex_data.is_empty():
			codex_data = _default_codex()
		print("[SaveSystem] Codex loaded: ", codex_data.keys().size(), " keys")
		# In memory only: the codex file is rewritten with the next record, not on load.
		var renamed := rename_classes(codex_data)
		if renamed > 0:
			print("[SaveSystem] Migrated codex: %d retired class record(s) renamed (Cleric -> Healer)" % renamed)
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
		"artifacts_found": [],
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
	# Story 7.1 — the cemetery/memorial record, written at the moment of death (before the
	# reveal panels play) so a crash mid-reveal still leaves the codex correct.
	var adv_id = adventurer.get("id", -1)
	# Guard against double-recording the same hero if the death path is ever re-entered.
	if adv_id != -1:
		for existing in codex_data.get("fallen_heroes", []):
			if existing.get("id", -2) == adv_id:
				return
	var death_day = GameManager.current_day
	var entry = {
		"id": adv_id,
		"name": adventurer.get("name", "Unknown"),
		"class": adventurer.get("class", "Unknown"),
		"tarot_card": adventurer.get("tarot_card", ""),
		"hire_day": adventurer.get("hire_day", -1),
		"death_day": death_day,
		"day_fallen": death_day,  # legacy alias for pre-7.1 readers
		"missions_completed": adventurer.get("missions_completed", 0),
		"timestamp": Time.get_unix_time_from_system(),
	}
	codex_data["fallen_heroes"].append(entry)
	_save_codex()

func record_artifact_found(artifact_id: String) -> void:
	# Epic 12 — the artifact-tier loot record. Not attached to an adventurer (they die,
	# retire, age out); the guild's collection of relics is eternal, same as fallen_heroes.
	var def: Dictionary = DataManager.artifacts.get(artifact_id, {})
	var entry = {
		"id": artifact_id,
		"name": def.get("display_name", artifact_id),
		"description": def.get("description", ""),
		"found_day": GameManager.current_day,
		"timestamp": Time.get_unix_time_from_system(),
	}
	# codex.dat files written before this field existed won't have the key yet — _load_codex()
	# doesn't merge in new _default_codex() keys, it uses the file as-is (same latent gap
	# record_fallen_hero() has for fallen_heroes, just guarding against it explicitly here).
	if not codex_data.has("artifacts_found"):
		codex_data["artifacts_found"] = []
	codex_data["artifacts_found"].append(entry)
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
	# A junk or missing version reads as 0 (Story 11.2: int(null) would abort the load).
	var v = data.get("schema_version", 0)
	var version: int = int(v) if (v is int or v is float) else 0

	if version == CURRENT_SCHEMA_VERSION:
		return data

	if version > CURRENT_SCHEMA_VERSION:
		# Story 11.2: a save from a newer build loads best-effort; load_save_data() ignores the keys it doesn't know.
		print("[SaveSystem] Save schema v", version, " is newer than this build (v", CURRENT_SCHEMA_VERSION, "): loading known fields")
		return data

	print("[SaveSystem] Migrating save from schema v", version, " to v", CURRENT_SCHEMA_VERSION)

	if version < 1:
		data["schema_version"] = 1
		print("[SaveSystem] v0 -> v1: added schema_version")

	if version < 2:
		var renamed := rename_classes(data)
		data["schema_version"] = 2
		print("[SaveSystem] v1 -> v2: %d Cleric record(s) renamed to Healer" % renamed)

	return data


## Renames retired classes (RENAMED_CLASSES) in every "class" / "adventurer_class" value found anywhere
## in `data` (roster, recruits, mission entries and parties, reports, codex heroes). Returns the count.
static func rename_classes(data) -> int:
	var n := 0
	if data is Dictionary:
		for key in data:
			var v = data[key]
			if (key == "class" or key == "adventurer_class") and v is String and RENAMED_CLASSES.has(v):
				data[key] = RENAMED_CLASSES[v]
				n += 1
			elif v is Dictionary or v is Array:
				n += rename_classes(v)
	elif data is Array:
		for v in data:
			if v is Dictionary or v is Array:
				n += rename_classes(v)
	return n


# === ATOMIC FILE I/O ===

## Writes `data` to `filepath` through a .tmp file. Story 11.3: the tmp file is confirmed (no write error, every
## byte on disk: a full disk writes short) before the old file is touched; on any failure the tmp file is removed,
## the old file stays as it was and this returns false. `before_swap` runs between the confirmed write and the
## swap (the save's backup rotation).
func _write_file_atomic(filepath: String, data: Dictionary, before_swap := Callable()) -> bool:
	var tmp_path = filepath + ".tmp"

	var file = FileAccess.open(tmp_path, FileAccess.WRITE)
	if file == null:
		print("[SaveSystem] Cannot open tmp file: ", tmp_path, " (error ", FileAccess.get_open_error(), ")")
		return false

	var json_string: String = JSON.stringify(data, "\t")
	file.store_string(json_string)
	var write_err := file.get_error()
	file.close()
	if write_err != OK or not written_size_ok(tmp_path, json_string.to_utf8_buffer().size()):
		print("[SaveSystem] Write not confirmed: ", tmp_path, " (error ", write_err, "); the old file is kept")
		DirAccess.remove_absolute(tmp_path)
		return false

	if before_swap.is_valid():
		before_swap.call()

	# The file's own folder (Story 11.2: save_path may point below user://; renaming in user:// itself would hit
	# the player's save instead).
	var dir = DirAccess.open(filepath.get_base_dir())
	if dir == null:
		print("[SaveSystem] Cannot open ", filepath.get_base_dir(), " for rename")
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

## Story 11.3: true when the file at `path` holds exactly `expected` bytes (a short write or a missing file: false).
static func written_size_ok(path: String, expected: int) -> bool:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return false
	var n := f.get_length()
	f.close()
	return n == expected

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

## Shifts every backup one down (the oldest drops off) and copies the save to .backup1. Story 11.3: the old loop
## deleted .backup3 instead of moving .backup2 into it, so only two backups were ever kept.
func _create_save_backup(max_backups: int = 3):
	if not FileAccess.file_exists(save_path):
		return

	var oldest = save_path + ".backup" + str(max_backups)
	if FileAccess.file_exists(oldest):
		DirAccess.remove_absolute(oldest)
	for i in range(max_backups - 1, 0, -1):
		var current_backup = save_path + ".backup" + str(i)
		if FileAccess.file_exists(current_backup):
			DirAccess.rename_absolute(current_backup, save_path + ".backup" + str(i + 1))

	var backup_path = save_path + ".backup1"
	DirAccess.copy_absolute(save_path, backup_path)

func restore_from_backup(backup_number: int = 1) -> bool:
	var backup_path = save_path + ".backup" + str(backup_number)

	if not FileAccess.file_exists(backup_path):
		print("[SaveSystem] Backup not found: ", backup_path)
		return false

	DirAccess.copy_absolute(backup_path, save_path)
	print("[SaveSystem] Restored from backup: ", backup_path)

	return not load_game().is_empty()


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

## Story 11.2: a backup counts (load_game() falls back to it when the main file is missing or broken).
func has_save_file() -> bool:
	if FileAccess.file_exists(save_path):
		return true
	for i in range(1, _max_backups() + 1):
		if FileAccess.file_exists(save_path + ".backup" + str(i)):
			return true
	return false

func get_save_info() -> Dictionary:
	if not has_save_file():
		return {}

	var save_data = _read_json_file(save_path)
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
		DirAccess.remove_absolute(save_path)
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
		var backup_path = save_path + ".backup" + str(i)
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

	var save_data = _read_json_file(save_path)
	return JSON.stringify(save_data, "\t")
