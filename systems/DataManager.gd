extends Node

var character_classes: Dictionary = {}
var character_names: Array = []
var character_traits: Dictionary = {}
var mission_types: Dictionary = {}
var items: Dictionary = {}
var dialogue_lines: Dictionary = {}
var settlements: Dictionary = {}
signal data_ready

signal data_loaded(data_type: String)
signal data_modified(data_type: String, data: Dictionary)

func _ready():
	print("DataManager initialized")
	load_all_base_data()

func load_all_base_data():
	load_character_data()
	load_mission_data()
	load_economy_data()
	load_dialogue_data()
	load_settlement_data()
	print("All base data loaded")
	# Emit the signal after all data is loaded
	data_ready.emit()

func load_character_data():
	character_classes = load_data_file("res://data/characters/classes.json", {})
	character_names = load_data_file("res://data/characters/names.json", [])
	character_traits = load_data_file("res://data/characters/traits.json", {})
	data_loaded.emit("characters")

func load_mission_data():
	mission_types = load_data_file("res://data/missions/mission_types.json", {})
	data_loaded.emit("missions")

func load_economy_data():
	items = load_data_file("res://data/economy/items.json", {})
	data_loaded.emit("economy")

func load_dialogue_data():
	dialogue_lines = load_data_file("res://data/dialogue/patron_lines.json", {})
	data_loaded.emit("dialogue")

func load_settlement_data():
	settlements = load_data_file("res://data/settlements/locations.json", {})
	data_loaded.emit("settlements")

func load_data_file(path: String, fallback) -> Variant:
	if not FileAccess.file_exists(path):
		print("Data file not found: ", path, " - using fallback")
		return fallback
	
	var file = FileAccess.open(path, FileAccess.READ)
	if file == null:
		print("Cannot open data file: ", path)
		return fallback
	
	var json_text = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var parse_result = json.parse(json_text)
	
	if parse_result != OK:
		print("JSON parse error in: ", path)
		return fallback
	
	return json.data

func register_mod_data(mod_name: String, data_type: String, data: Dictionary):
	print("Mod registered data for: ", data_type)
	
	match data_type:
		"character_classes":
			character_classes.merge(data)
		"mission_types":
			mission_types.merge(data)
		"items":
			items.merge(data)
		"settlements":
			settlements.merge(data)
	
	data_modified.emit(data_type, data)

func get_random_character_name() -> String:
	if character_names.size() == 0:
		return "Unknown"
	return character_names[randi() % character_names.size()]

func get_character_class_data(identifier: String) -> Dictionary:
	# Try direct key lookup first (fastest)
	if character_classes.has(identifier):
		return character_classes[identifier]
	
	# Fallback: search by display name
	for class_id in character_classes:
		var class_data = character_classes[class_id]
		if class_data.get("display_name", "") == identifier:
			return class_data
	
	return {}

func get_mission_type_data(mission_type: String) -> Dictionary:
	return mission_types.get(mission_type, {})

func get_item_data(item_id: String) -> Dictionary:
	return items.get(item_id, {})

func get_dialogue_line(category: String, context: String = "default") -> String:
	var category_data = dialogue_lines.get(category, {})
	var context_lines = category_data.get(context, [])
	if context_lines.size() == 0:
		return "..."
	return context_lines[randi() % context_lines.size()]
	
	
func generateAvailableAdventurers(number_to_generate: int) -> Dictionary:
	var list_of_adventurers = {}
	
	# Check if character classes are loaded before starting
	if character_classes.is_empty():
		print("Error: Cannot generate adventurers. Character classes not loaded.")
		return {}
	
	for i in range(number_to_generate):
		# Call a function that generates a single adventurer
		var new_adventurer = generateSingleAdventurer(i)
		
		# Add the new adventurer to the dictionary using a unique key
		if not new_adventurer.is_empty():
			var unique_key = new_adventurer.get("name", "Adventurer" + str(i))
			list_of_adventurers[unique_key] = new_adventurer
			
	return list_of_adventurers
	
func generateAvailableMissions() -> Dictionary:
	var available_missions = {}
	
	# Check if mission types are loaded
	if mission_types.is_empty():
		print("Error: Mission types not loaded.")
		return {}
	
	var missions_to_generate = 3 # Or a number passed as an argument
	var mission_ids = mission_types.keys()
	
	for i in range(missions_to_generate):
		if mission_ids.is_empty():
			break # No missions to generate
		
		var random_id = mission_ids[randi() % mission_ids.size()]
		var mission_data = mission_types[random_id]
		
		# Use a unique key for each generated mission
		var mission_key = "mission_" + str(i)
		available_missions[mission_key] = mission_data
		
	return available_missions
	
	
		
func generateSingleAdventurer(number: int) -> Dictionary:
	var adventurer_data = {}
	# Check if character classes have been loaded
	if character_classes.is_empty():
		print("Error: Character classes not loaded.")
		return {}
	# Get a list of class IDs (dictionary keys)
	var class_ids = character_classes.keys()
	# Check if there are any classes available
	if class_ids.is_empty():
		print("Error: No character classes available.")
		return {}
	# Select a random class ID from the list
	var random_class_id = class_ids[randi() % class_ids.size()]
	var this_character_class = character_classes[random_class_id]
	var character_name = get_random_character_name()
	# Assemble the character's data into a dictionary
	adventurer_data["name"] = character_name
	adventurer_data["class"] = this_character_class.get("display_name", "Unknown Class")
	adventurer_data["class_id"] = random_class_id
	# You can add more attributes here, like stats or traits, based on your JSON data
	# adventurer_data["stats"] = this_character_class.get("base_stats", {})

	print("Generated adventurer: ", adventurer_data)
	
	return adventurer_data


func get_missions_by_category(category: String) -> Dictionary:
	var filtered_missions = {}
	for mission_id in mission_types:
		var mission_data = mission_types[mission_id]
		if mission_data.get("category", "general") == category:
			filtered_missions[mission_id] = mission_data
	return filtered_missions
	
	

func get_random_missions(category: String, count: int) -> Dictionary:
	var category_missions = get_missions_by_category(category)
	var random_missions = {}
	var mission_keys = category_missions.keys()
	
	for i in range(min(count, mission_keys.size())):
		var random_key = mission_keys[randi() % mission_keys.size()]
		random_missions[random_key] = category_missions[random_key]
		mission_keys.erase(random_key)  # Avoid duplicates
	
	return random_missions
