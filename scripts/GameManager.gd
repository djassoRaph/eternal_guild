# GameManager.gd - Autoload Singleton
extends Node

# === CORE GAME STATE ===
var gold: int = 1000
var beer_stock: int = 5
var current_day: int = 1
var max_adventurers: int = 5
var adventurers: Array = []
var available_missions: Array = []  # Changed from Dictionary to Array
var recruitment_manager = null
var patron_recruitment_pool = []  # Patrons interested in joining
var firewood_stock: int = 0
var fireplace_fuel: float = 0.0  # Starts at 0% (fire is out)
var max_firewood_storage: int = 10
var daily_patron_visits: int = 0  # Track patrons for fuel drain
var mission_tier_unlocked: int = 1
var tax_due_day: int = 30
var daily_operating_cost: int = 5

# === UI UPDATE SIGNALS ===
signal gold_changed(new_amount: int)
signal beer_changed(new_amount: int)  
signal day_changed(new_day: int)
signal adventurer_roster_changed()
signal missions_changed
signal recruitment_pool_changed
signal game_over_triggered(reason: String)
signal firewood_changed(new_amount: int)
signal fireplace_fuel_changed(new_percentage: float)
signal mission_dispatched(adventurer, mission)
signal missions_resolved(reports)
signal morning_briefing_ready(reports)


var mission_refresh_day: int = 1
var recruit_refresh_day: int = 1
var daily_recruits: Array = []
var game_over_active: bool = false
var beer_shortage_days: int = 0
var adventurer_morale: Dictionary = {}  # adventurer_id -> morale level (1-3)

# === Progression Tracking ===
var total_missions_completed: int = 0
var tavern_reputation: int = 0
var taxes_paid_count: int = 0

var active_missions: Array = []       # Missions currently in progress with countdown timers
var pending_reports: Array = []       # Resolved mission results waiting to be shown in morning briefing
var has_pending_briefing: bool = false # Flag for morning briefing UI to check



# Tier unlock conditions
var tier_requirements = {
	1: {"always_unlocked": true},  # Starting tier
	2: {"taxes_paid": 1, "description": "Pay first tax (Day 30)"},
	3: {"reputation": 50, "day": 60, "missions_completed": 10, "description": "Build reputation and experience"}
}


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

func purchase_firewood(bundles: int, cost: int) -> bool:
	"""Purchase firewood for the fireplace"""
	# Check storage capacity
	if firewood_stock + bundles > max_firewood_storage:
		log_message("⚠️ Not enough storage space! (Max: " + str(max_firewood_storage) + " bundles)")
		return false
	
	# Check if can afford
	if not spend_gold(cost):
		log_message("❌ Insufficient gold to buy firewood (Need " + str(cost) + " gold)")
		return false
	
	# Purchase successful
	firewood_stock += bundles
	firewood_changed.emit(firewood_stock)
	
	log_message("🪵 Purchased " + str(bundles) + " bundle(s) of firewood for " + str(cost) + " gold")
	log_message("📦 Firewood stock: " + str(firewood_stock) + "/" + str(max_firewood_storage))
	
	return true



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
	"""Get adventurers available for missions """
	var ready = []
	for adv in adventurers:
		if adv.get("ready", true) and not adv.get("on_mission", false) and adv.get("status", "Ready") == "Ready":
			ready.append(adv)
	return ready
	
func is_adventurer_available(adventurer: Dictionary) -> bool:
	"""Check if specific adventurer is available for missions"""
	return adventurer.status == "Ready"


func get_unavailable_adventurers() -> Array:
	"""Get adventurers who are currently unavailable"""
	var unavailable = []
	for adv in adventurers:
		if adv.status != "Ready":
			unavailable.append(adv)
	return unavailable

func can_form_party(minimum_size: int = 2) -> bool:
	"""Check if enough adventurers available for party mission"""
	return get_ready_adventurers().size() >= minimum_size

func get_max_party_size() -> int:
	"""Get maximum party size based on available adventurers"""
	return get_ready_adventurers().size()

func get_max_adventurers() -> int:
	"""Get maximum adventurer capacity"""
	return max_adventurers

# === MISSION SYSTEM ===
func send_on_mission(adventurer: Dictionary, mission: Dictionary):
	"""Dispatch an adventurer on a mission. Does NOT resolve it — just starts the timer."""
	var duration = mission.get("duration_days", 1)

	adventurer.status = "On Mission"
	adventurer["current_mission"] = mission.get("name", "Unknown Mission")

	var active_entry = {
		"adventurer": adventurer,
		"mission": mission,
		"days_remaining": duration,
		"total_duration": duration,
		"success_chance": calculate_mission_success_chance(adventurer, mission),
		"sent_day": current_day
	}

	active_missions.append(active_entry)

	log_message("🗡️ " + adventurer.name + " departs on: " + mission.get("name", "?") + " (" + str(duration) + " day" + ("s" if duration > 1 else "") + ")")

	adventurer_roster_changed.emit()
	mission_dispatched.emit(adventurer, mission)


