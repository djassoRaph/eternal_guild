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

var reputation_label: Label  # code-built (Epic 14) — no scene-file changes needed

const ZONE_PROMPT_UI := preload("res://scripts/game/ZonePromptUI.gd")
const DISTURBANCE_DIRECTOR := "res://scripts/game/disturbance_director.gd"   # Story 14.4 (loaded by path)
const ROYAL_MESSENGER := "res://scripts/game/royal_messenger.gd"   # Story 10.7: the demo's ending (loaded by path)


## Story 4.2 review P4: the event log sits on the hall's HUD layer, which draws over the hall's popups (the hire desk,
## the bar's stock, the bedroom): while one is open (ZonePromptUI.modal_open, the one rule) the log steps aside, its
## panel too (GameUI/MainArea holds only the log; it also stopped the mouse over the popup's left side).
func _process(_delta: float) -> void:
	var log_area = get_node_or_null("GameUI/MainArea")
	if log_area:
		log_area.visible = not ZONE_PROMPT_UI.modal_open(get_tree())
	var top_bar = get_node_or_null("GameUI/TopStatsBar")
	if top_bar:
		top_bar.visible = not GameManager.game_over_active   # Story 13.4 review P9: the fall screen owns the screen


func _ready():
	await get_tree().process_frame
	await get_tree().process_frame
	_init_zone_prompts()
	_fix_welcome_tax_line()   # Story 14.6: the welcome text states the active profile's tax
	var director = load(DISTURBANCE_DIRECTOR).new()   # Story 14.4: today's tavern disturbance, shown in the day phase
	director.name = "DisturbanceDirector"
	add_child(director)
	var messenger = load(ROYAL_MESSENGER).new()   # Story 10.7: the King's messenger on the demo ending's day (demo only)
	messenger.name = "RoyalMessenger"
	add_child(messenger)
	log_message("Game started successfully!")
	add_to_group("main_tavern")
	# Epic 16 (Stories 16.3, 16.4): the hall's staff work by themselves (their brains); elsewhere they stay cosmetic
	get_tree().call_group("staff", "enable_automation")
	# Allow this node to process input even when paused
	process_mode = Node.PROCESS_MODE_ALWAYS
		
	# Connect GameManager signals to update UI
	GameManager.gold_changed.connect(_on_gold_changed)
	GameManager.beer_changed.connect(_on_beer_changed)
	GameManager.day_changed.connect(_on_day_changed)
	GameBus.game_over_triggered.connect(_on_game_over_triggered)   # Story 13.4: the fall, by its cause key
	
	GameManager.firewood_changed.connect(_on_firewood_changed)
	GameManager.fireplace_fuel_changed.connect(_on_fuel_changed)
	GameManager.reputation_changed.connect(_on_reputation_changed)

	# Reputation label — code-built and appended to the existing TopStatsBar (Epic 14)
	reputation_label = Label.new()
	$GameUI/TopStatsBar.add_child(reputation_label)

	# Initialize UI with current GameManager values
	_on_gold_changed(GameManager.get_gold())
	_on_beer_changed(GameManager.get_beer())
	_on_day_changed(GameManager.get_day())
	_on_firewood_changed(GameManager.get_firewood_stock())
	_on_fuel_changed(GameManager.get_fireplace_fuel())
	_on_reputation_changed(GameManager.tavern_reputation)

	print("UI connected to GameManager signals")

	# New-Game overwrite-window fix (Epic 11) — write the fresh Day 1 state to disk now,
	# rather than waiting for the Day-2 autosave, so quitting early doesn't leave the
	# previous run's save behind for Continue to pick up.
	if GameManager.pending_new_game_save:
		GameManager.pending_new_game_save = false
		SaveSystem.start_new_run_save()   # also starts the run: the automatic saves may now write (Story 11.2 review)
		GameManager.check_tax_warning()   # Story 14.6 review P10: a first tax due within the warning days (the demo's Day 3) is warned on Day 1


# === UI UPDATE FUNCTIONS (Connected to GameManager signals) ===
func _on_gold_changed(new_amount: int):
	"""Update gold display when GameManager gold changes"""
	gold_label.text = "Gold: " + str(new_amount)

