# recruitment_popup.gd 
extends PopupPanel

@onready var main_container = $MainContainer

# Available recruits for the day (fallback system)
var available_recruits = []

func _ready():
	print("Recruitment Popup ready")

func open_recruitment_desk():
	"""Main entry point - always use enhanced system"""
	# Try enhanced system first (when RecruitmentManager is ready)
	if GameManager.has_method("recruitment_manager") and GameManager.recruitment_manager:
		populate_enhanced_recruitment_content()
	else:
		# Fallback to basic system for now
		populate_basic_recruitment_content()
	
	popup_centered()

# ENHANCED SYSTEM (Future - when RecruitmentManager is implemented)
func populate_enhanced_recruitment_content():
	"""Enhanced recruitment with patron conversions"""
	# Clear existing content
	for child in main_container.get_children():
		child.queue_free()
	
	await get_tree().process_frame
	create_enhanced_recruitment_ui()

func create_enhanced_recruitment_ui():
	# Enhanced guild master greeting
	var greeting_context = get_recruitment_context()
	send_log_message("\"" + greeting_context + "\"")
	
	create_guild_status_display()
	
	# TWO SECTIONS: Daily Applicants + Patron Conversions
	create_daily_applicants_section()
	create_patron_conversions_section()

func get_recruitment_context() -> String:
	"""Dynamic greeting based on current situation"""
	# FUTURE: When RecruitmentManager is ready
	# var daily_count = GameManager.recruitment_manager.get_daily_applicants().size()
	# var patron_count = GameManager.recruitment_manager.get_patron_opportunities().size()
	
	# For now, basic greeting
	return "Welcome back! Several brave souls seek to join your guild today."

func create_daily_applicants_section():
	"""Section for regular daily applicants"""
	var gamemanager_recruits = GameManager.get_available_recruits()  # Fixed: Use get_available_recruits()
	
	if gamemanager_recruits.size() > 0:
		var daily_title = Label.new()
		daily_title.text = "Available Applicants (" + str(gamemanager_recruits.size()) + ")"  # Fixed: Use correct count
		daily_title.add_theme_font_size_override("font_size", 16)
		daily_title.add_theme_color_override("font_color", Color.CYAN)
		daily_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		main_container.add_child(daily_title)
		
		var daily_scroll = ScrollContainer.new()
		daily_scroll.custom_minimum_size = Vector2(600, 300)
		main_container.add_child(daily_scroll)
		
		var daily_container = VBoxContainer.new()
		daily_scroll.add_child(daily_container)
		daily_container.add_theme_constant_override("separation", 10)
		
		for applicant in gamemanager_recruits:  # Fixed: Proper indentation
			create_recruit_card(applicant, daily_container)

func create_patron_conversions_section():
	"""Section for patrons who expressed interest"""
	# FUTURE: When RecruitmentManager is implemented
	# var patron_opportunities = GameManager.recruitment_manager.get_patron_opportunities()
	# 
	# if patron_opportunities.size() > 0:
	#     ... create patron conversion cards
	
	# For now, just a placeholder
	var placeholder = Label.new()
	placeholder.text = "Patron recruitment system coming soon..."
	placeholder.add_theme_font_size_override("font_size", 12)
	placeholder.add_theme_color_override("font_color", Color.GRAY)
	placeholder.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	main_container.add_child(placeholder)

# BASIC SYSTEM (Current working version)
func populate_basic_recruitment_content():
	"""Basic recruitment system (current working version)"""
	# Clear existing content
	for child in main_container.get_children():
		child.queue_free()
	
	await get_tree().process_frame
	create_basic_recruitment_ui()