func send_party_on_mission(party: Array, mission: Dictionary):
	"""Dispatch a party on a mission. Does NOT resolve — starts the timer."""
	var duration = mission.get("duration_days", 1)

	for adventurer in party:
		adventurer.status = "On Mission"
		adventurer["current_mission"] = mission.get("name", "Unknown Mission")

	var active_entry = {
		"party": party,
		"mission": mission,
		"days_remaining": duration,
		"total_duration": duration,
		"is_party_mission": true,
		"sent_day": current_day
	}

	active_missions.append(active_entry)

	var names = ", ".join(party.map(func(a): return a.name))
	log_message("🗡️ Party departs on: " + mission.get("name", "?") + " (" + str(duration) + " day" + ("s" if duration > 1 else "") + ")")
	log_message("   Party: " + names)

	adventurer_roster_changed.emit()
	mission_dispatched.emit(party[0], mission)


func calculate_mission_success_chance(adventurer: Dictionary, mission: Dictionary) -> int:
	"""Calculate success chance — extracted from mission_board.gd for reuse"""
	var base_chance = 50
	var success_factors = mission.get("success_factors", ["strength"])
	var stat_bonus = 0

	for factor in success_factors:
		match factor:
			"strength": stat_bonus += adventurer.get("strength", 0) * 3
			"dexterity": stat_bonus += adventurer.get("dexterity", 0) * 3
			"intelligence": stat_bonus += adventurer.get("intelligence", 0) * 3
			"endurance": stat_bonus += adventurer.get("endurance", 0) * 2

	var experience_bonus = adventurer.get("missions_completed", 0) * 2
	var danger_penalty = mission.get("danger", 1) * 8
	var final_chance = base_chance + stat_bonus + experience_bonus - danger_penalty

	return clampi(final_chance, 10, 95)


func complete_mission(adventurer: Dictionary, mission: Dictionary, success: bool):
	"""Enhanced mission completion with mandatory recovery period"""
	if success:
		var reward = randi_range(mission.reward_range[0], mission.reward_range[1])
		add_gold(reward)
		adventurer.missions_completed += 1
		adventurer.gold_earned += reward

		# SUCCESS: Adventurer needs rest (1 day minimum)
		adventurer.status = "Resting"
		adventurer.recovery = 1

		total_missions_completed += 1
		tavern_reputation += 2
		GameManager.check_tier_unlocks()

		log_message("✅ SUCCESS! " + adventurer.name + " completed " + mission.name + " and earned " + str(reward) + " gold!")
		log_message("😴 " + adventurer.name + " rests for 1 day to recover their strength")
	else:
		adventurer.missions_failed += 1
		log_message("💥 FAILED! " + adventurer.name + " failed the mission: " + mission.name)

		# FAILURE ONLY: Handle injury and death consequences
		if adventurer.get("injured", false):
			adventurer.status = "Injured"
			adventurer.recovery = randi_range(2, 5)
		else:
			adventurer.status = "Resting"
			adventurer.recovery = 1

		handle_party_failure_consequences(adventurer, mission)

	# Clear mission tracking
	adventurer.erase("current_mission")
	# Emit signal so UI updates
	adventurer_roster_changed.emit()



func complete_party_mission(party: Array, mission: Dictionary, success: bool):
	"""Enhanced party missions with recovery periods"""
	if success:
		var reward = randi_range(mission.reward_range[0], mission.reward_range[1])
		add_gold(reward)
		log_message("✅ PARTY SUCCESS! Completed " + mission.name + " and earned " + str(reward) + " gold!")
		
		for adventurer in party:
			# SUCCESS: All party members need rest
			adventurer.status = "Resting"
			adventurer.recovery = 1  # 1 day rest for successful party missions
			adventurer.missions_completed += 1
			adventurer.gold_earned += reward / party.size()
			check_adventurer_level_up(adventurer)
		
		log_message("😴 Party members rest for 1 day after their successful mission")
	else:
		log_message("💥 PARTY FAILED! Mission " + mission.name + " was catastrophic")
		for adventurer in party:
			handle_party_failure_consequences(adventurer, mission)
			# CRITICAL FIX: Emit signal so UI updates
			adventurer_roster_changed.emit()



# === DAILY PROCESSING ===
func process_mission_returns():
	"""Tick down active mission timers. Resolve any that hit 0. Store results for morning briefing."""
	var resolved_indices = []

	for i in range(active_missions.size()):
		var entry = active_missions[i]
		entry.days_remaining -= 1

		if entry.days_remaining <= 0:
			resolved_indices.append(i)
			var report = _resolve_mission(entry)
			pending_reports.append(report)
		else:
			var mission_name = entry.mission.get("name", "Unknown")
			var days_left = entry.days_remaining
			if entry.get("is_party_mission", false):
				log_message("📍 Party on " + mission_name + " — " + str(days_left) + " day" + ("s" if days_left > 1 else "") + " remaining")
			else:
				var adv_name = entry.adventurer.get("name", "Someone")
				log_message("📍 " + adv_name + " on " + mission_name + " — " + str(days_left) + " day" + ("s" if days_left > 1 else "") + " remaining")

	resolved_indices.reverse()
	for idx in resolved_indices:
		active_missions.remove_at(idx)

	if pending_reports.size() > 0:
		has_pending_briefing = true
		morning_briefing_ready.emit(pending_reports)


func _resolve_mission(entry: Dictionary) -> Dictionary:
	"""Roll the dice for a completed mission and return a report dictionary."""
	if entry.get("is_party_mission", false):
		return _resolve_party_mission(entry)
	else:
		return _resolve_solo_mission(entry)


