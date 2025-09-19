# Interactive.gd - FIXED VERSION with missing functions
extends Node3D

@onready var bar_area = $BarArea
@onready var mission_area = $MissionBoard  
@onready var recruitment_area = $RecruitmentDesk
@onready var bedroom_area = $NextDayArea

var player_in_bedroom = false
var player_in_bar = false
var player_in_mission = false
var player_in_recruitment = false
var player_in_bedroomarea = false

func _ready():
	print("Script attached to: ", get_path())
	print("Looking for GameUI...")
	
	print("bar_area: ", bar_area)
	print("mission_area: ", mission_area) 
	print("recruitment_area: ", recruitment_area)
	print("nextday_area: ", bedroom_area)
	
	# Connect area signals
	bar_area.body_entered.connect(_on_bar_entered)
	bar_area.body_exited.connect(_on_bar_exited)
	
	bedroom_area.body_entered.connect(_on_nextday_entered)
	bedroom_area.body_exited.connect(_on_nextday_exited)
	
	mission_area.body_entered.connect(_on_mission_entered)
	mission_area.body_exited.connect(_on_mission_exited)
	
	recruitment_area.body_entered.connect(_on_recruitment_entered)
	recruitment_area.body_exited.connect(_on_recruitment_exited)
	
	send_log_message("Interactive areas connected!")

func _input(event):
	if event.is_action_pressed("interact"):
		# PRIORITY 1: Try patron interaction first
		if try_interact_with_nearby_patron():
			return  # Exit early if patron interaction happened
		
		# PRIORITY 2: Zone-based interactions
		var player = get_node("/root/Node3D/SubViewportContainer/SubViewport/Player")
		
		if player_in_bar:
			print("🍺 Attempting to open beer popup...")
			var beer_popup = get_node("/root/Node3D/GameUI/PopupManager/BeerManagementPopup")
			print("🔍 Beer popup found: ", beer_popup)
			if beer_popup:
				print("✅ Calling open_beer_management...")
				beer_popup.open_beer_management()
				send_log_message("Looking at your stock")
			else:
				print("❌ Beer popup not found!")

		elif player_in_mission:
			# Check if player has any adventurers first
			var main_script = get_tree().current_scene
			if main_script and main_script.has_method("get_adventurer_count"):
				var adventurer_count = main_script.get_adventurer_count()
				if adventurer_count == 0:
					send_log_message("❌ You need to hire adventurers before checking the mission board!")
					send_log_message("💡 Visit the recruitment desk first.")
					return
			
			var mission_popup = get_node("/root/Node3D/GameUI/PopupManager/MissionBoardPopup")
			if mission_popup:
				mission_popup.open_mission_board()
				send_log_message("Examining available guild contracts...")
				
		elif player_in_recruitment:
			var recruitment_popup = get_node("/root/Node3D/GameUI/PopupManager/RecruitmentPopup")
			if recruitment_popup:
				recruitment_popup.open_recruitment_desk()
				send_log_message("Looking for new guild members...")
		
		elif player_in_bedroomarea:
			send_log_message("💤 Resting and advancing to the next day...")
			advance_day_interaction()

# MISSING FUNCTION - CRITICAL FIX
func find_nearby_patrons() -> Array:
	"""Find all patrons within interaction range of player"""
	var nearby_patrons = []
	var player = get_node("/root/Node3D/SubViewportContainer/SubViewport/Player")
	
	if not player:
		return nearby_patrons
	
	# Find all patron nodes in the scene
	var patron_spawner = get_node("/root/Node3D/SubViewportContainer/SubViewport/PatronSpawner")
	if not patron_spawner:
		return nearby_patrons
	
	# Check all current patrons from the spawner
	for patron in patron_spawner.current_patrons:
		if patron and is_instance_valid(patron):
			var distance = player.global_position.distance_to(patron.global_position)
			if distance <= 2.5:  # Within interaction range
				nearby_patrons.append(patron)
	
	return nearby_patrons

func try_interact_with_nearby_patron() -> bool:
	"""Enhanced interaction - serve beer OR chat/recruit"""
	var nearby_patrons = find_nearby_patrons()
	
	if nearby_patrons.size() == 0:
		return false  # No patrons nearby
	
	var patron = nearby_patrons[0]  # Interact with closest patron
	
	# Priority 1: If patron wants service (yellow sphere), serve them
	if patron.wants_service and not patron.has_been_served:
		return try_serve_patron(patron)
	
	# Priority 2: If patron has been served, open chat/recruitment options
	elif patron.has_been_served or not patron.wants_service:
		return open_patron_chat(patron)
	
	return false

