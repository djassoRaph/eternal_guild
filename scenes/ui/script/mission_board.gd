extends Control

# UI References - connected to nodes you created in editor
@onready var title_label = $MainContainer/TitleLabel
@onready var stats_row = $MainContainer/StatsRow
@onready var mission_stats_label = $MainContainer/StatsRow/MissionStatsLabel
@onready var readiness_label = $MainContainer/StatsRow/ReadinessLabel
@onready var tier_row = $MainContainer/TierRow
@onready var tier1_label = $MainContainer/TierRow/Tier1Label
@onready var tier2_label = $MainContainer/TierRow/Tier2Label
@onready var tier3_label = $MainContainer/TierRow/Tier3Label
@onready var progress_label = $MainContainer/ProgressLabel
@onready var scroll_container = $MainContainer/ScrollContainer
@onready var missionboard = $"."
@onready var missions_container = $ScrollContainer/MissionsContainer
var assigned_missions = []

func _ready():
	print("Mission Board scene ready")
	GameManager.adventurer_roster_changed.connect(_refresh_mission_display)
	missionboard.visible = false

func _input(event):
	if visible and event.is_action_pressed("ui_cancel"):
		visible = false

func open_mission_board():
	# Check if player has adventurers first
	var total_adventurers = GameManager.get_adventurer_count()
	
	if total_adventurers == 0:
		send_log_message("❌ No adventurers in your guild!")
		send_log_message("💡 Visit the recruitment desk to hire adventurers first.")
		visible = false  # Hide if no adventurers
		return
	
	update_static_ui()
	populate_missions()
	visible = true  # Show the board

func update_static_ui():
	"""Update all static UI labels with current game state"""
	# Update title
	title_label.text = "📋 Guild Mission Board - Day " + str(GameManager.get_day())
	
	# Update mission statistics
	var available_missions = GameManager.available_missions
	var solo_count = available_missions.filter(func(m): return not m.party_required).size()
	var party_count = available_missions.size() - solo_count
	
	mission_stats_label.text = "📊 Available: " + str(available_missions.size()) + " missions (🚶 " + str(solo_count) + " solo, 👥 " + str(party_count) + " party)"
	
	# Update readiness
	var ready = GameManager.get_ready_adventurers().size()
	readiness_label.text = "🗡️ Ready: " + str(ready) + " adventurers"
	
	if ready >= 2:
		readiness_label.add_theme_color_override("font_color", Color.GREEN)
	elif ready == 1:
		readiness_label.add_theme_color_override("font_color", Color.YELLOW)
	else:
		readiness_label.add_theme_color_override("font_color", Color.RED)
	
	# Update tier status
	update_tier_labels()

func _on_roster_changed():
	"""Called when adventurer roster changes (missions complete, injuries, etc)"""
	if visible:
		# Refresh the entire board to show updated adventurer availability
		populate_missions()
		

func _refresh_mission_display():
	# Clear and rebuild mission cards
	if visible:
		populate_missions()


func update_tier_labels():
	"""Update tier unlock status display"""
	var current_tier = GameManager.mission_tier_unlocked
	
	# Update each tier label
	for tier in [1, 2, 3]:
		var status = GameManager.get_tier_unlock_status(tier)
		var label = get_node("MainContainer/TierRow/Tier" + str(tier) + "Label")
		
		if status.unlocked:
			if tier == current_tier:
				label.text = "✅ Tier " + str(tier) + " [CURRENT]"
				label.add_theme_color_override("font_color", Color.GREEN)
			else:
				label.text = "✅ Tier " + str(tier)
				label.add_theme_color_override("font_color", Color.DARK_GREEN)
		else:
			label.text = "🔒 Tier " + str(tier)
			label.add_theme_color_override("font_color", Color.GRAY)
			if status.missing.size() > 0:
				label.tooltip_text = "Locked: " + "\n".join(status.missing)
	
	# Show progress to next tier
	if current_tier < 3:
		var next_tier = current_tier + 1
		var next_status = GameManager.get_tier_unlock_status(next_tier)
		
		if not next_status.unlocked and next_status.missing.size() > 0:
			progress_label.text = "📈 Next Tier: " + ", ".join(next_status.missing)
			progress_label.visible = true
		else:
			progress_label.visible = false
	else:
		progress_label.text = "🎉 All tiers unlocked!"
		progress_label.add_theme_color_override("font_color", Color.GREEN)
		progress_label.visible = true