func _resolve_solo_mission(entry: Dictionary) -> Dictionary:
	"""Resolve a solo mission and apply consequences to the adventurer."""
	var adventurer = entry.adventurer
	var mission = entry.mission
	var success_chance = entry.success_chance
	var roll = randi() % 100 + 1
	var success = roll <= success_chance

	complete_mission(adventurer, mission, success)

	return {
		"type": "solo",
		"mission_name": mission.get("name", "Unknown"),
		"adventurer_name": adventurer.get("name", "Unknown"),
		"adventurer_class": adventurer.get("class", "Unknown"),
		"success": success,
		"roll": roll,
		"success_chance": success_chance,
		"reward": mission.get("reward_range", [0, 0]),
		"duration": entry.total_duration,
		"alive": adventurer.get("status", "") != "Dead",
		"injured": adventurer.get("status", "") == "Injured",
		"category": mission.get("category", "combat")
	}


func _resolve_party_mission(entry: Dictionary) -> Dictionary:
	"""Resolve a party mission and apply consequences."""
	var party = entry.party
	var mission = entry.mission

	var total_chance = 0
	for adv in party:
		total_chance += calculate_mission_success_chance(adv, mission)
	var avg_chance = total_chance / party.size()

	var party_bonus = (party.size() - 1) * 5
	var final_chance = clampi(avg_chance + party_bonus, 10, 95)

	var roll = randi() % 100 + 1
	var success = roll <= final_chance

	complete_party_mission(party, mission, success)

	var member_names = party.map(func(a): return a.get("name", "?"))
	var casualties = party.filter(func(a): return a.get("status", "") == "Dead")
	var injured = party.filter(func(a): return a.get("status", "") == "Injured")

	return {
		"type": "party",
		"mission_name": mission.get("name", "Unknown"),
		"party_members": member_names,
		"party_size": party.size(),
		"success": success,
		"roll": roll,
		"success_chance": final_chance,
		"reward": mission.get("reward_range", [0, 0]),
		"duration": entry.total_duration,
		"casualties": casualties.map(func(a): return a.get("name", "?")),
		"injured": injured.map(func(a): return a.get("name", "?")),
		"category": mission.get("category", "combat")
	}


func get_and_clear_pending_reports() -> Array:
	"""Called by MorningBriefing UI to consume the pending reports."""
	var reports = pending_reports.duplicate()
	pending_reports.clear()
	has_pending_briefing = false
	return reports

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
	"""Enhanced recovery processing with clear status transitions"""
	for adventurer in adventurers:
		if adventurer.status in ["Injured", "Resting"] and adventurer.has("recovery"):
			adventurer.recovery -= 1
			
			if adventurer.recovery <= 0:
				# Recovery complete
				var old_status = adventurer.status
				adventurer.status = "Ready"
				adventurer.erase("recovery")
				
				match old_status:
					"Injured":
						log_message("🩹 " + adventurer.name + " has fully recovered from injuries!")
					"Resting":
						log_message("😊 " + adventurer.name + " is refreshed and ready for new missions!")
			else:
				# Still recovering
				match adventurer.status:
					"Injured":
						log_message("🏥 " + adventurer.name + " continues healing (" + str(adventurer.recovery) + " days remaining)")
					"Resting":
						log_message("😴 " + adventurer.name + " is still resting (" + str(adventurer.recovery) + " days remaining)")


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
	var tax_amount = 1000 + (adventurers.size() * 5)
	
	if spend_gold(tax_amount):
		tax_due_day += 30
		taxes_paid_count += 1
		log_message("Successfully paid " + str(tax_amount) + " gold in taxes")
		log_message("Next tax payment due on day " + str(tax_due_day))
		GameManager.check_tier_unlocks()
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

func despawn_all_patrons():
	"""Remove all patrons from tavern when day ends"""
	var patron_spawner = get_node_or_null("/root/Node3D/SubViewportContainer/SubViewport/TavernNavigation/PatronSpawner")
	if patron_spawner and patron_spawner.has_method("despawn_all_patrons"):
		patron_spawner.despawn_all_patrons()
		log_message("🌙 All patrons have left for the night")

func get_firewood_stock() -> int:
	return firewood_stock

func get_fireplace_fuel() -> float:
	return fireplace_fuel

func get_max_firewood_storage() -> int:
	return max_firewood_storage


