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
const CAPITALS_DATA_PATH = "res://data/settlements/capitals.json"


func _ready():
	print("capitals.json called.")
	_load_capital_definitions()

# Called by the world map when the player confirms their tavern spot.
# Stores the generated layout in memory for the session. Saving to disk
# is a later step (gated on the load-game fix); this just stops the map
# from being thrown away on scene change.
func set_generated_world(records: Array, center: Dictionary) -> void:
	world_map = records.duplicate(true)
	chosen_center = center.duplicate(true)
	print("[WorldManager] Stored world: ", world_map.size(), " hexes. Center: ", chosen_center.get("id", "?"))


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
