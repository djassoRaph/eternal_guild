# interactive.gd - ENHANCED VERSION with Patron-Recruitment Bridge
# Supports procedural world choice system and modding architecture
extends Node3D

@onready var bar_area = $BarArea
@onready var mission_area = $MissionBoard  
@onready var recruitment_area = $RecruitmentDesk
@onready var bedroom_area = $NextDayArea

# Player state tracking
var player_in_bedroom = false
var player_in_bar = false
var player_in_mission = false
var player_in_recruitment = false
var player_in_bedroomarea = false

# Enhanced patron interaction system
var current_patrons = []  # Track all active patrons
var patron_recruitment_pool = []  # Patrons interested in joining

func _ready():
	print("Enhanced Interactive System initializing...")
	print("Script attached to: ", get_path())
	
	print("bar_area: ", bar_area)
	print("mission_area: ", mission_area) 
	print("recruitment_area: ", recruitment_area)
	print("nextday_area: ", bedroom_area)
	
	# Connect area signals
	setup_interaction_areas()
	
	# Initialize patron tracking system
	setup_patron_tracking()
	
	send_log_message("Enhanced Interactive areas connected!")

func setup_interaction_areas():
	"""Connect all interaction area signals"""
	bar_area.body_entered.connect(_on_bar_entered)
	bar_area.body_exited.connect(_on_bar_exited)
	
	bedroom_area.body_entered.connect(_on_nextday_entered)
	bedroom_area.body_exited.connect(_on_nextday_exited)
	
	mission_area.body_entered.connect(_on_mission_entered)
	mission_area.body_exited.connect(_on_mission_exited)
	
	recruitment_area.body_entered.connect(_on_recruitment_entered)
	recruitment_area.body_exited.connect(_on_recruitment_exited)

func setup_patron_tracking():
	"""Initialize patron tracking system for recruitment integration"""
	# Get reference to PatronSpawner if it exists
	var patron_spawner = get_node_or_null("../PatronSpawner")
	if patron_spawner:
		print("Connected to PatronSpawner for enhanced interactions")
		# Note: In future, connect to patron spawn/despawn signals
	else:
		print("PatronSpawner not found - will search manually for patrons")

func _input(event):
	if event.is_action_pressed("interact"):
		handle_interaction_priority()

func handle_interaction_priority():
	"""Handle E key with priority: Patrons > Zone interactions"""
	var player = get_node("/root/Node3D/SubViewportContainer/SubViewport/Player")
	if not player:
		print("❌ Player not found!")
		return
	
	# PRIORITY 1: Try to serve nearby patrons
	var served_patron = try_serve_nearby_patron(player)
	if served_patron:
		print("✅ Served a patron!")
		return  # Exit early, don't check zone interactions
	
	# PRIORITY 2: Try to chat with served patrons for recruitment
	var chat_patron = try_chat_with_patron(player)
	if chat_patron:
		print("💬 Started conversation with patron!")
		return
		
	# PRIORITY 3: Zone-based interactions
	handle_zone_interactions()

func try_serve_nearby_patron(player) -> bool:
	"""Try to serve patrons needing service"""
	if player and player.has_method("try_serve_nearby_patron"):
		var served = player.try_serve_nearby_patron()
		return served != null
	return false

func try_chat_with_patron(player) -> bool:
	"""Try to chat with patrons who have been served (NEW FEATURE)"""
	var nearby_patrons = find_nearby_patrons(player.global_position)
	
	for patron in nearby_patrons:
		if patron.has_method("can_chat") and patron.can_chat():
			initiate_patron_conversation(patron)
			return true
	return false

func find_nearby_patrons(player_position: Vector3) -> Array:
	"""Find all patrons within interaction range - MISSING FUNCTION IMPLEMENTED"""
	var nearby = []
	var interaction_distance = 3.0
	
	# Method 1: Check PatronSpawner children
	var patron_spawner = get_node_or_null("../PatronSpawner")
	if patron_spawner:
		for child in patron_spawner.get_children():
			if child.has_method("get_global_position"):  # Duck typing for patron-like objects
				var distance = player_position.distance_to(child.global_position)
				if distance <= interaction_distance:
					nearby.append(child)
					print("Found nearby patron at distance: ", distance)
	
	# Method 2: Search scene tree if no spawner found
	if nearby.size() == 0:
		search_tree_for_nearby_patrons(get_tree().current_scene, player_position, interaction_distance, nearby)
	
	print("Found ", nearby.size(), " nearby patrons")
	return nearby

func search_tree_for_nearby_patrons(node: Node, player_pos: Vector3, max_distance: float, result_array: Array):
	"""Recursively search for patron nodes near player"""
	if node.has_method("get_global_position"):
		var distance = player_pos.distance_to(node.global_position)
		if distance <= max_distance and is_patron_node(node):
			result_array.append(node)
	
	# Search children
	for child in node.get_children():
		search_tree_for_nearby_patrons(child, player_pos, max_distance, result_array)

