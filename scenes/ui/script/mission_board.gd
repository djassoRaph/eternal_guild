# mission_board.gd
extends Control

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
@onready var missions_container = $MainContainer/ScrollContainer/MissionsContainer

const MISSION_CARD_SCENE = preload("res://scenes/ui/SingleMissionCard.tscn")
const PARTY_MISSION_CARD_SCENE = preload("res://scenes/ui/PartyMissionCard.tscn")
var assigned_missions = []
var _subviewport_container = null
var _confirm_panel = null

signal board_closed

func _ready():
	print("🎯 Mission Board ready")
	GameManager.adventurer_roster_changed.connect(_refresh_mission_display)
	visible = false
	add_to_group("mission_board")
	
	mouse_filter = Control.MOUSE_FILTER_STOP
	var viewport = get_tree().root.get_node_or_null("Node3D/SubViewportContainer")
	if viewport:
		viewport.mouse_filter = Control.MOUSE_FILTER_PASS
		print("🔧 Emergency fix applied!")
	_subviewport_container = get_tree().root.get_node_or_null("Node3D/SubViewportContainer")
	if scroll_container:
		scroll_container.mouse_filter = Control.MOUSE_FILTER_STOP
		scroll_container.follow_focus = true

		
func _input(event):
	if not visible:
		return
	
	# Handle ESC to close
	if event.is_action_pressed("ui_cancel"):
		close_board()
		get_viewport().set_input_as_handled()
	

func close_board():
	"""Properly close the mission board"""
	print("🚪 Closing mission board")
	if _subviewport_container:
		_subviewport_container.mouse_filter = Control.MOUSE_FILTER_STOP
	board_closed.emit()
	queue_free()

func open_mission_board():
	"""Open and populate the mission board"""
	var total_adventurers = GameManager.get_adventurer_count()
	
	if total_adventurers == 0:
		send_log_message("❌ No adventurers in your guild!")
		send_log_message("💡 Visit the recruitment desk to hire adventurers first.")
		close_board()
		return
	if _subviewport_container:
		_subviewport_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	update_static_ui()
	populate_missions()
	visible = true
	print("✅ Mission board opened")


func update_static_ui():
	"""Update all static UI labels with current game state"""
	title_label.text = "📋 Guild Mission Board - Day " + str(GameManager.get_day())
	
	var available_missions = GameManager.available_missions
	var solo_count = available_missions.filter(func(m): return not m.party_required).size()
	var party_count = available_missions.size() - solo_count
	
	mission_stats_label.text = "📊 Available: " + str(available_missions.size()) + " missions (🚶 " + str(solo_count) + " solo, 👥 " + str(party_count) + " party)"
	
	var ready = GameManager.get_ready_adventurers().size()
	readiness_label.text = "🗡️ Ready: " + str(ready) + " adventurers"
	
	if ready >= 2:
		readiness_label.add_theme_color_override("font_color", Color.GREEN)
	elif ready == 1:
		readiness_label.add_theme_color_override("font_color", Color.YELLOW)
	else:
		readiness_label.add_theme_color_override("font_color", Color.RED)
	
	update_tier_labels()

func _refresh_mission_display():
	if visible:
		populate_missions()

func update_tier_labels():
	"""Update tier unlock status display"""
	var current_tier = GameManager.mission_tier_unlocked
	
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
	print("🔄 Populating missions")
	
	# Clear existing mission cards
	for child in missions_container.get_children():
		child.queue_free()
	
	
	await get_tree().process_frame
	
	var available_missions = GameManager.available_missions
	
	if available_missions.size() == 0:
		var no_missions = Label.new()
		no_missions.text = "📄 No missions available. Check back tomorrow!"
		no_missions.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		no_missions.add_theme_font_size_override("font_size", 14)
		missions_container.add_child(no_missions)
		return
	
	# Get ready adventurers once (not per mission)
	var solo = available_missions.filter(func(m): 
		return not m.get("party_required", false))
	var party = available_missions.filter(func(m): 
		var pr = m.get("party_required", false)
		return pr == true or (pr is int and pr > 1)
	)
	var ready_adventurers = GameManager.get_ready_adventurers()
	print("   Available adventurers: ", ready_adventurers.size())
	
	# Group missions by category
	var missions_by_category = group_missions_by_category(available_missions)
	
	# Create mission cards by category
	for category in missions_by_category.keys():
		create_category_section(category, missions_by_category[category], ready_adventurers)

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

