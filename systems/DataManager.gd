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

var daily_recruits: Array = []
var patron_recruitment_pool: Array = []
var recruit_refresh_day: int = 1

var recruitment_config = {
	"daily_applicants_base": 2,
	"daily_applicants_variance": 2,
	"patron_recruitment_chance": 0.08,
	"patron_service_bonus": 0.12,
	"applicant_stay_duration": [2, 5],
	"guild_reputation_factor": 0.001
}



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


func create_default_dialogue() -> Dictionary:
	return {
		"regular_conversation": [
			"This beer is excellent! Where do you source it?",
			"I heard there's been strange activity near the eastern mountains...",
			"Business seems good here. You're doing well for yourself.",
			"Have you heard the latest news from the capital?",
			"Your guild has quite a reputation around these parts.",
			"This place has a welcoming atmosphere."
		],
		"recruitment_interest": [
			"You know, I've been thinking... This place has a good energy. Mind if I stick around and help out?",
			"I've heard you're looking for adventurers. I've got some experience...",
			"Your guild seems well-run. I'd be interested in joining, if you'll have me.",
			"I'm getting tired of just drinking here. How about I help you send others on adventures instead?"
		],
		"player_responses": [
			"Oh, you're looking for work? I do run an adventuring guild...",
			"Interesting. We're always looking for capable people.",
			"That's quite an offer. Let me tell you about our operations."
		]
	}
	
func create_default_names() -> Array:
	return [
		"Gareth", "Lyra", "Thorin", "Sera", "Marcus", "Elara", "Kael", "Mira", 
		"Dain", "Vera", "Bronn", "Nina", "Rex", "Thara", "Finn", "Cora", 
		"Tobias", "Runa", "Aldric", "Brenna", "Caelum", "Dara", "Ewen", "Fira"
	]

func generate_complete_character(source: String = "daily_applicant") -> Dictionary:
	"""Generate complete character using YOUR existing class structure"""
	var character = {}
	
	# Basic identity
	character.name = get_random_character_name()
	character.gender = "male" if randf() < 0.5 else "female"
	
	# Get class data from YOUR structure
	var class_info = get_random_class_from_your_data()
	character.class = class_info.display_name
	character.class_id = class_info.class_key
	character.description = class_info.description
	character.model_path = class_info.model_path
	
	# Generate stats using YOUR stat system
	character.merge(generate_stats_your_way(class_info))
	
	# Add personality and background
	character.merge(generate_personality_data())
	
	# Calculate cost using YOUR base_cost
	character.hiring_cost = calculate_cost_your_way(character, class_info)
	character.source = source
	character.availability_days = randi_range(2, 5)
	character.recruitment_day = GameManager.current_day
	character.id = generate_unique_id()
	
	# Adventure stats
	character.merge(get_base_adventure_stats())
	
	return character

func get_random_class_from_your_data() -> Dictionary:
	"""Get random class using YOUR JSON structure"""
	if character_classes.is_empty():
		return {"display_name": "Fighter", "description": "Basic warrior", "model_path": "", "base_cost": 15, "class_key": "Fighter"}
	
	var class_keys = character_classes.keys()
	var random_key = class_keys[randi() % class_keys.size()]
	var class_data = character_classes[random_key]
	
	return {
		"display_name": class_data.get("display_name", random_key),
		"description": class_data.get("description", "Adventurer"),
		"model_path": class_data.get("model_path", ""),
		"base_cost": class_data.get("base_cost", 15),
		"stat_bonuses": class_data.get("stat_bonuses", {}),
		"preferred_missions": class_data.get("preferred_missions", []),
		"class_key": random_key
	}

func generate_stats_your_way(class_info: Dictionary) -> Dictionary:
	"""Generate stats using YOUR stat bonus system"""
	var stats = {}
	var stat_bonuses = class_info.get("stat_bonuses", {})
	
	# Base stats (1-6) + your class bonuses
	for stat in ["strength", "dexterity", "intelligence", "endurance"]:
		var base_value = randi_range(1, 6)
		var bonus = stat_bonuses.get(stat, 0)
		stats[stat] = max(1, base_value + bonus)  # Ensure minimum 1
	
	return stats

func generate_personality_data() -> Dictionary:
	"""Generate personality traits"""
	var personalities = ["brave", "cautious", "greedy", "loyal", "cunning", "scholarly", "compassionate"]
	var motivations = ["gold", "glory", "knowledge", "adventure"]
	var backgrounds = [
		"Former city guard", "Wandering mercenary", "Village protector", 
		"Reformed thief", "Academy dropout", "Temple acolyte"
	]
	
	return {
		"personality": personalities[randi() % personalities.size()],
		"motivation": motivations[randi() % motivations.size()],
		"background": backgrounds[randi() % backgrounds.size()]
	}

