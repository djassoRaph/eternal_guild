extends PopupPanel

@onready var main_container = $MainContainer

# Mission data from your prototype
var missions = [
	{"name": "Clear Slimes", "danger": 1, "reward_range": [5, 10], "party_required": false},
	{"name": "Escort Merchant", "danger": 5, "reward_range": [40, 60], "party_required": true},
	{"name": "Scavenge Herbs in Forest", "danger": 3, "reward_range": [10, 20], "party_required": true},
	{"name": "Defend the Grain Warehouse", "danger": 2, "reward_range": [15, 25], "party_required": true}
]

func _ready():
	print("Mission Board Popup ready")

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
	var main_script = get_tree().current_scene
	var total_adventurers = 0
	if main_script and main_script.has_method("get_adventurer_count"):
		total_adventurers = main_script.get_adventurer_count()
	
	if total_adventurers == 0:
		send_log_message("❌ No adventurers in your guild!")
		send_log_message("💡 Visit the recruitment desk to hire adventurers first.")
		hide()  # Close the popup since there's nothing to show
		return
	
	# Simple title for the popup
	var title = Label.new()
	title.text = "📋 Guild Mission Board"
	title.add_theme_font_size_override("font_size", 18)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	main_container.add_child(title)
	
	# Missions container
	var missions_scroll = ScrollContainer.new()
	missions_scroll.custom_minimum_size = Vector2(650, 450)
	main_container.add_child(missions_scroll)
	
	var missions_container = VBoxContainer.new()
	missions_scroll.add_child(missions_container)
	missions_container.add_theme_constant_override("separation", 15)
	
	# Create mission cards
	for mission in missions:
		create_mission_card(mission, missions_container)

func create_mission_card(mission: Dictionary, parent: VBoxContainer):
	"""Create a card showing mission details and assignment options"""
	var card = PanelContainer.new()
	parent.add_child(card)
	
	# Style the card based on danger level
	var card_style = StyleBoxFlat.new()
	var danger_color = get_danger_color(mission.danger)
	card_style.bg_color = Color(danger_color.r * 0.3, danger_color.g * 0.3, danger_color.b * 0.3, 0.9)
	card_style.border_width_left = 3
	card_style.border_width_right = 3
	card_style.border_width_top = 3
	card_style.border_width_bottom = 3
	card_style.border_color = danger_color
	card.add_theme_stylebox_override("panel", card_style)
	
	var card_content = VBoxContainer.new()
	card.add_child(card_content)
	card_content.add_theme_constant_override("separation", 10)
	
	# Mission header (name and danger)
	var header_container = HBoxContainer.new()
	card_content.add_child(header_container)
	
	var mission_name = Label.new()
	mission_name.text = "⚔️ " + mission.name
	mission_name.add_theme_font_size_override("font_size", 16)
	mission_name.add_theme_color_override("font_color", Color.WHITE)
	mission_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_container.add_child(mission_name)
	
	var danger_label = Label.new()
	danger_label.text = get_danger_description(mission.danger) + " (" + str(mission.danger) + "/5)"
	danger_label.add_theme_font_size_override("font_size", 14)
	danger_label.add_theme_color_override("font_color", danger_color)
	header_container.add_child(danger_label)
	
	# Mission details container
	var details_container = HBoxContainer.new()
	card_content.add_child(details_container)
	details_container.add_theme_constant_override("separation", 20)
	
	# Left side: Mission info
	var info_container = VBoxContainer.new()
	details_container.add_child(info_container)
	info_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	# Description
	var description = Label.new()
	description.text = get_mission_description(mission.name)
	description.add_theme_font_size_override("font_size", 12)
	description.add_theme_color_override("font_color", Color.LIGHT_GRAY)
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info_container.add_child(description)
	
	# Requirements
	var requirements = Label.new()
	if mission.party_required:
		requirements.text = "👥 Party Required (2+ adventurers)"
		requirements.add_theme_color_override("font_color", Color.ORANGE)
	else:
		requirements.text = "🚶 Solo Mission (1 adventurer)"
		requirements.add_theme_color_override("font_color", Color.GREEN)
	requirements.add_theme_font_size_override("font_size", 11)
	info_container.add_child(requirements)
	
	# Reward info
	var reward_info = Label.new()
	reward_info.text = "💰 Reward: " + str(mission.reward_range[0]) + "-" + str(mission.reward_range[1]) + " gold"
	reward_info.add_theme_font_size_override("font_size", 12)
	reward_info.add_theme_color_override("font_color", Color.YELLOW)
	info_container.add_child(reward_info)
	
	# Right side: Assignment section
	var assignment_container = VBoxContainer.new()
	details_container.add_child(assignment_container)
	assignment_container.custom_minimum_size = Vector2(200, 0)
	assignment_container.add_theme_constant_override("separation", 5)
	
	# Check available adventurers
	var ready_adventurers = get_ready_adventurers()
	var can_assign = false
	var assign_text = ""
	
	if mission.party_required:
		if ready_adventurers.size() >= 2:  # Need at least 2 for party
			can_assign = true
			assign_text = "Assign Party"
		else:
			assign_text = "Need More Adventurers"
	else:
		if ready_adventurers.size() >= 1:
			can_assign = true
			assign_text = "Assign Adventurer"
		else:
			assign_text = "No Ready Adventurers"
	
	# Available adventurers info
	var adventurer_info = Label.new()
	adventurer_info.text = "Available: " + str(ready_adventurers.size()) + " adventurers"
	adventurer_info.add_theme_font_size_override("font_size", 10)
	adventurer_info.add_theme_color_override("font_color", Color.CYAN)
	adventurer_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	assignment_container.add_child(adventurer_info)
	
	# Assign button
	var assign_button = Button.new()
	assign_button.text = assign_text
	assign_button.disabled = not can_assign
	assign_button.custom_minimum_size = Vector2(180, 40)
	assignment_container.add_child(assign_button)
	
	# Connect button to assignment function
	if can_assign:
		assign_button.pressed.connect(func(): assign_mission(mission, ready_adventurers))

