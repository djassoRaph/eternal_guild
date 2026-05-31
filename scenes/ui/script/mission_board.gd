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
	"""Handle when a solo mission card's send button is pressed — DEFERRED resolution"""
	print("🎯 Mission dispatched: ", mission.get("name"), " with ", adventurer.get("name"))
	GameManager.send_on_mission(adventurer, mission)
	assigned_missions.append(mission)
	GameManager.adventurer_roster_changed.emit()
	queue_free()

func _on_party_mission_card_started(mission: Dictionary, adventurers: Array):
	"""Handle when a party mission card's send button is pressed — DEFERRED resolution"""
	print("🎯 Party mission dispatched: ", mission.get("name"), " with ", adventurers.size(), " adventurers")
	GameManager.send_party_on_mission(adventurers, mission)
	assigned_missions.append(mission)
	GameManager.adventurer_roster_changed.emit()
	queue_free()

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