func _on_reputation_changed(new_value: int):
	"""Update reputation display when GameManager reputation changes (Epic 14)"""
	if reputation_label:
		var tier: Dictionary = GameManager.get_reputation_tier()
		reputation_label.text = "Reputation: " + str(new_value) + " (" + str(tier.get("label", "Unknown")) + ")"

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
	if GameManager.game_over_active: return   # Story 13.4 (DG-8): the fall screen owns the keys (no pause menu, no F9/F10)
	if str(GameManager.demo_ending.get("state", "")) == "ended": return   # Story 10.7: the demo's end (a panel, the card) owns the keys
	# A conversation is open (Story 10.2): the dialogue box reads Esc/E/Space first and ends the conversation
	# itself. Nothing here acts meanwhile: Esc never toggles the pause menu, and the debug keys (F9, F10)
	# stand down (F10 would wipe the run mid-conversation). Only a mission screen that opened over the box
	# still closes on Esc.
	if not get_tree().get_nodes_in_group("dialogue_open").is_empty():
		if event.is_action_pressed("ui_cancel"):
			for board in get_tree().get_nodes_in_group("mission_board"):
				if board.visible:
					board.visible = false
					return
		return

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
		# (Story 13.4: the B key's test game over is gone: a fall now ends the run for real. F12 > Failures has them.)

func toggle_pause_menu():
	pause_menu.visible = !pause_menu.visible
	# Freeze the whole game world (player, patrons, fireplace drain) while the menu is up.
	set_world_frozen(pause_menu.visible)
	print("PauseMenu visible: ", pause_menu.visible)

## The hall's world frozen or running (Story 18.1, DC-11; split out of toggle_pause_menu, same effect): the
## SubViewportContainer DISABLED (the player, patrons, staff, the fire's zone stop) and the mouse off it. This root runs
## ALWAYS, so a tree pause alone would leave the hall running; we DISABLE the game subtree instead so this script keeps
## catching ESC. The pause menu, the Codex opened from the hall's book and the demo ending's stop_hall() use it.
func set_world_frozen(on: bool) -> void:
	var svc = get_node_or_null("SubViewportContainer")
	if svc:
		svc.mouse_filter = Control.MOUSE_FILTER_IGNORE if on else Control.MOUSE_FILTER_STOP
		svc.process_mode = Node.PROCESS_MODE_DISABLED if on else Node.PROCESS_MODE_INHERIT

func is_world_frozen() -> bool:
	var svc = get_node_or_null("SubViewportContainer")
	return svc != null and svc.process_mode == Node.PROCESS_MODE_DISABLED

# Pause-menu buttons (Main Menu / Save / Load / Save & Exit / Quit) are owned by
# pause_menu.gd, attached to the PauseMenu CanvasLayer. main_tavern only shows/hides it.

## Story 14.6: the welcome text (MainTavern.tscn's EventLog) said "Tax day comes every 30 days! ... 1000 gold coins"
## whatever the profile; its "- Tax day comes every" line is replaced from the active tax config at load (on a grace day:
## overdue since the due day, review P11).
func _fix_welcome_tax_line() -> void:
	if not (game_log is RichTextLabel):
		return
	var lines: PackedStringArray = game_log.text.split("\n")
	for i in lines.size():
		if lines[i].begins_with("- Tax day comes every"):
			lines[i] = GameManager.tax_rule_line(GameManager.tax_config(), GameManager.tax_due_day, GameManager.current_day)
	game_log.text = "\n".join(lines)

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

func _on_game_over_triggered(reason: String):
	"""The guild fell (Story 13.4): `reason` is the cause key; the screen shows 'The Guild Falls'."""
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
	# One prompt manager (Story 25.10): the scene's GameUI already runs ZonePromptUI; a second one made
	# two labels print over each other and split the zones between two E arbiters.
	var zui = zui_script.find(get_tree())
	if zui == null:
		zui = zui_script.new()
		add_child(zui)
	zui.connect_tavern_zones()
	print("Tavern zone prompts initialized")
