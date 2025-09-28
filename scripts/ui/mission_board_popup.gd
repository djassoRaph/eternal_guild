extends PopupPanel

@onready var main_container = $MainContainer

# Remove hardcoded missions - now loaded from GameManager
var assigned_missions = []

func _ready():
	print("Mission Board Popup ready - using dynamic mission system")
 
func open_mission_board():
	populate_popup_content()
	popup_centered()

func populate_popup_content():
	# Clear existing content
	for child in main_container.get_children():
		child.queue_free()
	
	await get_tree().process_frame
	
	# Create the mission board interface
	create_mission_board_ui()

func create_mission_board_ui():
	# Check if player has adventurers first
	var total_adventurers = GameManager.get_adventurer_count()
	
	if total_adventurers == 0:
		send_log_message("❌ No adventurers in your guild!")
		send_log_message("💡 Visit the recruitment desk to hire adventurers first.")
		hide()
		return
	
	# Simple title for the popup
	var title = Label.new()
	title.text = "📋 Guild Mission Board - Day " + str(GameManager.get_day())
	title.add_theme_font_size_override("font_size", 18)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	main_container.add_child(title)
	
	# Get available missions from GameManager
	var available_missions = GameManager.available_missions
	
	if available_missions.size() == 0:
		var no_missions_label = Label.new()
		no_missions_label.text = "🔄 No missions available today. Check back tomorrow!"
		no_missions_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		no_missions_label.add_theme_font_size_override("font_size", 14)
		main_container.add_child(no_missions_label)
		return
	
	# Mission statistics display
	create_mission_statistics(available_missions)
	
	# Missions container
	var missions_scroll = ScrollContainer.new()
	missions_scroll.custom_minimum_size = Vector2(700, 500)
	main_container.add_child(missions_scroll)
	
	var missions_container = VBoxContainer.new()
	missions_scroll.add_child(missions_container)
	missions_container.add_theme_constant_override("separation", 15)
	
	# Group missions by category for better organization
	var missions_by_category = group_missions_by_category(available_missions)
	
	# Create mission cards by category
	for category in missions_by_category.keys():
		create_category_section(category, missions_by_category[category], missions_container)

func create_mission_statistics(missions: Array):
	"""Display helpful statistics about available missions"""
	var stats_container = HBoxContainer.new()
	main_container.add_child(stats_container)
	
	var total_missions = missions.size()
	var solo_missions = missions.filter(func(m): return not m.party_required).size()
	var party_missions = total_missions - solo_missions
	
	var stats_label = Label.new()
	stats_label.text = "📊 Available: " + str(total_missions) + " missions (🚶 " + str(solo_missions) + " solo, 👥 " + str(party_missions) + " party)"
	stats_label.add_theme_font_size_override("font_size", 12)
	stats_label.add_theme_color_override("font_color", Color.LIGHT_GRAY)
	stats_container.add_child(stats_label)
	
	# Show adventurer readiness
	var ready_adventurers = GameManager.get_ready_adventurers().size()
	var readiness_label = Label.new()
	readiness_label.text = " | 🗡️ Ready: " + str(ready_adventurers) + " adventurers"
	readiness_label.add_theme_font_size_override("font_size", 12)
	if ready_adventurers >= 2:
		readiness_label.add_theme_color_override("font_color", Color.GREEN)
	elif ready_adventurers == 1:
		readiness_label.add_theme_color_override("font_color", Color.YELLOW)
	else:
		readiness_label.add_theme_color_override("font_color", Color.RED)
	stats_container.add_child(readiness_label)

func group_missions_by_category(missions: Array) -> Dictionary:
	"""Group missions by category for organized display"""
	var grouped = {}
	
	for mission in missions:
		if not is_mission_assigned(mission):
			var category = mission.get("category", "misc")
			if not grouped.has(category):
				grouped[category] = []
			grouped[category].append(mission)
	
	return grouped

func create_category_section(category: String, missions: Array, parent: VBoxContainer):
	"""Create a section for each mission category"""
	if missions.size() == 0:
		return
	
	# Category header
	var category_header = Label.new()
	var category_info = get_category_info(category)
	category_header.text = category_info.icon + " " + category_info.name + " (" + str(missions.size()) + ")"
	category_header.add_theme_font_size_override("font_size", 16)
	category_header.add_theme_color_override("font_color", get_category_color(category))
	parent.add_child(category_header)
	
	# Category description
	var category_desc = Label.new()
	category_desc.text = "   " + category_info.description
	category_desc.add_theme_font_size_override("font_size", 11)
	category_desc.add_theme_color_override("font_color", Color.LIGHT_GRAY)
	parent.add_child(category_desc)
	
	# Mission cards for this category
	for mission in missions:
		create_mission_card(mission, parent)