func create_category_section(category: String, missions: Array, ready_adventurers: Array):
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
		create_mission_card(mission, ready_adventurers)

func create_mission_card(mission: Dictionary, ready_adventurers: Array):
	print("   Creating card for: ", mission.get("name", "Unknown"))
	
	var party_raw = mission.get("party_required", 0)
	var is_party_mission: bool
	if party_raw is bool:
		is_party_mission = party_raw
	elif party_raw is int:
		is_party_mission = party_raw > 1
	else:
		is_party_mission = false
	var card_instance
	
	if is_party_mission:
		card_instance = PARTY_MISSION_CARD_SCENE.instantiate()
		missions_container.add_child(card_instance)
		card_instance.setup(mission, ready_adventurers)
		card_instance.mission_started.connect(_on_party_mission_card_started)  # ← different handler
	else:
		card_instance = MISSION_CARD_SCENE.instantiate()
		missions_container.add_child(card_instance)
		card_instance.setup(mission, ready_adventurers)
		card_instance.mission_started.connect(_on_mission_card_started)
	
	print("   ✓ Card created for: ", mission.get("name", "Unknown"))

func _on_mission_card_started(mission: Dictionary, adventurer: Dictionary):
	"""Handle when a solo mission card's send button is pressed — show confirmation first"""
	print("🎯 Mission confirmation requested: ", mission.get("name"), " with ", adventurer.get("name"))
	show_dispatch_confirm(mission, adventurer)

func _on_party_mission_card_started(mission: Dictionary, adventurers: Array):
	"""Handle when a party mission card's send button is pressed — show confirmation first"""
	print("🎯 Party mission confirmation requested: ", mission.get("name"), " with ", adventurers.size(), " adventurers")
	show_party_dispatch_confirm(mission, adventurers)

func execute_solo_mission(adventurer: Dictionary, mission: Dictionary):
	"""Execute a solo mission"""
	var success_chance = calculate_solo_success_chance(adventurer, mission)
	var roll = randi() % 100 + 1
	
	send_log_message("🗡️ " + adventurer.name + " departs on: " + mission.name)
	send_log_message("🎲 Success chance: " + str(success_chance) + "% (Rolled: " + str(roll) + ")")
	
	# Complete mission through GameManager
	GameManager.complete_mission(adventurer, mission, roll <= success_chance)
	
	# Emit roster changed to update UI
	GameManager.adventurer_roster_changed.emit()
	
	queue_free()

func calculate_solo_success_chance(adventurer: Dictionary, mission: Dictionary) -> int:
	"""Calculate success chance for solo mission"""
	var base_chance = 50
	var success_factors = mission.get("success_factors", ["strength"])
	var stat_bonus = 0
	
	for factor in success_factors:
		match factor:
			"strength": stat_bonus += adventurer.get("strength", 0) * 3
			"dexterity": stat_bonus += adventurer.get("dexterity", 0) * 3
			"intelligence": stat_bonus += adventurer.get("intelligence", 0) * 3
			"endurance": stat_bonus += adventurer.get("endurance", 0) * 2
	
	var experience_bonus = adventurer.get("missions_completed", 0) * 2
	var danger_penalty = mission.get("danger", 1) * 8
	var final_chance = base_chance + stat_bonus + experience_bonus - danger_penalty
	
	return clampi(final_chance, 10, 95)

func is_mission_assigned(mission: Dictionary) -> bool:
	"""Check if mission is already assigned"""
	for assigned in assigned_missions:
		if assigned.name == mission.name:
			return true
	return false

# Helper functions for UI display
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

func send_log_message(message: String):
	GameManager.log_message(message)

func refresh_daily_missions():
	"""Reset missions for new day"""
	assigned_missions.clear()

# === DISPATCH CONFIRMATION PANEL ===

func _remove_confirm_panel():
	if _confirm_panel != null and is_instance_valid(_confirm_panel):
		_confirm_panel.queue_free()
	_confirm_panel = null

