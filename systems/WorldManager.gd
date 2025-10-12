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

# --- Loaded Game Data ---
var capital_definitions: Dictionary = {}
const CAPITALS_DATA_PATH = "res://data/settlements/capitals.json"


func _ready():
	print("capitals.json called.")
	_load_capital_definitions()

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
