# single_mission_card.gd
extends PanelContainer

# Node references
@onready var mission_name_label = $MarginContainer/VBoxContainer/HBoxContainer/MissionNameLabel
@onready var danger_label = $MarginContainer/VBoxContainer/HBoxContainer/DangerLabel
@onready var description_label = $MarginContainer/VBoxContainer/DescriptionLabel

@onready var reward_label = $MarginContainer/VBoxContainer/RewardLabel
@onready var adventurer_dropdown = $MarginContainer/VBoxContainer/AdventurerDropdown
@onready var send_button = $MarginContainer/VBoxContainer/SendButton

# Data
var mission_data: Dictionary = {}
var available_adventurers: Array = []
var selected_adventurer: Dictionary = {}

# Signal to tell MissionBoard "player clicked send"
signal mission_started(mission: Dictionary, adventurer: Dictionary)

func _ready():
	print("ready")
	# Wire up signals
	adventurer_dropdown.item_selected.connect(_on_adventurer_selected)
	send_button.pressed.connect(_on_send_button_pressed)
	if not mission_data.is_empty():
		populate_card()

func populate_card():
	mission_name_label.text = mission_data.get("name", "Unknown Mission")
# Called by MissionBoard to populate the card
func setup(test_mission: Dictionary, adventurers: Array):
	print("inside setup", test_mission)
	
	mission_data = test_mission
	available_adventurers = adventurers
	
	# Check if nodes are ready
	if not is_node_ready():
		await ready  # Wait for _ready() to finish
	
	# Populate mission info
	mission_name_label.text = test_mission.get("name", "Unknown Mission")
	description_label.text = test_mission.get("description", "No description available.")
	
	var min_reward = test_mission.get("reward_range", [0, 0])[0]
	var max_reward = test_mission.get("reward_range", [0, 0])[1]
	reward_label.text = "💰 Reward: " + str(min_reward) + "-" + str(max_reward) + " gold"
	
	var danger = test_mission.get("danger", 1)
	danger_label.text = get_danger_text(danger)
	danger_label.add_theme_color_override("font_color", get_danger_color(danger))
	
	# Populate dropdown
	populate_adventurer_dropdown()

func populate_adventurer_dropdown():
	adventurer_dropdown.clear()
	
	if available_adventurers.size() == 0:
		adventurer_dropdown.add_item("⚠️ No adventurers available")
		adventurer_dropdown.disabled = true
		send_button.disabled = true
		return
	
	# Add placeholder
	adventurer_dropdown.add_item("-- Select Adventurer --")
	adventurer_dropdown.set_item_disabled(0, true)  # Can't select placeholder
	
	# Add adventurers
	for i in available_adventurers.size():
		var adv = available_adventurers[i]
		var display_text = adv.get("name", "Unknown") + " (" + adv.get("class", "?") + ")"
		adventurer_dropdown.add_item(display_text)
	
	# Start with placeholder selected
	adventurer_dropdown.selected = 0
	send_button.disabled = true

func _on_adventurer_selected(index: int):
	if index == 0:  # Placeholder selected
		selected_adventurer = {}
		send_button.disabled = true
		return
	
	# Adjust for placeholder (index 0)
	var adventurer_index = index - 1
	
	if adventurer_index >= 0 and adventurer_index < available_adventurers.size():
		selected_adventurer = available_adventurers[adventurer_index]
		send_button.disabled = false
		
		# Show success chance preview
		var chance = calculate_success_chance()
		send_button.text = "🗡️ Send on Mission (" + str(chance) + "% success)"

func _on_send_button_pressed():
	if selected_adventurer.is_empty():
		return
	
	# Emit signal - let MissionBoard handle GameManager interaction
	mission_started.emit(mission_data, selected_adventurer)

func calculate_success_chance() -> int:
	"""Calculate mission success chance"""
	var base_chance = 50
	var adv = selected_adventurer
	
	var stat_bonus = 0
	var success_factors = mission_data.get("success_factors", ["strength"])
	
	for factor in success_factors:
		match factor:
			"strength": stat_bonus += adv.get("strength", 0) * 3
			"dexterity": stat_bonus += adv.get("dexterity", 0) * 3
			"intelligence": stat_bonus += adv.get("intelligence", 0) * 3
			"endurance": stat_bonus += adv.get("endurance", 0) * 2
	
	var experience_bonus = adv.get("missions_completed", 0) * 2
	var danger_penalty = mission_data.get("danger", 1) * 8
	
	var final_chance = base_chance + stat_bonus + experience_bonus - danger_penalty
	return clampi(final_chance, 10, 95)

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
