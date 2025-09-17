extends Node

var character_classes: Dictionary = {}
var character_names: Array = []
var character_traits: Dictionary = {}
var mission_types: Dictionary = {}
var items: Dictionary = {}
var dialogue_lines: Dictionary = {}
var settlements: Dictionary = {}

signal data_ready

var daily_recruits: Array = []
var recruit_refresh_day: int = 1

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
	if character_classes.has(identifier):
		return character_classes[identifier]
	
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
	
	if character_classes.is_empty():
		print("Error: Cannot generate adventurers. Character classes not loaded.")
		return {}
	
	for i in range(number_to_generate):
		var new_adventurer = generateSingleAdventurer(i)
		
		if not new_adventurer.is_empty():
			var unique_key = new_adventurer.get("name", "Adventurer" + str(i))
			list_of_adventurers[unique_key] = new_adventurer
			
	return list_of_adventurers

func generateAvailableMissions() -> Array:
	var available_missions = []
	
	if mission_types.is_empty():
		print("Error: Mission types not loaded.")
		return []
	
	var missions_to_generate = 3
	var mission_templates = mission_types.get("mission_templates", [])
	
	if mission_templates.is_empty():
		print("No mission templates found")
		return []
	
	for i in range(missions_to_generate):
		if mission_templates.size() > 0:
			var random_mission = mission_templates[randi() % mission_templates.size()]
			available_missions.append(random_mission.duplicate())
	
	return available_missions

func generateSingleAdventurer(number: int) -> Dictionary:
	var adventurer_data = {}
	
	if character_classes.is_empty():
		print("Error: Character classes not loaded.")
		return {}
	
	var class_ids = character_classes.keys()
	
	if class_ids.is_empty():
		print("Error: No character classes available.")
		return {}
	
	var random_class_id = class_ids[randi() % class_ids.size()]
	var this_character_class = character_classes[random_class_id]
	var character_name = get_random_character_name()
	
	adventurer_data["name"] = character_name
	adventurer_data["class"] = this_character_class.get("display_name", "Unknown Class")
	adventurer_data["class_id"] = random_class_id
	
	print("Generated adventurer: ", adventurer_data)
	
	return adventurer_data

func generate_daily_missions(count: int = 6, settlement_type: String = "default") -> Array:
	"""Generate varied missions based on settlement type and current events"""
	var selected_missions = []
	
	if not mission_types.has("mission_templates"):
		print("❌ Mission templates not loaded!")
		return get_fallback_missions(count)
	
	var templates = mission_types["mission_templates"]
	var available_categories = get_available_categories(settlement_type)
	
	var category_targets = calculate_category_distribution(count, available_categories)
	
	for category in category_targets.keys():
		var category_count = category_targets[category]
		var category_missions = templates.filter(func(m): return m.get("category", "misc") == category)
		
		for i in category_count:
			if category_missions.size() > 0:
				var mission = category_missions[randi() % category_missions.size()].duplicate()
				
				apply_settlement_modifiers(mission, settlement_type)
				apply_seasonal_modifiers(mission)
				add_mission_variety(mission)
				
				selected_missions.append(mission)
	
	while selected_missions.size() < count:
		var random_mission = templates[randi() % templates.size()].duplicate()
		
		if not has_duplicate_mission(selected_missions, random_mission):
			apply_settlement_modifiers(random_mission, settlement_type)
			apply_seasonal_modifiers(random_mission)
			add_mission_variety(random_mission)
			selected_missions.append(random_mission)
	
	selected_missions.shuffle()
	
	print("✅ Generated ", selected_missions.size(), " varied missions for settlement type: ", settlement_type)
	return selected_missions

func get_available_categories(settlement_type: String) -> Array:
	"""Get mission categories available for this settlement type"""
	if not mission_types.has("settlement_modifiers"):
		return ["combat", "escort", "gathering", "investigation", "delivery", "construction"]
	
	var modifiers = mission_types["settlement_modifiers"]
	var settlement_config = modifiers.get(settlement_type, {})
	
	return settlement_config.get("available_categories", 
		["combat", "escort", "gathering", "investigation", "delivery", "construction"])

func calculate_category_distribution(total_missions: int, available_categories: Array) -> Dictionary:
	"""Calculate how many missions should come from each category"""
	var distribution = {}
	var missions_per_category = max(1, total_missions / available_categories.size())
	var remaining = total_missions
	
	for category in available_categories:
		var count = min(missions_per_category, remaining)
		distribution[category] = count
		remaining -= count
		
		if remaining <= 0:
			break
	
	while remaining > 0:
		var random_category = available_categories[randi() % available_categories.size()]
		distribution[random_category] = distribution.get(random_category, 0) + 1
		remaining -= 1
	
	return distribution

func apply_settlement_modifiers(mission: Dictionary, settlement_type: String):
	"""Apply settlement-specific modifiers to missions"""
	if not mission_types.has("settlement_modifiers"):
		return
	
	var modifiers = mission_types["settlement_modifiers"]
	var settlement_config = modifiers.get(settlement_type, {})
	
	var reward_multiplier = settlement_config.get("reward_multiplier", 1.0)
	if reward_multiplier != 1.0:
		mission.reward_range[0] = int(mission.reward_range[0] * reward_multiplier)
		mission.reward_range[1] = int(mission.reward_range[1] * reward_multiplier)
	
	var danger_increase = settlement_config.get("danger_increase", 0)
	var danger_decrease = settlement_config.get("danger_decrease", 0)
	mission.danger = clampi(mission.danger + danger_increase - danger_decrease, 1, 5)
	
	var category = mission.get("category", "misc")
	var category_bonus = settlement_config.get(category + "_bonus", 0.0)
	if category_bonus > 0.0:
		mission.reward_range[0] = int(mission.reward_range[0] * (1.0 + category_bonus))
		mission.reward_range[1] = int(mission.reward_range[1] * (1.0 + category_bonus))