# Enhanced advance_day function
func advance_day():
	"""Enhanced day advancement with availability reporting"""
	current_day += 1
	day_changed.emit(current_day)
	fireplace_fuel = 0.0  # Fire dies completely
	fireplace_fuel_changed.emit(fireplace_fuel)
	log_message("🌅 Day " + str(current_day) + " begins - the fire has gone out overnight")
	print("🌅 Day ", current_day, " begins!")
	log_message("=== Day " + str(current_day) + " ===")
	
	# Process recovery FIRST (makes adventurers available)
	process_adventurer_recovery()
	
	# Show availability status
	log_daily_availability_status()
	
	# Process beer consumption and other daily events
	var beer_adequate = process_adventurer_beer_consumption()
	process_mission_returns()
	process_daily_operations_with_beer()
	check_tax_deadline()
	
	# Show daily status if beer shortage is active
	if beer_shortage_days > 0:
		log_message(get_guild_status_report())
	
	# Check for complete guild collapse
	if adventurers.size() == 0 and beer_shortage_days > 0:
		log_message("💀 GUILD COLLAPSE: No adventurers remain!")
		log_message("Consider hiring new recruits and restocking beer immediately.")
	
	# Recruitment and mission refresh
	var days_since_recruit_refresh = current_day - recruit_refresh_day
	if days_since_recruit_refresh >= 2 or daily_recruits.size() == 0:
		generate_daily_recruits(randi_range(2, 4))
	
	if current_day % 2 == 0:
		refresh_available_missions()
		log_message("📋 New guild contracts have been posted!")
	
	# End of day summary with availability
	var availability_report = get_guild_availability_report()
	log_message("💰 Gold: " + str(gold) + " | 🍺 Beer: " + str(beer_stock) + " pints | 👥 Available: " + str(availability_report["ready"]) + "/" + str(adventurers.size()))


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
	"""Get all data for saving - COMPLETE VERSION"""
	print("💾 Gathering save data...")
	
	var data = {
		# Core resources
		"gold": gold,
		"beer_stock": beer_stock,
		
		# Time tracking
		"current_day": current_day,
		"tax_due_day": tax_due_day,
		
		# Adventurers
		"adventurers": adventurers,
		"max_adventurers": max_adventurers,
		
		# Beer shortage tracking
		"beer_shortage_days": beer_shortage_days,
		"adventurer_morale": adventurer_morale,
		
		# Firewood system
		"firewood_stock": firewood_stock,
		"fireplace_fuel": fireplace_fuel,
		
		# Recruitment
		"daily_recruits": daily_recruits,
		"recruit_refresh_day": recruit_refresh_day,
		
		# Missions
		"available_missions": available_missions,
		
		# Patron recruitment pool
		"patron_recruitment_pool": patron_recruitment_pool
	}
	
	print("   Saved: ", data.keys().size(), " fields")
	print("   Day: ", data.current_day, ", Gold: ", data.gold)
	
	return data

func load_save_data(data: Dictionary):
	"""Load game state from save data - COMPLETE VERSION"""
	print("📂 Loading save data into GameManager...")
	
	# Core resources
	gold = int(data.get("gold", 10))
	beer_stock = int(data.get("beer_stock", 0))
	
	# Time tracking
	current_day = int(data.get("current_day", 1))
	tax_due_day = int(data.get("tax_due_day", 30))
	
	# Adventurers
	adventurers = data.get("adventurers", [])
	max_adventurers = int(data.get("max_adventurers", 5))
	
	# Beer shortage tracking
	beer_shortage_days = int(data.get("beer_shortage_days", 0))
	adventurer_morale = data.get("adventurer_morale", {})
	
	# Firewood system
	firewood_stock = int(data.get("firewood_stock", 0))
	fireplace_fuel = data.get("fireplace_fuel", 100.0)
	
	# Recruitment
	daily_recruits = data.get("daily_recruits", [])
	recruit_refresh_day = int(data.get("recruit_refresh_day", 0))
	
	# Missions
	available_missions = data.get("available_missions", [])
	
	# Patron recruitment pool
	patron_recruitment_pool = data.get("patron_recruitment_pool", [])
	
	# Reset game over state
	game_over_active = false
	
	# Re-enable processing
	set_process_mode(Node.PROCESS_MODE_INHERIT)
	
	# Emit all signals to update UI
	gold_changed.emit(gold)
	beer_changed.emit(beer_stock)
	day_changed.emit(current_day)
	firewood_changed.emit(firewood_stock)
	fireplace_fuel_changed.emit(fireplace_fuel)
	adventurer_roster_changed.emit()
	
	print("✅ Game state loaded successfully")
	print("   Day: ", current_day)
	print("   Gold: ", gold)
	print("   Beer: ", beer_stock)
	print("   Adventurers: ", adventurers.size())
	print("   Firewood: ", firewood_stock)
	print("   Fuel: ", fireplace_fuel, "%")
	
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
	#if adventurers.size() == 0 and gold < 20:
	#	pass
	#	trigger_game_over("no_adventurers", "No adventurers and insufficient gold to hire new ones")
	
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
	"""Reset GameManager to initial state - COMPLETE VERSION"""
	print("🔄 Resetting game state...")
	
	# Core resources
	gold = 10
	beer_stock = 0
	
	# Time
	current_day = 1
	tax_due_day = 30
	daily_operating_cost = 1
	
	# Adventurers
	adventurers.clear()
	max_adventurers = 5
	beer_shortage_days = 0
	adventurer_morale.clear()
	
	# Firewood
	firewood_stock = 0
	fireplace_fuel = 100.0
	
	# Recruitment
	daily_recruits.clear()
	recruit_refresh_day = 0
	patron_recruitment_pool.clear()
	
	# Missions
	available_missions.clear()
	
	# Game state
	game_over_active = false
	
	# Re-enable processing
	set_process_mode(Node.PROCESS_MODE_INHERIT)
	
	# Emit all signals to refresh UI
	gold_changed.emit(gold)
	beer_changed.emit(beer_stock)
	day_changed.emit(current_day)
	firewood_changed.emit(firewood_stock)
	fireplace_fuel_changed.emit(fireplace_fuel)
	adventurer_roster_changed.emit()
	
	print("✅ Game state reset to initial values")



