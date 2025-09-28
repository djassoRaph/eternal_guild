extends Node3D
#main_tavern.gd - UPDATED FOR GAMEMANAGER

@onready var game_log = $GameUI/MainArea/TavernView/LogContainer/EventLog
@onready var log_container = $GameUI/MainArea/TavernView/LogContainer
@onready var day_label = $GameUI/TopStatsBar/DayLabel
@onready var gold_label = $GameUI/TopStatsBar/GoldLabel
@onready var beer_label = $GameUI/TopStatsBar/BeerLabel
@onready var fade_system = %FadeToBlack

func _ready():
	
	log_message("Game started successfully!")

	# Allow this node to process input even when paused
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	# Connect fade system
	if fade_system:
		fade_system.fade_complete.connect(_on_sleep_complete)
	
	# Connect GameManager signals to update UI
	GameManager.gold_changed.connect(_on_gold_changed)
	GameManager.beer_changed.connect(_on_beer_changed)
	GameManager.day_changed.connect(_on_day_changed)
	GameManager.game_over_triggered.connect(_on_game_over_triggered)
	
	# Initialize UI with current GameManager values
	_on_gold_changed(GameManager.get_gold())
	_on_beer_changed(GameManager.get_beer())
	_on_day_changed(GameManager.get_day())
	
	print("UI connected to GameManager signals")

# === UI UPDATE FUNCTIONS (Connected to GameManager signals) ===
func _on_gold_changed(new_amount: int):
	"""Update gold display when GameManager gold changes"""
	gold_label.text = "Gold: " + str(new_amount)

func _on_beer_changed(new_amount: int):
	"""Update beer display when GameManager beer changes"""
	beer_label.text = "Beer: " + str(new_amount)

func _on_day_changed(new_day: int):
	"""Update day display when GameManager day changes"""
	day_label.text = "Day: " + str(new_day)

# === DAY ADVANCEMENT ===
func advance_to_next_day():
	"""Handle day advancement - GameManager does the processing"""
	log_message("Preparing for the next day...")
	fade_system.start_sleep_fade()

func _on_sleep_complete():
	"""Called when fade completes - trigger GameManager day advancement"""
	log_message("Ready for another day of guild management!")

# === LEGACY SUPPORT FUNCTIONS (for existing popups) ===
func get_adventurer_count() -> int:
	"""Legacy function - redirect to GameManager"""
	return GameManager.get_adventurer_count()

func get_ready_adventurers() -> Array:
	"""Legacy function - redirect to GameManager"""
	return GameManager.get_ready_adventurers()

func get_max_adventurers() -> int:
	"""Legacy function - redirect to GameManager"""
	return GameManager.get_max_adventurers()

func complete_mission(adventurer: Dictionary, mission: Dictionary, success: bool):
	"""Legacy function - redirect to GameManager"""
	GameManager.complete_mission(adventurer, mission, success)

func complete_party_mission(party: Array, mission: Dictionary, success: bool):
	"""Legacy function - redirect to GameManager"""
	GameManager.complete_party_mission(party, mission, success)

func hire_recruit(recruit: Dictionary):
	"""Legacy function - redirect to GameManager"""
	if GameManager.hire_adventurer(recruit):
		log_message("Successfully hired " + recruit.name + "!")
	else:
		log_message("Could not hire " + recruit.name + " - insufficient funds or roster full!")

func get_current_gold() -> int:
	"""Legacy function - redirect to GameManager"""
	return GameManager.get_gold()

func update_gold(change: int):
	"""Legacy function - redirect to GameManager"""
	if change > 0:
		GameManager.add_gold(change)
	else:
		GameManager.spend_gold(-change)

func get_current_beer() -> int:
	"""Legacy function - redirect to GameManager"""
	return GameManager.get_beer()

func update_beer(change: int):
	"""Legacy function - redirect to GameManager"""
	if change > 0:
		GameManager.add_beer(change)
	else:
		GameManager.consume_beer(-change)

# === INPUT HANDLING ===
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
	get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")

func _on_quit_button_pressed() -> void:
	print("_on_quit_button_pressed log")
	get_tree().quit()

# === LOGGING SYSTEM ===
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

func fix_floor_collision():
	# Get all StaticBody3D nodes in Architecture
	var architecture = get_node("SubViewportContainer/SubViewport/Architecture")
	
	# Fix main floor
	var floor_body = architecture.get_node("Floor/StaticBody3D")
	if floor_body:
		floor_body.collision_layer = 2
		print("Fixed main floor collision_layer = 2")
	
	# Fix entrance floor
	var entrance_body = architecture.get_node("FloorEntrance/StaticBody3D")  
	if entrance_body:
		entrance_body.collision_layer = 2
		print("Fixed entrance floor collision_layer = 2")
	
	# Fix all furniture that NPCs might walk into
	var furniture = get_node("SubViewportContainer/SubViewport/Furniture")
	
	# Fix bar counter
	var bar_body = furniture.get_node("Bar/BarCounter/StaticBody3D")
	if bar_body:
		bar_body.collision_layer = 2
		print("Fixed bar collision_layer = 2")
	
	print("All floor collision layers fixed!")


func _on_game_over_triggered(reason: String):
	"""Handle game over event"""
	var game_over_screen = get_node("GameUI/GameOverScreen")
	if game_over_screen:
		game_over_screen.show_game_over(reason)
	else:
		print("GameOverScreen not found!")
