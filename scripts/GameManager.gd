# GameManager.gd - Autoload Singleton
extends Node

# === CORE GAME STATE ===
var gold: int = 30
var beer_stock: int = 5
var current_day: int = 1
var max_adventurers: int = 5
var adventurers: Array = []
var available_missions: Array = []  # Changed from Dictionary to Array
var recruitment_manager = null
var patron_recruitment_pool = []  # Patrons interested in joining

# === ECONOMIC SETTINGS ===
var tax_due_day: int = 30
var daily_operating_cost: int = 1

# === UI UPDATE SIGNALS ===
signal gold_changed(new_amount: int)
signal beer_changed(new_amount: int)  
signal day_changed(new_day: int)
signal adventurer_roster_changed()
signal missions_changed
signal recruitment_pool_changed
signal game_over_triggered(reason: String)

var mission_refresh_day: int = 1
var recruit_refresh_day: int = 1
var daily_recruits: Array = []
var game_over_active: bool = false

# === INITIALIZATION ===
func _ready():
	print("🎮 GameManager singleton initialized")
	print("Initial state - Gold: ", gold, " Beer: ", beer_stock, " Day: ", current_day)
	DataManager.data_ready.connect(_on_data_ready)

func _on_data_ready():
	refresh_missions()

func refresh_missions():
	print("DEBUG: refresh_missions() called on day ", current_day)
	available_missions = DataManager.generateAvailableMissions()
	print("DEBUG: Generated missions: ", available_missions.size())
	log_message("New guild contracts have been posted!")

# === GOLD MANAGEMENT ===
func add_gold(amount: int):
	"""Add gold and notify all systems"""
	gold += amount
	gold_changed.emit(gold)
	print("💰 Added ", amount, " gold. Total: ", gold)

func spend_gold(amount: int) -> bool:
	"""Spend gold if sufficient funds available"""
	if gold >= amount:
		gold -= amount
		gold_changed.emit(gold)
		print("💸 Spent ", amount, " gold. Remaining: ", gold)
		return true
	else:
		print("❌ Insufficient gold. Need ", amount, " but have ", gold)
		return false

func get_gold() -> int:
	"""Get current gold amount"""
	return gold

# === BEER MANAGEMENT ===
func add_beer(amount: int):
	"""Add beer stock and notify systems"""
	beer_stock += amount
	beer_changed.emit(beer_stock)
	print("🍺 Added ", amount, " beer. Total: ", beer_stock)

func consume_beer(amount: int) -> bool:
	"""Consume beer if available"""
	if beer_stock >= amount:
		beer_stock -= amount
		beer_changed.emit(beer_stock)
		print("🍻 Consumed ", amount, " beer. Remaining: ", beer_stock)
		return true
	else:
		print("❌ Insufficient beer. Need ", amount, " but have ", beer_stock)
		return false

func get_beer() -> int:
	"""Get current beer stock"""
	return beer_stock

# === DAY MANAGEMENT ===
func get_day() -> int:
	"""Get current day number"""
	return current_day

func get_adventurer_count() -> int:
	"""Get total number of adventurers"""
	return adventurers.size()

func get_ready_adventurers() -> Array:
	"""Get adventurers available for missions"""
	var ready = []
	for adv in adventurers:
		if adv.status == "Ready":
			ready.append(adv)
	return ready

func get_max_adventurers() -> int:
	"""Get maximum adventurer capacity"""
	return max_adventurers

# === MISSION SYSTEM ===
func complete_mission(adventurer: Dictionary, mission: Dictionary, success: bool):
	"""Handle mission completion"""
	if success:
		var reward = randi_range(mission.reward_range[0], mission.reward_range[1])
		add_gold(reward)
		adventurer.missions_completed += 1
		adventurer.gold_earned += reward
		log_message("✅ SUCCESS! " + adventurer.name + " completed " + mission.name + " and earned " + str(reward) + " gold!")
	else:
		adventurer.missions_failed += 1
		log_message("💥 FAILED! " + adventurer.name + " failed the mission: " + mission.name)
		
		# Handle injury chance
		if randf() < (mission.danger * 0.15):
			adventurer.status = "Injured"
			adventurer.recovery = randi_range(1, 3)
			adventurer.injuries_sustained += 1
			log_message("🏥 " + adventurer.name + " was injured and needs " + str(adventurer.recovery) + " days to recover")