func get_category_info(category: String) -> Dictionary:
	"""Get category display information"""
	var category_data = {
		"combat": {"name": "Combat Operations", "icon": "⚔️", "description": "Dangerous missions requiring fighting prowess"},
		"escort": {"name": "Escort & Protection", "icon": "🛡️", "description": "Guard duty and safe passage missions"},
		"gathering": {"name": "Resource Gathering", "icon": "🌿", "description": "Collection and harvesting missions"},
		"investigation": {"name": "Investigation & Scouting", "icon": "🔍", "description": "Information gathering and reconnaissance"},
		"delivery": {"name": "Delivery & Transport", "icon": "📦", "description": "Moving goods and messages safely"},
		"construction": {"name": "Construction & Repair", "icon": "🔨", "description": "Building and maintenance work"}
	}
	
	return category_data.get(category, {"name": "Miscellaneous", "icon": "📋", "description": "Various guild tasks"})

func get_category_color(category: String) -> Color:
	"""Get color coding for mission categories"""
	var colors = {
		"combat": Color.RED,
		"escort": Color.BLUE,
		"gathering": Color.GREEN,
		"investigation": Color.PURPLE,
		"delivery": Color.YELLOW,
		"construction": Color.ORANGE
	}
	return colors.get(category, Color.WHITE)

func is_mission_assigned(mission: Dictionary) -> bool:
	"""Check if this mission is currently assigned"""
	for assigned in assigned_missions:
		if assigned.name == mission.name:
			return true
	return false

func create_mission_card(mission: Dictionary, parent: VBoxContainer):
	"""Create a card showing mission details and assignment options"""
	var card = PanelContainer.new()
	parent.add_child(card)

	# Enhanced styling with category-aware colors
	var card_style = StyleBoxFlat.new()
	var danger_color = get_danger_color(mission.danger)
	var category_color = get_category_color(mission.get("category", "misc"))
	
	# Blend danger and category colors
	card_style.bg_color = Color(
		(danger_color.r + category_color.r * 0.3) * 0.4,
		(danger_color.g + category_color.g * 0.3) * 0.4,
		(danger_color.b + category_color.b * 0.3) * 0.4,
		0.9
	)
	card_style.border_width_left = 3
	card_style.border_width_right = 3
	card_style.border_width_top = 3
	card_style.border_width_bottom = 3
	card_style.border_color = danger_color
	card.add_theme_stylebox_override("panel", card_style)
	
	var card_content = VBoxContainer.new()
	card.add_child(card_content)
	card_content.add_theme_constant_override("separation", 8)
	
	# Mission header with enhanced info
	var header_container = HBoxContainer.new()
	card_content.add_child(header_container)
	
	var mission_name = Label.new()
	var category_info = get_category_info(mission.get("category", "misc"))
	mission_name.text = category_info.icon + " " + mission.name
	mission_name.add_theme_font_size_override("font_size", 16)
	mission_name.add_theme_color_override("font_color", Color.WHITE)
	mission_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_container.add_child(mission_name)
	
	var danger_label = Label.new()
	danger_label.text = get_danger_description(mission.danger) + " (" + str(mission.danger) + "/5)"
	danger_label.add_theme_font_size_override("font_size", 14)
	danger_label.add_theme_color_override("font_color", danger_color)
	header_container.add_child(danger_label)
	
	# Duration info
	var duration = mission.get("duration_days", 1)
	var duration_label = Label.new()
	duration_label.text = "⏰ " + str(duration) + " day" + ("s" if duration > 1 else "")
	duration_label.add_theme_font_size_override("font_size", 12)
	duration_label.add_theme_color_override("font_color", Color.CYAN)
	header_container.add_child(duration_label)
	
	# Mission details container
	var details_container = HBoxContainer.new()
	card_content.add_child(details_container)
	details_container.add_theme_constant_override("separation", 20)
	
	# Left side: Mission info
	var info_container = VBoxContainer.new()
	details_container.add_child(info_container)
	info_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	# Enhanced description
	var description = Label.new()
	description.text = mission.get("description", "Mission details unavailable.")
	description.add_theme_font_size_override("font_size", 12)
	description.add_theme_color_override("font_color", Color.LIGHT_GRAY)
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info_container.add_child(description)
	
	# Requirements with enhanced info
	var requirements = Label.new()
	if mission.party_required:
		requirements.text = "👥 Party Required (2+ adventurers)"
		requirements.add_theme_color_override("font_color", Color.ORANGE)
	else:
		requirements.text = "🚶 Solo Mission (1 adventurer)"
		requirements.add_theme_color_override("font_color", Color.GREEN)
	requirements.add_theme_font_size_override("font_size", 11)
	info_container.add_child(requirements)
	
	# Enhanced reward info
	var reward_info = Label.new()
	var min_reward = mission.reward_range[0]
	var max_reward = mission.reward_range[1]
	reward_info.text = "💰 Reward: " + str(min_reward) + "-" + str(max_reward) + " gold"
	reward_info.add_theme_font_size_override("font_size", 12)
	reward_info.add_theme_color_override("font_color", Color.YELLOW)
	info_container.add_child(reward_info)
	
	# Right side: Assignment section (existing logic)
	create_assignment_section(mission, details_container)

