extends PopupPanel

@onready var main_container = $MainContainer

# Available recruits for the day
var available_recruits = []

func _ready():
	print("Recruitment Popup ready")

func open_recruitment_desk():
	generate_daily_recruits()
	populate_popup_content()
	popup_centered()

func populate_popup_content():
	# Clear existing content
	for child in main_container.get_children():
		child.queue_free()
	
	await get_tree().process_frame
	
	# Create the recruitment interface
	create_recruitment_ui()

func create_recruitment_ui():
	# Guild master greeting
	var greeting = Label.new()
	greeting.text = "\"Welcome, Guildmaster! These brave souls seek to join your guild.\""
	greeting.add_theme_font_size_override("font_size", 14)
	greeting.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	main_container.add_child(greeting)
	
	send_log_message("\"Welcome, Guildmaster! These brave souls seek to join your guild.\"")
	
	# Available recruits section
	var recruits_title = Label.new()
	recruits_title.text = "Available Applicants Today"
	recruits_title.add_theme_font_size_override("font_size", 16)
	recruits_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	main_container.add_child(recruits_title)
	
	# Recruits container
	var recruits_scroll = ScrollContainer.new()
	recruits_scroll.custom_minimum_size = Vector2(600, 400)
	main_container.add_child(recruits_scroll)
	
	var recruits_container = VBoxContainer.new()
	recruits_scroll.add_child(recruits_container)
	recruits_container.add_theme_constant_override("separation", 10)
	
	# Create recruit cards
	for recruit in available_recruits:
		create_recruit_card(recruit, recruits_container)

func generate_daily_recruits():
	"""Generate 3-5 random applicants for the day"""
	if available_recruits.size() > 0:
		return  # Already generated for today
		
	available_recruits.clear()
	var num_recruits = randi() % 3 + 3  # 3-5 recruits
	
	for i in range(num_recruits):
		var recruit = create_recruit_applicant()
		available_recruits.append(recruit)
	
	send_log_message("📋 " + str(num_recruits) + " new applicants have arrived today!")

func create_recruit_applicant() -> Dictionary:
	"""Create a potential recruit with stats and hiring cost"""
	var recruit = create_adventurer()  # Use existing function from main
	
	# Add recruitment-specific data
	recruit["hiring_cost"] = calculate_hiring_cost(recruit)
	recruit["personality"] = get_random_personality()
	recruit["background"] = get_random_background(recruit.class)
	recruit["availability"] = "Available"
	
	return recruit

func create_adventurer() -> Dictionary:
	"""Create an adventurer with random stats"""
	var adventurer_names = ["Brom", "Ezren", "Kael", "Lyra", "Nim", "Tarin", "Zara", "Garrick", "Mira", "Thorne", "Elira", "Doran", "Sylas", "Iris", "Raphio", "Aiden", "Cora", "Finn", "Runa", "Tobias"]
	var adventurer_classes = ["Fighter", "Rogue", "Mage", "Healer"]
	
	var adv_name = adventurer_names[randi() % adventurer_names.size()]
	var adv_class = adventurer_classes[randi() % adventurer_classes.size()]
	
	var stats = {
		"strength": randi() % 6 + 1,
		"dexterity": randi() % 6 + 1,
		"intelligence": randi() % 6 + 1,
		"endurance": randi() % 6 + 1
	}
	
	# Class bonuses
	match adv_class:
		"Fighter":
			stats.strength += 2
			stats.endurance += 1
		"Rogue":
			stats.dexterity += 2
		"Mage":
			stats.intelligence += 2
		"Healer":
			stats.intelligence += 1
	
	var adventurer = {
		"id": randi() % 10000 + 1000,  # Temporary ID
		"name": adv_name,
		"class": adv_class,
		"status": "Ready",
		"recovery": 0,
		"strength": stats.strength,
		"dexterity": stats.dexterity,
		"intelligence": stats.intelligence,
		"endurance": stats.endurance,
		"missions_completed": 0,
		"missions_failed": 0,
		"gold_earned": 0,
		"injuries_sustained": 0
	}
	
	return adventurer

func calculate_hiring_cost(recruit: Dictionary) -> int:
	"""Calculate hiring cost based on stats and class"""
	var base_cost = 10
	var stat_total = recruit.strength + recruit.dexterity + recruit.intelligence + recruit.endurance
	var stat_bonus = (stat_total - 16) * 2  # Above average gets more expensive
	var class_bonus = 0
	
	match recruit.class:
		"Fighter": class_bonus = 0
		"Rogue": class_bonus = 2
		"Mage": class_bonus = 5
		"Healer": class_bonus = 8  # Most expensive
	
	return max(5, base_cost + stat_bonus + class_bonus)

func get_random_personality() -> String:
	"""Get a random personality trait"""
	var personalities = [
		"Eager", "Cautious", "Brave", "Greedy", "Loyal", "Reckless", 
		"Wise", "Ambitious", "Humble", "Proud", "Calm", "Fiery",
		"Cheerful", "Stoic", "Curious", "Determined"
	]
	return personalities[randi() % personalities.size()]