func try_serve_patron(patron) -> bool:
	"""Existing beer service functionality"""
	var player = get_node("/root/Node3D/SubViewportContainer/SubViewport/Player")
	if not player:
		return false
	
	if patron.serve(player.global_position):
		print("✅ Served patron with beer!")
		
		# IMPORTANT: Check for recruitment interest after good service
		# NOTE: This will be implemented when RecruitmentManager is ready
		# if GameManager.recruitment_manager:
		#     GameManager.recruitment_manager.check_patron_recruitment_interest(patron, true)
		
		return true
	return false

func open_patron_chat(patron) -> bool:
	"""New chat system that can lead to recruitment"""
	# NOTE: For now, just show regular dialogue until RecruitmentManager is implemented
	show_regular_dialogue(patron, get_random_patron_dialogue())
	
	# FUTURE: When RecruitmentManager is ready, uncomment this:
	# if GameManager.recruitment_manager:
	#     var interaction_result = GameManager.recruitment_manager.interact_with_patron(patron)
	#     if interaction_result.has_recruitment_interest:
	#         show_recruitment_dialogue(patron, interaction_result)
	#         return true
	#     else:
	#         show_regular_dialogue(patron, interaction_result.dialogue)
	#         return true
	
	return true

func get_random_patron_dialogue() -> String:
	"""Temporary dialogue until RecruitmentManager is implemented"""
	var dialogues = [
		"This beer is excellent! Where do you source it?",
		"I heard there's been dragon activity near the eastern mountains...",
		"Business seems good here. You're doing well for yourself.",
		"Have you heard the latest news from the capital?",
		"The weather's been strange lately, don't you think?",
		"Your guild has quite a reputation around these parts.",
		"I've been thinking about taking up adventuring myself...",
		"This place has a good atmosphere. Very welcoming.",
	]
	return dialogues[randi() % dialogues.size()]

func show_recruitment_dialogue(patron, interaction_data):
	"""Show recruitment opportunity dialogue"""
	var main_scene = get_tree().current_scene
	
	# Display the patron's interest message
	if main_scene.has_method("log_message"):
		main_scene.log_message("[" + patron.patron_name + "]: " + interaction_data.dialogue)
		
		# Player response options via log
		main_scene.log_message("[You]: Oh, you're looking for work? I do run an adventuring guild...")
		main_scene.log_message("[" + patron.patron_name + "]: Perfect! I'd love to join if you'll have me.")
		main_scene.log_message("[You]: Let me check our current roster. Head over to the recruitment desk!")
	
	# FUTURE: Add patron to recruitment system when RecruitmentManager is ready
	# var recruitment_data = interaction_data.recruitment_data
	# GameManager.recruitment_manager.add_patron_to_recruitment_pool(patron, recruitment_data)
	# patron.show_recruitment_interest_indicator()

func show_regular_dialogue(patron, dialogue: String):
	"""Show regular patron conversation"""
	var main_scene = get_tree().current_scene
	
	if main_scene.has_method("log_message"):
		main_scene.log_message("[" + patron.patron_name + "]: " + dialogue)
		
		# Random player responses
		var player_responses = [
			"[You]: Interesting, tell me more.",
			"[You]: Thanks for letting me know.",
			"[You]: I appreciate you sharing that.",
			"[You]: Good to know, thanks.",
			"[You]: Always good to hear from our regulars.",
		]
		var response = player_responses[randi() % player_responses.size()]
		main_scene.log_message(response)

# Zone interaction functions
func _on_bar_entered(body):
	if body.name == "Player":
		player_in_bar = true
		print("💡 Press E to manage tavern")

func _on_bar_exited(body):
	if body.name == "Player":
		player_in_bar = false

func _on_mission_entered(body):
	if body.name == "Player":
		player_in_mission = true
		print("💡 Press E to view missions")

func _on_mission_exited(body):
	if body.name == "Player":
		player_in_mission = false

func _on_recruitment_entered(body):
	if body.name == "Player":
		player_in_recruitment = true
		print("💡 Press E to recruit adventurers")

func _on_recruitment_exited(body):
	if body.name == "Player":
		player_in_recruitment = false
		
func _on_nextday_entered(body):
	if body.name == "Player":
		player_in_bedroomarea = true
		print("Near bedroom door - Press E to rest")

func _on_nextday_exited(body):
	if body.name == "Player":
		player_in_bedroomarea = false

func send_log_message(message: String):
	var main_script = get_tree().current_scene
	if main_script and main_script.has_method("log_message"):
		await get_tree().process_frame  # Wait one frame
		main_script.log_message(message)
	else:
		print("Could not find main tavern script")

func advance_day_interaction():
	"""Handle the bedroom day advancement interaction"""
	if player_in_bedroomarea:
		GameManager.advance_day()
		send_log_message("Day advanced successfully!")