func create_assignment_section(mission: Dictionary, parent: HBoxContainer):
	"""Create the assignment buttons and adventurer selection"""
	var assignment_container = VBoxContainer.new()
	parent.add_child(assignment_container)
	assignment_container.custom_minimum_size = Vector2(200, 0)
	assignment_container.add_theme_constant_override("separation", 5)
	
	# Check available adventurers
	var ready_adventurers = GameManager.get_ready_adventurers()
	var can_assign = false
	var assign_text = ""
	
	if mission.party_required:
		if ready_adventurers.size() >= 2:
			can_assign = true
			assign_text = "Assign Party"
		else:
			assign_text = "Need More Adventurers"
	else:
		if ready_adventurers.size() >= 1:
			can_assign = true
			assign_text = "Assign Solo"
		else:
			assign_text = "No Available Adventurers"
	
	var assign_button = Button.new()
	assign_button.text = assign_text
	assign_button.disabled = not can_assign
	assign_button.custom_minimum_size = Vector2(180, 35)
	
	if can_assign:
		if mission.party_required:
			assign_button.pressed.connect(func(): show_party_selection(mission))
		else:
			assign_button.pressed.connect(func(): show_solo_selection(mission))
	
	assignment_container.add_child(assign_button)
	
	# Show adventurer requirements hint
	if not can_assign:
		var hint_label = Label.new()
		if mission.party_required and ready_adventurers.size() < 2:
			hint_label.text = "Need " + str(2 - ready_adventurers.size()) + " more adventurers"
		elif ready_adventurers.size() == 0:
			hint_label.text = "Recruit adventurers first"
		hint_label.add_theme_font_size_override("font_size", 10)
		hint_label.add_theme_color_override("font_color", Color.RED)
		assignment_container.add_child(hint_label)

# Keep existing assignment logic functions...
func show_solo_selection(mission: Dictionary):
	"""Handle solo mission assignment"""
	var ready_adventurers = GameManager.get_ready_adventurers()
	if ready_adventurers.size() > 0:
		var adventurer = ready_adventurers[0]  # Take first available
		execute_solo_mission(adventurer, mission)
	else:
		send_log_message("❌ No adventurers available for assignment!")

func show_party_selection(mission: Dictionary):
	"""Handle party mission assignment"""
	var ready_adventurers = GameManager.get_ready_adventurers()
	if ready_adventurers.size() >= 2:
		# Take all available adventurers for party mission
		execute_party_mission(ready_adventurers, mission)
	else:
		send_log_message("❌ Not enough adventurers available for party mission!")

func execute_solo_mission(adventurer: Dictionary, mission: Dictionary):
	"""Execute a solo mission"""
	# Mark mission as assigned
	assigned_missions.append(mission)
	
	# Calculate success chance based on adventurer stats and mission requirements
	var success_chance = calculate_solo_success_chance(adventurer, mission)
	var roll = randi() % 100 + 1
	
	send_log_message("🗡️ " + adventurer.name + " departs on: " + mission.name)
	send_log_message("🎲 Success chance: " + str(success_chance) + "% (Rolled: " + str(roll) + ")")
	
	# Use GameManager's mission completion system
	GameManager.complete_mission(adventurer, mission, roll <= success_chance)
	
	# Close the popup after assignment
	hide()

