extends Node3D

@onready var game_log = $GameUI/MainArea/TavernView/LogContainer/EventLog
@onready var log_container = $GameUI/MainArea/TavernView/LogContainer
@onready var day_label = $GameUI/TopStatsBar/DayLabel
@onready var gold_label = $GameUI/TopStatsBar/GoldLabel
@onready var beer_label = $GameUI/TopStatsBar/BeerLabel
@onready var fade_system = $UIOverlay/FadeToBlack
var adventurers = []
var max_adventurers = 5
var current_day = 1
var tax_due_day = 30
var daily_operating_cost = 1
var customer_visits = 0



func _ready():
	log_message("Game started successfully!")
	# Allow this node to process input even when paused
	process_mode = Node.PROCESS_MODE_ALWAYS
	if fade_system:
		fade_system.fade_complete.connect(_on_sleep_complete)

func _input(event):
	if event.is_action_pressed("ui_cancel"):
		toggle_pause_menu()

func advance_to_next_day():
	"""Handle all day advancement logic"""
	current_day += 1
	
	log_message("=== Day " + str(current_day) + " begins ===")
	
	# Process daily events in order
	process_mission_returns()
	process_daily_operations()
	process_customer_visits()
	process_adventurer_recovery()
	reset_daily_content()
	check_tax_deadline()
	
	fade_system.start_sleep_fade()
	
	# Update day display
	day_label.text = "Day: " + str(current_day)
	
	log_message("Ready for another day of guild management!")


func toggle_pause_menu():
	print("Toggle called!")
	var pause_menu = get_node("PauseMenu")
	print("Found pause menu: ", pause_menu)
	pause_menu.visible = !pause_menu.visible
	get_tree().paused = pause_menu.visible


func _on_main_menu_button_pressed() -> void:
	print("on_main_menu_button log")
	get_tree().paused = false
	get_tree().change_scene_to_file("res://MainMenu.tscn")


func _on_quit_button_pressed() -> void:
	print("_on_quit_button_pressed log")
	get_tree().quit()

		
func send_log_message(message: String):
	var main_script = get_node("/root/Node3D")
	if main_script and main_script.has_method("log_message"):
		main_script.log_message(message)

func log_message(message: String):
	print("log_message function called with: ", message)
	if game_log and game_log is RichTextLabel:
		# Add your message
		if game_log.text == "":
			game_log.text = "Welcome to the Eternal Guild!\n"
			game_log.text += "Day 1 begins...\n"
			game_log.text += "---\n"
			game_log.text += message
		else:
			game_log.text += "\n" + message
		
		# Force updates and recalculation
		await get_tree().process_frame
		await get_tree().process_frame  # Extra frame for safety
		
		# Force the ScrollContainer to update its scrollbars
		log_container.queue_redraw()
		
		if log_container.get_v_scroll_bar():
			var vbar = log_container.get_v_scroll_bar()
			# Wait for scrollbar to update
			await get_tree().process_frame
			print("After update - VScrollBar max: ", vbar.max_value)
			vbar.value = vbar.max_value
			print("Final scroll position: ", vbar.value)
			


func get_adventurer_count() -> int:
	"""Get current number of adventurers"""
	return adventurers.size()

func get_ready_adventurers() -> Array:
	"""Get list of adventurers ready for missions"""
	var ready_adventurers = []
	for adv in adventurers:
		if adv.status == "Ready":
			ready_adventurers.append(adv)
	return ready_adventurers

func get_max_adventurers() -> int:
	"""Get maximum adventurers allowed"""
	return max_adventurers
	
	
	
func complete_mission(adventurer: Dictionary, mission: Dictionary, success: bool):
	"""Handle mission completion for solo adventurers"""
	# Add your mission completion logic here
	if success:
		var reward = randi() % (mission.reward_range[1] - mission.reward_range[0] + 1) + mission.reward_range[0]
		log_message("✅ SUCCESS! " + adventurer.name + " completed " + mission.name + " and earned " + str(reward) + " gold!")
		# Update adventurer stats, gold, etc.
		update_gold(reward)
	else:
		log_message("💥 FAILED! " + adventurer.name + " failed the mission: " + mission.name)
		# Handle failure consequences

func complete_party_mission(party: Array, mission: Dictionary, success: bool, healer_count: int):
	"""Handle mission completion for party missions"""
	if success:
		var reward = randi() % (mission.reward_range[1] - mission.reward_range[0] + 1) + mission.reward_range[0]
		update_gold(reward)  # ADD THIS LINE
		log_message("✅ PARTY SUCCESS! Completed " + mission.name + " and earned " + str(reward) + " gold!")
		
		# Set all party members back to Ready
		for adventurer in party:
			adventurer.status = "Ready"
	else:
		log_message("💥 PARTY FAILED! Mission " + mission.name + " was unsuccessful")
		
		# Handle failures based on mission danger and healer presence
		for adventurer in party:
			if healer_count > 0 and randf() < 0.7:  # Healers reduce injury chance
				adventurer.status = "Ready"
				log_message(adventurer.name + " was protected from injury by the party healer")
			elif randf() < (mission.danger * 0.2):  # Higher danger = more injury chance
				adventurer.status = "Injured"  # You'll need to handle injured status
				log_message(adventurer.name + " was injured and needs time to recover")
			else:
				adventurer.status = "Ready"
	