func get_danger_color(danger_level: int) -> Color:
	"""Get color based on danger level"""
	match danger_level:
		1: return Color.GREEN
		2: return Color.YELLOW
		3: return Color.ORANGE
		4: return Color.RED
		5: return Color.PURPLE
		_: return Color.WHITE

func get_danger_description(danger_level: int) -> String:
	"""Convert danger number to descriptive text"""
	match danger_level:
		1: return "Very Easy"
		2: return "Easy"
		3: return "Moderate"
		4: return "Hard"
		5: return "Very Hard"
		_: return "Unknown"

func get_mission_description(mission_name: String) -> String:
	"""Get flavor text for missions"""
	match mission_name:
		"Clear Slimes": return "Simple pest control in the nearby sewers. Perfect for beginners to earn their first gold."
		"Escort Merchant": return "Protect a merchant caravan traveling dangerous roads. Bandits have been spotted recently."
		"Scavenge Herbs in Forest": return "Gather rare medicinal herbs from the enchanted forest. Watch out for territorial creatures."
		"Defend the Grain Warehouse": return "Guard the town's grain warehouse from bandit raids overnight. Critical for winter supplies."
		_: return "A standard guild contract requiring skilled adventurers."

func assign_mission(mission: Dictionary, ready_adventurers: Array):
	"""Assign adventurers to a mission"""
	hide()  # Close the mission board
	
	if mission.party_required:
		# For party missions, take 2-3 ready adventurers
		var party_size = min(3, ready_adventurers.size())
		var assigned_party = []
		
		for i in range(party_size):
			assigned_party.append(ready_adventurers[i])
		
		send_log_message("⚔️ Assigning party to: " + mission.name)
		for adv in assigned_party:
			send_log_message("👥 " + adv.name + " (" + adv.class + ") joins the party")
		
		# Send party on mission
		send_party_on_mission(assigned_party, mission)
	else:
		# For solo missions, take the first ready adventurer
		var adventurer = ready_adventurers[0]
		send_log_message("⚔️ " + adventurer.name + " is embarking on: " + mission.name)
		send_solo_on_mission(adventurer, mission)

func send_solo_on_mission(adventurer: Dictionary, mission: Dictionary):
	"""Send a single adventurer on a mission"""
	var adventurer_score = 0
	
	# Calculate adventurer's effectiveness for this mission
	match adventurer.class:
		"Fighter":
			adventurer_score = adventurer.strength + adventurer.endurance
		"Rogue":
			adventurer_score = adventurer.dexterity + adventurer.endurance
		"Mage":
			adventurer_score = adventurer.intelligence * 1.5
		"Healer":
			adventurer_score = adventurer.intelligence
	
	var roll = randi() % 6 + 1
	adventurer_score += roll
	var difficulty = mission.danger * 10
	
	send_log_message("🎲 " + adventurer.name + " rolls: " + str(roll) + " (Total score: " + str(adventurer_score) + " vs " + str(difficulty) + ")")
	
	# Update adventurer status in main game
	var main_script = get_tree().current_scene
	if main_script and main_script.has_method("complete_mission"):
		main_script.complete_mission(adventurer, mission, adventurer_score >= difficulty)

func send_party_on_mission(party: Array, mission: Dictionary):
	"""Send a party of adventurers on a mission"""
	var party_score = 0
	var healer_count = 0
	
	# Calculate combined party score
	for adv in party:
		match adv.class:
			"Fighter":
				party_score += adv.strength + adv.endurance
			"Rogue":
				party_score += adv.dexterity + adv.endurance
			"Mage":
				party_score += adv.intelligence * 1.5
			"Healer":
				party_score += adv.intelligence
				healer_count += 1
	
	# Party bonuses
	party_score += party.size() * 2  # Teamwork bonus
	if healer_count > 0:
		party_score += healer_count * 3  # Healer reduces injury risk
	
	var roll = randi() % 6 + 1
	party_score += roll
	var difficulty = mission.danger * 10
	
	send_log_message("🎲 Party rolls: " + str(roll) + " (Total score: " + str(party_score) + " vs " + str(difficulty) + ")")
	
	# Update party in main game
	var main_script = get_tree().current_scene
	if main_script and main_script.has_method("complete_party_mission"):
		main_script.complete_party_mission(party, mission, party_score >= difficulty, healer_count)

func get_ready_adventurers() -> Array:
	"""Get list of adventurers ready for missions"""
	var main_script = get_tree().current_scene
	if main_script and main_script.has_method("get_ready_adventurers"):
		return main_script.get_ready_adventurers()
	return []

func send_log_message(message: String):
	"""Send message to main game log"""
	var main_script = get_tree().current_scene
	if main_script and main_script.has_method("log_message"):
		await get_tree().process_frame
		main_script.log_message(message)
	else:
		print("LOG: " + message)
