# party_mission_card.gd - Handle party (multi-adventurer) missions
extends PanelContainer

@onready var mission_name_label = $MarginContainer/VBoxContainer/HBoxContainer/MissionNameLabel
@onready var danger_label = $MarginContainer/VBoxContainer/HBoxContainer/DangerLabel
@onready var description_label = $MarginContainer/VBoxContainer/DescriptionLabel
@onready var required_label = $MarginContainer/VBoxContainer/RequiredLabel
@onready var reward_label = $MarginContainer/VBoxContainer/RewardLabel
@onready var selection_label = $MarginContainer/VBoxContainer/AdventurerSelectionContainer/SelectionLabel
@onready var adventurer_buttons_container = $MarginContainer/VBoxContainer/AdventurerSelectionContainer/AdventurerButtonsContainer
@onready var send_button = $MarginContainer/VBoxContainer/SendButton

var mission_data: Dictionary = {}
var available_adventurers: Array = []
var selected_adventurers: Array = []
var adventurer_buttons: Array = []

signal mission_started(mission: Dictionary, adventurers: Array)

func _ready():
	print("✅ Party mission card _ready() called")
	send_button.pressed.connect(_on_send_button_pressed)

func setup(test_mission: Dictionary, adventurers: Array):
	"""Setup party mission card with data"""
	mission_data = test_mission
	available_adventurers = adventurers
	
	if not is_node_ready():
		await ready
	
	print("🎯 Setting up party mission: ", test_mission.get("name", "Unknown"))
	
	# Populate mission info
	mission_name_label.text = test_mission.get("name", "Unknown Mission")
	description_label.text = test_mission.get("description", "No description.")
	
	var min_reward = test_mission.get("reward_range", [0, 0])[0]
	var max_reward = test_mission.get("reward_range", [0, 0])[1]
	reward_label.text = "💰 Reward: " + str(min_reward) + "-" + str(max_reward) + " gold"
	
	var danger = test_mission.get("danger", 1)
	danger_label.text = get_danger_text(danger)
	danger_label.add_theme_color_override("font_color", get_danger_color(danger))
	
	# Get required party size
	var raw = test_mission.get("party_required", 2)
	var party_size: int = 2 if raw is bool else maxi(2, int(raw))
	required_label.text = "👥 Requires: " + str(party_size) + " adventurers"
	
	# Create selection buttons for each adventurer
	populate_adventurer_buttons(party_size)
	
	print("✅ Party mission ready - need ", party_size, " adventurers")

func populate_adventurer_buttons(party_size: int):
	"""Create toggle buttons for each available adventurer"""
	print("🔘 Creating ", available_adventurers.size(), " adventurer buttons")
	
	# Clear existing buttons
	for child in adventurer_buttons_container.get_children():
		child.queue_free()
	adventurer_buttons.clear() 
	await get_tree().process_frame
	
	if available_adventurers.size() == 0:
		var no_adventurers = Label.new()
		no_adventurers.text = "⚠️ No adventurers available"
		adventurer_buttons_container.add_child(no_adventurers)
		return
	
	# Create a toggle button for each adventurer
	for i in range(available_adventurers.size()):
		var adv = available_adventurers[i]
		var btn = Button.new()
		btn.text = adv.get("name", "Unknown") + "\n(" + adv.get("class", "?") + ")"
		btn.toggle_mode = true
		btn.custom_minimum_size = Vector2(80, 60)
		btn.toggled.connect(_on_adventurer_button_toggled.bind(i, btn))

		adventurer_buttons.append(btn)
		adventurer_buttons_container.add_child(btn)
		print("   ✓ Added button for: ", adv.get("name"))
	
	print("✅ Buttons ready - select ", party_size, " to continue")

func _on_adventurer_button_toggled(is_pressed: bool, index: int, btn: Button):
	var adv = available_adventurers[index]
	var party_size = get_party_size()

	if is_pressed:
		if adv not in selected_adventurers:
			selected_adventurers.append(adv)
			btn.modulate = Color.GREEN
	else:
		selected_adventurers.erase(adv)
		btn.modulate = Color.WHITE

	# Update selection display
	selection_label.text = "👤 Selected: " + str(selected_adventurers.size()) + " / " + str(party_size)
	send_button.disabled = selected_adventurers.size() != party_size

	if selected_adventurers.size() == party_size:
		send_button.text = "🗡️ Send Party (" + str(selected_adventurers.size()) + ")"
		print("✅ Party ready! Can send mission now")
	else:
		send_button.text = "🗡️ Send Party"

func _on_send_button_pressed():
	"""Handle send button press"""
	if selected_adventurers.size() == 0:
		print("❌ No adventurers selected!")
		return
	
	print("🚀 Party mission started with ", selected_adventurers.size(), " adventurers")
	for adv in selected_adventurers:
		print("   - ", adv.get("name"))
	
	mission_started.emit(mission_data, selected_adventurers)

func calculate_party_success_chance() -> int:
	"""Calculate success chance for the entire party"""
	if selected_adventurers.size() == 0:
		return 0
	
	var base_chance = 60  # Parties have better base chance
	var total_power = 0
	var success_factors = mission_data.get("success_factors", ["strength"])
	
	# Average stats across all party members
	for adv in selected_adventurers:
		var stat_bonus = 0
		for factor in success_factors:
			match factor:
				"strength": stat_bonus += adv.get("strength", 0) * 2
				"dexterity": stat_bonus += adv.get("dexterity", 0) * 2
				"intelligence": stat_bonus += adv.get("intelligence", 0) * 2
				"endurance": stat_bonus += adv.get("endurance", 0) * 1.5
		total_power += stat_bonus
	
	# Average out
	var avg_stat_bonus = int(total_power / selected_adventurers.size())
	var experience_bonus = 0
	
	# Experience bonus is shared (higher if all have more missions)
	for adv in selected_adventurers:
		experience_bonus += adv.get("missions_completed", 0)
	experience_bonus = int(experience_bonus / selected_adventurers.size())
	
	var danger_penalty = mission_data.get("danger", 1) * 10
	var party_size_bonus = selected_adventurers.size() * 5  # Teams work better together
	
	var final_chance = base_chance + avg_stat_bonus + experience_bonus - danger_penalty + party_size_bonus
	return clampi(final_chance, 15, 95)

func get_danger_text(danger: int) -> String:
	match danger:
		1: return "⚪ Safe"
		2: return "🟡 Low Risk"
		3: return "🟠 Moderate"
		4: return "🔴 Dangerous"
		5: return "🟣 Extreme"
		_: return "❓ Unknown"

func get_danger_color(danger: int) -> Color:
	match danger:
		1: return Color.GREEN
		2: return Color.YELLOW
		3: return Color.ORANGE
		4: return Color.RED
		5: return Color.PURPLE
		_: return Color.WHITE


func get_party_size() -> int:
	var raw = mission_data.get("party_required", 2)
	return 2 if raw is bool else maxi(2, int(raw))
