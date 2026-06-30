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
	for hex in world_map:
		if not hex.get("locked", false):
			hex["active_mission"] = null
	var eligible: Array = []
	for hex in world_map:
		if hex["is_center"] or hex["is_zone"] or hex.get("locked", false) or hex.get("biome", "") == "sea":
			continue
		eligible.append(hex)
	eligible.shuffle()
	var count := mini(missions.size(), eligible.size())
	for i in count:
		eligible[i]["active_mission"] = missions[i]
	print("[WorldManager] Assigned ", count, " missions to hex tiles")


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
