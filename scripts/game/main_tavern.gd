extends Node3D
#main_tavern.gd

@onready var game_log = $GameUI/MainArea/TavernView/LogContainer/EventLog
@onready var log_container = $GameUI/MainArea/TavernView/LogContainer
@onready var day_label = $GameUI/TopStatsBar/DayLabel
@onready var gold_label = $GameUI/TopStatsBar/GoldLabel
@onready var beer_label = $GameUI/TopStatsBar/BeerLabel
@onready var fade_system = %FadeToBlack
@onready var game_over_screen = %GameOverScreen
@onready var pause_menu = %PauseMenu
@onready var firewood_label = $GameUI/TopStatsBar/FirewoodLabel
@onready var fuel_label = $GameUI/TopStatsBar/FuelLabel
@onready var phase_label = $GameUI/TopStatsBar/PhaseLabel


func _ready():
	await get_tree().process_frame
	await get_tree().process_frame
	_init_zone_prompts()
	log_message("Game started successfully!")
	add_to_group("main_tavern")
	# Allow this node to process input even when paused
	process_mode = Node.PROCESS_MODE_ALWAYS
		
	# Connect GameManager signals to update UI
	GameManager.gold_changed.connect(_on_gold_changed)
	GameManager.beer_changed.connect(_on_beer_changed)
	GameManager.day_changed.connect(_on_day_changed)
	GameManager.game_over_triggered.connect(_on_game_over_triggered)
	
	GameManager.firewood_changed.connect(_on_firewood_changed)
	GameManager.fireplace_fuel_changed.connect(_on_fuel_changed)
	
	# Initialize UI with current GameManager values
	_on_gold_changed(GameManager.get_gold())
	_on_beer_changed(GameManager.get_beer())
	_on_day_changed(GameManager.get_day())
	_on_firewood_changed(GameManager.get_firewood_stock())
	_on_fuel_changed(GameManager.get_fireplace_fuel())
	
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
	_update_day_phase_display()

func advance_day():
	"""Handle bedroom/sleep interaction - UPDATED FOR BEDROOM POPUP"""
	print("Opening bedroom/quarters...")
	var bedroom_popup = get_node("/root/Node3D/GameUI/PopupManager/BedroomPopup")
	if bedroom_popup and bedroom_popup.has_method("open_bedroom"):
		bedroom_popup.open_bedroom()
		log_message("Reviewing the day before resting...")
	else:
		print("Bedroom popup not found!")
		# Fallback: advance day immediately
		if GameManager.has_method("advance_day"):
			GameManager.despawn_all_patrons()
			GameManager.advance_day()



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
	# === STEP 1: Handle ESC key (highest priority) ===
	if event.is_action_pressed("ui_cancel"):
		# Try to close mission board first
		var mission_boards = get_tree().get_nodes_in_group("mission_board")
		for board in mission_boards:
			if board.visible:
				print("Closing mission board with ESC")
				board.visible = false
				return  # ESC handled - stop here
		
		# No mission board open, toggle pause menu
		print("Toggling pause menu with ESC")
		toggle_pause_menu()
		return  # ESC handled - stop here
	
	# === STEP 2: Block other input if ANY UI is open ===
	# Check if mission board is open
	var mission_boards = get_tree().get_nodes_in_group("mission_board")
	for board in mission_boards:
		if board.visible:
			return  # Block all non-ESC input
	
	# Check if pause menu is open
	if pause_menu and pause_menu.visible:
		return  # Block all non-ESC input
	
	# === STEP 3: Normal game input (only runs if no UI is open) ===
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_F9:
			GameManager.adventurer_roster_changed.emit()
			print("Force refreshed roster")
		
		elif event.keycode == KEY_F10:
			GameManager.reset_game_state()
			print("Game state reset!")
		
		elif event.keycode == KEY_B:
			print("Testing Game Over Screen...")
			GameManager.trigger_game_over("test_game_over", "TEST: Manual game over triggered with B key")

func toggle_pause_menu():
	pause_menu.visible = !pause_menu.visible
	var svc = get_node_or_null("SubViewportContainer")
	if svc:
		svc.mouse_filter = Control.MOUSE_FILTER_IGNORE if pause_menu.visible else Control.MOUSE_FILTER_STOP
		print("SVC mouse_filter is now: ", svc.mouse_filter)  # Should print 2 when paused
	print("PauseMenu visible: ", pause_menu.visible)

# Pause-menu buttons (Main Menu / Save / Load / Save & Exit / Quit) are owned by
# pause_menu.gd, attached to the PauseMenu CanvasLayer. main_tavern only shows/hides it.

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
		
		if not is_inside_tree():
			return
		await get_tree().process_frame
		# Scene may change mid-coroutine (e.g. Save & Exit to main menu) — re-check before EACH get_tree()
		if not is_inside_tree():
			return
		await get_tree().process_frame

		if not is_inside_tree():
			return
		log_container.queue_redraw()

		if log_container.get_v_scroll_bar():
			var vbar = log_container.get_v_scroll_bar()
			if not is_inside_tree():
				return
			await get_tree().process_frame
			if not is_inside_tree():
				return
			vbar.value = vbar.max_value

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
	var game_over_screen = get_node("GameOverScreen")  # Changed path
	if game_over_screen:
		game_over_screen.show_game_over(reason)
	else:
		print("GameOverScreen not found!")
		
		
func _on_firewood_changed(new_amount: int):
	"""Update firewood display when stock changes"""
	if firewood_label:
		var max_storage = GameManager.get_max_firewood_storage()
		firewood_label.text = "Wood: " + str(new_amount) + "/" + str(max_storage)

func _on_fuel_changed(new_percentage: float):
	"""Update fuel display when fire level changes — show comfort impact"""
	if fuel_label:
		var fuel_int = int(new_percentage)
		var color: Color
		var status_text: String

		if fuel_int >= 75:
			color = Color.GREEN
			status_text = "Fire: " + str(fuel_int) + "% — Cozy! +tips"
		elif fuel_int >= 50:
			color = Color.YELLOW
			status_text = "Fire: " + str(fuel_int) + "% — Warm"
		elif fuel_int >= 25:
			color = Color.ORANGE
			status_text = "Fire: " + str(fuel_int) + "% — Chilly"
		elif fuel_int > 0:
			color = Color.RED
			status_text = "Fire: " + str(fuel_int) + "% — Cold! No tips"
		else:
			color = Color.RED
			status_text = "Fire: OUT — No tips!"

		fuel_label.text = status_text
		fuel_label.add_theme_color_override("font_color", color)

func _update_day_phase_display():
	"""Update the day phase indicator — placeholder until full phase system"""
	if not phase_label:
		return

	var day = GameManager.get_day()
	phase_label.text = "Day " + str(day) + " — Morning"
	phase_label.add_theme_color_override("font_color", Color(0.9, 0.8, 0.5))
		
func _init_zone_prompts():
	var zui_script = preload("res://scripts/game/ZonePromptUI.gd")
	var zui = zui_script.new()
	add_child(zui)
	zui.connect_tavern_zones()
	print("Tavern zone prompts initialized")
