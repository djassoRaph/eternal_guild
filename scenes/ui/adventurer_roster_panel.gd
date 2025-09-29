# adventurer_roster_panel.gd
extends Control

@onready var roster_list = $RosterScrollContainer/RosterList

# Preload the card template
var adventurer_card_scene = preload("res://scenes/ui/AdventurerCard.tscn")

# Track spawned cards
var adventurer_cards: Dictionary = {}

func _ready():
	print("🎯 Adventurer Roster Panel initialized")
	
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
	"""Slide panel in/out"""
	var tween = create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_CUBIC)
	
	if position.x >= 1920:  # Currently hidden
		# Slide in from right
		tween.tween_property(self, "position:x", 1570, 0.3)
		print("📂 Opening roster panel")
	else:  # Currently visible
		# Slide out to right
		tween.tween_property(self, "position:x", 1920, 0.3)
		print("📁 Closing roster panel")

func refresh_roster():
	"""Rebuild entire roster from GameManager"""
	print("🔄 Refreshing adventurer roster...")
	
	# Clear existing cards
	for card in adventurer_cards.values():
		card.queue_free()
	adventurer_cards.clear()
	
	# Get adventurers from GameManager
	var adventurers = GameManager.adventurers
	
	print("Found ", adventurers.size(), " adventurers to display")
	
	# Create card for each adventurer
	for adventurer in adventurers:
		create_adventurer_card(adventurer)

func create_adventurer_card(adventurer: Dictionary):
	"""Spawn and populate a single adventurer card"""
	# Instance the card template
	var card = adventurer_card_scene.instantiate()
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
	var level = adventurer.get("level", 1)
	class_label.text = adv_class + " (Level " + str(level) + ")"
	
	# Status with color coding
	var status = adventurer.get("status", "Ready")
	status_label.text = "Status: " + status
	
	match status:
		"Ready":
			status_label.add_theme_color_override("font_color", Color.GREEN)
		"Resting":
			status_label.add_theme_color_override("font_color", Color.YELLOW)
			var recovery = adventurer.get("recovery", 0)
			if recovery > 0:
				status_label.text += " (" + str(recovery) + " days)"
		"Injured":
			status_label.add_theme_color_override("font_color", Color.RED)
			var recovery = adventurer.get("recovery", 0)
			if recovery > 0:
				status_label.text += " (" + str(recovery) + " days)"
		"on_mission":
			status_label.add_theme_color_override("font_color", Color.CYAN)
	
	# Daily wage
	wage_label.text = "Daily Cost: 1 gold"
	
	# Set portrait based on class
	var portrait_path = get_portrait_path(adv_class)
	if FileAccess.file_exists(portrait_path):
		portrait.texture = load(portrait_path)
	else:
		# Fallback to colored rectangle (already handled by default)
		print("⚠️ Portrait not found for class: ", adv_class)
	
	# Store card reference
	var adventurer_id = adventurer.get("id", adventurer.get("name"))
	adventurer_cards[adventurer_id] = card
	
	print("✅ Created card for: ", adventurer.get("name"))

func get_portrait_path(character_class: String) -> String:
	"""Get portrait file path based on class"""
	var class_lower = character_class.to_lower()
	return "res://assets/portraits/" + class_lower + ".png"

func _on_roster_changed():
	"""Called when GameManager adventurer roster changes"""
	print("🔔 Roster changed signal received!")
	refresh_roster()

func _on_day_changed(new_day: int):
	"""Called when day advances - refresh to update recovery timers"""
	refresh_roster()