func populate_missions():
	"""Clear and repopulate mission cards"""
	print("Populating missions - available count: ", GameManager.available_missions.size())  # Add this
	#for child in missions_container.get_children():
	#	child.queue_free()
	
	for mission in GameManager.available_missions:
		print("Creating card for mission: ", mission.name)
		var mission_button = RichTextLabel.new()
		mission_button.text = "[color=" + get_category_color(mission.category).to_html(false) + "]" + get_category_info(mission.category).icon + " " + mission.name + "[/color]\n" + mission.description + "\nReward: " + str(randi_range(mission.reward_range[0], mission.reward_range[1])) + " gold\nDanger: " + get_danger_description(mission.danger)
		mission_button.connect("pressed", _on_mission_selected.bind(mission))
		missions_container.add_child(mission_button)
	
	
	
	await get_tree().process_frame
	
	var available_missions = GameManager.available_missions
	
	if available_missions.size() == 0:
		var no_missions = Label.new()
		no_missions.text = "🔄 No missions available. Check back tomorrow!"
		no_missions.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		no_missions.add_theme_font_size_override("font_size", 14)
		missions_container.add_child(no_missions)
		return
	
	# Group missions by category
	var missions_by_category = group_missions_by_category(available_missions)
	
	# Create mission cards by category
	for category in missions_by_category.keys():
		create_category_section(category, missions_by_category[category])


func _on_mission_selected(mission):
	"""Handle mission selection and assignment"""
	print("Mission selected: ", mission.name)
	var ready_adventurers = GameManager.get_ready_adventurers()
	var is_party = mission.party_required
	var required_count = 3 if is_party else 1
	
	if ready_adventurers.size() < required_count:
		send_log_message("❌ Not enough ready adventurers for this mission!")
		return
	
	var assigned = ready_adventurers.slice(0, required_count - 1)
	var success_chance = calculate_success_chance(mission, assigned)
	var outcome = GameManager.assign_mission(mission, is_party, assigned)
	
	if outcome.success:
		send_log_message("✅ Mission '" + mission.name + "' assigned! Success chance: " + str(success_chance) + "%")
		assigned_missions.append(mission)
		refresh_daily_missions()  # Clear and repopulate to reflect new state
	else:
		send_log_message("❌ Failed to assign mission: " + outcome.reason)
	
	# Optionally close the board after selection (e.g., visible = false)

func calculate_success_chance(mission, assigned_adventurers):
	"""Calculate success chance for a mission based on adventurer stats"""
	var base_chance = 50  # Baseline success probability
	var total_strength = 0
	var total_dexterity = 0
	var total_intelligence = 0
	var total_endurance = 0
	var total_experience = 0
	var synergy_bonus = 0
	
	# Aggregate stats from assigned adventurers
	for adventurer in assigned_adventurers:
		total_strength += adventurer.get_stat("strength", 0)
		total_dexterity += adventurer.get_stat("dexterity", 0)
		total_intelligence += adventurer.get_stat("intelligence", 0)
		total_endurance += adventurer.get_stat("endurance", 0)
		total_experience += adventurer.get_stat("experience", 0)
		# Add synergy if multiple adventurers (simplified)
		if assigned_adventurers.size() > 1:
			synergy_bonus += 5
	
	var success_factors = mission.success_factors if mission.success_factors else ["strength", "teamwork"]
	var stat_bonus = 0
	
	for factor in success_factors:
		match factor:
			"strength": stat_bonus += (total_strength * 2)
			"dexterity": stat_bonus += (total_dexterity * 2)
			"intelligence": stat_bonus += (total_intelligence * 2)
			"endurance": stat_bonus += (total_endurance * 1)
			"teamwork": stat_bonus += synergy_bonus
	
	var experience_bonus = total_experience * 1
	var danger_penalty = mission.danger * 6
	var final_chance = base_chance + stat_bonus + experience_bonus - danger_penalty
	
	return clampi(final_chance, 15, 95)

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