func execute_party_mission(party: Array, mission: Dictionary):
	"""Execute a party mission"""
	# Mark mission as assigned
	assigned_missions.append(mission)
	
	# Calculate party success chance
	var success_chance = calculate_party_success_chance(party, mission)
	var roll = randi() % 100 + 1
	
	var party_names = ""
	for i in range(party.size()):
		if i > 0:
			party_names += ", "
			party_names += party[i].name
	send_log_message("⚔️ Party (" + party_names + ") departs on: " + mission.name)
	send_log_message("🎲 Party success chance: " + str(success_chance) + "% (Rolled: " + str(roll) + ")")
	
	# Count healers for injury reduction
	var healer_count = party.filter(func(adv): return adv.class == "Healer").size()
	
	# Use GameManager's party mission completion system
	GameManager.complete_party_mission(party, mission, roll <= success_chance)
	
	# Close the popup after assignment
	hide()

func calculate_solo_success_chance(adventurer: Dictionary, mission: Dictionary) -> int:
	"""Calculate success chance for solo missions based on adventurer stats and mission requirements"""
	var base_chance = 50
	
	# Stat bonuses based on mission success factors
	var success_factors = mission.get("success_factors", ["strength"])
	var stat_bonus = 0
	
	for factor in success_factors:
		match factor:
			"strength":
				stat_bonus += adventurer.strength * 3
			"dexterity":
				stat_bonus += adventurer.dexterity * 3
			"intelligence":
				stat_bonus += adventurer.intelligence * 3
			"endurance":
				stat_bonus += adventurer.endurance * 2
			"charisma":
				if adventurer.has("charisma"):
					stat_bonus += adventurer.charisma * 2
				else:
					stat_bonus += 5  # Default bonus
	
	# Experience bonus
	var experience_bonus = adventurer.missions_completed * 2
	
	# Danger penalty
	var danger_penalty = mission.danger * 8
	
	var final_chance = base_chance + stat_bonus + experience_bonus - danger_penalty
	
	# Clamp between 10% and 95%
	return clampi(final_chance, 10, 95)

func calculate_party_success_chance(party: Array, mission: Dictionary) -> int:
	"""Calculate success chance for party missions"""
	var base_chance = 60  # Party missions have higher base chance
	
	# Average party stats
	var total_strength = 0
	var total_dexterity = 0
	var total_intelligence = 0
	var total_endurance = 0
	var total_experience = 0
	
	for adventurer in party:
		total_strength += adventurer.strength
		total_dexterity += adventurer.dexterity
		total_intelligence += adventurer.intelligence
		total_endurance += adventurer.endurance
		total_experience += adventurer.missions_completed
	
	# Party synergy bonus
	var synergy_bonus = party.size() * 5  # Teamwork bonus
	
	# Stat bonuses
	var success_factors = mission.get("success_factors", ["strength", "teamwork"])
	var stat_bonus = 0
	
	for factor in success_factors:
		match factor:
			"strength":
				stat_bonus += (total_strength * 2)
			"dexterity":
				stat_bonus += (total_dexterity * 2)
			"intelligence":
				stat_bonus += (total_intelligence * 2)
			"endurance":
				stat_bonus += (total_endurance * 1)
			"teamwork":
				stat_bonus += synergy_bonus
	
	# Experience bonus
	var experience_bonus = total_experience * 1
	
	# Danger penalty (reduced for parties)
	var danger_penalty = mission.danger * 6
	
	var final_chance = base_chance + stat_bonus + experience_bonus - danger_penalty
	
	# Clamp between 15% and 95%
	return clampi(final_chance, 15, 95)

# Existing utility functions
func get_danger_color(danger: int) -> Color:
	"""Get color based on danger level"""
	match danger:
		1:
			return Color.GREEN
		2:
			return Color.YELLOW
		3:
			return Color.ORANGE
		4:
			return Color.RED
		5:
			return Color.PURPLE
		_:
			return Color.WHITE

func get_danger_description(danger: int) -> String:
	"""Get descriptive text for danger level"""
	match danger:
		1:
			return "Safe"
		2:
			return "Low Risk"
		3:
			return "Moderate"
		4:
			return "Dangerous"
		5:
			return "Extreme"
		_:
			return "Unknown"

func send_log_message(message: String):
	"""Send message to main game log"""
	GameManager.log_message(message)
	print("LOG: " + message)

func refresh_daily_missions():
	"""Reset missions for a new day - called by GameManager"""
	assigned_missions.clear()
	send_log_message("📋 New guild contracts have been posted!")
