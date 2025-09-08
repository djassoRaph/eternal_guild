extends Node3D

@onready var game_log = $GameUI/MainArea/TavernView/LogContainer/EventLog
@onready var log_container = $GameUI/MainArea/TavernView/LogContainer
@onready var day_label = $GameUI/TopStatsBar/DayLabel
@onready var gold_label = $GameUI/TopStatsBar/GoldLabel
@onready var beer_label = $GameUI/TopStatsBar/BeerLabel
var adventurers = []
var max_adventurers = 5


func _ready():
	log_message("Game started successfully!")
	# Allow this node to process input even when paused
	process_mode = Node.PROCESS_MODE_ALWAYS

func _input(event):
	if event.is_action_pressed("ui_cancel"):
		toggle_pause_menu()

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
	else:
		log_message("💥 FAILED! " + adventurer.name + " failed the mission: " + mission.name)
		# Handle failure consequences

func complete_party_mission(party: Array, mission: Dictionary, success: bool, healer_count: int):
	"""Handle mission completion for party missions"""
	# Add your party mission completion logic here
	log_message("Party mission completed - implement full logic here")
	
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
