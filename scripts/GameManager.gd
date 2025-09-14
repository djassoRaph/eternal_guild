# GameManager.gd - Autoload Singleton
# Save as: res://scripts/GameManager.gd
# Add to Project Settings > Autoload with name "GameManager"

extends Node

# === CORE GAME STATE ===
var gold: int = 30
var beer_stock: int = 5
var current_day: int = 1
var max_adventurers: int = 5
var adventurers: Array = []

# === ECONOMIC SETTINGS ===
var tax_due_day: int = 30
var daily_operating_cost: int = 1

# === UI UPDATE SIGNALS ===
signal gold_changed(new_amount: int)
signal beer_changed(new_amount: int)  
signal day_changed(new_day: int)
signal adventurer_roster_changed()

# === INITIALIZATION ===
func _ready():
	print("🎮 GameManager singleton initialized")
	print("Initial state - Gold: ", gold, " Beer: ", beer_stock, " Day: ", current_day)
	
	# Create starting adventurer (Brom)
	initialize_starting_adventurer()

func initialize_starting_adventurer():
	"""Create Brom the Fighter as starting adventurer"""
	var brom = {
		"id": 1,
		"name": "Brom",
		"class": "Fighter", 
		"status": "Ready",
		"recovery": 0,
		"strength": 6,
		"dexterity": 3,
		"intelligence": 2,
		"endurance": 5,
		"missions_completed": 0,
		"missions_failed": 0,
		"gold_earned": 0,
		"injuries_sustained": 0
	}
	
	adventurers.append(brom)
	adventurer_roster_changed.emit()
	print("✅ Brom the Fighter joins your guild!")

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
func advance_day():
	"""Advance to next day with all processing"""
	current_day += 1
	day_changed.emit(current_day)
	
	print("🌅 Day ", current_day, " begins!")
	
	# Process all daily events
	process_mission_returns()
	process_daily_operations() 
	process_customer_visits()
	process_adventurer_recovery()
	check_tax_deadline()

func get_day() -> int:
	"""Get current day number"""
	return current_day

# === ADVENTURER MANAGEMENT ===
func hire_adventurer(recruit: Dictionary) -> bool:
	"""Hire an adventurer if funds and space available"""
	var hiring_cost = recruit.get("hiring_cost", 10)
	
	if not spend_gold(hiring_cost):
		return false
		
	if adventurers.size() >= max_adventurers:
		print("❌ Roster full! Cannot hire ", recruit.name)
		add_gold(hiring_cost)  # Refund
		return false
	
	# Clean recruit data and add to roster
	var new_adventurer = recruit.duplicate()
	new_adventurer.erase("hiring_cost")
	new_adventurer.erase("personality")
	new_adventurer.erase("background") 
	new_adventurer.erase("availability")
	
	adventurers.append(new_adventurer)
	adventurer_roster_changed.emit()
	
	print("🎉 Hired ", recruit.name, " the ", recruit.class, " for ", hiring_cost, " gold!")
	return true

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
	var total_cost = daily_operating_cost + adventurers.size()
	
	if spend_gold(total_cost):
		log_message("Paid " + str(total_cost) + " gold in daily operating costs")
	else:
		log_message("WARNING: Could not afford operating costs!")

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
	"""Process tax payment"""
	var tax_amount = 50 + (adventurers.size() * 5)
	
	if spend_gold(tax_amount):
		tax_due_day += 30
		log_message("Successfully paid " + str(tax_amount) + " gold in taxes")
		log_message("Next tax payment due on day " + str(tax_due_day))
	else:
		log_message("FAILURE: Could not pay taxes! Game Over!")

# === LOGGING SYSTEM ===
func log_message(message: String):
	"""Send message to game log"""
	print("LOG: ", message)
	
	# Try to find and update the event log
	var main_scene = get_tree().current_scene
	if main_scene and main_scene.has_method("log_message"):
		main_scene.log_message(message)

# === SAVE/LOAD SYSTEM (Future) ===
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