func process_adventurer_beer_consumption() -> bool:
	"""Handle daily beer consumption with harsh consequences for shortages"""
	var adventurer_count = adventurers.size()
	var pints_needed = adventurer_count
	
	if adventurer_count == 0:
		beer_shortage_days = 0  # Reset when no adventurers
		return true
	
	print("🍺 Processing beer consumption: Need ", pints_needed, " pints, have ", beer_stock, " pints")
	
	if beer_stock >= pints_needed:
		# Sufficient beer - happy adventurers
		consume_beer_pints(pints_needed)
		beer_shortage_days = 0  # Reset shortage counter
		
		# Set all adventurers to high morale
		for adventurer in adventurers:
			adventurer_morale[adventurer.get("id", adventurer.name)] = 3
		
		log_message("✅ Adventurers enjoyed their daily rations (" + str(pints_needed) + " pints)")
		log_message("🙂 Guild morale is high - adventurers are content!")
		return true
	else:
		# Beer shortage - apply harsh consequences
		beer_shortage_days += 1
		log_message("🚨 BEER SHORTAGE - Day " + str(beer_shortage_days) + "!")
		log_message("Need " + str(pints_needed) + " pints, only have " + str(beer_stock) + " pints")
		
		apply_beer_shortage_consequences()
		return false
		
		
		
func apply_beer_shortage_consequences():
	"""Apply escalating consequences for beer shortages"""
	
	# Consume what beer we have
	if beer_stock > 0:
		var partial_consumption = beer_stock
		consume_beer_pints(partial_consumption)
		log_message("Shared remaining " + str(partial_consumption) + " pint(s) among adventurers")
	
	# Apply consequences based on shortage duration
	match beer_shortage_days:
		1:
			apply_day_1_shortage()
		2:
			apply_day_2_shortage()
		_:
			apply_extended_shortage()
			
func apply_day_1_shortage():
	"""Day 1 shortage: Immediate mission penalty"""
	log_message("💔 Day 1 Shortage Effects:")
	log_message("• Adventurer morale dropping")
	log_message("• Mission success rates reduced by 25%")
	log_message("• Adventurers grumbling about poor conditions")
	
	# Set all adventurers to low morale
	for adventurer in adventurers:
		adventurer_morale[adventurer.get("id", adventurer.name)] = 1
	
	# Add flavor text
	var complaints = [
		"\"Where's our daily ale? This is no way to run a guild!\"",
		"\"My throat's parched and my spirits are low...\"",
		"\"Other guilds take better care of their people.\"",
		"\"How can we fight on empty mugs?\""
	]
	log_message(complaints[randi() % complaints.size()])

func apply_day_2_shortage():
	"""Day 2 shortage: Mission penalties + departure risk"""
	log_message("💀 Day 2 Shortage Effects:")
	log_message("• Mission success rates reduced by 50%")
	log_message("• Adventurers considering leaving the guild")
	log_message("• Guild reputation at risk")
	
	# 50% chance each adventurer leaves
	var leaving_adventurers = []
	for adventurer in adventurers:
		if randf() < 0.5:
			leaving_adventurers.append(adventurer)
	
	# Process departures
	for adventurer in leaving_adventurers:
		adventurers.erase(adventurer)
		adventurer_morale.erase(adventurer.get("id", adventurer.name))
		log_message("💔 " + adventurer.name + " (" + adventurer.class + ") left the guild!")
		log_message("\"" + adventurer.name + " said: 'I can't work under these conditions!'\"")
	
	if leaving_adventurers.size() > 0:
		log_message("⚠️ " + str(leaving_adventurers.size()) + " adventurer(s) abandoned the guild!")
		adventurer_roster_changed.emit()
	else:
		log_message("😮‍💨 Fortunately, all adventurers decided to stay... for now.")

func apply_extended_shortage():
	"""Day 3+ shortage: Guaranteed departures"""
	log_message("☠️ Day " + str(beer_shortage_days) + " Shortage - Critical!")
	log_message("• Guild conditions are unbearable")
	log_message("• Adventurers abandoning their posts")
	log_message("• Reputation plummeting throughout the region")
	
	# Guaranteed departures after day 2
	if adventurers.size() > 0:
		var leaving = adventurers.pop_back()
		adventurer_morale.erase(leaving.get("id", leaving.name))
		log_message("💔 " + leaving.name + " (" + leaving.class + ") abandoned the guild!")
		
		var harsh_messages = [
			"\"" + leaving.name + " packed their belongings in disgust.\"",
			"\"" + leaving.name + " said this guild is a disgrace to adventurers.\"",
			"\"" + leaving.name + " vowed never to return to such poor management.\"",
			"\"" + leaving.name + " left without even saying goodbye.\""
		]
		log_message(harsh_messages[randi() % harsh_messages.size()])
		adventurer_roster_changed.emit()
		
		if adventurers.size() == 0:
			log_message("🏚️ All adventurers have abandoned the guild!")
			log_message("💀 The tavern sits empty, your reputation in ruins...")

# === MISSION SUCCESS RATE MODIFICATIONS ===
func get_beer_shortage_penalty() -> int:
	"""Get mission success penalty based on beer shortage duration"""
	match beer_shortage_days:
		0:
			return 0   # No penalty
		1:
			return 25  # -25% success rate
		2:
			return 50  # -50% success rate
		_:
			return 75  # -75% success rate (near-impossible missions)

func get_adventurer_morale_bonus(adventurer: Dictionary) -> int:
	"""Get mission bonus/penalty based on individual adventurer morale"""
	var adventurer_id = adventurer.get("id", adventurer.name)
	var morale = adventurer_morale.get(adventurer_id, 2)  # Default to neutral
	
	match morale:
		3:
			return 10   # +10% when happy
		2:
			return 0    # No modifier when neutral
		1:
			return -15  # -15% when unhappy (stacks with shortage penalty)
		_:
			return 0