func create_category_section(category: String, missions: Array):
	"""Create a section for each mission category"""
	if missions.size() == 0:
		return
	
	# Category header
	var category_header = Label.new()
	var category_info = get_category_info(category)
	category_header.text = category_info.icon + " " + category_info.name + " (" + str(missions.size()) + ")"
	category_header.add_theme_font_size_override("font_size", 16)
	category_header.add_theme_color_override("font_color", get_category_color(category))
	missions_container.add_child(category_header)
	
	# Mission cards for this category
	for mission in missions:
		create_mission_card(mission)

func create_mission_card(mission: Dictionary):
	"""Create a mission card (keeping your existing logic)"""
	var card = PanelContainer.new()
	missions_container.add_child(card)
	
	# Enhanced styling with category-aware colors
	var card_style = StyleBoxFlat.new()
	var danger_color = get_danger_color(mission.danger)
	var category_color = get_category_color(mission.get("category", "misc"))
	
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
	
	# Mission header
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
	
	# Duration
	var duration = mission.get("duration_days", 1)
	var duration_label = Label.new()
	duration_label.text = "⏰ " + str(duration) + " day" + ("s" if duration > 1 else "")
	duration_label.add_theme_font_size_override("font_size", 12)
	duration_label.add_theme_color_override("font_color", Color.CYAN)
	header_container.add_child(duration_label)
	
	# Details container
	var details_container = HBoxContainer.new()
	card_content.add_child(details_container)
	details_container.add_theme_constant_override("separation", 20)
	
	# Mission info
	var info_container = VBoxContainer.new()
	details_container.add_child(info_container)
	info_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	var description = Label.new()
	description.text = mission.get("description", "Mission details unavailable.")
	description.add_theme_font_size_override("font_size", 12)
	description.add_theme_color_override("font_color", Color.LIGHT_GRAY)
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info_container.add_child(description)
	
	var requirements = Label.new()
	if mission.party_required:
		requirements.text = "👥 Party Required (2+ adventurers)"
		requirements.add_theme_color_override("font_color", Color.ORANGE)
	else:
		requirements.text = "🚶 Solo Mission (1 adventurer)"
		requirements.add_theme_color_override("font_color", Color.GREEN)
	requirements.add_theme_font_size_override("font_size", 11)
	info_container.add_child(requirements)
	
	var reward_info = Label.new()
	var min_reward = mission.reward_range[0]
	var max_reward = mission.reward_range[1]
	reward_info.text = "💰 Reward: " + str(min_reward) + "-" + str(max_reward) + " gold"
	reward_info.add_theme_font_size_override("font_size", 12)
	reward_info.add_theme_color_override("font_color", Color.YELLOW)
	info_container.add_child(reward_info)
	
	# Assignment buttons
	create_assignment_section(mission, details_container)

func create_assignment_section(mission: Dictionary, parent: HBoxContainer):
	"""Create assignment buttons"""
	var assignment_container = VBoxContainer.new()
	parent.add_child(assignment_container)
	assignment_container.custom_minimum_size = Vector2(200, 0)
	
	var ready_adventurers = GameManager.get_ready_adventurers()
	var can_assign = false
	var assign_text = ""
	
	if mission.party_required:
		can_assign = ready_adventurers.size() >= 2
		assign_text = "Assign Party" if can_assign else "Need More Adventurers"
	else:
		can_assign = ready_adventurers.size() >= 1
		assign_text = "Assign Solo" if can_assign else "No Available Adventurers"
	
	var assign_button = Button.new()
	assign_button.text = assign_text
	assign_button.disabled = not can_assign
	assign_button.custom_minimum_size = Vector2(180, 35)
	
	if can_assign:
		if mission.party_required:
			assign_button.pressed.connect(func(): execute_party_mission(ready_adventurers, mission))
		else:
			assign_button.pressed.connect(func(): execute_solo_mission(ready_adventurers[0], mission))
	
	assignment_container.add_child(assign_button)

# Keep all your existing helper functions
func is_mission_assigned(mission: Dictionary) -> bool:
	for assigned in assigned_missions:
		if assigned.name == mission.name:
			return true
	return false