func apply_seasonal_modifiers(mission: Dictionary):
	"""Apply seasonal event modifiers"""
	if not mission_types.has("seasonal_events"):
		return
	
	var seasonal_events = mission_types["seasonal_events"]
	var category = mission.get("category", "misc")
	
	if category == "gathering" and randf() < 0.3:
		var harvest_bonus = seasonal_events.get("harvest_season", {}).get("reward_bonus", 0.0)
		mission.reward_range[0] = int(mission.reward_range[0] * (1.0 + harvest_bonus))
		mission.reward_range[1] = int(mission.reward_range[1] * (1.0 + harvest_bonus))
		mission.description += " (Harvest season bonus!)"

func add_mission_variety(mission: Dictionary):
	"""Add randomized elements to make missions feel unique"""
	var base_name = mission.name
	var base_description = mission.get("description", "")
	
	var locations = ["the northern woods", "the eastern plains", "the mountain pass", 
					"the old ruins", "the merchant district", "the border regions",
					"the coastal road", "the ancient temple", "the forgotten mines"]
	
	var clients = ["a local merchant", "the town council", "a worried farmer", 
				  "the garrison commander", "a traveling scholar", "the guild master",
				  "a concerned citizen", "the village elder", "a mysterious stranger"]
	
	var urgency_modifiers = ["urgent", "time-sensitive", "routine", "critical", "standard"]
	
	if randf() < 0.4:
		var location = locations[randi() % locations.size()]
		mission.name = base_name + " (" + location + ")"
	
	if randf() < 0.6:
		var client = clients[randi() % clients.size()]
		mission.description = "Requested by " + client + ": " + base_description
	
	if randf() < 0.3:
		var urgency = urgency_modifiers[randi() % urgency_modifiers.size()]
		if urgency != "standard":
			mission.description += " [" + urgency.to_upper() + "]"

func has_duplicate_mission(missions: Array, new_mission: Dictionary) -> bool:
	"""Check if a mission with the same base ID already exists"""
	var new_id = new_mission.get("id", new_mission.name)
	
	for existing in missions:
		var existing_id = existing.get("id", existing.name)
		if existing_id == new_id:
			return true
	
	return false

func get_fallback_missions(count: int) -> Array:
	"""Fallback missions if JSON loading fails"""
	var fallback = [
		{"name": "Clear Slimes", "danger": 1, "reward_range": [5, 10], "party_required": false, "category": "combat"},
		{"name": "Escort Merchant", "danger": 2, "reward_range": [15, 25], "party_required": true, "category": "escort"},
		{"name": "Gather Herbs", "danger": 1, "reward_range": [8, 15], "party_required": false, "category": "gathering"},
		{"name": "Investigate Rumors", "danger": 2, "reward_range": [20, 30], "party_required": false, "category": "investigation"},
		{"name": "Deliver Package", "danger": 1, "reward_range": [10, 18], "party_required": false, "category": "delivery"},
		{"name": "Repair Bridge", "danger": 2, "reward_range": [25, 40], "party_required": true, "category": "construction"}
	]
	
	return fallback.slice(0, min(count, fallback.size()))

func get_missions_by_danger_range(min_danger: int, max_danger: int, count: int = 3) -> Array:
	"""Get missions within a specific danger range"""
	if not mission_types.has("mission_templates"):
		return []
	
	var templates = mission_types["mission_templates"]
	var filtered_missions = templates.filter(func(m): 
		return m.danger >= min_danger and m.danger <= max_danger)
	
	filtered_missions.shuffle()
	
	var selected = []
	for i in min(count, filtered_missions.size()):
		var mission = filtered_missions[i].duplicate()
		add_mission_variety(mission)
		selected.append(mission)
	
	return selected

func get_solo_missions(count: int = 3) -> Array:
	"""Get missions suitable for solo adventurers"""
	if not mission_types.has("mission_templates"):
		return []
	
	var templates = mission_types["mission_templates"]
	var solo_missions = templates.filter(func(m): return not m.get("party_required", false))
	
	solo_missions.shuffle()
	
	var selected = []
	for i in min(count, solo_missions.size()):
		var mission = solo_missions[i].duplicate()
		add_mission_variety(mission)
		selected.append(mission)
	
	return selected

func get_party_missions(count: int = 3) -> Array:
	"""Get missions requiring party cooperation"""
	if not mission_types.has("mission_templates"):
		return []
	
	var templates = mission_types["mission_templates"]
	var party_missions = templates.filter(func(m): return m.get("party_required", false))
	
	party_missions.shuffle()
	
	var selected = []
	for i in min(count, party_missions.size()):
		var mission = party_missions[i].duplicate()
		add_mission_variety(mission)
		selected.append(mission)
	
	return selected

func get_mission_chains() -> Array:
	"""Get available mission chains"""
	return mission_types.get("mission_chains", [])

func get_next_chain_mission(chain_id: String, completed_missions: Array) -> Dictionary:
	"""Get the next mission in a chain"""
	var chains = get_mission_chains()
	for chain in chains:
		if chain.get("chain_id") == chain_id:
			var chain_missions = chain.get("missions", [])
			break
	
	return {}