func complete_party_mission(party: Array, mission: Dictionary, success: bool, healer_count: int):
	"""Handle party mission completion"""
	if success:
		var reward = randi_range(mission.reward_range[0], mission.reward_range[1])
		add_gold(reward)
		log_message("✅ PARTY SUCCESS! Completed " + mission.name + " and earned " + str(reward) + " gold!")
		
		for adventurer in party:
			adventurer.status = "Ready"
			adventurer.missions_completed += 1
			adventurer.gold_earned += reward / party.size()
	else:
		log_message("💥 PARTY FAILED! Mission " + mission.name + " was unsuccessful")
		
		for adventurer in party:
			adventurer.missions_failed += 1
			
			# Healer protection
			if healer_count > 0 and randf() < 0.7:
				adventurer.status = "Ready"
				log_message(adventurer.name + " was protected by the party healer")
			elif randf() < (mission.danger * 0.2):
				adventurer.status = "Injured"
				adventurer.recovery = randi_range(1, 3)
				adventurer.injuries_sustained += 1
				log_message(adventurer.name + " was injured and needs recovery")
			else:
				adventurer.status = "Ready"

# === DAILY PROCESSING ===
func process_mission_returns():
	"""Handle adventurers returning from missions"""
	for adventurer in adventurers:
		if adventurer.status == "on_mission":
			adventurer.status = "Ready"
			log_message(adventurer.name + " returns from their mission")

func process_daily_operations():
	"""Handle daily costs and maintenance"""
	var base_cost = daily_operating_cost
	var adventurer_wages = adventurers.size() * 1  # 1 gold per adventurer per day
	var total_cost = base_cost + adventurer_wages
	
	# Beer consumption by adventurers
	var beer_needed = adventurers.size() * 1  # 1 beer per adventurer per day
	
	if spend_gold(total_cost):
		log_message("Paid " + str(total_cost) + " gold in daily costs (" + str(base_cost) + " operations + " + str(adventurer_wages) + " wages)")
	else:
		log_message("WARNING: Could not afford operating costs!")
	
	# Adventurers consume beer
	if beer_needed > 0:
		if consume_beer(beer_needed):
			log_message("Adventurers consumed " + str(beer_needed) + " beer")
		else:
			log_message("WARNING: Insufficient beer for adventurers! Morale will suffer.")
			# Apply morale penalty (implement this later)

func process_customer_visits():
	"""Handle tavern customers and beer sales"""
	var customer_count = randi_range(2, 5) + min(adventurers.size(), 3)
	var beer_sold = min(customer_count, beer_stock)
	var sales_income = beer_sold * 6  # 6 gold per beer
	
	if beer_sold > 0:
		consume_beer(beer_sold)
		add_gold(sales_income)
		log_message(str(customer_count) + " customers visited the tavern")
		log_message("Sold " + str(beer_sold) + " beer for " + str(sales_income) + " gold")
		
		if beer_sold < customer_count:
			log_message("WARNING: " + str(customer_count - beer_sold) + " customers left disappointed!")
	else:
		log_message(str(customer_count) + " customers visited but you had no beer!")

func process_adventurer_recovery():
	"""Handle injured adventurer recovery"""
	for adventurer in adventurers:
		if adventurer.status == "Injured" and adventurer.has("recovery"):
			adventurer.recovery -= 1
			if adventurer.recovery <= 0:
				adventurer.status = "Ready"
				adventurer.erase("recovery")
				log_message(adventurer.name + " has recovered from injuries!")

func check_tax_deadline():
	"""Monitor tax payment deadlines"""
	var days_until_tax = tax_due_day - current_day
	
	if days_until_tax == 5:
		log_message("NOTICE: Tax payment due in 5 days! Need 50 gold")
	elif days_until_tax == 1:
		log_message("URGENT: Tax payment due TOMORROW! Need 50 gold")
	elif days_until_tax <= 0:
		handle_tax_payment()