# === INTEGRATION WITH EXISTING MISSION SYSTEM ===
func calculate_mission_success_with_beer_effects(base_chance: int, adventurer: Dictionary) -> int:
	"""Apply beer shortage and morale effects to mission success calculation"""
	var shortage_penalty = get_beer_shortage_penalty()
	var morale_effect = get_adventurer_morale_bonus(adventurer)
	
	var modified_chance = base_chance - shortage_penalty + morale_effect
	
	# Log the effects for transparency
	if shortage_penalty > 0:
		log_message("⚠️ Beer shortage penalty: -" + str(shortage_penalty) + "%")
	if morale_effect != 0:
		var effect_text = "+" if morale_effect > 0 else ""
		log_message("😊 " + adventurer.name + " morale effect: " + effect_text + str(morale_effect) + "%")
	
	# Ensure minimum 5% chance, maximum 95%
	return clampi(modified_chance, 5, 95)

# === DAILY PROCESSING INTEGRATION ===
func process_daily_operations_with_beer():
	"""Enhanced daily operations that include beer consumption"""
	# Pay adventurer wages
	var wage_cost = adventurers.size()  # 1 gold per adventurer
	if spend_gold(wage_cost):
		log_message("💰 Paid " + str(wage_cost) + " gold in adventurer wages")
	else:
		log_message("💸 WARNING: Could not afford adventurer wages!")
		# Could add wage shortage consequences here too
	
	# Handle beer consumption with consequences
	process_adventurer_beer_consumption()
	
	# Regular tavern customers (existing function)
	process_customer_visits()

# === STATUS REPORTING ===
func get_guild_status_report() -> String:
	"""Generate a comprehensive guild status report"""
	var report = "=== GUILD STATUS REPORT ===\n"
	report += "Day: " + str(current_day) + "\n"
	report += "Gold: " + str(gold) + "\n"
	report += "Beer Stock: " + str(beer_stock) + " pints\n"
	report += "Adventurers: " + str(adventurers.size()) + "/" + str(max_adventurers) + "\n"
	
	if beer_shortage_days > 0:
		report += "⚠️ BEER SHORTAGE: Day " + str(beer_shortage_days) + "\n"
		report += "Mission Penalty: -" + str(get_beer_shortage_penalty()) + "%\n"
	else:
		report += "✅ Beer supplies adequate\n"
	
	# Morale breakdown
	var high_morale = 0
	var neutral_morale = 0
	var low_morale = 0
	
	for adventurer in adventurers:
		var morale = adventurer_morale.get(adventurer.get("id", adventurer.name), 2)
		match morale:
			3: high_morale += 1
			2: neutral_morale += 1
			1: low_morale += 1
	
	report += "Morale - High: " + str(high_morale) + ", Neutral: " + str(neutral_morale) + ", Low: " + str(low_morale) + "\n"
	report += "========================\n"
	
	return report


func add_beer_pints(pints: int):
	"""Add beer stock in pints and notify systems"""
	beer_stock += pints
	beer_changed.emit(beer_stock)
	print("🍺 Added ", pints, " pint(s). Total: ", beer_stock, " pints")

func consume_beer_pints(pints: int) -> bool:
	"""Consume beer pints if available"""
	if beer_stock >= pints:
		beer_stock -= pints
		beer_changed.emit(beer_stock)
		print("🍻 Consumed ", pints, " pint(s). Remaining: ", beer_stock, " pints")
		return true
	else:
		print("❌ Insufficient beer. Need ", pints, " pints but have ", beer_stock, " pints")
		return false

func get_beer_pints() -> int:
	"""Get current beer stock in pints"""
	return beer_stock

func count_active_patrons() -> int:
	"""Count active patrons in tavern for fuel drain calculation"""
	var patron_spawner = get_node_or_null("/root/Node3D/SubViewportContainer/SubViewport/TavernNavigation/PatronSpawner")
	if patron_spawner and patron_spawner.has_method("get_patron_count"):
		return patron_spawner.get_patron_count()
	return 0


func stoke_fireplace() -> bool:
	"""Use firewood to increase fire level"""
	if firewood_stock <= 0:
		log_message("❌ No firewood available! Buy some from your quarters.")
		return false
	
	# Consume 1 bundle
	firewood_stock -= 1
	firewood_changed.emit(firewood_stock)
	
	# Add 25% fuel (capped at 100%)
	var old_fuel = fireplace_fuel
	fireplace_fuel = min(100.0, fireplace_fuel + 25.0)
	fireplace_fuel_changed.emit(fireplace_fuel)
	
	log_message("🔥 Stoked the fire! (" + str(int(old_fuel)) + "% → " + str(int(fireplace_fuel)) + "%)")
	
	return true

func _process(delta):
	# Only drain fuel if fire is burning
	if fireplace_fuel > 0:
		# Base drain rate
		var drain_rate = 0.15  # 0.15% per second base
		
		# Add drain based on active patrons (door opening/closing, warmth used)
		var active_patrons = count_active_patrons()
		var patron_drain = active_patrons * 0.05  # 0.05% per patron per second
		
		# Total drain
		var total_drain = (drain_rate + patron_drain) * delta
		
		# Apply drain
		fireplace_fuel -= total_drain
		fireplace_fuel = max(0.0, fireplace_fuel)
		
		# Emit signal if changed significantly (avoid spam)
		if int(fireplace_fuel) != int(fireplace_fuel + total_drain):
			fireplace_fuel_changed.emit(fireplace_fuel)





