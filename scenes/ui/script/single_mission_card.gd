# single_mission_card.gd - FIXED VERSION (No placeholder handling)
extends PanelContainer

@onready var mission_name_label = $MarginContainer/VBoxContainer/HBoxContainer/MissionNameLabel
@onready var danger_label = $MarginContainer/VBoxContainer/HBoxContainer/DangerLabel
@onready var description_label = $MarginContainer/VBoxContainer/DescriptionLabel
@onready var reward_label = $MarginContainer/VBoxContainer/RewardLabel
@onready var adventurer_dropdown = $MarginContainer/VBoxContainer/AdventurerDropdown
@onready var send_button = $MarginContainer/VBoxContainer/SendButton

var mission_data: Dictionary = {}
var available_adventurers: Array = []
var selected_adventurer: Dictionary = {}

signal mission_started(mission: Dictionary, adventurer: Dictionary)

func _ready():
	print("✅ Mission card _ready() called")
	print("   Dropdown node path check: ", adventurer_dropdown.get_path())
	print("   Dropdown is valid: ", is_instance_valid(adventurer_dropdown))
	
	# Ensure dropdown has focus mode enabled
	adventurer_dropdown.focus_mode = Control.FOCUS_ALL
	adventurer_dropdown.mouse_filter = Control.MOUSE_FILTER_STOP
	
	# Connect signals PROPERLY
	if not adventurer_dropdown.item_selected.is_connected(_on_adventurer_selected):
		adventurer_dropdown.item_selected.connect(_on_adventurer_selected)
		print("✅ Connected item_selected signal")
	
	if not send_button.pressed.is_connected(_on_send_button_pressed):
		send_button.pressed.connect(_on_send_button_pressed)
		print("✅ Connected send_button pressed signal")

func setup(test_mission: Dictionary, adventurers: Array):
	"""Setup mission card with data"""
	mission_data = test_mission
	available_adventurers = adventurers
	
	if not is_node_ready():
		await ready
	
	print("🎯 Setting up mission card for: ", test_mission.get("name", "Unknown"))
	
	# Populate mission info
	mission_name_label.text = test_mission.get("name", "Unknown Mission")
	description_label.text = test_mission.get("description", "No description.")
	
	var min_reward = test_mission.get("reward_range", [0, 0])[0]
	var max_reward = test_mission.get("reward_range", [0, 0])[1]
	reward_label.text = "💰 Reward: " + str(min_reward) + "-" + str(max_reward) + " gold"
	
	var danger = test_mission.get("danger", 1)
	danger_label.text = get_danger_text(danger)
	danger_label.add_theme_color_override("font_color", get_danger_color(danger))
	
	populate_adventurer_dropdown()

func populate_adventurer_dropdown():
	"""Populate dropdown with available adventurers"""
	print("🔽 Populating dropdown with ", available_adventurers.size(), " adventurers")
	
	# Clear everything
	adventurer_dropdown.clear()
	selected_adventurer = {}
	
	if available_adventurers.size() == 0:
		adventurer_dropdown.add_item("⚠️ No adventurers available")
		adventurer_dropdown.disabled = true
		send_button.disabled = true
		return
	
	# Add placeholder at index 0 (disabled so user can't select it)
	adventurer_dropdown.add_item("-- Select Adventurer --")
	adventurer_dropdown.set_item_disabled(0, true)
	
	# Add each adventurer starting at index 1
	for adv in available_adventurers:
		var text = adv.get("name", "Unknown") + " (" + adv.get("class", "?") + ")"
		adventurer_dropdown.add_item(text)
		print("   ✓ Added: ", text)
	
	# Start with placeholder selected, button disabled
	adventurer_dropdown.selected = 0
	adventurer_dropdown.disabled = false
	send_button.disabled = true
	send_button.text = "🗡️ Send on Mission"
	
	print("✅ Dropdown ready with ", adventurer_dropdown.item_count, " items")

		
func _on_adventurer_selected(index: int):
	"""Handle adventurer selection from dropdown"""
	print("🎯 Adventurer selected - Index: ", index)
	
	if index == 0:
		print("   → Placeholder selected, disabling button")
		selected_adventurer = {}
		send_button.disabled = true
		send_button.text = "🗡️ Send on Mission"
		return
		
	var adv_index = index - 1
	if adv_index >= 0 and adv_index < available_adventurers.size():
		var chance = calculate_success_chance()
		selected_adventurer = available_adventurers[adv_index]
		send_button.disabled = false
		send_button.text = "🗡️ Send (" + str(chance) + "% success)"
		print("✅ Selected: ", selected_adventurer.get("name"))
	else:
		print("❌ Invalid adventurer index: ", index)
		selected_adventurer = {}
		send_button.disabled = true
		send_button.text = "🗡️ Send on Mission"

func _on_send_button_pressed():
	"""Handle send button press"""
	if selected_adventurer.is_empty():
		print("❌ No adventurer selected!")
		return
	
	print("🚀 Mission started! ", selected_adventurer.get("name"), " -> ", mission_data.get("name"))
	mission_started.emit(mission_data, selected_adventurer)

func calculate_success_chance() -> int:
	"""Calculate success chance for selected adventurer"""
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