func handle_tax_payment():
	"""Process tax payment with proper game over"""
	var tax_amount = 50 + (adventurers.size() * 5)
	
	if spend_gold(tax_amount):
		tax_due_day += 30
		log_message("Successfully paid " + str(tax_amount) + " gold in taxes")
		log_message("Next tax payment due on day " + str(tax_due_day))
	else:
		# Trigger game over instead of just logging
		trigger_game_over("bankruptcy", "Could not pay taxes of " + str(tax_amount) + " gold")
		
		
# === LOGGING SYSTEM ===
func log_message(message: String):
	"""Send message to game log"""
	print("LOG: ", message)
	
	# Try to find and update the event log
	var main_scene = get_tree().current_scene
	if main_scene and main_scene.has_method("log_message"):
		main_scene.log_message(message)

# === RECRUITMENT SYSTEM ===
func generate_daily_recruits(count: int = 3):
	"""Generate new recruits for the day"""
	daily_recruits.clear()
	
	print("🔄 Generating ", count, " new recruits for day ", current_day)
	daily_recruits = generate_fallback_recruits(count)
	recruit_refresh_day = current_day
	
	# Log the new recruits
	log_message("📢 New adventurers seeking employment at the guild!")
	for recruit in daily_recruits:
		var cost = recruit.get("hiring_cost", 10)
		log_message("• " + recruit.name + " the " + recruit.class + " (Hiring cost: " + str(cost) + " gold)")

func generate_fallback_recruits(count: int) -> Array:
	"""Generate recruits when DataManager is not available"""
	var recruits = []
	var classes = ["Fighter", "Rogue", "Mage", "Ranger", "Cleric"]
	var names = ["Thara", "Bronn", "Lysa", "Gareth", "Mira", "Dain", "Vera", "Kael", "Nina", "Rex"]
	
	for i in count:
		var recruit = {
			"id": generate_recruit_id(),
			"name": names[randi() % names.size()],
			"class": classes[randi() % classes.size()],
			"status": "Ready",
			"recovery": 0,
			"missions_completed": 0,
			"missions_failed": 0,
			"gold_earned": 0,
			"injuries_sustained": 0
		}
		
		# Generate random stats
		recruit.strength = randi_range(2, 8)
		recruit.dexterity = randi_range(2, 8) 
		recruit.intelligence = randi_range(2, 8)
		recruit.endurance = randi_range(2, 8)
		
		# Class-based stat adjustments
		match recruit.class:
			"Fighter":
				recruit.strength += 2
				recruit.endurance += 1
			"Rogue":
				recruit.dexterity += 2
				recruit.intelligence += 1
			"Mage":
				recruit.intelligence += 2
				recruit.dexterity += 1
			"Ranger":
				recruit.dexterity += 1
				recruit.endurance += 1
				recruit.intelligence += 1
			"Cleric":
				recruit.intelligence += 1
				recruit.endurance += 2
		
		# Calculate hiring cost based on stats
		var stat_total = recruit.strength + recruit.dexterity + recruit.intelligence + recruit.endurance
		recruit.hiring_cost = max(8, stat_total * 2 + randi_range(-5, 10))
		
		# Add personality and background flavor
		var personalities = ["Brave", "Cautious", "Greedy", "Noble", "Mysterious", "Cheerful", "Grim", "Ambitious"]
		var backgrounds = ["Former soldier", "Ex-bandit", "Scholar's apprentice", "Village hero", "Wandering mercenary", "Fallen noble", "Guild dropout", "Self-taught warrior"]
		
		recruit.personality = personalities[randi() % personalities.size()]
		recruit.background = backgrounds[randi() % backgrounds.size()]
		recruit.availability = randi_range(3, 7)  # Days they'll stay available
		
		recruits.append(recruit)
	
	return recruits

func generate_recruit_id() -> int:
	"""Generate unique recruit ID"""
	return Time.get_unix_time_from_system() + randi_range(1000, 9999)

