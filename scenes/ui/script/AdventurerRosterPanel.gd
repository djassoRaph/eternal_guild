# AdventurerRosterPanel.gd
extends Control

@onready var roster_list = $RosterScrollContainer/RosterList

# Preload the card template
var adventurer_card_scene = preload("res://scenes/ui/AdventurerCard.tscn")

# Track spawned cards
var adventurer_cards: Dictionary = {}

# CRITICAL FIX: Prevent overlapping refresh calls
var is_refreshing: bool = false

func _ready():
	print("Adventurer Roster Panel initialized")
	
	# Connect to GameManager signals
	if GameManager:
		GameManager.adventurer_roster_changed.connect(_on_roster_changed)
		GameManager.day_changed.connect(_on_day_changed)
	
	# Initial population
	refresh_roster()
	
	# Start hidden (off-screen to the right)
	position.x = 1920  # Off-screen
	visible = true

func _input(event):
	"""Handle Tab key to toggle panel"""
	if event.is_action_pressed("ui_focus_next"):  # Tab key
		toggle_panel()


func toggle_panel():
	"""Toggle panel visibility (used by Tab key)"""
	if position.x >= 1920:  # Currently hidden
		show_panel()
	else:  # Currently visible
		hide_panel()

func show_panel():
	"""Slide panel in from right (only if currently hidden)"""
	if position.x >= 1920:  # Currently hidden
		var tween = create_tween()
		tween.set_ease(Tween.EASE_OUT)
		tween.set_trans(Tween.TRANS_CUBIC)
		tween.tween_property(self, "position:x", 1570, 0.3)
		print("Opening roster panel")
	# If already visible, do nothing (keep it shown)

func hide_panel():
	"""Slide panel out to right (only if currently visible)"""
	if position.x < 1920:  # Currently visible
		var tween = create_tween()
		tween.set_ease(Tween.EASE_OUT)
		tween.set_trans(Tween.TRANS_CUBIC)
		tween.tween_property(self, "position:x", 1920, 0.3)
		print("Closing roster panel")
	# If already hidden, do nothing



func refresh_roster():
	"""Rebuild entire roster from GameManager"""
	# CRITICAL FIX: Prevent overlapping refreshes
	if is_refreshing:
		print("Refresh already in progress, skipping...")
		return
	
	is_refreshing = true
	print("Refreshing adventurer roster...")
	
	# Clear ALL children from roster_list
	for child in roster_list.get_children():
		child.queue_free()
	
	# Clear the tracking dictionary
	adventurer_cards.clear()
	
	# Wait for nodes to actually be freed
	await get_tree().process_frame
	
	# Get adventurers from GameManager
	var adventurers = GameManager.adventurers
	print("Found ", adventurers.size(), " adventurers to display")
	
	if adventurers.size() == 0:
		_show_empty_roster_message()
	else:
		# Create card for each adventurer
		for adventurer in adventurers:
			create_adventurer_card(adventurer)
	
	# CRITICAL FIX: Release the lock after refresh completes
	is_refreshing = false
	print("Roster refresh complete")

func _show_empty_roster_message():
	"""Display message when no adventurers hired"""
	var empty_label = Label.new()
	empty_label.text = "No adventurers in guild\nVisit recruitment desk to hire"
	empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	empty_label.add_theme_font_size_override("font_size", 12)
	empty_label.add_theme_color_override("font_color", Color.GRAY)
	roster_list.add_child(empty_label)  # FIXED: Use roster_list

func _get_adventurer_level(adventurer: Dictionary) -> int:
	"""Calculate level based on completed missions"""
	var missions = adventurer.get("missions_completed", 0)
	if missions < 3:
		return 1
	elif missions < 8:
		return 2
	elif missions < 15:
		return 3
	elif missions < 25:
		return 4
	elif missions < 40:
		return 5
	else:
		return 6

func _coerce_status(s) -> int:
	# Godot JSON loads saved statuses as floats (and roster ones as strings); coerce to the enum int.
	if s is String:
		return AdventurerStatus.from_save(s)
	return int(s)

func _get_status_display(adventurer: Dictionary) -> String:
	match _coerce_status(adventurer.get("status", AdventurerStatus.Status.READY)):
		AdventurerStatus.Status.READY:
			return "Ready"
		AdventurerStatus.Status.ON_MISSION:
			var mission_name = adventurer.get("current_mission", "Unknown Mission")
			return "On Mission: " + str(mission_name)
		AdventurerStatus.Status.WOUNDED:
			var days = int(adventurer.get("recovery", 0))
			return "Wounded (" + str(days) + " day" + ("s" if days != 1 else "") + ")"
		AdventurerStatus.Status.RESTING:
			var days = int(adventurer.get("recovery", 0))
			return "Resting (" + str(days) + " day" + ("s" if days != 1 else "") + ")"
		_:
			return "Unknown"

func create_adventurer_card(adventurer: Dictionary):
	"""Spawn and populate a single adventurer card"""
	# id computed first so the drag script receives it before _ready() fires
	var adventurer_id = adventurer.get("id", adventurer.get("name"))

	var card = adventurer_card_scene.instantiate()
	card.set_script(preload("res://scenes/ui/script/adventurer_card.gd"))
	card.adventurer_id = adventurer_id
	roster_list.add_child(card)
	
	# Get references to the card's internal nodes
	var card_content = card.get_node("CardContent")
	var portrait = card_content.get_node("Portrait")
	var info_container = card_content.get_node("InfoContainer")
	
	# Populate the labels
	var name_label = info_container.get_node("NameLabel")
	var class_label = info_container.get_node("ClassLabel")
	var status_label = info_container.get_node("StatusLabel")
	var wage_label = info_container.get_node("WageLabel")
	
	name_label.text = adventurer.get("name", "Unknown")
	
	# Class and level
	var adv_class = adventurer.get("class", "Adventurer")
	var level = _get_adventurer_level(adventurer)  # FIXED: Use the function
	class_label.text = adv_class + " (Level " + str(level) + ")"
	
	# Status with color coding
	var status = _coerce_status(adventurer.get("status", AdventurerStatus.Status.READY))
	status_label.text = "Status: " + _get_status_display(adventurer)

	match status:
		AdventurerStatus.Status.READY:
			status_label.add_theme_color_override("font_color", Color.GREEN)
		AdventurerStatus.Status.RESTING:
			status_label.add_theme_color_override("font_color", Color.YELLOW)
		AdventurerStatus.Status.WOUNDED:
			status_label.add_theme_color_override("font_color", Color.RED)
		AdventurerStatus.Status.ON_MISSION:
			status_label.add_theme_color_override("font_color", Color.CYAN)
	
	# Daily wage
	wage_label.text = "Daily Cost: 1 gold"
	
	# Portrait via shared socket: Tarot art → class portrait → class-colored silhouette (Story 7.5)
	portrait.texture = PortraitSocket.resolve_texture(adventurer)
	
	# Grey out cards for adventurers who aren't currently Ready
	var is_ready := false
	for adv in GameManager.get_ready_adventurers():
		if adv.get("id", adv.get("name")) == adventurer_id:
			is_ready = true
			break
	if not is_ready:
		card.modulate = Color(0.55, 0.55, 0.55, 0.80)

	# Store card reference
	adventurer_cards[adventurer_id] = card

	print("Created card for: ", adventurer.get("name"))

func _on_roster_changed():
	"""Called when GameManager adventurer roster changes"""
	print("Roster changed signal received!")
	refresh_roster()
	show_panel()

func _on_day_changed(new_day: int):
	"""Called when day advances - refresh to update recovery timers"""
	refresh_roster()