func get_random_background(character_class: String) -> String:
	"""Get a background story based on class"""
	var backgrounds = {
		"Fighter": [
			"Former city guard",
			"Retired soldier", 
			"Village protector",
			"Tournament fighter",
			"Mercenary veteran",
			"Blacksmith's apprentice"
		],
		"Rogue": [
			"Reformed thief",
			"Scout from the borderlands",
			"Former spy",
			"Treasure hunter",
			"Street informant",
			"Circus performer"
		],
		"Mage": [
			"Academy dropout",
			"Wandering scholar",
			"Court wizard's apprentice",
			"Self-taught spellcaster",
			"Library researcher",
			"Ancient tome collector"
		],
		"Healer": [
			"Temple acolyte",
			"Traveling physician",
			"Herbalist from the forest",
			"Military medic",
			"Village wise woman",
			"Monastery refugee"
		]
	}
	var class_backgrounds = backgrounds.get(character_class, ["Unknown origin"])
	return class_backgrounds[randi() % class_backgrounds.size()]

func create_recruit_card(recruit: Dictionary, parent: VBoxContainer):
	"""Create a card showing recruit details and hire option"""
	var card = PanelContainer.new()
	parent.add_child(card)
	
	# Style the card
	var card_style = StyleBoxFlat.new()
	card_style.bg_color = Color(0.1, 0.2, 0.1, 0.9)  # Dark green background
	card_style.border_width_left = 2
	card_style.border_width_right = 2
	card_style.border_width_top = 2
	card_style.border_width_bottom = 2
	card_style.border_color = Color(0.4, 0.8, 0.4, 1.0)  # Green border
	card.add_theme_stylebox_override("panel", card_style)
	
	var card_content = HBoxContainer.new()
	card.add_child(card_content)
	card_content.add_theme_constant_override("separation", 20)
	
	# Left side: Character info
	var info_container = VBoxContainer.new()
	card_content.add_child(info_container)
	info_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	# Name and class
	var name_label = Label.new()
	name_label.text = "🗡️ " + recruit.name + " the " + recruit.class
	name_label.add_theme_font_size_override("font_size", 16)
	name_label.add_theme_color_override("font_color", Color.WHITE)
	info_container.add_child(name_label)
	
	# Stats
	var stats_label = Label.new()
	stats_label.text = "💪" + str(recruit.strength) + " | 🏃" + str(recruit.dexterity) + " | 🧠" + str(recruit.intelligence) + " | ❤️" + str(recruit.endurance)
	stats_label.add_theme_font_size_override("font_size", 12)
	stats_label.add_theme_color_override("font_color", Color.LIGHT_GRAY)
	info_container.add_child(stats_label)
	
	# Personality and background
	var personality_label = Label.new()
	personality_label.text = "📖 " + recruit.personality + " • " + recruit.background
	personality_label.add_theme_font_size_override("font_size", 11)
	personality_label.add_theme_color_override("font_color", Color.CYAN)
	info_container.add_child(personality_label)
	
	# Right side: Hiring section
	var hiring_container = VBoxContainer.new()
	card_content.add_child(hiring_container)
	hiring_container.custom_minimum_size = Vector2(150, 0)
	hiring_container.add_theme_constant_override("separation", 5)
	
	# Cost label
	var cost_label = Label.new()
	cost_label.text = "Hiring Cost: " + str(recruit.hiring_cost) + "g"
	cost_label.add_theme_font_size_override("font_size", 14)
	cost_label.add_theme_color_override("font_color", Color.YELLOW)
	cost_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hiring_container.add_child(cost_label)
	
	# Hire button
	var hire_button = Button.new()
	hire_button.custom_minimum_size = Vector2(120, 35)
	hiring_container.add_child(hire_button)
	
	# Check if we can hire
	var current_gold = get_current_gold()
	var current_roster_size = get_current_roster_size()
	var max_adventurers = get_max_adventurers()
	var can_hire = current_gold >= recruit.hiring_cost and current_roster_size < max_adventurers
	
	if can_hire:
		hire_button.text = "Hire"
		hire_button.pressed.connect(func(): hire_recruit(recruit))
	else:
		if current_gold < recruit.hiring_cost:
			hire_button.text = "Too Expensive"
		else:
			hire_button.text = "Roster Full"
		hire_button.disabled = true

func hire_recruit(recruit: Dictionary):
	"""Hire a recruit and add them to the main adventurers roster"""
	var main_script = get_tree().current_scene
	if main_script and main_script.has_method("hire_adventurer"):
		# Call main script to handle the hiring
		main_script.hire_adventurer(recruit)
		
		# Mark as hired
		recruit.availability = "Hired"
		
		# Close and reopen popup to refresh
		hide()
		await get_tree().create_timer(0.1).timeout
		open_recruitment_desk()
	else:
		send_log_message("❌ Error: Could not complete hiring process")

func get_current_gold() -> int:
	"""Get current gold from the main scene"""
	var gold_label = get_node_or_null("/root/Node3D/GameUI/TopStatsBar/GoldLabel")
	if gold_label:
		var parts = gold_label.text.split(" ")
		return int(parts[1])
	return 0

func get_current_roster_size() -> int:
	"""Get current adventurer count from main scene"""
	var main_script = get_tree().current_scene
	if main_script and main_script.has_method("get_adventurer_count"):
		return main_script.get_adventurer_count()
	return 0

func get_max_adventurers() -> int:
	"""Get max adventurers from main scene"""
	var main_script = get_tree().current_scene
	if main_script and main_script.has_method("get_max_adventurers"):
		return main_script.get_max_adventurers()
	return 5  # Default

func send_log_message(message: String):
	"""Send message to main game log"""
	var main_script = get_tree().current_scene
	if main_script and main_script.has_method("log_message"):
		await get_tree().process_frame
		main_script.log_message(message)
	else:
		print("LOG: " + message)