func get_available_recruits() -> Array:
	"""Get current list of available recruits"""
	var current_recruits = []
	for recruit in daily_recruits:
		var days_since_generation = current_day - recruit_refresh_day
		if days_since_generation < recruit.get("availability", 5):
			current_recruits.append(recruit)
		else:
			print("Recruit ", recruit.name, " is no longer available (expired)")
	
	return current_recruits

func remove_hired_recruit(recruit: Dictionary):
	"""Remove a recruit from the available pool after hiring"""
	for i in range(daily_recruits.size()):
		if daily_recruits[i].get("id") == recruit.get("id"):
			daily_recruits.remove_at(i)
			print("✅ Removed hired recruit: ", recruit.name)
			break

# Enhanced advance_day function
func advance_day():
	"""Enhanced day advancement with recruitment refresh"""
	current_day += 1
	day_changed.emit(current_day)
	
	print("🌅 Day ", current_day, " begins!")
	
	# Process all daily events
	process_mission_returns()
	process_daily_operations() 
	process_customer_visits()
	process_adventurer_recovery()
	check_tax_deadline()
	
	# Check if recruits need refreshing (every 2-3 days)
	var days_since_recruit_refresh = current_day - recruit_refresh_day
	if days_since_recruit_refresh >= 2 or daily_recruits.size() == 0:
		generate_daily_recruits(randi_range(2, 4))  # 2-4 new recruits
	
	# Check if missions need refreshing (every 2 days)
	if current_day % 2 == 0:
		refresh_available_missions()
		log_message("📋 New guild contracts have been posted!")

func refresh_available_missions():
	"""Refresh the mission pool"""
	if DataManager and DataManager.has_method("generate_daily_missions"):
		var new_missions = DataManager.generate_daily_missions(6)  # Generate 6 new missions
		available_missions.clear()
		for mission in new_missions:
			available_missions.append(mission)
		mission_refresh_day = current_day
		missions_changed.emit()
		print("✅ Refreshed available missions: ", available_missions.size(), " missions loaded")
	else:
		# Fallback mission refresh
		var fallback_missions = generate_fallback_missions()
		available_missions.clear()
		for mission in fallback_missions:
			available_missions.append(mission)
		print("⚠️ Using fallback missions: ", available_missions.size(), " missions loaded")

func generate_fallback_missions() -> Array:
	"""Generate fallback missions when DataManager is not available"""
	var base_missions = [
		{"name": "Clear Slimes", "danger": 1, "reward_range": [5, 10], "party_required": false, "category": "combat"},
		{"name": "Escort Merchant", "danger": 2, "reward_range": [15, 25], "party_required": true, "category": "escort"},
		{"name": "Gather Herbs", "danger": 1, "reward_range": [8, 15], "party_required": false, "category": "gathering"},
		{"name": "Investigate Bandits", "danger": 3, "reward_range": [25, 40], "party_required": true, "category": "investigation"},
		{"name": "Deliver Supplies", "danger": 2, "reward_range": [12, 22], "party_required": false, "category": "delivery"},
		{"name": "Repair Fortifications", "danger": 3, "reward_range": [30, 50], "party_required": true, "category": "construction"}
	]
	
	# Add variety to prevent identical missions
	var selected_missions = []
	base_missions.shuffle()
	
	for i in min(4, base_missions.size()):
		var mission = base_missions[i].duplicate()
		
		# Add location variety
		var locations = ["(Northern Route)", "(Eastern Frontier)", "(Mountain Pass)", "(Coastal Road)", "(Ancient Ruins)", "(Border Region)"]
		mission.name += " " + locations[randi() % locations.size()]
		
		# Add slight reward variation
		var variance = randi_range(-2, 3)
		mission.reward_range[0] = max(3, mission.reward_range[0] + variance)
		mission.reward_range[1] = max(5, mission.reward_range[1] + variance)
		
		selected_missions.append(mission)
	
	return selected_missions

func cleanup_expired_recruitment_candidates():
	"""Remove expired patron recruitment candidates"""
	patron_recruitment_pool = patron_recruitment_pool.filter(func(candidate): 
		candidate.availability_window -= 1
		return candidate.availability_window > 0
	)