func _build_confirm_panel_base(mission: Dictionary) -> PanelContainer:
	var panel = PanelContainer.new()
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.10, 0.09, 0.97)
	style.border_color = Color(0.8, 0.6, 0.2, 0.8)
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	panel.add_theme_stylebox_override("panel", style)
	panel.custom_minimum_size = Vector2(420, 0)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	panel.add_child(vbox)

	# Mission name
	var category = mission.get("category", "misc")
	var cat_info = get_category_info(category)
	var name_label = Label.new()
	name_label.text = cat_info.icon + "  " + mission.get("name", "Unknown Mission")
	name_label.add_theme_font_size_override("font_size", 18)
	name_label.add_theme_color_override("font_color", Color(0.95, 0.85, 0.5))
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(name_label)

	var sep = HSeparator.new()
	vbox.add_child(sep)

	# Duration
	var duration = mission.get("duration_days", 1)
	var dur_label = Label.new()
	dur_label.text = "⏱  Duration: " + str(duration) + " day" + ("s" if duration != 1 else "") + " away"
	dur_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	vbox.add_child(dur_label)

	# Danger
	var danger = mission.get("danger", 1)
	var skulls = ""
	for _i in danger:
		skulls += "💀"
	var danger_label = Label.new()
	danger_label.text = "⚠  Danger: " + skulls + " (" + str(danger) + ")"
	danger_label.add_theme_color_override("font_color", Color(0.9, 0.5, 0.2))
	vbox.add_child(danger_label)

	# Reward
	var reward = mission.get("reward_range", [0, 0])
	var reward_label = Label.new()
	reward_label.text = "💰  Reward: " + str(reward[0]) + "–" + str(reward[1]) + " gold"
	reward_label.add_theme_color_override("font_color", Color(0.9, 0.8, 0.3))
	vbox.add_child(reward_label)

	return panel

func show_dispatch_confirm(mission: Dictionary, adventurer: Dictionary):
	_remove_confirm_panel()

	var panel = _build_confirm_panel_base(mission)
	var vbox = panel.get_child(0) as VBoxContainer

	# Success chance
	var chance = GameManager.calculate_mission_success_chance(adventurer, mission)
	var chance_label = Label.new()
	chance_label.text = "🎲  " + str(chance) + "% chance of success"
	var chance_color: Color
	if chance >= 70:
		chance_color = Color(0.3, 0.85, 0.4)
	elif chance >= 50:
		chance_color = Color(0.9, 0.8, 0.2)
	else:
		chance_color = Color(0.9, 0.35, 0.3)
	chance_label.add_theme_color_override("font_color", chance_color)
	chance_label.add_theme_font_size_override("font_size", 16)
	chance_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(chance_label)

	# Relevant stats
	var factors = mission.get("success_factors", [])
	if factors.size() > 0:
		var stats_header = Label.new()
		stats_header.text = "📊  Relevant Stats — " + adventurer.get("name", "Adventurer") + ":"
		stats_header.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
		vbox.add_child(stats_header)
		for factor in factors:
			if factor in ["strength", "dexterity", "intelligence", "endurance"]:
				var stat_label = Label.new()
				stat_label.text = "  • " + factor.capitalize() + ": " + str(adventurer.get(factor, 0))
				stat_label.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))
				vbox.add_child(stat_label)

	# Trait display
	var personality = adventurer.get("personality", "")
	if personality != "":
		var trait_data = GameManager.get_trait_data(personality)
		if not trait_data.is_empty():
			var effect_text = ""
			if trait_data.has("mission_bonus"):
				var pct = int(trait_data.mission_bonus * 100)
				effect_text = ("+" if pct > 0 else "") + str(pct) + "% success chance"
			elif trait_data.has("danger_resistance"):
				effect_text = "+" + str(int(trait_data.danger_resistance * 100)) + "% on dangerous missions"
			elif trait_data.has("reward_bonus"):
				effect_text = "+" + str(int(trait_data.reward_bonus * 100)) + "% gold on success"
			elif trait_data.has("injury_chance"):
				effect_text = "Higher injury risk on failure"
			elif trait_data.has("cost_multiplier"):
				effect_text = "Costs more daily wages"
			if effect_text != "":
				var trait_label = Label.new()
				trait_label.text = "⚡  Trait: " + personality.capitalize() + " — " + effect_text
				trait_label.add_theme_color_override("font_color", Color(0.85, 0.75, 1.0))
				trait_label.add_theme_font_size_override("font_size", 12)
				vbox.add_child(trait_label)

	var sep2 = HSeparator.new()
	vbox.add_child(sep2)

	var btn_row = HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.add_theme_constant_override("separation", 16)
	vbox.add_child(btn_row)

	var confirm_btn = Button.new()
	confirm_btn.text = "Send " + adventurer.get("name", "Adventurer")
	confirm_btn.add_theme_color_override("font_color", Color(0.3, 0.85, 0.4))
	confirm_btn.pressed.connect(func():
		_remove_confirm_panel()
		GameManager.send_on_mission(adventurer, mission)
		assigned_missions.append(mission)
		GameManager.adventurer_roster_changed.emit()
		queue_free()
	)
	btn_row.add_child(confirm_btn)

	var cancel_btn = Button.new()
	cancel_btn.text = "Cancel"
	cancel_btn.add_theme_color_override("font_color", Color(0.9, 0.35, 0.3))
	cancel_btn.pressed.connect(_remove_confirm_panel)
	btn_row.add_child(cancel_btn)

	var confirm_layer = CanvasLayer.new()
	confirm_layer.layer = 10
	get_tree().root.add_child(confirm_layer)

	var center = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	confirm_layer.add_child(center)

	center.add_child(panel)
	_confirm_panel = confirm_layer