func execute_solo_mission(adventurer: Dictionary, mission: Dictionary):
	assigned_missions.append(mission)
	var success_chance = calculate_solo_success_chance(adventurer, mission)
	var roll = randi() % 100 + 1
	
	send_log_message("🗡️ " + adventurer.name + " departs on: " + mission.name)
	send_log_message("🎲 Success chance: " + str(success_chance) + "% (Rolled: " + str(roll) + ")")
	
		# Complete mission (this will set status to Resting/Injured)
	GameManager.complete_mission(adventurer, mission, roll <= success_chance)
	
	# CRITICAL FIX: Emit roster changed signal to update all UI
	GameManager.adventurer_roster_changed.emit()
	hide()

func execute_party_mission(party: Array, mission: Dictionary):
	assigned_missions.append(mission)
	var success_chance = calculate_party_success_chance(party, mission)
	var roll = randi() % 100 + 1
	for member in party:
		member.status = "on_mission"
		member["current_mission"] = mission.name
	var party_names = ""
	for i in range(party.size()):
		if i > 0:
			party_names += ", " + party[i].name
		else:
			party_names = party[i].name
			
	send_log_message("⚔️ Party (" + party_names + ") departs on: " + mission.name)
	send_log_message("🎲 Success: " + str(success_chance) + "% (Rolled: " + str(roll) + ")")
	
	GameManager.complete_party_mission(party, mission, roll <= success_chance)
	GameManager.adventurer_roster_changed.emit()
	hide()

func calculate_solo_success_chance(adventurer: Dictionary, mission: Dictionary) -> int:
	var base_chance = 50
	var success_factors = mission.get("success_factors", ["strength"])
	var stat_bonus = 0
	
	for factor in success_factors:
		match factor:
			"strength": stat_bonus += adventurer.strength * 3
			"dexterity": stat_bonus += adventurer.dexterity * 3
			"intelligence": stat_bonus += adventurer.intelligence * 3
			"endurance": stat_bonus += adventurer.endurance * 2
	
	var experience_bonus = adventurer.missions_completed * 2
	var danger_penalty = mission.danger * 8
	var final_chance = base_chance + stat_bonus + experience_bonus - danger_penalty
	
	return clampi(final_chance, 10, 95)

func calculate_party_success_chance(party: Array, mission: Dictionary) -> int:
	var base_chance = 60
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
	
	var synergy_bonus = party.size() * 5
	var success_factors = mission.get("success_factors", ["strength", "teamwork"])
	var stat_bonus = 0
	
	for factor in success_factors:
		match factor:
			"strength": stat_bonus += (total_strength * 2)
			"dexterity": stat_bonus += (total_dexterity * 2)
			"intelligence": stat_bonus += (total_intelligence * 2)
			"endurance": stat_bonus += (total_endurance * 1)
			"teamwork": stat_bonus += synergy_bonus
	
	var experience_bonus = total_experience * 1
	var danger_penalty = mission.danger * 6
	var final_chance = base_chance + stat_bonus + experience_bonus - danger_penalty
	
	return clampi(final_chance, 15, 95)

func get_category_info(category: String) -> Dictionary:
	var category_data = {
		"combat": {"name": "Combat Operations", "icon": "⚔️"},
		"escort": {"name": "Escort & Protection", "icon": "🛡️"},
		"gathering": {"name": "Resource Gathering", "icon": "🌿"},
		"investigation": {"name": "Investigation & Scouting", "icon": "🔍"},
		"delivery": {"name": "Delivery & Transport", "icon": "📦"},
		"construction": {"name": "Construction & Repair", "icon": "🔨"}
	}
	return category_data.get(category, {"name": "Miscellaneous", "icon": "📋"})

func get_category_color(category: String) -> Color:
	var colors = {
		"combat": Color.RED,
		"escort": Color.BLUE,
		"gathering": Color.GREEN,
		"investigation": Color.PURPLE,
		"delivery": Color.YELLOW,
		"construction": Color.ORANGE
	}
	return colors.get(category, Color.WHITE)

func get_danger_color(danger: int) -> Color:
	match danger:
		1: return Color.GREEN
		2: return Color.YELLOW
		3: return Color.ORANGE
		4: return Color.RED
		5: return Color.PURPLE
		_: return Color.WHITE

func get_danger_description(danger: int) -> String:
	match danger:
		1: return "Safe"
		2: return "Low Risk"
		3: return "Moderate"
		4: return "Dangerous"
		5: return "Extreme"
		_: return "Unknown"

func send_log_message(message: String):
	GameManager.log_message(message)

func refresh_daily_missions():
	assigned_missions.clear()