# Enhanced hiring function
func hire_adventurer(recruit: Dictionary) -> bool:
	"""Enhanced adventurer hiring with recruit pool management"""
	var hiring_cost = recruit.get("hiring_cost", 10)
	
	if not spend_gold(hiring_cost):
		log_message("❌ Insufficient gold to hire " + recruit.name + " (Need " + str(hiring_cost) + " gold)")
		return false
		
	if adventurers.size() >= max_adventurers:
		print("❌ Roster full! Cannot hire ", recruit.name)
		add_gold(hiring_cost)  # Refund
		log_message("❌ Roster full! Cannot hire more adventurers (Maximum: " + str(max_adventurers) + ")")
		return false
	
	# Clean recruit data and add to roster
	var new_adventurer = recruit.duplicate()
	new_adventurer.erase("hiring_cost")
	new_adventurer.erase("personality")
	new_adventurer.erase("background") 
	new_adventurer.erase("availability")
	
	adventurers.append(new_adventurer)
	remove_hired_recruit(recruit)  # Remove from available pool
	adventurer_roster_changed.emit()
	
	log_message("🎉 Hired " + recruit.name + " the " + recruit.class + " for " + str(hiring_cost) + " gold!")
	log_message("📊 Current roster: " + str(adventurers.size()) + "/" + str(max_adventurers) + " adventurers")
	
	return true

# === SAVE/LOAD SYSTEM ===
func get_save_data() -> Dictionary:
	"""Get all data for saving"""
	return {
		"gold": gold,
		"beer_stock": beer_stock,
		"current_day": current_day,
		"tax_due_day": tax_due_day,
		"adventurers": adventurers,
		"max_adventurers": max_adventurers
	}

func load_save_data(data: Dictionary):
	"""Load game state from save data"""
	gold = data.get("gold", 30)
	beer_stock = data.get("beer_stock", 5) 
	current_day = data.get("current_day", 1)
	tax_due_day = data.get("tax_due_day", 30)
	adventurers = data.get("adventurers", [])
	max_adventurers = data.get("max_adventurers", 5)
	
	# Emit signals to update all UI
	gold_changed.emit(gold)
	beer_changed.emit(beer_stock)
	day_changed.emit(current_day)
	adventurer_roster_changed.emit()
	
	print("✅ Game state loaded successfully")
	
	
func get_patron_recruitment_pool() -> Array:
	"""Get current patron recruitment candidates"""
	return patron_recruitment_pool

func clear_patron_recruitment_pool():
	"""Clear all patron recruitment candidates (for testing)"""
	patron_recruitment_pool.clear()
	print("Patron recruitment pool cleared")


# In GameManager.gd
func check_additional_failure_conditions():
	"""Check for other game over conditions"""
	
	# No adventurers and no gold to hire new ones
	if adventurers.size() == 0 and gold < 20:
		pass
		trigger_game_over("no_adventurers", "No adventurers and insufficient gold to hire new ones")
	
	# Extended period without income
	if beer_stock == 0 and gold < 5 and current_day > 10:
		pass
		trigger_game_over("abandoned_tavern", "Tavern abandoned - no customers for too long")

func trigger_game_over(failure_type: String, reason: String):
	"""Trigger game over state and stop all game processes"""
	if game_over_active:
		return  # Prevent multiple game overs
		
	game_over_active = true
	log_message("FAILURE: " + reason)
	log_message("GAME OVER!")
	
	# Stop all game processes
	set_process_mode(Node.PROCESS_MODE_DISABLED)
	
	# Emit signal to show game over screen
	game_over_triggered.emit("Tax Bankruptcy: " + reason)


func reset_game_state():
	"""Reset GameManager to initial state"""
	gold = 30
	beer_stock = 5
	current_day = 1
	tax_due_day = 30
	daily_operating_cost = 1
	adventurers.clear()
	available_missions.clear()
	daily_recruits.clear()
	game_over_active = false
	
	# Re-enable processing
	set_process_mode(Node.PROCESS_MODE_INHERIT)
	
	# Emit all signals to refresh UI
	gold_changed.emit(gold)
	beer_changed.emit(beer_stock)
	day_changed.emit(current_day)
	adventurer_roster_changed.emit()
	
	print("Game state reset to initial values")