func calculate_cost_your_way(character: Dictionary, class_info: Dictionary) -> int:
	"""Calculate hiring cost using YOUR base_cost system"""
	var base_cost = class_info.get("base_cost", 15)
	
	# Add cost based on total stats
	var stat_total = character.strength + character.dexterity + character.intelligence + character.endurance
	var stat_bonus = max(0, (stat_total - 20) * 1)  # Above average costs more
	
	# Personality modifiers
	var personality_cost = 0
	match character.personality:
		"loyal": personality_cost = 2
		"brave": personality_cost = 1
		"greedy": personality_cost = -1
		"cautious": personality_cost = -1
	
	return max(5, base_cost + stat_bonus + personality_cost)

func get_base_adventure_stats() -> Dictionary:
	return {
		"status": "Ready",
		"recovery": 0,
		"missions_completed": 0,
		"missions_failed": 0,
		"gold_earned": 0,
		"injuries_sustained": 0,
		"level": 1,
		"experience": 0
	}

func generate_unique_id() -> String:
	return "CHAR_" + str(Time.get_unix_time_from_system()) + "_" + str(randi() % 10000)

# RECRUITMENT SYSTEM FUNCTIONS

func generate_daily_applicants(count: int = -1) -> Array:
	"""Generate daily applicants"""
	if count == -1:
		count = recruitment_config.daily_applicants_base + randi_range(0, recruitment_config.daily_applicants_variance)
	
	var applicants = []
	
	for i in count:
		var applicant = generate_complete_character("daily_applicant")
		applicants.append(applicant)
	
	daily_recruits = applicants
	recruit_refresh_day = GameManager.current_day
	
	print("Generated ", applicants.size(), " daily applicants")
	return applicants

func check_patron_recruitment_interest(patron, was_well_served: bool = false) -> bool:
	"""Check if patron becomes interested in joining"""
	var base_chance = recruitment_config.patron_recruitment_chance
	var total_chance = base_chance
	
	if was_well_served:
		total_chance += recruitment_config.patron_service_bonus
	
	if randf() <= total_chance:
		var recruitment_data = generate_complete_character("patron_conversion")
		recruitment_data.patron_reference = patron
		recruitment_data.hiring_cost -= 3  # Loyalty discount
		recruitment_data.expires_time = Time.get_unix_time_from_system() + 600
		
		patron_recruitment_pool.append(recruitment_data)
		print("Patron ", patron.patron_name, " is interested in joining!")
		return true
	
	return false

func get_patron_recruitment_dialogue(recruitment_interest: bool = false) -> Dictionary:
	"""Get dialogue for patron interactions"""
	if recruitment_interest:
		var interest_lines = dialogue_lines.get("recruitment_interest", ["I'd like to join your guild..."])
		var player_responses = dialogue_lines.get("player_responses", ["Tell me more."])
		
		return {
			"patron_line": interest_lines[randi() % interest_lines.size()],
			"player_response": player_responses[randi() % player_responses.size()],
			"confirmation": "Perfect! I'd love to join if you'll have me."
		}
	else:
		var regular_lines = dialogue_lines.get("regular_conversation", ["Nice place you have here."])
		return {
			"patron_line": regular_lines[randi() % regular_lines.size()]
		}

func get_available_daily_applicants() -> Array:
	"""Get current valid daily applicants"""
	var current_applicants = []
	var current_day = GameManager.current_day
	
	for applicant in daily_recruits:
		var days_available = current_day - applicant.recruitment_day
		if days_available < applicant.availability_days:
			current_applicants.append(applicant)
	
	return current_applicants

func get_patron_opportunities() -> Array:
	"""Get current patron recruitment opportunities"""
	var current_time = Time.get_unix_time_from_system()
	var valid_opportunities = []
	
	for opportunity in patron_recruitment_pool:
		if current_time < opportunity.get("expires_time", current_time + 1):
			valid_opportunities.append(opportunity)
	
	patron_recruitment_pool = valid_opportunities
	return valid_opportunities

func remove_recruited_character(character_id: String):
	"""Remove character after hiring"""
	for i in range(daily_recruits.size() - 1, -1, -1):
		if daily_recruits[i].get("id") == character_id:
			daily_recruits.remove_at(i)
			break
	
	for i in range(patron_recruitment_pool.size() - 1, -1, -1):
		if patron_recruitment_pool[i].get("id") == character_id:
			patron_recruitment_pool.remove_at(i)
			break