func calculate_patron_tip() -> int:
	"""Calculate tip based on fireplace comfort level"""
	# Simple linear formula: 100% fuel = 6g, 50% fuel = 3g, 0% fuel = 0g
	var base_tip = 6.0
	var comfort_ratio = fireplace_fuel / 100.0
	var final_tip = int(base_tip * comfort_ratio)
	
	return final_tip


# === CUSTOMER SERVICE WITH CLEAR ECONOMICS ===
func serve_customer_beer() -> int:
	"""Serve beer to customer with fire-based tip calculation"""
	if consume_beer_pints(1):
		var payment = 6  # Base payment for beer
		var tip = calculate_patron_tip()  # Fire-based tip
		var total = payment + tip
		
		add_gold(total)
		daily_patron_visits += 1  # Track for statistics
		
		if tip > 0:
			log_message("Served 1 pint for " + str(payment) + "g + " + str(tip) + "g tip (Fire: " + str(int(fireplace_fuel)) + "%)")
		else:
			log_message("Served 1 pint for " + str(payment) + "g (No tip - fire is out!)")
		
		return total
	else:
		log_message("Cannot serve customer - no beer available!")
		return 0
		
		
func get_adventurer_status_description(adventurer: Dictionary) -> String:
	"""Get detailed status description for UI display"""
	match adventurer.status:
		"Ready":
			return "Available for missions"
		"Injured":
			var days = adventurer.get("recovery", 0)
			return "Injured (" + str(days) + " day" + ("s" if days != 1 else "") + " remaining)"
		"Resting":
			var days = adventurer.get("recovery", 0) 
			return "Resting (" + str(days) + " day" + ("s" if days != 1 else "") + " remaining)"
		"on_mission":
			return "Currently on mission"
		_:
			return "Status unknown"


func get_guild_availability_report() -> Dictionary:
	"""Get comprehensive availability report"""
	var ready = get_ready_adventurers()
	var unavailable = get_unavailable_adventurers()
	
	var resting_count = 0
	var injured_count = 0
	var on_mission_count = 0
	
	for adv in unavailable:
		match adv.status:
			"Resting":
				resting_count += 1
			"Injured": 
				injured_count += 1
			"on_mission":
				on_mission_count += 1
	
	return {
		"total_adventurers": adventurers.size(),
		"ready": ready.size(),
		"resting": resting_count,
		"injured": injured_count,
		"on_mission": on_mission_count,
		"availability_percentage": (ready.size() * 100) / max(1, adventurers.size())
	}



func log_daily_availability_status():
	"""Log current availability status each morning"""
	var report = get_guild_availability_report()
	
	if report["ready"] == 0:
		log_message("⚠️ NO ADVENTURERS AVAILABLE for missions today!")
	elif report["ready"] == report["total_adventurers"]:
		log_message("✅ All " + str(report["total_adventurers"]) + " adventurers are ready for missions")
	else:
		log_message("📊 Guild Status: " + str(report["ready"]) + "/" + str(report["total_adventurers"]) + " adventurers available")
		
		if report["injured"] > 0:
			log_message("🏥 " + str(report["injured"]) + " adventurer(s) recovering from injuries")
		if report["resting"] > 0:
			log_message("😴 " + str(report["resting"]) + " adventurer(s) resting after missions")

func check_adventurer_level_up(adventurer: Dictionary):
	"""Placeholder for level up system"""
	pass

func handle_party_failure_consequences(adventurer: Dictionary, mission: Dictionary):
	"""Handle the brutal consequences of mission failure"""
	var adventurer_level = get_adventurer_level(adventurer)
	var death_chance = calculate_death_chance(adventurer_level, mission.danger)
	
	var death_roll = randf()
	
	log_message("⚠️ " + adventurer.name + " faces danger (Level " + str(adventurer_level) + " vs Danger " + str(mission.danger) + ")")
	log_message("🎲 Death chance: " + str(int(death_chance * 100)) + "% (Rolled: " + str(int(death_roll * 100)) + ")")
	
	if death_roll < death_chance:
		# ADVENTURER DIES
		handle_adventurer_death(adventurer, mission)
	else:
		# INJURED BUT SURVIVES
		handle_adventurer_injury(adventurer, mission)

func calculate_death_chance(adventurer_level: int, mission_danger: int) -> float:
	"""Calculate death chance based on your design requirements"""
	var base_death_chance: float
	
	# Death rates by adventurer level (your specified rates)
	match adventurer_level:
		1:
			base_death_chance = 0.35  # 35% base death rate (30-40% range)
		2, 3:
			base_death_chance = 0.175  # 17.5% base death rate (15-20% range)
		4, 5:
			base_death_chance = 0.075  # 7.5% base death rate (5-10% range)
		_:
			base_death_chance = 0.05   # 5% for veterans (level 6+)
	
	# Mission danger multiplier
	var danger_multiplier = 1.0 + (mission_danger - 1) * 0.3  # +30% per danger level above 1
	
	# Beer shortage penalty (from existing system)
	var beer_penalty = 0.0
	if beer_shortage_days > 0:
		beer_penalty = beer_shortage_days * 0.1  # +10% death chance per day of shortage
	
	var final_death_chance = base_death_chance * danger_multiplier + beer_penalty
	
	# Cap at 80% max death chance (always some hope)
	return min(final_death_chance, 0.8)