func create_basic_recruitment_ui():
	"""Redesigned: Roster section + Applicants section in a shared scroll container"""
	send_log_message("\"Welcome, Guildmaster! These brave souls seek to join your guild.\"")

	# Status row: gold + roster count
	create_guild_status_display()

	# Single scroll container wrapping both sections
	var scroll = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(600, 500)
	main_container.add_child(scroll)

	var content = VBoxContainer.new()
	content.add_theme_constant_override("separation", 8)
	scroll.add_child(content)

	# --- Section 1: YOUR GUILD ---
	var roster = GameManager.adventurers
	var roster_header = Label.new()
	roster_header.text = "⚔️ YOUR GUILD (" + str(roster.size()) + "/" + str(GameManager.get_max_adventurers()) + ")"
	roster_header.add_theme_font_size_override("font_size", 16)
	roster_header.add_theme_color_override("font_color", Color.ORANGE)
	roster_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(roster_header)

	if roster.size() == 0:
		var empty_label = Label.new()
		empty_label.text = "No adventurers hired yet."
		empty_label.add_theme_color_override("font_color", Color.GRAY)
		empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		content.add_child(empty_label)
	else:
		for adventurer in roster:
			_create_adventurer_card(adventurer, content)

	var sep = HSeparator.new()
	content.add_child(sep)

	# --- Section 2: AVAILABLE TODAY ---
	var recruits = GameManager.get_available_recruits()
	var applicants_header = Label.new()
	applicants_header.text = "📋 AVAILABLE TODAY (" + str(recruits.size()) + " applicants)"
	applicants_header.add_theme_font_size_override("font_size", 16)
	applicants_header.add_theme_color_override("font_color", Color.CYAN)
	applicants_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(applicants_header)

	if recruits.size() == 0:
		var no_recruits = Label.new()
		no_recruits.text = "No applicants available today."
		no_recruits.add_theme_color_override("font_color", Color.GRAY)
		no_recruits.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		content.add_child(no_recruits)
	else:
		for recruit in recruits:
			create_recruit_card(recruit, content)

func _get_adventurer_level(adventurer: Dictionary) -> int:
	var mc = adventurer.get("missions_completed", 0)
	if mc < 3: return 1
	elif mc < 8: return 2
	elif mc < 15: return 3
	elif mc < 25: return 4
	elif mc < 40: return 5
	else: return 6

func _create_adventurer_card(adventurer: Dictionary, parent: VBoxContainer):
	var card = PanelContainer.new()
	parent.add_child(card)

	var card_style = StyleBoxFlat.new()
	card_style.bg_color = Color(0.12, 0.15, 0.2, 0.9)
	card_style.border_width_left = 2
	card_style.border_width_right = 2
	card_style.border_width_top = 2
	card_style.border_width_bottom = 2
	card_style.border_color = Color(0.5, 0.6, 0.9, 1.0)
	card.add_theme_stylebox_override("panel", card_style)

	var card_content = HBoxContainer.new()
	card.add_child(card_content)
	card_content.add_theme_constant_override("separation", 20)

	# Left: info
	var info = VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card_content.add_child(info)

	var level = _get_adventurer_level(adventurer)
	var name_label = Label.new()
	name_label.text = adventurer.get("name", "?") + " the " + adventurer.get("class", "?") + " (Lvl " + str(level) + ")"
	name_label.add_theme_font_size_override("font_size", 15)
	name_label.add_theme_color_override("font_color", Color.WHITE)
	info.add_child(name_label)

	var stats_label = Label.new()
	stats_label.text = "STR:" + str(adventurer.get("strength", 0)) + " | DEX:" + str(adventurer.get("dexterity", 0)) + " | INT:" + str(adventurer.get("intelligence", 0)) + " | END:" + str(adventurer.get("endurance", 0))
	stats_label.add_theme_font_size_override("font_size", 12)
	stats_label.add_theme_color_override("font_color", Color.LIGHT_GRAY)
	info.add_child(stats_label)

	var status = adventurer.get("status", "Ready")
	var status_label = Label.new()
	status_label.text = "Status: " + status
	status_label.add_theme_font_size_override("font_size", 12)
	var status_color: Color
	match status:
		"Ready":      status_color = Color.GREEN
		"Resting":    status_color = Color.YELLOW
		"Injured":    status_color = Color.RED
		"On Mission": status_color = Color.CYAN
		_:            status_color = Color.GRAY
	status_label.add_theme_color_override("font_color", status_color)
	info.add_child(status_label)

	# Right: dismiss button
	var dismiss_btn = Button.new()
	dismiss_btn.text = "Dismiss"
	dismiss_btn.custom_minimum_size = Vector2(100, 35)
	dismiss_btn.add_theme_color_override("font_color", Color(0.9, 0.35, 0.3))
	if status == "On Mission":
		dismiss_btn.disabled = true
		dismiss_btn.tooltip_text = "On mission"
	else:
		dismiss_btn.pressed.connect(func(): _on_dismiss_pressed(adventurer))
	card_content.add_child(dismiss_btn)