func show_party_dispatch_confirm(mission: Dictionary, party: Array):
	_remove_confirm_panel()

	var panel = _build_confirm_panel_base(mission)
	var vbox = panel.get_child(0) as VBoxContainer

	# Average success chance with party bonus
	var total_chance = 0
	for adv in party:
		total_chance += GameManager.calculate_mission_success_chance(adv, mission)
	var avg_chance = total_chance / party.size() if party.size() > 0 else 0
	var party_bonus = (party.size() - 1) * 5
	var final_chance = clampi(avg_chance + party_bonus, 10, 95)

	var chance_label = Label.new()
	chance_label.text = "🎲  " + str(final_chance) + "% party chance of success"
	var chance_color: Color
	if final_chance >= 70:
		chance_color = Color(0.3, 0.85, 0.4)
	elif final_chance >= 50:
		chance_color = Color(0.9, 0.8, 0.2)
	else:
		chance_color = Color(0.9, 0.35, 0.3)
	chance_label.add_theme_color_override("font_color", chance_color)
	chance_label.add_theme_font_size_override("font_size", 16)
	chance_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(chance_label)

	# Party members with relevant stats
	var factors = mission.get("success_factors", [])
	var party_header = Label.new()
	party_header.text = "👥  Party Members:"
	party_header.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	vbox.add_child(party_header)

	for adv in party:
		var stat_parts: Array = []
		for factor in factors:
			if factor in ["strength", "dexterity", "intelligence", "endurance"]:
				stat_parts.append(factor.capitalize()[0] + ": " + str(adv.get(factor, 0)))
		var adv_line = "  • " + adv.get("name", "?") + " (" + adv.get("class", "?") + ")"
		if stat_parts.size() > 0:
			adv_line += " — " + ", ".join(stat_parts)
		var adv_label = Label.new()
		adv_label.text = adv_line
		adv_label.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))
		vbox.add_child(adv_label)

	var sep2 = HSeparator.new()
	vbox.add_child(sep2)

	var btn_row = HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.add_theme_constant_override("separation", 16)
	vbox.add_child(btn_row)

	var confirm_btn = Button.new()
	confirm_btn.text = "Send Party (" + str(party.size()) + ")"
	confirm_btn.add_theme_color_override("font_color", Color(0.3, 0.85, 0.4))
	confirm_btn.pressed.connect(func():
		_remove_confirm_panel()
		GameManager.send_party_on_mission(party, mission)
		assigned_missions.append(mission)
		GameManager.adventurer_roster_changed.emit()
		queue_free()
	)
	btn_row.add_child(confirm_btn)

	var cancel_btn = Button.new()
	cancel_btn.text = "Cancel"
	cancel_btn.add_theme_color_override("font_color", Color(0.9, 0.35, 0.3))
	cancel_btn.pressed.connect(_remove_confirm_panel)
	btn_row.add_child(cancel_btn)

	var confirm_layer = CanvasLayer.new()
	confirm_layer.layer = 10
	get_tree().root.add_child(confirm_layer)

	var center = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	confirm_layer.add_child(center)

	center.add_child(panel)
	_confirm_panel = confirm_layer
