# File: systems/WorldManager.gd

# WorldManager.gd - Singleton Autoload
# Authoritative source for the current world state, including the map,
# settlements, and points of interest. It loads the core world data
# that the generator will use.
extends Node

# --- World State Data ---
var world_map: Array = []
var capitals: Array = []
var landmarks: Array = []
var chosen_center: Dictionary = {}   # the tavern_site hex the player picked
var overheard_rumours: Array = []    # Story 8.5 — eavesdropped rumours; drained by the Latest News feed (Epic 6)

# --- Loaded Game Data ---
var capital_definitions: Dictionary = {}
var faction_data: Dictionary = {}
const CAPITALS_DATA_PATH = "res://data/settlements/capitals.json"
const FACTIONS_DATA_PATH = "res://data/config/factions.json"


func _ready():
	_load_capital_definitions()
	load_faction_data()

# Called by the world map when the player confirms their tavern spot,
# and by GameManager.load_save_data() when restoring from a save file.
func set_generated_world(records: Array, center: Dictionary) -> void:
	world_map = records.duplicate(true)
	chosen_center = center.duplicate(true)
	print("[WorldManager] Stored world: ", world_map.size(), " hexes. Center: ", chosen_center.get("id", "?"))


func get_save_data() -> Dictionary:
	var serialized: Array = []
	for rec in world_map:
		var copy = rec.duplicate(true)
		var c = copy.get("coord")
		if c is Vector2i or c is Vector2:
			copy["coord"] = [c.x, c.y]
		serialized.append(copy)
	return {"world_map": serialized, "chosen_center": chosen_center.duplicate(true)}


func load_save_data(data: Dictionary) -> void:
	var records: Array = data.get("world_map", [])
	for rec in records:
		var c = rec.get("coord")
		if c is Array and c.size() == 2:
			rec["coord"] = Vector2i(int(c[0]), int(c[1]))
	world_map = records
	chosen_center = data.get("chosen_center", {})
	print("[WorldManager] Restored world: ", world_map.size(), " hexes")


func assign_missions_to_hexes(missions: Array) -> void:
	if world_map.is_empty():
		return
	# Clear old, non-locked assignments.
	for hex in world_map:
		if not hex.get("locked", false):
			hex["active_mission"] = null

	# Eligible hexes, each annotated with its hex-distance from the tavern.
	var center_coord := _center_coord()
	var eligible: Array = []
	for hex in world_map:
		if hex.get("is_center", false) or hex.get("is_zone", false) or hex.get("locked", false) or hex.get("biome", "") == "sea":
			continue
		eligible.append({"hex": hex, "d": _hex_distance(center_coord, _coord_of(hex))})
	if eligible.is_empty():
		return
	var max_d := 1
	for e in eligible:
		max_d = maxi(max_d, e["d"])

	# Place each mission near its "reach" — a distance that scales with the quest's
	# duration (and a little with danger). Short/easy quests land close to the tavern;
	# long/dangerous ones sit farther out. Fixes 1-day quests spawning across the map.
	var used := {}
	var placed := 0
	for mission in missions:
		var band := _distance_band_for(mission, max_d)
		var target := randf_range(band.x, band.y)
		var idx := _closest_unused_to(eligible, used, target)
		if idx == -1:
			break  # every eligible hex is taken
		eligible[idx]["hex"]["active_mission"] = mission
		used[idx] = true
		placed += 1
	print("[WorldManager] Assigned ", placed, " missions (distance-aware, max reach ", max_d, ") to hex tiles")


func _distance_band_for(mission: Dictionary, max_d: int) -> Vector2:
	# Reach grows ~linearly with quest length (hexes per travel-day) plus a touch of danger.
	# Tunable via game_config.json; sensible defaults so no config edit is required.
	var per_day: float = DataManager.get_config("mission_hexes_per_day", 3.0)
	var spread: float = DataManager.get_config("mission_distance_spread", 2.0)
	var dur := float(mission.get("duration_days", 1))
	var danger := float(mission.get("danger", 1))
	var reach := dur * per_day + (danger - 1.0)
	var lo := maxf(1.0, reach - spread)
	var hi := minf(reach + spread, float(max_d))
	if lo > hi:
		lo = hi
	return Vector2(lo, hi)


func _closest_unused_to(eligible: Array, used: Dictionary, target: float) -> int:
	# The free eligible hex whose distance is nearest `target`.
	var best := -1
	var best_diff := INF
	for i in eligible.size():
		if used.has(i):
			continue
		var diff: float = absf(float(eligible[i]["d"]) - target)
		if diff < best_diff:
			best_diff = diff
			best = i
	return best


func _center_coord() -> Vector2i:
	return _coord_to_vec(chosen_center.get("coord"))


func _coord_of(hex: Dictionary) -> Vector2i:
	return _coord_to_vec(hex.get("coord"))


func _coord_to_vec(c) -> Vector2i:
	if c is Vector2i:
		return c
	if c is Vector2:
		return Vector2i(int(c.x), int(c.y))
	if c is Array and c.size() == 2:
		return Vector2i(int(c[0]), int(c[1]))
	return Vector2i.ZERO


func _hex_distance(a: Vector2i, b: Vector2i) -> int:
	# Axial (q, r) → cube distance.
	var dq := a.x - b.x
	var dr := a.y - b.y
	return int((abs(dq) + abs(dq + dr) + abs(dr)) / 2.0)


# --- Data Loading ---
func _load_capital_definitions():
	"""
	Loads the main faction capitals from the JSON file. This is done once
	at startup. This keeps our world generation data-driven and easy to mod.
	"""
	if not FileAccess.file_exists(CAPITALS_DATA_PATH):
		print("WorldManager Error: capitals.json not found at %s" % CAPITALS_DATA_PATH)
		return

	var file = FileAccess.open(CAPITALS_DATA_PATH, FileAccess.READ)
	var content = JSON.parse_string(file.get_as_text())
	if content:
		capital_definitions = content
	else:
		print("WorldManager Error: Failed to parse capitals.json.")


func load_faction_data():
	if not FileAccess.file_exists(FACTIONS_DATA_PATH):
		print("[WorldManager] factions.json not found at ", FACTIONS_DATA_PATH)
		return
	var file = FileAccess.open(FACTIONS_DATA_PATH, FileAccess.READ)
	var content = JSON.parse_string(file.get_as_text())
	if content:
		faction_data = content
		print("[WorldManager] Factions loaded: ", faction_data.get("rival_guild_names", []).size(), " rivals, ", faction_data.get("biomes", []).size(), " biomes")
	else:
		print("[WorldManager] Failed to parse factions.json")