func _on_dismiss_pressed(adventurer: Dictionary):
	if GameManager.dismiss_adventurer(adventurer):
		hide()
		await get_tree().create_timer(0.1).timeout
		open_recruitment_desk()

func create_guild_status_display():
	"""Display current guild status and resources"""
	var status_container = HBoxContainer.new()
	status_container.add_theme_constant_override("separation", 30)
	main_container.add_child(status_container)
	
	var gold_status = Label.new()
	gold_status.text = "Gold: " + str(GameManager.get_gold())
	gold_status.add_theme_font_size_override("font_size", 14)
	gold_status.add_theme_color_override("font_color", Color.YELLOW)
	status_container.add_child(gold_status)
	
	var roster_status = Label.new()
	var current_size = GameManager.get_adventurer_count()
	var max_size = GameManager.get_max_adventurers()
	roster_status.text = "Roster: " + str(current_size) + "/" + str(max_size)
	roster_status.add_theme_font_size_override("font_size", 14)
	roster_status.add_theme_color_override("font_color", Color.CYAN)
	status_container.add_child(roster_status)


func create_recruit_applicant() -> Dictionary:
	"""Create a potential recruit with stats and hiring cost"""
	var recruit = create_adventurer()  # Use existing function
	
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
			"Former city guard", "Retired soldier", "Village protector",
			"Tournament fighter", "Mercenary veteran", "Blacksmith's apprentice"
		],
		"Rogue": [
			"Reformed thief", "Scout from the borderlands", "Former spy",
			"Treasure hunter", "Street informant", "Circus performer"
		],
		"Mage": [
			"Academy dropout", "Wandering scholar", "Court wizard's apprentice",
			"Self-taught spellcaster", "Library researcher", "Ancient tome collector"
		],
		"Healer": [
			"Temple acolyte", "Traveling physician", "Herbalist from the forest",
			"Military medic", "Village wise woman", "Monastery refugee"
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
	name_label.text = recruit.name + " the " + recruit.class
	name_label.add_theme_font_size_override("font_size", 16)
	name_label.add_theme_color_override("font_color", Color.WHITE)
	info_container.add_child(name_label)
	
	# Stats
	var stats_label = Label.new()
	stats_label.text = "STR:" + str(recruit.strength) + " | DEX:" + str(recruit.dexterity) + " | INT:" + str(recruit.intelligence) + " | END:" + str(recruit.endurance)
	stats_label.add_theme_font_size_override("font_size", 12)
	stats_label.add_theme_color_override("font_color", Color.LIGHT_GRAY)
	info_container.add_child(stats_label)
	
	# Personality and background
	var personality_label = Label.new()
	personality_label.text = recruit.personality + " • " + recruit.background
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
	
	# Check if we can hire - USE GAMEMANAGER
	var current_gold = GameManager.get_gold()
	var current_roster_size = GameManager.get_adventurer_count()
	var max_adventurers = GameManager.get_max_adventurers()
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
	"""Hire a recruit using GameManager"""
	if GameManager.hire_adventurer(recruit):
		# Mark as hired to prevent re-hiring
		recruit.availability = "Hired"
		
		# Close and reopen popup to refresh
		hide()
		await get_tree().create_timer(0.1).timeout
		open_recruitment_desk()
	else:
		send_log_message("Cannot hire " + recruit.name + " - insufficient funds or roster full!")

func refresh_daily_recruits():
	"""Reset recruits for a new day"""
	available_recruits.clear()
	send_log_message("New adventurers have arrived seeking employment!")

func send_log_message(message: String):
	"""Send message to GameManager logging system"""
	if GameManager.has_method("log_message"):
		GameManager.log_message(message)

# ENHANCED PORTRAIT SYSTEM (Future expansion)
func get_character_portrait_texture(character: Dictionary) -> Texture2D:
	"""Get portrait texture for character - works with or without portrait files"""
	var npc_class_name = character.get("class", "Fighter")
	var gender = character.get("gender", "male")
	
	# Try to load class-specific portrait
	var portrait_path = "res://assets/portraits/" + npc_class_name.to_lower() + ".png"
	
	if FileAccess.file_exists(portrait_path):
		return load(portrait_path)
	
	# Try generic class portrait
	portrait_path = "res://assets/portraits/" + npc_class_name.to_lower() + ".png"
	if FileAccess.file_exists(portrait_path):
		return load(portrait_path)
	
	# Generate colored portrait based on class
	return generate_placeholder_portrait(npc_class_name, gender)

func generate_placeholder_portrait(npc_class_name: String, gender: String) -> ImageTexture:
	"""Generate a colored placeholder portrait"""
	var image = Image.create(64, 64, false, Image.FORMAT_RGB8)
	
	# Class-based colors
	var color = Color.GRAY
	match npc_class_name.to_lower():
		"fighter": color = Color.RED
		"rogue": color = Color.GREEN
		"mage": color = Color.BLUE
		"healer": color = Color.YELLOW
		"barbarian": color = Color.ORANGE
		"ranger": color = Color.DARK_GREEN
	
	# Lighter color for female characters
	if gender == "female":
		color = color.lightened(0.3)
	
	image.fill(color)
	
	# Add simple border
	for x in range(64):
		for y in range(64):
			if x < 2 or x > 61 or y < 2 or y > 61:
				image.set_pixel(x, y, Color.BLACK)
	
	var texture = ImageTexture.new()
	texture.create_from_image(image)
	return texture

func create_enhanced_recruit_card_with_portrait(recruit: Dictionary, parent: VBoxContainer):
	"""Enhanced recruit card with portrait (future feature)"""
	var card = PanelContainer.new()
	parent.add_child(card)
	
	# Style the card
	var card_style = StyleBoxFlat.new()
	card_style.bg_color = Color(0.1, 0.2, 0.1, 0.9)
	card_style.border_width_left = 2
	card_style.border_width_right = 2
	card_style.border_width_top = 2
	card_style.border_width_bottom = 2
	card_style.border_color = Color(0.4, 0.8, 0.4, 1.0)
	card.add_theme_stylebox_override("panel", card_style)
	
	var card_content = HBoxContainer.new()
	card.add_child(card_content)
	card_content.add_theme_constant_override("separation", 15)
	
	# LEFT: Portrait
	var portrait_container = VBoxContainer.new()
	card_content.add_child(portrait_container)
	
	var portrait = TextureRect.new()
	portrait.custom_minimum_size = Vector2(64, 64)
	portrait.texture = get_character_portrait_texture(recruit)
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait_container.add_child(portrait)
	
	# Portrait name label
	var portrait_name = Label.new()
	portrait_name.text = recruit.name
	portrait_name.add_theme_font_size_override("font_size", 12)
	portrait_name.add_theme_color_override("font_color", Color.WHITE)
	portrait_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	portrait_container.add_child(portrait_name)
	
	# MIDDLE: Character info
	var info_container = VBoxContainer.new()
	card_content.add_child(info_container)
	info_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	# Class and description
	var class_label = Label.new()
	class_label.text = recruit.class + " • " + recruit.get("gender", "").capitalize()
	class_label.add_theme_font_size_override("font_size", 16)
	class_label.add_theme_color_override("font_color", Color.CYAN)
	info_container.add_child(class_label)
	
	# Stats
	var stats_label = Label.new()
	stats_label.text = "STR:" + str(recruit.strength) + " | DEX:" + str(recruit.dexterity) + " | INT:" + str(recruit.intelligence) + " | END:" + str(recruit.endurance)
	stats_label.add_theme_font_size_override("font_size", 12)
	stats_label.add_theme_color_override("font_color", Color.LIGHT_GRAY)
	info_container.add_child(stats_label)
	
	# Personality and background
	var personality_label = Label.new()
	personality_label.text = recruit.get("personality", "Balanced") + " • " + recruit.get("motivation", "Adventure")
	personality_label.add_theme_font_size_override("font_size", 11)
	personality_label.add_theme_color_override("font_color", Color.YELLOW)
	info_container.add_child(personality_label)
	
	var background_label = Label.new()
	background_label.text = recruit.get("background", "Unknown origin")
	background_label.add_theme_font_size_override("font_size", 10)
	background_label.add_theme_color_override("font_color", Color.GRAY)
	info_container.add_child(background_label)
	
	# RIGHT: Hiring section
	var hiring_container = VBoxContainer.new()
	card_content.add_child(hiring_container)
	hiring_container.custom_minimum_size = Vector2(120, 0)
	hiring_container.add_theme_constant_override("separation", 5)
	
	# Cost label
	var cost_label = Label.new()
	cost_label.text = str(recruit.hiring_cost) + " gold"
	cost_label.add_theme_font_size_override("font_size", 14)
	cost_label.add_theme_color_override("font_color", Color.YELLOW)
	cost_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hiring_container.add_child(cost_label)
	
	# Source indicator
	var source_label = Label.new()
	var source_text = "Daily Applicant" if recruit.get("source") == "daily_applicant" else "Patron Convert"
	source_label.text = source_text
	source_label.add_theme_font_size_override("font_size", 9)
	source_label.add_theme_color_override("font_color", Color.GRAY)
	source_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hiring_container.add_child(source_label)
	
	# Hire button
	var hire_button = Button.new()
	hire_button.custom_minimum_size = Vector2(100, 35)
	hiring_container.add_child(hire_button)
	
	# Check if we can hire
	var current_gold = GameManager.get_gold()
	var current_roster_size = GameManager.get_adventurer_count()
	var max_adventurers = GameManager.get_max_adventurers()
	var can_hire = current_gold >= recruit.hiring_cost and current_roster_size < max_adventurers
	
	if can_hire:
		hire_button.text = "Hire"
		hire_button.pressed.connect(func(): hire_enhanced_recruit(recruit))
	else:
		if current_gold < recruit.hiring_cost:
			hire_button.text = "Too Expensive"
		else:
			hire_button.text = "Roster Full"
		hire_button.disabled = true

func hire_enhanced_recruit(recruit: Dictionary):
	"""Hire recruit using enhanced system"""
	if GameManager.hire_adventurer(recruit):
		# Remove from DataManager pools
		if DataManager.has_method("remove_recruited_character"):
			DataManager.remove_recruited_character(recruit.get("id", ""))
		
		send_log_message("Successfully hired " + recruit.name + " the " + recruit.class + "!")
		
		# Refresh popup
		hide()
		await get_tree().create_timer(0.1).timeout
		open_recruitment_desk()
	else:
		send_log_message("Cannot hire " + recruit.name + " - insufficient funds or roster full!")