func get_adventurer_level(adventurer: Dictionary) -> int:
	"""Calculate adventurer level based on completed missions"""
	var missions_completed = adventurer.get("missions_completed", 0)
	
	if missions_completed < 3:
		return 1  # Fresh recruits
	elif missions_completed < 8:
		return 2  # Some experience
	elif missions_completed < 15:
		return 3  # Proven survivors
	elif missions_completed < 25:
		return 4  # Experienced adventurers
	elif missions_completed < 40:
		return 5  # Veterans
	else:
		return 6  # Legendary heroes

func handle_adventurer_death(adventurer: Dictionary, mission: Dictionary):
	"""Handle permanent adventurer death with dramatic narrative"""
	var death_messages = [
		adventurer.name + " fought valiantly but was overwhelmed",
		adventurer.name + " made the ultimate sacrifice during " + mission.name,
		"The guild mourns the loss of " + adventurer.name,
		adventurer.name + " fell in battle, but their courage will be remembered"
	]
	
	log_message("💀 " + death_messages[randi() % death_messages.size()])
	
	# Remove from adventurer roster
	adventurers.erase(adventurer)
	adventurer_roster_changed.emit()
	
	# Death has economic consequences - funeral costs
	var funeral_cost = randi_range(5, 15)
	if spend_gold(funeral_cost):
		log_message("💰 Paid " + str(funeral_cost) + " gold for " + adventurer.name + "'s funeral")
	else:
		log_message("💸 Could not afford proper funeral rites for " + adventurer.name)
	
	# Check for guild collapse
	if adventurers.size() == 0:
		log_message("🏚️ ALL ADVENTURERS HAVE PERISHED!")
		log_message("💡 Visit the recruitment desk immediately to rebuild your guild!")

func handle_adventurer_injury(adventurer: Dictionary, mission: Dictionary):
	"""Handle injury with extended recovery time"""
	var injury_severity = randi_range(2, 5)  # 2-5 days for injuries
	
	adventurer.status = "Injured"
	adventurer.recovery = injury_severity
	adventurer.injuries_sustained = adventurer.get("injuries_sustained", 0) + 1
	
	log_message("🏥 " + adventurer.name + " survived but is badly injured")
	log_message("⏰ " + adventurer.name + " needs " + str(injury_severity) + " day(s) to recover")



func check_tier_unlocks():
	"""Check and unlock new mission tiers based on progression"""
	var previous_tier = mission_tier_unlocked
	
	# Check Tier 2 unlock
	if mission_tier_unlocked == 1 and taxes_paid_count >= 1:
		mission_tier_unlocked = 2
		log_message("🎉 TIER 2 MISSIONS UNLOCKED!")
		log_message("New contract types are now available at the mission board.")
	
	# Check Tier 3 unlock
	elif mission_tier_unlocked == 2 and tavern_reputation >= 50 and current_day >= 60 and total_missions_completed >= 10:
		mission_tier_unlocked = 3
		log_message("🎉 TIER 3 MISSIONS UNLOCKED!")
		log_message("Elite contracts are now available - high risk, high reward!")
	
	# Refresh missions if tier changed
	if mission_tier_unlocked > previous_tier:
		refresh_available_missions()



func get_tier_unlock_status(tier: int) -> Dictionary:
	"""Get unlock status for a specific tier"""
	if tier == 1:
		return {"unlocked": true, "description": "Basic guild contracts"}
	
	var requirements = tier_requirements.get(tier, {})
	var status = {"unlocked": false, "missing": [], "description": requirements.get("description", "")}
	
	if tier == 2:
		if taxes_paid_count >= requirements.get("taxes_paid", 1):
			status.unlocked = true
		else:
			status.missing.append("Pay first tax (Day " + str(tax_due_day) + ")")
	
	elif tier == 3:
		status.unlocked = true  # Start assuming unlocked
		
		if tavern_reputation < requirements.get("reputation", 50):
			status.unlocked = false
			status.missing.append("Reputation: " + str(tavern_reputation) + "/" + str(requirements.get("reputation", 50)))
		
		if current_day < requirements.get("day", 60):
			status.unlocked = false
			status.missing.append("Day: " + str(current_day) + "/" + str(requirements.get("day", 60)))
		
		if total_missions_completed < requirements.get("missions_completed", 10):
			status.unlocked = false
			status.missing.append("Missions: " + str(total_missions_completed) + "/" + str(requirements.get("missions_completed", 10)))
	
	return status

func refresh_available_missions():
	"""Refresh the mission pool with tier restrictions"""
	if DataManager and DataManager.has_method("generate_daily_missions_with_tiers"):
		var new_missions = DataManager.generate_daily_missions_with_tiers(6, mission_tier_unlocked)
		available_missions.clear()
		for mission in new_missions:
			available_missions.append(mission)
		mission_refresh_day = current_day
		missions_changed.emit()
		print("✅ Refreshed missions (Tier ", mission_tier_unlocked, "): ", available_missions.size(), " missions loaded")
	else:
		# Fallback
		var fallback_missions = generate_fallback_missions()
		available_missions.clear()
		for mission in fallback_missions:
			available_missions.append(mission)
		print("⚠️ Using fallback missions")



func assign_adventurer_to_mission(adventurer: Dictionary, mission: Dictionary):
	# Mark adventurer as busy
	adventurer["on_mission"] = true
	adventurer["current_mission"] = mission
	
	if not "active_missions" in self:
				
		active_missions.append({
			"adventurer": adventurer,
			"mission": mission,
			"days_left": 1  # placeholder
		})
		
	# Emit roster change so UI updates
	adventurer_roster_changed.emit()