func is_patron_node(node: Node) -> bool:
	"""Check if node is a patron (RealisticPatron or similar)"""
	return node.get_script() != null and (
		"Patron" in str(node.get_script()) or 
		node.has_method("can_be_served_by") or
		node.has_method("serve")
	)

func initiate_patron_conversation(patron) -> void:
	"""Start conversation with patron for potential recruitment"""
	print("💬 Starting conversation with ", patron.get("patron_name", "Patron"))
	
	# Roll for recruitment interest (30% chance)
	if randf() < 0.3:
		make_patron_recruitment_interested(patron)
	else:
		show_casual_patron_chat(patron)

func make_patron_recruitment_interested(patron):
	"""Mark patron as interested in joining guild"""
	print("🌟 Patron shows interest in joining your guild!")
	
	# Create recruitment candidate data
	var recruitment_candidate = create_recruitment_candidate_from_patron(patron)
	patron_recruitment_pool.append(recruitment_candidate)
	
	# Mark patron as converted
	if patron.has_method("set_recruitment_status"):
		patron.set_recruitment_status("interested")
	
	send_log_message("\"Your guild intrigues me... Perhaps we could discuss employment?\"")
	send_log_message("💡 Visit the recruitment desk to hire interested patrons!")

func create_recruitment_candidate_from_patron(patron) -> Dictionary:
	"""Convert patron to recruitment candidate with discount"""
	var candidate = {
		"id": randi() % 10000 + 2000,  # Different ID range
		"name": patron.get("patron_name", generate_random_name()),
		"class": get_random_class(),
		"source": "patron_conversion",
		"loyalty_discount": 0.25,  # 25% discount for patron loyalty
		"availability_window": 3,  # Available for 3 days
		"conversation_history": ["Met at tavern"],
		"personality": get_patron_personality(),
		"background": get_patron_background(),
		"motivation": "Impressed by guild hospitality"
	}
	
	# Generate stats with slight bonus for being a paying customer
	add_character_stats(candidate)
	candidate["hiring_cost"] = calculate_patron_hiring_cost(candidate)
	
	return candidate

func show_casual_patron_chat(patron):
	"""Show casual conversation with patron"""
	var casual_lines = [
		"\"This is a fine establishment you run here!\"",
		"\"The beer is excellent, thank you.\"",
		"\"I've heard tales of your adventurers' exploits.\"",
		"\"Safe travels to you, guildmaster.\"",
		"\"May fortune smile upon your ventures.\"",
		"\"This tavern has such a welcoming atmosphere!\""
	]
	var line = casual_lines[randi() % casual_lines.size()]
	send_log_message(line)

func handle_zone_interactions():
	"""Handle zone-based interactions (existing functionality)"""
	print("🔑 E key detected! Checking zones...")
	
	if player_in_bar:
		open_beer_management()
	elif player_in_mission:
		open_mission_board()
	elif player_in_recruitment:
		open_recruitment_desk()
	elif player_in_bedroom:
		advance_day()

func open_beer_management():
	"""Open beer management popup"""
	print("🍺 Attempting to open beer popup...")
	var beer_popup = get_node("/root/Node3D/GameUI/PopupManager/BeerManagementPopup")
	if beer_popup:
		print("✅ Calling open_beer_management...")
		beer_popup.open_beer_management()
		send_log_message("Looking at your stock")
	else:
		print("❌ Beer popup not found!")

func open_mission_board():
	"""Open mission board with adventurer check"""
	var adventurer_count = GameManager.get_adventurer_count()
	if adventurer_count == 0:
		send_log_message("❌ You need to hire adventurers before checking the mission board!")
		send_log_message("💡 Visit the recruitment desk first.")
		return
	
	print("📋 Opening mission board...")
	var mission_popup = get_node("/root/Node3D/GameUI/PopupManager/MissionBoardPopup")
	if mission_popup:
		mission_popup.open_mission_board()
		send_log_message("Reviewing available missions")
	else:
		print("❌ Mission popup not found!")

func open_recruitment_desk():
	"""Open recruitment desk with patron integration"""
	print("👥 Opening recruitment desk...")
	var recruitment_popup = get_node("/root/Node3D/GameUI/PopupManager/RecruitmentPopup")
	if recruitment_popup:
		# Pass patron recruitment pool to popup (future enhancement)
		recruitment_popup.open_recruitment_desk()
		send_log_message("Reviewing potential recruits")
	else:
		print("❌ Recruitment popup not found!")

func advance_day():
	"""Handle day advancement"""
	print("🌙 Advancing to next day...")
	if GameManager.has_method("advance_day"):
		GameManager.advance_day()
		# Clear expired patron recruitment candidates
		cleanup_expired_recruitment_candidates()
	
	send_log_message("You rest for the night and prepare for tomorrow's challenges.")

func cleanup_expired_recruitment_candidates():
	"""Remove expired patron recruitment candidates"""
	patron_recruitment_pool = patron_recruitment_pool.filter(func(candidate): 
		candidate.availability_window -= 1
		return candidate.availability_window > 0
	)