func hire_recruit(recruit: Dictionary):
	"""Hire a recruit and add them to the adventure££¤rs roster"""
	# Add missing variables if not declared
	if not has_method("get_gold"):
		var gold = 30  # Initialize if missing
		var beer_stock = 5
		var day = 1
	
	var current_gold = get_current_gold()  # Get from UI label
	
	if current_gold >= recruit.hiring_cost and adventurers.size() < max_adventurers:
		# Update gold in UI
		update_gold(-recruit.hiring_cost)
		
		# Add to roster (remove recruitment-specific data)
		var new_adventurer = recruit.duplicate()
		new_adventurer.erase("hiring_cost")
		new_adventurer.erase("personality") 
		new_adventurer.erase("background")
		new_adventurer.erase("availability")
		adventurers.append(new_adventurer)
		
		# Log the hiring
		log_message("🎉 Hired " + recruit.name + " the " + recruit.class + " for " + str(recruit.hiring_cost) + " gold!")
		log_message("👥 Guild roster: " + str(adventurers.size()) + "/" + str(max_adventurers))
	else:
		log_message("❌ Cannot hire " + recruit.name + " - insufficient funds or roster full!")

func get_current_gold() -> int:
	"""Get current gold from UI label"""
	var parts = gold_label.text.split(" ")
	return int(parts[1])

func update_gold(change: int):
	"""Update gold display"""
	var current_gold = get_current_gold()
	var new_gold = current_gold + change
	gold_label.text = "Gold: " + str(new_gold)

func process_mission_returns():
	"""Handle adventurers returning from missions"""
	var returning_adventurers = []
	
	for adventurer in adventurers:
		if adventurer.status == "on_mission":
			returning_adventurers.append(adventurer)
	
	if returning_adventurers.size() > 0:
		log_message("Adventurers return from their missions...")
		for adventurer in returning_adventurers:
			adventurer.status = "Ready"
			log_message(adventurer.name + " has returned to the guild")

func process_daily_operations():
	"""Handle daily operating costs and maintenance"""
	var total_cost = daily_operating_cost + (adventurers.size() * 1)  # Cost increases with roster size
	
	if get_current_gold() >= total_cost:
		update_gold(-total_cost)
		log_message("Paid " + str(total_cost) + " gold in daily operating costs")
	else:
		log_message("WARNING: Could not afford operating costs! Guild reputation may suffer")
		# Could add reputation system later

func process_customer_visits():
	"""Handle customers visiting the tavern and consuming beer"""
	var base_customers = randi_range(2, 5)
	var reputation_bonus = min(adventurers.size(), 3)  # More adventurers = better reputation
	customer_visits = base_customers + reputation_bonus
	
	var current_beer = get_current_beer()
	var beer_consumed = min(customer_visits, current_beer)
	var beer_sales_gold = beer_consumed * 6  # Sell beer for 2 gold each
	
	if beer_consumed > 0:
		update_beer(-beer_consumed)
		update_gold(beer_sales_gold)
		log_message(str(customer_visits) + " customers visited the tavern")
		log_message("Sold " + str(beer_consumed) + " beer for " + str(beer_sales_gold) + " gold")
		
		if beer_consumed < customer_visits:
			var missed_customers = customer_visits - beer_consumed
			log_message("WARNING: " + str(missed_customers) + " customers left disappointed - no beer!")
			log_message("Consider stocking more beer to maximize profits")
	else:
		log_message(str(customer_visits) + " customers visited but you had no beer to serve")
		log_message("Lost potential income! Visit the bar to purchase beer")

func process_adventurer_recovery():
	"""Handle injured adventurers recovering"""
	for adventurer in adventurers:
		if adventurer.has("recovery_days") and adventurer.recovery_days > 0:
			adventurer.recovery_days -= 1
			if adventurer.recovery_days <= 0:
				adventurer.status = "Ready"
				log_message(adventurer.name + " has recovered from injuries!")

func reset_daily_content():
	"""Reset missions and recruitment for new day"""
	# Reset missions in mission board
	var mission_popup = get_node_or_null("GameUI/PopupManager/MissionBoardPopup")
	if mission_popup and mission_popup.has_method("refresh_daily_missions"):
		mission_popup.refresh_daily_missions()
	
	# Reset recruitment
	var recruitment_popup = get_node_or_null("GameUI/PopupManager/RecruitmentPopup")
	if recruitment_popup and recruitment_popup.has_method("refresh_daily_recruits"):
		recruitment_popup.refresh_daily_recruits()

func check_tax_deadline():
	"""Check tax payment deadline and handle consequences"""
	var days_until_tax = tax_due_day - current_day
	
	if days_until_tax == 5:
		log_message("NOTICE: Tax payment due in 5 days! Need 50 gold")
	elif days_until_tax == 1:
		log_message("URGENT: Tax payment due TOMORROW! Need 50 gold")
	elif days_until_tax <= 0:
		handle_tax_payment()

func handle_tax_payment():
	"""Handle the monthly tax payment"""
	var tax_amount = calculate_tax_owed()
	
	if get_current_gold() >= tax_amount:
		update_gold(-tax_amount)
		tax_due_day += 30  # Next tax due in 30 days
		log_message("Successfully paid " + str(tax_amount) + " gold in taxes")
		log_message("Next tax payment due on day " + str(tax_due_day))
	else:
		log_message("FAILURE: Could not pay taxes!")
		log_message("GAME OVER: Your guild license has been revoked")
		# Could trigger game over screen here

func calculate_tax_owed() -> int:
	"""Calculate tax based on guild size and success"""
	var base_tax = 50
	var adventurer_tax = adventurers.size() * 5
	return base_tax + adventurer_tax

func get_current_beer() -> int:
	"""Get current beer from UI label"""
	var parts = beer_label.text.split(" ")
	return int(parts[1])

func update_beer(change: int):
	"""Update beer display"""
	var current_beer = get_current_beer()
	var new_beer = current_beer + change
	beer_label.text = "Beer: " + str(new_beer)
	
func _on_sleep_complete():
	"""Called when fade transition completes - do the actual day advancement"""
	current_day += 1
	log_message("🌅 Day " + str(current_day) + " begins...")