# === AREA ENTER/EXIT HANDLERS ===
func _on_bar_entered(body):
	if body.name == "Player":
		player_in_bar = true
		print("Player entered bar area")

func _on_bar_exited(body):
	if body.name == "Player":
		player_in_bar = false
		print("Player left bar area")

func _on_mission_entered(body):
	if body.name == "Player":
		player_in_mission = true
		print("Player entered mission area")

func _on_mission_exited(body):
	if body.name == "Player":
		player_in_mission = false
		print("Player left mission area")

func _on_recruitment_entered(body):
	if body.name == "Player":
		player_in_recruitment = true
		print("Player entered recruitment area")

func _on_recruitment_exited(body):
	if body.name == "Player":
		player_in_recruitment = false
		print("Player left recruitment area")

func _on_nextday_entered(body):
	if body.name == "Player":
		player_in_bedroom = true
		print("Player entered bedroom area")

func _on_nextday_exited(body):
	if body.name == "Player":
		player_in_bedroom = false
		print("Player left bedroom area")

# === UTILITY FUNCTIONS FOR RECRUITMENT SYSTEM ===
func generate_random_name() -> String:
	"""Generate random name for patron-turned-recruit"""
	var names = ["Aelred", "Brigid", "Caius", "Delara", "Ewan", "Fiona", "Gareth", "Hilda", "Ivan", "Jora", "Kael", "Liora", "Magnus", "Nora", "Oswin", "Petra", "Quinn", "Rhea", "Soren", "Tara"]
	return names[randi() % names.size()]

func get_random_class() -> String:
	"""Get random class for patron conversion"""
	var classes = ["Fighter", "Rogue", "Mage", "Healer", "Barbarian", "Ranger"]
	return classes[randi() % classes.size()]

func get_patron_personality() -> String:
	"""Get personality trait for patron"""
	var personalities = ["Grateful", "Loyal", "Experienced", "Worldly", "Reliable", "Sociable", "Observant", "Diplomatic"]
	return personalities[randi() % personalities.size()]

func get_patron_background() -> String:
	"""Get background for patron-turned-recruit"""
	var backgrounds = [
		"Former tavern regular",
		"Traveling merchant",
		"Retired city guard",
		"Wandering scholar",
		"Local tradesperson",
		"Former soldier seeking purpose"
	]
	return backgrounds[randi() % backgrounds.size()]

func add_character_stats(character: Dictionary):
	"""Add randomized stats to character"""
	character["strength"] = randi() % 5 + 2  # 2-6, slightly better than pure random
	character["dexterity"] = randi() % 5 + 2
	character["intelligence"] = randi() % 5 + 2
	character["endurance"] = randi() % 5 + 2
	
	# Apply class bonuses
	match character.class:
		"Fighter":
			character.strength += 2
			character.endurance += 1
		"Rogue":
			character.dexterity += 2
			character.intelligence += 1
		"Mage":
			character.intelligence += 2
		"Healer":
			character.intelligence += 1
			character.endurance += 1
		"Barbarian":
			character.strength += 3
		"Ranger":
			character.dexterity += 1
			character.endurance += 1

func calculate_patron_hiring_cost(candidate: Dictionary) -> int:
	"""Calculate hiring cost with patron loyalty discount"""
	var base_cost = 15  # Slightly higher base than random applicants
	var stat_total = candidate.strength + candidate.dexterity + candidate.intelligence + candidate.endurance
	var stat_bonus = (stat_total - 18) * 2
	
	var class_bonus = 0
	match candidate.class:
		"Fighter": class_bonus = 0
		"Rogue": class_bonus = 3
		"Mage": class_bonus = 6
		"Healer": class_bonus = 10
		"Barbarian": class_bonus = 2
		"Ranger": class_bonus = 4
	
	var total_cost = base_cost + stat_bonus + class_bonus
	
	# Apply loyalty discount
	var discounted_cost = int(total_cost * (1.0 - candidate.loyalty_discount))
	
	return max(8, discounted_cost)  # Minimum cost

func send_log_message(message: String):
	"""Send message to GameManager logging system"""
	if GameManager.has_method("log_message"):
		GameManager.log_message(message)
	else:
		print("LOG: ", message)

# === DEBUG FUNCTIONS ===
func _input_debug(event):
	"""Debug functions for testing"""
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_F9:  # Debug patron recruitment
			debug_patron_recruitment()

func debug_patron_recruitment():
	"""Debug function to test patron recruitment system"""
	print("=== PATRON RECRUITMENT DEBUG ===")
	print("Current recruitment pool size: ", patron_recruitment_pool.size())
	for candidate in patron_recruitment_pool:
		print("- ", candidate.name, " (", candidate.class, ") - ", candidate.hiring_cost, "g")
	print("================================")

func get_patron_recruitment_pool() -> Array:
	"""Get current patron recruitment candidates"""
	return patron_recruitment_pool

func clear_patron_recruitment_pool():
	"""Clear all patron recruitment candidates (for testing)"""
	patron_recruitment_pool.clear()
	print("Patron recruitment pool cleared")
